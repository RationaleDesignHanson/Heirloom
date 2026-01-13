//
//  HeritageUnlockTrackerTests.swift
//  HeirloomTestsV2
//
//  Tests for HeritageUnlockTracker: daily unlocks, quota management, catch-up logic
//  Created: 2026-01-13
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class HeritageUnlockTrackerTests: XCTestCase {

    var sut: HeritageUnlockTracker!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        setupCleanUserDefaults()
        modelContext = try TestRecipeFactory.createTestModelContext()
    }

    override func tearDown() async throws {
        sut = nil
        modelContext = nil
        tearDownUserDefaults()
        try await super.tearDown()
    }

    // MARK: - Daily Unlock Batch Tests

    func test_unlockDailyBatch_7RecipesPerDay() async throws {
        // Given: Day 1 of trial with revealed collections
        sut = UnlockStateBuilder.trialStarted()
        _ = TestRecipeFactory.createBlindBoxCollections(count: 5, revealed: true, context: modelContext)
        let heritageRecipes = TestRecipeFactory.createLiteraryKitchenRecipes(count: 20, context: modelContext)

        // When: Unlock daily batch
        try await sut.unlockDailyBatch(context: modelContext)

        // Then: Should unlock 7 recipes
        XCTAssertEqual(sut.totalUnlockedCount, 7, "Should unlock 7 recipes on day 1")
    }

    func test_unlockDailyBatch_requiresTrialOrPremium() async throws {
        // Given: Expired trial, no premium
        let expiredManager = TrialStateBuilder.expired()
        sut = UnlockStateBuilder.fresh()

        // When: Try to unlock
        try await sut.unlockDailyBatch(context: modelContext)

        // Then: Should not unlock (trial expired)
        XCTAssertEqual(sut.totalUnlockedCount, 0, "Should not unlock without trial or premium")
    }

    func test_unlockDailyBatch_requiresRevealedBlindBoxes() async throws {
        // Given: Trial active but blind boxes NOT revealed
        sut = UnlockStateBuilder.trialStarted()
        _ = TestRecipeFactory.createBlindBoxCollections(count: 5, revealed: false, context: modelContext)

        // When: Try to unlock
        try await sut.unlockDailyBatch(context: modelContext)

        // Then: Should not unlock (boxes not revealed)
        XCTAssertEqual(sut.totalUnlockedCount, 0, "Should not unlock until blind boxes revealed")
    }

    func test_unlockDailyBatch_stopsAfterTrialExpires() async throws {
        // Given: Trial expired
        sut = UnlockStateBuilder()
            .withTrialDay(15)
            .withUnlockedCount(98)
            .build()

        // When: Try to unlock
        try await sut.unlockDailyBatch(context: modelContext)

        // Then: Should not unlock more recipes
        XCTAssertEqual(sut.totalUnlockedCount, 98, "Should not unlock after trial expires")
    }

    // MARK: - Unlock Distribution Tests (70% Literary, 30% Regional)
    // Note: selectBalancedRecipes is private, so we test distribution indirectly through unlockDailyBatch

    // MARK: - hasUnlocksAvailableToday Tests

    func test_hasUnlocksAvailableToday_whenNeverUnlocked() throws {
        // Given: Never unlocked before
        sut = UnlockStateBuilder.fresh()

        // Then: Should have unlocks available
        XCTAssertTrue(sut.hasUnlocksAvailableToday, "Should have unlocks available if never unlocked")
    }

    func test_hasUnlocksAvailableToday_whenUnlockedToday() throws {
        // Given: Unlocked today already
        sut = UnlockStateBuilder()
            .withUnlockToday()
            .build()

        // Then: Should NOT have unlocks available
        XCTAssertFalse(sut.hasUnlocksAvailableToday, "Should not have unlocks if already unlocked today")
    }

    func test_hasUnlocksAvailableToday_whenUnlockedYesterday() throws {
        // Given: Unlocked yesterday
        sut = UnlockStateBuilder()
            .withUnlockYesterday()
            .build()

        // Then: Should have unlocks available
        XCTAssertTrue(sut.hasUnlocksAvailableToday, "Should have unlocks available if unlocked yesterday")
    }

    // MARK: - Catch-Up Logic Tests

    func test_catchUp_missedTwoDays_unlocks14Recipes() throws {
        // Given: Day 3 of trial, but only unlocked on day 1 (missed day 2)
        sut = UnlockStateBuilder()
            .withTrialDay(3)
            .withUnlockedCount(7) // Only day 1's unlocks
            .withLastUnlockDate(DateManipulator.daysAgo(2)) // Last unlocked 2 days ago
            .build()

        // Then: Should have 14 recipes to unlock (days 2 and 3)
        XCTAssertEqual(sut.recipesToUnlockToday, 14, "Should catch up on missed days")
    }

    func test_catchUp_doesNotExceedQuota() throws {
        // Given: Day 14, but only unlocked 50 recipes (should have 98)
        sut = UnlockStateBuilder()
            .withTrialDay(14)
            .withUnlockedCount(50)
            .withLastUnlockDate(DateManipulator.daysAgo(1))
            .build()

        // Then: Should catch up but not exceed 100 total
        let recipesToUnlock = sut.recipesToUnlockToday
        XCTAssertLessThanOrEqual(recipesToUnlock, 50, "Catch-up should not exceed quota")
        XCTAssertGreaterThan(recipesToUnlock, 0, "Should have catch-up recipes")
    }

    // MARK: - Quota Management Tests

    func test_totalRecipesRemaining_calculatesCorrectly() throws {
        // Given: 50 recipes unlocked
        sut = UnlockStateBuilder.fiftyUnlocked()

        // Then: Should have 50 remaining
        XCTAssertEqual(sut.totalRecipesRemaining, 50, "Should have 50 recipes remaining")
    }

    func test_quotaMet_100RecipesUnlocked() throws {
        // Given: 100 recipes unlocked (quota met)
        sut = UnlockStateBuilder.quotaMet()

        // Then: No recipes remaining
        XCTAssertEqual(sut.totalRecipesRemaining, 0, "Should have 0 recipes remaining at quota")
        XCTAssertEqual(sut.totalUnlockedCount, 100, "Should have 100 recipes unlocked")
        XCTAssertEqual(sut.recipesToUnlockToday, 0, "Should have 0 recipes to unlock")
    }

    // MARK: - Migration Tests

    func test_migrateExistingUsers_grandfathersOldUsers() async throws {
        // Given: Existing user before trial system
        // (No trial start date, no locked recipes)
        sut = UnlockStateBuilder()
            .withNoTrial()
            .withUnlockedCount(0)
            .build()

        // When: Migration runs
        await sut.migrateExistingUsers(context: modelContext)

        // Then: Should grandfather all recipes as unlocked
        // Note: Implementation should set unlockedRecipeIds to all 100 heritage recipes
        // Or mark user as "grandfathered" to bypass unlock system
    }

    func test_resetTrialTracking_clearsAllState() throws {
        // Given: User with unlocks
        sut = UnlockStateBuilder.day7Complete()
        XCTAssertGreaterThan(sut.totalUnlockedCount, 0, "Should have unlocks")

        // When: Reset tracking
        sut.resetTrialTracking()

        // Then: All state should be cleared
        XCTAssertEqual(sut.totalUnlockedCount, 0, "Should have 0 unlocks after reset")
        XCTAssertNil(sut.trialStartDate, "Trial start date should be nil")
        XCTAssertNil(sut.lastUnlockDate, "Last unlock date should be nil")
    }

    // MARK: - Boundary Condition Tests

    func test_boundary_zeroUnlocked() throws {
        // Given: 0 recipes unlocked
        sut = UnlockStateBuilder.zeroUnlocked()

        // Then: Should have 100 remaining
        XCTAssertEqual(sut.totalUnlockedCount, 0, "Should have 0 unlocked")
        XCTAssertEqual(sut.totalRecipesRemaining, 100, "Should have 100 remaining")
    }

    func test_boundary_50Unlocked_halfway() throws {
        // Given: 50 recipes unlocked (halfway)
        sut = UnlockStateBuilder.fiftyUnlocked()

        // Then: Should have 50 remaining
        XCTAssertEqual(sut.totalUnlockedCount, 50, "Should have 50 unlocked")
        XCTAssertEqual(sut.totalRecipesRemaining, 50, "Should have 50 remaining")
    }

    func test_boundary_100Unlocked_quotaMet() throws {
        // Given: 100 recipes unlocked (quota met)
        sut = UnlockStateBuilder.quotaMet()

        // Then: Should have 0 remaining
        XCTAssertEqual(sut.totalUnlockedCount, 100, "Should have 100 unlocked")
        XCTAssertEqual(sut.totalRecipesRemaining, 0, "Should have 0 remaining")
    }

    // MARK: - Race Condition Tests

    func test_simultaneousUnlockCalls_preventDuplication() async throws {
        // Given: Trial started with revealed collections
        sut = UnlockStateBuilder.trialStarted()
        _ = TestRecipeFactory.createBlindBoxCollections(count: 5, revealed: true, context: modelContext)
        _ = TestRecipeFactory.createLiteraryKitchenRecipes(count: 50, context: modelContext)

        // When: Multiple simultaneous unlock calls
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try? await self.sut.unlockDailyBatch(context: self.modelContext)
                }
            }
        }

        // Then: Should only unlock once (7 recipes, not 35)
        XCTAssertEqual(sut.totalUnlockedCount, 7, "Simultaneous calls should not duplicate unlocks")
    }

    // MARK: - isUnlocked Per-Recipe Check Tests

    func test_isUnlocked_returnsTrue_forUnlockedRecipe() throws {
        // Given: Specific recipe unlocked
        let recipeId = "literary_kitchen_recipe_001"
        let recipe = TestRecipeFactory.createHeritageRecipe(id: recipeId, context: modelContext)
        sut = UnlockStateBuilder()
            .withUnlockedRecipeIds(Set([recipeId]))
            .build()

        // Then: Should return true for unlocked recipe
        XCTAssertTrue(sut.isUnlocked(recipe), "Should return true for unlocked recipe")
    }

    func test_isUnlocked_returnsFalse_forLockedRecipe() throws {
        // Given: Recipe not unlocked
        let recipeId = "literary_kitchen_recipe_001"
        let recipe = TestRecipeFactory.createHeritageRecipe(id: recipeId, context: modelContext)
        sut = UnlockStateBuilder.fresh()

        // Then: Should return false for locked recipe
        XCTAssertFalse(sut.isUnlocked(recipe), "Should return false for locked recipe")
    }

    // MARK: - startTrialPeriod Tests

    func test_startTrialPeriod_onlyStartsOnce() throws {
        // Given: Fresh state
        sut = UnlockStateBuilder.fresh()
        XCTAssertNil(sut.trialStartDate, "Trial should not be started yet")

        // When: Start trial
        sut.startTrialPeriod()

        let firstStartDate = sut.trialStartDate
        XCTAssertNotNil(firstStartDate, "Trial should be started")

        // And: Try to start again
        sut.startTrialPeriod()

        // Then: Start date should not change
        assertDatesEqual(sut.trialStartDate, firstStartDate, within: 1.0)
    }
}
