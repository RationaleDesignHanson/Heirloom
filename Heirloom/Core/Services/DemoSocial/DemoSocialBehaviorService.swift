//
//  DemoSocialBehaviorService.swift
//  Heirloom
//
//  Orchestrates demo social behaviors for TestFlight users.
//  All behaviors check DemoSocialGate.isEnabled before executing.
//
//  Behaviors:
//  - Auto-accept: When user sends request to demo user, auto-accept after 5-30s
//  - Proactive requests: Demo users send requests to new users after onboarding
//  - Recipe sharing: After connection established, demo user shares a recipe after delay
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData

/// Service that orchestrates demo social behaviors
@MainActor
final class DemoSocialBehaviorService: ObservableObject {

    // MARK: - Singleton

    static let shared = DemoSocialBehaviorService()

    // MARK: - Configuration

    /// Delay range for auto-accepting requests (seconds)
    private let autoAcceptDelayRange: ClosedRange<Double> = 5...30

    /// Delay before demo user sends proactive request after onboarding (seconds)
    private let proactiveRequestDelay: Double = 5 * 60  // 5 minutes

    /// Delay before demo user shares recipe after connection established (seconds)
    private let recipeShareDelayRange: ClosedRange<Double> = 30 * 60...120 * 60  // 30min - 2hr

    // MARK: - Dependencies

    private let gate: DemoSocialGate
    private let db: Firestore
    private let auth: Auth

    // MARK: - State

    /// Whether the service has been started
    @Published private(set) var isRunning = false

    /// Active scheduled tasks (for cancellation)
    private var scheduledTasks: [String: Task<Void, Never>] = [:]

    /// Connection IDs we're watching for recipe sharing
    private var pendingRecipeShares: Set<String> = []

    // MARK: - Demo User Data

    /// List of demo user IDs
    static let demoUserIds: Set<String> = [
        "demo_grandmazing",
        "demo_phillipfry",
        "demo_chef_maria",
        "demo_fitfoodie",
        "demo_bakingbelle",
        "demo_grillmaster"
    ]

    /// Demo user display info for creating connections/shares
    static let demoUserInfo: [String: (displayName: String, photoURL: String)] = [
        "demo_grandmazing": (
            displayName: "Grandmazing",
            photoURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grandmazing-avatar.webp"
        ),
        "demo_phillipfry": (
            displayName: "Phillip Fry",
            photoURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_phillipfry-avatar.webp"
        ),
        "demo_chef_maria": (
            displayName: "Maria Santos",
            photoURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_chef_maria-avatar.webp"
        ),
        "demo_fitfoodie": (
            displayName: "Alex Chen",
            photoURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_fitfoodie-avatar.webp"
        ),
        "demo_bakingbelle": (
            displayName: "Belle Thompson",
            photoURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bakingbelle-avatar.webp"
        ),
        "demo_grillmaster": (
            displayName: "Marcus Johnson",
            photoURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grillmaster-avatar.webp"
        ),
    ]

    /// Recommended recipes to share per demo user (recipe IDs from seed data)
    static let demoUserWelcomeRecipes: [String: (recipeId: String, message: String)] = [
        "demo_grandmazing": (
            recipeId: "demo_grandmazing_chocolate_chip_cookies",
            message: "Welcome to Heirloom! Here's my most popular recipe to get you started. These cookies are a family favorite!"
        ),
        "demo_phillipfry": (
            recipeId: "demo_phillipfry_one_pot_pasta",
            message: "Hey! Thought you might like this one - it's my go-to weeknight dinner. Super easy and delicious!"
        ),
        "demo_chef_maria": (
            recipeId: "demo_chef_maria_garlic_shrimp",
            message: "Bienvenido! I'd love to share this classic Latin dish with you. It's always a crowd-pleaser!"
        ),
        "demo_fitfoodie": (
            recipeId: "demo_fitfoodie_protein_bowl",
            message: "Welcome! This is my favorite post-workout meal. 45g of protein and it actually tastes amazing!"
        ),
        "demo_bakingbelle": (
            recipeId: "demo_bakingbelle_chocolate_lava_cakes",
            message: "Hi there! I wanted to share my favorite quick dessert. It looks fancy but it's actually super easy!"
        ),
        "demo_grillmaster": (
            recipeId: "demo_grillmaster_smash_burgers",
            message: "Welcome! These burgers are life-changing. Those crispy edges are what it's all about!"
        ),
    ]

    // MARK: - Initialization

    init(
        gate: DemoSocialGate = .shared,
        db: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth()
    ) {
        self.gate = gate
        self.db = db
        self.auth = auth
    }

    // MARK: - Lifecycle

    /// Start the demo behavior service
    /// Called after user completes onboarding
    func start() {
        guard gate.isEnabled else {
            Log.info("Demo social behaviors disabled - gate is off", category: .social)
            return
        }

        guard !isRunning else {
            return
        }

        isRunning = true
        Log.info("Demo social behavior service started", category: .social)

        // Start listening for user-initiated requests to demo users
        startObservingConnectionRequests()
    }

    /// Stop the demo behavior service
    func stop() {
        guard isRunning else {
            return
        }

        isRunning = false

        // Cancel all scheduled tasks
        for (key, task) in scheduledTasks {
            task.cancel()
            Log.debug("Cancelled scheduled task: \(key)", category: .social)
        }
        scheduledTasks.removeAll()
        pendingRecipeShares.removeAll()

        Log.info("Demo social behavior service stopped", category: .social)
    }

    /// Check if demo behaviors should be active
    func refreshState() {
        if gate.isEnabled && !isRunning {
            start()
        } else if !gate.isEnabled && isRunning {
            stop()
        }
    }

    // MARK: - Public API

    /// Call this when user completes onboarding to trigger proactive demo request
    func onOnboardingComplete() {
        guard gate.isEnabled else { return }

        scheduleProactiveDemoRequest()
    }

    /// Call this when user sends a connection request
    /// If it's to a demo user, schedule auto-accept
    func onConnectionRequestSent(to userId: String, connectionId: String) {
        guard gate.isEnabled else { return }
        guard isDemoUser(userId) else { return }

        scheduleAutoAccept(demoUserId: userId, connectionId: connectionId)
    }

    /// Check if a user ID belongs to a demo user
    func isDemoUser(_ userId: String) -> Bool {
        Self.demoUserIds.contains(userId)
    }

    // MARK: - Auto-Accept Logic

    /// Schedule auto-accept for a connection request to a demo user
    private func scheduleAutoAccept(demoUserId: String, connectionId: String) {
        let delay = Double.random(in: autoAcceptDelayRange)

        Log.info("Scheduling auto-accept for demo user", category: .social, metadata: [
            "demoUserId": demoUserId,
            "connectionId": connectionId,
            "delaySeconds": delay
        ])

        let taskKey = "autoAccept_\(connectionId)"
        scheduledTasks[taskKey]?.cancel()

        scheduledTasks[taskKey] = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard !Task.isCancelled else { return }
                guard gate.isEnabled else { return }

                await performAutoAccept(demoUserId: demoUserId, connectionId: connectionId)
            } catch {
                // Task was cancelled
            }
        }
    }

    /// Perform the auto-accept by updating connection status
    private func performAutoAccept(demoUserId: String, connectionId: String) async {
        guard let userId = auth.currentUser?.uid else { return }

        let now = Date()
        let batch = db.batch()

        // Update user's connection document
        let userConnectionRef = db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connectionId)

        batch.updateData([
            "status": ConnectionStatus.connected.rawValue,
            "acceptedAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now)
        ], forDocument: userConnectionRef)

        // Update demo user's connection document
        let demoConnectionRef = db.collection("users")
            .document(demoUserId)
            .collection("connections")
            .document(connectionId)

        batch.updateData([
            "status": ConnectionStatus.connected.rawValue,
            "acceptedAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now)
        ], forDocument: demoConnectionRef)

        do {
            try await batch.commit()

            Log.info("Demo user auto-accepted connection request", category: .social, metadata: [
                "demoUserId": demoUserId,
                "connectionId": connectionId
            ])

            // Create notification for user that demo user accepted
            await createAcceptanceNotification(demoUserId: demoUserId, connectionId: connectionId)

            // Schedule recipe share after connection established
            scheduleRecipeShare(demoUserId: demoUserId, connectionId: connectionId)

        } catch {
            Log.error("Failed to auto-accept connection", category: .social, error: error, metadata: [
                "connectionId": connectionId
            ])
        }

        // Clean up task reference
        scheduledTasks.removeValue(forKey: "autoAccept_\(connectionId)")
    }

    // MARK: - Proactive Request Logic

    /// Schedule a demo user to send a connection request to the new user
    private func scheduleProactiveDemoRequest() {
        guard let userId = auth.currentUser?.uid else { return }

        // Check if user already has a demo connection (don't spam)
        Task {
            let hasExistingDemo = await checkIfUserHasDemoConnection(userId: userId)
            if hasExistingDemo {
                Log.debug("User already has demo connection, skipping proactive request", category: .social)
                return
            }

            let taskKey = "proactiveRequest_\(userId)"
            scheduledTasks[taskKey]?.cancel()

            Log.info("Scheduling proactive demo request", category: .social, metadata: [
                "delaySeconds": proactiveRequestDelay
            ])

            scheduledTasks[taskKey] = Task {
                do {
                    try await Task.sleep(nanoseconds: UInt64(proactiveRequestDelay * 1_000_000_000))

                    guard !Task.isCancelled else { return }
                    guard gate.isEnabled else { return }

                    await sendProactiveDemoRequest(toUserId: userId)
                } catch {
                    // Task was cancelled
                }
            }
        }
    }

    /// Check if user already has any demo connections
    private func checkIfUserHasDemoConnection(userId: String) async -> Bool {
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("connections")
                .getDocuments()

            for doc in snapshot.documents {
                if let connectedUserId = doc.data()["connectedUserId"] as? String,
                   isDemoUser(connectedUserId) {
                    return true
                }
            }
            return false
        } catch {
            return false
        }
    }

    /// Send a proactive connection request from a demo user to the real user
    private func sendProactiveDemoRequest(toUserId: String) async {
        // Pick a random demo user
        let demoUserId = Self.demoUserIds.randomElement() ?? "demo_grandmazing"
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        // Fetch user's profile info
        let userDisplayName: String
        let userPhotoURL: String?

        do {
            let profileDoc = try await db.collection("users")
                .document(toUserId)
                .collection("profile")
                .document("data")
                .getDocument()

            userDisplayName = profileDoc.data()?["displayName"] as? String ?? "Friend"
            userPhotoURL = profileDoc.data()?["photoURL"] as? String
        } catch {
            userDisplayName = "Friend"
            userPhotoURL = nil
        }

        let connectionId = UUID().uuidString
        let now = Date()

        // Create connection documents (demo user is the initiator)
        let demoConnection: [String: Any] = [
            "id": connectionId,
            "userId": demoUserId,
            "connectedUserId": toUserId,
            "connectedUserDisplayName": userDisplayName,
            "connectedUserPhotoURL": userPhotoURL as Any,
            "status": ConnectionStatus.pending.rawValue,
            "initiatedBy": demoUserId,
            "requestedAt": Timestamp(date: now),
            "recipesSharedCount": 0,
            "recipesReceivedCount": 0,
            "isFavorite": false,
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now),
            "isDemoConnection": true
        ]

        let userConnection: [String: Any] = [
            "id": connectionId,
            "userId": toUserId,
            "connectedUserId": demoUserId,
            "connectedUserDisplayName": demoInfo.displayName,
            "connectedUserPhotoURL": demoInfo.photoURL,
            "status": ConnectionStatus.pending.rawValue,
            "initiatedBy": demoUserId,
            "requestedAt": Timestamp(date: now),
            "recipesSharedCount": 0,
            "recipesReceivedCount": 0,
            "isFavorite": false,
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now),
            "isDemoConnection": true
        ]

        let batch = db.batch()

        // Create in demo user's collection
        let demoRef = db.collection("users")
            .document(demoUserId)
            .collection("connections")
            .document(connectionId)
        batch.setData(demoConnection, forDocument: demoRef)

        // Create in user's collection
        let userRef = db.collection("users")
            .document(toUserId)
            .collection("connections")
            .document(connectionId)
        batch.setData(userConnection, forDocument: userRef)

        do {
            try await batch.commit()

            Log.info("Demo user sent proactive connection request", category: .social, metadata: [
                "demoUserId": demoUserId,
                "toUserId": toUserId,
                "connectionId": connectionId
            ])

            // Create notification for user
            await createConnectionRequestNotification(
                forUserId: toUserId,
                fromDemoUserId: demoUserId,
                connectionId: connectionId
            )

        } catch {
            Log.error("Failed to send proactive demo request", category: .social, error: error)
        }

        // Clean up task reference
        scheduledTasks.removeValue(forKey: "proactiveRequest_\(toUserId)")
    }

    // MARK: - Recipe Sharing Logic

    /// Schedule a recipe share from demo user after connection is established
    private func scheduleRecipeShare(demoUserId: String, connectionId: String) {
        guard !pendingRecipeShares.contains(connectionId) else { return }
        pendingRecipeShares.insert(connectionId)

        let delay = Double.random(in: recipeShareDelayRange)

        Log.info("Scheduling demo recipe share", category: .social, metadata: [
            "demoUserId": demoUserId,
            "connectionId": connectionId,
            "delayMinutes": delay / 60
        ])

        let taskKey = "recipeShare_\(connectionId)"
        scheduledTasks[taskKey]?.cancel()

        scheduledTasks[taskKey] = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard !Task.isCancelled else { return }
                guard gate.isEnabled else { return }

                await performRecipeShare(demoUserId: demoUserId, connectionId: connectionId)
            } catch {
                // Task was cancelled
            }
        }
    }

    /// Perform the recipe share from demo user
    private func performRecipeShare(demoUserId: String, connectionId: String) async {
        guard let userId = auth.currentUser?.uid else { return }
        guard let welcomeRecipe = Self.demoUserWelcomeRecipes[demoUserId] else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        // Check if the connection is still active
        do {
            let connectionDoc = try await db.collection("users")
                .document(userId)
                .collection("connections")
                .document(connectionId)
                .getDocument()

            guard let status = connectionDoc.data()?["status"] as? String,
                  status == ConnectionStatus.connected.rawValue else {
                Log.debug("Connection no longer active, skipping recipe share", category: .social)
                return
            }
        } catch {
            return
        }

        let shareId = UUID().uuidString
        let now = Date()
        let expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: now)!

        // Create the share document
        let shareData: [String: Any] = [
            "shareId": shareId,
            "recipeId": welcomeRecipe.recipeId,
            "ownerId": demoUserId,
            "ownerName": demoInfo.displayName,
            "recipeTitle": getRecipeTitle(for: welcomeRecipe.recipeId),
            "shareType": "heirloom",
            "createdAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: expiresAt),
            "includeCardBack": true,
            "includeRating": true,
            "includeNotes": true,
            "includePinnedComments": true,
            "includeAllComments": false,
            "includeCookingHistory": false,
            "includeStickers": true,
            "personalMessage": welcomeRecipe.message,
            "allowReSharing": true,
            "generation": 1,
            "rootRecipeId": welcomeRecipe.recipeId,
            "rootOwnerId": demoUserId,
            "recipientUserIds": [userId],
            "isDirectShare": true,
            "sharedWithCount": 1,
            "acceptedBy": [],
            "acceptCount": 0,
            "viewCount": 0,
            "isDemoShare": true
        ]

        do {
            try await db.collection("shares").document(shareId).setData(shareData)

            Log.info("Demo user shared recipe", category: .social, metadata: [
                "demoUserId": demoUserId,
                "recipeId": welcomeRecipe.recipeId,
                "shareId": shareId
            ])

            // Create notification for user
            await createRecipeShareNotification(
                forUserId: userId,
                fromDemoUserId: demoUserId,
                shareId: shareId,
                recipeTitle: getRecipeTitle(for: welcomeRecipe.recipeId)
            )

        } catch {
            Log.error("Failed to create demo recipe share", category: .social, error: error)
        }

        // Clean up
        pendingRecipeShares.remove(connectionId)
        scheduledTasks.removeValue(forKey: "recipeShare_\(connectionId)")
    }

    /// Get recipe title from recipe ID (simplified lookup)
    private func getRecipeTitle(for recipeId: String) -> String {
        switch recipeId {
        case "demo_grandmazing_chocolate_chip_cookies":
            return "Brown Butter Chocolate Chip Cookies"
        case "demo_phillipfry_one_pot_pasta":
            return "Creamy One-Pot Pasta"
        case "demo_chef_maria_garlic_shrimp":
            return "Camarones al Ajillo (Garlic Shrimp)"
        case "demo_fitfoodie_protein_bowl":
            return "Ultimate Protein Power Bowl"
        case "demo_bakingbelle_chocolate_lava_cakes":
            return "Molten Chocolate Lava Cakes"
        case "demo_grillmaster_smash_burgers":
            return "Ultimate Smash Burgers"
        default:
            return "Recipe"
        }
    }

    // MARK: - Connection Observation

    /// Start listening for user-initiated requests to demo users
    private func startObservingConnectionRequests() {
        // This is called from start() but actual observation happens
        // when onConnectionRequestSent is called from ConnectionService
        Log.debug("Demo behavior service ready to observe connection requests", category: .social)
    }

    // MARK: - Notifications

    /// Create notification for user that demo user accepted their request
    private func createAcceptanceNotification(demoUserId: String, connectionId: String) async {
        guard let userId = auth.currentUser?.uid else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let notificationId = UUID().uuidString
        let now = Date()

        let notificationData: [String: Any] = [
            "id": notificationId,
            "type": "connectionRequestAccepted",
            "actorUserId": demoUserId,
            "actorDisplayName": demoInfo.displayName,
            "actorPhotoURL": demoInfo.photoURL,
            "connectionId": connectionId,
            "timestamp": Timestamp(date: now),
            "read": false,
            "isDemoNotification": true
        ]

        do {
            try await db.collection("users")
                .document(userId)
                .collection("notifications")
                .document(notificationId)
                .setData(notificationData)
        } catch {
            Log.error("Failed to create acceptance notification", category: .social, error: error)
        }
    }

    /// Create notification for user that demo user sent them a request
    private func createConnectionRequestNotification(
        forUserId userId: String,
        fromDemoUserId demoUserId: String,
        connectionId: String
    ) async {
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let notificationId = UUID().uuidString
        let now = Date()

        let notificationData: [String: Any] = [
            "id": notificationId,
            "type": "connectionRequestReceived",
            "actorUserId": demoUserId,
            "actorDisplayName": demoInfo.displayName,
            "actorPhotoURL": demoInfo.photoURL,
            "connectionId": connectionId,
            "timestamp": Timestamp(date: now),
            "read": false,
            "isDemoNotification": true
        ]

        do {
            try await db.collection("users")
                .document(userId)
                .collection("notifications")
                .document(notificationId)
                .setData(notificationData)
        } catch {
            Log.error("Failed to create connection request notification", category: .social, error: error)
        }
    }

    /// Create notification for user that demo user shared a recipe
    private func createRecipeShareNotification(
        forUserId userId: String,
        fromDemoUserId demoUserId: String,
        shareId: String,
        recipeTitle: String
    ) async {
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let notificationId = UUID().uuidString
        let now = Date()

        let notificationData: [String: Any] = [
            "id": notificationId,
            "type": "connectionSharedRecipe",
            "actorUserId": demoUserId,
            "actorDisplayName": demoInfo.displayName,
            "actorPhotoURL": demoInfo.photoURL,
            "shareId": shareId,
            "recipeTitle": recipeTitle,
            "deepLinkURL": "heirloom://share/\(shareId)",
            "timestamp": Timestamp(date: now),
            "read": false,
            "isDemoNotification": true
        ]

        do {
            try await db.collection("users")
                .document(userId)
                .collection("notifications")
                .document(notificationId)
                .setData(notificationData)
        } catch {
            Log.error("Failed to create recipe share notification", category: .social, error: error)
        }
    }

    // MARK: - User Accepts Demo Request

    /// Call this when user accepts a pending request from a demo user
    /// Schedules the recipe share
    func onDemoConnectionAccepted(demoUserId: String, connectionId: String) {
        guard gate.isEnabled else { return }
        guard isDemoUser(demoUserId) else { return }

        scheduleRecipeShare(demoUserId: demoUserId, connectionId: connectionId)
    }

    // MARK: - User Shares Recipe With Demo Connection

    /// Delay range for demo user to accept a shared recipe (seconds)
    private let shareAcceptDelayRange: ClosedRange<Double> = 5...30

    /// Delay range for demo user to modify the recipe after accepting (seconds)
    private let recipeModifyDelayRange: ClosedRange<Double> = 120...300  // 2-5 minutes

    /// Call this when user shares a recipe with a demo connection
    /// Schedules auto-accept and subsequent recipe modification
    func onRecipeSharedWithDemoUser(
        shareId: String,
        recipeId: String,
        recipeTitle: String,
        demoUserId: String
    ) {
        guard gate.isEnabled else { return }
        guard isDemoUser(demoUserId) else { return }

        scheduleShareAcceptance(
            shareId: shareId,
            recipeId: recipeId,
            recipeTitle: recipeTitle,
            demoUserId: demoUserId
        )
    }

    /// Schedule demo user acceptance of a shared recipe
    private func scheduleShareAcceptance(
        shareId: String,
        recipeId: String,
        recipeTitle: String,
        demoUserId: String
    ) {
        let delay = Double.random(in: shareAcceptDelayRange)

        Log.info("Scheduling demo share acceptance", category: .social, metadata: [
            "shareId": shareId,
            "demoUserId": demoUserId,
            "delaySeconds": delay
        ])

        let taskKey = "shareAccept_\(shareId)"
        scheduledTasks[taskKey]?.cancel()

        scheduledTasks[taskKey] = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard !Task.isCancelled else { return }
                guard gate.isEnabled else { return }

                await performShareAcceptance(
                    shareId: shareId,
                    recipeId: recipeId,
                    recipeTitle: recipeTitle,
                    demoUserId: demoUserId
                )
            } catch {
                // Task was cancelled
            }
        }
    }

    /// Perform demo user acceptance of the shared recipe
    private func performShareAcceptance(
        shareId: String,
        recipeId: String,
        recipeTitle: String,
        demoUserId: String
    ) async {
        guard let userId = auth.currentUser?.uid else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let now = Date()

        // Update share document to mark as accepted by demo user
        do {
            try await db.collection("shares").document(shareId).updateData([
                "acceptedBy": FieldValue.arrayUnion([demoUserId]),
                "acceptCount": FieldValue.increment(Int64(1)),
                "lastAcceptedAt": Timestamp(date: now)
            ])

            Log.info("Demo user accepted shared recipe", category: .social, metadata: [
                "shareId": shareId,
                "demoUserId": demoUserId
            ])

            // Create notification for user that demo user accepted
            let notificationId = UUID().uuidString
            let notificationData: [String: Any] = [
                "id": notificationId,
                "type": "shareAccepted",
                "actorUserId": demoUserId,
                "actorDisplayName": demoInfo.displayName,
                "actorPhotoURL": demoInfo.photoURL,
                "shareId": shareId,
                "recipeTitle": recipeTitle,
                "timestamp": Timestamp(date: now),
                "read": false,
                "isDemoNotification": true
            ]

            try await db.collection("users")
                .document(userId)
                .collection("notifications")
                .document(notificationId)
                .setData(notificationData)

            // Create lineage record for the demo user's "copy" of the recipe
            await createDemoLineageRecord(
                recipeId: recipeId,
                demoUserId: demoUserId,
                originalOwnerId: userId
            )

            // Schedule recipe modification after acceptance
            scheduleRecipeModification(
                shareId: shareId,
                recipeId: recipeId,
                recipeTitle: recipeTitle,
                demoUserId: demoUserId
            )

        } catch {
            Log.error("Failed to accept share for demo user", category: .social, error: error)
        }

        scheduledTasks.removeValue(forKey: "shareAccept_\(shareId)")
    }

    /// Create a lineage record for the demo user's copy of the shared recipe
    private func createDemoLineageRecord(
        recipeId: String,
        demoUserId: String,
        originalOwnerId: String
    ) async {
        guard let recipeUUID = UUID(uuidString: recipeId) else { return }

        let lineageId = UUID().uuidString
        let now = Date()

        // Create lineage record for demo user (generation 1)
        let lineageData: [String: Any] = [
            "id": lineageId,
            "rootRecipeId": recipeId,
            "parentRecipeId": recipeId,
            "currentRecipeId": recipeId,  // Same recipe ID for collaborative editing
            "ownerId": demoUserId,
            "rootOwnerId": originalOwnerId,
            "generation": 1,
            "createdAt": Timestamp(date: now),
            "lastModified": Timestamp(date: now),
            "isHeirloom": true,
            "hasLocalModifications": false,
            "modifications": []
        ]

        do {
            // Store in global lineages collection (for cross-user queries)
            try await db.collection("lineages").document(lineageId).setData(lineageData)

            Log.info("Created demo user lineage record", category: .social, metadata: [
                "lineageId": lineageId,
                "demoUserId": demoUserId
            ])
        } catch {
            Log.error("Failed to create demo lineage record", category: .social, error: error)
        }
    }

    /// Schedule demo user modification of the shared recipe
    private func scheduleRecipeModification(
        shareId: String,
        recipeId: String,
        recipeTitle: String,
        demoUserId: String
    ) {
        let delay = Double.random(in: recipeModifyDelayRange)

        Log.info("Scheduling demo recipe modification", category: .social, metadata: [
            "shareId": shareId,
            "demoUserId": demoUserId,
            "delaySeconds": delay
        ])

        let taskKey = "recipeModify_\(shareId)"
        scheduledTasks[taskKey]?.cancel()

        scheduledTasks[taskKey] = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard !Task.isCancelled else { return }
                guard gate.isEnabled else { return }

                await performRecipeModification(
                    shareId: shareId,
                    recipeId: recipeId,
                    recipeTitle: recipeTitle,
                    demoUserId: demoUserId
                )
            } catch {
                // Task was cancelled
            }
        }
    }

    /// Perform demo user modification of the shared recipe
    private func performRecipeModification(
        shareId: String,
        recipeId: String,
        recipeTitle: String,
        demoUserId: String
    ) async {
        guard let userId = auth.currentUser?.uid else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        // Pick a random modification theme
        let modification = Self.recipeModifications.randomElement() ?? Self.recipeModifications[0]

        let newTitle = modification.titlePrefix + recipeTitle
        let now = Date()

        // Update the recipe in Firestore (user's copy)
        do {
            let recipeRef = db.collection("users")
                .document(userId)
                .collection("recipes")
                .document(recipeId)

            // First fetch the current recipe to add ingredient
            let recipeDoc = try await recipeRef.getDocument()

            guard recipeDoc.exists else {
                Log.warning("Recipe not found for demo modification", category: .social)
                return
            }

            // Update recipe title
            try await recipeRef.updateData([
                "title": newTitle,
                "modifiedAt": Timestamp(date: now)
            ])

            // Add the new ingredient to the recipe's ingredients subcollection
            let ingredientId = UUID().uuidString
            let ingredientData: [String: Any] = [
                "id": ingredientId,
                "name": modification.ingredientName,
                "quantity": modification.ingredientQuantity,
                "unit": modification.ingredientUnit,
                "orderIndex": 999,  // Add at end
                "isOptional": false,
                "notes": "Added by \(demoInfo.displayName)",
                "createdAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ]

            try await db.collection("users")
                .document(userId)
                .collection("recipes")
                .document(recipeId)
                .collection("ingredients")
                .document(ingredientId)
                .setData(ingredientData)

            Log.info("Demo user modified shared recipe", category: .social, metadata: [
                "recipeId": recipeId,
                "newTitle": newTitle,
                "addedIngredient": modification.ingredientName,
                "demoUserId": demoUserId
            ])

            // Record the modification in lineage and notify user
            await recordDemoModification(
                recipeId: recipeId,
                demoUserId: demoUserId,
                modificationDescription: modification.description,
                userId: userId
            )

            // Create notification for user about the modification
            await createModificationNotification(
                userId: userId,
                demoUserId: demoUserId,
                recipeId: recipeId,
                recipeTitle: recipeTitle,
                newTitle: newTitle,
                modificationDescription: modification.description
            )

        } catch {
            Log.error("Failed to modify recipe for demo user", category: .social, error: error)
        }

        scheduledTasks.removeValue(forKey: "recipeModify_\(shareId)")
    }

    /// Record the demo modification in lineage system
    private func recordDemoModification(
        recipeId: String,
        demoUserId: String,
        modificationDescription: String,
        userId: String
    ) async {
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let now = Date()
        let modificationId = UUID().uuidString

        // Create modification record
        let modificationData: [String: Any] = [
            "id": modificationId,
            "timestamp": Timestamp(date: now),
            "modifiedBy": demoUserId,
            "modifiedByName": demoInfo.displayName,
            "changeType": "ingredient_added",
            "changeDescription": modificationDescription,
            "fieldChanged": "ingredients"
        ]

        // Find and update the demo user's lineage record
        do {
            let lineageQuery = db.collection("lineages")
                .whereField("ownerId", isEqualTo: demoUserId)
                .whereField("currentRecipeId", isEqualTo: recipeId)

            let snapshot = try await lineageQuery.getDocuments()

            if let lineageDoc = snapshot.documents.first {
                try await lineageDoc.reference.updateData([
                    "modifications": FieldValue.arrayUnion([modificationData]),
                    "lastModified": Timestamp(date: now),
                    "hasLocalModifications": true
                ])

                Log.info("Recorded demo modification in lineage", category: .social)
            }
        } catch {
            Log.error("Failed to record demo modification in lineage", category: .social, error: error)
        }
    }

    /// Create notification for user about demo user's modification
    private func createModificationNotification(
        userId: String,
        demoUserId: String,
        recipeId: String,
        recipeTitle: String,
        newTitle: String,
        modificationDescription: String
    ) async {
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let notificationId = UUID().uuidString
        let now = Date()

        let notificationData: [String: Any] = [
            "id": notificationId,
            "type": "lineage_modification",
            "actorUserId": demoUserId,
            "actorDisplayName": demoInfo.displayName,
            "actorPhotoURL": demoInfo.photoURL,
            "recipeId": recipeId,
            "recipeTitle": newTitle,
            "originalTitle": recipeTitle,
            "changeType": "ingredient_added",
            "changeDescription": modificationDescription,
            "timestamp": Timestamp(date: now),
            "read": false,
            "isDemoNotification": true
        ]

        do {
            try await db.collection("users")
                .document(userId)
                .collection("notifications")
                .document(notificationId)
                .setData(notificationData)

            Log.info("Created modification notification for user", category: .social)
        } catch {
            Log.error("Failed to create modification notification", category: .social, error: error)
        }
    }

    // MARK: - Recipe Modification Themes

    /// Predefined recipe modifications for demo users
    private struct RecipeModification {
        let titlePrefix: String
        let ingredientName: String
        let ingredientQuantity: String
        let ingredientUnit: String
        let description: String
    }

    private static let recipeModifications: [RecipeModification] = [
        RecipeModification(
            titlePrefix: "Spicy ",
            ingredientName: "jalapeño pepper, diced",
            ingredientQuantity: "1",
            ingredientUnit: "",
            description: "Made it spicy by adding jalapeño"
        ),
        RecipeModification(
            titlePrefix: "Garlic Lover's ",
            ingredientName: "extra garlic cloves, minced",
            ingredientQuantity: "3",
            ingredientUnit: "",
            description: "Added extra garlic for more flavor"
        ),
        RecipeModification(
            titlePrefix: "Cheesy ",
            ingredientName: "shredded parmesan cheese",
            ingredientQuantity: "½",
            ingredientUnit: "cup",
            description: "Made it cheesier with extra parmesan"
        ),
        RecipeModification(
            titlePrefix: "Herb-Infused ",
            ingredientName: "fresh rosemary, chopped",
            ingredientQuantity: "2",
            ingredientUnit: "tbsp",
            description: "Added fresh rosemary for an herby twist"
        ),
        RecipeModification(
            titlePrefix: "Smoky ",
            ingredientName: "smoked paprika",
            ingredientQuantity: "1",
            ingredientUnit: "tsp",
            description: "Added smoked paprika for a smoky flavor"
        ),
        RecipeModification(
            titlePrefix: "Zesty ",
            ingredientName: "lemon zest",
            ingredientQuantity: "1",
            ingredientUnit: "tbsp",
            description: "Added lemon zest for brightness"
        ),
        RecipeModification(
            titlePrefix: "Honey-Glazed ",
            ingredientName: "honey",
            ingredientQuantity: "2",
            ingredientUnit: "tbsp",
            description: "Added honey for a sweet glaze"
        ),
        RecipeModification(
            titlePrefix: "Crispy ",
            ingredientName: "panko breadcrumbs",
            ingredientQuantity: "¼",
            ingredientUnit: "cup",
            description: "Added panko for extra crunch"
        )
    ]
}
