import Foundation
import SwiftData
import UIKit
import PDFKit

/// Actor-based manager for processing bulk import jobs
/// Handles rate limiting, concurrency control, and state persistence
@MainActor
final class ImportJobManager: ObservableObject {

    // MARK: - Configuration
    private let maxConcurrentImports = 3
    private let maxRequestsPerMinute = 20
    private var requestTimestamps: [Date] = []

    // MARK: - State
    @Published private(set) var activeJob: ImportJob?
    @Published private(set) var isProcessing = false

    /// Immediate signal for UI responsiveness - bypasses @Query latency
    /// Set synchronously when job is created, before SwiftData save completes
    @Published private(set) var pendingJobId: UUID?

    private var currentTasks: [UUID: Task<Void, Never>] = [:]
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var shouldPauseForBackground = false
    private var activeContext: ModelContext? // Store context for background saves

    // MARK: - Dependencies
    private let importService: RecipeImportService
    private let aiRecipeExtractor: AIRecipeExtractor
    private let multiPageAnalyzer: MultiPageRecipeAnalyzer
    private let firebaseSync: FirebaseSyncService
    private let backendConfig: BackendConfig

    init(
        importService: RecipeImportService,
        aiRecipeExtractor: AIRecipeExtractor,
        multiPageAnalyzer: MultiPageRecipeAnalyzer,
        firebaseSync: FirebaseSyncService,
        backendConfig: BackendConfig
    ) {
        self.importService = importService
        self.aiRecipeExtractor = aiRecipeExtractor
        self.multiPageAnalyzer = multiPageAnalyzer
        self.firebaseSync = firebaseSync
        self.backendConfig = backendConfig
        setupRateLimiter()
        setupBackgroundHandling()
    }

    // MARK: - Background Task Handling

    private func setupBackgroundHandling() {
        // Observe app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appWillEnterBackground() {
        guard isProcessing, let job = activeJob, let context = activeContext else { return }

        Log.info("App backgrounding - starting background task", category: .import, metadata: [
            "job_id": job.id.uuidString,
            "phase": job.phase.rawValue
        ])

        // Mark as potentially interrupted
        job.wasInterrupted = true
        job.interruptedAt = Date()
        job.checkpoint?.markInterrupted(phase: job.phase)

        // Save immediately using stored context
        try? context.save()

        // Request background execution time
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Called when time expires - clean up
            Log.warning("Background task expired - import interrupted", category: .import)
            Task { @MainActor in
                self?.handleBackgroundTaskExpiration()
            }
        }
    }

    @objc private func appDidBecomeActive() {
        guard isProcessing else { return }

        Log.info("App foregrounding - ending background task", category: .import)

        // End background task when returning to foreground
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    private func handleBackgroundTaskExpiration() {
        Log.warning("Background time limit reached - import will pause", category: .import)

        // End the background task
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }

        // Note: Import will be killed by iOS, but state is persisted in SwiftData
        // User can resume by reopening the app
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

        // Clean up background task if still active
        let taskToEnd = backgroundTask
        if taskToEnd != .invalid {
            Task { @MainActor in
                UIApplication.shared.endBackgroundTask(taskToEnd)
            }
        }
    }

    // MARK: - Job Creation

    /// Create a new import job from a list of URLs
    /// - Parameters:
    ///   - urls: Array of URL strings to import
    ///   - jobName: Optional name for the job
    ///   - context: SwiftData ModelContext for persistence
    /// - Returns: The created ImportJob
    func createJob(
        urls: [String],
        jobName: String? = nil,
        collectionName: String? = nil,
        collectionType: CollectionType? = nil,
        context: ModelContext
    ) throws -> ImportJob {
        // Create job
        let job = ImportJob(jobName: jobName)
        job.status = .processing  // Set to processing immediately so banner shows it
        job.cookbookName = collectionName
        job.collectionType = collectionType

        // Signal UI immediately (bypasses @Query latency)
        self.pendingJobId = job.id

        context.insert(job)

        // Create items with duplicate detection
        var seenNormalized: Set<String> = []
        var items: [ImportItem] = []

        for urlString in urls {
            let normalized = URLNormalizer.normalize(urlString)
            let item = ImportItem(urlString: urlString, normalizedURL: normalized)

            // Check for duplicates within this batch
            if let normalized = normalized {
                if seenNormalized.contains(normalized) {
                    item.markSkipped(reason: "Duplicate URL in batch")
                } else {
                    seenNormalized.insert(normalized)
                }
            }

            item.job = job
            context.insert(item)

            // Create placeholder recipe for non-skipped items (progressive enhancement)
            if item.status != .skipped {
                createPlaceholderRecipe(for: item, job: job, context: context)
            }

            items.append(item)
        }

        job.items = items
        job.totalItems = items.count
        job.completedItems = items.filter { $0.isCompleted }.count
        job.successfulItems = items.filter { $0.status == .success }.count
        job.failedItems = items.filter { $0.status == .failed }.count

        try context.save()

        return job
    }

    /// Create and analyze PDF import job from PDF URLs
    /// This is the RESILIENT method that creates the job FIRST, then analyzes
    /// - Parameters:
    ///   - pdfURLs: Array of PDF file URLs
    ///   - jobName: Name for the job
    ///   - cookbookName: Optional cookbook name for auto-categorization
    ///   - collectionType: Optional collection type
    ///   - context: SwiftData ModelContext for persistence
    ///   - costBreakdown: Optional cost breakdown for credit deduction
    ///   - generateAIImages: Whether to generate AI images for imported recipes
    /// - Returns: The created ImportJob (already inserted and saved)
    func createAndAnalyzePDFJob(
        pdfURLs: [URL],
        jobName: String,
        cookbookName: String?,
        collectionType: CollectionType? = nil,
        context: ModelContext,
        costBreakdown: PDFCostCalculator.CostBreakdown? = nil,
        generateAIImages: Bool = false
    ) async throws -> ImportJob {
        // STEP 1: Create job immediately (so banner appears)
        let job = ImportJob(jobName: jobName, continueOnError: true)
        job.status = .processing  // Set to processing immediately so banner shows it
        job.phase = .validation
        job.phaseProgress = 0.0
        job.totalItems = 0 // Will be updated as we discover recipes
        job.cookbookName = cookbookName
        job.collectionType = collectionType
        job.pdfURL = pdfURLs.first?.absoluteString // Store for resume detection
        job.shouldGenerateAIImages = generateAIImages

        // Signal UI immediately (bypasses @Query latency)
        self.pendingJobId = job.id

        context.insert(job)

        // Create checkpoint for resumable imports
        let checkpoint = PDFImportCheckpoint()
        checkpoint.job = job
        context.insert(checkpoint)
        job.checkpoint = checkpoint

        try context.save()

        Log.info("PDF import job created (analyzing...)", category: .import, metadata: [
            "pdf_count": pdfURLs.count
        ])

        // STEP 1.5: Deduct credits if cost breakdown provided
        if let breakdown = costBreakdown, breakdown.totalCredits > 0 {
            try await deductCreditsForImport(
                credits: breakdown.totalCredits,
                context: context
            )
            job.creditsDeducted = breakdown.totalCredits
            try context.save()
        }

        // STEP 1.6: Copy PDFs to stable location (temp files get cleaned up during long operations)
        // Returns tuples of (originalURL, stableURL) to maintain classification lookup
        let pdfURLMapping = try copyPDFsToStableLocation(pdfURLs, jobId: job.id)

        // STEP 2: Validate PDFs quickly
        job.phase = .validation
        job.phaseProgress = 1.0
        try context.save()

        // STEP 3: Analyze pages and create items (this is the long operation)
        job.phase = .analysis
        job.phaseProgress = 0.0
        try context.save()

        var allItems: [ImportItem] = []
        var totalPagesProcessed = 0
        var totalPagesAcrossAllPDFs = 0

        // Count total pages first for accurate progress
        for (_, stableURL) in pdfURLMapping {
            guard let pdfDocument = PDFDocument(url: stableURL) else { continue }
            totalPagesAcrossAllPDFs += pdfDocument.pageCount
        }

        // Process each PDF (using stable copies, but original URLs for classification lookup)
        for (originalURL, pdfURL) in pdfURLMapping {
            // Extract cookbook metadata from front matter
            let metadataExtractor = PDFMetadataExtractor()
            let cookbookMetadata = await metadataExtractor.extractMetadata(from: pdfURL)

            if let metadata = cookbookMetadata {
                Log.info("Extracted cookbook metadata", category: .import, metadata: [
                    "file": pdfURL.lastPathComponent,
                    "title": metadata.title ?? "nil",
                    "author": metadata.author ?? "nil"
                ])

                // Store author on job for collection creation (only set once from first PDF)
                if job.cookbookAuthor == nil, let author = metadata.author, !author.isEmpty {
                    job.cookbookAuthor = author
                    try? context.save()
                }
            }

            // Extract first page as cookbook cover image (only if it looks like a cover, not a recipe page)
            if job.cookbookCoverImagePath == nil, // Only extract once for first PDF
               let pdfDocument = PDFDocument(url: pdfURL),
               let firstPage = pdfDocument.page(at: 0) {

                // Check if first page is a text-heavy recipe page vs a proper cover
                // Covers typically have minimal text (title, author) while recipe pages have lots of text
                let pageText = firstPage.string ?? ""
                let textLength = pageText.count
                let isTextHeavyPage = textLength > 400 // Recipe pages typically have 400+ characters

                if isTextHeavyPage {
                    // Skip using this as cover - it's likely a recipe page, not a cookbook cover
                    // The collection will get an AI-generated cover if AI images are enabled
                    Log.info("First page appears to be a recipe page, skipping as cover", category: .import, metadata: [
                        "file": pdfURL.lastPathComponent,
                        "textLength": textLength
                    ])
                } else {
                    // Render first page to image - it looks like a proper cover
                    let pageBounds = firstPage.bounds(for: .mediaBox)
                    let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
                    let coverImage = renderer.image { ctx in
                        UIColor.white.setFill()
                        ctx.fill(CGRect(origin: .zero, size: pageBounds.size))
                        ctx.cgContext.translateBy(x: 0, y: pageBounds.height)
                        ctx.cgContext.scaleBy(x: 1, y: -1)
                        firstPage.draw(with: .mediaBox, to: ctx.cgContext)
                    }

                    // Save cover image to disk
                    let imageStorage = ServiceContainer.shared.resolve(ImageStorageService.self)
                    let coverFileName = "cookbook-cover-\(UUID().uuidString)"
                    if let coverPath = try? await imageStorage.saveImage(coverImage, fileName: coverFileName) {
                        job.cookbookCoverImagePath = coverPath
                        try? context.save()

                        Log.info("Saved cookbook cover image", category: .import, metadata: [
                            "file": pdfURL.lastPathComponent,
                            "coverPath": coverPath,
                            "textLength": textLength
                        ])
                    }
                }
            }

            // Check if this PDF is text-rich (use text pipeline) or scanned (use Vision pipeline)
            // Use original URL for classification lookup since that's what PDFCostCalculator used
            let pdfType = costBreakdown?.classifications[originalURL]
            let isTextRich = pdfType == .textRich

            if isTextRich {
                // TEXT-RICH PATH: Use fast text extraction pipeline
                Log.info("Using TEXT pipeline for text-rich PDF", category: .import, metadata: [
                    "file": pdfURL.lastPathComponent
                ])

                let items = try await processTextRichPDF(
                    pdfURL: pdfURL,
                    cookbookMetadata: cookbookMetadata,
                    job: job,
                    context: context,
                    totalPagesAcrossAllPDFs: totalPagesAcrossAllPDFs,
                    totalPagesProcessed: &totalPagesProcessed
                )
                allItems.append(contentsOf: items)

            } else {
                // SCANNED/MIXED PATH: Use Vision API pipeline
                Log.info("Using VISION pipeline for scanned/mixed PDF", category: .import, metadata: [
                    "file": pdfURL.lastPathComponent,
                    "type": pdfType?.displayName ?? "unknown"
                ])

                let items = try await processScannedPDF(
                    pdfURL: pdfURL,
                    cookbookMetadata: cookbookMetadata,
                    job: job,
                    context: context,
                    totalPagesAcrossAllPDFs: totalPagesAcrossAllPDFs,
                    pagesAlreadyProcessed: totalPagesProcessed
                )
                allItems.append(contentsOf: items)
                // Update total pages after Vision processing
                if let document = PDFDocument(url: pdfURL) {
                    totalPagesProcessed += document.pageCount
                }
            }
        }

        // STEP 4: Update job with all items
        job.items = allItems
        job.totalItems = allItems.count
        job.phaseProgress = 1.0
        try context.save()

        Log.info("PDF analysis complete - job ready for extraction", category: .import, metadata: [
            "pdf_count": pdfURLs.count,
            "recipe_count": allItems.count
        ])

        return job
    }

    // MARK: - Text-Rich PDF Processing (Fast Path)

    /// Process a text-rich PDF using text extraction (much faster than Vision)
    private func processTextRichPDF(
        pdfURL: URL,
        cookbookMetadata: CookbookMetadata?,
        job: ImportJob,
        context: ModelContext,
        totalPagesAcrossAllPDFs: Int,
        totalPagesProcessed: inout Int
    ) async throws -> [ImportItem] {
        var items: [ImportItem] = []

        // Maintain security-scoped access for the entire operation
        let needsSecurityScope = pdfURL.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                pdfURL.stopAccessingSecurityScopedResource()
            }
        }

        // Step 1: Extract text from all pages (pass useOCRFallback but skip internal security scope)
        let textExtractor = PDFTextExtractor()
        let extraction = try await textExtractor.extractText(from: pdfURL, useOCRFallback: true)

        Log.info("Text extraction complete", category: .import, metadata: [
            "file": pdfURL.lastPathComponent,
            "total_chars": extraction.totalCharCount,
            "native_pages": extraction.nativeCount,
            "ocr_pages": extraction.ocrCount
        ])

        // Update progress
        totalPagesProcessed += extraction.pages.count
        job.phaseProgress = Double(totalPagesProcessed) / Double(totalPagesAcrossAllPDFs)
        try? context.save()

        // Step 2: Analyze text to find recipe boundaries
        let aiService = ServiceContainer.shared.resolve(AIServiceProtocol.self)
        let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
        let configuration = ServiceContainer.shared.resolve(AIConfigurationProtocol.self)

        let batchAnalyzer = CookbookBatchAnalyzer(
            aiService: aiService,
            analytics: analytics,
            configuration: configuration
        )

        let analysisResult = try await batchAnalyzer.analyzeAndExtract(
            from: extraction,
            detailedProgressCallback: { [weak job] progress in
                guard let job = job else { return }
                // Update phaseProgress based on detection/extraction phase
                // Detection = first 30% of analysis, Extraction = remaining 70%
                if progress.phase == "detecting" {
                    let detectionProgress = Double(progress.current) / Double(max(progress.total, 1))
                    job.phaseProgress = detectionProgress * 0.3
                } else {
                    let extractionProgress = Double(progress.current) / Double(max(progress.total, 1))
                    job.phaseProgress = 0.3 + (extractionProgress * 0.7)
                }
                try? context.save()
            }
        )

        Log.info("Text batch analysis complete", category: .import, metadata: [
            "file": pdfURL.lastPathComponent,
            "recipes_found": analysisResult.recipeCount,
            "multi_page_count": analysisResult.multiPageCount
        ])

        // Step 3: Extract images for each recipe
        let imageCropper = RecipeImageCropper()
        let imageResults = try await imageCropper.extractImagesForRecipes(
            boundaries: analysisResult.boundaries,
            pdfURL: pdfURL
        )

        // Step 4: Create ImportItems for each recipe
        for (index, boundary) in analysisResult.boundaries.enumerated() {
            // Get the extracted recipe data
            let extractedRecipe = index < analysisResult.extractedRecipes.count
                ? analysisResult.extractedRecipes[index]
                : nil

            // Get the image result
            let imageResult = imageResults.first { $0.recipeTitle == boundary.title }

            // Get image data from cropped food image or first page
            let imageData: Data
            if let croppedImage = imageResult?.croppedImage,
               let data = croppedImage.jpegData(compressionQuality: 0.9) {
                imageData = data
            } else if let firstPageImage = imageResult?.pageImages.first,
                      let data = firstPageImage.jpegData(compressionQuality: 0.9) {
                imageData = data
            } else {
                // Fallback: create a placeholder 1x1 transparent image
                imageData = Data()
            }

            let item = ImportItem(
                source: .pdf,
                imageData: imageData,
                pageNumber: boundary.startPage,
                totalPages: boundary.endPage - boundary.startPage + 1,
                isMultiPageRecipe: boundary.isMultiPage
            )

            // Store pre-extracted recipe data to skip Vision API extraction later
            if let recipe = extractedRecipe {
                item.preExtractedTitle = recipe.title
                item.preExtractedIngredients = recipe.ingredients
                item.preExtractedInstructions = recipe.instructions
                item.preExtractedServings = recipe.servings
                item.preExtractedPrepTime = recipe.prepTime
                item.preExtractedCookTime = recipe.cookTime
                item.preExtractedNotes = recipe.notes
            }

            // Apply cookbook metadata
            item.cookbookTitle = cookbookMetadata?.title
            item.cookbookAuthor = cookbookMetadata?.author

            item.job = job
            context.insert(item)

            // Create placeholder recipe for progressive enhancement (immediate UI feedback)
            createPlaceholderRecipe(for: item, job: job, context: context)

            items.append(item)

            Log.info("Created import item from text extraction", category: .import, metadata: [
                "file": pdfURL.lastPathComponent,
                "title": boundary.title,
                "pages": "\(boundary.startPage)-\(boundary.endPage)",
                "has_pre_extracted": extractedRecipe != nil,
                "placeholder_id": item.placeholderRecipeID?.uuidString ?? "none"
            ])
        }

        try context.save()
        return items
    }

    // MARK: - Scanned PDF Processing (Vision Path)

    /// Process a scanned/mixed PDF using Vision API (slower but necessary for images)
    private func processScannedPDF(
        pdfURL: URL,
        cookbookMetadata: CookbookMetadata?,
        job: ImportJob,
        context: ModelContext,
        totalPagesAcrossAllPDFs: Int,
        pagesAlreadyProcessed: Int
    ) async throws -> [ImportItem] {
        var items: [ImportItem] = []
        var localPagesProcessed = pagesAlreadyProcessed

        let pdfProcessor = ServiceContainer.shared.resolve(PDFProcessor.self)

        // Process PDF in batches to avoid loading all pages into memory
        try await pdfProcessor.renderPDFPagesInBatches(
            from: pdfURL,
            batchSize: 3
        ) { [self] batch in
            // Analyze this batch and maintain state
            try await self.multiPageAnalyzer.processBatch(
                batch,
                progressCallback: { currentPage in
                    Task { @MainActor in
                        localPagesProcessed += 1
                        job.phaseProgress = Double(localPagesProcessed) / Double(totalPagesAcrossAllPDFs)

                        // Save checkpoint after each page analyzed
                        job.checkpoint?.addCompletedPage(currentPage)
                        try? context.save()
                    }
                }
            )
        }

        // Finalize groups after all batches are processed
        let recipeGroups = multiPageAnalyzer.finalizeGroups()

        Log.info("Vision analysis complete", category: .import, metadata: [
            "file": pdfURL.lastPathComponent,
            "recipe_groups": recipeGroups.count,
            "multi_page_recipes": recipeGroups.filter { $0.isMultiPage }.count
        ])

        // Create ImportItems in batches
        let groupBatches = recipeGroups.chunked(into: 5)

        for groupBatch in groupBatches {
            for group in groupBatch {
                let combinedImage = group.pageCount == 1 ? group.pages[0] : group.combinedImage()
                guard let imageData = combinedImage.jpegData(compressionQuality: 0.9) else {
                    continue
                }

                let item = ImportItem(
                    source: .pdf,
                    imageData: imageData,
                    pageNumber: group.startPage,
                    totalPages: group.pageCount,
                    isMultiPageRecipe: group.isMultiPage
                )

                item.cookbookTitle = cookbookMetadata?.title
                item.cookbookAuthor = cookbookMetadata?.author

                item.job = job
                context.insert(item)

                // Create placeholder recipe for progressive enhancement (immediate UI feedback)
                createPlaceholderRecipe(for: item, job: job, context: context)

                items.append(item)
            }

            try context.save()
            await Task.yield()
        }

        return items
    }

    /// Create a new import job from camera captures
    /// - Parameters:
    ///   - images: Array of captured images
    ///   - context: SwiftData ModelContext for persistence
    /// - Returns: The created ImportJob
    func createCameraImportJob(
        images: [UIImage],
        collectionName: String? = nil,
        collectionType: CollectionType? = nil,
        context: ModelContext
    ) async throws -> ImportJob {
        let job = ImportJob(
            jobName: "Camera Scan",
            continueOnError: true
        )
        job.status = .processing  // Set to processing immediately so banner shows it
        job.totalItems = images.count
        job.cookbookName = collectionName
        job.collectionType = collectionType
        Log.info("Created camera import job", category: .import, metadata: [
            "jobId": job.id.uuidString,
            "cookbookName": collectionName ?? "nil",
            "collectionType": collectionType?.rawValue ?? "nil"
        ])
        context.insert(job)

        for image in images {
            guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                continue
            }

            let item = ImportItem(
                source: .camera,
                imageData: imageData
            )
            item.job = job
            context.insert(item)

            // Create placeholder recipe for progressive enhancement (immediate UI feedback)
            createPlaceholderRecipe(for: item, job: job, context: context)
        }

        try context.save()
        return job
    }

    /// Create a new import job from photo library selections
    /// - Parameters:
    ///   - images: Array of selected images
    ///   - context: SwiftData ModelContext for persistence
    /// - Returns: The created ImportJob
    func createPhotoLibraryImportJob(
        images: [UIImage],
        collectionName: String? = nil,
        collectionType: CollectionType? = nil,
        context: ModelContext
    ) async throws -> ImportJob {
        let job = ImportJob(
            jobName: "Photo Library Import",
            continueOnError: true
        )
        job.status = .processing  // Set to processing immediately so banner shows it
        job.totalItems = images.count
        job.cookbookName = collectionName
        job.collectionType = collectionType
        context.insert(job)

        for image in images {
            guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                continue
            }

            let item = ImportItem(
                source: .photoLibrary,
                imageData: imageData
            )
            item.job = job
            context.insert(item)

            // Create placeholder recipe for progressive enhancement (immediate UI feedback)
            createPlaceholderRecipe(for: item, job: job, context: context)
        }

        try context.save()
        return job
    }

    // MARK: - Job Processing

    /// Start processing an import job
    /// - Parameters:
    ///   - job: The ImportJob to process
    ///   - context: SwiftData ModelContext for persistence
    func startJob(_ job: ImportJob, context: ModelContext) async throws {
        guard !isProcessing else {
            throw ImportJobError.alreadyProcessing
        }

        // Clear any stale completed job before starting new one
        // This prevents UI from briefly showing old completion screen
        if let oldJob = activeJob, oldJob.isComplete {
            Log.info("Clearing completed job before starting new one", category: .import, metadata: [
                "old_job_id": oldJob.id.uuidString,
                "new_job_id": job.id.uuidString
            ])
            activeJob = nil
            activeContext = nil
        }

        activeJob = job
        activeContext = context // Store context for background saves
        isProcessing = true
        job.status = .processing

        // Create checkpoint if doesn't exist
        if job.checkpoint == nil {
            let checkpoint = PDFImportCheckpoint()
            checkpoint.job = job
            context.insert(checkpoint)
            job.checkpoint = checkpoint
        }

        // Clear interrupted flag (user manually started)
        job.wasInterrupted = false
        job.checkpoint?.clearInterruptedFlag()

        try context.save()

        // Get pending items
        guard let items = job.items?.filter({ $0.status == .pending }) else {
            await completeJob(job, context: context)
            return
        }

        // Create and track the main processing task
        let processingTask = Task { @MainActor in
            // PHASE 1: Validation (quick - mostly already done in PDFImportView)
            job.phase = .validation
            job.phaseProgress = 1.0 // Complete instantly (validation already done)
            try? context.save()

            // Check for cancellation
            guard !Task.isCancelled else {
                Log.info("Job cancelled during validation phase", category: .import)
                return
            }

            // PHASE 2: Analysis (extract food images from PDF pages)
            job.phase = .analysis
            job.phaseProgress = 0.0
            try? context.save()

            await analyzeAndExtractImages(job: job, items: items, context: context)

            // Check for cancellation
            guard !Task.isCancelled else {
                Log.info("Job cancelled during analysis phase", category: .import)
                return
            }

            job.phaseProgress = 1.0
            try? context.save()

            // PHASE 3: Extraction (AI recipe extraction)
            job.phase = .extraction
            job.phaseProgress = 0.0
            try? context.save()

            // Check for cancellation
            guard !Task.isCancelled else {
                Log.info("Job cancelled before extraction phase", category: .import)
                return
            }

            // Process items with concurrency control
            await withTaskGroup(of: Void.self) { group in
                var activeCount = 0

                for item in items {
                    // Check for cancellation before processing next item
                    guard !Task.isCancelled else {
                        Log.info("Job cancelled during extraction phase", category: .import)
                        return
                    }

                    // Wait if at max concurrent imports
                    while activeCount >= maxConcurrentImports {
                        await group.next()
                        activeCount -= 1
                    }

                    // Wait for rate limit
                    await waitForRateLimit()

                    // Start import task
                    activeCount += 1
                    group.addTask { @MainActor in
                        await self.processItem(item, job: job, context: context)
                    }
                }

                // Wait for all tasks to complete
                await group.waitForAll()
            }

            // Check for cancellation
            guard !Task.isCancelled else {
                Log.info("Job cancelled after extraction phase", category: .import)
                return
            }

            // PHASE 4: AI Image Generation (if enabled)
            if job.shouldGenerateAIImages {
                job.phase = .imageGeneration
                job.phaseProgress = 0.0
                try? context.save()

                await self.generateAIImagesForJob(job: job, context: context)

                // Check for cancellation
                guard !Task.isCancelled else {
                    Log.info("Job cancelled during image generation phase", category: .import)
                    return
                }
            }

            // Only complete job if not cancelled
            if !Task.isCancelled {
                await completeJob(job, context: context)
            }
        }

        // Store the task so it can be cancelled
        currentTasks[job.id] = processingTask

        // Wait for the task to complete
        await processingTask.value
    }

    /// Pause the current job
    func pauseJob(_ job: ImportJob, context: ModelContext) throws {
        guard job.status == .processing else { return }

        job.status = .paused
        isProcessing = false
        activeJob = nil
        activeContext = nil // Clear stored context

        // Cancel active tasks
        currentTasks.values.forEach { $0.cancel() }
        currentTasks.removeAll()

        try context.save()
    }

    /// Resume a paused job
    func resumeJob(_ job: ImportJob, context: ModelContext) async throws {
        guard job.status == .paused else { return }

        try await startJob(job, context: context)
    }

    /// Resume an interrupted job from checkpoint
    func resumeInterruptedJob(_ job: ImportJob, context: ModelContext) async throws {
        guard job.canResume else {
            throw ImportJobError.cannotResume
        }

        Log.info("Resuming interrupted import", category: .import, metadata: [
            "job_id": job.id.uuidString,
            "phase": job.checkpoint?.resumePhase.rawValue ?? "unknown",
            "completed_pages": job.checkpoint?.analyzedPageNumbers.count ?? 0,
            "completed_recipes": job.checkpoint?.lastExtractedItemIndex ?? -1
        ])

        let resumePhase = job.checkpoint?.resumePhase ?? .extraction

        // Clear interrupted flags
        job.wasInterrupted = false
        job.checkpoint?.clearInterruptedFlag()
        job.status = .processing
        activeJob = job
        isProcessing = true
        try context.save()

        switch resumePhase {
        case .analysis:
            try await resumePageAnalysis(job: job, context: context)
        case .extraction:
            try await resumeRecipeExtraction(job: job, context: context)
        default:
            // If interrupted during validation or already completed, just continue normally
            try await startJob(job, context: context)
        }
    }

    /// Resume page analysis phase, skipping completed pages
    private func resumePageAnalysis(job: ImportJob, context: ModelContext) async throws {
        guard let pdfURLString = job.pdfURL,
              let pdfURL = URL(string: pdfURLString) else {
            throw ImportJobError.missingPDFURL
        }

        // Check file exists
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw ImportJobError.pdfFileNotFound
        }

        let completedPages = job.checkpoint?.completedPagesSet() ?? Set<Int>()

        job.phase = .analysis
        job.status = .processing

        Log.info("Resuming page analysis", category: .import, metadata: [
            "pdf_url": pdfURLString,
            "completed_pages": completedPages.count,
            "skipping": Array(completedPages).sorted()
        ])

        // Resume batch processing, skipping completed pages
        let pdfProcessor = ServiceContainer.shared.resolve(PDFProcessor.self)
        var totalPagesProcessed = completedPages.count
        var totalPagesAcrossAllPDFs = 0

        // Count total pages
        if let pdfDocument = PDFDocument(url: pdfURL) {
            totalPagesAcrossAllPDFs = pdfDocument.pageCount
        }

        try await pdfProcessor.renderPDFPagesInBatches(from: pdfURL, batchSize: 3) { [self] batch in
            // Filter out already-analyzed pages
            let pendingPages = batch.filter { !completedPages.contains($0.pageNumber) }

            guard !pendingPages.isEmpty else {
                Log.debug("Skipping already-analyzed batch", category: .import)
                return
            }

            Log.info("Processing pending batch", category: .import, metadata: [
                "pending_count": pendingPages.count,
                "skipped_count": batch.count - pendingPages.count
            ])

            try await self.multiPageAnalyzer.processBatch(
                pendingPages,
                progressCallback: { currentPage in
                    Task { @MainActor in
                        totalPagesProcessed += 1
                        job.phaseProgress = Double(totalPagesProcessed) / Double(totalPagesAcrossAllPDFs)

                        // Save checkpoint after each page analyzed
                        job.checkpoint?.addCompletedPage(currentPage)
                        try? context.save()
                    }
                }
            )
        }

        // Finalize groups and create ImportItems
        let recipeGroups = multiPageAnalyzer.finalizeGroups()

        Log.info("Resume: Creating import items", category: .import, metadata: [
            "recipe_groups": recipeGroups.count
        ])

        // Create ImportItems (similar to createAndAnalyzePDFJob)
        for group in recipeGroups {
            let combinedImage = group.pageCount == 1 ? group.pages[0] : group.combinedImage()
            guard let imageData = combinedImage.jpegData(compressionQuality: 0.9) else {
                continue
            }

            let item = ImportItem(
                source: .pdf,
                imageData: imageData,
                pageNumber: group.startPage,
                totalPages: group.pageCount,
                isMultiPageRecipe: group.isMultiPage
            )

            item.job = job
            context.insert(item)

            // Create placeholder recipe for progressive enhancement (immediate UI feedback)
            createPlaceholderRecipe(for: item, job: job, context: context)
        }

        job.items = job.items ?? []
        job.totalItems = job.items?.count ?? 0
        job.phaseProgress = 1.0
        try context.save()

        // Transition to extraction phase
        try await resumeRecipeExtraction(job: job, context: context)
    }

    /// Resume recipe extraction phase, skipping completed recipes
    private func resumeRecipeExtraction(job: ImportJob, context: ModelContext) async throws {
        job.phase = .extraction
        job.status = .processing

        // Get only pending items (not yet processed)
        guard let allItems = job.items, !allItems.isEmpty else {
            // No items exist yet - job was interrupted during analysis phase
            // Fall back to resuming page analysis to create items
            Log.info("No items found - falling back to analysis phase", category: .import, metadata: [
                "job_id": job.id.uuidString
            ])
            try await resumePageAnalysis(job: job, context: context)
            return
        }

        let pendingItems = allItems.filter { $0.status == .pending && !$0.wasCheckpointed }

        guard !pendingItems.isEmpty else {
            // All items already processed - complete the job
            Log.info("All items already processed - completing job", category: .import, metadata: [
                "total_items": job.totalItems,
                "successful_items": job.successfulItems
            ])
            await completeJob(job, context: context)
            return
        }

        Log.info("Resuming recipe extraction", category: .import, metadata: [
            "pending_items": pendingItems.count,
            "total_items": job.totalItems,
            "already_successful": job.successfulItems
        ])

        // Process remaining items (use existing concurrent logic)
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0

            for item in pendingItems {
                // Wait if at max concurrent imports
                while activeCount >= maxConcurrentImports {
                    await group.next()
                    activeCount -= 1
                }

                // Wait for rate limit
                await waitForRateLimit()

                // Start import task
                activeCount += 1
                group.addTask { @MainActor in
                    await self.processItem(item, job: job, context: context)
                }
            }

            // Wait for all tasks to complete
            await group.waitForAll()
        }

        // PHASE 4: AI Image Generation (if enabled) - same as normal flow
        if job.shouldGenerateAIImages {
            job.phase = .imageGeneration
            job.phaseProgress = 0.0
            try? context.save()

            Log.info("Running AI image generation after resume", category: .import, metadata: [
                "job_id": job.id.uuidString
            ])

            await generateAIImagesForJob(job: job, context: context)
        }

        await completeJob(job, context: context)
    }

    /// Retry failed items in a job
    func retryFailedItems(_ job: ImportJob, context: ModelContext) async throws {
        guard let failedItems = job.items?.filter({ $0.status == .failed && $0.canRetry }) else {
            return
        }

        // Reset failed items to pending
        failedItems.forEach { item in
            item.incrementRetry()
        }

        job.status = .processing
        try context.save()

        try await startJob(job, context: context)
    }

    // MARK: - Analysis Phase

    /// Placeholder for analysis phase (currently minimal since analysis happens in PDFImportView)
    /// In the future, this could include additional preprocessing steps
    private func analyzeAndExtractImages(job: ImportJob, items: [ImportItem], context: ModelContext) async {
        // Analysis phase is currently very quick since page boundary detection
        // already happened in PDFImportView before creating the job.
        // Image extraction will happen during processItem for each recipe.

        Log.info("Analysis phase (placeholder)", category: .import, metadata: [
            "item_count": items.count
        ])

        // Simulate brief analysis delay for UX purposes
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }

    // MARK: - Placeholder Management (Progressive Enhancement)

    /// Create a placeholder recipe for an ImportItem for immediate UI feedback
    /// The placeholder appears in the recipe list with "Processing..." status while extraction happens
    private func createPlaceholderRecipe(
        for item: ImportItem,
        job: ImportJob,
        context: ModelContext
    ) {
        let placeholder = Recipe.createImportPlaceholder(
            jobId: job.id,
            itemIndex: item.pageNumber ?? 0,
            cookbookName: job.cookbookName
        )

        // Store thumbnail/source image if available
        if let imageData = item.imageData,
           let image = UIImage(data: imageData) {
            Task {
                let imageService = ServiceContainer.shared.resolve(ImageStorageService.self)
                if let fileName = try? await imageService.saveImage(image, recipeId: placeholder.id) {
                    await MainActor.run {
                        placeholder.imageFileName = fileName
                    }
                }
            }
        }

        context.insert(placeholder)
        item.placeholderRecipeID = placeholder.id

        Log.info("Created placeholder recipe", category: .import, metadata: [
            "placeholder_id": placeholder.id.uuidString,
            "item_id": item.id.uuidString,
            "page_number": item.pageNumber ?? -1
        ])
    }

    /// Update a placeholder recipe with extracted data
    private func updatePlaceholderWithExtraction(
        _ placeholder: Recipe,
        from extractedRecipe: Recipe,
        item: ImportItem
    ) {
        // Transfer all data from extracted recipe to placeholder
        placeholder.title = extractedRecipe.title
        placeholder.instructions = extractedRecipe.instructions
        placeholder.servings = extractedRecipe.servings
        placeholder.prepTime = extractedRecipe.prepTime
        placeholder.cookTime = extractedRecipe.cookTime
        placeholder.notes = extractedRecipe.notes
        placeholder.sourceType = extractedRecipe.sourceType
        placeholder.sourceURL = extractedRecipe.sourceURL
        placeholder.sourceBookTitle = extractedRecipe.sourceBookTitle ?? item.cookbookTitle
        placeholder.sourceBookAuthor = extractedRecipe.sourceBookAuthor ?? item.cookbookAuthor

        // Transfer ingredients
        if let extractedIngredients = extractedRecipe.ingredients {
            for ingredient in extractedIngredients {
                ingredient.recipe = placeholder
            }
            placeholder.ingredients = extractedIngredients
        }

        // Transfer image if extracted recipe has one
        if let imageFileName = extractedRecipe.imageFileName, placeholder.imageFileName == nil {
            placeholder.imageFileName = imageFileName
        }

        // Mark as complete
        placeholder.processingStatus = .ready
        placeholder.processingProgress = 1.0
        placeholder.processingErrorMessage = nil

        Log.info("Updated placeholder with extraction", category: .import, metadata: [
            "placeholder_id": placeholder.id.uuidString,
            "title": placeholder.title
        ])
    }

    /// Mark a placeholder recipe as failed
    private func markPlaceholderFailed(
        _ placeholder: Recipe,
        errorMessage: String
    ) {
        placeholder.processingStatus = .failed
        placeholder.processingErrorMessage = errorMessage

        Log.info("Marked placeholder as failed", category: .import, metadata: [
            "placeholder_id": placeholder.id.uuidString,
            "error": errorMessage
        ])
    }

    /// Find placeholder recipe for an ImportItem
    private func findPlaceholder(for item: ImportItem, context: ModelContext) -> Recipe? {
        guard let placeholderID = item.placeholderRecipeID else { return nil }

        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { $0.id == placeholderID }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: - Item Processing

    private func processItem(_ item: ImportItem, job: ImportJob, context: ModelContext) async {
        Log.info("🚀 Starting processItem", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "job_id": job.id.uuidString,
            "source": item.source.rawValue,
            "has_image_data": item.imageData != nil,
            "image_data_size_kb": (item.imageData?.count ?? 0) / 1024,
            "has_placeholder": item.placeholderRecipeID != nil
        ])

        // Find placeholder recipe if it exists (created during analysis phase)
        let placeholder = findPlaceholder(for: item, context: context)

        // Update placeholder progress if exists
        if let placeholder = placeholder {
            placeholder.processingProgress = 0.1  // Show some progress
            try? context.save()
        }

        // Mark as processing
        item.startProcessing()
        try? context.save()

        do {
            // Process based on source type - note that camera/photoLibrary may return multiple recipes
            var recipes: [Recipe] = []

            switch item.source {
            case .url:
                Log.info("🌐 Processing URL import", category: .import, metadata: [
                    "item_id": item.id.uuidString
                ])
                let recipe = try await processURLImport(item)
                recipes = [recipe]

            case .pdf:
                Log.info("📄 Processing PDF page", category: .import, metadata: [
                    "item_id": item.id.uuidString,
                    "page_number": item.pageNumber ?? -1
                ])
                // PDF pages can contain multiple recipes
                recipes = try await processPDFPage(item)

            case .camera, .photoLibrary:
                Log.info("📸 Processing camera/photo import", category: .import, metadata: [
                    "item_id": item.id.uuidString,
                    "source": item.source.rawValue
                ])
                // Camera/photo imports can return multiple recipes from one image
                recipes = try await processImageImport(item)
            }

            Log.info("✅ Source-specific processing completed", category: .import, metadata: [
                "item_id": item.id.uuidString,
                "recipe_count": recipes.count
            ])

            // Apply cookbook metadata and source tracking to all recipes
            let duplicateDetectionService = ServiceContainer.shared.resolve(DuplicateDetectionService.self)
            var recipesToInsert: [Recipe] = []
            var skippedDuplicates: [(Recipe, [DuplicateDetectionService.DuplicateMatch])] = []

            for (index, recipe) in recipes.enumerated() {
                // Cookbook metadata
                if let cookbookTitle = item.cookbookTitle {
                    recipe.sourceBookTitle = cookbookTitle
                }
                if let cookbookAuthor = item.cookbookAuthor {
                    recipe.sourceBookAuthor = cookbookAuthor
                }

                // Multi-recipe source tracking
                recipe.sourceImportItemID = item.id
                recipe.sourceRecipeIndex = index

                // Check for duplicates before inserting
                do {
                    let duplicates = try duplicateDetectionService.findDuplicates(
                        for: recipe,
                        in: context,
                        threshold: 0.85 // High threshold to avoid false positives
                    )

                    if !duplicates.isEmpty {
                        // Found potential duplicate(s)
                        let exactMatches = duplicates.filter { $0.matchType == .exactHash }
                        let nearPerfectMatches = duplicates.filter { $0.similarityScore >= 0.95 }

                        if !exactMatches.isEmpty {
                            // Exact duplicate (content hash match) - skip insertion
                            Log.warning("⚠️ Skipping exact duplicate recipe", category: .import, metadata: [
                                "title": recipe.title,
                                "content_hash": recipe.contentHash ?? "none",
                                "duplicate_id": exactMatches[0].recipe.id.uuidString,
                                "duplicate_title": exactMatches[0].recipe.title
                            ])
                            skippedDuplicates.append((recipe, duplicates))
                            continue
                        } else if !nearPerfectMatches.isEmpty {
                            // Near-perfect title/content match (>=0.95 similarity) - skip insertion
                            Log.warning("⚠️ Skipping near-identical duplicate recipe", category: .import, metadata: [
                                "title": recipe.title,
                                "similarity_score": nearPerfectMatches[0].similarityScore,
                                "match_type": "\(nearPerfectMatches[0].matchType)",
                                "duplicate_id": nearPerfectMatches[0].recipe.id.uuidString,
                                "duplicate_title": nearPerfectMatches[0].recipe.title
                            ])
                            skippedDuplicates.append((recipe, duplicates))
                            continue
                        } else {
                            // Similar but not near-identical - insert with warning
                            Log.info("ℹ️ Recipe similar to existing recipe (inserting anyway)", category: .import, metadata: [
                                "title": recipe.title,
                                "similarity_score": duplicates[0].similarityScore,
                                "match_type": "\(duplicates[0].matchType)",
                                "similar_to": duplicates[0].recipe.title
                            ])
                        }
                    }

                    // No exact duplicates - proceed with insertion or placeholder update
                    if index == 0, let placeholder = placeholder {
                        // First recipe uses the placeholder (progressive enhancement)
                        updatePlaceholderWithExtraction(placeholder, from: recipe, item: item)
                        recipesToInsert.append(placeholder)
                        // Transfer ingredients to placeholder's context
                        if let ingredients = recipe.ingredients {
                            for ingredient in ingredients {
                                context.insert(ingredient)
                            }
                        }
                        Log.info("✅ Updated placeholder with first recipe", category: .import, metadata: [
                            "placeholder_id": placeholder.id.uuidString,
                            "title": recipe.title
                        ])
                    } else {
                        // Additional recipes get inserted normally
                        recipesToInsert.append(recipe)
                        context.insert(recipe)
                    }
                } catch {
                    // Duplicate detection failed - insert anyway (don't block import)
                    Log.warning("⚠️ Duplicate detection failed, inserting recipe anyway", category: .import, metadata: [
                        "title": recipe.title,
                        "error": error.localizedDescription
                    ])
                    if index == 0, let placeholder = placeholder {
                        // Use placeholder even if duplicate detection failed
                        updatePlaceholderWithExtraction(placeholder, from: recipe, item: item)
                        recipesToInsert.append(placeholder)
                        if let ingredients = recipe.ingredients {
                            for ingredient in ingredients {
                                context.insert(ingredient)
                            }
                        }
                    } else {
                        recipesToInsert.append(recipe)
                        context.insert(recipe)
                    }
                }
            }

            // Update recipes list to only include inserted recipes
            recipes = recipesToInsert

            // Log if duplicates were skipped
            if !skippedDuplicates.isEmpty {
                Log.info("📋 Skipped duplicate recipes", category: .import, metadata: [
                    "count": skippedDuplicates.count,
                    "skipped_titles": skippedDuplicates.map { $0.0.title }.joined(separator: " | "),
                    "original_count": recipes.count + skippedDuplicates.count,
                    "inserted_count": recipes.count
                ])
            }

            // Handle case where all recipes were duplicates
            guard !recipes.isEmpty else {
                // If we have skipped duplicates, this is a successful extraction
                // (the recipes were found, just already exist in the database)
                if !skippedDuplicates.isEmpty {
                    // Get the existing recipe IDs from the duplicates
                    let existingRecipeIDs = skippedDuplicates.compactMap { $0.1.first?.recipe.id }

                    // Delete placeholder since all recipes were duplicates
                    if let placeholder = placeholder {
                        context.delete(placeholder)
                        Log.info("Deleted placeholder - all recipes were duplicates", category: .import, metadata: [
                            "placeholder_id": placeholder.id.uuidString
                        ])
                    }

                    // Mark as successful with the existing recipe IDs
                    item.markSuccess(recipeIDs: existingRecipeIDs)

                    Log.info("✅ All recipes were duplicates (extraction succeeded)", category: .import, metadata: [
                        "item_id": item.id.uuidString,
                        "duplicate_count": skippedDuplicates.count,
                        "duplicate_titles": skippedDuplicates.map { $0.0.title }.joined(separator: " | ")
                    ])

                    // Update job progress
                    job.updateProgress(success: true)
                    item.wasCheckpointed = true

                    // Update checkpoint
                    if let items = job.items,
                       let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
                        job.checkpoint?.updateExtractionProgress(itemIndex: itemIndex)

                        Log.info("Checkpointed duplicate recipe", category: .import, metadata: [
                            "recipe_index": itemIndex,
                            "total_completed": job.successfulItems
                        ])
                    }

                    // Return early - this is a successful extraction (duplicates)
                    return
                }

                // No recipes extracted and no duplicates - genuine failure
                // Mark placeholder as failed before throwing
                if let placeholder = placeholder {
                    markPlaceholderFailed(placeholder, errorMessage: "No recipe could be extracted")
                }
                throw ImportJobError.noRecipeFound
            }

            // Save source image for all recipes if available
            if let imageData = item.imageData,
               let sourceImage = UIImage(data: imageData) {
                let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)

                for recipe in recipes {
                    do {
                        let fileName = try await imageStorageService.saveImage(
                            sourceImage,
                            recipeId: recipe.id
                        )
                        await MainActor.run {
                            recipe.imageFileName = fileName
                            Log.info("Saved recipe image from bulk import", category: .import, metadata: [
                                "recipeId": recipe.id.uuidString,
                                "fileName": fileName,
                                "source": item.source.rawValue
                            ])
                        }
                    } catch {
                        Log.warning("Failed to save image for bulk import recipe", category: .import, metadata: [
                            "recipeId": recipe.id.uuidString,
                            "error": error.localizedDescription
                        ])
                    }
                }
            }

            // Create snapshots for edit tracking
            for recipe in recipes {
                recipe.createSnapshot()
            }

            try context.save()

            // Sync all recipes to Firebase if active
            if backendConfig.isFirebaseActive {
                for recipe in recipes {
                    do {
                        try await firebaseSync.uploadRecipe(recipe)
                        Log.info("Bulk import recipe synced to Firebase", category: .firebase, metadata: ["title": recipe.title, "source": item.source.rawValue])
                    } catch {
                        Log.warning("Failed to sync bulk import recipe to Firebase", category: .firebase, metadata: ["error": error.localizedDescription, "title": recipe.title])
                        // Continue with next recipe
                    }
                }
            }

            // Collect all recipe IDs
            let recipeIDs = recipes.map { $0.id }

            // Update extraction results with actual recipe IDs
            for (index, recipeID) in recipeIDs.enumerated() {
                if index < item.extractionResults.count {
                    item.extractionResults[index].recipeID = recipeID
                }
            }

            // Mark item based on extraction success rate
            if let detectedCount = item.detectedRecipeCount, detectedCount > recipeIDs.count {
                // Partial success (some recipes failed)
                item.markPartialSuccess(recipeIDs: recipeIDs)

                Log.warning("⚠️ Partial import success", category: .import, metadata: [
                    "item_id": item.id.uuidString,
                    "successful": recipeIDs.count,
                    "failed": detectedCount - recipeIDs.count,
                    "successful_titles": recipes.map { $0.title }.joined(separator: " | ")
                ])
            } else {
                // Full success (all detected recipes extracted)
                item.markSuccess(recipeIDs: recipeIDs)

                if recipes.count > 1 {
                    Log.info("✨ Multiple recipes extracted from single import item", category: .import, metadata: [
                        "item_id": item.id.uuidString,
                        "recipe_count": recipes.count,
                        "titles": recipes.map { $0.title }.joined(separator: " | ")
                    ])
                }
            }

            // Update job progress
            // Note: We increment by 1 per item, even if multiple recipes extracted
            job.updateProgress(success: true)
            item.wasCheckpointed = true

            // Update checkpoint with recipe index (using primary recipe)
            if let items = job.items,
               let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
                job.checkpoint?.updateExtractionProgress(itemIndex: itemIndex)

                Log.info("Checkpointed recipe(s)", category: .import, metadata: [
                    "recipe_index": itemIndex,
                    "total_completed": job.successfulItems,
                    "recipe_count": recipes.count,
                    "recipe_ids": recipeIDs.map { $0.uuidString }.joined(separator: ", ")
                ])
            }

            try context.save()

        } catch {
            // Mark item as failed
            item.markFailed(error: error.localizedDescription)
            job.updateProgress(success: false)

            // Mark placeholder as failed (if not already marked in the noRecipeFound case)
            if let placeholder = placeholder, placeholder.processingStatus != .failed {
                markPlaceholderFailed(placeholder, errorMessage: error.localizedDescription)
            }

            // Log detailed error information for debugging
            Log.error("❌ RECIPE EXTRACTION FAILED", category: .import, metadata: [
                "job_id": job.id.uuidString,
                "item_id": item.id.uuidString,
                "source": item.source.rawValue,
                "page_number": item.pageNumber ?? -1,
                "pdf_url": item.pdfURL ?? "unknown",
                "error_message": error.localizedDescription,
                "error_type": "\(type(of: error))",
                "is_multi_page": item.isMultiPageRecipe ?? false,
                "total_pages": item.totalPages ?? 0,
                "retry_count": item.retryCount,
                "has_placeholder": placeholder != nil
            ])

            try? context.save()

            // Stop job if not continuing on error
            if !job.continueOnError {
                job.status = .failed
                isProcessing = false
                activeJob = nil
                activeContext = nil // Clear stored context
                // Clear pending signal
                if self.pendingJobId == job.id {
                    self.pendingJobId = nil
                }
            }
        }
    }

    // MARK: - Source-Specific Processing

    /// Process URL-based import (video/recipe URL)
    private func processURLImport(_ item: ImportItem) async throws -> Recipe {
        guard let urlString = item.urlString else {
            throw ImportJobError.missingURLString
        }

        // Import recipe from URL
        let importedRecipe = try await importService.importRecipe(from: urlString)

        // Create Recipe object
        let recipe = Recipe(
            title: importedRecipe.title,
            sourceType: .url,
            sourceURL: urlString,
            instructions: importedRecipe.instructions,
            servings: importedRecipe.servings,
            prepTime: importedRecipe.prepTime,
            cookTime: importedRecipe.cookTime
        )

        // Add ingredients
        for ingredientText in importedRecipe.ingredients {
            let ingredient = Ingredient(
                originalText: ingredientText,
                name: ingredientText,
                quantity: nil,
                unit: nil
            )
            ingredient.recipe = recipe
            recipe.ingredients?.append(ingredient)
        }

        // Download and save recipe image if available
        if let imageURLString = importedRecipe.imageURL,
           let imageURL = URL(string: imageURLString) {
            Log.info("Downloading recipe image", category: .network, metadata: ["url": imageURLString])
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                Log.debug("Downloaded image data", category: .network, metadata: ["bytes": data.count])

                if let image = UIImage(data: data) {
                    Log.debug("Created UIImage from data", category: .storage)
                    let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)
                    let fileName = try await imageStorageService.saveImage(image, recipeId: recipe.id)
                    Log.info("Saved recipe image", category: .storage, metadata: ["fileName": fileName])
                    recipe.imageFileName = fileName
                } else {
                    Log.warning("Failed to create UIImage from downloaded data", category: .storage)
                }
            } catch {
                Log.warning("Failed to download recipe image", category: .network, metadata: ["error": error.localizedDescription])
                // Don't fail the entire import if image download fails
            }
        }

        return recipe
    }

    /// Process PDF page import
    /// - Returns: Array of recipes extracted from the PDF page (may be multiple if page contains multiple recipes)
    private func processPDFPage(_ item: ImportItem) async throws -> [Recipe] {
        // Check if this item has pre-extracted data from text pipeline (FAST PATH)
        if item.hasPreExtractedData {
            Log.info("📄 Using PRE-EXTRACTED data (text pipeline)", category: .import, metadata: [
                "item_id": item.id.uuidString,
                "title": item.preExtractedTitle ?? "nil",
                "page_number": item.pageNumber ?? -1
            ])

            // Create recipe directly from pre-extracted data
            let recipe = createRecipeFromPreExtractedData(item)

            // Still need to parse ingredients for scaling
            await parseIngredientsImmediately(for: recipe)

            // Save image if available
            if let imageData = item.imageData,
               let image = UIImage(data: imageData) {
                await extractFoodImage(from: image, for: recipe)
            }

            Log.info("✅ Recipe created from pre-extracted data", category: .import, metadata: [
                "item_id": item.id.uuidString,
                "title": recipe.title
            ])

            return [recipe]
        }

        // SLOW PATH: Use Vision API for scanned/image-based PDFs
        guard let imageData = item.imageData else {
            throw ImportJobError.missingImageData
        }

        guard let image = UIImage(data: imageData) else {
            throw ImportJobError.invalidImageData
        }

        // Detect recipes in the image
        let detected = try await aiRecipeExtractor.detectRecipes(from: image)

        // Extract recipe(s) from image
        Log.info("📝 Extracting recipes via VISION API", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "detected_count": detected.count
        ])
        let result = try await aiRecipeExtractor.extractRecipesFromImage(
            image: image,
            detectedRecipes: detected
        )

        Log.info("✅ Recipe extraction completed", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "extracted_count": result.recipes.count
        ])

        // Ensure we found at least one recipe
        guard !result.recipes.isEmpty else {
            Log.error("❌ No recipes found in image", category: .import, metadata: [
                "item_id": item.id.uuidString,
                "detected_count": detected.count
            ])
            throw ImportJobError.noRecipeFound
        }

        // Convert ALL detected recipes to Recipe models
        // PDF imports use .cookbook sourceType to prevent public sharing (copyright protection)
        Log.info("🔄 Converting extracted recipes to Recipe models", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "recipe_count": result.recipes.count
        ])
        let recipes = result.recipes.map { extractedRecipe in
            createRecipe(from: extractedRecipe, sourceImage: image, sourceType: .cookbook)
        }

        Log.info("✅ Recipe models created", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "recipe_titles": recipes.map { $0.title }.joined(separator: " | ")
        ])

        // CRITICAL: Parse ingredients immediately to enable automatic scaling
        // This prevents the need for warning symbols and "Fix" buttons
        for recipe in recipes {
            await parseIngredientsImmediately(for: recipe)
        }

        // Extract food images from PDF page for all recipes (if present)
        for recipe in recipes {
            await extractFoodImage(from: image, for: recipe)
        }

        // Log if multiple recipes were detected on PDF page
        if recipes.count > 1 {
            Log.info("Multiple recipes detected on PDF page", category: .import, metadata: [
                "count": recipes.count,
                "page": item.pageNumber ?? -1,
                "titles": recipes.map { $0.title }.joined(separator: ", ")
            ])
        }

        return recipes
    }

    /// Create a Recipe from pre-extracted text pipeline data (skips Vision API)
    /// Uses .cookbook sourceType for PDF imports to prevent public sharing (copyright protection)
    private func createRecipeFromPreExtractedData(_ item: ImportItem) -> Recipe {
        let recipe = Recipe(
            title: item.preExtractedTitle ?? "Untitled Recipe",
            sourceType: .cookbook,
            sourceURL: nil,
            instructions: item.preExtractedInstructions ?? [],
            servings: item.preExtractedServings,
            prepTime: item.preExtractedPrepTime,
            cookTime: item.preExtractedCookTime
        )

        // Add ingredients (filtering out section headers in brackets)
        if let ingredients = item.preExtractedIngredients {
            for ingredientText in ingredients {
                // Skip section headers that are entirely in brackets like [Asparagus], [Main], [Vegetables]
                let trimmed = ingredientText.trimmingCharacters(in: .whitespacesAndNewlines)
                if isBracketedSectionHeader(trimmed) {
                    Log.debug("Skipping bracketed section header in PDF import", category: .import, metadata: ["text": trimmed])
                    continue
                }

                let ingredient = Ingredient(
                    originalText: ingredientText,
                    name: ingredientText,
                    quantity: nil,
                    unit: nil
                )
                ingredient.recipe = recipe
                recipe.ingredients?.append(ingredient)
            }
        }

        // Add notes if present
        if let notes = item.preExtractedNotes, !notes.isEmpty {
            recipe.setNotes(notes)
        }

        // Generate content hash for duplicate detection
        DuplicateDetectionService.updateContentHash(for: recipe)

        return recipe
    }

    /// Process camera/photo library import
    /// - Returns: Array of recipes extracted from the image (may be multiple if image contains multiple recipes)
    private func processImageImport(_ item: ImportItem) async throws -> [Recipe] {
        Log.info("🔍 Starting image import processing", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "source": item.source.rawValue
        ])

        guard let imageData = item.imageData else {
            Log.error("❌ Missing image data for import item", category: .import, metadata: [
                "item_id": item.id.uuidString
            ])
            throw ImportJobError.missingImageData
        }

        guard let image = UIImage(data: imageData) else {
            Log.error("❌ Failed to create UIImage from data", category: .import, metadata: [
                "item_id": item.id.uuidString,
                "data_size_bytes": imageData.count
            ])
            throw ImportJobError.invalidImageData
        }

        Log.info("📸 Image loaded successfully", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "width": image.size.width,
            "height": image.size.height,
            "data_size_kb": imageData.count / 1024
        ])

        // Detect recipes in the image
        Log.info("🔍 Calling AIRecipeExtractor.detectRecipes()", category: .import, metadata: [
            "item_id": item.id.uuidString
        ])
        let detected = try await aiRecipeExtractor.detectRecipes(from: image)

        Log.info("✅ Recipe detection completed", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "detected_count": detected.count
        ])

        // Extract recipe(s) from image
        let result = try await aiRecipeExtractor.extractRecipesFromImage(
            image: image,
            detectedRecipes: detected
        )

        // Store detection and extraction metadata on item
        item.detectedRecipeCount = detected.count
        item.extractionResults = result.extractionResults

        Log.info("📝 Extraction completed", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "detected": detected.count,
            "extracted": result.recipes.count,
            "failed": result.failedCount
        ])

        // Ensure we found at least one recipe
        guard !result.recipes.isEmpty else {
            Log.error("❌ All recipe extractions failed", category: .import, metadata: [
                "item_id": item.id.uuidString,
                "attempted": detected.count,
                "failures": result.extractionResults.map { "\($0.detectedTitle): \($0.errorMessage ?? "unknown")" }.joined(separator: "; ")
            ])
            throw ImportJobError.noRecipeFound
        }

        // Convert ALL successfully extracted recipes to Recipe models
        let sourceType: RecipeSourceType = item.source == .camera ? .scan : .scan
        let recipes = result.recipes.map { extractedRecipe in
            createRecipe(from: extractedRecipe, sourceImage: image, sourceType: sourceType)
        }

        // CRITICAL: Parse ingredients immediately to enable automatic scaling
        // This prevents the need for warning symbols and "Fix" buttons
        for recipe in recipes {
            await parseIngredientsImmediately(for: recipe)
        }

        // Log if multiple recipes were detected
        if recipes.count > 1 {
            Log.info("✨ Multiple recipes extracted from single image", category: .import, metadata: [
                "count": recipes.count,
                "titles": recipes.map { $0.title }.joined(separator: " | "),
                "partial_success": recipes.count < detected.count
            ])
        }

        // Warn if partial failure
        if result.failedCount > 0 {
            Log.warning("⚠️ Partial extraction failure", category: .import, metadata: [
                "successful": recipes.count,
                "failed": result.failedCount,
                "failed_titles": result.extractionResults.filter { !$0.success }.map { $0.detectedTitle }.joined(separator: ", ")
            ])
        }

        return recipes
    }

    /// Convert ExtractedRecipe to Recipe model
    private func createRecipe(
        from extracted: AIRecipeExtractor.ExtractedRecipe,
        sourceImage: UIImage?,
        sourceType: RecipeSourceType
    ) -> Recipe {
        let recipe = Recipe(
            title: extracted.title,
            sourceType: sourceType,
            sourceURL: nil,
            instructions: extracted.instructions,
            servings: extracted.servings,
            prepTime: extracted.prepTime,
            cookTime: extracted.cookTime
        )

        // Add ingredients (filtering out section headers in brackets)
        for ingredientText in extracted.ingredients {
            // Skip section headers that are entirely in brackets like [Asparagus], [Main], [Vegetables]
            let trimmed = ingredientText.trimmingCharacters(in: .whitespacesAndNewlines)
            if isBracketedSectionHeader(trimmed) {
                Log.debug("Skipping bracketed section header in image import", category: .import, metadata: ["text": trimmed])
                continue
            }

            let ingredient = Ingredient(
                originalText: ingredientText,
                name: ingredientText,
                quantity: nil,
                unit: nil
            )
            ingredient.recipe = recipe
            recipe.ingredients?.append(ingredient)
        }

        // Add notes if present
        if let notes = extracted.notes, !notes.isEmpty {
            recipe.setNotes(notes)
        }

        // Generate content hash for duplicate detection
        DuplicateDetectionService.updateContentHash(for: recipe)

        return recipe
    }

    /// Check if text is a bracketed section header like [Asparagus], [Main], [Vegetables]*
    private func isBracketedSectionHeader(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Check for [Text] or [Text]*
        if trimmed.hasPrefix("[") {
            let withoutAsterisk = trimmed.replacingOccurrences(of: "*", with: "")
            if withoutAsterisk.hasSuffix("]") {
                return true
            }
        }
        return false
    }

    /// Parse ingredients immediately to enable automatic scaling
    /// This matches the behavior of web imports and prevents warning symbols
    private func parseIngredientsImmediately(for recipe: Recipe) async {
        guard let ingredients = recipe.ingredients, !ingredients.isEmpty else {
            Log.debug("No ingredients to parse", category: .import, metadata: ["recipeId": recipe.id.uuidString])
            return
        }

        // Extract ingredient texts
        let ingredientTexts = ingredients.map { $0.originalText }

        Log.info("Parsing ingredients immediately for scaling", category: .import, metadata: [
            "recipeId": recipe.id.uuidString,
            "count": ingredientTexts.count
        ])

        do {
            // Get AI ingredient parser from container
            let aiIngredientParser: AIIngredientParser = ServiceContainer.shared.resolve(AIIngredientParser.self)

            // Parse all ingredients
            let parsed = try await aiIngredientParser.parseBatch(ingredientTexts)

            // Update ingredients with parsed data
            for (index, ingredient) in ingredients.enumerated() {
                guard index < parsed.count else { continue }
                let parsedData = parsed[index]
                ingredient.quantity = parsedData.quantity
                ingredient.quantityMax = parsedData.quantityMax
                ingredient.unit = parsedData.unit
                ingredient.normalizedUnit = parsedData.normalizedUnit
                ingredient.name = parsedData.name
                ingredient.preparation = parsedData.preparation
                ingredient.category = parsedData.category
            }

            let withQuantities = ingredients.filter { $0.quantity != nil }.count
            Log.info("Ingredients parsed successfully", category: .import, metadata: [
                "recipeId": recipe.id.uuidString,
                "total": ingredients.count,
                "withQuantities": withQuantities
            ])
        } catch {
            Log.error("Failed to parse ingredients immediately", category: .import, metadata: [
                "recipeId": recipe.id.uuidString,
                "error": error.localizedDescription
            ])
            // Continue without parsed ingredients - they will remain as placeholders
        }
    }

    /// Extract food image from page image using Vision framework
    private func extractFoodImage(from pageImage: UIImage, for recipe: Recipe) async {
        let imageStorage = ServiceContainer.shared.resolve(ImageStorageService.self)
        let imageExtractor = PDFImageExtractor(imageStorage: imageStorage)

        let extracted = await imageExtractor.extractAndSaveImage(
            from: pageImage,
            for: recipe
        )

        if extracted {
            Log.info("Extracted food image for recipe", category: .import, metadata: [
                "recipeId": recipe.id.uuidString,
                "title": recipe.title
            ])
        } else {
            Log.debug("No food image found in page", category: .import, metadata: [
                "recipeId": recipe.id.uuidString
            ])
        }
    }

    // MARK: - AI Image Generation

    /// Delay between image generation requests (in seconds)
    /// Using sequential processing with delay to avoid Replicate rate limits
    private static let imageGenerationDelaySeconds: Double = 3.0

    /// Maximum retry passes for failed images
    /// After first pass, retry failed recipes up to this many additional times
    private static let maxRetryPasses = 2

    /// Delay between retry passes (in seconds)
    private static let retryPassDelaySeconds: Double = 10.0

    /// Generate AI images for all successfully imported recipes in a job
    /// Uses sequential processing with retry passes to handle rate limits
    private func generateAIImagesForJob(job: ImportJob, context: ModelContext) async {
        let imageGenerator = ServiceContainer.shared.resolve((any RecipeImageGeneratorProtocol).self)
        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)

        // Get all successfully imported recipe IDs from this job
        guard let items = job.items else {
            Log.warning("No items found for AI image generation", category: .import)
            return
        }

        let recipeIDs = items.flatMap { $0.recipeIDs }

        guard !recipeIDs.isEmpty else {
            Log.warning("No recipes found for AI image generation", category: .import)
            return
        }

        Log.info("Starting sequential AI image generation for import job", category: .import, metadata: [
            "jobId": job.id.uuidString,
            "recipeCount": recipeIDs.count,
            "delayBetweenImages": Self.imageGenerationDelaySeconds
        ])

        // Fetch recipes from SwiftData
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipeIDs.contains(recipe.id)
            }
        )

        var recipes: [Recipe] = []
        do {
            recipes = try context.fetch(descriptor)
        } catch {
            Log.error("Failed to fetch recipes for AI image generation", category: .import, error: error)
            return
        }

        let totalCount = recipes.count
        let startTime = Date()

        var successCount = 0
        var failedRecipes: [Recipe] = []

        // PASS 1: Process all recipes sequentially
        for (index, recipe) in recipes.enumerated() {
            // Check for cancellation
            guard !Task.isCancelled else {
                Log.info("AI image generation cancelled", category: .import)
                return
            }

            // Delay between requests (except first)
            if index > 0 {
                try? await Task.sleep(nanoseconds: UInt64(Self.imageGenerationDelaySeconds * 1_000_000_000))
            }

            do {
                try await imageGenerator.generateAndSaveImage(for: recipe)
                successCount += 1
                Log.info("Generated AI image for recipe", category: .import, metadata: [
                    "title": recipe.title,
                    "progress": "\(index + 1)/\(totalCount)"
                ])
            } catch {
                failedRecipes.append(recipe)
                Log.error("Failed to generate AI image for recipe", category: .import, error: error, metadata: [
                    "title": recipe.title,
                    "progress": "\(index + 1)/\(totalCount)"
                ])
            }

            // Update progress
            job.phaseProgress = Double(index + 1) / Double(totalCount)
            try? context.save()
        }

        // RETRY PASSES: Retry failed recipes
        var retryPass = 0
        while !failedRecipes.isEmpty && retryPass < Self.maxRetryPasses {
            retryPass += 1

            Log.info("Starting retry pass for failed images", category: .import, metadata: [
                "pass": retryPass,
                "failedCount": failedRecipes.count
            ])

            // Wait before retry pass
            try? await Task.sleep(nanoseconds: UInt64(Self.retryPassDelaySeconds * 1_000_000_000))

            var stillFailed: [Recipe] = []

            for (index, recipe) in failedRecipes.enumerated() {
                // Check for cancellation
                guard !Task.isCancelled else {
                    Log.info("AI image generation cancelled during retry", category: .import)
                    return
                }

                // Delay between requests (except first)
                if index > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(Self.imageGenerationDelaySeconds * 1_000_000_000))
                }

                do {
                    try await imageGenerator.generateAndSaveImage(for: recipe)
                    successCount += 1
                    Log.info("Retry succeeded for recipe image", category: .import, metadata: [
                        "title": recipe.title,
                        "retryPass": retryPass
                    ])
                } catch {
                    stillFailed.append(recipe)
                    Log.warning("Retry failed for recipe image", category: .import, metadata: [
                        "title": recipe.title,
                        "retryPass": retryPass
                    ])
                }
            }

            failedRecipes = stillFailed
        }

        let failureCount = failedRecipes.count
        let duration = Date().timeIntervalSince(startTime)

        Log.info("AI image generation completed", category: .import, metadata: [
            "jobId": job.id.uuidString,
            "successCount": successCount,
            "failureCount": failureCount,
            "durationSeconds": Int(duration),
            "avgSecondsPerImage": totalCount > 0 ? duration / Double(totalCount) : 0
        ])

        // Show toast if some images failed
        if failureCount > 0 && successCount > 0 {
            await MainActor.run {
                toastManager.warning(
                    title: "Some images couldn't be generated",
                    message: "\(successCount) of \(totalCount) images created"
                )
            }
        } else if failureCount > 0 && successCount == 0 {
            await MainActor.run {
                toastManager.error(
                    title: "Image generation failed",
                    message: "Recipes imported but images couldn't be generated"
                )
            }
        }

        // Note: AI collection cover generation happens in createOrAddToCollection
        // after recipes are routed to their collection
    }

    /// Generate an AI cover image for the collection when no suitable PDF cover was found
    private func generateAICollectionCover(for recipes: [Recipe], job: ImportJob, context: ModelContext) async {
        // Find the collection that contains these recipes
        guard let firstRecipe = recipes.first,
              let collection = firstRecipe.collections?.first else {
            Log.warning("No collection found for AI cover generation", category: .import)
            return
        }

        // Skip if collection already has a cover
        if collection.cookbookCoverImagePath != nil || collection.generatedBackgroundImagePath != nil {
            Log.info("Collection already has cover image, skipping AI generation", category: .import)
            return
        }

        Log.info("Generating AI cover for collection (first page was text-heavy)", category: .import, metadata: [
            "collectionName": collection.name,
            "recipeCount": recipes.count
        ])

        do {
            let collectionImageGenerator = ServiceContainer.shared.resolve(CollectionImageGenerator.self)
            let coverPath = try await collectionImageGenerator.generateBackground(for: collection)

            // Update collection with generated cover
            collection.generatedBackgroundImagePath = coverPath
            collection.useCustomBackground = true
            collection.lastImageGenerationDate = Date()
            try? context.save()

            Log.info("Generated AI collection cover", category: .import, metadata: [
                "collectionName": collection.name,
                "coverPath": coverPath
            ])
        } catch {
            Log.error("Failed to generate AI collection cover", category: .import, error: error, metadata: [
                "collectionName": collection.name
            ])
        }
    }

    // MARK: - Job Completion

    private func completeJob(_ job: ImportJob, context: ModelContext) async {
        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
        let collectionName = job.cookbookName ?? "your library"

        // CRITICAL: Recalculate success/failure counts from actual item statuses
        // These values are only set at job creation and don't auto-update
        if let items = job.items {
            job.successfulItems = items.filter { $0.status == .success }.count
            job.failedItems = items.filter { $0.status == .failed }.count
            job.completedItems = items.filter { $0.isCompleted }.count
        }

        // Clear pending signal since job is finishing
        if self.pendingJobId == job.id {
            self.pendingJobId = nil
        }

        // Set status based on success/failure outcomes
        if job.successfulItems == 0 && job.totalItems > 0 {
            // All items failed - mark as failed
            job.status = .failed
            Log.error("Import job completed with ALL items failed", category: .import, metadata: [
                "jobId": job.id.uuidString,
                "totalItems": job.totalItems,
                "failedItems": job.failedItems
            ])

            // Show error toast
            await MainActor.run {
                toastManager.error(
                    title: "Import Failed",
                    message: "All \(job.totalItems) recipe\(job.totalItems == 1 ? "" : "s") failed to import"
                )
            }
        } else if job.successfulItems > 0 && job.failedItems > 0 {
            // Partial success - mark as completed but log warning
            job.status = .completed
            Log.warning("Import job completed with some failures", category: .import, metadata: [
                "jobId": job.id.uuidString,
                "successfulItems": job.successfulItems,
                "failedItems": job.failedItems
            ])

            // Show partial success toast
            await MainActor.run {
                toastManager.warning(
                    title: "\(job.successfulItems) Recipe\(job.successfulItems == 1 ? "" : "s") Imported",
                    message: "\(job.failedItems) failed • Saved to \(collectionName)"
                )
            }
        } else {
            // All items succeeded
            job.status = .completed
            Log.info("Import job completed successfully", category: .import, metadata: [
                "jobId": job.id.uuidString,
                "successfulItems": job.successfulItems
            ])

            // Show success toast with collection name
            await MainActor.run {
                let recipeWord = job.successfulItems == 1 ? "recipe" : "recipes"
                toastManager.success(
                    title: "\(job.successfulItems) \(recipeWord.capitalized) Imported",
                    message: "Saved to \(collectionName)"
                )
            }
        }

        job.phase = .completed
        job.phaseProgress = 1.0
        job.completedAt = Date()
        isProcessing = false
        activeContext = nil // Clear stored context

        // End background task if active
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            Log.info("Background task ended - import completed", category: .import)
        }

        // Don't clear activeJob - let UI dismiss sheet explicitly
        // activeJob will be cleared when user taps "Done" button in ImportProgressView

        // Auto-create collection and add successful recipes
        // Determine collection name based on import type (single-page vs multi-page)
        let effectiveCookbookName = determineCollectionName(for: job)

        if let cookbookName = effectiveCookbookName, !cookbookName.isEmpty {
            Log.info("Auto-creating collection for completed job", category: .import, metadata: [
                "jobId": job.id.uuidString,
                "originalCookbookName": job.cookbookName ?? "nil",
                "effectiveCookbookName": cookbookName,
                "isSinglePageImport": isSinglePageImport(job: job),
                "collectionType": job.collectionType?.rawValue ?? "nil",
                "successfulRecipes": job.successfulItems
            ])
            await createOrAddToCollection(
                cookbookName: cookbookName,
                job: job,
                context: context
            )
        } else {
            Log.warning("Skipping collection creation - cookbook name is empty or nil", category: .import, metadata: [
                "jobId": job.id.uuidString,
                "cookbookName": job.cookbookName ?? "nil",
                "isEmpty": job.cookbookName?.isEmpty ?? true
            ])
        }

        // Clean up stable PDF copies now that import is complete
        cleanupStablePDFCopies(jobId: job.id)

        try? context.save()
    }

    /// Create or find collection and add successful recipes using CollectionRouter
    private func createOrAddToCollection(
        cookbookName: String,
        job: ImportJob,
        context: ModelContext
    ) async {
        // Get all successful recipe IDs from job items
        guard let items = job.items else { return }

        // Use flatMap to get ALL recipe IDs from each item (supports multi-recipe)
        let successfulRecipeIDs = items
            .filter { $0.status == .success }
            .flatMap { $0.recipeIDs }

        guard !successfulRecipeIDs.isEmpty else {
            Log.info("No successful recipes to add to collection", category: .import)
            return
        }

        // Log multi-recipe stats
        let totalItems = items.filter { $0.status == .success }.count
        let avgRecipesPerItem = Double(successfulRecipeIDs.count) / Double(max(totalItems, 1))
        Log.info("Adding recipes to collection via CollectionRouter", category: .import, metadata: [
            "items_processed": totalItems,
            "recipes_extracted": successfulRecipeIDs.count,
            "avg_recipes_per_item": String(format: "%.1f", avgRecipesPerItem)
        ])

        // Fetch recipes
        let recipeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                successfulRecipeIDs.contains(recipe.id)
            }
        )

        guard let recipes = try? context.fetch(recipeDescriptor) else {
            Log.error("Failed to fetch recipes for collection", category: .import)
            return
        }

        // Use CollectionRouter for unified routing logic
        let router = CollectionRouter(modelContext: context)
        router.routeCookbookImport(
            recipes,
            cookbookName: cookbookName,
            authorName: job.cookbookAuthor,
            jobID: job.id,
            coverImagePath: job.cookbookCoverImagePath
        )

        // Upload collection to Firebase if backend is active
        // Note: CollectionRouter has already saved the collection
        if backendConfig.isFirebaseActive {
            // Fetch the collection that was just created/updated by checking recipes' collections
            if let collection = recipes.first?.collections?.first {
                Task {
                    do {
                        try await firebaseSync.uploadCollection(collection)
                        Log.info("Collection synced to Firebase via CollectionRouter", category: .firebase, metadata: [
                            "collectionId": collection.id.uuidString,
                            "name": cookbookName,
                            "recipeCount": recipes.count
                        ])
                    } catch {
                        Log.error("Failed to sync collection to Firebase", category: .firebase, error: error, metadata: [
                            "collectionId": collection.id.uuidString,
                            "name": cookbookName
                        ])
                    }
                }
            }
        }

        Log.info("Successfully routed recipes to collection via CollectionRouter", category: .import, metadata: [
            "cookbook": cookbookName,
            "successful_recipes": recipes.count,
            "failed_recipes": job.failedItems
        ])

        // Generate AI cover for collection if:
        // 1. AI images were enabled for this job
        // 2. No cookbook cover was extracted (first page was text-heavy)
        // 3. Recipes exist and are now linked to the collection
        if job.shouldGenerateAIImages && job.cookbookCoverImagePath == nil && !recipes.isEmpty {
            await generateAICollectionCover(for: recipes, job: job, context: context)
        }
    }

    /// Clear the active job (called from UI when user dismisses)
    func clearActiveJob() {
        activeJob = nil
    }

    /// Delete a job completely (for clearing stuck/unwanted jobs)
    func deleteJob(_ job: ImportJob, context: ModelContext) throws {
        // Cancel any active tasks for this job
        if activeJob?.id == job.id {
            currentTasks.values.forEach { $0.cancel() }
            currentTasks.removeAll()
            activeJob = nil
            activeContext = nil
            isProcessing = false
        }

        // Delete checkpoint if exists
        if let checkpoint = job.checkpoint {
            context.delete(checkpoint)
        }

        // Collect placeholder recipe IDs to delete
        var placeholderIDsToDelete: [UUID] = []
        if let items = job.items {
            for item in items {
                // Collect placeholder IDs that are still in processing state
                if let placeholderID = item.placeholderRecipeID {
                    placeholderIDsToDelete.append(placeholderID)
                }
                context.delete(item)
            }
        }

        // Delete placeholder recipes that are still processing (not yet finalized)
        for placeholderID in placeholderIDsToDelete {
            let descriptor = FetchDescriptor<Recipe>(
                predicate: #Predicate<Recipe> { $0.id == placeholderID }
            )
            if let placeholder = try? context.fetch(descriptor).first {
                // Only delete if still in processing state (not finalized)
                if placeholder.processingStatus == .processing || placeholder.processingStatus == .failed {
                    context.delete(placeholder)
                    Log.info("Deleted placeholder recipe with job", category: .import, metadata: [
                        "placeholder_id": placeholderID.uuidString
                    ])
                }
            }
        }

        // Delete the job
        context.delete(job)

        try context.save()

        Log.info("Deleted import job", category: .import, metadata: [
            "job_id": job.id.uuidString,
            "status": job.status.rawValue,
            "placeholders_deleted": placeholderIDsToDelete.count
        ])
    }

    // MARK: - Collection Name Logic

    /// Determine the effective collection name based on import type
    /// - Camera/photo imports without names → "Cookbook Pages"
    /// - PDFs with custom names → use custom name (even if single-page)
    /// - PDFs without names → "Cookbook Pages"
    private func determineCollectionName(for job: ImportJob) -> String? {
        let isSinglePage = isSinglePageImport(job: job)
        let hasCustomName = job.cookbookName != nil && !job.cookbookName!.isEmpty
        let isPDF = job.items?.first?.source == .pdf

        // PDFs with custom names always use their name, even if single-page
        if isPDF && hasCustomName {
            Log.info("Routing PDF to named collection", category: .import, metadata: [
                "jobId": job.id.uuidString,
                "cookbookName": job.cookbookName ?? "nil",
                "isSinglePage": isSinglePage
            ])
            return job.cookbookName
        }

        // Single-page imports without custom names go to "Cookbook Pages"
        if isSinglePage {
            Log.info("Routing single-page import to Cookbook Pages", category: .import, metadata: [
                "jobId": job.id.uuidString,
                "originalCookbookName": job.cookbookName ?? "nil",
                "source": job.items?.first?.source.rawValue ?? "unknown"
            ])
            return "Cookbook Pages"
        }

        // Multi-page imports use original cookbook name
        Log.info("Routing multi-page import to named collection", category: .import, metadata: [
            "jobId": job.id.uuidString,
            "cookbookName": job.cookbookName ?? "nil",
            "source": job.items?.first?.source.rawValue ?? "unknown"
        ])
        return job.cookbookName
    }

    /// Check if this job represents a single-page import
    /// Returns true if:
    /// - Job has camera/photo library items (always single-page)
    /// - Job has PDF items that are ALL single-page recipes
    private func isSinglePageImport(job: ImportJob) -> Bool {
        guard let items = job.items?.filter({ $0.status == .success }), !items.isEmpty else {
            // No successful items - default to single-page (safer for camera imports)
            return true
        }

        // Check source type of first item (all items in a job have same source)
        guard let firstItem = items.first else { return true }

        switch firstItem.source {
        case .camera, .photoLibrary:
            // Camera and photo library imports are always treated as single-page
            return true

        case .pdf:
            // For PDFs, check if ALL items are single-page recipes
            let allSinglePage = items.allSatisfy { item in
                let isSinglePage = !(item.isMultiPageRecipe ?? false)
                let totalPages = item.totalPages ?? 1
                return isSinglePage && totalPages == 1
            }

            Log.info("PDF import page analysis", category: .import, metadata: [
                "jobId": job.id.uuidString,
                "totalItems": items.count,
                "allSinglePage": allSinglePage,
                "sampleItem_isMultiPage": items.first?.isMultiPageRecipe ?? false,
                "sampleItem_totalPages": items.first?.totalPages ?? 1
            ])

            return allSinglePage

        case .url:
            // URL imports are treated as single-page
            return true
        }
    }

    // MARK: - Credit Management

    /// Deduct credits for PDF import
    /// - Parameters:
    ///   - credits: Number of credits to deduct
    ///   - context: SwiftData ModelContext
    private func deductCreditsForImport(credits: Int, context: ModelContext) async throws {
        // Query for user credits
        let descriptor = FetchDescriptor<UserCredits>()
        let allCredits = try context.fetch(descriptor)

        guard let userCredits = allCredits.first else {
            Log.warning("No user credits found - skipping deduction", category: .import)
            return
        }

        try userCredits.deductCredits(credits)
        try context.save()

        Log.info("Credits deducted for import", category: .import, metadata: [
            "deducted": credits,
            "remaining_quota": userCredits.quotaRemaining,
            "remaining_purchased": userCredits.creditsBalance
        ])
    }

    // MARK: - PDF File Management

    /// Copy PDFs from temp directory to stable Caches location
    /// iOS can clean up temp files at any time, so we need a stable location for long operations
    /// Returns array of (originalURL, stableURL) tuples to maintain classification lookup
    private func copyPDFsToStableLocation(_ pdfURLs: [URL], jobId: UUID) throws -> [(original: URL, stable: URL)] {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let importDir = cacheDir.appendingPathComponent("PDFImports/\(jobId.uuidString)", isDirectory: true)

        // Create import directory
        try fileManager.createDirectory(at: importDir, withIntermediateDirectories: true)

        var urlMapping: [(original: URL, stable: URL)] = []

        for (index, pdfURL) in pdfURLs.enumerated() {
            let fileName = pdfURL.lastPathComponent
            let stableURL = importDir.appendingPathComponent("\(index)_\(fileName)")

            // Copy file to stable location
            if fileManager.fileExists(atPath: pdfURL.path) {
                try fileManager.copyItem(at: pdfURL, to: stableURL)
                urlMapping.append((original: pdfURL, stable: stableURL))

                Log.info("Copied PDF to stable location", category: .import, metadata: [
                    "original": pdfURL.lastPathComponent,
                    "stable": stableURL.path
                ])
            } else {
                Log.warning("PDF file already missing from temp location", category: .import, metadata: [
                    "file": pdfURL.lastPathComponent,
                    "path": pdfURL.path
                ])
                // Try to use original anyway (might work if it's not a temp file)
                urlMapping.append((original: pdfURL, stable: pdfURL))
            }
        }

        return urlMapping
    }

    /// Clean up stable PDF copies after import completes
    func cleanupStablePDFCopies(jobId: UUID) {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let importDir = cacheDir.appendingPathComponent("PDFImports/\(jobId.uuidString)", isDirectory: true)

        do {
            if fileManager.fileExists(atPath: importDir.path) {
                try fileManager.removeItem(at: importDir)
                Log.info("Cleaned up stable PDF copies", category: .import, metadata: [
                    "jobId": jobId.uuidString
                ])
            }
        } catch {
            Log.warning("Failed to clean up stable PDF copies", category: .import, metadata: [
                "jobId": jobId.uuidString,
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - Rate Limiting

    private func setupRateLimiter() {
        // Clean up old timestamps periodically
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupRateLimiterTimestamps()
            }
        }
    }

    private func waitForRateLimit() async {
        // Record this request
        requestTimestamps.append(Date())

        // Count requests in last minute
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        let recentRequests = requestTimestamps.filter { $0 > oneMinuteAgo }

        // If at limit, wait until we can make another request
        if recentRequests.count >= maxRequestsPerMinute {
            if let oldestRequest = recentRequests.first {
                let waitTime = 60 - Date().timeIntervalSince(oldestRequest)
                if waitTime > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
        }
    }

    private func cleanupRateLimiterTimestamps() {
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        requestTimestamps.removeAll { $0 < oneMinuteAgo }
    }
}

// MARK: - Errors

enum ImportJobError: LocalizedError {
    case alreadyProcessing
    case noItemsToProcess
    case jobNotFound
    case missingURLString
    case missingImageData
    case invalidImageData
    case noRecipeFound
    case cannotResume
    case missingPDFURL
    case pdfFileNotFound

    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Another import job is already in progress"
        case .noItemsToProcess:
            return "No items found to process"
        case .jobNotFound:
            return "Import job not found"
        case .missingURLString:
            return "URL string is missing for URL import"
        case .missingImageData:
            return "Image data is missing for image/PDF import"
        case .invalidImageData:
            return "Could not create image from image data"
        case .noRecipeFound:
            return "No recipe could be extracted from the image"
        case .cannotResume:
            return "Cannot resume this import job - checkpoint is invalid or expired"
        case .missingPDFURL:
            return "PDF URL is missing - cannot resume import"
        case .pdfFileNotFound:
            return "PDF file was moved or deleted - cannot resume import"
        }
    }
}

// MARK: - Async Semaphore

/// A simple async semaphore for rate limiting concurrent operations
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        if value > 0 {
            value -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}

// MARK: - Image Generation Progress Tracker

/// Thread-safe progress tracking for parallel image generation
actor ImageGenerationProgressTracker {
    private let total: Int
    private(set) var successCount: Int = 0
    private(set) var failureCount: Int = 0

    var completedCount: Int { successCount + failureCount }

    init(total: Int) {
        self.total = total
    }

    func recordSuccess() {
        successCount += 1
    }

    func recordFailure() {
        failureCount += 1
    }
}
