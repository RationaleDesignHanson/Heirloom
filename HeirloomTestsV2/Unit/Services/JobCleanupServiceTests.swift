//
//  JobCleanupServiceTests.swift
//  HeirloomTestsV2
//
//  Unit tests for JobCleanupService
//  Tests cleanup of stale jobs, orphaned files, and retention policies
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class JobCleanupServiceTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!
    var cleanupService: JobCleanupService!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create()
        cleanupService = JobCleanupService()

        // Register ImageStorageService in shared container for cleanup tests
        // JobCleanupService uses ServiceContainer.shared.resolve() internally
        let imageCache = ImageCache()
        let imageStorageService = ImageStorageService(imageCache: imageCache)
        ServiceContainer.shared.register(ImageStorageService.self, instance: imageStorageService)
    }

    override func tearDown() async throws {
        // Clean up the registered service
        ServiceContainer.shared.reset()
        env.tearDown()
        env = nil
        cleanupService = nil
        try await super.tearDown()
    }

    // MARK: - Retention Policy Tests

    /// Test 1: Failed job retention is 7 days
    func test_retentionPolicy_failedJobs_is7Days() {
        XCTAssertEqual(JobCleanupService.failedJobRetentionDays, 7)
    }

    /// Test 2: Completed job retention is 90 days
    func test_retentionPolicy_completedJobs_is90Days() {
        XCTAssertEqual(JobCleanupService.completedJobRetentionDays, 90)
    }

    /// Test 3: App Group temp file retention is 30 days
    func test_retentionPolicy_appGroupTempFiles_is30Days() {
        XCTAssertEqual(JobCleanupService.appGroupTempFileRetentionDays, 30)
    }

    // MARK: - Video Processing Job Cleanup Tests

    /// Test 4: Pending video jobs are not deleted
    func test_videoJobCleanup_pendingJob_notDeleted() async throws {
        // GIVEN: A pending video job from 30 days ago
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        env.createVideoProcessingJob(status: .pending, createdAt: thirtyDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should still exist (pending jobs are never deleted)
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 1)
    }

    /// Test 5: Processing video jobs are not deleted
    func test_videoJobCleanup_processingJob_notDeleted() async throws {
        // GIVEN: A processing video job from 30 days ago
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        env.createVideoProcessingJob(status: .processing, createdAt: thirtyDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should still exist
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 1)
    }

    /// Test 6: Failed video job older than 7 days is deleted
    func test_videoJobCleanup_failedJobOlderThan7Days_deleted() async throws {
        // GIVEN: A failed video job from 10 days ago
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        env.createVideoProcessingJob(status: .failed, createdAt: tenDaysAgo, completedAt: tenDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should be deleted
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 0)
    }

    /// Test 7: Failed video job within 7 days is NOT deleted
    func test_videoJobCleanup_failedJobWithin7Days_notDeleted() async throws {
        // GIVEN: A failed video job from 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        env.createVideoProcessingJob(status: .failed, createdAt: threeDaysAgo, completedAt: threeDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should still exist
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 1)
    }

    /// Test 8: Cancelled video job older than 7 days is deleted
    func test_videoJobCleanup_cancelledJobOlderThan7Days_deleted() async throws {
        // GIVEN: A cancelled video job from 10 days ago
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        env.createVideoProcessingJob(status: .cancelled, createdAt: tenDaysAgo, completedAt: tenDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should be deleted
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 0)
    }

    /// Test 9: Completed video job older than 90 days is deleted
    func test_videoJobCleanup_completedJobOlderThan90Days_deleted() async throws {
        // GIVEN: A completed video job from 100 days ago
        let hundredDaysAgo = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        env.createVideoProcessingJob(status: .completed, createdAt: hundredDaysAgo, completedAt: hundredDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should be deleted
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 0)
    }

    /// Test 10: Completed video job within 90 days is NOT deleted
    func test_videoJobCleanup_completedJobWithin90Days_notDeleted() async throws {
        // GIVEN: A completed video job from 30 days ago
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        env.createVideoProcessingJob(status: .completed, createdAt: thirtyDaysAgo, completedAt: thirtyDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should still exist
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 1)
    }

    /// Test 11: Saved video job older than 90 days is deleted
    func test_videoJobCleanup_savedJobOlderThan90Days_deleted() async throws {
        // GIVEN: A saved video job from 100 days ago
        let hundredDaysAgo = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        env.createVideoProcessingJob(status: .saved, createdAt: hundredDaysAgo, completedAt: hundredDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should be deleted
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 0)
    }

    // MARK: - Import Job Cleanup Tests

    /// Test 12: Pending import jobs are not deleted
    func test_importJobCleanup_pendingJob_notDeleted() async throws {
        // GIVEN: A pending import job from 30 days ago
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        env.createImportJob(status: .pending, createdAt: thirtyDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should still exist
        let jobs = try env.fetchAllImportJobs()
        XCTAssertEqual(jobs.count, 1)
    }

    /// Test 13: Failed import job older than 7 days is deleted
    func test_importJobCleanup_failedJobOlderThan7Days_deleted() async throws {
        // GIVEN: A failed import job from 10 days ago
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        env.createImportJob(status: .failed, createdAt: tenDaysAgo, completedAt: tenDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should be deleted
        let jobs = try env.fetchAllImportJobs()
        XCTAssertEqual(jobs.count, 0)
    }

    /// Test 14: Completed import job older than 90 days is deleted
    func test_importJobCleanup_completedJobOlderThan90Days_deleted() async throws {
        // GIVEN: A completed import job from 100 days ago
        let hundredDaysAgo = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        env.createImportJob(status: .completed, createdAt: hundredDaysAgo, completedAt: hundredDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should be deleted
        let jobs = try env.fetchAllImportJobs()
        XCTAssertEqual(jobs.count, 0)
    }

    /// Test 15: Completed import job within 90 days is NOT deleted
    func test_importJobCleanup_completedJobWithin90Days_notDeleted() async throws {
        // GIVEN: A completed import job from 30 days ago
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        env.createImportJob(status: .completed, createdAt: thirtyDaysAgo, completedAt: thirtyDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should still exist
        let jobs = try env.fetchAllImportJobs()
        XCTAssertEqual(jobs.count, 1)
    }

    // MARK: - Mixed Cleanup Tests

    /// Test 16: Cleanup handles multiple jobs with different statuses
    func test_cleanup_multipleJobs_correctlyFilters() async throws {
        // GIVEN: Mix of jobs with different statuses and ages
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let hundredDaysAgo = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!

        // Should be deleted (failed, older than 7 days)
        env.createVideoProcessingJob(status: .failed, createdAt: tenDaysAgo, completedAt: tenDaysAgo)

        // Should be deleted (completed, older than 90 days)
        env.createVideoProcessingJob(status: .completed, createdAt: hundredDaysAgo, completedAt: hundredDaysAgo)

        // Should NOT be deleted (failed, within 7 days)
        env.createVideoProcessingJob(status: .failed, createdAt: threeDaysAgo, completedAt: threeDaysAgo)

        // Should NOT be deleted (pending, never deleted)
        env.createVideoProcessingJob(status: .pending, createdAt: hundredDaysAgo)

        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Should have 2 jobs remaining
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 2)

        // Verify correct jobs remain
        let statuses = jobs.map { $0.status }
        XCTAssertTrue(statuses.contains(.failed))  // Recent failed job
        XCTAssertTrue(statuses.contains(.pending)) // Pending job
    }

    /// Test 17: Cleanup runs without errors on empty database
    func test_cleanup_emptyDatabase_runsWithoutError() async throws {
        // GIVEN: Empty database
        let videoJobs = try env.fetchAllVideoProcessingJobs()
        let importJobs = try env.fetchAllImportJobs()
        XCTAssertEqual(videoJobs.count, 0)
        XCTAssertEqual(importJobs.count, 0)

        // WHEN/THEN: Cleanup should not throw
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // Verify still empty
        let videoJobsAfter = try env.fetchAllVideoProcessingJobs()
        let importJobsAfter = try env.fetchAllImportJobs()
        XCTAssertEqual(videoJobsAfter.count, 0)
        XCTAssertEqual(importJobsAfter.count, 0)
    }

    // MARK: - Edge Cases

    /// Test 18: Job with nil completedAt uses createdAt for age calculation
    func test_cleanup_nilCompletedAt_usesCreatedAt() async throws {
        // GIVEN: A failed job with nil completedAt, createdAt 10 days ago
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        env.createVideoProcessingJob(status: .failed, createdAt: tenDaysAgo, completedAt: nil)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should be deleted (uses createdAt for age)
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 0)
    }

    /// Test 19: Paused video jobs are not deleted
    func test_videoJobCleanup_pausedJob_notDeleted() async throws {
        // GIVEN: A paused video job from 100 days ago
        let hundredDaysAgo = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        env.createVideoProcessingJob(status: .paused, createdAt: hundredDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should still exist (paused jobs are active, not deleted)
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 1)
    }

    /// Test 20: Job just within retention boundary is NOT deleted
    func test_cleanup_withinBoundary_notDeleted() async throws {
        // GIVEN: A failed job from 6 days, 23 hours ago (just within 7 day boundary)
        // Use 6 days to avoid race condition at exact boundary
        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        env.createVideoProcessingJob(status: .failed, createdAt: sixDaysAgo, completedAt: sixDaysAgo)
        try env.save()

        // WHEN: Running cleanup
        await cleanupService.performDailyCleanup(context: env.modelContext)

        // THEN: Job should still exist (within retention period)
        let jobs = try env.fetchAllVideoProcessingJobs()
        XCTAssertEqual(jobs.count, 1)
    }
}
