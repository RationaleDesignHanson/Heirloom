import XCTest
import SwiftData
@testable import Heirloom

/// Tests for ImportJob and ImportItem models
/// Covers state management, progress tracking, and relationships
@MainActor
final class ImportModelsTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([ImportJob.self, ImportItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - ImportJob Tests

    func test_importJob_initialization() {
        let job = ImportJob(jobName: "Test Job")

        XCTAssertNotNil(job.id)
        XCTAssertEqual(job.jobName, "Test Job")
        XCTAssertEqual(job.status, .pending)
        XCTAssertEqual(job.totalItems, 0)
        XCTAssertEqual(job.completedItems, 0)
        XCTAssertEqual(job.successfulItems, 0)
        XCTAssertEqual(job.failedItems, 0)
        XCTAssertTrue(job.continueOnError)
    }

    func test_importJob_progress() {
        let job = ImportJob()
        job.totalItems = 10
        job.completedItems = 3

        XCTAssertEqual(job.progress, 0.3, accuracy: 0.001)
    }

    func test_importJob_progressWithZeroItems() {
        let job = ImportJob()
        job.totalItems = 0
        job.completedItems = 0

        XCTAssertEqual(job.progress, 0.0)
    }

    func test_importJob_updateProgress_success() {
        let job = ImportJob()
        job.totalItems = 10

        job.updateProgress(success: true)

        XCTAssertEqual(job.completedItems, 1)
        XCTAssertEqual(job.successfulItems, 1)
        XCTAssertEqual(job.failedItems, 0)
    }

    func test_importJob_updateProgress_failure() {
        let job = ImportJob()
        job.totalItems = 10

        job.updateProgress(success: false)

        XCTAssertEqual(job.completedItems, 1)
        XCTAssertEqual(job.successfulItems, 0)
        XCTAssertEqual(job.failedItems, 1)
    }

    func test_importJob_isComplete_completed() {
        let job = ImportJob()
        job.status = .completed

        XCTAssertTrue(job.isComplete)
    }

    func test_importJob_isComplete_failed() {
        let job = ImportJob()
        job.status = .failed

        XCTAssertTrue(job.isComplete)
    }

    func test_importJob_isComplete_processing() {
        let job = ImportJob()
        job.status = .processing

        XCTAssertFalse(job.isComplete)
    }

    func test_importJob_canRetry_failed() {
        let job = ImportJob()
        job.status = .failed

        XCTAssertTrue(job.canRetry)
    }

    func test_importJob_canRetry_paused() {
        let job = ImportJob()
        job.status = .paused

        XCTAssertTrue(job.canRetry)
    }

    func test_importJob_canRetry_completed() {
        let job = ImportJob()
        job.status = .completed

        XCTAssertFalse(job.canRetry)
    }

    func test_importJob_shouldContinueProcessing() {
        let job = ImportJob()

        job.status = .processing
        XCTAssertTrue(job.shouldContinueProcessing)

        job.status = .paused
        XCTAssertFalse(job.shouldContinueProcessing)

        job.status = .completed
        XCTAssertFalse(job.shouldContinueProcessing)
    }

    func test_importJob_persistence() throws {
        let job = ImportJob(jobName: "Persist Test")
        job.totalItems = 5
        job.completedItems = 2
        job.status = .processing

        modelContext.insert(job)
        try modelContext.save()

        let descriptor = FetchDescriptor<ImportJob>()
        let jobs = try modelContext.fetch(descriptor)

        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs.first?.jobName, "Persist Test")
        XCTAssertEqual(jobs.first?.totalItems, 5)
        XCTAssertEqual(jobs.first?.status, .processing)
    }

    // MARK: - ImportItem Tests

    func test_importItem_initialization() {
        let item = ImportItem(urlString: "https://example.com/recipe")

        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.urlString, "https://example.com/recipe")
        XCTAssertEqual(item.status, .pending)
        XCTAssertNil(item.errorMessage)
        XCTAssertEqual(item.retryCount, 0)
    }

    func test_importItem_startProcessing() {
        let item = ImportItem(urlString: "https://example.com/recipe")

        item.startProcessing()

        XCTAssertEqual(item.status, .processing)
    }

    func test_importItem_markSuccess() {
        let item = ImportItem(urlString: "https://example.com/recipe")
        let recipeID = UUID()

        item.markSuccess(recipeID: recipeID)

        XCTAssertEqual(item.status, .success)
        XCTAssertEqual(item.recipeID, recipeID)
        XCTAssertNotNil(item.processedAt)
    }

    func test_importItem_markFailed() {
        let item = ImportItem(urlString: "https://example.com/recipe")

        item.markFailed(error: "Network timeout")

        XCTAssertEqual(item.status, .failed)
        XCTAssertEqual(item.errorMessage, "Network timeout")
        XCTAssertNotNil(item.processedAt)
    }

    func test_importItem_markSkipped() {
        let item = ImportItem(urlString: "https://example.com/recipe")

        item.markSkipped(reason: "Duplicate URL")

        XCTAssertEqual(item.status, .skipped)
        XCTAssertEqual(item.errorMessage, "Duplicate URL")
        XCTAssertNotNil(item.processedAt)
    }

    func test_importItem_incrementRetry() {
        let item = ImportItem(urlString: "https://example.com/recipe")
        item.status = .failed

        item.incrementRetry()

        XCTAssertEqual(item.retryCount, 1)
        XCTAssertEqual(item.status, .pending)
    }

    func test_importItem_canRetry_belowLimit() {
        let item = ImportItem(urlString: "https://example.com/recipe")
        item.status = .failed
        item.retryCount = 2

        XCTAssertTrue(item.canRetry)
    }

    func test_importItem_canRetry_atLimit() {
        let item = ImportItem(urlString: "https://example.com/recipe")
        item.status = .failed
        item.retryCount = 3

        XCTAssertFalse(item.canRetry)
    }

    func test_importItem_canRetry_successStatus() {
        let item = ImportItem(urlString: "https://example.com/recipe")
        item.status = .success
        item.retryCount = 1

        XCTAssertFalse(item.canRetry)
    }

    func test_importItem_isCompleted_success() {
        let item = ImportItem(urlString: "https://example.com/recipe")
        item.status = .success

        XCTAssertTrue(item.isCompleted)
    }

    func test_importItem_isCompleted_failed() {
        let item = ImportItem(urlString: "https://example.com/recipe")
        item.status = .failed

        XCTAssertTrue(item.isCompleted)
    }

    func test_importItem_isCompleted_skipped() {
        let item = ImportItem(urlString: "https://example.com/recipe")
        item.status = .skipped

        XCTAssertTrue(item.isCompleted)
    }

    func test_importItem_isCompleted_pending() {
        let item = ImportItem(urlString: "https://example.com/recipe")
        item.status = .pending

        XCTAssertFalse(item.isCompleted)
    }

    func test_importItem_isDuplicate() {
        let item1 = ImportItem(urlString: "https://example.com/recipe", normalizedURL: "https://example.com/recipe")
        let item2 = ImportItem(urlString: "https://example.com/recipe?source=email", normalizedURL: "https://example.com/recipe")

        XCTAssertTrue(item1.isDuplicate(of: item2))
    }

    func test_importItem_isDuplicate_different() {
        let item1 = ImportItem(urlString: "https://example.com/recipe1", normalizedURL: "https://example.com/recipe1")
        let item2 = ImportItem(urlString: "https://example.com/recipe2", normalizedURL: "https://example.com/recipe2")

        XCTAssertFalse(item1.isDuplicate(of: item2))
    }

    func test_importItem_isDuplicate_nilNormalized() {
        let item1 = ImportItem(urlString: "invalid", normalizedURL: nil)
        let item2 = ImportItem(urlString: "also invalid", normalizedURL: nil)

        XCTAssertFalse(item1.isDuplicate(of: item2))
    }

    func test_importItem_persistence() throws {
        let item = ImportItem(urlString: "https://example.com/recipe")
        item.status = .processing
        item.normalizedURL = "https://example.com/recipe"

        modelContext.insert(item)
        try modelContext.save()

        let descriptor = FetchDescriptor<ImportItem>()
        let items = try modelContext.fetch(descriptor)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.urlString, "https://example.com/recipe")
        XCTAssertEqual(items.first?.status, .processing)
    }

    // MARK: - Relationship Tests

    func test_jobItemRelationship() throws {
        let job = ImportJob(jobName: "Relationship Test")
        let item1 = ImportItem(urlString: "https://example.com/recipe1")
        let item2 = ImportItem(urlString: "https://example.com/recipe2")

        item1.job = job
        item2.job = job
        job.items = [item1, item2]

        modelContext.insert(job)
        modelContext.insert(item1)
        modelContext.insert(item2)
        try modelContext.save()

        let descriptor = FetchDescriptor<ImportJob>()
        let jobs = try modelContext.fetch(descriptor)

        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs.first?.items?.count, 2)
    }

    func test_cascadeDelete() throws {
        let job = ImportJob(jobName: "Delete Test")
        let item = ImportItem(urlString: "https://example.com/recipe")

        item.job = job
        job.items = [item]

        modelContext.insert(job)
        modelContext.insert(item)
        try modelContext.save()

        modelContext.delete(job)
        try modelContext.save()

        let itemDescriptor = FetchDescriptor<ImportItem>()
        let items = try modelContext.fetch(itemDescriptor)

        XCTAssertEqual(items.count, 0, "Items should be deleted when job is deleted")
    }

    // MARK: - AI Suggestions Tests (Phase 3 placeholders)

    func test_importItem_aiSuggestions() {
        let item = ImportItem(urlString: "https://example.com/recipe")
        item.suggestedCollections = ["Desserts", "Quick Meals"]
        item.suggestedTags = ["chocolate", "baking"]
        item.suggestionConfidence = 0.85

        XCTAssertEqual(item.suggestedCollections?.count, 2)
        XCTAssertEqual(item.suggestedTags?.count, 2)
        XCTAssertEqual(item.suggestionConfidence ?? 0, 0.85, accuracy: 0.01)
    }

    // MARK: - Real-World Scenarios

    func test_realWorld_batchImportProgress() {
        let job = ImportJob(jobName: "Batch Import")
        job.totalItems = 10

        // Process items
        for _ in 0..<7 {
            job.updateProgress(success: true)
        }
        for _ in 0..<2 {
            job.updateProgress(success: false)
        }

        XCTAssertEqual(job.completedItems, 9)
        XCTAssertEqual(job.successfulItems, 7)
        XCTAssertEqual(job.failedItems, 2)
        XCTAssertEqual(job.progress, 0.9, accuracy: 0.001)
    }

    func test_realWorld_retryFailedItem() {
        let item = ImportItem(urlString: "https://example.com/recipe")

        // First attempt fails
        item.startProcessing()
        item.markFailed(error: "Timeout")

        XCTAssertEqual(item.status, .failed)
        XCTAssertTrue(item.canRetry)

        // Retry
        item.incrementRetry()
        XCTAssertEqual(item.status, .pending)
        XCTAssertEqual(item.retryCount, 1)

        // Second attempt succeeds
        item.startProcessing()
        item.markSuccess(recipeID: UUID())

        XCTAssertEqual(item.status, .success)
    }
}
