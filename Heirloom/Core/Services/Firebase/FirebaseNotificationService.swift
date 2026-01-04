import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Service for managing recipe lineage notifications
@MainActor
class FirebaseNotificationService: ObservableObject {

    // MARK: - Singleton

    static let shared = FirebaseNotificationService()

    private init() {
        startListening()
    }

    // MARK: - Published State

    @Published var notifications: [LineageNotification] = []
    @Published var unreadCount: Int = 0

    // MARK: - Dependencies

    private lazy var db: Firestore = {
        // Use shared Firestore instance (configured by FirebaseSyncService)
        Firestore.firestore()
    }()
    private var auth: Auth { Auth.auth() }
    private var listener: ListenerRegistration?

    // MARK: - Notification Listening

    /// Start listening for notifications from Firebase
    func startListening() {
        guard let userId = auth.currentUser?.uid else {
            Log.warning("Cannot start notification listener - not authenticated", category: .firebase)
            return
        }

        Log.info("Starting notification listener", category: .firebase, metadata: ["userId": userId])

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
                    Log.warning("No documents in notification snapshot", category: .firebase)
                    return
                }

                Log.info("Received notifications", category: .firebase, metadata: ["count": documents.count])

                Task { @MainActor in
                    self.notifications = documents.compactMap { doc in
                        self.parseNotification(doc)
                    }

                    self.unreadCount = self.notifications.filter { !$0.read }.count
                    Log.debug("Unread notifications count updated", category: .firebase, metadata: ["unreadCount": self.unreadCount])
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
            Log.warning("Cannot mark notification as read - not authenticated", category: .firebase)
            return
        }

        Log.info("Marking notification as read", category: .firebase, metadata: ["notificationId": notification.id])

        try await db.collection("users/\(userId)/notifications")
            .document(notification.id)
            .updateData(["read": true])

        Log.info("Notification marked as read", category: .firebase, metadata: ["notificationId": notification.id])
    }

    /// Mark all notifications for a recipe as read
    func markAllAsRead(for recipeId: UUID) async throws {
        guard let userId = auth.currentUser?.uid else {
            Log.warning("Cannot mark notifications as read - not authenticated", category: .firebase)
            return
        }

        let notificationsToMark = unreadNotifications(for: recipeId)

        Log.info("Marking recipe notifications as read", category: .firebase, metadata: ["count": notificationsToMark.count, "recipeId": recipeId.uuidString])

        // Update in batches
        let batch = db.batch()

        for notification in notificationsToMark {
            let ref = db.collection("users/\(userId)/notifications")
                .document(notification.id)
            batch.updateData(["read": true], forDocument: ref)
        }

        try await batch.commit()

        Log.info("All recipe notifications marked as read", category: .firebase, metadata: ["recipeId": recipeId.uuidString])
    }

    /// Mark all notifications as read (for tab badge clear)
    func markAllAsRead() async throws {
        guard let userId = auth.currentUser?.uid else {
            Log.warning("Cannot mark all notifications as read - not authenticated", category: .firebase)
            return
        }

        let unreadNotifications = notifications.filter { !$0.read }

        Log.info("Marking all notifications as read", category: .firebase, metadata: ["count": unreadNotifications.count])

        // Update in batches
        let batch = db.batch()

        for notification in unreadNotifications {
            let ref = db.collection("users/\(userId)/notifications")
                .document(notification.id)
            batch.updateData(["read": true], forDocument: ref)
        }

        try await batch.commit()

        Log.info("All notifications marked as read", category: .firebase)
    }

    // MARK: - Parsing

    private func parseNotification(_ doc: QueryDocumentSnapshot) -> LineageNotification? {
        let data = doc.data()

        guard
            let type = data["type"] as? String,
            type == "lineage_modification",
            let recipeIdString = data["recipeId"] as? String,
            let recipeId = UUID(uuidString: recipeIdString),
            let rootRecipeIdString = data["rootRecipeId"] as? String,
            let rootRecipeId = UUID(uuidString: rootRecipeIdString),
            let generation = data["generation"] as? Int,
            let modifiedBy = data["modifiedBy"] as? String,
            let changeType = data["changeType"] as? String,
            let changeDescription = data["changeDescription"] as? String,
            let timestamp = (data["timestamp"] as? Timestamp)?.dateValue()
        else {
            Log.warning("Failed to parse notification document", category: .firebase, metadata: ["documentId": doc.documentID])
            return nil
        }

        let read = data["read"] as? Bool ?? false
        let modifiedByName = data["modifiedByName"] as? String

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
