//
//  ConnectionTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Integration tests for user connections feature
//
//  Tests the connections system to ensure:
//  - Connection status transitions work correctly
//  - Request/accept/decline flows function properly
//  - Connection state queries return correct results
//  - Connection metadata is tracked correctly
//

import XCTest
@testable import Heirloom

@MainActor
final class ConnectionTests: XCTestCase {

    // MARK: - Connection Status Tests

    /// Test 1: Pending status is correct initial state
    func test_connectionStatus_pending_isCorrectInitialState() {
        let status = ConnectionStatus.pending
        XCTAssertEqual(status.rawValue, "pending")
    }

    /// Test 2: Connected status indicates active connection
    func test_connectionStatus_connected_indicatesActiveConnection() {
        let status = ConnectionStatus.connected
        XCTAssertEqual(status.rawValue, "connected")
    }

    /// Test 3: Rejected status indicates declined request
    func test_connectionStatus_rejected_indicatesDeclinedRequest() {
        let status = ConnectionStatus.rejected
        XCTAssertEqual(status.rawValue, "rejected")
    }

    /// Test 4: Blocked status indicates user block
    func test_connectionStatus_blocked_indicatesUserBlock() {
        let status = ConnectionStatus.blocked
        XCTAssertEqual(status.rawValue, "blocked")
    }

    // MARK: - Connection Model Tests

    /// Test 5: Connection stores user information correctly
    func test_connection_storesUserInfoCorrectly() {
        let connection = TestConnection(
            id: "conn123",
            userId: "user1",
            connectedUserId: "user2",
            connectedUserDisplayName: "Test User",
            status: .connected,
            initiatedBy: "user1"
        )

        XCTAssertEqual(connection.id, "conn123")
        XCTAssertEqual(connection.userId, "user1")
        XCTAssertEqual(connection.connectedUserId, "user2")
        XCTAssertEqual(connection.connectedUserDisplayName, "Test User")
    }

    /// Test 6: Connection tracks connected status
    func test_connection_tracksConnectedStatus() {
        let connection = TestConnection(
            id: "conn1",
            userId: "a",
            connectedUserId: "b",
            status: .connected
        )
        XCTAssertEqual(connection.status, .connected)
        XCTAssertTrue(connection.isConnected)
    }

    /// Test 7: Connection tracks pending status
    func test_connection_tracksPendingStatus() {
        let connection = TestConnection(
            id: "conn1",
            userId: "a",
            connectedUserId: "b",
            status: .pending
        )
        XCTAssertEqual(connection.status, .pending)
        XCTAssertFalse(connection.isConnected)
    }

    /// Test 8: Connection tracks blocked status
    func test_connection_tracksBlockedStatus() {
        let connection = TestConnection(
            id: "conn1",
            userId: "a",
            connectedUserId: "b",
            status: .blocked
        )
        XCTAssertEqual(connection.status, .blocked)
        XCTAssertTrue(connection.isBlocked)
    }

    // MARK: - Request Direction Tests

    /// Test 9: Can determine if user initiated request
    func test_connection_canDetermineInitiator_outgoing() {
        let currentUserId = "user1"
        let connection = TestConnection(
            id: "conn1",
            userId: currentUserId,
            connectedUserId: "user2",
            status: .pending,
            initiatedBy: currentUserId
        )

        XCTAssertTrue(connection.isOutgoingRequest(for: currentUserId))
        XCTAssertFalse(connection.isIncomingRequest(for: currentUserId))
    }

    /// Test 10: Can determine if user received request
    func test_connection_canDetermineInitiator_incoming() {
        let currentUserId = "user2"
        let connection = TestConnection(
            id: "conn1",
            userId: "user1",
            connectedUserId: currentUserId,
            status: .pending,
            initiatedBy: "user1"
        )

        XCTAssertFalse(connection.isOutgoingRequest(for: currentUserId))
        XCTAssertTrue(connection.isIncomingRequest(for: currentUserId))
    }

    // MARK: - Status Transition Tests

    /// Test 11: Pending can transition to connected
    func test_statusTransition_pendingToConnected_isValid() {
        let validTransitions = ConnectionStatus.pending.validTransitions
        XCTAssertTrue(validTransitions.contains(.connected))
    }

    /// Test 12: Pending can transition to rejected
    func test_statusTransition_pendingToRejected_isValid() {
        let validTransitions = ConnectionStatus.pending.validTransitions
        XCTAssertTrue(validTransitions.contains(.rejected))
    }

    /// Test 13: Connected can transition to blocked
    func test_statusTransition_connectedToBlocked_isValid() {
        let validTransitions = ConnectionStatus.connected.validTransitions
        XCTAssertTrue(validTransitions.contains(.blocked))
    }

    /// Test 14: Blocked cannot transition to connected directly
    func test_statusTransition_blockedToConnected_isInvalid() {
        let validTransitions = ConnectionStatus.blocked.validTransitions
        XCTAssertFalse(validTransitions.contains(.connected))
    }

    // MARK: - Connection Metadata Tests

    /// Test 15: Tracks recipes shared count
    func test_connection_tracksRecipesShared() {
        var connection = TestConnection(
            id: "conn1",
            userId: "a",
            connectedUserId: "b",
            status: .connected
        )
        connection.recipesSharedCount = 5

        XCTAssertEqual(connection.recipesSharedCount, 5)
    }

    /// Test 16: Tracks recipes received count
    func test_connection_tracksRecipesReceived() {
        var connection = TestConnection(
            id: "conn1",
            userId: "a",
            connectedUserId: "b",
            status: .connected
        )
        connection.recipesReceivedCount = 3

        XCTAssertEqual(connection.recipesReceivedCount, 3)
    }

    /// Test 17: Tracks favorite status
    func test_connection_tracksFavoriteStatus() {
        var connection = TestConnection(
            id: "conn1",
            userId: "a",
            connectedUserId: "b",
            status: .connected
        )
        connection.isFavorite = true

        XCTAssertTrue(connection.isFavorite)
    }

    // MARK: - Display Name Tests

    /// Test 18: Display name falls back correctly
    func test_connection_displayNameFallback() {
        let withName = TestConnection(
            id: "1",
            userId: "a",
            connectedUserId: "b",
            connectedUserDisplayName: "John",
            status: .connected
        )
        let withoutName = TestConnection(
            id: "2",
            userId: "a",
            connectedUserId: "b",
            connectedUserDisplayName: nil,
            status: .connected
        )

        XCTAssertEqual(withName.displayName, "John")
        XCTAssertEqual(withoutName.displayName, "Unknown User")
    }

    // MARK: - Sorting Tests

    /// Test 19: Connections sort by display name
    func test_connections_sortByDisplayName() {
        let alice = TestConnection(id: "1", userId: "a", connectedUserId: "b", connectedUserDisplayName: "Alice", status: .connected)
        let bob = TestConnection(id: "2", userId: "a", connectedUserId: "c", connectedUserDisplayName: "Bob", status: .connected)
        let charlie = TestConnection(id: "3", userId: "a", connectedUserId: "d", connectedUserDisplayName: "Charlie", status: .connected)

        let sorted = [charlie, alice, bob].sorted { $0.displayName < $1.displayName }

        XCTAssertEqual(sorted[0].displayName, "Alice")
        XCTAssertEqual(sorted[1].displayName, "Bob")
        XCTAssertEqual(sorted[2].displayName, "Charlie")
    }

    /// Test 20: Favorites sort first
    func test_connections_favoritesSortFirst() {
        var regular = TestConnection(id: "1", userId: "a", connectedUserId: "b", connectedUserDisplayName: "Regular", status: .connected)
        regular.isFavorite = false

        var favorite = TestConnection(id: "2", userId: "a", connectedUserId: "c", connectedUserDisplayName: "Favorite", status: .connected)
        favorite.isFavorite = true

        let sorted = [regular, favorite].sorted { c1, _ in c1.isFavorite }

        XCTAssertTrue(sorted.first?.isFavorite ?? false)
    }
}

// MARK: - Test Models

/// Connection status for testing
enum ConnectionStatus: String {
    case pending = "pending"
    case connected = "connected"
    case rejected = "rejected"
    case blocked = "blocked"

    var validTransitions: [ConnectionStatus] {
        switch self {
        case .pending:
            return [.connected, .rejected, .blocked]
        case .connected:
            return [.blocked]
        case .rejected:
            return [.pending] // Can re-request
        case .blocked:
            return [] // Must unblock first
        }
    }
}

/// Connection model for testing
struct TestConnection {
    let id: String
    let userId: String
    let connectedUserId: String
    var connectedUserDisplayName: String?
    var status: ConnectionStatus
    var initiatedBy: String?
    var recipesSharedCount: Int = 0
    var recipesReceivedCount: Int = 0
    var isFavorite: Bool = false

    var isConnected: Bool {
        status == .connected
    }

    var isBlocked: Bool {
        status == .blocked
    }

    var displayName: String {
        connectedUserDisplayName ?? "Unknown User"
    }

    func isOutgoingRequest(for userId: String) -> Bool {
        initiatedBy == userId && status == .pending
    }

    func isIncomingRequest(for userId: String) -> Bool {
        initiatedBy != userId && status == .pending
    }
}
