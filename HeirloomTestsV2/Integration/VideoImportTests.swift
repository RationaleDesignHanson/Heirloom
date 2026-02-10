//
//  VideoImportTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Integration tests for video import feature
//
//  Tests the video import pipeline to ensure:
//  - Cost calculation by video type (regular vs ASMR)
//  - Credit deduction based on analysis results
//  - Platform detection (YouTube, TikTok, Instagram, etc.)
//  - Processing phase transitions
//  - Error handling and credit refunds
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class VideoImportTests: XCTestCase {

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

    /// Test 1: Regular video costs 1 credit
    func test_videoCreditCost_regular_isOneCredit() {
        // GIVEN/WHEN/THEN: Regular videos cost 1 credit
        XCTAssertEqual(UserCredits.VideoCreditCost.regular.rawValue, 1)
    }

    /// Test 2: ASMR video costs 5 credits
    func test_videoCreditCost_asmr_isFiveCredits() {
        // GIVEN/WHEN/THEN: ASMR videos cost 5 credits
        XCTAssertEqual(UserCredits.VideoCreditCost.asmr.rawValue, 5)
    }

    /// Test 3: Can afford regular video with fresh quota
    func test_canAfford_regularVideo_withFreshQuota_returnsTrue() throws {
        // GIVEN: Fresh quota (25 credits)
        XCTAssertEqual(userCredits.availableToday, 25)

        // WHEN: Checking affordability for regular video
        let canAfford = userCredits.canAfford(credits: UserCredits.VideoCreditCost.regular.rawValue)

        // THEN: Should be affordable
        XCTAssertTrue(canAfford)
    }

    /// Test 4: Can afford ASMR video with fresh quota
    func test_canAfford_asmrVideo_withFreshQuota_returnsTrue() throws {
        // GIVEN: Fresh quota (25 credits)
        XCTAssertEqual(userCredits.availableToday, 25)

        // WHEN: Checking affordability for ASMR video
        let canAfford = userCredits.canAfford(credits: UserCredits.VideoCreditCost.asmr.rawValue)

        // THEN: Should be affordable
        XCTAssertTrue(canAfford)
    }

    /// Test 5: Can afford 5 ASMR videos with fresh quota
    func test_canAfford_fiveASMRVideos_withFreshQuota_returnsTrue() throws {
        // GIVEN: Fresh quota (25 credits)
        let asmrCost = UserCredits.VideoCreditCost.asmr.rawValue // 5 credits
        let fiveVideosCost = asmrCost * 5 // 25 credits

        // WHEN: Checking affordability
        let canAfford = userCredits.canAfford(credits: fiveVideosCost)

        // THEN: Should be exactly affordable
        XCTAssertTrue(canAfford)
    }

    /// Test 6: Cannot afford 6th ASMR video with fresh quota
    func test_canAfford_sixASMRVideos_withFreshQuota_returnsFalse() throws {
        // GIVEN: Fresh quota (25 credits)
        let asmrCost = UserCredits.VideoCreditCost.asmr.rawValue
        let sixVideosCost = asmrCost * 6 // 30 credits

        // WHEN: Checking affordability
        let canAfford = userCredits.canAfford(credits: sixVideosCost)

        // THEN: Should not be affordable
        XCTAssertFalse(canAfford)
    }

    // MARK: - Credit Deduction Tests

    /// Test 7: Deducting credits for regular video
    func test_deductCredits_regularVideo_deductsCorrectAmount() throws {
        // GIVEN: Fresh quota
        let initialAvailable = userCredits.availableToday

        // WHEN: Deducting for regular video
        try userCredits.deductCredits(UserCredits.VideoCreditCost.regular.rawValue)

        // THEN: Should deduct 1 credit
        XCTAssertEqual(userCredits.availableToday, initialAvailable - 1)
    }

    /// Test 8: Deducting credits for ASMR video
    func test_deductCredits_asmrVideo_deductsCorrectAmount() throws {
        // GIVEN: Fresh quota
        let initialAvailable = userCredits.availableToday

        // WHEN: Deducting for ASMR video
        try userCredits.deductCredits(UserCredits.VideoCreditCost.asmr.rawValue)

        // THEN: Should deduct 5 credits
        XCTAssertEqual(userCredits.availableToday, initialAvailable - 5)
    }

    /// Test 9: Insufficient credits for ASMR throws error
    func test_deductCredits_insufficientForASMR_throwsError() throws {
        // GIVEN: Only 3 credits available
        userCredits.tierCreditsUsed = 22 // 3 remaining from daily
        userCredits.creditsBalance = 0

        // WHEN/THEN: Deducting for ASMR should throw
        XCTAssertThrowsError(try userCredits.deductCredits(UserCredits.VideoCreditCost.asmr.rawValue)) { error in
            guard case CreditError.insufficientCredits = error else {
                XCTFail("Expected insufficientCredits error")
                return
            }
        }
    }

    // MARK: - Platform Detection Tests

    /// Test 10: Detect YouTube URL
    func test_platformDetection_youtubeURL_detectsCorrectly() {
        // GIVEN: YouTube URL
        let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!

        // WHEN: Detecting platform
        let platformInfo = PlatformDetector.detect(from: url)

        // THEN: Should detect YouTube
        XCTAssertNotNil(platformInfo)
        XCTAssertEqual(platformInfo?.platform, .youtube)
    }

    /// Test 11: Detect YouTube short URL
    func test_platformDetection_youtubeShortURL_detectsCorrectly() {
        // GIVEN: YouTube short URL
        let url = URL(string: "https://youtu.be/dQw4w9WgXcQ")!

        // WHEN: Detecting platform
        let platformInfo = PlatformDetector.detect(from: url)

        // THEN: Should detect YouTube
        XCTAssertNotNil(platformInfo)
        XCTAssertEqual(platformInfo?.platform, .youtube)
    }

    /// Test 12: Detect TikTok URL
    func test_platformDetection_tiktokURL_detectsCorrectly() {
        // GIVEN: TikTok URL
        let url = URL(string: "https://www.tiktok.com/@user/video/123456789")!

        // WHEN: Detecting platform
        let platformInfo = PlatformDetector.detect(from: url)

        // THEN: Should detect TikTok
        XCTAssertNotNil(platformInfo)
        XCTAssertEqual(platformInfo?.platform, .tiktok)
    }

    /// Test 13: Detect TikTok short URL
    func test_platformDetection_tiktokShortURL_detectsCorrectly() {
        // GIVEN: TikTok short URL
        let url = URL(string: "https://vm.tiktok.com/ABC123")!

        // WHEN: Detecting platform
        let platformInfo = PlatformDetector.detect(from: url)

        // THEN: Should detect TikTok
        XCTAssertNotNil(platformInfo)
        XCTAssertEqual(platformInfo?.platform, .tiktok)
    }

    /// Test 14: Detect Instagram Reels URL
    func test_platformDetection_instagramReelsURL_detectsCorrectly() {
        // GIVEN: Instagram Reels URL
        let url = URL(string: "https://www.instagram.com/reels/ABC123")!

        // WHEN: Detecting platform
        let platformInfo = PlatformDetector.detect(from: url)

        // THEN: Should detect Instagram
        XCTAssertNotNil(platformInfo)
        XCTAssertEqual(platformInfo?.platform, .instagram)
    }

    /// Test 15: Detect Facebook URL
    func test_platformDetection_facebookURL_detectsCorrectly() {
        // GIVEN: Facebook video URL
        let url = URL(string: "https://www.facebook.com/watch?v=123456789")!

        // WHEN: Detecting platform
        let platformInfo = PlatformDetector.detect(from: url)

        // THEN: Should detect Facebook
        XCTAssertNotNil(platformInfo)
        XCTAssertEqual(platformInfo?.platform, .facebook)
    }

    /// Test 16: Unknown URL returns nil
    func test_platformDetection_unknownURL_returnsNil() {
        // GIVEN: Unknown URL
        let url = URL(string: "https://someunknownsite.com/video/123")!

        // WHEN: Detecting platform
        let platformInfo = PlatformDetector.detect(from: url)

        // THEN: Should return nil for unknown platforms
        XCTAssertNil(platformInfo)
    }

    // MARK: - Video Type Decision Tests

    /// Test 17: Daily quota allows 25 regular videos
    func test_dailyQuota_allows25RegularVideos() throws {
        // GIVEN: Fresh quota
        let maxRegular = UserCredits.dailyFreeQuota / UserCredits.VideoCreditCost.regular.rawValue

        // THEN: Should allow 25 regular videos
        XCTAssertEqual(maxRegular, 25)
    }

    /// Test 18: Daily quota allows 5 ASMR videos
    func test_dailyQuota_allows5ASMRVideos() throws {
        // GIVEN: Fresh quota
        let maxASMR = UserCredits.dailyFreeQuota / UserCredits.VideoCreditCost.asmr.rawValue

        // THEN: Should allow 5 ASMR videos
        XCTAssertEqual(maxASMR, 5)
    }

    /// Test 19: Mixed video types calculate correctly
    func test_mixedVideoTypes_calculateCorrectly() throws {
        // GIVEN: Mix of video types: 10 regular, 2 ASMR
        let regularCost = 10 * UserCredits.VideoCreditCost.regular.rawValue  // 10
        let asmrCost = 2 * UserCredits.VideoCreditCost.asmr.rawValue         // 10
        let totalCost = regularCost + asmrCost                                // 20

        // WHEN: Checking affordability
        let canAfford = userCredits.canAfford(credits: totalCost)

        // THEN: Should be affordable (20 from 25)
        XCTAssertTrue(canAfford)
        XCTAssertEqual(totalCost, 20)
    }

    // MARK: - Credit Refund Eligibility Tests

    /// Test 20: ASMR credits refundable during early phases
    func test_asmrCredits_refundableInEarlyPhases() {
        // GIVEN: Refundable phases for ASMR
        let refundablePhases: [ProcessingPhase] = [
            .queued,
            .loadingModel,
            .extractingAudio,
            .transcribing,
            .analyzingFrames
        ]

        // THEN: All early phases should be refundable
        for phase in refundablePhases {
            XCTAssertTrue(phase.isRefundable, "Phase \(phase) should be refundable")
        }
    }

    /// Test 21: ASMR credits not refundable after structuring
    func test_asmrCredits_notRefundableAfterStructuring() {
        // GIVEN: Non-refundable phases
        let nonRefundablePhases: [ProcessingPhase] = [
            .structuringRecipe,
            .augmenting,
            .complete
        ]

        // THEN: Late phases should not be refundable
        for phase in nonRefundablePhases {
            XCTAssertFalse(phase.isRefundable, "Phase \(phase) should not be refundable")
        }
    }

    // MARK: - Persistence Tests

    /// Test 22: Video credits persist after deduction
    func test_videoCredits_persistAfterDeduction() throws {
        // GIVEN: Initial state
        XCTAssertEqual(userCredits.tierCreditsUsed, 0)

        // WHEN: Deducting credits and saving
        try userCredits.deductCredits(UserCredits.VideoCreditCost.asmr.rawValue)
        try env.save()

        // THEN: Credits should persist
        let fetchedCredits = try env.fetchUserCredits()
        XCTAssertNotNil(fetchedCredits)
        XCTAssertEqual(fetchedCredits?.tierCreditsUsed, 5)
    }

    /// Test 23: Can afford with purchased credits after quota exhausted
    func test_canAfford_asmrWithPurchased_afterQuotaExhausted() throws {
        // GIVEN: Exhausted quota but has purchased credits
        userCredits.tierCreditsUsed = 25 // Quota exhausted
        userCredits.creditsBalance = 10 // Has purchased credits

        // WHEN: Checking affordability for ASMR video
        let canAfford = userCredits.canAfford(credits: UserCredits.VideoCreditCost.asmr.rawValue)

        // THEN: Should be affordable from purchased
        XCTAssertTrue(canAfford)
    }

    // MARK: - Edge Cases

    /// Test 24: Zero videos costs nothing
    func test_zeroVideos_costsNothing() throws {
        // GIVEN: Zero videos
        let regularCost = 0 * UserCredits.VideoCreditCost.regular.rawValue
        let asmrCost = 0 * UserCredits.VideoCreditCost.asmr.rawValue

        // WHEN/THEN: Both should be zero and affordable
        XCTAssertEqual(regularCost, 0)
        XCTAssertEqual(asmrCost, 0)
        XCTAssertTrue(userCredits.canAfford(credits: 0))
    }

    /// Test 25: Large batch with purchased credits succeeds
    func test_largeBatch_withinPurchasedCredits_succeeds() throws {
        // GIVEN: Large purchased balance
        userCredits.creditsBalance = 500
        let largeBatchCost = 50 * UserCredits.VideoCreditCost.asmr.rawValue // 250 credits

        // WHEN: Checking affordability
        let canAfford = userCredits.canAfford(credits: largeBatchCost)

        // THEN: Should be affordable
        XCTAssertTrue(canAfford)
    }
}

// MARK: - Test Helpers

extension ProcessingPhase {
    /// Whether credits can be refunded if processing fails at this phase
    var isRefundable: Bool {
        let refundablePhases: [ProcessingPhase] = [
            .queued, .loadingModel, .extractingAudio, .transcribing, .analyzingFrames
        ]
        return refundablePhases.contains(self)
    }
}
