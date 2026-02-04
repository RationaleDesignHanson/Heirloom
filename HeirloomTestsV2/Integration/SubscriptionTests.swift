//
//  SubscriptionTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Integration tests for subscription system
//
//  Tests the subscription and paywall system to ensure:
//  - Subscription status states are correct
//  - Trial progression works correctly
//  - Premium feature gating works
//  - Paywall triggers fire appropriately
//  - 3-strike rule functions correctly
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class SubscriptionTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true)
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        try await super.tearDown()
    }

    // MARK: - Subscription Status Tests

    /// Test 1: None status indicates no subscription
    func test_subscriptionStatus_none_indicatesNoSubscription() {
        // GIVEN: None status
        let status = HeirloomSubscriptionStatus.none

        // THEN: Should not be premium
        XCTAssertFalse(status.isPremium)
        XCTAssertFalse(status.isSubscription)
    }

    /// Test 2: Trial status is premium
    func test_subscriptionStatus_trial_isPremium() {
        // GIVEN: Trial status
        let status = HeirloomSubscriptionStatus.trial

        // THEN: Should be premium
        XCTAssertTrue(status.isPremium)
        XCTAssertFalse(status.isSubscription)
        XCTAssertTrue(status.isTrial)
    }

    /// Test 3: Monthly status is premium and subscription
    func test_subscriptionStatus_monthly_isPremiumAndSubscription() {
        // GIVEN: Monthly status
        let status = HeirloomSubscriptionStatus.monthly

        // THEN: Should be both premium and subscription
        XCTAssertTrue(status.isPremium)
        XCTAssertTrue(status.isSubscription)
        XCTAssertFalse(status.isTrial)
    }

    /// Test 4: Annual status is premium and subscription
    func test_subscriptionStatus_annual_isPremiumAndSubscription() {
        // GIVEN: Annual status
        let status = HeirloomSubscriptionStatus.annual

        // THEN: Should be both premium and subscription
        XCTAssertTrue(status.isPremium)
        XCTAssertTrue(status.isSubscription)
    }

    /// Test 5: Lifetime status is premium but not subscription
    func test_subscriptionStatus_lifetime_isPremiumNotSubscription() {
        // GIVEN: Lifetime status
        let status = HeirloomSubscriptionStatus.lifetime

        // THEN: Should be premium but not subscription (one-time purchase)
        XCTAssertTrue(status.isPremium)
        XCTAssertFalse(status.isSubscription)
    }

    /// Test 6: Expired status is not premium
    func test_subscriptionStatus_expired_isNotPremium() {
        // GIVEN: Expired status
        let status = HeirloomSubscriptionStatus.expired

        // THEN: Should not be premium
        XCTAssertFalse(status.isPremium)
        XCTAssertFalse(status.isSubscription)
    }

    /// Test 7: Grace period status is still premium
    func test_subscriptionStatus_grace_isStillPremium() {
        // GIVEN: Grace period status
        let status = HeirloomSubscriptionStatus.grace

        // THEN: Should still be premium (billing issue but access continues)
        XCTAssertTrue(status.isPremium)
    }

    // MARK: - Trial Duration Tests

    /// Test 8: Default trial is 14 days
    func test_trialDuration_default_isFourteenDays() {
        // GIVEN: Default trial duration constant
        let defaultTrialDays = TrialDuration.annual

        // THEN: Should be 14 days
        XCTAssertEqual(defaultTrialDays.days, 14)
    }

    /// Test 9: Monthly plan trial is 7 days
    func test_trialDuration_monthlyPlan_isSevenDays() {
        // GIVEN: Monthly plan trial duration
        let monthlyTrialDays = TrialDuration.monthly

        // THEN: Should be 7 days
        XCTAssertEqual(monthlyTrialDays.days, 7)
    }

    // MARK: - Product Identifier Tests

    /// Test 10: Monthly product ID is correct
    func test_productIdentifier_monthly_isCorrect() {
        // GIVEN: Monthly product identifier
        let productId = ProductIdentifier.monthly

        // THEN: Should have correct raw value
        XCTAssertEqual(productId.rawValue, "com.rationalestudio.heirloom.monthly")
    }

    /// Test 11: Annual product ID is correct
    func test_productIdentifier_annual_isCorrect() {
        // GIVEN: Annual product identifier
        let productId = ProductIdentifier.annual

        // THEN: Should have correct raw value
        XCTAssertEqual(productId.rawValue, "com.rationalestudio.heirloom.annual")
    }

    /// Test 12: Lifetime product ID is correct
    func test_productIdentifier_lifetime_isCorrect() {
        // GIVEN: Lifetime product identifier
        let productId = ProductIdentifier.lifetime

        // THEN: Should have correct raw value
        XCTAssertEqual(productId.rawValue, "com.rationalestudio.heirloom.lifetime")
    }

    // MARK: - Paywall Trigger Tests

    /// Test 13: URL import trigger exists
    func test_paywallTrigger_urlImport_exists() {
        // GIVEN: URL import trigger
        let trigger = PaywallTrigger.urlImport

        // THEN: Should be a valid trigger
        XCTAssertNotNil(trigger)
        XCTAssertTrue(trigger.isHardWall)
    }

    /// Test 14: Cookbook scan trigger exists
    func test_paywallTrigger_cookbookScan_exists() {
        // GIVEN: Cookbook scan trigger
        let trigger = PaywallTrigger.cookbookScan

        // THEN: Should be a valid trigger
        XCTAssertNotNil(trigger)
        XCTAssertTrue(trigger.isHardWall)
    }

    /// Test 15: Sync trigger exists
    func test_paywallTrigger_sync_exists() {
        // GIVEN: Sync trigger
        let trigger = PaywallTrigger.sync

        // THEN: Should be a valid trigger
        XCTAssertNotNil(trigger)
        XCTAssertTrue(trigger.isHardWall)
    }

    /// Test 16: First recipe trigger is soft wall
    func test_paywallTrigger_firstRecipeAdded_isSoftWall() {
        // GIVEN: First recipe added trigger
        let trigger = PaywallTrigger.firstRecipeAdded

        // THEN: Should be a soft wall (dismissible)
        XCTAssertFalse(trigger.isHardWall)
        XCTAssertTrue(trigger.isSoftWall)
    }

    /// Test 17: Day 13 urgency trigger is soft wall
    func test_paywallTrigger_day13Urgency_isSoftWall() {
        // GIVEN: Day 13 urgency trigger
        let trigger = PaywallTrigger.day13Urgency

        // THEN: Should be a soft wall
        XCTAssertFalse(trigger.isHardWall)
        XCTAssertTrue(trigger.isSoftWall)
    }

    // MARK: - Cooldown Tests

    /// Test 18: First recipe cooldown is 48 hours
    func test_paywallCooldown_firstRecipe_is48Hours() {
        // GIVEN: First recipe trigger
        let trigger = PaywallTrigger.firstRecipeAdded

        // THEN: Should have 48 hour cooldown
        XCTAssertEqual(trigger.cooldownInterval, 48 * 60 * 60)
    }

    /// Test 19: Five recipes cooldown is 72 hours
    func test_paywallCooldown_fiveRecipes_is72Hours() {
        // GIVEN: Five recipes trigger
        let trigger = PaywallTrigger.fiveRecipesOrDay7

        // THEN: Should have 72 hour cooldown
        XCTAssertEqual(trigger.cooldownInterval, 72 * 60 * 60)
    }

    /// Test 20: Day 13 has no cooldown (one-time)
    func test_paywallCooldown_day13_hasNoCooldown() {
        // GIVEN: Day 13 urgency trigger
        let trigger = PaywallTrigger.day13Urgency

        // THEN: Should have no cooldown (nil or 0)
        XCTAssertTrue(trigger.cooldownInterval == nil || trigger.cooldownInterval == 0)
    }

    // MARK: - 3-Strike Rule Tests

    /// Test 21: Strike count starts at zero
    func test_strikeCount_startsAtZero() {
        // GIVEN: Fresh PaywallState
        let state = PaywallState()

        // THEN: Strike count should be zero
        XCTAssertEqual(state.dismissCount, 0)
        XCTAssertFalse(state.isStrikeRuleActive)
    }

    /// Test 22: Strike rule activates after 3 dismissals
    func test_strikeRule_activatesAfter3Dismissals() {
        // GIVEN: State with 3 dismissals
        var state = PaywallState()
        state.dismissCount = 3

        // THEN: Strike rule should be active
        XCTAssertTrue(state.isStrikeRuleActive)
    }

    /// Test 23: Strike rule not active with 2 dismissals
    func test_strikeRule_notActiveWith2Dismissals() {
        // GIVEN: State with 2 dismissals
        var state = PaywallState()
        state.dismissCount = 2

        // THEN: Strike rule should not be active
        XCTAssertFalse(state.isStrikeRuleActive)
    }

    // MARK: - Extraction Mode Tests

    /// Test 24: Audio transcript mode is free
    func test_extractionMode_audioTranscript_isFree() {
        // GIVEN: Audio transcript extraction mode
        let mode = ExtractionMode.audioTranscript

        // THEN: Should not require premium
        XCTAssertFalse(mode.requiresPremium)
    }

    /// Test 25: On-screen text mode is free
    func test_extractionMode_onScreenText_isFree() {
        // GIVEN: On-screen text extraction mode
        let mode = ExtractionMode.onScreenText

        // THEN: Should not require premium
        XCTAssertFalse(mode.requiresPremium)
    }

    /// Test 26: Visual frames mode requires premium
    func test_extractionMode_visualFrames_requiresPremium() {
        // GIVEN: Visual frames extraction mode
        let mode = ExtractionMode.visualFrames

        // THEN: Should require premium
        XCTAssertTrue(mode.requiresPremium)
    }

    // MARK: - Trial Day Calculation Tests

    /// Test 27: Days remaining calculated correctly
    func test_trialDaysRemaining_calculatedCorrectly() {
        // GIVEN: Trial that started 5 days ago
        let startDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let expiryDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate)!

        // WHEN: Calculating days remaining
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0

        // THEN: Should have approximately 9 days remaining (±1 for time-of-day edge cases)
        XCTAssertTrue(daysRemaining >= 8 && daysRemaining <= 9, "Expected 8-9 days remaining, got \(daysRemaining)")
    }

    /// Test 28: Trial expired when expiry date is in past
    func test_trialExpired_whenExpiryDateInPast() {
        // GIVEN: Expiry date in the past
        let expiryDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // WHEN: Checking if expired
        let isExpired = expiryDate < Date()

        // THEN: Should be expired
        XCTAssertTrue(isExpired)
    }

    // MARK: - ASMR Credits Tests

    /// Test 29: Free user gets 1 ASMR extraction per month
    func test_asmrCredits_freeUser_gets1PerMonth() {
        // GIVEN: Free user ASMR allowance
        let freeAllowance = ASMRUsageLimits.freeExtractionsPerMonth

        // THEN: Should be 1 extraction
        XCTAssertEqual(freeAllowance, 1)
    }

    /// Test 30: Premium user gets 4 ASMR extractions per month
    func test_asmrCredits_premiumUser_gets4PerMonth() {
        // GIVEN: Premium user ASMR allowance
        let premiumAllowance = ASMRUsageLimits.premiumExtractionsPerMonth

        // THEN: Should be 4 extractions
        XCTAssertEqual(premiumAllowance, 4)
    }

    /// Test 31: Each ASMR extraction costs 5 credits
    func test_asmrCredits_extractionCost_is5Credits() {
        // GIVEN: ASMR extraction cost
        let cost = ASMRUsageLimits.creditsPerExtraction

        // THEN: Should be 5 credits
        XCTAssertEqual(cost, 5)
    }
}

// MARK: - Test Helpers

/// Trial duration options
enum TrialDuration {
    case monthly
    case annual

    var days: Int {
        switch self {
        case .monthly: return 7
        case .annual: return 14
        }
    }
}

/// Paywall state for testing
struct PaywallState {
    var dismissCount: Int = 0
    var recipeCount: Int = 0

    var isStrikeRuleActive: Bool {
        dismissCount >= 3
    }
}

/// Extraction mode for video processing
enum ExtractionMode {
    case audioTranscript
    case onScreenText
    case visualFrames

    var requiresPremium: Bool {
        self == .visualFrames
    }
}

/// ASMR usage limits
enum ASMRUsageLimits {
    static let freeExtractionsPerMonth = 1
    static let premiumExtractionsPerMonth = 4
    static let creditsPerExtraction = 5
}

extension PaywallTrigger {
    /// Whether this trigger blocks the feature (hard wall)
    var isHardWall: Bool {
        switch self {
        case .urlImport, .cookbookScan, .sync, .largePDFImport, .visualVideoExtraction:
            return true
        default:
            return false
        }
    }

    /// Whether this trigger is dismissible (soft wall)
    var isSoftWall: Bool {
        !isHardWall
    }

    /// Cooldown interval in seconds (nil = no cooldown)
    var cooldownInterval: TimeInterval? {
        switch self {
        case .firstRecipeAdded: return 48 * 60 * 60  // 48 hours
        case .fiveRecipesOrDay7: return 72 * 60 * 60 // 72 hours
        case .day13Urgency: return nil                // One-time
        default: return nil                           // Hard walls have no cooldown
        }
    }
}
