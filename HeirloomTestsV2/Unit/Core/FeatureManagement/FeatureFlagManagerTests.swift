//
//  FeatureFlagManagerTests.swift
//  HeirloomTestsV2
//
//  Tests for FeatureFlagManager: flag resolution, overrides, precedence
//  Created: 2026-01-13
//

import XCTest
@testable import Heirloom

@MainActor
final class FeatureFlagManagerTests: XCTestCase {

    var sut: FeatureFlagManager!
    var userDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()

        // Create isolated UserDefaults for testing
        userDefaults = UserDefaults(suiteName: "test.feature.flags")!
        userDefaults.removePersistentDomain(forName: "test.feature.flags")

        let localProvider = LocalFeatureFlagProvider(userDefaults: userDefaults)
        sut = FeatureFlagManager(localProvider: localProvider, remoteProvider: nil)
    }

    override func tearDown() async throws {
        userDefaults.removePersistentDomain(forName: "test.feature.flags")
        userDefaults = nil
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Default Behavior Tests

    func test_allFeatures_enabledByDefault() {
        // Given: Fresh FeatureFlagManager with no overrides

        // When: Check all features
        for feature in Feature.allCases {
            let isEnabled = sut.isEnabled(feature)

            // Then: All features should be enabled by default
            XCTAssertTrue(isEnabled, "Feature \(feature.rawValue) should be enabled by default")
        }
    }

    func test_isAvailable_premiumFeature_requiresSubscription() {
        // Given: Feature that requires premium
        let feature = Feature.videoImport
        XCTAssertTrue(feature.requiresPremium, "Video import should require premium")

        // And: Non-premium subscription manager
        let subscriptionManager = TrialStateBuilder().withExpiredTrial().build()
        XCTAssertFalse(subscriptionManager.isPremium, "Should not be premium")

        // When: Check if feature is available
        let isAvailable = sut.isAvailable(feature, subscriptionManager: subscriptionManager)

        // Then: Feature should not be available (requires premium)
        XCTAssertFalse(isAvailable, "Premium feature should not be available without subscription")
    }

    func test_isAvailable_premiumFeature_allowedWithSubscription() {
        // Given: Feature that requires premium
        let feature = Feature.cloudSync
        XCTAssertTrue(feature.requiresPremium, "Cloud sync should require premium")

        // And: Premium subscription manager
        let subscriptionManager = TrialStateBuilder().withActiveSubscription(.monthly).build()
        XCTAssertTrue(subscriptionManager.isPremium, "Should be premium")

        // When: Check if feature is available
        let isAvailable = sut.isAvailable(feature, subscriptionManager: subscriptionManager)

        // Then: Feature should be available (has premium)
        XCTAssertTrue(isAvailable, "Premium feature should be available with subscription")
    }

    func test_isAvailable_nonPremiumFeature_alwaysAvailable() {
        // Given: Feature that doesn't require premium
        let feature = Feature.collections
        XCTAssertFalse(feature.requiresPremium, "Collections should not require premium")

        // And: Non-premium subscription manager
        let subscriptionManager = TrialStateBuilder().withExpiredTrial().build()
        XCTAssertFalse(subscriptionManager.isPremium, "Should not be premium")

        // When: Check if feature is available
        let isAvailable = sut.isAvailable(feature, subscriptionManager: subscriptionManager)

        // Then: Feature should be available (doesn't require premium)
        XCTAssertTrue(isAvailable, "Non-premium feature should always be available")
    }

    // MARK: - Local Override Tests

    func test_setLocalOverride_disablesFeature() {
        // Given: Feature enabled by default
        let feature = Feature.videoImport
        XCTAssertTrue(sut.isEnabled(feature), "Should be enabled by default")

        // When: Set local override to disable
        sut.setLocalOverride(feature, enabled: false)

        // Then: Feature should be disabled
        XCTAssertFalse(sut.isEnabled(feature), "Should be disabled after override")
    }

    func test_setLocalOverride_enablesFeature() {
        // Given: Feature disabled via override
        let feature = Feature.videoImport
        sut.setLocalOverride(feature, enabled: false)
        XCTAssertFalse(sut.isEnabled(feature), "Should be disabled")

        // When: Set local override to enable
        sut.setLocalOverride(feature, enabled: true)

        // Then: Feature should be enabled
        XCTAssertTrue(sut.isEnabled(feature), "Should be enabled after override")
    }

    func test_clearLocalOverride_restoresDefault() {
        // Given: Feature disabled via override
        let feature = Feature.collections
        sut.setLocalOverride(feature, enabled: false)
        XCTAssertFalse(sut.isEnabled(feature), "Should be disabled")

        // When: Clear override
        sut.clearLocalOverride(feature)

        // Then: Feature should return to default (enabled)
        XCTAssertTrue(sut.isEnabled(feature), "Should return to default (enabled)")
    }

    func test_clearAllLocalOverrides_restoresAllDefaults() {
        // Given: Multiple features with overrides
        sut.setLocalOverride(.videoImport, enabled: false)
        sut.setLocalOverride(.cloudSync, enabled: false)
        sut.setLocalOverride(.collections, enabled: false)

        XCTAssertFalse(sut.isEnabled(.videoImport))
        XCTAssertFalse(sut.isEnabled(.cloudSync))
        XCTAssertFalse(sut.isEnabled(.collections))

        // When: Clear all overrides
        sut.clearAllLocalOverrides()

        // Then: All features should return to default (enabled)
        XCTAssertTrue(sut.isEnabled(.videoImport), "Video import should be enabled")
        XCTAssertTrue(sut.isEnabled(.cloudSync), "Cloud sync should be enabled")
        XCTAssertTrue(sut.isEnabled(.collections), "Collections should be enabled")
    }

    func test_localOverride_returnsCurrentOverrideValue() {
        // Given: Feature with no override
        let feature = Feature.tags
        XCTAssertNil(sut.localOverride(for: feature), "Should have no override initially")

        // When: Set override to false
        sut.setLocalOverride(feature, enabled: false)

        // Then: Local override should return false
        XCTAssertEqual(sut.localOverride(for: feature), false, "Should return false override")

        // When: Set override to true
        sut.setLocalOverride(feature, enabled: true)

        // Then: Local override should return true
        XCTAssertEqual(sut.localOverride(for: feature), true, "Should return true override")
    }

    // MARK: - Precedence Tests

    func test_precedence_localOverride_overridesDefault() {
        // Given: Feature enabled by default
        let feature = Feature.scaling
        XCTAssertTrue(sut.isEnabled(feature), "Should be enabled by default")

        // When: Set local override to false
        sut.setLocalOverride(feature, enabled: false)

        // Then: Local override should take precedence
        XCTAssertFalse(sut.isEnabled(feature), "Local override should take precedence over default")
    }

    // MARK: - Persistence Tests

    func test_localOverrides_persistAcrossInstances() {
        // Given: Feature disabled via override
        let feature = Feature.recipeSharing
        sut.setLocalOverride(feature, enabled: false)
        XCTAssertFalse(sut.isEnabled(feature), "Should be disabled")

        // When: Create new FeatureFlagManager instance with same UserDefaults
        let localProvider = LocalFeatureFlagProvider(userDefaults: userDefaults)
        let newManager = FeatureFlagManager(localProvider: localProvider, remoteProvider: nil)

        // Then: Override should persist
        XCTAssertFalse(newManager.isEnabled(feature), "Override should persist across instances")
    }

    // MARK: - Feature Metadata Tests

    func test_featureMetadata_displayName() {
        // Check a few display names
        XCTAssertEqual(Feature.videoImport.displayName, "Video Import")
        XCTAssertEqual(Feature.premiumSubscription.displayName, "Premium Subscription")
        XCTAssertEqual(Feature.collections.displayName, "Collections")
    }

    func test_featureMetadata_requiresPremium() {
        // Premium features
        XCTAssertTrue(Feature.videoImport.requiresPremium)
        XCTAssertTrue(Feature.asmrProcessing.requiresPremium)
        XCTAssertTrue(Feature.cloudSync.requiresPremium)
        XCTAssertTrue(Feature.cookbookScan.requiresPremium)

        // Non-premium features
        XCTAssertFalse(Feature.collections.requiresPremium)
        XCTAssertFalse(Feature.tags.requiresPremium)
        XCTAssertFalse(Feature.scaling.requiresPremium)
    }

    func test_featureMetadata_category() {
        // Core features
        XCTAssertEqual(Feature.recipeManagement.category, .core)
        XCTAssertEqual(Feature.collections.category, .core)

        // Premium features
        XCTAssertEqual(Feature.videoImport.category, .premium)
        XCTAssertEqual(Feature.cloudSync.category, .premium)

        // Heritage features
        XCTAssertEqual(Feature.blindBoxCollections.category, .heritage)
        XCTAssertEqual(Feature.dailyHeritageDrop.category, .heritage)

        // Social features
        XCTAssertEqual(Feature.recipeSharing.category, .social)
        XCTAssertEqual(Feature.discovery.category, .social)
    }

    // MARK: - Edge Cases

    func test_rapidToggle_handlesCorrectly() {
        // Given: Feature
        let feature = Feature.dinnerParty

        // When: Rapidly toggle 10 times
        for i in 0..<10 {
            let shouldEnable = i % 2 == 0
            sut.setLocalOverride(feature, enabled: shouldEnable)
        }

        // Then: Final state should be disabled (10th toggle)
        XCTAssertFalse(sut.isEnabled(feature), "Should be disabled after 10 toggles")
    }

    func test_multipleFeatures_independentOverrides() {
        // Given: Multiple features
        let feature1 = Feature.videoImport
        let feature2 = Feature.cloudSync
        let feature3 = Feature.collections

        // When: Set different overrides
        sut.setLocalOverride(feature1, enabled: false)
        sut.setLocalOverride(feature2, enabled: true)
        // feature3 has no override

        // Then: Each feature should have independent state
        XCTAssertFalse(sut.isEnabled(feature1), "Feature 1 should be disabled")
        XCTAssertTrue(sut.isEnabled(feature2), "Feature 2 should be enabled")
        XCTAssertTrue(sut.isEnabled(feature3), "Feature 3 should be default (enabled)")
    }
}
