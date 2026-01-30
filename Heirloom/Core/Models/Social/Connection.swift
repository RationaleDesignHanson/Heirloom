//
//  Connection.swift
//  Heirloom
//
//  Social Layer Phase 2: Connection Model
//  Represents bidirectional connections (friendships) between users
//

import Foundation

/// Connection between two users
/// Stored in Firestore at users/{userId}/connections/{connectionId}
/// Bidirectional: Both users have a connection document pointing to each other
struct Connection: Codable, Identifiable {
    // MARK: - Identity

    /// Unique ID for this connection
    let id: String

    /// The current user's ID (owner of this connection document)
    let userId: String

    /// The connected user's ID
    let connectedUserId: String

    /// Display name of connected user (denormalized for quick access)
    var connectedUserDisplayName: String

    /// Photo URL of connected user (denormalized)
    var connectedUserPhotoURL: String?

    /// Handle of connected user (for @mentions)
    var connectedUserHandle: String?

    // MARK: - Connection Details

    /// Current status of the connection
    var status: ConnectionStatus

    /// Who initiated the connection request
    let initiatedBy: String

    /// When the connection request was sent
    let requestedAt: Date

    /// When the connection was accepted (if status is .connected)
    var acceptedAt: Date?

    /// When the connection was last rejected (if status is .rejected)
    var rejectedAt: Date?

    // MARK: - Kitchen Table Context

    /// Kitchen Table ID where this connection originated (if applicable)
    /// Helps identify connections from same cooking groups
    var sourceKitchenTableId: String?

    /// Whether this connection is from the same Kitchen Table
    var isKitchenTableConnection: Bool

    // MARK: - Interaction Metadata

    /// Number of recipes shared with this connection
    var recipesSharedCount: Int

    /// Number of recipes received from this connection
    var recipesReceivedCount: Int

    /// Last time a recipe was shared with this connection
    var lastRecipeSharedAt: Date?

    /// Last time this connection was interacted with
    var lastInteractionAt: Date?

    // MARK: - Favorites & Notes

    /// Whether this connection is marked as favorite/close friend
    var isFavorite: Bool

    /// Private note about this connection (only visible to user)
    var privateNote: String?

    // MARK: - Metadata

    /// When this connection document was created
    let createdAt: Date

    /// When this connection document was last updated
    var updatedAt: Date

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case connectedUserId
        case connectedUserDisplayName
        case connectedUserPhotoURL
        case connectedUserHandle
        case status
        case initiatedBy
        case requestedAt
        case acceptedAt
        case rejectedAt
        case sourceKitchenTableId
        case isKitchenTableConnection
        case recipesSharedCount
        case recipesReceivedCount
        case lastRecipeSharedAt
        case lastInteractionAt
        case isFavorite
        case privateNote
        case createdAt
        case updatedAt
    }

    // MARK: - Initialization

    /// Simple initializer for creating new connections
    init(
        id: String,
        userId: String,
        connectedUserId: String,
        connectedUserDisplayName: String,
        initiatedBy: String,
        sourceKitchenTableId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.connectedUserId = connectedUserId
        self.connectedUserDisplayName = connectedUserDisplayName
        self.connectedUserPhotoURL = nil
        self.connectedUserHandle = nil
        self.status = .pending
        self.initiatedBy = initiatedBy
        self.requestedAt = Date()
        self.acceptedAt = nil
        self.rejectedAt = nil
        self.sourceKitchenTableId = sourceKitchenTableId
        self.isKitchenTableConnection = sourceKitchenTableId != nil
        self.recipesSharedCount = 0
        self.recipesReceivedCount = 0
        self.lastRecipeSharedAt = nil
        self.lastInteractionAt = nil
        self.isFavorite = false
        self.privateNote = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Full initializer for all fields (used by services)
    init(
        id: String,
        userId: String,
        connectedUserId: String,
        connectedUserDisplayName: String,
        connectedUserPhotoURL: String?,
        status: ConnectionStatus,
        initiatedBy: String,
        requestedAt: Date,
        acceptedAt: Date?,
        sourceKitchenTableId: String?,
        recipesSharedCount: Int,
        recipesReceivedCount: Int,
        isFavorite: Bool,
        privateNote: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.connectedUserId = connectedUserId
        self.connectedUserDisplayName = connectedUserDisplayName
        self.connectedUserPhotoURL = connectedUserPhotoURL
        self.connectedUserHandle = nil
        self.status = status
        self.initiatedBy = initiatedBy
        self.requestedAt = requestedAt
        self.acceptedAt = acceptedAt
        self.rejectedAt = nil
        self.sourceKitchenTableId = sourceKitchenTableId
        self.isKitchenTableConnection = sourceKitchenTableId != nil
        self.recipesSharedCount = recipesSharedCount
        self.recipesReceivedCount = recipesReceivedCount
        self.lastRecipeSharedAt = nil
        self.lastInteractionAt = nil
        self.isFavorite = isFavorite
        self.privateNote = privateNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Connection Status

enum ConnectionStatus: String, Codable {
    case pending    // Request sent, awaiting response
    case connected  // Request accepted, fully connected
    case rejected   // Request rejected by recipient
    case blocked    // User has blocked this connection
}

// MARK: - Helper Extensions

extension Connection {
    /// Whether this connection can share recipes
    var canShareRecipes: Bool {
        return status == .connected
    }

    /// Whether this connection request is outgoing (sent by this user)
    var isOutgoingRequest: Bool {
        return initiatedBy == userId && status == .pending
    }

    /// Whether this connection request is incoming (received by this user)
    var isIncomingRequest: Bool {
        return initiatedBy == connectedUserId && status == .pending
    }

    /// Whether this is an active connection
    var isActive: Bool {
        return status == .connected
    }

    /// Whether this connection can be accepted
    var canAccept: Bool {
        return isIncomingRequest
    }

    /// Formatted display text for connection status
    var statusDisplayText: String {
        switch status {
        case .pending:
            return isOutgoingRequest ? "Request Sent" : "Pending Approval"
        case .connected:
            return "Connected"
        case .rejected:
            return "Declined"
        case .blocked:
            return "Blocked"
        }
    }

    /// Formatted text for when connection was established
    var connectionDateText: String? {
        guard let acceptedAt = acceptedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Connected \(formatter.localizedString(for: acceptedAt, relativeTo: Date()))"
    }
}

// MARK: - Sorting & Filtering

extension Connection {
    /// Sort comparator for displaying connections
    static func sortByRecency(_ lhs: Connection, _ rhs: Connection) -> Bool {
        let lhsDate = lhs.lastInteractionAt ?? lhs.acceptedAt ?? lhs.createdAt
        let rhsDate = rhs.lastInteractionAt ?? rhs.acceptedAt ?? rhs.createdAt
        return lhsDate > rhsDate
    }

    /// Sort comparator for favorites first, then by recency
    static func sortByFavoritesThenRecency(_ lhs: Connection, _ rhs: Connection) -> Bool {
        if lhs.isFavorite != rhs.isFavorite {
            return lhs.isFavorite
        }
        return sortByRecency(lhs, rhs)
    }

    /// Sort comparator by name
    static func sortByName(_ lhs: Connection, _ rhs: Connection) -> Bool {
        return lhs.connectedUserDisplayName.localizedCaseInsensitiveCompare(rhs.connectedUserDisplayName) == .orderedAscending
    }
}
