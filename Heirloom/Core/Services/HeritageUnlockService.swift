import Foundation
import SwiftData

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

    /// Sync local recipe unlock status with Firebase state
    /// Call this on app launch and after sign-in
    func syncLocalRecipesWithUserState() async throws {
        guard firebaseAuth.currentUser != nil else {
            Log.info("Not authenticated, skipping heritage sync", category: .firebase)
            return
        }

        let userState = try await getUserHeritageState()

        // Fetch all heritage recipes
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isHeritageRecipe == true }
        )
        let heritageRecipes = try modelContext.fetch(descriptor)

        Log.info("Syncing local recipes with user state", category: .storage, metadata: [
            "totalHeritage": heritageRecipes.count,
            "userUnlocked": userState.unlockedRecipeIds.count
        ])

        var syncedCount = 0
        for recipe in heritageRecipes {
            guard let heritageId = recipe.heritageCollectionId else { continue }

            // Unlock if in user's unlocked set
            let shouldBeUnlocked = userState.unlockedRecipeIds.contains(heritageId)

            // Update if state differs
            if recipe.isLocked != !shouldBeUnlocked {
                recipe.isLocked = !shouldBeUnlocked
                syncedCount += 1
            }
        }

        try modelContext.save()

        Log.info("Heritage recipe sync complete", category: .storage, metadata: [
            "syncedCount": syncedCount,
            "nowUnlocked": userState.unlockedRecipeIds.count
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

        // Get next batch
        let startIndex = userState.unlockedRecipeIds.count
        let endIndex = min(startIndex + recipesPerBatch, userState.unlockSchedule.count)

        guard startIndex < endIndex else {
            // No more recipes to unlock
            userState.hasCompletedTrial = true
            try await saveHeritageState(userState, userId: userId)
            return []
        }

        let newlyUnlocked = Array(userState.unlockSchedule[startIndex..<endIndex])

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
        let allRecipeIds = heritageRecipes.compactMap { $0.heritageCollectionId }

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
        // TODO: Implement Firebase fetch
        // For now, check UserDefaults for local testing
        if let data = UserDefaults.standard.data(forKey: "heritage_state_\(userId)"),
           let state = try? JSONDecoder().decode(UserHeritageState.self, from: data) {
            return state
        }
        return nil
    }

    /// Save heritage state to Firebase
    private func saveHeritageState(_ state: UserHeritageState, userId: String) async throws {
        // TODO: Implement Firebase save
        // For now, save to UserDefaults for local testing
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "heritage_state_\(userId)")
        }
    }
}

// MARK: - Data Models

struct UserHeritageState: Codable {
    let userId: String
    var unlockedRecipeIds: [String]     // Heritage recipe IDs user has unlocked
    let unlockSchedule: [String]        // Full 100-recipe unlock order (deterministic)
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
