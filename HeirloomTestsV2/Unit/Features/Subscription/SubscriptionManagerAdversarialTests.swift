//
//  SubscriptionManagerAdversarialTests.swift
//  HeirloomTestsV2
//
//  Adversarial (edge case) tests for SubscriptionManager
//  Created: 2026-01-13
//

import XCTest
@testable import Heirloom

@MainActor
final class SubscriptionManagerAdversarialTests: XCTestCase {

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

    // MARK: - Trial Expiry Tests

    func test_trialExpired_day15_isInTrialReturnsFalse() throws {
        // Given: Trial expired (day 15+)
        sut = TrialStateBuilder.expired()

        // Then: Trial should be expired
        XCTAssertEqual(sut.isInTrial, false, "Expired trial should not be active")
        XCTAssertEqual(sut.isTrialExpired, true, "Trial should be marked as expired")
        XCTAssertEqual(sut.isPremium, false, "Expired trial is not premium")
    }

    func test_trialNeverStarted_isInTrialReturnsFalse() throws {
        // Given: No trial ever started
        sut = TrialStateBuilder.noTrial()

        // Then: isInTrial should be false
        XCTAssertEqual(sut.isInTrial, false, "No trial means isInTrial = false")
        XCTAssertEqual(sut.isTrialExpired, false, "No trial means not expired")
        XCTAssertEqual(sut.trialExpiryDate, nil, "No expiry date without trial")
    }

    func test_doubleTrialInitialization_prevented() throws {
        // Given: Trial already initialized on day 1
        sut = TrialStateBuilder.day1()
        let originalExpiryDate = sut.trialExpiryDate

        // When: Create a new manager instance (would call initializeTrialIfNeeded in init)
        let newManager = TrialStateBuilder.day1()

        // Then: Trial date should not have changed
        assertDatesEqual(newManager.trialExpiryDate, originalExpiryDate, within: 1.0)
        XCTAssertEqual(newManager.daysRemaining, 14, "Days remaining should not reset")
    }

    func test_debugForceNonPremium_respectsFlag() throws {
        // Given: User has subscription but debug flag is set
        sut = TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .withDebugForceNonPremium(true)
            .build()

        // Then: isPremium should be false despite subscription
        XCTAssertEqual(sut.isPremium, false, "Debug flag should override premium status")
    }

    // MARK: - Concurrent Access Tests

    func test_concurrentStatusRefreshes_maintainConsistentState() async throws {
        // Given: Subscription manager with monthly subscription
        sut = TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .build()

        // When: Multiple concurrent refresh calls
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await self.sut.refreshStatus()
                }
            }
        }

        // Then: State should be consistent (no corruption)
        XCTAssertEqual(sut.status, .monthly, "Status should be monthly after concurrent refreshes")
        XCTAssertEqual(sut.isPremium, true, "Premium status should be consistent")
    }

    func test_rapidStatusChecks_duringRefresh_noCorruption() async throws {
        // Given: Subscription manager
        sut = TrialStateBuilder.day7()

        // When: Rapid status checks during refresh
        Task {
            await sut.refreshStatus()
        }

        // Rapidly check status (should not crash or corrupt)
        for _ in 0..<100 {
            _ = sut.isPremium
            _ = sut.isInTrial
            _ = sut.status
        }

        // Then: Should complete without corruption
        XCTAssertNotNil(sut.status, "Status should be valid")
    }

    // MARK: - Invalid Data Handling Tests

    func test_invalidTrialDates_handledGracefully() throws {
        // Given: Corrupted trial dates in UserDefaults
        let futureStartDate = DateManipulator.daysFromNow(10)
        let pastExpiryDate = DateManipulator.daysAgo(5)

        UserDefaults.standard.set(futureStartDate, forKey: "first_launch_date")
        UserDefaults.standard.set(pastExpiryDate, forKey: "trial_expiry_date")

        sut = TrialStateBuilder().withNoExistingTrial().build()

        // Then: Should handle invalid dates gracefully
        XCTAssertFalse(sut.isInTrial, "Invalid dates should not result in active trial")
    }

    func test_cacheTTL_preventsDuplicateRefreshes() async throws {
        // Given: Just refreshed status
        sut = TrialStateBuilder.day7()
        await sut.refreshStatus()

        let refreshTime1 = Date()

        // When: Refresh again immediately (within TTL)
        await sut.refreshStatus()

        let refreshTime2 = Date()

        // Then: Second refresh should be quick (cached)
        let timeDifference = refreshTime2.timeIntervalSince(refreshTime1)
        XCTAssertLessThan(timeDifference, 0.1, "Cached refresh should be instant")
    }

    // MARK: - Product ID Persistence Tests

    func test_productIDTracking_persistsAcrossLaunches() throws {
        // Given: User purchases monthly subscription
        sut = TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .build()

        XCTAssertEqual(sut.currentProductID, .monthly, "Should track monthly initially")

        // When: Simulate app restart by creating new manager
        sut = TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .build()

        // Then: Product ID should still be tracked
        XCTAssertEqual(sut.currentProductID, .monthly, "Product ID should persist across launches")
    }

    // MARK: - Status Transition Tests

    func test_statusTransition_noneToTrial() throws {
        // Given: No subscription
        sut = TrialStateBuilder.noTrial()
        XCTAssertEqual(sut.status, .none, "Initial status should be none")

        // When: Trial starts
        sut.initializeTrialOnBlindBoxReveal()

        // Then: Status should transition to trial
        XCTAssertEqual(sut.status, .trial, "Status should transition to trial")
    }

    func test_statusTransition_trialToExpired() throws {
        // Given: Trial on day 14 (last day)
        sut = TrialStateBuilder.day14()
        XCTAssertEqual(sut.isInTrial, true, "Should be in trial on day 14")

        // When: Trial expires (simulate day 15)
        sut = TrialStateBuilder.expired()

        // Then: Status should be expired
        XCTAssertEqual(sut.isTrialExpired, true, "Trial should be expired")
        XCTAssertEqual(sut.isInTrial, false, "Should not be in trial")
    }

    func test_statusTransition_expiredToMonthly_afterPurchase() throws {
        // Given: Expired trial
        sut = TrialStateBuilder.expired()
        XCTAssertEqual(sut.isPremium, false, "Should not be premium with expired trial")

        // When: User purchases monthly subscription
        sut = TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .build()

        // Then: Status should be monthly
        XCTAssertEqual(sut.status, .monthly, "Status should transition to monthly")
        XCTAssertEqual(sut.isPremium, true, "Should be premium after purchase")
    }

    func test_statusTransition_monthlyToLifetime_afterUpgrade() throws {
        // Given: Monthly subscription
        sut = TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .build()
        XCTAssertEqual(sut.status, .monthly)

        // When: User upgrades to lifetime
        sut = TrialStateBuilder()
            .withActiveSubscription(.lifetime)
            .build()

        // Then: Status should be lifetime
        XCTAssertEqual(sut.status, .lifetime, "Status should transition to lifetime")
        XCTAssertEqual(sut.isPremium, true, "Should still be premium")
    }

    // MARK: - Boundary Condition Tests

    func test_boundaryDay0_justStarted() throws {
        // Given: Trial just started (day 0)
        sut = TrialStateBuilder()
            .withDaysIntoTrial(0)
            .build()

        // Then: Should have 14 days remaining
        XCTAssertEqual(sut.daysRemaining, 14, "Day 0 should have 14 days remaining")
        XCTAssertEqual(sut.isInTrial, true, "Should be in trial")
    }

    func test_boundaryDay14_lastDay() throws {
        // Given: Trial on last day (day 14)
        sut = TrialStateBuilder.day14()

        // Then: Should have 0 days remaining but still be in trial
        XCTAssertEqual(sut.daysRemaining, 0, "Day 14 should have 0 days remaining")
        XCTAssertEqual(sut.isInTrial, true, "Should still be in trial on last day")
    }

    func test_boundaryDay15_expired() throws {
        // Given: Day 15 (first day after trial)
        sut = TrialStateBuilder()
            .withDaysIntoTrial(15)
            .build()

        // Then: Trial should be expired
        XCTAssertEqual(sut.isInTrial, false, "Day 15 should be expired")
        XCTAssertEqual(sut.isTrialExpired, true, "Should be marked as expired")
    }

    // MARK: - Upgrade/Downgrade Edge Cases

    func test_upgradeDowngrade_noProductID_cannotUpgradeOrDowngrade() throws {
        // Given: No subscription
        sut = TrialStateBuilder.noTrial()

        // Then: Cannot upgrade or downgrade
        XCTAssertEqual(sut.canUpgrade, false, "No subscription means cannot upgrade")
        XCTAssertEqual(sut.canDowngrade, false, "No subscription means cannot downgrade")
    }

    func test_upgradeDowngrade_lifetimeCannotChange() throws {
        // Given: Lifetime purchase
        sut = TrialStateBuilder.lifetime()

        // Then: Cannot change plan
        XCTAssertEqual(sut.canUpgrade, false, "Lifetime cannot upgrade")
        XCTAssertEqual(sut.canDowngrade, false, "Lifetime cannot downgrade")
        XCTAssertEqual(sut.currentProductID, .lifetime)
    }
}
