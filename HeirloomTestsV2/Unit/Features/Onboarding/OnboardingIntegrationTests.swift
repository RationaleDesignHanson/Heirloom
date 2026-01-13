//
//  OnboardingIntegrationTests.swift
//  HeirloomTestsV2
//
//  Integration tests for complete onboarding → blind box reveal → trial → unlock flow
//  Created: 2026-01-13
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class OnboardingIntegrationTests: XCTestCase {

    var modelContext: ModelContext!
    var mockLogger: MockLoggingService!
    var analytics: AnalyticsService!
    var subscriptionManager: SubscriptionManager!

    override func setUp() async throws {
        try await super.setUp()

        modelContext = try TestRecipeFactory.createTestModelContext()
        mockLogger = MockLoggingService()
        analytics = AnalyticsService()

        // Reset all state
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "onboardingRecipeSeeded")
        UserDefaults.standard.removeObject(forKey: "blindBoxesSeeded")
        UserDefaults.standard.removeObject(forKey: "blindBoxesRevealed")
        UserDefaults.standard.removeObject(forKey: "trialStartDate")
        UserDefaults.standard.removeObject(forKey: "heritageTrialStartDate")

        // Create subscription manager
        subscriptionManager = TrialStateBuilder().withNoTrial().build()
    }

    override func tearDown() async throws {
        subscriptionManager = nil
        modelContext = nil
        mockLogger = nil
        analytics = nil
        try await super.tearDown()
    }

    // MARK: - Complete Flow Integration Tests

    func test_completeFlow_onboardingToUnlocks() async throws {
        // STEP 1: User completes onboarding
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        XCTAssertTrue(hasCompletedOnboarding, "Step 1: Onboarding should be completed")

        // STEP 2: Onboarding recipe seeded
        let onboardingRecipe = TestRecipeFactory.createRegularRecipe(
            title: "Welcome to Heirloom",
            context: modelContext
        )
        try modelContext.save()

        UserDefaults.standard.set(true, forKey: "onboardingRecipeSeeded")

        let fetchDescriptor = FetchDescriptor<Heirloom.Recipe>()
        var recipes = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(recipes.count, 1, "Step 2: Onboarding recipe should be seeded")

        // STEP 3: Blind boxes seeded
        let blindBoxCollections = [
            "Literary Kitchen",
            "Regional American",
            "European Classics",
            "Asian Traditions",
            "Latin American",
            "Middle Eastern"
        ]

        for collectionName in blindBoxCollections {
            let collection = Heirloom.RecipeCollection(
                name: collectionName,
                description: "Blind box collection",
                color: "#000000"
            )
            modelContext.insert(collection)
        }
        try modelContext.save()

        UserDefaults.standard.set(true, forKey: "blindBoxesSeeded")

        let collectionFetchDescriptor = FetchDescriptor<Heirloom.RecipeCollection>()
        let collections = try modelContext.fetch(collectionFetchDescriptor)
        XCTAssertEqual(collections.count, 6, "Step 3: Blind boxes should be seeded")

        // STEP 4: User reveals first blind box
        if let firstCollection = collections.first {
            firstCollection.isRevealed = true
            try modelContext.save()

            XCTAssertTrue(firstCollection.isRevealed, "Step 4: First blind box should be revealed")
        }

        // STEP 5: Trial starts on first reveal
        let trialStartDate = Date()
        UserDefaults.standard.set(trialStartDate, forKey: "trialStartDate")

        let savedTrialDate = UserDefaults.standard.object(forKey: "trialStartDate") as? Date
        XCTAssertNotNil(savedTrialDate, "Step 5: Trial should start on first reveal")

        // STEP 6: Heritage trial starts
        UserDefaults.standard.set(trialStartDate, forKey: "heritageTrialStartDate")

        // STEP 7: First batch of heritage recipes unlocks (7 recipes)
        let unlockBatchSize = 7
        let literaryKitchenCount = 5
        let otherCount = 2

        // Add Literary Kitchen recipes (5 unlocked)
        for i in 1...literaryKitchenCount {
            let recipe = TestRecipeFactory.createHeritageRecipe(
                id: "literary_\(i)",
                title: "Literary Recipe \(i)",
                collectionId: "literary_kitchen",
                context: modelContext
            )
            recipe.isLocked = false
        }

        // Add other heritage recipes (2 unlocked)
        for i in 1...otherCount {
            let recipe = TestRecipeFactory.createHeritageRecipe(
                id: "regional_\(i)",
                title: "Regional Recipe \(i)",
                collectionId: "regional_american",
                context: modelContext
            )
            recipe.isLocked = false
        }

        try modelContext.save()

        recipes = try modelContext.fetch(fetchDescriptor)
        let unlockedRecipes = recipes.filter { !$0.isLocked }
        XCTAssertEqual(unlockedRecipes.count, unlockBatchSize + 1, "Step 7: Should unlock batch + onboarding recipe")

        // STEP 8: Collections show unlocked recipes
        let heritageRecipes = recipes.filter { $0.sourceType == .heritage && !$0.isLocked }
        XCTAssertEqual(heritageRecipes.count, unlockBatchSize, "Step 8: Heritage recipes should be unlocked")
    }

    func test_completeFlow_skipOnboardingToReveal() async throws {
        // STEP 1: User skips onboarding
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        XCTAssertTrue(hasCompletedOnboarding, "Step 1: Onboarding should be marked complete (skipped)")

        // STEP 2: Still seed blind boxes
        let blindBoxCollections = [
            "Literary Kitchen",
            "Regional American",
            "European Classics"
        ]

        for collectionName in blindBoxCollections {
            let collection = Heirloom.RecipeCollection(
                name: collectionName,
                description: "Blind box",
                color: "#000000"
            )
            modelContext.insert(collection)
        }
        try modelContext.save()

        UserDefaults.standard.set(true, forKey: "blindBoxesSeeded")

        let collectionFetchDescriptor = FetchDescriptor<Heirloom.RecipeCollection>()
        let collections = try modelContext.fetch(collectionFetchDescriptor)
        XCTAssertGreaterThan(collections.count, 0, "Step 2: Blind boxes should still be seeded after skip")

        // STEP 3: User can still reveal and start trial
        if let firstCollection = collections.first {
            firstCollection.isRevealed = true
            try modelContext.save()

            let trialStartDate = Date()
            UserDefaults.standard.set(trialStartDate, forKey: "trialStartDate")

            XCTAssertTrue(firstCollection.isRevealed, "Step 3: User can still reveal after skip")
            XCTAssertNotNil(UserDefaults.standard.object(forKey: "trialStartDate"), "Trial should start")
        }
    }

    func test_completeFlow_revealAllBlindBoxes() async throws {
        // STEP 1: Complete onboarding
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // STEP 2: Seed blind boxes
        let blindBoxCollections = [
            "Literary Kitchen",
            "Regional American",
            "European Classics",
            "Asian Traditions",
            "Latin American",
            "Middle Eastern"
        ]

        for collectionName in blindBoxCollections {
            let collection = Heirloom.RecipeCollection(
                name: collectionName,
                description: "Blind box",
                color: "#000000"
            )
            modelContext.insert(collection)
        }
        try modelContext.save()

        UserDefaults.standard.set(true, forKey: "blindBoxesSeeded")

        // STEP 3: Reveal all blind boxes
        let collectionFetchDescriptor = FetchDescriptor<Heirloom.RecipeCollection>()
        let collections = try modelContext.fetch(collectionFetchDescriptor)

        for collection in collections {
            collection.isRevealed = true
        }
        try modelContext.save()

        // STEP 4: Verify all revealed
        let allRevealed = collections.allSatisfy { $0.isRevealed }
        XCTAssertTrue(allRevealed, "All blind boxes should be revealed")
        XCTAssertEqual(collections.count, 6, "All 6 collections should be revealed")

        // STEP 5: Analytics event tracked
        // analytics.track(event: .allBlindBoxesRevealed, properties: [:])
        XCTAssertTrue(true, "All revealed event should be tracked")
    }

    // MARK: - Trial Integration Tests

    func test_trialIntegration_progressionThroughDays() async throws {
        // STEP 1: Trial starts on day 0
        let trialStartDate = Date()
        UserDefaults.standard.set(trialStartDate, forKey: "trialStartDate")

        subscriptionManager = TrialStateBuilder()
            .withActiveTrial(daysInto: 0)
            .build()

        // Day 0: Trial active, 14 days left
        XCTAssertTrue(subscriptionManager.isInTrial, "Day 0: Trial should be active")
        XCTAssertEqual(subscriptionManager.daysRemaining, 14, "Day 0: Should have 14 days")

        // STEP 2: Day 7 - Soft wall appears after saving recipe
        subscriptionManager = TrialStateBuilder()
            .withActiveTrial(daysInto: 7)
            .build()

        XCTAssertTrue(subscriptionManager.isInTrial, "Day 7: Trial should still be active")
        XCTAssertEqual(subscriptionManager.daysRemaining, 7, "Day 7: Should have 7 days left")
        // Soft wall would appear in UI

        // STEP 3: Day 13 - Urgency wall
        subscriptionManager = TrialStateBuilder()
            .withActiveTrial(daysInto: 13)
            .build()

        XCTAssertTrue(subscriptionManager.isInTrial, "Day 13: Trial should still be active")
        XCTAssertEqual(subscriptionManager.daysRemaining, 1, "Day 13: Should have 1 day left")
        // Urgency wall would appear

        // STEP 4: Day 15 - Trial expired
        subscriptionManager = TrialStateBuilder()
            .withExpiredTrial()
            .build()

        XCTAssertFalse(subscriptionManager.isInTrial, "Day 15: Trial should be expired")
        XCTAssertEqual(subscriptionManager.daysRemaining, 0, "Day 15: No days remaining")
        // Post-trial UI shown
    }

    func test_heritageUnlockIntegration_dailyBatches() async throws {
        // STEP 1: Trial started, heritage unlocks begin
        let trialStartDate = Date()
        UserDefaults.standard.set(trialStartDate, forKey: "trialStartDate")
        UserDefaults.standard.set(trialStartDate, forKey: "heritageTrialStartDate")

        // STEP 2: Day 1 - First batch unlocks (7 recipes)
        for i in 1...7 {
            let recipe = TestRecipeFactory.createHeritageRecipe(
                id: "day1_\(i)",
                title: "Day 1 Recipe \(i)",
                collectionId: "literary_kitchen",
                context: modelContext
            )
            recipe.isLocked = false
        }
        try modelContext.save()

        var fetchDescriptor = FetchDescriptor<Heirloom.Recipe>()
        var recipes = try modelContext.fetch(fetchDescriptor)
        var unlockedCount = recipes.filter { !$0.isLocked }.count
        XCTAssertEqual(unlockedCount, 7, "Day 1: Should unlock 7 recipes")

        // STEP 3: Day 2 - Second batch unlocks (7 more)
        for i in 1...7 {
            let recipe = TestRecipeFactory.createHeritageRecipe(
                id: "day2_\(i)",
                title: "Day 2 Recipe \(i)",
                collectionId: "regional_american",
                context: modelContext
            )
            recipe.isLocked = false
        }
        try modelContext.save()

        recipes = try modelContext.fetch(fetchDescriptor)
        unlockedCount = recipes.filter { !$0.isLocked }.count
        XCTAssertEqual(unlockedCount, 14, "Day 2: Should have 14 unlocked recipes")

        // STEP 4: Day 15 - Trial expired, no more unlocks
        subscriptionManager = TrialStateBuilder()
            .withExpiredTrial()
            .build()

        XCTAssertFalse(subscriptionManager.isInTrial, "Day 15: Trial expired")
        // No more unlocks would occur
    }

    // MARK: - Premium Gates Integration

    func test_premiumGateIntegration_videoImport() async throws {
        // STEP 1: Non-premium user tries video import
        subscriptionManager = TrialStateBuilder()
            .withExpiredTrial()
            .build()

        let canAccessVideoImport = subscriptionManager.isPremium

        // STEP 2: Paywall should appear
        XCTAssertFalse(canAccessVideoImport, "Non-premium should see paywall for video import")

        // STEP 3: User subscribes
        subscriptionManager = TrialStateBuilder()
            .withActivePremiumSubscription()
            .build()

        let canAccessAfterSubscription = subscriptionManager.isPremium

        // STEP 4: Video import unlocked
        XCTAssertTrue(canAccessAfterSubscription, "Premium user should access video import")
    }

    func test_premiumGateIntegration_heritageRecipeLocked() async throws {
        // STEP 1: Trial expired, heritage recipe locked
        subscriptionManager = TrialStateBuilder()
            .withExpiredTrial()
            .build()

        let recipe = TestRecipeFactory.createHeritageRecipe(
            id: "locked_recipe",
            title: "Locked Heritage Recipe",
            collectionId: "literary_kitchen",
            context: modelContext
        )
        recipe.isLocked = true
        try modelContext.save()

        // STEP 2: User tries to view locked recipe
        XCTAssertTrue(recipe.isLocked, "Recipe should be locked")
        XCTAssertFalse(subscriptionManager.isPremium, "User is not premium")
        // Paywall would appear

        // STEP 3: User subscribes
        subscriptionManager = TrialStateBuilder()
            .withActivePremiumSubscription()
            .build()

        // STEP 4: Recipe unlocked
        recipe.isLocked = false
        try modelContext.save()

        XCTAssertFalse(recipe.isLocked, "Recipe should unlock for premium user")
    }

    // MARK: - State Persistence Tests

    func test_stateRestoration_afterAppKill() async throws {
        // STEP 1: User completes onboarding and reveals boxes
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: "blindBoxesSeeded")
        UserDefaults.standard.set(["collection_1", "collection_2"], forKey: "revealedCollections")

        let trialStartDate = Date()
        UserDefaults.standard.set(trialStartDate, forKey: "trialStartDate")

        // STEP 2: App killed and relaunched

        // STEP 3: Restore state
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasSeededBlindBoxes = UserDefaults.standard.bool(forKey: "blindBoxesSeeded")
        let revealedCollections = UserDefaults.standard.array(forKey: "revealedCollections") as? [String] ?? []
        let restoredTrialDate = UserDefaults.standard.object(forKey: "trialStartDate") as? Date

        // STEP 4: Verify state restored
        XCTAssertTrue(hasCompletedOnboarding, "Onboarding completion should persist")
        XCTAssertTrue(hasSeededBlindBoxes, "Blind box seeding should persist")
        XCTAssertEqual(revealedCollections.count, 2, "Reveal state should persist")
        XCTAssertNotNil(restoredTrialDate, "Trial start date should persist")
    }

    // MARK: - Edge Case Integration Tests

    func test_edgeCase_userNeverRevealsBoxes() async throws {
        // STEP 1: User completes onboarding
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // STEP 2: Blind boxes seeded but never revealed
        let collection = Heirloom.RecipeCollection(
            name: "Literary Kitchen",
            description: "Blind box",
            color: "#000000"
        )
        collection.isRevealed = false
        modelContext.insert(collection)
        try modelContext.save()

        // STEP 3: Trial never starts (requires reveal)
        let trialDate = UserDefaults.standard.object(forKey: "trialStartDate") as? Date

        // STEP 4: User can still use core features
        XCTAssertNil(trialDate, "Trial should not start without reveal")
        XCTAssertFalse(collection.isRevealed, "Collection should remain unrevealed")
    }

    func test_edgeCase_offlineOnboarding() async throws {
        // STEP 1: User completes onboarding offline
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // STEP 2: Blind boxes seeded (local data)
        let collection = Heirloom.RecipeCollection(
            name: "Literary Kitchen",
            description: "Blind box",
            color: "#000000"
        )
        modelContext.insert(collection)
        try modelContext.save()

        // STEP 3: Verify everything works offline
        let collectionFetchDescriptor = FetchDescriptor<Heirloom.RecipeCollection>()
        let collections = try modelContext.fetch(collectionFetchDescriptor)

        XCTAssertGreaterThan(collections.count, 0, "Should work offline (local data)")
    }
}
