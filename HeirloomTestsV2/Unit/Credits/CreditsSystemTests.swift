//
//  CreditsSystemTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Unit tests for credits system
//
//  Tests the credit management system to ensure:
//  - Daily quota reset works correctly
//  - Quota vs purchased credit priority (free first)
//  - Insufficient balance handling
//  - Purchase credit packages
//  - Credit deduction logic
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class CreditsSystemTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!
    var userCredits: UserCredits!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true, credits: 25)
        userCredits = env.createUserCredits(purchasedCredits: 0, dailyQuotaUsed: 0)
        try env.save()
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        userCredits = nil
        try await super.tearDown()
    }

    // MARK: - Daily Quota Tests

    /// Test 1: Fresh user has full daily quota
    func test_freshUser_hasFull25DailyQuota() throws {
        // GIVEN: A fresh user with no activity
        XCTAssertEqual(userCredits.dailyQuotaUsed, 0)

        // WHEN: Checking available credits
        let available = userCredits.availableToday

        // THEN: Should have full daily quota (25)
        XCTAssertEqual(available, UserCredits.dailyFreeQuota)
        XCTAssertEqual(available, 25, "Fresh user should have 25 daily credits")
    }

    /// Test 2: Quota remaining decreases with usage
    func test_deductCredits_decreasesQuotaRemaining() throws {
        // GIVEN: User with full quota
        let initialQuota = userCredits.quotaRemaining
        XCTAssertEqual(initialQuota, 25)

        // WHEN: Deducting 5 credits
        try userCredits.deductCredits(5)

        // THEN: Quota remaining should decrease
        XCTAssertEqual(userCredits.quotaRemaining, 20)
        XCTAssertEqual(userCredits.dailyQuotaUsed, 5)
    }

    /// Test 3: Daily quota resets at midnight
    func test_dailyQuotaReset_resetsAtMidnight() throws {
        // GIVEN: User who used all quota yesterday
        userCredits.dailyQuotaUsed = 25
        userCredits.dailyQuotaResetDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // WHEN: Accessing quota today
        let wasReset = userCredits.resetDailyQuotaIfNeeded()

        // THEN: Quota should be reset
        XCTAssertTrue(wasReset, "Quota should reset on new day")
        XCTAssertEqual(userCredits.dailyQuotaUsed, 0, "Used quota should be zero after reset")
        XCTAssertEqual(userCredits.quotaRemaining, 25, "Full quota should be available")
    }

    /// Test 4: Quota does not reset on same day
    func test_dailyQuotaReset_doesNotResetOnSameDay() throws {
        // GIVEN: User who used some quota today
        userCredits.dailyQuotaUsed = 10
        userCredits.dailyQuotaResetDate = Date()

        // WHEN: Checking if reset needed
        let wasReset = userCredits.resetDailyQuotaIfNeeded()

        // THEN: Should not reset
        XCTAssertFalse(wasReset, "Quota should not reset on same day")
        XCTAssertEqual(userCredits.dailyQuotaUsed, 10, "Used quota should remain unchanged")
    }

    // MARK: - Credit Priority Tests (Quota First)

    /// Test 5: Deduction uses daily quota first before purchased
    func test_deductCredits_usesQuotaBeforePurchased() throws {
        // GIVEN: User with 25 daily quota AND 50 purchased credits
        userCredits.creditsBalance = 50
        XCTAssertEqual(userCredits.quotaRemaining, 25)
        XCTAssertEqual(userCredits.creditsBalance, 50)

        // WHEN: Deducting 10 credits
        try userCredits.deductCredits(10)

        // THEN: Should deduct from quota first, purchased unchanged
        XCTAssertEqual(userCredits.dailyQuotaUsed, 10, "Should use daily quota first")
        XCTAssertEqual(userCredits.creditsBalance, 50, "Purchased credits should be unchanged")
        XCTAssertEqual(userCredits.quotaRemaining, 15)
    }

    /// Test 6: Deduction uses purchased credits when quota exhausted
    func test_deductCredits_usesPurchasedWhenQuotaExhausted() throws {
        // GIVEN: User with 5 quota remaining and 50 purchased
        userCredits.dailyQuotaUsed = 20
        userCredits.creditsBalance = 50
        XCTAssertEqual(userCredits.quotaRemaining, 5)

        // WHEN: Deducting 15 credits (more than quota remaining)
        try userCredits.deductCredits(15)

        // THEN: Should use remaining quota (5) + purchased (10)
        XCTAssertEqual(userCredits.dailyQuotaUsed, 25, "Should exhaust daily quota")
        XCTAssertEqual(userCredits.creditsBalance, 40, "Should deduct 10 from purchased")
    }

    /// Test 7: Available today combines quota and purchased
    func test_availableToday_combinesQuotaAndPurchased() throws {
        // GIVEN: User with 10 quota remaining and 30 purchased
        userCredits.dailyQuotaUsed = 15
        userCredits.creditsBalance = 30

        // WHEN: Checking available
        let available = userCredits.availableToday

        // THEN: Should be sum of remaining quota + purchased
        XCTAssertEqual(available, 40, "Should combine 10 quota + 30 purchased")
    }

    // MARK: - Insufficient Balance Tests

    /// Test 8: Throws error when insufficient credits
    func test_deductCredits_throwsWhenInsufficient() throws {
        // GIVEN: User with only 5 total credits
        userCredits.dailyQuotaUsed = 20
        userCredits.creditsBalance = 0
        XCTAssertEqual(userCredits.availableToday, 5)

        // WHEN/THEN: Deducting more than available should throw
        XCTAssertThrowsError(try userCredits.deductCredits(10)) { error in
            guard case CreditError.insufficientCredits(let needed, let available) = error else {
                XCTFail("Expected insufficientCredits error, got \(error)")
                return
            }
            XCTAssertEqual(needed, 10)
            XCTAssertEqual(available, 5)
        }
    }

    /// Test 9: Can afford returns true when sufficient
    func test_canAfford_returnsTrueWhenSufficient() throws {
        // GIVEN: User with 25 credits available
        XCTAssertEqual(userCredits.availableToday, 25)

        // WHEN/THEN: Checking affordability
        XCTAssertTrue(userCredits.canAfford(credits: 1))
        XCTAssertTrue(userCredits.canAfford(credits: 25))
        XCTAssertFalse(userCredits.canAfford(credits: 26))
    }

    /// Test 10: Can afford returns false when insufficient
    func test_canAfford_returnsFalseWhenInsufficient() throws {
        // GIVEN: User with 0 credits (quota exhausted, no purchased)
        userCredits.dailyQuotaUsed = 25
        userCredits.creditsBalance = 0

        // WHEN/THEN: Should not afford any credits
        XCTAssertFalse(userCredits.canAfford(credits: 1))
        XCTAssertFalse(userCredits.canAfford(credits: 5))
    }

    // MARK: - Purchase Credits Tests

    /// Test 11: Adding purchased credits increases balance
    func test_addPurchasedCredits_increasesBalance() throws {
        // GIVEN: User with 0 purchased credits
        XCTAssertEqual(userCredits.creditsBalance, 0)

        // WHEN: Purchasing 100 credits
        userCredits.addPurchasedCredits(100)

        // THEN: Balance should increase
        XCTAssertEqual(userCredits.creditsBalance, 100)
        XCTAssertEqual(userCredits.lifetimePurchasedCredits, 100)
        XCTAssertNotNil(userCredits.lastPurchaseDate)
    }

    /// Test 12: Multiple purchases accumulate
    func test_addPurchasedCredits_accumulates() throws {
        // GIVEN: User who made one purchase
        userCredits.addPurchasedCredits(50)

        // WHEN: Making another purchase
        userCredits.addPurchasedCredits(75)

        // THEN: Credits should accumulate
        XCTAssertEqual(userCredits.creditsBalance, 125)
        XCTAssertEqual(userCredits.lifetimePurchasedCredits, 125)
    }

    /// Test 13: Purchased credits persist across quota reset
    func test_purchasedCredits_persistAcrossQuotaReset() throws {
        // GIVEN: User with purchased credits who used all quota
        userCredits.creditsBalance = 100
        userCredits.dailyQuotaUsed = 25
        userCredits.dailyQuotaResetDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // WHEN: Quota resets
        userCredits.resetDailyQuotaIfNeeded()

        // THEN: Purchased credits should remain
        XCTAssertEqual(userCredits.creditsBalance, 100, "Purchased credits should persist")
        XCTAssertEqual(userCredits.quotaRemaining, 25, "Daily quota should reset")
        XCTAssertEqual(userCredits.availableToday, 125, "Total should be quota + purchased")
    }

    // MARK: - Credit Cost Constants Tests

    /// Test 14: PDF credit costs are correct
    func test_pdfCreditCosts_areCorrect() throws {
        // GIVEN/WHEN/THEN: Verify credit cost constants
        XCTAssertEqual(UserCredits.PDFCreditCost.textRich.rawValue, 1)
        XCTAssertEqual(UserCredits.PDFCreditCost.mixed.rawValue, 3)
        XCTAssertEqual(UserCredits.PDFCreditCost.scanned.rawValue, 5)
    }

    /// Test 15: Video credit costs are correct
    func test_videoCreditCosts_areCorrect() throws {
        // GIVEN/WHEN/THEN: Verify video cost constants
        XCTAssertEqual(UserCredits.VideoCreditCost.regular.rawValue, 1)
        XCTAssertEqual(UserCredits.VideoCreditCost.asmr.rawValue, 5)
    }

    // MARK: - Edge Cases

    /// Test 16: Zero credit deduction succeeds
    func test_deductCredits_zeroDeduction_succeeds() throws {
        // GIVEN: User with credits
        let initialQuota = userCredits.quotaRemaining

        // WHEN: Deducting 0 credits
        try userCredits.deductCredits(0)

        // THEN: Should succeed with no change
        XCTAssertEqual(userCredits.quotaRemaining, initialQuota)
    }

    /// Test 17: Exact balance deduction succeeds
    func test_deductCredits_exactBalance_succeeds() throws {
        // GIVEN: User with exactly 25 credits (all quota)
        XCTAssertEqual(userCredits.availableToday, 25)

        // WHEN: Deducting exactly 25
        try userCredits.deductCredits(25)

        // THEN: Should succeed, leaving 0
        XCTAssertEqual(userCredits.availableToday, 0)
        XCTAssertEqual(userCredits.dailyQuotaUsed, 25)
    }

    /// Test 18: Large purchase amount works
    func test_addPurchasedCredits_largeAmount_works() throws {
        // GIVEN: User with 0 credits

        // WHEN: Purchasing large amount
        userCredits.addPurchasedCredits(10000)

        // THEN: Should work correctly
        XCTAssertEqual(userCredits.creditsBalance, 10000)
        XCTAssertEqual(userCredits.availableToday, 10025) // 10000 + 25 quota
    }

    /// Test 19: Quota reset time is next midnight
    func test_quotaResetTime_isNextMidnight() throws {
        // GIVEN: Current time

        // WHEN: Getting reset time
        let resetTime = userCredits.quotaResetTime

        // THEN: Should be start of tomorrow
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let expectedReset = calendar.startOfDay(for: tomorrow)

        XCTAssertEqual(resetTime, expectedReset, "Reset time should be midnight tomorrow")
    }

    /// Test 20: Error message contains needed and available
    func test_creditError_containsUsefulInfo() throws {
        // GIVEN: User with limited credits
        userCredits.dailyQuotaUsed = 20
        userCredits.creditsBalance = 0 // Only 5 available

        // WHEN: Attempting to deduct too many
        do {
            try userCredits.deductCredits(10)
            XCTFail("Should have thrown error")
        } catch let error as CreditError {
            // THEN: Error should contain useful info
            let description = error.errorDescription ?? ""
            XCTAssertTrue(description.contains("10"), "Should mention needed credits")
            XCTAssertTrue(description.contains("5"), "Should mention available credits")

            let suggestion = error.recoverySuggestion ?? ""
            XCTAssertTrue(suggestion.contains("5"), "Should suggest purchasing shortfall")
        }
    }
}
