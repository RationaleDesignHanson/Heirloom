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
    ///   - context: SwiftData ModelContext for persistence
    /// - Returns: The created ImportJob (already inserted and saved)
    func createAndAnalyzePDFJob(
        pdfURLs: [URL],
        jobName: String,
        cookbookName: String?,
        collectionType: CollectionType? = nil,
        context: ModelContext
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
        for pdfURL in pdfURLs {
            guard let pdfDocument = PDFDocument(url: pdfURL) else { continue }
            totalPagesAcrossAllPDFs += pdfDocument.pageCount
        }

        // Process each PDF
        for pdfURL in pdfURLs {
            // Extract cookbook metadata from front matter
            let metadataExtractor = PDFMetadataExtractor()
            let cookbookMetadata = await metadataExtractor.extractMetadata(from: pdfURL)

            if let metadata = cookbookMetadata {
                Log.info("Extracted cookbook metadata", category: .import, metadata: [
                    "file": pdfURL.lastPathComponent,
                    "title": metadata.title ?? "nil",
                    "author": metadata.author ?? "nil"
                ])
            }

            // Extract first page as cookbook cover image
            if job.cookbookCoverImagePath == nil, // Only extract once for first PDF
               let pdfDocument = PDFDocument(url: pdfURL),
               let firstPage = pdfDocument.page(at: 0) {

                // Render first page to image
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
                        "coverPath": coverPath
                    ])
                }
            }

            // Render PDF pages in batches and analyze incrementally
            Log.info("Starting batched PDF processing", category: .import, metadata: [
                "file": pdfURL.lastPathComponent
            ])

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
                            totalPagesProcessed += 1
                            job.phaseProgress = Double(totalPagesProcessed) / Double(totalPagesAcrossAllPDFs)

                            // Save checkpoint after each page analyzed
                            job.checkpoint?.addCompletedPage(currentPage)
                            try? context.save()

                            Log.debug("Checkpointed page", category: .import, metadata: [
                                "page": currentPage,
                                "total_analyzed": job.checkpoint?.analyzedPageNumbers.count ?? 0
                            ])
                        }
                    }
                )
            }

            // Finalize groups after all batches are processed
            let recipeGroups = multiPageAnalyzer.finalizeGroups()

            Log.info("Multi-page analysis complete", category: .import, metadata: [
                "file": pdfURL.lastPathComponent,
                "recipe_groups": recipeGroups.count,
                "multi_page_recipes": recipeGroups.filter { $0.isMultiPage }.count
            ])

            // Create ImportItems in batches to avoid loading all images into memory
            // Process 5 recipe groups at a time
            let groupBatches = recipeGroups.chunked(into: 5)

            for (batchIndex, groupBatch) in groupBatches.enumerated() {
                Log.info("Creating import items batch", category: .import, metadata: [
                    "file": pdfURL.lastPathComponent,
                    "batch": batchIndex + 1,
                    "total_batches": groupBatches.count,
                    "recipes_in_batch": groupBatch.count
                ])

                for group in groupBatch {
                    let combinedImage = group.pageCount == 1 ? group.pages[0] : group.combinedImage()
                    guard let imageData = combinedImage.jpegData(compressionQuality: 0.9) else {
                        Log.warning("Failed to create image data for recipe group", category: .import, metadata: [
                            "file": pdfURL.lastPathComponent,
                            "pages": group.pageRange
                        ])
                        continue
                    }

                    let item = ImportItem(
                        source: .pdf,
                        imageData: imageData,
                        pageNumber: group.startPage,
                        totalPages: group.pageCount,
                        isMultiPageRecipe: group.isMultiPage
                    )

                    // Apply cookbook metadata
                    item.cookbookTitle = cookbookMetadata?.title
                    item.cookbookAuthor = cookbookMetadata?.author

                    item.job = job
                    context.insert(item)
                    allItems.append(item)

                    Log.info("Created import item for recipe group", category: .import, metadata: [
                        "file": pdfURL.lastPathComponent,
                        "title": group.title,
                        "pages": group.pageRange,
                        "is_multi_page": group.isMultiPage
                    ])
                }

                // Save batch to database and force memory cleanup
                try context.save()
                await Task.yield()

                Log.info("Saved import items batch to database", category: .import, metadata: [
                    "file": pdfURL.lastPathComponent,
                    "batch": batchIndex + 1
                ])
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

        // PHASE 1: Validation (quick - mostly already done in PDFImportView)
        job.phase = .validation
        job.phaseProgress = 1.0 // Complete instantly (validation already done)
        try context.save()

        // PHASE 2: Analysis (extract food images from PDF pages)
        job.phase = .analysis
        job.phaseProgress = 0.0
        try context.save()

        await analyzeAndExtractImages(job: job, items: items, context: context)

        job.phaseProgress = 1.0
        try context.save()

        // PHASE 3: Extraction (AI recipe extraction)
        job.phase = .extraction
        job.phaseProgress = 0.0
        try context.save()

        // Process items with concurrency control
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0

            for item in items {
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

        await completeJob(job, context: context)
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

    // MARK: - Item Processing

    private func processItem(_ item: ImportItem, job: ImportJob, context: ModelContext) async {
        Log.info("🚀 Starting processItem", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "job_id": job.id.uuidString,
            "source": item.source.rawValue,
            "has_image_data": item.imageData != nil,
            "image_data_size_kb": (item.imageData?.count ?? 0) / 1024
        ])

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

                    // No exact duplicates - proceed with insertion
                    recipesToInsert.append(recipe)
                    context.insert(recipe)
                } catch {
                    // Duplicate detection failed - insert anyway (don't block import)
                    Log.warning("⚠️ Duplicate detection failed, inserting recipe anyway", category: .import, metadata: [
                        "title": recipe.title,
                        "error": error.localizedDescription
                    ])
                    recipesToInsert.append(recipe)
                    context.insert(recipe)
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

            // Ensure we have at least one recipe
            guard !recipes.isEmpty else {
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
                "retry_count": item.retryCount
            ])

            try? context.save()

            // Stop job if not continuing on error
            if !job.continueOnError {
                job.status = .failed
                isProcessing = false
                activeJob = nil
                activeContext = nil // Clear stored context
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
        guard let imageData = item.imageData else {
            throw ImportJobError.missingImageData
        }

        guard let image = UIImage(data: imageData) else {
            throw ImportJobError.invalidImageData
        }

        // Detect recipes in the image
        let detected = try await aiRecipeExtractor.detectRecipes(from: image)

        // Extract recipe(s) from image
        Log.info("📝 Extracting recipes from image", category: .import, metadata: [
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
        Log.info("🔄 Converting extracted recipes to Recipe models", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "recipe_count": result.recipes.count
        ])
        let recipes = result.recipes.map { extractedRecipe in
            createRecipe(from: extractedRecipe, sourceImage: image, sourceType: .scan)
        }

        Log.info("✅ Recipe models created", category: .import, metadata: [
            "item_id": item.id.uuidString,
            "recipe_titles": recipes.map { $0.title }.joined(separator: " | ")
        ])

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

        // Add ingredients
        for ingredientText in extracted.ingredients {
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

    // MARK: - Job Completion

    private func completeJob(_ job: ImportJob, context: ModelContext) async {
        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
        let collectionName = job.cookbookName ?? "your library"

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

        // Auto-create collection and add successful recipes if cookbook name exists
        if let cookbookName = job.cookbookName, !cookbookName.isEmpty {
            Log.info("Auto-creating collection for completed job", category: .import, metadata: [
                "jobId": job.id.uuidString,
                "cookbookName": cookbookName,
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

        // Delete all items
        if let items = job.items {
            for item in items {
                context.delete(item)
            }
        }

        // Delete the job
        context.delete(job)

        try context.save()

        Log.info("Deleted import job", category: .import, metadata: [
            "job_id": job.id.uuidString,
            "status": job.status.rawValue
        ])
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
