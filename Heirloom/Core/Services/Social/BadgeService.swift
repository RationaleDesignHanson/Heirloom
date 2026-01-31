//
//  BadgeService.swift
//  Heirloom
//
//  Phase 9: Badge System
//  Manages app icon badge and in-app badge counts for connection requests
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import Combine

/// Service for managing badge counts for pending connection requests
@MainActor
class BadgeService: ObservableObject {

    // MARK: - Published State

    /// Current count of pending connection requests
    @Published private(set) var pendingRequestCount: Int = 0

    // MARK: - Dependencies

    private let connectionService: ConnectionServiceProtocol
    private let auth: Auth
    private let db: Firestore

    // MARK: - State

    private var connectionListener: ListenerRegistration?
    private var isListening = false

    // MARK: - Initialization

    init(
        connectionService: ConnectionServiceProtocol,
        auth: Auth = Auth.auth(),
        firestore: Firestore = Firestore.firestore()
    ) {
        self.connectionService = connectionService
        self.auth = auth
        self.db = firestore

        Log.info("BadgeService initialized", category: .social)
    }

    deinit {
        // Cleanup Firebase listener
        // Note: Cannot call MainActor methods from deinit
        connectionListener?.remove()
        connectionListener = nil
    }

    // MARK: - Listener Management

    /// Start listening for pending connection request changes
    func startListening() {
        guard let userId = auth.currentUser?.uid else {
            Log.warning("Cannot start badge listener - no authenticated user", category: .social)
            return
        }

        // Don't create duplicate listeners
        guard !isListening else {
            Log.debug("Badge listener already running", category: .social)
            return
        }

        Log.info("Starting badge listener for pending connection requests", category: .social, metadata: ["userId": userId])

        // Listen to incoming connection requests (where user is recipient)
        connectionListener = db.collection("users")
            .document(userId)
            .collection("connections")
            .whereField("status", isEqualTo: "pending")
            .whereField("initiatedBy", isNotEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Log.error("Badge listener error", category: .social, error: error)
                    return
                }

                let count = snapshot?.documents.count ?? 0

                Task { @MainActor in
                    self.updateCount(count)
                }
            }

        isListening = true
        Log.info("Badge listener started", category: .social)
    }

    /// Stop listening for changes
    func stopListening() {
        guard isListening else { return }

        connectionListener?.remove()
        connectionListener = nil
        isListening = false

        // Clear badge on stop
        pendingRequestCount = 0
        updateAppIconBadge()

        Log.info("Badge listener stopped", category: .social)
    }

    // MARK: - Badge Updates

    /// Update badge count and app icon badge
    private func updateCount(_ count: Int) {
        // Update published count for UI
        let oldCount = pendingRequestCount
        pendingRequestCount = count

        // Update app icon badge
        updateAppIconBadge()

        Log.info("Badge count updated", category: .social, metadata: [
            "oldCount": oldCount,
            "newCount": count
        ])
    }

    /// Update iOS app icon badge
    private func updateAppIconBadge() {
        let badgeCount = pendingRequestCount

        UNUserNotificationCenter.current().setBadgeCount(badgeCount) { error in
            if let error = error {
                Log.error("Failed to update app icon badge", category: .social, metadata: [
                    "count": badgeCount,
                    "error": error.localizedDescription
                ])
            } else {
                Log.debug("App icon badge updated", category: .social, metadata: ["count": badgeCount])
            }
        }
    }

    /// Manually refresh badge count (for foreground refresh)
    func refreshCount() async {
        guard auth.currentUser?.uid != nil else {
            Log.debug("Skipping badge refresh - not authenticated", category: .social)
            return
        }

        do {
            let count = try await connectionService.getPendingRequestCount()

            await MainActor.run {
                updateCount(count)
            }

            Log.debug("Badge count manually refreshed", category: .social, metadata: ["count": count])
        } catch {
            Log.error("Failed to refresh badge count", category: .social, error: error)
        }
    }

    /// Clear badge (called on sign out)
    func clearBadge() {
        stopListening()
        Log.info("Badge cleared", category: .social)
    }
}
