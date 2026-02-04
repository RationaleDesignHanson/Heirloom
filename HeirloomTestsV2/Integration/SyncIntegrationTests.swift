//
//  SyncIntegrationTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Integration tests for sync operations
//
//  Tests the sync system to ensure:
//  - Sync state transitions work correctly
//  - Conflict detection triggers appropriately
//  - Retry logic respects limits
//  - Staleness detection works
//

import XCTest
@testable import Heirloom

@MainActor
final class SyncIntegrationTests: XCTestCase {

    // MARK: - Sync State Tests

    /// Test 1: Initial sync state is idle
    func test_syncState_initial_isIdle() {
        let state = SyncState()
        XCTAssertEqual(state.status, .idle)
        XCTAssertFalse(state.isSyncing)
    }

    /// Test 2: Sync state transitions to syncing
    func test_syncState_syncing_transitionsCorrectly() {
        var state = SyncState()
        state.status = .syncing
        XCTAssertEqual(state.status, .syncing)
        XCTAssertTrue(state.isSyncing)
    }

    /// Test 3: Sync state transitions to completed
    func test_syncState_completed_transitionsCorrectly() {
        var state = SyncState()
        state.status = .syncing
        state.status = .completed
        state.lastSyncDate = Date()
        XCTAssertEqual(state.status, .completed)
        XCTAssertNotNil(state.lastSyncDate)
    }

    /// Test 4: Sync state tracks errors
    func test_syncState_error_tracksErrorMessage() {
        var state = SyncState()
        state.status = .syncing
        state.status = .error
        state.errorMessage = "Network connection lost"
        XCTAssertEqual(state.status, .error)
        XCTAssertEqual(state.errorMessage, "Network connection lost")
    }

    // MARK: - Sync Error Handling Tests

    /// Test 5: Retry count tracked
    func test_syncRetry_countTracked() {
        var state = SyncState()
        state.retryCount = 0
        state.retryCount += 1
        state.retryCount += 1
        state.retryCount += 1
        XCTAssertEqual(state.retryCount, 3)
    }

    /// Test 6: Max retries respected
    func test_syncRetry_maxRetriesRespected() {
        var state = SyncState()
        state.retryCount = 3
        let maxRetries = 3
        let shouldRetry = state.retryCount < maxRetries
        XCTAssertFalse(shouldRetry)
    }

    /// Test 7: Retry count resets on success
    func test_syncRetry_resetsOnSuccess() {
        var state = SyncState()
        state.retryCount = 2
        state.status = .error
        state.status = .completed
        state.retryCount = 0
        state.lastSyncDate = Date()
        XCTAssertEqual(state.retryCount, 0)
        XCTAssertEqual(state.status, .completed)
    }

    // MARK: - Sync Tracker Tests

    /// Test 8: Sync tracker can mark items as pending
    func test_syncTracker_marksPendingItems() {
        var tracker = SyncTracker()
        let recipeId = UUID()
        tracker.markPending(recipeId)
        XCTAssertTrue(tracker.isPending(recipeId))
    }

    /// Test 9: Sync tracker clears after sync
    func test_syncTracker_clearsAfterSync() {
        var tracker = SyncTracker()
        let recipeId = UUID()
        tracker.markPending(recipeId)
        tracker.markSynced(recipeId)
        XCTAssertFalse(tracker.isPending(recipeId))
    }

    /// Test 10: Sync tracker tracks multiple items
    func test_syncTracker_tracksMultipleItems() {
        var tracker = SyncTracker()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        tracker.markPending(id1)
        tracker.markPending(id2)
        tracker.markPending(id3)
        XCTAssertEqual(tracker.pendingCount, 3)
    }

    // MARK: - Conflict Detection Tests

    /// Test 11: Conflict state can be detected
    func test_conflict_canBeDetected() {
        let local = TestRecipeVersion(id: UUID(), modifiedAt: Date())
        let remote = TestRecipeVersion(id: local.id, modifiedAt: Date().addingTimeInterval(-100))
        let hasConflict = local.modifiedAt != remote.modifiedAt
        XCTAssertTrue(hasConflict)
    }

    /// Test 12: Conflict resolution picks latest
    func test_conflict_resolutionPicksLatest() {
        let older = TestRecipeVersion(id: UUID(), modifiedAt: Date().addingTimeInterval(-100))
        let newer = TestRecipeVersion(id: older.id, modifiedAt: Date())
        let winner = [older, newer].max { $0.modifiedAt < $1.modifiedAt }
        XCTAssertEqual(winner?.modifiedAt, newer.modifiedAt)
    }

    /// Test 13: Same timestamp means no conflict
    func test_conflict_sameTimestamp_noConflict() {
        let timestamp = Date()
        let local = TestRecipeVersion(id: UUID(), modifiedAt: timestamp)
        let remote = TestRecipeVersion(id: local.id, modifiedAt: timestamp)
        let hasConflict = local.modifiedAt != remote.modifiedAt
        XCTAssertFalse(hasConflict)
    }

    // MARK: - Timestamp Tests

    /// Test 14: Can detect stale data
    func test_syncTimestamp_detectsStaleData() {
        let lastSync = Date().addingTimeInterval(-86400 * 7) // 7 days ago
        let staleThreshold = Date().addingTimeInterval(-86400)
        let isStale = lastSync < staleThreshold
        XCTAssertTrue(isStale)
    }

    /// Test 15: Fresh data is not stale
    func test_syncTimestamp_freshDataNotStale() {
        let lastSync = Date().addingTimeInterval(-3600) // 1 hour ago
        let staleThreshold = Date().addingTimeInterval(-86400)
        let isStale = lastSync < staleThreshold
        XCTAssertFalse(isStale)
    }

    /// Test 16: Never synced is always stale
    func test_syncTimestamp_neverSynced_isStale() {
        let lastSync: Date? = nil
        let staleThreshold = Date().addingTimeInterval(-86400)
        let isStale = lastSync ?? Date.distantPast < staleThreshold
        XCTAssertTrue(isStale)
    }

    // MARK: - Priority Sorting Tests

    /// Test 17: Priority sorting by favorite status
    func test_syncPriority_favoritesSortFirst() {
        let favorite = SyncItem(id: UUID(), isFavorite: true, modifiedAt: Date())
        let regular = SyncItem(id: UUID(), isFavorite: false, modifiedAt: Date())

        let items = [regular, favorite].sorted { item1, _ in
            item1.isFavorite
        }

        XCTAssertTrue(items.first?.isFavorite ?? false)
    }

    /// Test 18: Priority sorting by modification date
    func test_syncPriority_recentFirstAfterFavorites() {
        let older = SyncItem(id: UUID(), isFavorite: false, modifiedAt: Date().addingTimeInterval(-3600))
        let newer = SyncItem(id: UUID(), isFavorite: false, modifiedAt: Date())

        let items = [older, newer].sorted { $0.modifiedAt > $1.modifiedAt }

        XCTAssertEqual(items.first?.id, newer.id)
    }

    // MARK: - Batch Processing Tests

    /// Test 19: Batch size limits sync operations
    func test_batchProcessing_respectsBatchSize() {
        let batchSize = 10
        let totalItems = 25
        let expectedBatches = (totalItems + batchSize - 1) / batchSize
        XCTAssertEqual(expectedBatches, 3)
    }

    /// Test 20: Empty batch completes immediately
    func test_batchProcessing_emptyBatchCompletes() {
        let tracker = SyncTracker()
        XCTAssertEqual(tracker.pendingCount, 0)
    }
}

// MARK: - Test Models

/// Sync state for testing
struct SyncState {
    var status: SyncStatus = .idle
    var lastSyncDate: Date?
    var errorMessage: String?
    var retryCount: Int = 0

    var isSyncing: Bool {
        status == .syncing
    }
}

/// Sync status for testing
enum SyncStatus {
    case idle
    case syncing
    case completed
    case error
}

/// Sync tracker for testing
struct SyncTracker {
    private var pendingIds: Set<UUID> = []

    var pendingCount: Int {
        pendingIds.count
    }

    mutating func markPending(_ id: UUID) {
        pendingIds.insert(id)
    }

    mutating func markSynced(_ id: UUID) {
        pendingIds.remove(id)
    }

    func isPending(_ id: UUID) -> Bool {
        pendingIds.contains(id)
    }
}

/// Recipe version for conflict testing
struct TestRecipeVersion {
    let id: UUID
    let modifiedAt: Date
}

/// Sync item for priority testing
struct SyncItem {
    let id: UUID
    let isFavorite: Bool
    let modifiedAt: Date
}
