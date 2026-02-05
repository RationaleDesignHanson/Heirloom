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
}
