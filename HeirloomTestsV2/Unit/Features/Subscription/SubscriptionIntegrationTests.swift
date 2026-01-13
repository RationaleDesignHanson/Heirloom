//
//  SubscriptionIntegrationTests.swift
//  HeirloomTestsV2
//
//  Integration tests for subscription flows: onboarding → reveal → trial → paywall
//  Created: 2026-01-13
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class SubscriptionIntegrationTests: XCTestCase {

    var subscriptionManager: SubscriptionManager!
    var paywallManager: PaywallManager!
    var unlockTracker: HeritageUnlockTracker!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        setupCleanUserDefaults()
        modelContext = try TestRecipeFactory.createTestModelContext()
    }

    override func tearDown() async throws {
        subscriptionManager = nil
        paywallManager = nil
        unlockTracker = nil
        modelContext = nil
        tearDownUserDefaults()
        try await super.tearDown()
    }

    // MARK: - Blind Box Reveal Flow

    func test_blindBoxRevealFlow_endToEnd() async throws {
        // Given: User completes onboarding
        let (collections, onboardingRecipe) = TestRecipeFactory.setupOnboardingScenario(context: modelContext)
        XCTAssertEqual(collections.count, 5, "Should have 5 blind box collections")
        XCTAssertFalse(collections[0].isRevealed, "Collections should not be revealed yet")

        // When: User reveals blind boxes
        for collection in collections {
            collection.isRevealed = true
        }

        // And: Trial starts
        subscriptionManager = TrialStateBuilder.noTrial()
        subscriptionManager.initializeTrialOnBlindBoxReveal()

        // Then: Trial should be active
        XCTAssertTrue(subscriptionManager.isInTrial, "Trial should be active after blind box reveal")
        XCTAssertEqual(subscriptionManager.daysRemaining, 14, "Should have 14 days")

        // And: Heritage trial starts
        unlockTracker = UnlockStateBuilder.fresh()
        unlockTracker.startTrialPeriod()

        XCTAssertNotNil(unlockTracker.trialStartDate, "Heritage trial should start")

        // And: First batch unlocks
        let heritageRecipes = TestRecipeFactory.createLiteraryKitchenRecipes(count: 20, context: modelContext)
        try await unlockTracker.unlockDailyBatch(context: modelContext)

        XCTAssertEqual(unlockTracker.totalUnlockedCount, 7, "Should unlock 7 recipes on reveal")

        // And: Collections show unlocked recipes
        XCTAssertTrue(collections.allSatisfy { $0.isRevealed }, "All collections should be revealed")
    }

    // MARK: - Trial Progression

    func test_trialProgression_day1ToDay15() async throws {
        // Day 1: Trial active, 14 days remaining, daily unlock works
        subscriptionManager = TrialStateBuilder.day1()
        unlockTracker = UnlockStateBuilder.trialStarted()

        XCTAssertTrue(subscriptionManager.isInTrial, "Day 1: Trial should be active")
        XCTAssertEqual(subscriptionManager.daysRemaining, 14, "Day 1: Should have 14 days")
        XCTAssertTrue(unlockTracker.hasUnlocksAvailableToday, "Day 1: Should have unlocks available")

        // Day 7: Soft wall after recipe save
        subscriptionManager = TrialStateBuilder.day7()
        paywallManager = PaywallStateBuilder()
            .withRecipeCount(1)
            .withSubscriptionState(TrialStateBuilder().withDaysIntoTrial(7))
            .build()

        XCTAssertTrue(subscriptionManager.isInTrial, "Day 7: Trial should still be active")
        XCTAssertEqual(subscriptionManager.daysRemaining, 7, "Day 7: Should have 7 days")

        let shouldShowPaywall = paywallManager.shouldShow(for: .firstRecipeAdded)
        XCTAssertTrue(shouldShowPaywall, "Day 7: Soft wall should trigger after recipe save")

        // Day 13: Urgency wall triggers
        subscriptionManager = TrialStateBuilder.day13()
        paywallManager = PaywallStateBuilder()
            .withSubscriptionState(TrialStateBuilder().withDaysIntoTrial(13))
            .build()

        XCTAssertTrue(subscriptionManager.isInTrial, "Day 13: Trial should still be active")
        XCTAssertEqual(subscriptionManager.daysRemaining, 1, "Day 13: Should have 1 day")

        let shouldShowUrgency = paywallManager.shouldShow(for: .day13Urgency)
        XCTAssertTrue(shouldShowUrgency, "Day 13: Urgency wall should trigger")

        // Day 15: Trial expired, no more unlocks, post-trial UI
        subscriptionManager = TrialStateBuilder.expired()
        unlockTracker = UnlockStateBuilder()
            .withTrialDay(15)
            .withUnlockedCount(98)
            .build()

        XCTAssertFalse(subscriptionManager.isInTrial, "Day 15: Trial should be expired")
        XCTAssertTrue(subscriptionManager.isTrialExpired, "Day 15: Should be marked as expired")
        XCTAssertEqual(unlockTracker.recipesToUnlockToday, 0, "Day 15: Should have no unlocks")
    }

    // MARK: - Premium Gates

    func test_premiumGates_nonPremiumUser() async throws {
        // Given: Non-premium user (expired trial)
        subscriptionManager = TrialStateBuilder.expired()
        let trialBuilder = TrialStateBuilder().withDaysIntoTrial(15)
        paywallManager = PaywallStateBuilder()
            .withSubscriptionState(trialBuilder)
            .build()

        // Then: All premium features should be gated

        // 1. Video import blocked
        let videoImportBlocked = paywallManager.shouldShow(for: .urlImport)
        XCTAssertTrue(videoImportBlocked, "Video import should be blocked for non-premium")

        // 2. ASMR blocked (credits exhausted)
        // Note: ASMR has separate credit system - would need ASMR manager test

        // 3. Heritage recipes locked after trial
        let hasUnlocks = unlockTracker?.hasUnlocksAvailableToday ?? false
        XCTAssertFalse(hasUnlocks || !subscriptionManager.isInTrial, "Heritage unlocks should stop after trial")

        // 4. Sync blocked
        let syncBlocked = paywallManager.shouldShow(for: .sync)
        XCTAssertTrue(syncBlocked, "Sync should be blocked for non-premium")
    }

    func test_premiumGates_premiumUser_bypassesAll() async throws {
        // Given: Premium user (monthly subscription)
        subscriptionManager = TrialStateBuilder.monthly()
        let trialBuilder = TrialStateBuilder().withActiveSubscription(.monthly)
        paywallManager = PaywallStateBuilder()
            .withSubscriptionState(trialBuilder)
            .build()

        // Then: Premium user bypasses all gates
        XCTAssertFalse(paywallManager.shouldShow(for: .urlImport), "Premium: Video import not blocked")
        XCTAssertFalse(paywallManager.shouldShow(for: .cookbookScan), "Premium: Cookbook scan not blocked")
        XCTAssertFalse(paywallManager.shouldShow(for: .sync), "Premium: Sync not blocked")
        XCTAssertFalse(paywallManager.shouldShow(for: .firstRecipeAdded), "Premium: No soft walls")
    }

    // MARK: - 3-Strike Rule Integration

    func test_strikeRule_blocksFeatures_afterThreeDismissals() async throws {
        // Given: User dismissed paywall 2 times
        paywallManager = PaywallStateBuilder.twoDismissals()
        XCTAssertEqual(paywallManager.softWallDismissCount, 2)
        XCTAssertFalse(paywallManager.isStrikeRuleActive, "Strike rule should not be active yet")

        // When: User dismisses third time
        paywallManager.dismiss()

        // Then: Strike rule activates
        XCTAssertEqual(paywallManager.softWallDismissCount, 3, "Should have 3 dismissals")
        XCTAssertTrue(paywallManager.isStrikeRuleActive, "Strike rule should activate after 3 dismissals")

        // And: Premium features now blocked
        XCTAssertTrue(paywallManager.shouldShow(for: .urlImport), "Video import should be blocked by strike rule")
        XCTAssertTrue(paywallManager.shouldShow(for: .cookbookScan), "Cookbook scan should be blocked")
        XCTAssertTrue(paywallManager.shouldShow(for: .sync), "Sync should be blocked")
    }

    // MARK: - Catch-Up Scenario

    func test_catchUp_userMissedDays_canUnlockMultipleDays() async throws {
        // Given: User on day 7 but only unlocked on days 1 and 2 (missed 5 days)
        unlockTracker = UnlockStateBuilder()
            .withTrialDay(7)
            .withUnlockedCount(14) // Only days 1-2 (14 recipes)
            .withLastUnlockDate(DateManipulator.daysAgo(5))
            .build()

        // Then: Should have 35 recipes to unlock (days 3-7: 5 * 7 = 35)
        let catchUpRecipes = unlockTracker.recipesToUnlockToday
        XCTAssertEqual(catchUpRecipes, 35, "Should catch up on 5 missed days")

        // When: Unlock daily batch
        let (collections, heritageRecipes, _) = TestRecipeFactory.setupTrialScenario(day: 7, context: modelContext)
        try await unlockTracker.unlockDailyBatch(context: modelContext)

        // Then: Should unlock catch-up amount
        XCTAssertEqual(unlockTracker.totalUnlockedCount, 14 + 35, "Should unlock catch-up recipes")
    }

    // MARK: - Subscription Status Transitions

    func test_statusTransition_trialToMonthly_preservesUnlocks() async throws {
        // Given: User in trial with unlocks
        unlockTracker = UnlockStateBuilder.day7Complete()
        subscriptionManager = TrialStateBuilder.day7()

        let unlocksBeforePurchase = unlockTracker.totalUnlockedCount
        XCTAssertEqual(unlocksBeforePurchase, 49, "Should have 49 unlocks on day 7")

        // When: User purchases monthly subscription
        subscriptionManager = TrialStateBuilder.monthly()

        // Then: Status transitions to monthly
        XCTAssertEqual(subscriptionManager.status, .monthly, "Status should be monthly")
        XCTAssertTrue(subscriptionManager.isPremium, "Should be premium")

        // And: Unlocks are preserved
        XCTAssertEqual(unlockTracker.totalUnlockedCount, unlocksBeforePurchase, "Unlocks should be preserved")
    }

    // MARK: - Edge Case: Immediate Purchase Without Trial

    func test_immediatePurchase_withoutStartingTrial() async throws {
        // Given: User purchases immediately (skips trial)
        subscriptionManager = TrialStateBuilder()
            .withNoExistingTrial()
            .withActiveSubscription(.annual)
            .build()

        // Then: Should be premium without trial
        XCTAssertFalse(subscriptionManager.isInTrial, "Should not be in trial")
        XCTAssertTrue(subscriptionManager.isPremium, "Should be premium")
        XCTAssertEqual(subscriptionManager.status, .annual, "Status should be annual")

        // And: Heritage unlocks should work (premium bypass)
        unlockTracker = UnlockStateBuilder.fresh()
        let (collections, heritageRecipes, _) = TestRecipeFactory.setupTrialScenario(day: 1, context: modelContext)

        // Premium users can unlock without trial
        unlockTracker.startTrialPeriod() // Or use premium bypass
        try await unlockTracker.unlockDailyBatch(context: modelContext)

        XCTAssertGreaterThan(unlockTracker.totalUnlockedCount, 0, "Premium users should be able to unlock")
    }

    // MARK: - Edge Case: Re-subscribe After Expired

    func test_resubscribe_afterExpiredTrial() async throws {
        // Given: Trial expired, user was inactive
        subscriptionManager = TrialStateBuilder.expired()
        XCTAssertFalse(subscriptionManager.isPremium, "Should not be premium with expired trial")

        // When: User re-subscribes (monthly)
        subscriptionManager = TrialStateBuilder.monthly()

        // Then: Should be premium again
        XCTAssertTrue(subscriptionManager.isPremium, "Should be premium after re-subscribe")
        XCTAssertEqual(subscriptionManager.status, .monthly, "Status should be monthly")

        // And: Can access premium features
        let trialBuilder = TrialStateBuilder().withActiveSubscription(.monthly)
        paywallManager = PaywallStateBuilder()
            .withSubscriptionState(trialBuilder)
            .build()

        XCTAssertFalse(paywallManager.shouldShow(for: .urlImport), "Should not show paywalls")
    }
}
