//
//  ConnectionService.swift
//  Heirloom
//
//  Social Layer Phase 3: Connection Service
//  Manages bidirectional connections (friendships) between users
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Protocol

/// Protocol for connection management
@MainActor
protocol ConnectionServiceProtocol {
    /// Fetch all connections for current user
    func fetchConnections(status: ConnectionStatus?, forceRefresh: Bool) async throws -> [Connection]

    /// Send a connection request to another user
    func sendConnectionRequest(
        to userId: String,
        displayName: String,
        sourceKitchenTableId: String?
    ) async throws -> Connection

    /// Accept a connection invite from a shared link (creates connected status immediately)
    func acceptConnectionInvite(
        from inviterUserId: String,
        inviterDisplayName: String
    ) async throws -> Connection

    /// Accept a connection request
    func acceptRequest(connectionId: String) async throws

    /// Decline a connection request
    func declineRequest(connectionId: String) async throws

    /// Remove an existing connection
    func removeConnection(connectionId: String) async throws

    /// Block a user (prevents future connection requests)
    func blockUser(userId: String) async throws

    /// Unblock a user
    func unblockUser(userId: String) async throws

    /// Get count of pending connection requests
    func getPendingRequestCount() async throws -> Int

    /// Mark connection as favorite
    func toggleFavorite(connectionId: String) async throws

    /// Add private note to connection
    func updatePrivateNote(connectionId: String, note: String?) async throws

    /// Increment recipe share counter
    func recordRecipeShare(connectionId: String) async throws

    /// Clear cache (useful for logout or testing)
    func clearCache()
}

// MARK: - Implementation

/// Firebase implementation of connection service
@MainActor
class FirebaseConnectionService: ConnectionServiceProtocol {

    // MARK: - Dependencies

    private let db: Firestore
    private let auth: Auth

    // MARK: - Cache

    /// In-memory cache of connections (userId -> [Connection])
    private var connectionsCache: [String: [Connection]] = [:]

    /// Timestamp of last cache clear
    private var lastCacheClear: Date = Date()

    /// Cache expiration time (5 minutes for frequently changing data)
    private let cacheExpirationSeconds: TimeInterval = 5 * 60

    // MARK: - Initialization

    init(
        firestore: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth()
    ) {
        self.db = firestore
        self.auth = auth
    }

    // MARK: - Fetch Connections

    /// Fetch all connections for current user
    func fetchConnections(status: ConnectionStatus? = nil, forceRefresh: Bool = false) async throws -> [Connection] {
         guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Clear cache if expired
        clearCacheIfExpired()

        // Check cache first (only if no status filter and not forcing refresh)
        if !forceRefresh, status == nil, let cached = connectionsCache[userId] {
            Log.debug("Connections cache hit", category: .social, metadata: ["userId": userId])
            return cached
        }

        // Build query
        var query: Query = db.collection("users")
            .document(userId)
            .collection("connections")

        // Filter by status if provided
        if let status = status {
            query = query.whereField("status", isEqualTo: status.rawValue)
        }

        // Fetch from Firestore
        let snapshot = try await query.getDocuments()

        let connections = snapshot.documents.compactMap { doc -> Connection? in
            try? Firestore.Decoder().decode(Connection.self, from: doc.data())
        }

        // Update cache (only if no filter)
        if status == nil {
            connectionsCache[userId] = connections
        }

        Log.info("Fetched connections", category: .social, metadata: [
            "userId": userId,
            "count": connections.count,
            "status": status?.rawValue ?? "all"
        ])

        return connections
    }

    // MARK: - Send Connection Request

    /// Send a connection request to another user
    func sendConnectionRequest(
        to targetUserId: String,
        displayName: String,
        sourceKitchenTableId: String? = nil
    ) async throws -> Connection {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        guard userId != targetUserId else {
            throw NSError(
                domain: "ConnectionService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Cannot connect to yourself"]
            )
        }

        // Check if connection already exists
        let existingConnections = try await fetchConnections(status: nil)
        if existingConnections.contains(where: { $0.connectedUserId == targetUserId }) {
            throw NSError(
                domain: "ConnectionService",
                code: 409,
                userInfo: [NSLocalizedDescriptionKey: "Connection already exists"]
            )
        }

        // Check if target user has blocked current user
        let isBlocked = try await checkIfBlocked(by: targetUserId, userId: userId)
        if isBlocked {
            throw NSError(
                domain: "ConnectionService",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Cannot send connection request"]
            )
        }

        let connectionId = UUID().uuidString
        let now = Date()

        // Create outgoing connection (for sender)
        let outgoingConnection = Connection(
            id: connectionId,
            userId: userId,
            connectedUserId: targetUserId,
            connectedUserDisplayName: displayName,
            connectedUserPhotoURL: nil,
            status: .pending,
            initiatedBy: userId,
            requestedAt: now,
            acceptedAt: nil,
            sourceKitchenTableId: sourceKitchenTableId,
            recipesSharedCount: 0,
            recipesReceivedCount: 0,
            isFavorite: false,
            privateNote: nil,
            createdAt: now,
            updatedAt: now
        )

        // Get current user's display name for incoming connection
        let currentUserDisplayName = auth.currentUser?.displayName ?? "User"

        // Create incoming connection (for recipient)
        let incomingConnection = Connection(
            id: connectionId,
            userId: targetUserId,
            connectedUserId: userId,
            connectedUserDisplayName: currentUserDisplayName,
            connectedUserPhotoURL: auth.currentUser?.photoURL?.absoluteString,
            status: .pending,
            initiatedBy: userId,
            requestedAt: now,
            acceptedAt: nil,
            sourceKitchenTableId: sourceKitchenTableId,
            recipesSharedCount: 0,
            recipesReceivedCount: 0,
            isFavorite: false,
            privateNote: nil,
            createdAt: now,
            updatedAt: now
        )

        // Save both connections in a batch
        let batch = db.batch()

        let outgoingData = try Firestore.Encoder().encode(outgoingConnection)
        let outgoingRef = db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connectionId)
        batch.setData(outgoingData, forDocument: outgoingRef)

        let incomingData = try Firestore.Encoder().encode(incomingConnection)
        let incomingRef = db.collection("users")
            .document(targetUserId)
            .collection("connections")
            .document(connectionId)
        batch.setData(incomingData, forDocument: incomingRef)

        try await batch.commit()

        // Clear cache
        connectionsCache.removeValue(forKey: userId)

        // Create notification for recipient
        try await createConnectionNotification(
            for: targetUserId,
            type: .connectionRequestReceived,
            actorUserId: userId,
            actorDisplayName: currentUserDisplayName,
            connectionId: connectionId
        )

        Log.info("Sent connection request", category: .social, metadata: [
            "from": userId,
            "to": targetUserId,
            "connectionId": connectionId
        ])

        return outgoingConnection
    }

    // MARK: - Accept Invite

    /// Accept a connection invite from a shared link
    /// Creates connection in .connected status immediately (no pending request)
    func acceptConnectionInvite(
        from inviterUserId: String,
        inviterDisplayName: String
    ) async throws -> Connection {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        guard userId != inviterUserId else {
            throw NSError(
                domain: "ConnectionService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Cannot connect to yourself"]
            )
        }

        // Check if connection already exists in current user's collection
        // (We can only read our own connections)
        let existingConnections = try await fetchConnections(status: nil)
        if existingConnections.contains(where: { $0.connectedUserId == inviterUserId }) {
            throw NSError(
                domain: "ConnectionService",
                code: 409,
                userInfo: [NSLocalizedDescriptionKey: "Connection already exists"]
            )
        }

        // Fetch inviter's display name from Firebase Auth
        let actualInviterDisplayName: String
        let inviterPhotoURL: String?

        do {
            // Query Firestore for inviter's public profile data
            let profileDoc = try await db.collection("users")
                .document(inviterUserId)
                .collection("profile")
                .document("data")
                .getDocument()

            if let data = profileDoc.data() {
                actualInviterDisplayName = data["displayName"] as? String ?? inviterDisplayName
                inviterPhotoURL = data["photoURL"] as? String
            } else {
                // Fallback to provided displayName
                actualInviterDisplayName = inviterDisplayName
                inviterPhotoURL = nil
            }
        } catch {
            // If profile fetch fails, use fallback
            actualInviterDisplayName = inviterDisplayName
            inviterPhotoURL = nil
            Log.warning("Failed to fetch inviter profile, using fallback", category: .social, metadata: [
                "inviterUserId": inviterUserId,
                "error": error.localizedDescription
            ])
        }

        // Fetch current user's profile to get accurate display name and photo
        let currentUserProfile: (displayName: String, photoURL: String?)?
        do {
            let profileDoc = try await db.collection("users")
                .document(userId)
                .collection("profile")
                .document("data")
                .getDocument()

            if let data = profileDoc.data() {
                let displayName = data["displayName"] as? String ?? auth.currentUser?.displayName ?? "User"
                let photoURL = data["photoURL"] as? String
                currentUserProfile = (displayName, photoURL)
            } else {
                // Fallback to Firebase Auth
                currentUserProfile = (auth.currentUser?.displayName ?? "User", auth.currentUser?.photoURL?.absoluteString)
            }
        } catch {
            // If profile fetch fails, use Firebase Auth as fallback
            currentUserProfile = (auth.currentUser?.displayName ?? "User", auth.currentUser?.photoURL?.absoluteString)
            Log.warning("Failed to fetch current user profile, using fallback", category: .social, metadata: [
                "userId": userId,
                "error": error.localizedDescription
            ])
        }

        let connectionId = UUID().uuidString
        let now = Date()

        // Create connection for inviter (who shared the link)
        let inviterConnection = Connection(
            id: connectionId,
            userId: inviterUserId,
            connectedUserId: userId,
            connectedUserDisplayName: currentUserProfile?.displayName ?? "User",
            connectedUserPhotoURL: currentUserProfile?.photoURL,
            status: .connected, // Immediately connected
            initiatedBy: inviterUserId,
            requestedAt: now,
            acceptedAt: now, // Accepted immediately
            sourceKitchenTableId: nil,
            recipesSharedCount: 0,
            recipesReceivedCount: 0,
            isFavorite: false,
            privateNote: nil,
            createdAt: now,
            updatedAt: now
        )

        // Create connection for accepter (current user)
        let accepterConnection = Connection(
            id: connectionId,
            userId: userId,
            connectedUserId: inviterUserId,
            connectedUserDisplayName: actualInviterDisplayName,
            connectedUserPhotoURL: inviterPhotoURL,
            status: .connected, // Immediately connected
            initiatedBy: inviterUserId,
            requestedAt: now,
            acceptedAt: now, // Accepted immediately
            sourceKitchenTableId: nil,
            recipesSharedCount: 0,
            recipesReceivedCount: 0,
            isFavorite: false,
            privateNote: nil,
            createdAt: now,
            updatedAt: now
        )

        // Write both connections in a batch
        let batch = db.batch()

        let inviterData = try Firestore.Encoder().encode(inviterConnection)
        let inviterRef = db.collection("users")
            .document(inviterUserId)
            .collection("connections")
            .document(connectionId)
        batch.setData(inviterData, forDocument: inviterRef)

        let accepterData = try Firestore.Encoder().encode(accepterConnection)
        let accepterRef = db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connectionId)
        batch.setData(accepterData, forDocument: accepterRef)

        try await batch.commit()

        // Clear cache
        connectionsCache.removeValue(forKey: userId)

        // Create notification for inviter (they get notified someone accepted)
        try await createConnectionNotification(
            for: inviterUserId,
            type: .connectionRequestAccepted,
            actorUserId: userId,
            actorDisplayName: currentUserProfile?.displayName ?? "User",
            connectionId: connectionId
        )

        Log.info("Accepted connection invite from link", category: .social, metadata: [
            "accepter": userId,
            "inviter": inviterUserId,
            "connectionId": connectionId
        ])

        return accepterConnection
    }

    // MARK: - Accept Request

    /// Accept a connection request
    func acceptRequest(connectionId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Fetch the connection
        let connections = try await fetchConnections(status: .pending)
        guard let connection = connections.first(where: { $0.id == connectionId }) else {
            throw NSError(
                domain: "ConnectionService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Connection request not found"]
            )
        }

        // Verify user is the recipient (not the initiator)
        guard connection.initiatedBy != userId else {
            throw NSError(
                domain: "ConnectionService",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Cannot accept your own request"]
            )
        }

        let now = Date()

        // Update both connections to connected status
        let batch = db.batch()

        let userRef = db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connectionId)

        batch.updateData([
            "status": ConnectionStatus.connected.rawValue,
            "acceptedAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now)
        ], forDocument: userRef)

        let connectedUserRef = db.collection("users")
            .document(connection.connectedUserId)
            .collection("connections")
            .document(connectionId)

        batch.updateData([
            "status": ConnectionStatus.connected.rawValue,
            "acceptedAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now)
        ], forDocument: connectedUserRef)

        try await batch.commit()

        // Clear cache for both users
        connectionsCache.removeValue(forKey: userId)
        connectionsCache.removeValue(forKey: connection.connectedUserId)

        // Create notification for initiator
        try await createConnectionNotification(
            for: connection.connectedUserId,
            type: .connectionRequestAccepted,
            actorUserId: userId,
            actorDisplayName: auth.currentUser?.displayName ?? "User",
            connectionId: connectionId
        )

        Log.info("Accepted connection request", category: .social, metadata: [
            "userId": userId,
            "connectionId": connectionId
        ])
    }

    // MARK: - Decline Request

    /// Decline a connection request
    func declineRequest(connectionId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Fetch the connection
        let connections = try await fetchConnections(status: .pending)
        guard let connection = connections.first(where: { $0.id == connectionId }) else {
            throw NSError(
                domain: "ConnectionService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Connection request not found"]
            )
        }

        let now = Date()

        // Update both connections to rejected status
        let batch = db.batch()

        let userRef = db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connectionId)

        batch.updateData([
            "status": ConnectionStatus.rejected.rawValue,
            "updatedAt": Timestamp(date: now)
        ], forDocument: userRef)

        let connectedUserRef = db.collection("users")
            .document(connection.connectedUserId)
            .collection("connections")
            .document(connectionId)

        batch.updateData([
            "status": ConnectionStatus.rejected.rawValue,
            "updatedAt": Timestamp(date: now)
        ], forDocument: connectedUserRef)

        try await batch.commit()

        // Clear cache
        connectionsCache.removeValue(forKey: userId)

        Log.info("Declined connection request", category: .social, metadata: [
            "userId": userId,
            "connectionId": connectionId
        ])
    }

    // MARK: - Remove Connection

    /// Remove an existing connection
    func removeConnection(connectionId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Fetch the connection
        let connections = try await fetchConnections(status: nil)
        guard let connection = connections.first(where: { $0.id == connectionId }) else {
            throw NSError(
                domain: "ConnectionService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Connection not found"]
            )
        }

        // Delete both connections
        let batch = db.batch()

        let userRef = db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connectionId)
        batch.deleteDocument(userRef)

        let connectedUserRef = db.collection("users")
            .document(connection.connectedUserId)
            .collection("connections")
            .document(connectionId)
        batch.deleteDocument(connectedUserRef)

        try await batch.commit()

        // Clear cache
        connectionsCache.removeValue(forKey: userId)
        connectionsCache.removeValue(forKey: connection.connectedUserId)

        Log.info("Removed connection", category: .social, metadata: [
            "userId": userId,
            "connectionId": connectionId
        ])
    }

    // MARK: - Block/Unblock

    /// Block a user (prevents future connection requests)
    func blockUser(userId targetUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Check if connection exists, if so update it to blocked
        let connections = try await fetchConnections(status: nil)
        if let connection = connections.first(where: { $0.connectedUserId == targetUserId }) {
            // Update existing connection to blocked
            let ref = db.collection("users")
                .document(userId)
                .collection("connections")
                .document(connection.id)

            try await ref.updateData([
                "status": ConnectionStatus.blocked.rawValue,
                "updatedAt": Timestamp(date: Date())
            ])
        } else {
            // Create new blocked connection entry
            let blockId = UUID().uuidString
            let blockedConnection = Connection(
                id: blockId,
                userId: userId,
                connectedUserId: targetUserId,
                connectedUserDisplayName: "Blocked User",
                connectedUserPhotoURL: nil,
                status: .blocked,
                initiatedBy: userId,
                requestedAt: Date(),
                acceptedAt: nil,
                sourceKitchenTableId: nil,
                recipesSharedCount: 0,
                recipesReceivedCount: 0,
                isFavorite: false,
                privateNote: nil,
                createdAt: Date(),
                updatedAt: Date()
            )

            let data = try Firestore.Encoder().encode(blockedConnection)
            try await db.collection("users")
                .document(userId)
                .collection("connections")
                .document(blockId)
                .setData(data)
        }

        // Clear cache
        connectionsCache.removeValue(forKey: userId)

        Log.info("Blocked user", category: .social, metadata: [
            "userId": userId,
            "blockedUserId": targetUserId
        ])
    }

    /// Unblock a user
    func unblockUser(userId targetUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Find blocked connection
        let connections = try await fetchConnections(status: .blocked)
        guard let connection = connections.first(where: { $0.connectedUserId == targetUserId }) else {
            throw NSError(
                domain: "ConnectionService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Blocked connection not found"]
            )
        }

        // Delete the blocked connection
        try await db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connection.id)
            .delete()

        // Clear cache
        connectionsCache.removeValue(forKey: userId)

        Log.info("Unblocked user", category: .social, metadata: [
            "userId": userId,
            "unblockedUserId": targetUserId
        ])
    }

    // MARK: - Pending Count

    /// Get count of pending connection requests
    func getPendingRequestCount() async throws -> Int {
        guard let userId = auth.currentUser?.uid else {
            return 0
        }

        let query = db.collection("users")
            .document(userId)
            .collection("connections")
            .whereField("status", isEqualTo: ConnectionStatus.pending.rawValue)
            .whereField("initiatedBy", isNotEqualTo: userId) // Only count requests from others

        let snapshot = try await query.getDocuments()
        return snapshot.documents.count
    }

    // MARK: - Connection Updates

    /// Mark connection as favorite
    func toggleFavorite(connectionId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Fetch connection
        let connections = try await fetchConnections(status: nil)
        guard let connection = connections.first(where: { $0.id == connectionId }) else {
            throw NSError(
                domain: "ConnectionService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Connection not found"]
            )
        }

        // Toggle favorite status
        let newFavoriteStatus = !connection.isFavorite

        try await db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connectionId)
            .updateData([
                "isFavorite": newFavoriteStatus,
                "updatedAt": Timestamp(date: Date())
            ])

        // Clear cache
        connectionsCache.removeValue(forKey: userId)

        Log.info("Toggled connection favorite", category: .social, metadata: [
            "connectionId": connectionId,
            "isFavorite": newFavoriteStatus
        ])
    }

    /// Add private note to connection
    func updatePrivateNote(connectionId: String, note: String?) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        try await db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connectionId)
            .updateData([
                "privateNote": note as Any,
                "updatedAt": Timestamp(date: Date())
            ])

        // Clear cache
        connectionsCache.removeValue(forKey: userId)

        Log.info("Updated connection note", category: .social, metadata: [
            "connectionId": connectionId,
            "hasNote": note != nil
        ])
    }

    /// Increment recipe share counter
    func recordRecipeShare(connectionId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ConnectionService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        try await db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connectionId)
            .updateData([
                "recipesSharedCount": FieldValue.increment(Int64(1)),
                "updatedAt": Timestamp(date: Date())
            ])

        Log.debug("Recorded recipe share", category: .social, metadata: [
            "connectionId": connectionId
        ])
    }

    // MARK: - Cache Management

    /// Clear the entire cache
    func clearCache() {
        connectionsCache.removeAll()
        lastCacheClear = Date()
        Log.info("Cleared connections cache", category: .social)
    }

    /// Clear cache if it has expired
    private func clearCacheIfExpired() {
        let timeSinceLastClear = Date().timeIntervalSince(lastCacheClear)

        if timeSinceLastClear > cacheExpirationSeconds {
            Log.info("Connections cache expired, clearing", category: .social, metadata: [
                "age": "\(Int(timeSinceLastClear))s"
            ])
            clearCache()
        }
    }

    // MARK: - Helper Methods

    /// Check if a user has blocked another user
    private func checkIfBlocked(by userId: String, userId targetUserId: String) async throws -> Bool {
        let query = db.collection("users")
            .document(userId)
            .collection("connections")
            .whereField("connectedUserId", isEqualTo: targetUserId)
            .whereField("status", isEqualTo: ConnectionStatus.blocked.rawValue)
            .limit(to: 1)

        let snapshot = try await query.getDocuments()
        return !snapshot.documents.isEmpty
    }

    /// Create a connection notification
    private func createConnectionNotification(
        for userId: String,
        type: ConnectionNotificationType,
        actorUserId: String,
        actorDisplayName: String,
        connectionId: String
    ) async throws {
        let notificationData = ConnectionNotificationData.connectionRequest(
            from: actorUserId,
            actorDisplayName: actorDisplayName,
            actorPhotoURL: nil,
            connectionId: connectionId
        )

        // Convert to dictionary for Firestore
        let data: [String: Any] = [
            "type": type.rawValue,
            "actorUserId": actorUserId,
            "actorDisplayName": actorDisplayName,
            "connectionId": connectionId,
            "deepLinkURL": notificationData.deepLinkURL as Any,
            "createdAt": Timestamp(date: Date()),
            "isRead": false
        ]

        try await db.collection("users")
            .document(userId)
            .collection("notifications")
            .addDocument(data: data)

        Log.debug("Created connection notification", category: .social, metadata: [
            "userId": userId,
            "type": type.rawValue
        ])
    }
}
