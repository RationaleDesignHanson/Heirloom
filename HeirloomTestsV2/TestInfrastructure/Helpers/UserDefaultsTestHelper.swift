//
//  UserDefaultsTestHelper.swift
//  HeirloomTestsV2
//
//  Utility for managing UserDefaults state in tests
//  Created: 2026-01-13
//

import Foundation

/// Helper for managing UserDefaults in tests
/// Ensures clean state between tests and provides snapshot/restore capabilities
enum UserDefaultsTestHelper {

    // MARK: - Clean State

    /// Clear all Heirloom-related UserDefaults keys
    /// Use this in setUp() or tearDown() for test isolation
    static func clearAll() {
        clearSubscriptionKeys()
        clearPaywallKeys()
        clearHeritageKeys()
        clearOnboardingKeys()
        clearDebugKeys()
    }

    /// Clear subscription-related keys
    static func clearSubscriptionKeys() {
        let keys = [
            "subscription_status",
            "first_launch_date",
            "trial_expiry_date",
            "subscription_expiry_date",
            "last_subscription_status_refresh",
            "cached_product_id"
        ]
        removeKeys(keys)
    }

    /// Clear paywall-related keys
    static func clearPaywallKeys() {
        let keys = [
            "paywall_first_recipe_trigger_date",
            "paywall_five_recipes_trigger_date",
            "paywall_soft_wall_dismiss_count",
            "paywall_recipe_count",
            "paywall_has_triggered_first_recipe",
            "paywall_has_triggered_five_recipes",
            "paywall_has_triggered_day13"
        ]
        removeKeys(keys)
    }

    /// Clear heritage unlock keys
    static func clearHeritageKeys() {
        let keys = [
            "heritageUnlockedRecipeIds",
            "heritageLastUnlockDate",
            "heritageTrialStartDate"
        ]
        removeKeys(keys)
    }

    /// Clear onboarding keys
    static func clearOnboardingKeys() {
        let keys = [
            "hasCompletedOnboarding"
        ]
        removeKeys(keys)
    }

    /// Clear debug keys
    static func clearDebugKeys() {
        let keys = [
            "debug_force_non_premium",
            "feature_revenuecat_enabled"
        ]
        removeKeys(keys)
    }

    // MARK: - Snapshot & Restore

    private static var snapshot: [String: Any] = [:]

    /// Take a snapshot of current UserDefaults state
    /// Useful for restoring state after a test
    static func takeSnapshot(keys: [String]) {
        snapshot = [:]
        for key in keys {
            if let value = UserDefaults.standard.object(forKey: key) {
                snapshot[key] = value
            }
        }
    }

    /// Restore UserDefaults state from snapshot
    static func restoreSnapshot() {
        for (key, value) in snapshot {
            UserDefaults.standard.set(value, forKey: key)
        }
        snapshot = [:]
    }

    /// Take snapshot of all Heirloom keys
    static func takeFullSnapshot() {
        let allKeys = subscriptionKeys + paywallKeys + heritageKeys + onboardingKeys + debugKeys
        takeSnapshot(keys: allKeys)
    }

    // MARK: - Inspection

    /// Get all set keys (for debugging)
    static func getAllSetKeys() -> [String: Any] {
        var result: [String: Any] = [:]
        let allKeys = subscriptionKeys + paywallKeys + heritageKeys + onboardingKeys + debugKeys

        for key in allKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                result[key] = value
            }
        }

        return result
    }

    /// Print all set keys (for debugging)
    static func printAllSetKeys() {
        let keys = getAllSetKeys()
        print("=== UserDefaults State ===")
        if keys.isEmpty {
            print("(no keys set)")
        } else {
            for (key, value) in keys.sorted(by: { $0.key < $1.key }) {
                print("\(key): \(value)")
            }
        }
        print("========================")
    }

    // MARK: - Private Helpers

    private static func removeKeys(_ keys: [String]) {
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Key Lists

    private static let subscriptionKeys = [
        "subscription_status",
        "first_launch_date",
        "trial_expiry_date",
        "subscription_expiry_date",
        "last_subscription_status_refresh",
        "cached_product_id"
    ]

    private static let paywallKeys = [
        "paywall_first_recipe_trigger_date",
        "paywall_five_recipes_trigger_date",
        "paywall_soft_wall_dismiss_count",
        "paywall_recipe_count",
        "paywall_has_triggered_first_recipe",
        "paywall_has_triggered_five_recipes",
        "paywall_has_triggered_day13"
    ]

    private static let heritageKeys = [
        "heritageUnlockedRecipeIds",
        "heritageLastUnlockDate",
        "heritageTrialStartDate"
    ]

    private static let onboardingKeys = [
        "hasCompletedOnboarding"
    ]

    private static let debugKeys = [
        "debug_force_non_premium",
        "feature_revenuecat_enabled"
    ]
}

// MARK: - XCTestCase Extension

#if canImport(XCTest)
import XCTest

extension XCTestCase {

    /// Set up clean UserDefaults state for test
    /// Call this in setUp()
    func setupCleanUserDefaults() {
        UserDefaultsTestHelper.clearAll()
    }

    /// Tear down and restore UserDefaults
    /// Call this in tearDown()
    func tearDownUserDefaults() {
        UserDefaultsTestHelper.clearAll()
    }

    /// Wrap test with clean UserDefaults (alternative to setUp/tearDown)
    func withCleanUserDefaults(_ test: () throws -> Void) rethrows {
        UserDefaultsTestHelper.clearAll()
        defer { UserDefaultsTestHelper.clearAll() }
        try test()
    }

    /// Wrap async test with clean UserDefaults
    func withCleanUserDefaults(_ test: () async throws -> Void) async rethrows {
        UserDefaultsTestHelper.clearAll()
        defer { UserDefaultsTestHelper.clearAll() }
        try await test()
    }
}
#endif
