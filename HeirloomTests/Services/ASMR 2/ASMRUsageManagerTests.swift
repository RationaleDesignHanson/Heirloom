//
//  ASMRUsageManagerTests.swift
//  HeirloomTests
//
//  Created by Claude on 1/10/26.
//

import Testing
import Foundation
@testable import Heirloom

@Suite("ASMRUsageManager Tests")
struct ASMRUsageManagerTests {

    // MARK: - Mock Subscription Manager

    @MainActor
    class MockSubscriptionManager: SubscriptionManager {
        var hasActiveSubscription: Bool = false

        override init() {
            super.init()
        }
    }

    // MARK: - Test Initialization

    @MainActor
    @Test("Usage manager initializes with correct default values")
    func testInitialization() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = false

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        #expect(sut.creditsUsedThisMonth == 0)
        #expect(sut.creditsRemaining == 5) // Free tier: 5 credits
    }

    // MARK: - Can Start Extraction Tests

    @MainActor
    @Test("Free user with credits can start extraction")
    func testCanStartExtraction_FreeUser_WithCredits() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = false

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        #expect(sut.canStartExtraction() == true)
        #expect(sut.creditsRemaining == 5)
    }

    @MainActor
    @Test("Free user without credits cannot start extraction")
    func testCanStartExtraction_FreeUser_NoCredits() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = false

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        // Use all credits
        try? sut.startExtraction()

        #expect(sut.canStartExtraction() == false)
        #expect(sut.creditsRemaining == 0)
    }

    @MainActor
    @Test("Pro user has higher credit limit")
    func testCanStartExtraction_ProUser() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = true

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        #expect(sut.canStartExtraction() == true)
        #expect(sut.creditsRemaining == 20) // Pro tier: 20 credits
    }

    // MARK: - Start Extraction Tests

    @MainActor
    @Test("Starting extraction deducts credits")
    func testStartExtraction_DeductsCredits() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = false

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        try? sut.startExtraction()

        #expect(sut.creditsUsedThisMonth == 5)
        #expect(sut.creditsRemaining == 0)
    }

    @MainActor
    @Test("Starting extraction without credits throws error")
    func testStartExtraction_InsufficientCredits() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = false

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        // Use all credits
        try? sut.startExtraction()

        // Try to start another extraction
        do {
            try sut.startExtraction()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is ASMRUsageError)
        }
    }

    // MARK: - Refund Tests

    @MainActor
    @Test("Refunding extraction restores credits")
    func testRefundExtraction_RestoresCredits() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = false

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        try? sut.startExtraction()
        sut.refundExtraction()

        #expect(sut.creditsUsedThisMonth == 0)
        #expect(sut.creditsRemaining == 5)
    }

    @MainActor
    @Test("Refunding with no used credits doesn't go negative")
    func testRefundExtraction_NoNegativeCredits() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = false

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        sut.refundExtraction()

        #expect(sut.creditsUsedThisMonth == 0)
        #expect(sut.creditsRemaining == 5)
    }

    // MARK: - Usage Summary Tests

    @MainActor
    @Test("Usage summary returns correct values for free user")
    func testGetUsageSummary_FreeUser() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = false

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        let summary = sut.getUsageSummary()

        #expect(summary.extractionsUsed == 0)
        #expect(summary.extractionsRemaining == 1) // 5 credits = 1 extraction
        #expect(summary.extractionsTotal == 1)
        #expect(summary.creditsUsed == 0)
        #expect(summary.creditsRemaining == 5)
        #expect(summary.isProUser == false)
    }

    @MainActor
    @Test("Usage summary returns correct values for pro user")
    func testGetUsageSummary_ProUser() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = true

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        let summary = sut.getUsageSummary()

        #expect(summary.extractionsUsed == 0)
        #expect(summary.extractionsRemaining == 4) // 20 credits = 4 extractions
        #expect(summary.extractionsTotal == 4)
        #expect(summary.creditsUsed == 0)
        #expect(summary.creditsRemaining == 20)
        #expect(summary.isProUser == true)
    }

    @MainActor
    @Test("Usage summary updates after extraction")
    func testGetUsageSummary_AfterExtraction() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = false

        let sut = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        try? sut.startExtraction()
        let summary = sut.getUsageSummary()

        #expect(summary.extractionsUsed == 1)
        #expect(summary.extractionsRemaining == 0)
        #expect(summary.creditsUsed == 5)
        #expect(summary.creditsRemaining == 0)
    }

    // MARK: - Persistence Tests

    @MainActor
    @Test("Credits persist across instances")
    func testPersistence() {
        let mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        let mockSubManager = MockSubscriptionManager()
        mockSubManager.hasActiveSubscription = false

        // First instance - use credits
        let sut1 = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )
        try? sut1.startExtraction()

        // Second instance - should load persisted state
        let sut2 = ASMRUsageManager(
            subscriptionManager: mockSubManager,
            userDefaults: mockDefaults
        )

        #expect(sut2.creditsUsedThisMonth == 5)
        #expect(sut2.creditsRemaining == 0)
    }

    // MARK: - Teardown

    deinit {
        // Clean up test defaults
        UserDefaults(suiteName: "TestDefaults")?.removePersistentDomain(forName: "TestDefaults")
    }
}
