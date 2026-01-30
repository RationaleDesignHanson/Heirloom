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
        // Mark as processing
        item.startProcessing()
        try? context.save()

        do {
            let recipe: Recipe

            // Process based on source type
            switch item.source {
            case .url:
                recipe = try await processURLImport(item)

            case .pdf:
                recipe = try await processPDFPage(item)

            case .camera, .photoLibrary:
                recipe = try await processImageImport(item)
            }

            // Apply cookbook metadata if available (from PDF front matter)
            if let cookbookTitle = item.cookbookTitle {
                recipe.sourceBookTitle = cookbookTitle
            }
            if let cookbookAuthor = item.cookbookAuthor {
                recipe.sourceBookAuthor = cookbookAuthor
            }

            // Save recipe
            context.insert(recipe)

            // Save source image if available
            if let imageData = item.imageData,
               let sourceImage = UIImage(data: imageData) {
                do {
                    let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)
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

            try context.save()

            // Sync to Firebase if active
            if backendConfig.isFirebaseActive {
                do {
                    try await firebaseSync.uploadRecipe(recipe)
                    Log.info("Bulk import recipe synced to Firebase", category: .firebase, metadata: ["title": recipe.title, "source": item.source.rawValue])
                } catch {
                    Log.warning("Failed to sync bulk import recipe to Firebase", category: .firebase, metadata: ["error": error.localizedDescription, "title": recipe.title])
                    // Continue with next recipe
                }
            }

            // Mark item as successful
            item.markSuccess(recipeID: recipe.id)
            item.wasCheckpointed = true
            job.updateProgress(success: true)

            // Update checkpoint with recipe index
            if let items = job.items,
               let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
                job.checkpoint?.updateExtractionProgress(itemIndex: itemIndex)

                Log.info("Checkpointed recipe", category: .import, metadata: [
                    "recipe_index": itemIndex,
                    "total_completed": job.successfulItems,
                    "recipe_id": recipe.id.uuidString
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
    private func processPDFPage(_ item: ImportItem) async throws -> Recipe {
        guard let imageData = item.imageData else {
            throw ImportJobError.missingImageData
        }

        guard let image = UIImage(data: imageData) else {
            throw ImportJobError.invalidImageData
        }

        // Detect recipes in the image
        let detected = try await aiRecipeExtractor.detectRecipes(from: image)

        // Extract recipe(s) from image
        let result = try await aiRecipeExtractor.extractRecipesFromImage(
            image: image,
            detectedRecipes: detected
        )

        // Get first recipe (multi-page analysis should have grouped properly)
        guard let extractedRecipe = result.recipes.first else {
            throw ImportJobError.noRecipeFound
        }

        // Convert to Recipe model
        let recipe = createRecipe(from: extractedRecipe, sourceImage: image, sourceType: .scan)

        // Extract food image from PDF page (if present)
        await extractFoodImage(from: image, for: recipe)

        return recipe
    }

    /// Process camera/photo library import
    private func processImageImport(_ item: ImportItem) async throws -> Recipe {
        guard let imageData = item.imageData else {
            throw ImportJobError.missingImageData
        }

        guard let image = UIImage(data: imageData) else {
            throw ImportJobError.invalidImageData
        }

        // Detect recipes in the image
        let detected = try await aiRecipeExtractor.detectRecipes(from: image)

        // Extract recipe(s) from image
        let result = try await aiRecipeExtractor.extractRecipesFromImage(
            image: image,
            detectedRecipes: detected
        )

        // Get first recipe
        guard let extractedRecipe = result.recipes.first else {
            throw ImportJobError.noRecipeFound
        }

        // Convert to Recipe model
        let sourceType: RecipeSourceType = item.source == .camera ? .scan : .scan
        let recipe = createRecipe(from: extractedRecipe, sourceImage: image, sourceType: sourceType)

        return recipe
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
        job.status = .completed
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

    /// Create or find collection and add successful recipes
    private func createOrAddToCollection(
        cookbookName: String,
        job: ImportJob,
        context: ModelContext
    ) async {
        // Get all successful recipe IDs from job items
        guard let items = job.items else { return }

        let successfulRecipeIDs = items
            .filter { $0.status == .success && $0.recipeID != nil }
            .compactMap { $0.recipeID }

        guard !successfulRecipeIDs.isEmpty else {
            Log.info("No successful recipes to add to collection", category: .import)
            return
        }

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

        // Find or create collection
        // Use collection type from job if specified, otherwise default to userCreated
        let collectionType = job.collectionType ?? .userCreated

        // For cookbook collections, we need special handling:
        // - Custom names (non-default) should match by name AND type to allow grouping pages
        // - Default "Cookbook Pages" name should NEVER consolidate (always create separate collections)
        // - For other types (web, photo, video), consolidate into single collection by type
        let existingCollection: RecipeCollection?

        if collectionType == .cookbook && cookbookName == "Cookbook Pages" {
            // Never reuse default-named cookbook collections - always create new
            existingCollection = nil
            Log.info("Creating separate collection for default cookbook name", category: .import, metadata: [
                "cookbookName": cookbookName
            ])
        } else if collectionType == .cookbook {
            // For custom-named cookbooks, find by exact name AND type
            let typeRawValue = collectionType.rawValue
            let collectionDescriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate<RecipeCollection> { collection in
                    collection.name == cookbookName && collection.collectionType == typeRawValue
                }
            )
            existingCollection = try? context.fetch(collectionDescriptor).first
        } else {
            // For other types, find by name (existing behavior)
            let collectionDescriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate<RecipeCollection> { collection in
                    collection.name == cookbookName
                }
            )
            existingCollection = try? context.fetch(collectionDescriptor).first
        }

        let collection: RecipeCollection
        if let existing = existingCollection {
            collection = existing
            Log.info("Adding recipes to existing collection", category: .import, metadata: [
                "collection": cookbookName,
                "collectionType": collectionType.rawValue,
                "recipe_count": recipes.count
            ])
        } else {
            collection = RecipeCollection(
                name: cookbookName,
                description: "Imported from \(cookbookName)",
                iconName: "book.fill",
                color: "#FF6B6B",
                isSystemCollection: false,
                collectionType: collectionType
            )
            context.insert(collection)
            Log.info("Created new collection for cookbook", category: .import, metadata: [
                "collection": cookbookName,
                "collectionType": collectionType.rawValue,
                "recipe_count": recipes.count
            ])
        }

        // Add collection to recipes
        for recipe in recipes {
            if recipe.collections == nil {
                recipe.collections = [collection]
            } else if let collections = recipe.collections,
                      !collections.contains(where: { $0.id == collection.id }) {
                recipe.collections?.append(collection)
            }
        }

        try? context.save()

        // Upload collection to Firebase if backend is active
        if backendConfig.isFirebaseActive {
            Task {
                do {
                    try await firebaseSync.uploadCollection(collection)
                    Log.info("Collection synced to Firebase", category: .firebase, metadata: [
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

        Log.info("Successfully added recipes to collection", category: .import, metadata: [
            "collection": cookbookName,
            "successful_recipes": recipes.count,
            "failed_recipes": job.failedItems
        ])
    }

    /// Clear the active job (called from UI when user dismisses)
    func clearActiveJob() {
        activeJob = nil
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
