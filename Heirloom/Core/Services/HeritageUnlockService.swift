import Foundation
import SwiftData
import FirebaseFirestore

/// Service for managing user-specific heritage recipe unlock state
/// Ensures same user gets same recipes across all devices using deterministic pseudo-random ordering
@MainActor
class HeritageUnlockService {
    private let modelContext: ModelContext
    private let firebaseAuth: FirebaseAuthService

    // MARK: - Configuration

    /// Number of recipes to unlock per batch (daily unlock during trial)
    private let recipesPerBatch = 5

    /// Total heritage recipes in collection
    private let totalHeritageRecipes = 100

    init(modelContext: ModelContext, firebaseAuth: FirebaseAuthService) {
        self.modelContext = modelContext
        self.firebaseAuth = firebaseAuth
    }

    // MARK: - Public API

    /// Get or create user's heritage unlock state from Firebase
    /// This is the source of truth for which recipes are unlocked
    func getUserHeritageState() async throws -> UserHeritageState {
        guard let userId = firebaseAuth.currentUser?.uid else {
            throw HeritageUnlockError.notAuthenticated
        }

        // Try to fetch from Firebase
        if let existingState = try await fetchHeritageState(userId: userId) {
            Log.info("Fetched existing heritage state", category: .firebase, metadata: [
                "userId": userId,
                "unlockedCount": existingState.unlockedRecipeIds.count
            ])
            return existingState
        }

        // Create new state for first-time user
        Log.info("Creating new heritage state for user", category: .firebase, metadata: ["userId": userId])
        let newState = createHeritageState(userId: userId)
        try await saveHeritageState(newState, userId: userId)
        return newState
    }

    /// Sync local HeritageUnlockTracker with Firebase state
    /// Call this on app launch and after sign-in
    func syncLocalRecipesWithUserState() async throws {
        guard firebaseAuth.currentUser != nil else {
            Log.info("Not authenticated, skipping heritage sync", category: .firebase)
            return
        }

        let userState = try await getUserHeritageState()

        // Get the HeritageUnlockTracker
        let tracker = ServiceContainer.shared.resolve(HeritageUnlockTracker.self)

        // Sync unlocked recipe IDs to the tracker
        // Convert heritageRecipeId-based IDs to recipe UUID strings
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isHeritageRecipe == true }
        )
        let heritageRecipes = try modelContext.fetch(descriptor)

        Log.info("Syncing HeritageUnlockTracker with Firebase state", category: .firebase, metadata: [
            "totalHeritage": heritageRecipes.count,
            "firebaseUnlocked": userState.unlockedRecipeIds.count
        ])

        // Build map of heritageRecipeId to recipe UUIDs
        var syncedCount = 0
        for recipe in heritageRecipes {
            guard let heritageId = recipe.heritageRecipeId else { continue }

            // If this recipe's heritage recipe ID is in the unlocked set, unlock it in tracker
            if userState.unlockedRecipeIds.contains(heritageId) {
                let wasAlreadyUnlocked = tracker.unlockedRecipeIds.contains(recipe.id.uuidString)
                if !wasAlreadyUnlocked {
                    tracker.unlockedRecipeIds.insert(recipe.id.uuidString)
                    syncedCount += 1
                }
            }
        }

        Log.info("Heritage recipe sync complete", category: .firebase, metadata: [
            "syncedCount": syncedCount,
            "totalUnlockedInTracker": tracker.unlockedRecipeIds.count
        ])
    }

    /// Unlock next batch of recipes (daily unlock during trial)
    func unlockDailyBatch() async throws -> [String] {
        guard let userId = firebaseAuth.currentUser?.uid else {
            throw HeritageUnlockError.notAuthenticated
        }

        var userState = try await getUserHeritageState()

        // Check if already unlocked today
        if let lastUnlock = userState.lastDailyUnlock,
           Calendar.current.isDateInToday(lastUnlock) {
            Log.info("Daily batch already unlocked today", category: .firebase)
            return []
        }

        // Check if trial completed
        if userState.hasCompletedTrial {
            Log.info("Trial already completed, all recipes unlocked", category: .firebase)
            return []
        }

        // SPECIAL CASE: First unlock (blind box reveal)
        // Select 5 from Literary Kitchen + 3 from other revealed collection
        let newlyUnlocked: [String]
        if userState.unlockedRecipeIds.isEmpty {
            newlyUnlocked = try await unlockInitialBlindBoxRecipes()

            if newlyUnlocked.isEmpty {
                Log.warning("No recipes unlocked on first unlock", category: .firebase)
                return []
            }
        } else {
            // NORMAL CASE: Subsequent unlocks use deterministic schedule
            let startIndex = userState.unlockedRecipeIds.count
            let endIndex = min(startIndex + recipesPerBatch, userState.unlockSchedule.count)

            guard startIndex < endIndex else {
                // No more recipes to unlock
                userState.hasCompletedTrial = true
                try await saveHeritageState(userState, userId: userId)
                return []
            }

            newlyUnlocked = Array(userState.unlockSchedule[startIndex..<endIndex])
        }

        // Update state
        userState.unlockedRecipeIds.append(contentsOf: newlyUnlocked)
        userState.lastDailyUnlock = Date()
        userState.currentBatch += 1

        // Check if completed
        if userState.unlockedRecipeIds.count >= totalHeritageRecipes {
            userState.hasCompletedTrial = true
        }

        // Save to Firebase
        try await saveHeritageState(userState, userId: userId)

        // Sync to local recipes
        try await syncLocalRecipesWithUserState()

        Log.info("Unlocked daily batch", category: .firebase, metadata: [
            "newlyUnlocked": newlyUnlocked.count,
            "totalUnlocked": userState.unlockedRecipeIds.count,
            "batchNumber": userState.currentBatch
        ])

        return newlyUnlocked
    }

    /// Unlock initial recipes from revealed blind boxes (5 from Literary, 3 from other)
    /// This ensures first unlock respects the blind box reveal UX
    private func unlockInitialBlindBoxRecipes() async throws -> [String] {
        // Fetch revealed heritage collections (blind boxes that have been opened)
        let collectionDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { collection in
                collection.heritageCollectionId != nil &&
                collection.isBlindBox == true &&
                collection.isRevealed == true
            }
        )
        let revealedCollections = try modelContext.fetch(collectionDescriptor)
        let revealedCollectionIds = Set(revealedCollections.compactMap { $0.heritageCollectionId })

        guard !revealedCollectionIds.isEmpty else {
            Log.warning("No revealed collections found for initial unlock", category: .firebase)
            return []
        }

        Log.info("Unlocking initial blind box recipes", category: .firebase, metadata: [
            "revealedCollections": revealedCollectionIds.joined(separator: ", ")
        ])

        // Fetch all heritage recipes
        let recipeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isHeritageRecipe == true }
        )
        let allHeritage = try modelContext.fetch(recipeDescriptor)

        // Group by collection
        let grouped = Dictionary(grouping: allHeritage, by: { $0.heritageCollectionId ?? "" })

        var selected: [String] = []
        let literaryKitchenId = "literary-kitchen"

        // Allocate 5 to Literary Kitchen, 3 to the other collection
        for collectionId in revealedCollectionIds.sorted() {
            let targetCount = collectionId == literaryKitchenId ? 5 : 3

            guard let collectionRecipes = grouped[collectionId] else {
                Log.warning("No recipes found for revealed collection", category: .firebase, metadata: [
                    "collection": collectionId
                ])
                continue
            }

            // Randomly select the target number of recipes
            let selectedFromCollection = collectionRecipes
                .shuffled()
                .prefix(targetCount)
                .compactMap { $0.heritageRecipeId }  // Use unique recipe IDs

            selected.append(contentsOf: selectedFromCollection)

            Log.debug("Selected recipes from collection for initial unlock", category: .firebase, metadata: [
                "collection": collectionId,
                "selected": selectedFromCollection.count,
                "target": targetCount,
                "recipeIds": selectedFromCollection.joined(separator: ", ")
            ])
        }

        Log.info("Initial blind box unlock complete", category: .firebase, metadata: [
            "total": selected.count,
            "expected": 8,
            "collections": revealedCollectionIds.joined(separator: ", ")
        ])

        return selected
    }

    /// Unlock all heritage recipes (e.g., after trial ends or user subscribes)
    func unlockAllRecipes() async throws {
        guard let userId = firebaseAuth.currentUser?.uid else {
            throw HeritageUnlockError.notAuthenticated
        }

        var userState = try await getUserHeritageState()

        // Unlock everything
        userState.unlockedRecipeIds = userState.unlockSchedule
        userState.hasCompletedTrial = true
        userState.lastDailyUnlock = Date()

        try await saveHeritageState(userState, userId: userId)
        try await syncLocalRecipesWithUserState()

        Log.info("Unlocked all heritage recipes", category: .firebase, metadata: [
            "userId": userId,
            "totalUnlocked": userState.unlockedRecipeIds.count
        ])
    }

    // MARK: - Private Helpers

    /// Create deterministic unlock schedule for user
    /// Uses user ID as seed to ensure same order on all devices
    private func createHeritageState(userId: String) -> UserHeritageState {
        // Load all heritage recipe IDs from local database
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isHeritageRecipe == true }
        )

        let heritageRecipes = (try? modelContext.fetch(descriptor)) ?? []
        let allRecipeIds = heritageRecipes.compactMap { $0.heritageRecipeId }  // Use unique recipe IDs

        // Create deterministic shuffle using user ID as seed
        let shuffled = deterministicShuffle(allRecipeIds, seed: userId)

        Log.info("Created heritage unlock schedule", category: .firebase, metadata: [
            "userId": userId,
            "totalRecipes": shuffled.count,
            "recipesPerBatch": recipesPerBatch
        ])

        return UserHeritageState(
            userId: userId,
            unlockedRecipeIds: [],
            unlockSchedule: shuffled,
            currentBatch: 0,
            lastDailyUnlock: nil,
            trialEndsAt: nil,
            hasCompletedTrial: false
        )
    }

    /// Deterministic shuffle algorithm using user ID as seed
    /// Same seed always produces same shuffle order
    private func deterministicShuffle<T>(_ array: [T], seed: String) -> [T] {
        guard !array.isEmpty else { return array }

        // Convert seed to numeric hash
        var hasher = Hasher()
        hasher.combine(seed)
        let seedValue = abs(hasher.finalize())

        // Use seeded random number generator
        var rng = SeededRandomNumberGenerator(seed: UInt64(seedValue))

        // Fisher-Yates shuffle with seeded RNG
        var shuffled = array
        for i in (1..<shuffled.count).reversed() {
            let j = Int(rng.next(upperBound: UInt64(i + 1)))
            shuffled.swapAt(i, j)
        }

        return shuffled
    }

    /// Fetch heritage state from Firebase
    private func fetchHeritageState(userId: String) async throws -> UserHeritageState? {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userId).collection("heritageState").document("current")

        do {
            let document = try await docRef.getDocument()

            guard document.exists, let data = document.data() else {
                Log.debug("No heritage state found in Firebase", category: .firebase, metadata: ["userId": userId])
                return nil
            }

            // Parse from Firestore document
            let unlockedRecipeIds = data["unlockedRecipeIds"] as? [String] ?? []
            let unlockSchedule = data["unlockSchedule"] as? [String] ?? []
            let currentBatch = data["currentBatch"] as? Int ?? 0
            let lastDailyUnlock = (data["lastDailyUnlock"] as? Timestamp)?.dateValue()
            let trialEndsAt = (data["trialEndsAt"] as? Timestamp)?.dateValue()
            let hasCompletedTrial = data["hasCompletedTrial"] as? Bool ?? false

            Log.debug("Fetched heritage state from Firebase", category: .firebase, metadata: [
                "userId": userId,
                "unlockedCount": unlockedRecipeIds.count,
                "currentBatch": currentBatch
            ])

            return UserHeritageState(
                userId: userId,
                unlockedRecipeIds: unlockedRecipeIds,
                unlockSchedule: unlockSchedule,
                currentBatch: currentBatch,
                lastDailyUnlock: lastDailyUnlock,
                trialEndsAt: trialEndsAt,
                hasCompletedTrial: hasCompletedTrial
            )
        } catch {
            Log.error("Failed to fetch heritage state from Firebase", category: .firebase, metadata: [
                "userId": userId,
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    /// Save heritage state to Firebase
    private func saveHeritageState(_ state: UserHeritageState, userId: String) async throws {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userId).collection("heritageState").document("current")

        let data: [String: Any] = [
            "userId": state.userId,
            "unlockedRecipeIds": state.unlockedRecipeIds,
            "unlockSchedule": state.unlockSchedule,
            "currentBatch": state.currentBatch,
            "lastDailyUnlock": state.lastDailyUnlock != nil ? Timestamp(date: state.lastDailyUnlock!) : NSNull(),
            "trialEndsAt": state.trialEndsAt != nil ? Timestamp(date: state.trialEndsAt!) : NSNull(),
            "hasCompletedTrial": state.hasCompletedTrial,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await docRef.setData(data, merge: true)

            Log.info("Saved heritage state to Firebase", category: .firebase, metadata: [
                "userId": userId,
                "unlockedCount": state.unlockedRecipeIds.count,
                "currentBatch": state.currentBatch
            ])
        } catch {
            Log.error("Failed to save heritage state to Firebase", category: .firebase, metadata: [
                "userId": userId,
                "error": error.localizedDescription
            ])
            throw error
        }
    }
}

// MARK: - Data Models

struct UserHeritageState: Codable {
    let userId: String
    var unlockedRecipeIds: [String]     // Individual heritage recipe IDs unlocked (e.g., "presidential-001", "literary-005")
    let unlockSchedule: [String]        // Full 100-recipe unlock order (deterministic, individual recipe IDs)
    var currentBatch: Int               // Which batch they're on (0-based)
    var lastDailyUnlock: Date?          // Last daily unlock timestamp
    var trialEndsAt: Date?              // Trial expiration (optional)
    var hasCompletedTrial: Bool         // Unlocked all 100 recipes

    var totalBatches: Int {
        return (unlockSchedule.count + 4) / 5  // Ceiling division
    }

    var unlockedCount: Int {
        return unlockedRecipeIds.count
    }

    var percentComplete: Double {
        guard !unlockSchedule.isEmpty else { return 0 }
        return Double(unlockedRecipeIds.count) / Double(unlockSchedule.count)
    }
}

// MARK: - Seeded Random Number Generator

/// Random number generator with fixed seed for deterministic results
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // Linear congruential generator (simple but deterministic)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func next(upperBound: UInt64) -> UInt64 {
        return next() % upperBound
    }
}

// MARK: - Errors

enum HeritageUnlockError: LocalizedError {
    case notAuthenticated
    case stateNotFound
    case alreadyUnlocked

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User must be authenticated to access heritage recipes"
        case .stateNotFound:
            return "Heritage unlock state not found"
        case .alreadyUnlocked:
            return "Recipe batch already unlocked today"
        }
    }
}

// MARK: - Global Accessor

extension HeritageUnlockService {
    /// Global accessor via ServiceContainer for DI
    nonisolated(unsafe) static var shared: HeritageUnlockService {
        MainActor.assumeIsolated {
            ServiceContainer.shared.resolve(HeritageUnlockService.self)
        }
    }
}
