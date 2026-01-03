import Foundation
import SwiftData

/// Actor-based manager for processing bulk import jobs
/// Handles rate limiting, concurrency control, and state persistence
@MainActor
final class ImportJobManager: ObservableObject {
    // MARK: - Singleton
    static let shared = ImportJobManager()

    private init() {
        setupRateLimiter()
    }

    // MARK: - Configuration
    private let maxConcurrentImports = 3
    private let maxRequestsPerMinute = 20
    private var requestTimestamps: [Date] = []

    // MARK: - State
    @Published private(set) var activeJob: ImportJob?
    @Published private(set) var isProcessing = false

    private var currentTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Dependencies
    private let importService = RecipeImportService.shared

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
            // Import recipe
            let importedRecipe = try await importService.importRecipe(from: item.urlString)

            // Create Recipe object
            let recipe = Recipe(
                title: importedRecipe.title,
                sourceType: .url,
                sourceURL: item.urlString,
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

            // Save recipe
            context.insert(recipe)
            try context.save()

            // Sync to Firebase if active
            if BackendConfig.shared.isFirebaseActive {
                do {
                    try await FirebaseSyncService.shared.uploadRecipe(recipe)
                    print("✅ Bulk import recipe synced to Firebase: \(recipe.title)")
                } catch {
                    print("⚠️ Failed to sync bulk import recipe: \(error.localizedDescription)")
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

    // MARK: - Job Completion

    private func completeJob(_ job: ImportJob, context: ModelContext) async {
        job.status = .completed
        job.completedAt = Date()
        isProcessing = false
        activeJob = nil

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

    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Another import job is already in progress"
        case .noItemsToProcess:
            return "No items found to process"
        case .jobNotFound:
            return "Import job not found"
        }
    }
}
