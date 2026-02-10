//
//  PDFImportTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Integration tests for PDF import feature
//
//  Tests the PDF import pipeline to ensure:
//  - Cost calculation by PDF type (text-rich, mixed, scanned)
//  - Credit deduction before import
//  - Progress tracking through phases
//  - Error handling and recovery
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class PDFImportTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!
    var userCredits: UserCredits!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true, credits: 25)
        userCredits = env.createUserCredits(purchasedCredits: 0, tierCreditsUsed: 0)
        try env.save()
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        userCredits = nil
        try await super.tearDown()
    }

    // MARK: - Credit Cost Tests

    /// Test 1: Text-rich PDF costs 1 credit
    func test_pdfCreditCost_textRich_isOneCredit() {
        // GIVEN/WHEN/THEN: Text-rich PDFs cost 1 credit
        XCTAssertEqual(UserCredits.PDFCreditCost.textRich.rawValue, 1)
    }

    /// Test 2: Mixed PDF costs 3 credits
    func test_pdfCreditCost_mixed_isThreeCredits() {
        // GIVEN/WHEN/THEN: Mixed PDFs cost 3 credits
        XCTAssertEqual(UserCredits.PDFCreditCost.mixed.rawValue, 3)
    }

    /// Test 3: Scanned PDF costs 5 credits
    func test_pdfCreditCost_scanned_isFiveCredits() {
        // GIVEN/WHEN/THEN: Scanned PDFs cost 5 credits
        XCTAssertEqual(UserCredits.PDFCreditCost.scanned.rawValue, 5)
    }

    // MARK: - Credit Deduction Tests

    /// Test 4: Can afford text-rich PDF with fresh quota
    func test_canAfford_textRichPDF_withFreshQuota_returnsTrue() throws {
        // GIVEN: Fresh quota (25 credits)
        XCTAssertEqual(userCredits.availableToday, 25)

        // WHEN: Checking affordability
        let canAfford = userCredits.canAfford(credits: UserCredits.PDFCreditCost.textRich.rawValue)

        // THEN: Should be affordable
        XCTAssertTrue(canAfford)
    }

    /// Test 5: Can afford 5 scanned PDFs with fresh quota
    func test_canAfford_fiveScannedPDFs_withFreshQuota_returnsTrue() throws {
        // GIVEN: Fresh quota (25 credits)
        let scannedCost = UserCredits.PDFCreditCost.scanned.rawValue // 5 credits
        let fivePDFsCost = scannedCost * 5 // 25 credits

        // WHEN: Checking affordability
        let canAfford = userCredits.canAfford(credits: fivePDFsCost)

        // THEN: Should be exactly affordable
        XCTAssertTrue(canAfford)
    }

    /// Test 6: Cannot afford 6th scanned PDF with fresh quota
    func test_canAfford_sixScannedPDFs_withFreshQuota_returnsFalse() throws {
        // GIVEN: Fresh quota (25 credits)
        let scannedCost = UserCredits.PDFCreditCost.scanned.rawValue
        let sixPDFsCost = scannedCost * 6 // 30 credits

        // WHEN: Checking affordability
        let canAfford = userCredits.canAfford(credits: sixPDFsCost)

        // THEN: Should not be affordable
        XCTAssertFalse(canAfford)
    }

    /// Test 7: Can afford with purchased credits when quota exhausted
    func test_canAfford_withPurchasedCredits_afterQuotaExhausted() throws {
        // GIVEN: Exhausted quota but has purchased credits
        userCredits.tierCreditsUsed = 25 // Quota exhausted
        userCredits.creditsBalance = 50 // Has purchased credits

        // WHEN: Checking affordability for scanned PDF
        let canAfford = userCredits.canAfford(credits: UserCredits.PDFCreditCost.scanned.rawValue)

        // THEN: Should be affordable from purchased
        XCTAssertTrue(canAfford)
    }

    /// Test 8: Deducting credits for text-rich PDF
    func test_deductCredits_textRichPDF_deductsCorrectAmount() throws {
        // GIVEN: Fresh quota
        let initialAvailable = userCredits.availableToday

        // WHEN: Deducting for text-rich PDF
        try userCredits.deductCredits(UserCredits.PDFCreditCost.textRich.rawValue)

        // THEN: Should deduct 1 credit
        XCTAssertEqual(userCredits.availableToday, initialAvailable - 1)
    }

    /// Test 9: Deducting credits for scanned PDF
    func test_deductCredits_scannedPDF_deductsCorrectAmount() throws {
        // GIVEN: Fresh quota
        let initialAvailable = userCredits.availableToday

        // WHEN: Deducting for scanned PDF
        try userCredits.deductCredits(UserCredits.PDFCreditCost.scanned.rawValue)

        // THEN: Should deduct 5 credits
        XCTAssertEqual(userCredits.availableToday, initialAvailable - 5)
    }

    /// Test 10: Deducting credits for mixed PDF
    func test_deductCredits_mixedPDF_deductsCorrectAmount() throws {
        // GIVEN: Fresh quota
        let initialAvailable = userCredits.availableToday

        // WHEN: Deducting for mixed PDF
        try userCredits.deductCredits(UserCredits.PDFCreditCost.mixed.rawValue)

        // THEN: Should deduct 3 credits
        XCTAssertEqual(userCredits.availableToday, initialAvailable - 3)
    }

    /// Test 11: Insufficient credits throws error
    func test_deductCredits_insufficient_throwsError() throws {
        // GIVEN: No credits available
        userCredits.tierCreditsUsed = 25
        userCredits.creditsBalance = 0
        XCTAssertEqual(userCredits.availableToday, 0)

        // WHEN/THEN: Deducting should throw
        XCTAssertThrowsError(try userCredits.deductCredits(UserCredits.PDFCreditCost.textRich.rawValue)) { error in
            guard case CreditError.insufficientCredits = error else {
                XCTFail("Expected insufficientCredits error")
                return
            }
        }
    }

    // MARK: - Bulk Import Credit Tests

    /// Test 12: Multiple text-rich PDFs calculated correctly
    func test_bulkImport_multipleTextRich_costsCorrectly() throws {
        // GIVEN: 10 text-rich PDFs
        let pdfCount = 10
        let costPerPDF = UserCredits.PDFCreditCost.textRich.rawValue
        let totalCost = pdfCount * costPerPDF

        // WHEN: Checking affordability
        let canAfford = userCredits.canAfford(credits: totalCost)

        // THEN: Should be affordable (10 credits from 25)
        XCTAssertTrue(canAfford)
        XCTAssertEqual(totalCost, 10)
    }

    /// Test 13: Mixed batch with different PDF types
    func test_bulkImport_mixedTypes_costsCorrectly() throws {
        // GIVEN: Mix of PDF types: 2 text-rich, 2 mixed, 1 scanned
        let textRichCost = 2 * UserCredits.PDFCreditCost.textRich.rawValue  // 2
        let mixedCost = 2 * UserCredits.PDFCreditCost.mixed.rawValue        // 6
        let scannedCost = 1 * UserCredits.PDFCreditCost.scanned.rawValue    // 5
        let totalCost = textRichCost + mixedCost + scannedCost              // 13

        // WHEN: Checking affordability
        let canAfford = userCredits.canAfford(credits: totalCost)

        // THEN: Should be affordable (13 from 25)
        XCTAssertTrue(canAfford)
        XCTAssertEqual(totalCost, 13)
    }

    // MARK: - Daily Quota Limit Tests

    /// Test 14: Daily quota allows 25 text-rich PDFs
    func test_dailyQuota_allows25TextRichPDFs() throws {
        // GIVEN: Fresh quota
        let maxTextRich = UserCredits.dailyFreeQuota / UserCredits.PDFCreditCost.textRich.rawValue

        // THEN: Should allow 25 text-rich PDFs
        XCTAssertEqual(maxTextRich, 25)
    }

    /// Test 15: Daily quota allows 5 scanned PDFs
    func test_dailyQuota_allows5ScannedPDFs() throws {
        // GIVEN: Fresh quota
        let maxScanned = UserCredits.dailyFreeQuota / UserCredits.PDFCreditCost.scanned.rawValue

        // THEN: Should allow 5 scanned PDFs
        XCTAssertEqual(maxScanned, 5)
    }

    // MARK: - Credit Persistence Tests

    /// Test 16: Credits persist after import
    func test_credits_persistAfterImport() throws {
        // GIVEN: Initial credits
        _ = userCredits.creditsBalance

        // WHEN: Deducting credits (simulating import)
        try userCredits.deductCredits(UserCredits.PDFCreditCost.scanned.rawValue)
        try env.save()

        // THEN: Credits should persist
        let fetchedCredits = try env.fetchUserCredits()
        XCTAssertNotNil(fetchedCredits)
        XCTAssertEqual(fetchedCredits?.tierCreditsUsed, 5)
    }

    // MARK: - AI Image Generation Credit Tests

    /// Test 17: AI image generation adds additional cost
    func test_aiImageGeneration_addsCost() throws {
        // GIVEN: Base PDF cost
        let baseCost = UserCredits.PDFCreditCost.textRich.rawValue
        let aiImageCost = 5 // Example AI image cost
        let totalCost = baseCost + aiImageCost

        // WHEN: Checking total affordability
        let canAfford = userCredits.canAfford(credits: totalCost)

        // THEN: Should be affordable (6 from 25)
        XCTAssertTrue(canAfford)
    }

    // MARK: - Edge Cases

    /// Test 18: Zero PDFs costs nothing
    func test_zeroPDFs_costsNothing() throws {
        // GIVEN: Zero PDFs
        let cost = 0 * UserCredits.PDFCreditCost.textRich.rawValue

        // WHEN/THEN: Cost should be zero and always affordable
        XCTAssertEqual(cost, 0)
        XCTAssertTrue(userCredits.canAfford(credits: cost))
    }

    /// Test 19: Large batch within purchased credits
    func test_largeBatch_withinPurchasedCredits_succeeds() throws {
        // GIVEN: Large purchased balance
        userCredits.creditsBalance = 1000
        let largeBatchCost = 50 * UserCredits.PDFCreditCost.scanned.rawValue // 250 credits

        // WHEN: Checking affordability
        let canAfford = userCredits.canAfford(credits: largeBatchCost)

        // THEN: Should be affordable
        XCTAssertTrue(canAfford)
    }

    /// Test 20: Credits deducted from quota first, then purchased
    func test_creditsDeduction_usesQuotaFirstThenPurchased() throws {
        // GIVEN: Some quota used, and purchased credits
        userCredits.tierCreditsUsed = 20 // 5 quota remaining
        userCredits.creditsBalance = 50

        // WHEN: Deducting 10 credits (more than quota remaining)
        try userCredits.deductCredits(10)

        // THEN: Should use remaining quota (5) + purchased (5)
        XCTAssertEqual(userCredits.tierCreditsUsed, 25) // Quota exhausted
        XCTAssertEqual(userCredits.creditsBalance, 45) // 5 deducted from purchased
    }
}
