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
        context: ModelContext
    ) throws -> ImportJob {
        // Create job
        let job = ImportJob(jobName: jobName)
        job.status = .processing  // Set to processing immediately so banner shows it
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
        context: ModelContext
    ) async throws -> ImportJob {
        // STEP 1: Create job immediately (so banner appears)
        let job = ImportJob(jobName: jobName, continueOnError: true)
        job.status = .processing  // Set to processing immediately so banner shows it
        job.phase = .validation
        job.phaseProgress = 0.0
        job.totalItems = 0 // Will be updated as we discover recipes
        job.cookbookName = cookbookName
        context.insert(job)
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

            // Render PDF pages
            Log.info("Rendering PDF pages", category: .import, metadata: [
                "file": pdfURL.lastPathComponent
            ])

            let pdfProcessor = ServiceContainer.shared.resolve(PDFProcessor.self)
            let pages = try await pdfProcessor.renderPDFPages(from: pdfURL)

            // Analyze page boundaries with progress callback
            Log.info("Analyzing page boundaries", category: .import, metadata: [
                "file": pdfURL.lastPathComponent,
                "pages": pages.count
            ])

            let recipeGroups = try await multiPageAnalyzer.analyzePageBoundaries(
                pages: pages,
                progressCallback: { currentPage in
                    Task { @MainActor in
                        totalPagesProcessed += 1
                        job.phaseProgress = Double(totalPagesProcessed) / Double(totalPagesAcrossAllPDFs)
                        try? context.save()
                    }
                }
            )

            Log.info("Multi-page analysis complete", category: .import, metadata: [
                "file": pdfURL.lastPathComponent,
                "recipe_groups": recipeGroups.count,
                "multi_page_recipes": recipeGroups.filter { $0.isMultiPage }.count
            ])

            // Create ImportItems for this PDF
            for group in recipeGroups {
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
        context: ModelContext
    ) async throws -> ImportJob {
        let job = ImportJob(
            jobName: "Camera Scan",
            continueOnError: true
        )
        job.status = .processing  // Set to processing immediately so banner shows it
        job.totalItems = images.count
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
        context: ModelContext
    ) async throws -> ImportJob {
        let job = ImportJob(
            jobName: "Photo Library Import",
            continueOnError: true
        )
        job.status = .processing  // Set to processing immediately so banner shows it
        job.totalItems = images.count
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
        isProcessing = true
        job.status = .processing

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
            job.updateProgress(success: true)

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
        // Don't clear activeJob - let UI dismiss sheet explicitly
        // activeJob will be cleared when user taps "Done" button in ImportProgressView

        // Auto-create collection and add successful recipes if cookbook name exists
        if let cookbookName = job.cookbookName, !cookbookName.isEmpty {
            await createOrAddToCollection(
                cookbookName: cookbookName,
                job: job,
                context: context
            )
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
        let collectionDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate<RecipeCollection> { collection in
                collection.name == cookbookName
            }
        )

        let existingCollection = try? context.fetch(collectionDescriptor).first

        let collection: RecipeCollection
        if let existing = existingCollection {
            collection = existing
            Log.info("Adding recipes to existing collection", category: .import, metadata: [
                "collection": cookbookName,
                "recipe_count": recipes.count
            ])
        } else {
            collection = RecipeCollection(
                name: cookbookName,
                description: "Imported from \(cookbookName)",
                iconName: "book.fill",
                color: "#FF6B6B",
                isSystemCollection: false
            )
            context.insert(collection)
            Log.info("Created new collection for cookbook", category: .import, metadata: [
                "collection": cookbookName,
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
        }
    }
}
