//
//  SubscriptionManagerBaselineTests.swift
//  HeirloomTestsV2
//
//  Baseline (happy path) tests for SubscriptionManager
//  Created: 2026-01-13
//

import XCTest
@testable import Heirloom

@MainActor
final class SubscriptionManagerBaselineTests: XCTestCase {

    var sut: SubscriptionManager!

    override func setUp() async throws {
        try await super.setUp()
        setupCleanUserDefaults()
    }

    override func tearDown() async throws {
        sut = nil
        tearDownUserDefaults()
        try await super.tearDown()
    }

    // MARK: - Trial Initialization Tests

    func test_trialInitialization_onFirstLaunch() throws {
        // Given: Fresh install, no existing trial
        // When: Manager is initialized (initializeTrialIfNeeded called in init)
        sut = TrialStateBuilder()
            .withNoExistingTrial()
            .withDebugForceNonPremium(false)  // Allow trial initialization
            .build()

        // Then: Trial should be active with 14 days
        XCTAssertEqual(sut.isInTrial, true, "Trial should be active after initialization")
        XCTAssertEqual(sut.daysRemaining, 14, "Should have 14 days remaining")
        XCTAssertNotNil(sut.trialExpiryDate, "Trial expiry date should be set")
    }

    func test_trialInitialization_onBlindBoxReveal() throws {
        // Given: User completed onboarding, revealing blind boxes
        sut = TrialStateBuilder()
            .withNoExistingTrial()
            .build()

        // When: Blind box reveal triggers trial
        sut.initializeTrialOnBlindBoxReveal()

        // Then: Trial should start with 14 days
        XCTAssertEqual(sut.isInTrial, true, "Trial should be active")
        XCTAssertEqual(sut.daysRemaining, 14, "Should have 14 days")
        XCTAssertEqual(sut.status, .trial, "Status should be trial")
    }

    func test_daysRemaining_calculation_day7() throws {
        // Given: Trial started 7 days ago
        sut = TrialStateBuilder()
            .withDaysIntoTrial(7)
            .build()

        // Then: Should have 7 days remaining
        XCTAssertEqual(sut.daysRemaining, 7, "Should have 7 days remaining on day 7")
        XCTAssertEqual(sut.isInTrial, true, "Trial should still be active")
    }

    func test_isPremium_withActiveMonthlySubscription() throws {
        // Given: User has active monthly subscription
        sut = TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .build()

        // When: Refresh status
        Task {
            await sut.refreshStatus()
        }

        // Then: isPremium should be true
        XCTAssertEqual(sut.isPremium, true, "User with monthly subscription should be premium")
        XCTAssertEqual(sut.status, .monthly, "Status should be monthly")
    }

    func test_isInTrial_withActiveTrial() throws {
        // Given: Trial is active (day 1)
        sut = TrialStateBuilder.day1()

        // Then: isInTrial should be true
        XCTAssertEqual(sut.isInTrial, true, "User in trial should have isInTrial = true")
        XCTAssertEqual(sut.isPremium, false, "User in trial is not premium (yet)")
    }

    func test_statusRefresh_updatesCorrectly() async throws {
        // Given: User has monthly subscription
        sut = TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .build()

        // When: Refresh status
        await sut.refreshStatus()

        // Then: Status should be updated
        XCTAssertEqual(sut.status, .monthly, "Status should be monthly after refresh")
        XCTAssertEqual(sut.isPremium, true, "Should be premium")
        XCTAssertNotNil(sut.subscriptionExpiryDate, "Subscription expiry should be set")
    }

    // MARK: - Product ID Tracking Tests

    func test_currentProductID_tracksMonthly() throws {
        // Given: User purchased monthly subscription
        sut = TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .build()

        // Then: Current product ID should be monthly
        XCTAssertEqual(sut.currentProductID, .monthly, "Should track monthly product ID")
        XCTAssertEqual(sut.currentPlanName, "Monthly", "Plan name should be Monthly")
    }

    func test_currentProductID_tracksAnnual() throws {
        // Given: User purchased annual subscription
        sut = TrialStateBuilder()
            .withActiveSubscription(.annual)
            .build()

        // Then: Current product ID should be annual
        XCTAssertEqual(sut.currentProductID, .annual, "Should track annual product ID")
        XCTAssertEqual(sut.currentPlanName, "Annual", "Plan name should be Annual")
    }

    func test_currentProductID_tracksLifetime() throws {
        // Given: User purchased lifetime
        sut = TrialStateBuilder()
            .withActiveSubscription(.lifetime)
            .build()

        // Then: Current product ID should be lifetime
        XCTAssertEqual(sut.currentProductID, .lifetime, "Should track lifetime product ID")
        XCTAssertEqual(sut.currentPlanName, "Lifetime", "Plan name should be Lifetime")
    }

    // MARK: - Upgrade/Downgrade Eligibility Tests

    func test_canUpgrade_fromMonthlyToAnnual() throws {
        // Given: User has monthly subscription
        sut = TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .build()

        // Then: Can upgrade to annual
        XCTAssertEqual(sut.canUpgrade, true, "Monthly users can upgrade to annual")
        XCTAssertEqual(sut.canDowngrade, false, "Monthly users cannot downgrade")
    }

    func test_canDowngrade_fromAnnualToMonthly() throws {
        // Given: User has annual subscription
        sut = TrialStateBuilder()
            .withActiveSubscription(.annual)
            .build()

        // Then: Can downgrade to monthly
        XCTAssertEqual(sut.canDowngrade, true, "Annual users can downgrade to monthly")
        XCTAssertEqual(sut.canUpgrade, false, "Annual users cannot upgrade further")
    }

    func test_cannotUpgradeOrDowngrade_withLifetime() throws {
        // Given: User has lifetime purchase
        sut = TrialStateBuilder()
            .withActiveSubscription(.lifetime)
            .build()

        // Then: Cannot upgrade or downgrade
        XCTAssertEqual(sut.canUpgrade, false, "Lifetime users cannot upgrade")
        XCTAssertEqual(sut.canDowngrade, false, "Lifetime users cannot downgrade")
    }
}
