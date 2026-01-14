import Foundation
import SwiftData
import UIKit

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

    /// Create a new import job from PDF pages with intelligent multi-page grouping
    /// - Parameters:
    ///   - pdfPages: Array of page images from PDF
    ///   - fileName: PDF file name for job naming
    ///   - context: SwiftData ModelContext for persistence
    /// - Returns: The created ImportJob
    func createPDFImportJob(
        pdfPages: [(pageNumber: Int, image: UIImage)],
        fileName: String,
        context: ModelContext
    ) async throws -> ImportJob {
        Log.info("Creating PDF import job with multi-page analysis", category: .import, metadata: [
            "file": fileName,
            "pages": pdfPages.count
        ])

        // STEP 1: Analyze page boundaries to detect multi-page recipes
        let recipeGroups = try await multiPageAnalyzer.analyzePageBoundaries(pages: pdfPages)

        Log.info("Multi-page analysis complete", category: .import, metadata: [
            "file": fileName,
            "total_pages": pdfPages.count,
            "recipe_groups": recipeGroups.count,
            "multi_page_recipes": recipeGroups.filter { $0.isMultiPage }.count
        ])

        // STEP 2: Create job with one item per recipe (not per page!)
        let job = ImportJob(
            jobName: "Import \(fileName)",
            continueOnError: true
        )
        job.totalItems = recipeGroups.count
        context.insert(job)

        // STEP 3: Create ImportItem for each recipe group
        for group in recipeGroups {
            // For multi-page recipes, combine pages into single tall image
            let combinedImage = group.pageCount == 1 ? group.pages[0] : group.combinedImage()

            guard let imageData = combinedImage.jpegData(compressionQuality: 0.9) else {
                Log.warning("Failed to create image data for recipe group", category: .import, metadata: [
                    "file": fileName,
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
            item.job = job
            context.insert(item)

            Log.info("Created import item for recipe group", category: .import, metadata: [
                "file": fileName,
                "title": group.title,
                "pages": group.pageRange,
                "is_multi_page": group.isMultiPage
            ])
        }

        try context.save()

        Log.info("PDF import job created successfully", category: .import, metadata: [
            "file": fileName,
            "recipe_count": recipeGroups.count
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

    // MARK: - Job Completion

    private func completeJob(_ job: ImportJob, context: ModelContext) async {
        job.status = .completed
        job.completedAt = Date()
        isProcessing = false
        // Don't clear activeJob - let UI dismiss sheet explicitly
        // activeJob will be cleared when user taps "Done" button in ImportProgressView

        try? context.save()
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
