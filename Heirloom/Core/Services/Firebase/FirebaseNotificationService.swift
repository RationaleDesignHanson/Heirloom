import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Service for managing recipe lineage notifications
@MainActor
class FirebaseNotificationService: ObservableObject, FirebaseNotificationServiceProtocol {

    // MARK: - Dependencies

    private let configuration: FirebaseConfiguration
    private let logger: LoggingService

    // MARK: - Published State

    @Published var notifications: [LineageNotification] = []
    @Published var unreadCount: Int = 0

    // MARK: - State

    private var listener: ListenerRegistration?

    // MARK: - Initialization

    init(configuration: FirebaseConfiguration, logger: LoggingService) {
        self.configuration = configuration
        self.logger = logger
        startListening()
    }

    private var db: Firestore { configuration.db }
    private var auth: Auth { configuration.auth }

    // MARK: - Notification Listening

    /// Start listening for notifications from Firebase
    func startListening() {
        guard let userId = auth.currentUser?.uid else {
            logger.log("Cannot start notification listener - not authenticated", category: .firebase, level: .warning, metadata: nil)
            return
        }

        logger.log("Starting notification listener", category: .firebase, level: .info, metadata: nil)

        // Listen to notifications collection
        listener = db.collection("users/\(userId)/notifications")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Log.error("Error listening to notifications", category: .firebase, metadata: ["error": error.localizedDescription])
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.logger.log("No documents in notification snapshot", category: .firebase, level: .warning, metadata: nil)
                    return
                }

                self.logger.log("Received notifications", category: .firebase, level: .info, metadata: nil)

                Task { @MainActor in
                    self.notifications = documents.compactMap { doc in
                        self.parseNotification(doc)
                    }

                    self.unreadCount = self.notifications.filter { !$0.read }.count
                    self.logger.log("Unread notifications count updated", category: .firebase, level: .debug, metadata: nil)
                }
            }
    }

    /// Stop listening for notifications
    func stopListening() {
        listener?.remove()
        listener = nil
        Log.info("Stopped notification listener", category: .firebase)
    }

    // MARK: - Notification Queries

    /// Get unread notifications for a specific recipe
    func unreadNotifications(for recipeId: UUID) -> [LineageNotification] {
        return notifications.filter {
            $0.rootRecipeId == recipeId && !$0.read
        }
    }

    /// Get unread count for a specific recipe
    func unreadCount(for recipeId: UUID) -> Int {
        return unreadNotifications(for: recipeId).count
    }

    /// Check if there are any unread notifications
    var hasUnreadNotifications: Bool {
        return unreadCount > 0
    }

    // MARK: - Mark as Read

    /// Mark a notification as read
    func markAsRead(_ notification: LineageNotification) async throws {
        guard let userId = auth.currentUser?.uid else {
            logger.log("Cannot mark notification as read - not authenticated", category: .firebase, level: .warning, metadata: nil)
            return
        }

        logger.log("Marking notification as read", category: .firebase, level: .info, metadata: nil)

        // Add timeout protection for Firestore operations (30 seconds)
        try await TaskTimeout.withTimeout(seconds: TaskTimeout.firebaseStandard) { [self] in
            try await self.db.collection("users/\(userId)/notifications")
                .document(notification.id)
                .updateData(["read": true])
        }

        logger.log("Notification marked as read", category: .firebase, level: .info, metadata: nil)
    }

    /// Mark all notifications for a recipe as read
    func markAllAsRead(for recipeId: UUID) async throws {
        guard let userId = auth.currentUser?.uid else {
            logger.log("Cannot mark notifications as read - not authenticated", category: .firebase, level: .warning, metadata: nil)
            return
        }

        let notificationsToMark = unreadNotifications(for: recipeId)

        logger.log("Marking recipe notifications as read", category: .firebase, level: .info, metadata: nil)

        // Update in batches
        let batch = db.batch()

        for notification in notificationsToMark {
            let ref = db.collection("users/\(userId)/notifications")
                .document(notification.id)
            batch.updateData(["read": true], forDocument: ref)
        }

        // Add timeout protection for Firestore batch operations (30 seconds)
        try await TaskTimeout.withTimeout(seconds: TaskTimeout.firebaseStandard) {
            try await batch.commit()
        }

        logger.log("All recipe notifications marked as read", category: .firebase, level: .info, metadata: nil)
    }

    /// Mark all notifications as read (for tab badge clear)
    func markAllAsRead() async throws {
        guard let userId = auth.currentUser?.uid else {
            logger.log("Cannot mark all notifications as read - not authenticated", category: .firebase, level: .warning, metadata: nil)
            return
        }

        let unreadNotifications = notifications.filter { !$0.read }

        logger.log("Marking all notifications as read", category: .firebase, level: .info, metadata: nil)

        // Update in batches
        let batch = db.batch()

        for notification in unreadNotifications {
            let ref = db.collection("users/\(userId)/notifications")
                .document(notification.id)
            batch.updateData(["read": true], forDocument: ref)
        }

        // Add timeout protection for Firestore batch operations (30 seconds)
        try await TaskTimeout.withTimeout(seconds: TaskTimeout.firebaseStandard) {
            try await batch.commit()
        }

        Log.info("All notifications marked as read", category: .firebase)
    }

    // MARK: - Parsing

    private func parseNotification(_ doc: QueryDocumentSnapshot) -> LineageNotification? {
        let data = doc.data()

        // Only parse lineage_modification notifications (skip connection requests, etc.)
        guard let type = data["type"] as? String, type == "lineage_modification" else {
            // Skip non-lineage notifications silently (they're handled elsewhere)
            return nil
        }

        // Parse required fields with fallbacks for malformed data
        let recipeIdString = data["recipeId"] as? String ?? ""
        let rootRecipeIdString = data["rootRecipeId"] as? String ?? recipeIdString
        let generation = data["generation"] as? Int ?? 0
        let modifiedBy = data["modifiedBy"] as? String ?? "unknown"
        let changeType = data["changeType"] as? String ?? "modified"
        let changeDescription = data["changeDescription"] as? String ?? "Recipe was modified"

        // Timestamp: try Timestamp first, then Date, then use current date
        let timestamp: Date
        if let ts = data["timestamp"] as? Timestamp {
            timestamp = ts.dateValue()
        } else if let createdAt = data["createdAt"] as? Timestamp {
            timestamp = createdAt.dateValue()
        } else {
            timestamp = Date()
        }

        // Try to parse UUIDs - skip notification if recipe IDs are invalid
        guard let recipeId = UUID(uuidString: recipeIdString) else {
            Log.debug("Skipping notification with invalid recipeId", category: .firebase, metadata: [
                "documentId": doc.documentID,
                "recipeIdString": recipeIdString
            ])
            return nil
        }

        // Root recipe ID can fall back to recipe ID if not present
        let rootRecipeId = UUID(uuidString: rootRecipeIdString) ?? recipeId

        let read = data["read"] as? Bool ?? data["isRead"] as? Bool ?? false
        let modifiedByName = data["modifiedByName"] as? String ?? data["actorDisplayName"] as? String

        return LineageNotification(
            id: doc.documentID,
            recipeId: recipeId,
            rootRecipeId: rootRecipeId,
            generation: generation,
            modifiedBy: modifiedBy,
            modifiedByName: modifiedByName,
            changeType: changeType,
            changeDescription: changeDescription,
            timestamp: timestamp,
            read: read
        )
    }
}

// MARK: - Supporting Types

/// Represents a lineage modification notification
struct LineageNotification: Identifiable, Hashable {
    let id: String
    let recipeId: UUID
    let rootRecipeId: UUID
    let generation: Int
    let modifiedBy: String
    let modifiedByName: String?
    let changeType: String
    let changeDescription: String
    let timestamp: Date
    let read: Bool

    var displayMessage: String {
        let who = modifiedByName ?? "Someone"
        return "\(who) modified a recipe you shared"
    }
}
