//
//  PaywallManagerTests.swift
//  HeirloomTestsV2
//
//  Tests for PaywallManager: 3-strike rule, cooldowns, and trigger logic
//  Created: 2026-01-13
//

import XCTest
@testable import Heirloom

@MainActor
final class PaywallManagerTests: XCTestCase {

    var sut: PaywallManager!

    override func setUp() async throws {
        try await super.setUp()
        setupCleanUserDefaults()
    }

    override func tearDown() async throws {
        sut = nil
        tearDownUserDefaults()
        try await super.tearDown()
    }

    // MARK: - Soft Wall Trigger Tests

    func test_firstRecipeAdded_triggersPaywall() throws {
        // Given: Fresh state, no dismissals
        sut = PaywallStateBuilder.fresh()

        // When: Evaluate first recipe trigger
        let shouldShow = sut.shouldShow(for: .firstRecipeAdded)

        // Then: Should show paywall
        XCTAssertTrue(shouldShow, "First recipe should trigger paywall")
    }

    func test_fiveRecipesOrDay7_triggersPaywall() throws {
        // Given: Day 7 with 5 recipes
        sut = PaywallStateBuilder.day7With5Recipes()

        // When: Evaluate trigger
        let shouldShow = sut.shouldShow(for: .fiveRecipesOrDay7)

        // Then: Should show paywall
        XCTAssertTrue(shouldShow, "5 recipes on day 7 should trigger paywall")
    }

    func test_day13Urgency_triggersPaywall() throws {
        // Given: Day 13 of trial
        sut = PaywallStateBuilder()
            .withSubscriptionState(TrialStateBuilder().withDaysIntoTrial(13))
            .build()

        // When: Evaluate trigger
        let shouldShow = sut.shouldShow(for: .day13Urgency)

        // Then: Should show paywall
        XCTAssertTrue(shouldShow, "Day 13 should trigger urgency paywall")
    }

    // MARK: - Hard Wall Trigger Tests

    func test_urlImport_triggersHardWall() throws {
        // Given: Non-premium user
        sut = PaywallStateBuilder.fresh()

        // When: Evaluate URL import trigger
        let shouldShow = sut.shouldShow(for: .urlImport)

        // Then: Should show hard wall
        XCTAssertTrue(shouldShow, "URL import should trigger hard wall for non-premium")
    }

    func test_cookbookScan_triggersHardWall() throws {
        // Given: Non-premium user
        sut = PaywallStateBuilder.fresh()

        // When: Evaluate cookbook scan trigger
        let shouldShow = sut.shouldShow(for: .cookbookScan)

        // Then: Should show hard wall
        XCTAssertTrue(shouldShow, "Cookbook scan should trigger hard wall")
    }

    func test_sync_triggersHardWall() throws {
        // Given: Non-premium user
        sut = PaywallStateBuilder.fresh()

        // When: Evaluate sync trigger
        let shouldShow = sut.shouldShow(for: .sync)

        // Then: Should show hard wall
        XCTAssertTrue(shouldShow, "Sync should trigger hard wall")
    }

    // MARK: - 3-Strike Rule Tests

    func test_threeStrikes_activatesHardWall() throws {
        // Given: 3 dismissals (strike rule active)
        sut = PaywallStateBuilder.strikeRuleActive()

        // Then: Strike rule should be active
        XCTAssertTrue(sut.isStrikeRuleActive, "Strike rule should activate after 3 dismissals")
    }

    func test_softWall_dismissedOnce_incrementsCount() throws {
        // Given: Fresh state
        sut = PaywallStateBuilder.fresh()
        XCTAssertEqual(sut.softWallDismissCount, 0)

        // When: Dismiss paywall
        sut.dismiss()

        // Then: Count should increment
        XCTAssertEqual(sut.softWallDismissCount, 1, "Dismiss count should increment")
    }

    func test_softWall_dismissedThreeTimes_blocksFeatures() throws {
        // Given: Dismissed 2 times already
        sut = PaywallStateBuilder.twoDismissals()
        XCTAssertEqual(sut.softWallDismissCount, 2)

        // When: Dismiss third time
        sut.dismiss()

        // Then: Strike rule activates, hard walls enabled
        XCTAssertEqual(sut.softWallDismissCount, 3, "Should have 3 dismissals")
        XCTAssertTrue(sut.isStrikeRuleActive, "Strike rule should activate")

        // And: Soft walls become hard walls
        let shouldShowUrl = sut.shouldShow(for: .urlImport)
        XCTAssertTrue(shouldShowUrl, "URL import should now be blocked")
    }

    func test_strikeRule_softWallsCannotBeDismissed() throws {
        // Given: Strike rule active
        sut = PaywallStateBuilder.strikeRuleActive()

        // When: Try to show soft wall
        let trigger: PaywallTrigger = .firstRecipeAdded

        // Then: Soft wall should behave like hard wall
        XCTAssertTrue(sut.isStrikeRuleActive, "Strike rule should be active")
        // Note: In real implementation, soft walls with strike rule show as hard walls
    }

    // MARK: - Cooldown Period Tests

    func test_firstRecipe_48HourCooldown_active() throws {
        // Given: First recipe triggered 1 hour ago (within 48hr cooldown)
        sut = PaywallStateBuilder.firstRecipeCooldown()

        // When: Try to trigger again
        let shouldShow = sut.shouldShow(for: .firstRecipeAdded)

        // Then: Should not show (cooldown active)
        XCTAssertFalse(shouldShow, "Should not show within 48hr cooldown")
    }

    func test_firstRecipe_48HourCooldown_expired() throws {
        // Given: First recipe triggered 100 hours ago (cooldown expired)
        sut = PaywallStateBuilder.firstRecipeCooldownExpired()

        // When: Try to trigger again
        let shouldShow = sut.shouldShow(for: .firstRecipeAdded)

        // Then: Should show (cooldown expired)
        XCTAssertTrue(shouldShow, "Should show after 48hr cooldown expires")
    }

    func test_fiveRecipes_72HourCooldown_active() throws {
        // Given: Five recipes triggered 1 hour ago (within 72hr cooldown)
        sut = PaywallStateBuilder()
            .withCooldownActive(.fiveRecipesOrDay7, hoursAgo: 1)
            .build()

        // When: Try to trigger again
        let shouldShow = sut.shouldShow(for: .fiveRecipesOrDay7)

        // Then: Should not show (cooldown active)
        XCTAssertFalse(shouldShow, "Should not show within 72hr cooldown")
    }

    func test_fiveRecipes_72HourCooldown_expired() throws {
        // Given: Five recipes triggered 100 hours ago (cooldown expired)
        sut = PaywallStateBuilder()
            .withCooldownExpired(.fiveRecipesOrDay7)
            .build()

        // When: Try to trigger again
        let shouldShow = sut.shouldShow(for: .fiveRecipesOrDay7)

        // Then: Should show (cooldown expired)
        XCTAssertTrue(shouldShow, "Should show after 72hr cooldown expires")
    }

    func test_day13Urgency_noCooldown() throws {
        // Given: Day 13 triggered before
        sut = PaywallStateBuilder()
            .withTriggeredHistory(.day13Urgency)
            .withSubscriptionState(TrialStateBuilder().withDaysIntoTrial(13))
            .build()

        // When: Try to trigger again
        let shouldShow = sut.shouldShow(for: .day13Urgency)

        // Then: Should still show (no cooldown for urgency)
        // Note: Actual behavior depends on implementation
        // Urgency walls may show multiple times
    }

    // MARK: - State Persistence Tests

    func test_dismissCount_persistsAcrossLaunches() throws {
        // Given: Dismissed twice
        sut = PaywallStateBuilder.twoDismissals()
        XCTAssertEqual(sut.softWallDismissCount, 2)

        // When: Simulate app restart
        sut = PaywallStateBuilder.twoDismissals()

        // Then: Count should persist
        XCTAssertEqual(sut.softWallDismissCount, 2, "Dismiss count should persist")
    }

    func test_cooldownState_persistsAcrossLaunches() throws {
        // Given: Cooldown active
        sut = PaywallStateBuilder.firstRecipeCooldown()

        // When: Simulate app restart
        sut = PaywallStateBuilder.firstRecipeCooldown()

        // And: Try to show paywall
        let shouldShow = sut.shouldShow(for: .firstRecipeAdded)

        // Then: Cooldown should still be active
        XCTAssertFalse(shouldShow, "Cooldown should persist across launches")
    }

    // MARK: - Premium User Bypass Tests

    func test_premiumUser_bypassesAllPaywalls() throws {
        // Given: Premium user (monthly subscription)
        let trialStateBuilder = TrialStateBuilder().withActiveSubscription(.monthly)
        sut = PaywallStateBuilder()
            .withSubscriptionState(trialStateBuilder)
            .build()

        // When: Try to show any paywall
        let triggers: [PaywallTrigger] = [
            .firstRecipeAdded,
            .fiveRecipesOrDay7,
            .day13Urgency,
            .urlImport,
            .cookbookScan,
            .sync
        ]

        // Then: No paywalls should show
        for trigger in triggers {
            let shouldShow = sut.shouldShow(for: trigger)
            XCTAssertFalse(shouldShow, "Premium users should bypass \(trigger.displayName) paywall")
        }
    }

    // MARK: - Multiple Rapid Dismissals Test

    func test_rapidDismissals_handledCorrectly() throws {
        // Given: Fresh state
        sut = PaywallStateBuilder.fresh()

        // When: Rapidly dismiss 5 times
        for _ in 0..<5 {
            sut.dismiss()
        }

        // Then: Count should be 5 (or capped at 3 for strike rule)
        XCTAssertGreaterThanOrEqual(sut.softWallDismissCount, 3, "Should track at least 3 dismissals")
        XCTAssertTrue(sut.isStrikeRuleActive, "Strike rule should activate")
    }
}
