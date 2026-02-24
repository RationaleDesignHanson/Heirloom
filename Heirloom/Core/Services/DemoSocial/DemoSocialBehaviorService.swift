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
import FirebaseCore
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
    private let proactiveRequestDelay: Double = 0  // Immediate - ready in Table tab after onboarding

    /// Delay before demo user shares recipe after connection established (seconds)
    private let recipeShareDelayRange: ClosedRange<Double> = 5...15  // 5-15 seconds after acceptance

    /// Delay before sending welcome shares after onboarding (seconds)
    private let welcomeShareDelay: Double = 30  // 30 seconds after onboarding

    // MARK: - Dependencies

    private let gate: DemoSocialGate
    private let db: Firestore?
    private let auth: Auth?

    // MARK: - State

    /// Whether the service has been started
    @Published private(set) var isRunning = false

    /// Active scheduled tasks (for cancellation)
    private var scheduledTasks: [String: Task<Void, Never>] = [:]

    /// Connection IDs we're watching for recipe sharing
    private var pendingRecipeShares: Set<String> = []

    /// UserDefaults key for tracking whether proactive demo request was sent
    private static let proactiveRequestSentKey = "demo_social_proactive_request_sent"

    /// Whether we've already sent a proactive demo request for this user
    private var hasSentProactiveRequest: Bool {
        get { UserDefaults.standard.bool(forKey: Self.proactiveRequestSentKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.proactiveRequestSentKey) }
    }

    // MARK: - Demo User Data

    /// List of demo user IDs
    static let demoUserIds: Set<String> = [
        "demo_grandmazing",
        "demo_phillipfry",
        "demo_chef_maria",
        "demo_fitfoodie",
        "demo_bakingbelle",
        "demo_grillmaster",
        "demo_bigshare"  // Users manually friend him to get the Traveling Bolognese
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
        "demo_bigshare": (
            displayName: "Big Share",
            photoURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bigshare-avatar.webp"
        ),
    ]

    /// Demo recipe details for sharing (includes preview metadata)
    struct DemoRecipeDetails {
        let recipeId: String
        let title: String
        let message: String
        let servings: String
        let prepTime: String
        let cookTime: String
        let ingredientCount: Int
        let instructionCount: Int
        let imageURL: String
        // Lineage override fields (nil = recipe is root, existing behavior)
        let rootRecipeId: String?
        let rootOwnerId: String?
        let shareGeneration: Int  // Generation the RECIPIENT gets (default 1)

        init(recipeId: String, title: String, message: String, servings: String,
             prepTime: String, cookTime: String, ingredientCount: Int, instructionCount: Int,
             imageURL: String, rootRecipeId: String? = nil, rootOwnerId: String? = nil,
             shareGeneration: Int = 1) {
            self.recipeId = recipeId
            self.title = title
            self.message = message
            self.servings = servings
            self.prepTime = prepTime
            self.cookTime = cookTime
            self.ingredientCount = ingredientCount
            self.instructionCount = instructionCount
            self.imageURL = imageURL
            self.rootRecipeId = rootRecipeId
            self.rootOwnerId = rootOwnerId
            self.shareGeneration = shareGeneration
        }
    }

    /// Recommended recipes to share per demo user (UUIDs from seed data)
    /// IMPORTANT: Use lowercase UUIDs to match Firebase document IDs (app uses firebaseString which lowercases)
    static let demoUserWelcomeRecipes: [String: DemoRecipeDetails] = [
        "demo_grandmazing": DemoRecipeDetails(
            recipeId: "5e13b837-1a80-4d22-af8a-c474a6ea5c35",
            title: "Brown Butter Chocolate Chip Cookies",
            message: "Welcome to Heirloom! Here's my most popular recipe to get you started. These cookies are a family favorite!",
            servings: "24 cookies",
            prepTime: "20 min",
            cookTime: "12 min",
            ingredientCount: 11,
            instructionCount: 8,
            imageURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grandmazing_chocolate_chip_cookies-image.webp"
        ),
        "demo_phillipfry": DemoRecipeDetails(
            recipeId: "7ee0a981-0dd2-4105-aa26-ab941c23d688",
            title: "Creamy One-Pot Pasta",
            message: "Hey! Thought you might like this one - it's my go-to weeknight dinner. Super easy and delicious!",
            servings: "4 servings",
            prepTime: "10 min",
            cookTime: "20 min",
            ingredientCount: 9,
            instructionCount: 6,
            imageURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_phillipfry_one_pot_pasta-image.webp"
        ),
        "demo_chef_maria": DemoRecipeDetails(
            recipeId: "5d5a16d4-4fc2-483b-9737-7d0451f3c236",
            title: "Camarones al Ajillo (Garlic Shrimp)",
            message: "Bienvenido! I'd love to share this classic Latin dish with you. It's always a crowd-pleaser!",
            servings: "4 servings",
            prepTime: "15 min",
            cookTime: "10 min",
            ingredientCount: 10,
            instructionCount: 7,
            imageURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_chef_maria_garlic_shrimp-image.webp"
        ),
        "demo_fitfoodie": DemoRecipeDetails(
            recipeId: "f3890dc5-f51a-455a-8bf2-eb4bb089c5a9",
            title: "Ultimate Protein Power Bowl",
            message: "Welcome! This is my favorite post-workout meal. 45g of protein and it actually tastes amazing!",
            servings: "2 servings",
            prepTime: "15 min",
            cookTime: "25 min",
            ingredientCount: 12,
            instructionCount: 8,
            imageURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_fitfoodie_protein_bowl-image.webp"
        ),
        "demo_bakingbelle": DemoRecipeDetails(
            recipeId: "fceb840f-6acb-49f3-a7f0-e1da3de286ff",
            title: "Molten Chocolate Lava Cakes",
            message: "Hi there! I wanted to share my favorite quick dessert. It looks fancy but it's actually super easy!",
            servings: "4 cakes",
            prepTime: "15 min",
            cookTime: "14 min",
            ingredientCount: 7,
            instructionCount: 9,
            imageURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bakingbelle_chocolate_lava_cakes-image.webp"
        ),
        "demo_grillmaster": DemoRecipeDetails(
            recipeId: "1de8ec4c-7629-466d-b39b-87d97b48ec9f",
            title: "Ultimate Smash Burgers",
            message: "Welcome! These burgers are life-changing. Those crispy edges are what it's all about!",
            servings: "4 burgers",
            prepTime: "10 min",
            cookTime: "8 min",
            ingredientCount: 8,
            instructionCount: 7,
            imageURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grillmaster_smash_burgers-image.webp"
        ),
        "demo_bigshare": DemoRecipeDetails(
            recipeId: "e5f6a7b8-c9d0-1234-efab-345678901234",
            title: "The Traveling Bolognese",
            message: "This recipe started with Grandmazing in Vermont and has traveled through 5 kitchens — each person added their own twist. Accept it and check the Family Tree to see how it evolved!",
            servings: "6 servings",
            prepTime: "20 min",
            cookTime: "4 hours",
            ingredientCount: 14,
            instructionCount: 8,
            imageURL: "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bigshare_bolognese-image.webp",
            rootRecipeId: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            rootOwnerId: "demo_grandmazing",
            shareGeneration: 2
        ),
    ]

    // MARK: - Initialization

    init(
        gate: DemoSocialGate? = nil,
        db: Firestore? = nil,
        auth: Auth? = nil
    ) {
        // Create gate inside init body (MainActor context) if not provided
        self.gate = gate ?? .shared
        // Only initialize Firebase if configured (allows tests to run without Firebase)
        if FirebaseApp.app() != nil {
            self.db = db ?? Firestore.firestore()
            self.auth = auth ?? Auth.auth()
        } else {
            self.db = db
            self.auth = auth
        }
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
    /// Flow: Friend request first → User accepts → Then demo user shares a recipe
    func onOnboardingComplete() {
        guard gate.isEnabled else { return }

        // Only schedule the proactive friend request
        // Recipe sharing happens AFTER user accepts (via onDemoConnectionAccepted)
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
        Self.isDemoUser(userId)
    }

    /// Static check if a user ID belongs to a demo user (for use without instance)
    static func isDemoUser(_ userId: String) -> Bool {
        demoUserIds.contains(userId)
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
    /// Note: Only updates real user's connection doc (not demo user's)
    private func performAutoAccept(demoUserId: String, connectionId: String) async {
        guard let db = db, let auth = auth, let userId = auth.currentUser?.uid else { return }

        let now = Date()

        // Only update real user's connection document
        // Demo user accounts don't have connection docs
        let userConnectionRef = db.collection("users")
            .document(userId)
            .collection("connections")
            .document(connectionId)

        do {
            try await userConnectionRef.updateData([
                "status": ConnectionStatus.connected.rawValue,
                "acceptedAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ])

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
        guard let auth = auth, let userId = auth.currentUser?.uid else { return }

        // Fast local check — prevent duplicate requests across app launches
        if hasSentProactiveRequest {
            Log.debug("Proactive demo request already sent (UserDefaults), skipping", category: .social)
            return
        }

        // Check if user already has a demo connection (don't spam)
        Task {
            let hasExistingDemo = await checkIfUserHasDemoConnection(userId: userId)
            if hasExistingDemo {
                Log.debug("User already has demo connection, skipping proactive request", category: .social)
                hasSentProactiveRequest = true  // Mark so we don't re-check next launch
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
        guard let db = db else { return false }
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
    /// Note: Only creates connection doc in real user's account (not demo user's)
    /// to prevent demo accounts from accumulating data from all TestFlight users
    private func sendProactiveDemoRequest(toUserId: String) async {
        guard let db = db else { return }

        // Pick a random demo user
        let demoUserId = Self.demoUserIds.randomElement() ?? "demo_grandmazing"
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let connectionId = UUID().uuidString.lowercased()
        let now = Date()

        // Only create connection document in real user's collection
        // Demo user accounts don't need connection docs - they use hardcoded stats
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
            "isKitchenTableConnection": false,
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now),
            "isDemoConnection": true
        ]

        do {
            // Create only in real user's collection
            try await db.collection("users")
                .document(toUserId)
                .collection("connections")
                .document(connectionId)
                .setData(userConnection)

            // Mark as sent so we never duplicate on subsequent launches
            hasSentProactiveRequest = true

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

    // MARK: - Welcome Shares (Phase 10)

    /// Schedule welcome shares to be sent shortly after onboarding completes
    private func scheduleWelcomeShares() {
        guard let auth = auth, let userId = auth.currentUser?.uid else { return }

        let taskKey = "welcomeShares_\(userId)"
        scheduledTasks[taskKey]?.cancel()

        Log.info("Scheduling welcome shares", category: .social, metadata: [
            "delaySeconds": welcomeShareDelay
        ])

        scheduledTasks[taskKey] = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(welcomeShareDelay * 1_000_000_000))

                guard !Task.isCancelled else { return }
                guard gate.isEnabled else { return }

                await sendWelcomeShares(toUserId: userId)
            } catch {
                // Task was cancelled
            }
        }
    }

    /// Send 1-2 welcome shares from demo users to a new user
    /// These appear immediately in the user's "Shared with Me" inbox
    private func sendWelcomeShares(toUserId userId: String) async {
        // Check if user has already received welcome shares (prevent duplicates)
        let hasReceivedWelcome = await checkIfUserHasWelcomeShares(userId: userId)
        if hasReceivedWelcome {
            Log.debug("User already has welcome shares, skipping", category: .social)
            scheduledTasks.removeValue(forKey: "welcomeShares_\(userId)")
            return
        }

        // Pick 2 random demo users to send welcome shares
        let demoUsers = Array(Self.demoUserIds.shuffled().prefix(2))

        Log.info("Sending welcome shares from demo users", category: .social, metadata: [
            "demoUsers": demoUsers.joined(separator: ", "),
            "recipientUserId": userId
        ])

        for demoUserId in demoUsers {
            await sendSingleWelcomeShare(
                fromDemoUserId: demoUserId,
                toUserId: userId
            )

            // Small delay between shares
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
        }

        scheduledTasks.removeValue(forKey: "welcomeShares_\(userId)")
    }

    /// Check if user has already received welcome shares
    private func checkIfUserHasWelcomeShares(userId: String) async -> Bool {
        guard let db = db else { return false }
        do {
            let snapshot = try await db.collection("shares")
                .whereField("recipientUserIds", arrayContains: userId)
                .whereField("isWelcomeShare", isEqualTo: true)
                .limit(to: 1)
                .getDocuments()

            return !snapshot.documents.isEmpty
        } catch {
            return false
        }
    }

    /// Send a single welcome share from a demo user
    private func sendSingleWelcomeShare(
        fromDemoUserId demoUserId: String,
        toUserId userId: String
    ) async {
        guard let db = db else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }
        guard let welcomeRecipe = Self.demoUserWelcomeRecipes[demoUserId] else { return }

        // Check if we already sent a welcome share from this demo user to this user
        do {
            let existingShares = try await db.collection("shares")
                .whereField("ownerId", isEqualTo: demoUserId)
                .whereField("recipeId", isEqualTo: welcomeRecipe.recipeId)
                .whereField("recipientUserIds", arrayContains: userId)
                .getDocuments()

            if !existingShares.documents.isEmpty {
                Log.debug("Welcome share already exists, skipping duplicate", category: .social, metadata: [
                    "demoUserId": demoUserId
                ])
                return
            }
        } catch {
            Log.warning("Failed to check existing welcome shares, proceeding anyway", category: .social)
        }

        let shareId = UUID().uuidString.lowercased()
        let now = Date()
        let expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: now)!

        // Create the welcome share document with full preview details
        let shareData: [String: Any] = [
            "shareId": shareId,
            "recipeId": welcomeRecipe.recipeId,
            "ownerId": demoUserId,
            "ownerName": demoInfo.displayName,
            "recipeTitle": welcomeRecipe.title,
            "shareType": "heirloom",
            "createdAt": Timestamp(date: now),
            "sharedAt": Timestamp(date: now),
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
            "generation": welcomeRecipe.shareGeneration,
            "rootRecipeId": welcomeRecipe.rootRecipeId ?? welcomeRecipe.recipeId,
            "rootOwnerId": welcomeRecipe.rootOwnerId ?? demoUserId,
            "recipientUserIds": [userId],
            "isDirectShare": true,
            "sharedWithCount": 1,
            "acceptedBy": [],
            "acceptCount": 0,
            "viewCount": 0,
            "isDemoShare": true,
            "isWelcomeShare": true,  // Mark as welcome share for deduplication
            // Heritage chain for offline lineage display
            "heritageChain": buildHeritageChain(for: welcomeRecipe, sharerId: demoUserId),
            "heritageChainNames": buildHeritageChainNames(for: welcomeRecipe, sharerName: demoInfo.displayName),
            // Recipe preview fields for share sheet display
            "servings": welcomeRecipe.servings,
            "prepTime": welcomeRecipe.prepTime,
            "cookTime": welcomeRecipe.cookTime,
            "ingredientCount": welcomeRecipe.ingredientCount,
            "instructionCount": welcomeRecipe.instructionCount,
            "firebaseImageURL": welcomeRecipe.imageURL
        ]

        do {
            try await db.collection("shares").document(shareId).setData(shareData)

            Log.info("Welcome share sent", category: .social, metadata: [
                "shareId": shareId,
                "fromDemoUser": demoUserId,
                "recipeId": welcomeRecipe.recipeId
            ])

            // Create notification for user about the welcome share
            await createWelcomeShareNotification(
                forUserId: userId,
                fromDemoUserId: demoUserId,
                shareId: shareId,
                recipeTitle: welcomeRecipe.title
            )

        } catch {
            Log.error("Failed to send welcome share", category: .social, error: error, metadata: [
                "demoUserId": demoUserId
            ])
        }
    }

    /// Create notification for welcome share
    private func createWelcomeShareNotification(
        forUserId userId: String,
        fromDemoUserId demoUserId: String,
        shareId: String,
        recipeTitle: String
    ) async {
        guard let db = db else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let notificationId = UUID().uuidString.lowercased()
        let now = Date()

        let notificationData: [String: Any] = [
            "id": notificationId,
            "type": "welcomeRecipeShare",
            "actorUserId": demoUserId,
            "actorDisplayName": demoInfo.displayName,
            "actorPhotoURL": demoInfo.photoURL,
            "shareId": shareId,
            "recipeTitle": recipeTitle,
            "deepLinkURL": "heirloom://share/\(shareId)",
            "timestamp": Timestamp(date: now),
            "read": false,
            "isDemoNotification": true,
            "isWelcomeNotification": true
        ]

        do {
            try await db.collection("users")
                .document(userId)
                .collection("notifications")
                .document(notificationId)
                .setData(notificationData)
        } catch {
            Log.error("Failed to create welcome share notification", category: .social, error: error)
        }
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

        // Use detached task to survive view lifecycle changes
        // Store task reference for potential cancellation
        let task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard !Task.isCancelled else { return }
                guard let self = self else { return }
                guard self.gate.isEnabled else { return }

                await self.performRecipeShare(demoUserId: demoUserId, connectionId: connectionId)
            } catch {
                // Task was cancelled
            }
        }
        scheduledTasks[taskKey] = task
    }

    /// Perform the recipe share from demo user
    private func performRecipeShare(demoUserId: String, connectionId: String) async {
        Log.info("Executing demo recipe share", category: .social, metadata: [
            "demoUserId": demoUserId,
            "connectionId": connectionId
        ])

        guard let db = db, let auth = auth, let userId = auth.currentUser?.uid else {
            Log.warning("Demo share failed: missing db/auth/userId", category: .social)
            return
        }
        guard let welcomeRecipe = Self.demoUserWelcomeRecipes[demoUserId] else {
            Log.warning("Demo share failed: no welcome recipe for user", category: .social, metadata: ["demoUserId": demoUserId])
            return
        }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else {
            Log.warning("Demo share failed: no demo info for user", category: .social, metadata: ["demoUserId": demoUserId])
            return
        }

        // Check if we already shared this recipe to this user
        do {
            let existingShares = try await db.collection("shares")
                .whereField("ownerId", isEqualTo: demoUserId)
                .whereField("recipeId", isEqualTo: welcomeRecipe.recipeId)
                .whereField("recipientUserIds", arrayContains: userId)
                .getDocuments()

            if !existingShares.documents.isEmpty {
                Log.debug("Demo share already exists, skipping duplicate", category: .social, metadata: [
                    "demoUserId": demoUserId,
                    "existingShareCount": existingShares.documents.count
                ])
                return
            }
        } catch {
            Log.warning("Failed to check existing shares, proceeding anyway", category: .social)
        }

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

        let shareId = UUID().uuidString.lowercased()
        let now = Date()
        let expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: now)!

        // Create the share document with full recipe preview details
        let shareData: [String: Any] = [
            "shareId": shareId,
            "recipeId": welcomeRecipe.recipeId,
            "ownerId": demoUserId,
            "ownerName": demoInfo.displayName,
            "recipeTitle": welcomeRecipe.title,
            "shareType": "heirloom",
            "createdAt": Timestamp(date: now),
            "sharedAt": Timestamp(date: now),
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
            "generation": welcomeRecipe.shareGeneration,
            "rootRecipeId": welcomeRecipe.rootRecipeId ?? welcomeRecipe.recipeId,
            "rootOwnerId": welcomeRecipe.rootOwnerId ?? demoUserId,
            "recipientUserIds": [userId],
            "isDirectShare": true,
            "sharedWithCount": 1,
            "acceptedBy": [],
            "acceptCount": 0,
            "viewCount": 0,
            "isDemoShare": true,
            // Heritage chain for offline lineage display
            "heritageChain": buildHeritageChain(for: welcomeRecipe, sharerId: demoUserId),
            "heritageChainNames": buildHeritageChainNames(for: welcomeRecipe, sharerName: demoInfo.displayName),
            // Recipe preview fields for share sheet display
            "servings": welcomeRecipe.servings,
            "prepTime": welcomeRecipe.prepTime,
            "cookTime": welcomeRecipe.cookTime,
            "ingredientCount": welcomeRecipe.ingredientCount,
            "instructionCount": welcomeRecipe.instructionCount,
            "firebaseImageURL": welcomeRecipe.imageURL
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
                recipeTitle: welcomeRecipe.title
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
        // Use lowercase comparison for consistency with Firebase document IDs
        switch recipeId.lowercased() {
        case "5e13b837-1a80-4d22-af8a-c474a6ea5c35":
            return "Brown Butter Chocolate Chip Cookies"
        case "7ee0a981-0dd2-4105-aa26-ab941c23d688":
            return "Creamy One-Pot Pasta"
        case "5d5a16d4-4fc2-483b-9737-7d0451f3c236":
            return "Camarones al Ajillo (Garlic Shrimp)"
        case "f3890dc5-f51a-455a-8bf2-eb4bb089c5a9":
            return "Ultimate Protein Power Bowl"
        case "fceb840f-6acb-49f3-a7f0-e1da3de286ff":
            return "Molten Chocolate Lava Cakes"
        case "1de8ec4c-7629-466d-b39b-87d97b48ec9f":
            return "Ultimate Smash Burgers"
        default:
            return "Recipe"
        }
    }

    /// Build heritage chain (user IDs) for demo recipe
    /// Includes root owner and current sharer for multi-gen demos
    private func buildHeritageChain(for recipe: DemoRecipeDetails, sharerId: String) -> [String] {
        if let rootOwnerId = recipe.rootOwnerId, rootOwnerId != sharerId {
            // Multi-gen recipe: root owner → sharer
            return [rootOwnerId, sharerId]
        } else {
            // Single owner recipe
            return [sharerId]
        }
    }

    /// Build heritage chain names (display names) for demo recipe
    /// Parallel to buildHeritageChain - same order, display names instead of IDs
    private func buildHeritageChainNames(for recipe: DemoRecipeDetails, sharerName: String) -> [String] {
        if let rootOwnerId = recipe.rootOwnerId, let rootOwnerInfo = Self.demoUserInfo[rootOwnerId] {
            // Multi-gen recipe: root owner name → sharer name
            return [rootOwnerInfo.displayName, sharerName]
        } else {
            // Single owner recipe
            return [sharerName]
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
        guard let db = db, let auth = auth, let userId = auth.currentUser?.uid else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let notificationId = UUID().uuidString.lowercased()
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
        guard let db = db else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let notificationId = UUID().uuidString.lowercased()
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
        guard let db = db else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let notificationId = UUID().uuidString.lowercased()
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
    private let recipeModifyDelayRange: ClosedRange<Double> = 15...45  // 15-45 seconds for testing

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
        guard let db = db, let auth = auth, let userId = auth.currentUser?.uid else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let now = Date()

        do {
            // 1. Update share document to mark as accepted by demo user
            try await db.collection("shares").document(shareId).updateData([
                "acceptedBy": FieldValue.arrayUnion([demoUserId]),
                "acceptCount": FieldValue.increment(Int64(1)),
                "lastAcceptedAt": Timestamp(date: now)
            ])

            Log.info("Demo user accepted shared recipe", category: .social, metadata: [
                "shareId": shareId,
                "demoUserId": demoUserId
            ])

            // 2. Copy the recipe to demo user's collection (like real acceptance)
            await copyRecipeToDemoUser(
                recipeId: recipeId,
                fromUserId: userId,
                toDemoUserId: demoUserId
            )

            // 3. Create notification for user that demo user accepted
            let notificationId = UUID().uuidString.lowercased()
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

            // 4. Create lineage record for the demo user's copy of the recipe
            await createDemoLineageRecord(
                recipeId: recipeId,
                demoUserId: demoUserId,
                originalOwnerId: userId
            )

            // 5. Schedule recipe modification after acceptance
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

    /// Copy recipe from original user to demo user's collection
    private func copyRecipeToDemoUser(
        recipeId: String,
        fromUserId: String,
        toDemoUserId: String
    ) async {
        guard let db = db else { return }

        do {
            // Fetch original recipe
            let originalRecipeRef = db.collection("users")
                .document(fromUserId)
                .collection("recipes")
                .document(recipeId)

            let recipeDoc = try await originalRecipeRef.getDocument()

            guard recipeDoc.exists, var recipeData = recipeDoc.data() else {
                Log.warning("Original recipe not found for demo copy", category: .social)
                return
            }

            // Update metadata for demo user's copy
            let now = Date()
            recipeData["ownerId"] = toDemoUserId
            recipeData["sharedDate"] = Timestamp(date: now)
            recipeData["modifiedAt"] = Timestamp(date: now)

            // Copy recipe to demo user's collection (same ID for lineage tracking)
            let demoRecipeRef = db.collection("users")
                .document(toDemoUserId)
                .collection("recipes")
                .document(recipeId)

            try await demoRecipeRef.setData(recipeData)

            // Copy ingredients subcollection
            let ingredientsSnapshot = try await originalRecipeRef
                .collection("ingredients")
                .getDocuments()

            for ingredientDoc in ingredientsSnapshot.documents {
                try await demoRecipeRef
                    .collection("ingredients")
                    .document(ingredientDoc.documentID)
                    .setData(ingredientDoc.data())
            }

            Log.info("Copied recipe to demo user collection", category: .social, metadata: [
                "recipeId": recipeId,
                "demoUserId": toDemoUserId,
                "ingredientCount": ingredientsSnapshot.documents.count
            ])

        } catch {
            Log.error("Failed to copy recipe to demo user", category: .social, error: error)
        }
    }

    /// Create a lineage record for the demo user's copy of the shared recipe
    private func createDemoLineageRecord(
        recipeId: String,
        demoUserId: String,
        originalOwnerId: String
    ) async {
        guard let db = db else { return }
        guard UUID(uuidString: recipeId) != nil else { return }

        let lineageId = UUID().uuidString.lowercased()
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
        guard let db = db, let auth = auth, let userId = auth.currentUser?.uid else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        // Pick a random modification theme
        let modification = Self.recipeModifications.randomElement() ?? Self.recipeModifications[0]

        let newTitle = modification.titlePrefix + recipeTitle
        let now = Date()

        // Update the recipe in the DEMO USER'S collection (not the original user's)
        do {
            let recipeRef = db.collection("users")
                .document(demoUserId)  // Demo user's copy
                .collection("recipes")
                .document(recipeId)

            // First fetch the demo user's copy of the recipe
            let recipeDoc = try await recipeRef.getDocument()

            guard recipeDoc.exists else {
                Log.warning("Demo user's recipe copy not found for modification", category: .social, metadata: [
                    "recipeId": recipeId,
                    "demoUserId": demoUserId
                ])
                return
            }

            // Update recipe title on demo user's copy
            try await recipeRef.updateData([
                "title": newTitle,
                "modifiedAt": Timestamp(date: now)
            ])

            // Add the new ingredient to the demo user's recipe
            let ingredientId = UUID().uuidString.lowercased()
            let ingredientData: [String: Any] = [
                "id": ingredientId,
                "name": modification.ingredientName,
                "quantity": modification.ingredientQuantity,
                "unit": modification.ingredientUnit,
                "originalText": modification.originalText,
                "orderIndex": 999,  // Add at end
                "isOptional": false,
                "notes": "Added by \(demoInfo.displayName)",
                "createdAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ]

            try await db.collection("users")
                .document(demoUserId)  // Demo user's copy
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
        guard let db = db else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let now = Date()
        let modificationId = UUID().uuidString.lowercased()

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
        guard let db = db else { return }
        guard let demoInfo = Self.demoUserInfo[demoUserId] else { return }

        let notificationId = UUID().uuidString.lowercased()
        let now = Date()

        // Note: FirebaseNotificationService.parseNotification() requires these exact fields:
        // - recipeId (UUID string)
        // - rootRecipeId (UUID string)
        // - generation (Int)
        // - modifiedBy (String)
        // - modifiedByName (String, optional)
        // - changeType (String)
        // - changeDescription (String)
        // - timestamp (Timestamp)
        // - read (Bool)
        let notificationData: [String: Any] = [
            "id": notificationId,
            "type": "lineage_modification",
            "recipeId": recipeId,
            "rootRecipeId": recipeId,  // Same as recipeId for shared recipes
            "generation": 1,  // Demo user is first generation recipient
            "modifiedBy": demoUserId,
            "modifiedByName": demoInfo.displayName,
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
        let ingredientQuantity: Double
        let ingredientUnit: String
        let originalText: String  // Full text for display
        let description: String
    }

    private static let recipeModifications: [RecipeModification] = [
        RecipeModification(
            titlePrefix: "Spicy ",
            ingredientName: "jalapeño pepper, diced",
            ingredientQuantity: 1,
            ingredientUnit: "",
            originalText: "1 jalapeño pepper, diced",
            description: "Made it spicy by adding jalapeño"
        ),
        RecipeModification(
            titlePrefix: "Garlic Lover's ",
            ingredientName: "extra garlic cloves, minced",
            ingredientQuantity: 3,
            ingredientUnit: "",
            originalText: "3 extra garlic cloves, minced",
            description: "Added extra garlic for more flavor"
        ),
        RecipeModification(
            titlePrefix: "Cheesy ",
            ingredientName: "shredded parmesan cheese",
            ingredientQuantity: 0.5,
            ingredientUnit: "cup",
            originalText: "½ cup shredded parmesan cheese",
            description: "Made it cheesier with extra parmesan"
        ),
        RecipeModification(
            titlePrefix: "Herb-Infused ",
            ingredientName: "fresh rosemary, chopped",
            ingredientQuantity: 2,
            ingredientUnit: "tbsp",
            originalText: "2 tbsp fresh rosemary, chopped",
            description: "Added fresh rosemary for an herby twist"
        ),
        RecipeModification(
            titlePrefix: "Smoky ",
            ingredientName: "smoked paprika",
            ingredientQuantity: 1,
            ingredientUnit: "tsp",
            originalText: "1 tsp smoked paprika",
            description: "Added smoked paprika for a smoky flavor"
        ),
        RecipeModification(
            titlePrefix: "Zesty ",
            ingredientName: "lemon zest",
            ingredientQuantity: 1,
            ingredientUnit: "tbsp",
            originalText: "1 tbsp lemon zest",
            description: "Added lemon zest for brightness"
        ),
        RecipeModification(
            titlePrefix: "Honey-Glazed ",
            ingredientName: "honey",
            ingredientQuantity: 2,
            ingredientUnit: "tbsp",
            originalText: "2 tbsp honey",
            description: "Added honey for a sweet glaze"
        ),
        RecipeModification(
            titlePrefix: "Crispy ",
            ingredientName: "panko breadcrumbs",
            ingredientQuantity: 0.25,
            ingredientUnit: "cup",
            originalText: "¼ cup panko breadcrumbs",
            description: "Added panko for extra crunch"
        )
    ]
}
