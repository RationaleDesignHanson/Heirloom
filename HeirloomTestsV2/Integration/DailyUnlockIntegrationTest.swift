//
//  DailyUnlockIntegrationTest.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-02
//  Integration tests for daily unlock system
//
//  Tests the 14-day theme recipe unlock mechanism to ensure:
//  - Fresh install unlocks Day 1 recipes
//  - Day progression unlocks new recipes
//  - Edge cases are handled (expired trial, missing data)
//  - Catch-up unlocks work when returning after days
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class DailyUnlockIntegrationTest: XCTestCase {

    // MARK: - Properties

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var tracker: ThemeUnlockTracker!
    var testThemeIds: [String]!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        let schema = Schema([Recipe.self, RecipeCollection.self, Ingredient.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)

        // Create fresh tracker instance
        tracker = ThemeUnlockTracker()

        // Reset UserDefaults to clean state
        resetUserDefaults()

        // Setup test theme IDs
        testThemeIds = ["test-theme-1", "test-theme-2", "test-theme-3"]

        // Seed test data
        try await seedTestRecipes()
    }

    override func tearDown() async throws {
        // Clean up
        resetUserDefaults()
        tracker = nil
        modelContext = nil
        modelContainer = nil
        testThemeIds = nil

        try await super.tearDown()
    }

    // MARK: - Test Cases

    /// Test 1: Fresh install unlocks Day 1 recipes only
    func testFreshInstallUnlocksDayOne() throws {
        // Given: Fresh install, no prior trial
        XCTAssertEqual(tracker.currentTrialDay, 1, "Fresh install should start at Day 1")

        // When: User selects themes
        tracker.startTrial(withThemeIds: testThemeIds)

        // Then: Only Day 1 recipes should be unlocked
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe == true }
        )
        let allRecipes = try modelContext.fetch(descriptor)

        let day1Recipes = allRecipes.filter { $0.unlockDay == 1 }
        let day2Recipes = allRecipes.filter { $0.unlockDay == 2 }

        XCTAssertGreaterThan(day1Recipes.count, 0, "Should have Day 1 recipes")

        for recipe in day1Recipes {
            XCTAssertTrue(tracker.isUnlocked(recipe), "Day 1 recipe '\(recipe.title)' should be unlocked")
        }

        for recipe in day2Recipes {
            XCTAssertFalse(tracker.isUnlocked(recipe), "Day 2 recipe '\(recipe.title)' should be locked")
        }

        Log.info("Fresh install test passed", category: .trial, metadata: [
            "day1Count": day1Recipes.count,
            "day2Count": day2Recipes.count
        ])
    }

    /// Test 2: Day progression unlocks new recipes
    func testDayProgressionUnlocksNewRecipes() throws {
        // Given: User is on Day 1
        tracker.startTrial(withThemeIds: testThemeIds)
        XCTAssertEqual(tracker.currentTrialDay, 1)

        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe == true }
        )
        let allRecipes = try modelContext.fetch(descriptor)

        let day1UnlockedCount = allRecipes.filter { tracker.isUnlocked($0) }.count

        // When: User advances to Day 2
        #if DEBUG
        tracker.debugSetTrialDay(2)
        #endif

        // Then: More recipes should be unlocked
        let day2UnlockedCount = allRecipes.filter { tracker.isUnlocked($0) }.count

        XCTAssertGreaterThan(day2UnlockedCount, day1UnlockedCount,
                            "Day 2 should have more unlocked recipes than Day 1")
        XCTAssertEqual(tracker.currentTrialDay, 2, "Should be on Day 2")

        // When: User advances to Day 7
        #if DEBUG
        tracker.debugSetTrialDay(7)
        #endif

        // Then: Even more recipes should be unlocked
        let day7UnlockedCount = allRecipes.filter { tracker.isUnlocked($0) }.count

        XCTAssertGreaterThan(day7UnlockedCount, day2UnlockedCount,
                            "Day 7 should have more unlocked recipes than Day 2")
        XCTAssertEqual(tracker.currentTrialDay, 7, "Should be on Day 7")

        Log.info("Day progression test passed", category: .trial, metadata: [
            "day1Unlocked": day1UnlockedCount,
            "day2Unlocked": day2UnlockedCount,
            "day7Unlocked": day7UnlockedCount
        ])
    }

    /// Test 3: Full 14-day cycle unlocks all recipes
    func testFullUnlockCycle() throws {
        // Given: User starts trial
        tracker.startTrial(withThemeIds: testThemeIds)

        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe == true }
        )
        let allRecipes = try modelContext.fetch(descriptor)
        let totalRecipes = allRecipes.filter { $0.unlockDay != nil && $0.unlockDay! <= 14 }

        // When: User progresses through all 14 days
        for day in 1...14 {
            #if DEBUG
            tracker.debugSetTrialDay(day)
            #endif

            let unlockedCount = allRecipes.filter { tracker.isUnlocked($0) }.count
            Log.debug("Day \(day) check", category: .trial, metadata: [
                "unlockedCount": unlockedCount,
                "totalRecipes": totalRecipes.count
            ])
        }

        // Then: All recipes with unlockDay 1-14 should be unlocked
        #if DEBUG
        tracker.debugSetTrialDay(14)
        #endif

        let finalUnlockedCount = totalRecipes.filter { tracker.isUnlocked($0) }.count

        XCTAssertEqual(finalUnlockedCount, totalRecipes.count,
                      "All recipes should be unlocked by Day 14")
        XCTAssertTrue(tracker.isTrialComplete, "Trial should be marked complete")

        Log.info("Full unlock cycle test passed", category: .trial, metadata: [
            "totalRecipes": totalRecipes.count,
            "unlockedCount": finalUnlockedCount
        ])
    }

    /// Test 4: Day 15 (trial expired) still shows Day 14 recipes
    func testExpiredTrialShowsAllRecipes() throws {
        // Given: User completed trial
        tracker.startTrial(withThemeIds: testThemeIds)

        // When: Trial expires (Day 15)
        #if DEBUG
        tracker.debugSetTrialDay(15)
        #endif

        // Then: All recipes should still be unlocked
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe == true }
        )
        let allRecipes = try modelContext.fetch(descriptor)
        let recipesWithUnlockDays = allRecipes.filter { $0.unlockDay != nil }

        let unlockedCount = recipesWithUnlockDays.filter { tracker.isUnlocked($0) }.count

        XCTAssertEqual(unlockedCount, recipesWithUnlockDays.count,
                      "Expired trial should still show all unlocked recipes")
        XCTAssertTrue(tracker.isTrialComplete, "Trial should be complete on Day 15")
        XCTAssertEqual(tracker.daysRemaining, 0, "Days remaining should be 0")

        Log.info("Expired trial test passed", category: .trial, metadata: [
            "currentDay": tracker.currentTrialDay,
            "unlockedCount": unlockedCount
        ])
    }

    /// Test 5: Catch-up unlock when returning after days
    func testCatchUpUnlock() throws {
        // Given: User started trial 7 days ago but hasn't opened app since
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        tracker.trialStartDate = sevenDaysAgo
        tracker.selectedThemeIds = testThemeIds

        // When: User opens app today
        // (tracker automatically updates current day in init)
        tracker = ThemeUnlockTracker() // Re-init to trigger day calculation
        tracker.selectedThemeIds = testThemeIds

        // Then: Should be on Day 8
        XCTAssertEqual(tracker.currentTrialDay, 8,
                      "Should catch up to Day 8 after 7 days")

        // And: All recipes up to Day 8 should be unlocked
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe == true }
        )
        let allRecipes = try modelContext.fetch(descriptor)

        let day8Recipes = allRecipes.filter { $0.unlockDay ?? 99 <= 8 }
        let day9Recipes = allRecipes.filter { $0.unlockDay == 9 }

        for recipe in day8Recipes {
            XCTAssertTrue(tracker.isUnlocked(recipe),
                         "Recipe '\(recipe.title)' (Day \(recipe.unlockDay ?? 0)) should be unlocked")
        }

        for recipe in day9Recipes {
            XCTAssertFalse(tracker.isUnlocked(recipe),
                          "Day 9 recipe '\(recipe.title)' should still be locked")
        }

        Log.info("Catch-up unlock test passed", category: .trial, metadata: [
            "currentDay": tracker.currentTrialDay,
            "unlockedUpToDay8": day8Recipes.count
        ])
    }

    /// Test 6: Recipe without unlockDay is always unlocked
    func testRecipeWithoutUnlockDayAlwaysUnlocked() throws {
        // Given: A recipe with no unlock day (user-created recipe)
        let userRecipe = Recipe()
        userRecipe.title = "User's Recipe"
        userRecipe.isThemeRecipe = false
        userRecipe.unlockDay = nil
        modelContext.insert(userRecipe)
        try modelContext.save()

        // When: Checking if unlocked
        let isUnlocked = tracker.isUnlocked(userRecipe)

        // Then: Should be unlocked regardless of trial day
        XCTAssertTrue(isUnlocked, "Recipe without unlockDay should always be unlocked")

        Log.info("No unlock day test passed", category: .trial)
    }

    /// Test 7: Invalid unlock day is handled gracefully
    func testInvalidUnlockDayHandling() throws {
        // Given: A recipe with invalid unlock day (outside 1-14 range)
        let invalidRecipe = Recipe()
        invalidRecipe.title = "Invalid Unlock Day Recipe"
        invalidRecipe.isThemeRecipe = true
        invalidRecipe.unlockDay = 99 // Invalid
        modelContext.insert(invalidRecipe)
        try modelContext.save()

        // When: Running verification
        let result = tracker.verifyUnlockIntegrity(modelContext: modelContext)

        // Then: Should detect the error
        XCTAssertFalse(result.isValid, "Verification should fail with invalid unlock day")
        XCTAssertTrue(result.errors.contains { $0.contains("invalid unlockDay") },
                     "Should report invalid unlock day error")

        Log.info("Invalid unlock day test passed", category: .trial, metadata: [
            "errors": result.errors.joined(separator: " | ")
        ])
    }

    /// Test 8: New unlock check detection
    func testNewUnlockDetection() throws {
        // Given: User is on Day 1
        tracker.startTrial(withThemeIds: testThemeIds)

        // When: Checking for new unlocks on same day
        let hasNewUnlocks1 = tracker.checkForNewUnlocks()

        // Then: Should have new unlocks on first check
        XCTAssertTrue(hasNewUnlocks1, "First unlock check should find new unlocks")

        // When: Checking again on same day
        let hasNewUnlocks2 = tracker.checkForNewUnlocks()

        // Then: Should NOT have new unlocks
        XCTAssertFalse(hasNewUnlocks2, "Second check on same day should not find new unlocks")

        // When: Advancing to Day 2
        #if DEBUG
        tracker.debugSetTrialDay(2)
        #endif

        let hasNewUnlocks3 = tracker.checkForNewUnlocks()

        // Then: Should have new unlocks again
        XCTAssertTrue(hasNewUnlocks3, "New day should have new unlocks")

        Log.info("New unlock detection test passed", category: .trial)
    }

    // MARK: - Helper Methods

    private func resetUserDefaults() {
        let keys = [
            "theme_trial_start_date",
            "selected_theme_ids",
            "unlocked_recipe_ids",
            "last_unlock_check_date",
            "last_unlock_day"
        ]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        UserDefaults.standard.synchronize()
    }

    private func seedTestRecipes() async throws {
        // Create test recipes for each day (3 recipes per day × 14 days = 42 recipes)
        for day in 1...14 {
            for recipeIndex in 1...3 {
                let recipe = Recipe()
                recipe.title = "Test Recipe Day \(day) #\(recipeIndex)"
                recipe.isThemeRecipe = true
                recipe.unlockDay = day
                recipe.sourceThemeId = testThemeIds[recipeIndex % testThemeIds.count]
                recipe.themeRecipeId = "test-\(day)-\(recipeIndex)"

                // Add some ingredients
                let ingredient = Ingredient(
                    name: "Test Ingredient",
                    quantity: "1 cup",
                    recipe: recipe
                )
                recipe.ingredients = [ingredient]
                modelContext.insert(ingredient)

                modelContext.insert(recipe)
            }
        }

        try modelContext.save()

        Log.info("Seeded test recipes", category: .trial, metadata: [
            "recipeCount": 42
        ])
    }
}
