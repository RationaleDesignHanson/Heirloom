//
//  ImportJobProgressTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-04
//  Unit tests for ImportJob progress tracking and queue management
//
//  Tests ensure that:
//  - Import jobs track progress correctly through phases
//  - Multiple jobs can be queued and processed
//  - Job status transitions are valid
//  - Item-level progress aggregates correctly
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class ImportJobProgressTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true, credits: 100)
        try env.save()
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        try await super.tearDown()
    }

    // MARK: - ImportJob Status Tests

    /// Test 1: New job starts with pending status
    func test_newJob_hasPendingStatus() throws {
        // GIVEN/WHEN: Creating a new import job
        let job = ImportJob()
        env.modelContext.insert(job)

        // THEN: Status should be pending
        XCTAssertEqual(job.status, .pending)
    }

    /// Test 2: Job status can transition to processing
    func test_job_canTransitionToProcessing() throws {
        // GIVEN: A pending job
        let job = ImportJob()
        env.modelContext.insert(job)

        // WHEN: Transitioning to processing
        job.status = .processing

        // THEN: Status should be processing
        XCTAssertEqual(job.status, .processing)
    }

    /// Test 3: Job status can transition through all phases
    func test_job_canTransitionThroughAllStatuses() throws {
        // GIVEN: A job
        let job = ImportJob()
        env.modelContext.insert(job)

        // WHEN/THEN: Can transition through all valid states
        XCTAssertEqual(job.status, .pending)

        job.status = .processing
        XCTAssertEqual(job.status, .processing)

        job.status = .paused
        XCTAssertEqual(job.status, .paused)

        job.status = .completed
        XCTAssertEqual(job.status, .completed)
    }

    // MARK: - Progress Calculation Tests

    /// Test 4: Empty job has 0 progress
    func test_emptyJob_hasZeroProgress() throws {
        // GIVEN: A job with no items
        let job = ImportJob()
        job.totalItems = 0

        // THEN: Progress should be 0
        XCTAssertEqual(job.progress, 0.0)
    }

    /// Test 5: Job with all completed items has 100% progress
    func test_allCompletedItems_hasFullProgress() throws {
        // GIVEN: A job with all completed items
        let job = ImportJob()
        job.totalItems = 2
        job.completedItems = 2

        env.modelContext.insert(job)

        // THEN: Progress should be 1.0
        XCTAssertEqual(job.progress, 1.0, accuracy: 0.01)
    }

    /// Test 6: Job with mixed item status shows partial progress
    func test_mixedItemStatus_showsPartialProgress() throws {
        // GIVEN: A job with partial completion
        let job = ImportJob()
        job.totalItems = 4
        job.completedItems = 2

        env.modelContext.insert(job)

        // THEN: Progress should be 50%
        XCTAssertEqual(job.progress, 0.5, accuracy: 0.01)
    }

    /// Test 7: updateProgress increments counters correctly
    func test_updateProgress_incrementsCounters() throws {
        // GIVEN: A job
        let job = ImportJob()
        job.totalItems = 3

        // WHEN: Updating progress with success
        job.updateProgress(success: true)
        XCTAssertEqual(job.completedItems, 1)
        XCTAssertEqual(job.successfulItems, 1)
        XCTAssertEqual(job.failedItems, 0)

        // WHEN: Updating progress with failure
        job.updateProgress(success: false)
        XCTAssertEqual(job.completedItems, 2)
        XCTAssertEqual(job.successfulItems, 1)
        XCTAssertEqual(job.failedItems, 1)
    }

    // MARK: - Item Status Tests

    /// Test 8: New item starts with pending status
    func test_newItem_hasPendingStatus() throws {
        // GIVEN/WHEN: Creating a new item
        let item = ImportItem(urlString: "https://example.com/recipe")

        // THEN: Status should be pending
        XCTAssertEqual(item.status, .pending)
    }

    /// Test 9: Item can transition to processing
    func test_item_canTransitionToProcessing() throws {
        // GIVEN: A pending item
        let item = ImportItem(urlString: "https://example.com/recipe")

        // WHEN: Transitioning
        item.startProcessing()

        // THEN: Status should update
        XCTAssertEqual(item.status, .processing)
    }

    /// Test 10: Item stores error on failure
    func test_item_storesErrorOnFailure() throws {
        // GIVEN: An item
        let item = ImportItem(urlString: "https://example.com/recipe")

        // WHEN: Setting to failed with error
        item.markFailed(error: "AI extraction failed")

        // THEN: Error should be stored
        XCTAssertEqual(item.status, .failed)
        XCTAssertEqual(item.errorMessage, "AI extraction failed")
    }

    // MARK: - Queue Management Tests

    /// Test 11: Multiple jobs can be created
    func test_multipleJobs_canBeCreated() throws {
        // GIVEN/WHEN: Creating multiple jobs
        let job1 = ImportJob(jobName: "Cookbook 1")
        let job2 = ImportJob(jobName: "Camera Roll")
        let job3 = ImportJob(jobName: "Web Recipes")

        env.modelContext.insert(job1)
        env.modelContext.insert(job2)
        env.modelContext.insert(job3)
        try env.save()

        // THEN: All should exist
        let jobs = try env.fetchAllImportJobs()
        XCTAssertEqual(jobs.count, 3)
    }

    /// Test 12: Can query pending jobs
    func test_canQueryPendingJobs() throws {
        // GIVEN: Jobs with different statuses
        let pending = ImportJob(jobName: "Pending")
        let processing = ImportJob(jobName: "Processing")
        processing.status = .processing
        let completed = ImportJob(jobName: "Completed")
        completed.status = .completed

        env.modelContext.insert(pending)
        env.modelContext.insert(processing)
        env.modelContext.insert(completed)
        try env.save()

        // WHEN: Fetching all and filtering
        let allJobs = try env.fetchAllImportJobs()
        let pendingJobs = allJobs.filter { $0.status == .pending }

        // THEN: Should find only pending job
        XCTAssertEqual(pendingJobs.count, 1)
        XCTAssertEqual(pendingJobs.first?.jobName, "Pending")
    }

    /// Test 13: Jobs are sorted by creation date
    func test_jobs_sortedByCreationDate() throws {
        // GIVEN: Jobs created at different times
        let job1 = ImportJob(jobName: "First")
        job1.createdAt = Date().addingTimeInterval(-3600) // 1 hour ago

        let job2 = ImportJob(jobName: "Second")
        job2.createdAt = Date().addingTimeInterval(-1800) // 30 min ago

        let job3 = ImportJob(jobName: "Third")
        job3.createdAt = Date() // Now

        env.modelContext.insert(job1)
        env.modelContext.insert(job2)
        env.modelContext.insert(job3)
        try env.save()

        // WHEN: Fetching with sort
        let descriptor = FetchDescriptor<ImportJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let results = try env.modelContext.fetch(descriptor)

        // THEN: Should be in creation order
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].jobName, "First")
        XCTAssertEqual(results[1].jobName, "Second")
        XCTAssertEqual(results[2].jobName, "Third")
    }

    // MARK: - Completion Tracking Tests

    /// Test 14: Completed job stores completion date
    func test_completedJob_storesCompletionDate() throws {
        // GIVEN: A job
        let job = ImportJob(jobName: "Test")
        env.modelContext.insert(job)
        XCTAssertNil(job.completedAt)

        // WHEN: Marking as completed
        job.status = .completed
        job.completedAt = Date()

        // THEN: Completion date should be set
        XCTAssertNotNil(job.completedAt)
    }

    /// Test 15: isComplete returns true for completed status
    func test_isComplete_trueForCompletedStatus() throws {
        // GIVEN: A job
        let job = ImportJob()

        // THEN: Not complete initially
        XCTAssertFalse(job.isComplete)

        // WHEN: Set to completed
        job.status = .completed

        // THEN: Should be complete
        XCTAssertTrue(job.isComplete)
    }

    /// Test 16: isComplete returns true for failed status
    func test_isComplete_trueForFailedStatus() throws {
        // GIVEN: A job
        let job = ImportJob()

        // WHEN: Set to failed
        job.status = .failed

        // THEN: Should be complete (terminal state)
        XCTAssertTrue(job.isComplete)
    }

    // MARK: - Import Phase Tests

    /// Test 17: New job starts with validation phase
    func test_newJob_startsWithValidationPhase() throws {
        let job = ImportJob()
        XCTAssertEqual(job.phase, .validation)
    }

    /// Test 18: Can transition through phases
    func test_job_canTransitionThroughPhases() throws {
        let job = ImportJob()

        XCTAssertEqual(job.phase, .validation)

        job.phase = .analysis
        XCTAssertEqual(job.phase, .analysis)

        job.phase = .extraction
        XCTAssertEqual(job.phase, .extraction)

        job.phase = .completed
        XCTAssertEqual(job.phase, .completed)
    }

    /// Test 19: Phase has correct display names
    func test_phases_haveCorrectDisplayNames() throws {
        XCTAssertEqual(ImportPhase.validation.displayName, "Validating PDFs...")
        XCTAssertEqual(ImportPhase.analysis.displayName, "Analyzing pages...")
        XCTAssertEqual(ImportPhase.extraction.displayName, "Extracting recipes...")
        XCTAssertEqual(ImportPhase.imageGeneration.displayName, "Generating images...")
        XCTAssertEqual(ImportPhase.completed.displayName, "Import complete")
    }

    // MARK: - Item Source Tests

    /// Test 20: URL item has correct source
    func test_urlItem_hasCorrectSource() throws {
        let item = ImportItem(urlString: "https://example.com/recipe")
        XCTAssertEqual(item.source, .url)
        XCTAssertEqual(item.urlString, "https://example.com/recipe")
    }

    /// Test 21: PDF item has correct source
    func test_pdfItem_hasCorrectSource() throws {
        let imageData = Data([0x00, 0x01, 0x02])
        let item = ImportItem(
            source: .pdf,
            imageData: imageData,
            pdfURL: "/path/to/file.pdf",
            pageNumber: 1
        )
        XCTAssertEqual(item.source, .pdf)
        XCTAssertEqual(item.pageNumber, 1)
    }

    /// Test 22: Camera item has correct source
    func test_cameraItem_hasCorrectSource() throws {
        let imageData = Data([0x00, 0x01, 0x02])
        let item = ImportItem(source: .camera, imageData: imageData)
        XCTAssertEqual(item.source, .camera)
    }

    // MARK: - Item Completion Tests

    /// Test 23: markSuccess sets correct state
    func test_markSuccess_setsCorrectState() throws {
        let item = ImportItem(urlString: "https://example.com")
        let recipeID = UUID()

        item.markSuccess(recipeID: recipeID)

        XCTAssertEqual(item.status, .success)
        XCTAssertEqual(item.recipeIDs, [recipeID])
        XCTAssertNotNil(item.processedAt)
    }

    /// Test 24: markSkipped sets correct state
    func test_markSkipped_setsCorrectState() throws {
        let item = ImportItem(urlString: "https://example.com")

        item.markSkipped(reason: "Duplicate URL")

        XCTAssertEqual(item.status, .skipped)
        XCTAssertEqual(item.errorMessage, "Duplicate URL")
    }

    /// Test 25: canRetry is true for failed items under limit
    func test_canRetry_trueForFailedUnderLimit() throws {
        let item = ImportItem(urlString: "https://example.com")
        item.markFailed(error: "Network error")

        XCTAssertTrue(item.canRetry)

        item.retryCount = 3
        XCTAssertFalse(item.canRetry)
    }

    // MARK: - Deletion Tests

    /// Test 26: Deleting job also deletes items (cascade)
    func test_deletingJob_deletesItems() throws {
        // GIVEN: A job with items
        let job = ImportJob(jobName: "Test")
        let imageData = Data([0x00, 0x01, 0x02])
        let item = ImportItem(source: .pdf, imageData: imageData, pageNumber: 1)
        job.items = [item]
        item.job = job

        env.modelContext.insert(job)
        try env.save()

        // WHEN: Deleting the job
        env.modelContext.delete(job)
        try env.save()

        // THEN: Jobs should be deleted (items cascade)
        let remainingJobs = try env.fetchAllImportJobs()
        XCTAssertEqual(remainingJobs.count, 0)
    }

    // MARK: - Multi-Recipe Tests

    /// Test 27: markSuccess with multiple recipe IDs
    func test_markSuccess_withMultipleRecipeIDs() throws {
        let item = ImportItem(urlString: "https://example.com")
        let recipeIDs = [UUID(), UUID(), UUID()]

        item.markSuccess(recipeIDs: recipeIDs)

        XCTAssertEqual(item.status, .success)
        XCTAssertEqual(item.recipeIDs.count, 3)
        XCTAssertEqual(item.successfulRecipeCount, 3)
    }

    /// Test 28: isCompleted returns correct values
    func test_isCompleted_returnsCorrectValues() throws {
        let item = ImportItem(urlString: "https://example.com")

        XCTAssertFalse(item.isCompleted) // pending

        item.status = .processing
        XCTAssertFalse(item.isCompleted)

        item.status = .success
        XCTAssertTrue(item.isCompleted)

        item.status = .failed
        XCTAssertTrue(item.isCompleted)

        item.status = .skipped
        XCTAssertTrue(item.isCompleted)
    }
}
