import BackgroundTasks
import SwiftData
import Foundation

/// Background task for overnight collection image regeneration
@MainActor
class CollectionImageRefreshTask {
    static let taskIdentifier = "com.rationaledesign.heirloom.collection-image-refresh"

    private let generator: CollectionImageGenerator
    private let modelContainer: ModelContainer

    init(generator: CollectionImageGenerator, modelContainer: ModelContainer) {
        self.generator = generator
        self.modelContainer = modelContainer
    }

    /// Register background task handler
    static func register(generator: CollectionImageGenerator, modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await handleBackgroundTask(task as! BGProcessingTask, generator: generator, modelContainer: modelContainer)
            }
        }
    }

    /// Schedule next refresh (called when app backgrounds)
    static func scheduleRefresh() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true  // Only when charging

        // Schedule for 2-5 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 2

        if let targetDate = calendar.date(from: components) {
            let scheduledDate = targetDate < Date() ?
                calendar.date(byAdding: .day, value: 1, to: targetDate)! : targetDate
            request.earliestBeginDate = scheduledDate
        }

        do {
            try BGTaskScheduler.shared.submit(request)
            Log.info("Scheduled collection image refresh", category: .general, metadata: [
                "nextRun": request.earliestBeginDate?.description ?? "unknown"
            ])
        } catch {
            Log.error("Failed to schedule background task", category: .general, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    private static func handleBackgroundTask(
        _ task: BGProcessingTask,
        generator: CollectionImageGenerator,
        modelContainer: ModelContainer
    ) async {
        let refreshTask = CollectionImageRefreshTask(generator: generator, modelContainer: modelContainer)

        // Handle expiration
        task.expirationHandler = {
            Log.warning("Background task expired", category: .general)
            task.setTaskCompleted(success: false)
        }

        // Run refresh
        await refreshTask.refreshCollectionImages()
        task.setTaskCompleted(success: true)

        // Schedule next run
        scheduleRefresh()
    }

    /// Main refresh logic
    func refreshCollectionImages() async {
        Log.info("Starting collection image refresh", category: .general)

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { !$0.isSystemCollection }
        )

        guard let collections = try? context.fetch(descriptor) else {
            Log.error("Failed to fetch collections", category: .general)
            return
        }

        var refreshedCount = 0

        for collection in collections {
            // Skip if not needed
            guard shouldRefresh(collection) else { continue }

            do {
                let imagePath = try await generator.generateBackground(for: collection)

                // Update collection metadata
                collection.generatedBackgroundImagePath = imagePath
                collection.lastImageGenerationDate = Date()
                collection.lastRecipeCountAtGeneration = collection.recipes?.count ?? 0

                try? context.save()

                Log.info("Refreshed collection image", category: .general, metadata: [
                    "collection": collection.name
                ])
                refreshedCount += 1
            } catch {
                Log.error("Failed to refresh collection image", category: .general, metadata: [
                    "collection": collection.name,
                    "error": error.localizedDescription
                ])
            }

            // Rate limit - 2 seconds between generations
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        Log.info("Collection image refresh complete", category: .general, metadata: [
            "refreshed": refreshedCount,
            "total": collections.count
        ])
    }

    private func shouldRefresh(_ collection: RecipeCollection) -> Bool {
        // No existing AI-generated image
        if collection.generatedBackgroundImagePath == nil {
            return true
        }

        // Image older than 30 days
        if let lastGen = collection.lastImageGenerationDate,
           Date().timeIntervalSince(lastGen) > 30 * 24 * 60 * 60 {
            return true
        }

        // Recipe count changed significantly (>20%)
        let currentCount = collection.recipes?.count ?? 0
        let lastCount = collection.lastRecipeCountAtGeneration

        if lastCount > 0 {
            let changePercent = abs(Double(currentCount - lastCount) / Double(lastCount))
            if changePercent > 0.2 {
                return true
            }
        }

        return false
    }
}
