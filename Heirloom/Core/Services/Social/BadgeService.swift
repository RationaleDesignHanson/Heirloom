//
//  BadgeService.swift
//  Heirloom
//
//  Phase 9: Badge System
//  Manages app icon badge and in-app badge counts for connection requests and recipe shares
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import Combine

/// Service for managing badge counts for pending connection requests and recipe shares
@MainActor
class BadgeService: ObservableObject {

    // MARK: - Published State

    /// Current count of pending connection requests
    @Published private(set) var pendingRequestCount: Int = 0

    /// Current count of pending recipe shares
    @Published private(set) var pendingSharesCount: Int = 0

    /// Total badge count (connection requests + pending shares)
    var totalBadgeCount: Int {
        pendingRequestCount + pendingSharesCount
    }

    // MARK: - Dependencies

    private let connectionService: ConnectionServiceProtocol
    private let auth: Auth
    private let db: Firestore

    // MARK: - State

    private var connectionListener: ListenerRegistration?
    private var sharesListener: ListenerRegistration?
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
        // Cleanup Firebase listeners
        // Note: Cannot call MainActor methods from deinit
        connectionListener?.remove()
        connectionListener = nil
        sharesListener?.remove()
        sharesListener = nil
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

        Log.info("Starting badge listeners for connections and shares", category: .social, metadata: ["userId": userId])

        // Listen to incoming connection requests (where user is recipient)
        connectionListener = db.collection("users")
            .document(userId)
            .collection("connections")
            .whereField("status", isEqualTo: "pending")
            .whereField("initiatedBy", isNotEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Log.error("Connection badge listener error", category: .social, error: error)
                    return
                }

                let count = snapshot?.documents.count ?? 0

                Task { @MainActor in
                    self.updateRequestCount(count)
                }
            }

        // Listen to pending recipe shares (where user is recipient but hasn't accepted)
        sharesListener = db.collection("shares")
            .whereField("recipientUserIds", arrayContains: userId)
            .whereField("isDirectShare", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Log.error("Shares badge listener error", category: .social, error: error)
                    return
                }

                // Filter shares where user hasn't accepted yet
                let now = Date()
                let pendingShares = snapshot?.documents.filter { doc in
                    let data = doc.data()

                    // Check if not expired
                    if let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue(),
                       expiresAt < now {
                        return false
                    }

                    // Check if not already accepted
                    let acceptedBy = data["acceptedBy"] as? [String] ?? []
                    return !acceptedBy.contains(userId)
                } ?? []

                let count = pendingShares.count

                Task { @MainActor in
                    self.updateSharesCount(count)
                }
            }

        isListening = true
        Log.info("Badge listeners started", category: .social)
    }

    /// Stop listening for changes
    func stopListening() {
        guard isListening else { return }

        connectionListener?.remove()
        connectionListener = nil
        sharesListener?.remove()
        sharesListener = nil
        isListening = false

        // Clear badges on stop
        pendingRequestCount = 0
        pendingSharesCount = 0
        updateAppIconBadge()

        Log.info("Badge listeners stopped", category: .social)
    }

    // MARK: - Badge Updates

    /// Update connection request count and app icon badge
    private func updateRequestCount(_ count: Int) {
        let oldCount = pendingRequestCount
        pendingRequestCount = count
        updateAppIconBadge()

        Log.info("Connection request badge count updated", category: .social, metadata: [
            "oldCount": oldCount,
            "newCount": count,
            "totalBadge": totalBadgeCount
        ])
    }

    /// Update pending shares count and app icon badge
    private func updateSharesCount(_ count: Int) {
        let oldCount = pendingSharesCount
        pendingSharesCount = count
        updateAppIconBadge()

        Log.info("Pending shares badge count updated", category: .social, metadata: [
            "oldCount": oldCount,
            "newCount": count,
            "totalBadge": totalBadgeCount
        ])
    }

    /// Update iOS app icon badge with total count
    private func updateAppIconBadge() {
        let badgeCount = totalBadgeCount
        let requestCount = pendingRequestCount
        let shareCount = pendingSharesCount

        UNUserNotificationCenter.current().setBadgeCount(badgeCount) { error in
            if let error = error {
                Log.error("Failed to update app icon badge", category: .social, metadata: [
                    "count": badgeCount,
                    "error": error.localizedDescription
                ])
            } else {
                Log.debug("App icon badge updated", category: .social, metadata: [
                    "count": badgeCount,
                    "requests": requestCount,
                    "shares": shareCount
                ])
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
                updateRequestCount(count)
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
