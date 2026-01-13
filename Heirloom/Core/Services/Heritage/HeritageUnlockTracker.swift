//
//  HeritageUnlockTracker.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-13.
//

import Foundation
import SwiftData

/// Tracks heritage recipe unlocks during trial period
/// Manages progressive unlock system: ~7 recipes/day over 14-day trial
@MainActor
class HeritageUnlockTracker: ObservableObject {
    @Published var unlockedRecipeIds: Set<String> = []
    @Published var lastUnlockDate: Date?
    @Published var trialStartDate: Date?

    private let userDefaults = UserDefaults.standard
    private let unlockedRecipesKey = "heritageUnlockedRecipeIds"
    private let lastUnlockDateKey = "heritageLastUnlockDate"
    private let trialStartDateKey = "heritageTrialStartDate"

    // MARK: - Initialization

    init() {
        loadFromStorage()
    }

    // MARK: - Unlock Logic

    /// Check if user has unlocks available today
    var hasUnlocksAvailableToday: Bool {
        guard let lastUnlock = lastUnlockDate else { return true }
        return !Calendar.current.isDateInToday(lastUnlock)
    }

    /// Calculate how many recipes to unlock today
    var recipesToUnlockToday: Int {
        guard let trialStart = trialStartDate else { return 0 }

        let daysSinceTrialStart = Calendar.current.dateComponents([.day], from: trialStart, to: Date()).day ?? 0

        // 14-day trial: 100 recipes ÷ 14 = ~7 per day
        // Allow catch-up: if user misses days, they can unlock accumulated quota
        let expectedUnlockedByNow = min((daysSinceTrialStart + 1) * 7, 100)
        let currentlyUnlocked = unlockedRecipeIds.count

        return max(0, expectedUnlockedByNow - currentlyUnlocked)
    }

    /// Total recipes remaining to unlock
    var totalRecipesRemaining: Int {
        return max(0, 100 - unlockedRecipeIds.count)
    }

    /// Unlock daily batch of heritage recipes
    func unlockDailyBatch(context: ModelContext) async throws {
        guard hasUnlocksAvailableToday else {
            Log.info("No unlocks available today", category: .heritage)
            return
        }

        let count = recipesToUnlockToday
        guard count > 0 else {
            Log.info("No recipes to unlock (quota already met)", category: .heritage)
            return
        }

        // Fetch revealed heritage collections (blind boxes that have been opened)
        let collectionDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { collection in
                collection.heritageCollectionId != nil && collection.isBlindBox == true && collection.isRevealed == true
            }
        )
        let revealedCollections = try context.fetch(collectionDescriptor)
        let revealedCollectionIds = Set(revealedCollections.compactMap { $0.heritageCollectionId })

        guard !revealedCollectionIds.isEmpty else {
            Log.info("No revealed collections yet - cannot unlock recipes", category: .heritage)
            return
        }

        // Fetch all heritage recipes not yet unlocked
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.isHeritageRecipe == true
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        let allHeritage = try context.fetch(descriptor)

        // Filter to only locked recipes from revealed collections
        let lockedRecipes = allHeritage.filter { recipe in
            !unlockedRecipeIds.contains(recipe.id.uuidString) &&
            revealedCollectionIds.contains(recipe.heritageCollectionId ?? "")
        }

        guard !lockedRecipes.isEmpty else {
            Log.info("No locked recipes available in revealed collections", category: .heritage)
            return
        }

        // Select recipes with Literary Kitchen bias (5 for Literary, 2 for other)
        let recipesToUnlock = selectBalancedRecipes(from: lockedRecipes, count: count, revealedCollectionIds: revealedCollectionIds)

        // Mark as unlocked
        for recipe in recipesToUnlock {
            unlockedRecipeIds.insert(recipe.id.uuidString)
        }

        lastUnlockDate = Date()
        saveToStorage()

        Log.info("Unlocked \(recipesToUnlock.count) heritage recipes", category: .heritage, metadata: [
            "totalUnlocked": unlockedRecipeIds.count,
            "remaining": 100 - unlockedRecipeIds.count,
            "revealedCollections": revealedCollectionIds.joined(separator: ", ")
        ])
    }

    /// Select recipes with Literary Kitchen priority allocation
    /// - Literary Kitchen: 5 recipes
    /// - Other revealed collection: 2 recipes
    private func selectBalancedRecipes(from recipes: [Recipe], count: Int, revealedCollectionIds: Set<String>) -> [Recipe] {
        let grouped = Dictionary(grouping: recipes, by: { $0.heritageCollectionId ?? "" })
        var selected: [Recipe] = []

        let literaryKitchenId = "literary-kitchen"

        // Log available recipes per collection for debugging
        for collectionId in revealedCollectionIds.sorted() {
            let availableCount = grouped[collectionId]?.count ?? 0
            Log.debug("Available recipes in collection", category: .heritage, metadata: [
                "collection": collectionId,
                "availableCount": availableCount
            ])
        }

        // Allocate 5 to Literary Kitchen, 2 to the other collection
        for collectionId in revealedCollectionIds.sorted() {
            let targetCount = collectionId == literaryKitchenId ? 5 : 2

            guard let collectionRecipes = grouped[collectionId] else {
                Log.warning("No recipes found for revealed collection", category: .heritage, metadata: [
                    "collection": collectionId
                ])
                continue
            }

            let available = collectionRecipes.filter { !selected.contains($0) }
            let toSelect = min(targetCount, available.count)

            if toSelect < targetCount {
                Log.warning("Not enough recipes available in collection", category: .heritage, metadata: [
                    "collection": collectionId,
                    "target": targetCount,
                    "available": available.count,
                    "selecting": toSelect
                ])
            }

            // Randomly select the target number of recipes
            let selectedFromCollection = available.shuffled().prefix(toSelect)
            selected.append(contentsOf: selectedFromCollection)

            Log.debug("Selected recipes from collection", category: .heritage, metadata: [
                "collection": collectionId,
                "selected": selectedFromCollection.count,
                "target": targetCount
            ])
        }

        Log.info("Total recipes selected for unlock", category: .heritage, metadata: [
            "total": selected.count,
            "expected": 7
        ])

        return selected
    }

    /// Check if a specific recipe is unlocked
    func isUnlocked(_ recipe: Recipe) -> Bool {
        // Check debug override first (defaults to true for non-premium testing)
        let debugForceNonPremium = UserDefaults.standard.object(forKey: "debug_force_non_premium") as? Bool ?? true

        // Premium users have access to all heritage recipes (unless debug override)
        if !debugForceNonPremium {
            let subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
            if subscriptionManager.isPremium {
                return true
            }
        }

        // Non-heritage recipes are always accessible
        guard recipe.isHeritageRecipe else { return true }

        return unlockedRecipeIds.contains(recipe.id.uuidString)
    }

    /// Manually unlock a specific recipe (e.g., via purchase)
    func unlockRecipe(_ recipe: Recipe) {
        guard recipe.isHeritageRecipe else { return }

        unlockedRecipeIds.insert(recipe.id.uuidString)
        saveToStorage()

        Log.info("Manually unlocked heritage recipe", category: .heritage, metadata: [
            "recipeId": recipe.id.uuidString,
            "recipeName": recipe.title,
            "totalUnlocked": unlockedRecipeIds.count
        ])
    }

    /// Start tracking trial period
    func startTrialPeriod() {
        guard trialStartDate == nil else {
            Log.info("Trial period already started", category: .heritage)
            return
        }

        trialStartDate = Date()
        saveToStorage()

        Log.info("Started heritage trial period", category: .heritage)
    }

    /// Reset trial tracking (for testing or new users)
    func resetTrialTracking() {
        unlockedRecipeIds.removeAll()
        lastUnlockDate = nil
        trialStartDate = nil
        saveToStorage()

        Log.info("Reset heritage trial tracking", category: .heritage)
    }

    // MARK: - Migration

    /// Migrate existing users who already have heritage recipes from old system
    func migrateExistingUsers(context: ModelContext) async {
        // Only migrate if we haven't tracked any unlocks yet
        guard unlockedRecipeIds.isEmpty && trialStartDate == nil else {
            Log.info("Skipping migration - user already has tracked unlocks", category: .migration)
            return
        }

        do {
            // Check if user already has heritage recipes
            let descriptor = FetchDescriptor<Recipe>(
                predicate: #Predicate { $0.isHeritageRecipe == true }
            )

            let existingHeritage = try context.fetch(descriptor)

            if !existingHeritage.isEmpty {
                // User already has heritage recipes from old system
                // Mark them all as unlocked (grandfather existing users)
                for recipe in existingHeritage {
                    unlockedRecipeIds.insert(recipe.id.uuidString)
                }

                // Set trial start to now so they can continue unlocking
                trialStartDate = Date()
                saveToStorage()

                Log.info("Migrated \(existingHeritage.count) existing heritage recipes", category: .migration, metadata: [
                    "unlockedCount": existingHeritage.count
                ])
            } else {
                Log.info("No existing heritage recipes to migrate", category: .migration)
            }
        } catch {
            Log.error("Failed to migrate existing heritage recipes", category: .migration, error: error)
        }
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        if let ids = userDefaults.stringArray(forKey: unlockedRecipesKey) {
            unlockedRecipeIds = Set(ids)
        }
        lastUnlockDate = userDefaults.object(forKey: lastUnlockDateKey) as? Date
        trialStartDate = userDefaults.object(forKey: trialStartDateKey) as? Date
    }

    private func saveToStorage() {
        userDefaults.set(Array(unlockedRecipeIds), forKey: unlockedRecipesKey)
        userDefaults.set(lastUnlockDate, forKey: lastUnlockDateKey)
        userDefaults.set(trialStartDate, forKey: trialStartDateKey)
    }
}
