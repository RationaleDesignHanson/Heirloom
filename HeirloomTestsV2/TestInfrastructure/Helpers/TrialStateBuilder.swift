//
//  TrialStateBuilder.swift
//  HeirloomTestsV2
//
//  Fluent builder for creating SubscriptionManager instances in specific trial states
//  Created: 2026-01-13
//

import Foundation
@testable import Heirloom

/// Builder for creating SubscriptionManager instances with specific trial states
///
/// Usage:
/// ```swift
/// let manager = TrialStateBuilder()
///     .withDaysIntoTrial(7)
///     .build()
/// ```
@MainActor
final class TrialStateBuilder {

    // MARK: - Configuration

    private var trialDaysElapsed: Int = 0
    private var hasExistingTrial: Bool = true
    private var productID: ProductIdentifier?
    private var forceNonPremium: Bool = false

    // MARK: - Trial Configuration

    /// Set trial to a specific day (0 = just started, 14 = last day, 15+ = expired)
    func withDaysIntoTrial(_ days: Int) -> Self {
        self.trialDaysElapsed = days
        self.hasExistingTrial = true
        return self
    }

    /// Set trial as expired (equivalent to day 15+)
    func withExpiredTrial() -> Self {
        self.trialDaysElapsed = 15
        self.hasExistingTrial = true
        return self
    }

    /// Set no existing trial (never started)
    func withNoExistingTrial() -> Self {
        self.hasExistingTrial = false
        self.trialDaysElapsed = 0
        return self
    }

    /// Set active subscription (bypasses trial)
    func withActiveSubscription(_ product: ProductIdentifier) -> Self {
        self.productID = product
        return self
    }

    /// Force non-premium state (for testing debug flags)
    func withDebugForceNonPremium(_ enabled: Bool = true) -> Self {
        self.forceNonPremium = enabled
        return self
    }

    // MARK: - Build

    /// Build SubscriptionManager with configured state
    /// - Returns: Configured SubscriptionManager instance
    func build() -> SubscriptionManager {
        // Clear any existing state
        clearUserDefaults()

        // Configure debug flag
        if forceNonPremium {
            UserDefaults.standard.set(true, forKey: "debug_force_non_premium")
        }

        // Configure trial state
        if hasExistingTrial {
            let trialStartDate = Calendar.current.date(byAdding: .day, value: -trialDaysElapsed, to: Date())!
            let trialExpiryDate = Calendar.current.date(byAdding: .day, value: 14 - trialDaysElapsed, to: Date())!

            UserDefaults.standard.set(trialExpiryDate, forKey: "trial_expiry_date")
            UserDefaults.standard.set(trialStartDate, forKey: "first_launch_date")
        }

        // Configure subscription state
        if let productID = productID {
            UserDefaults.standard.set(productID.rawValue, forKey: "cached_product_id")

            // Set expiry far in the future for active subscription
            let expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
            UserDefaults.standard.set(expiryDate, forKey: "subscription_expiry_date")
            UserDefaults.standard.set("monthly", forKey: "subscription_status") // Will be overridden by manager
        }

        // Create dependencies
        let mockLogger = MockLoggingService()
        let analytics = AnalyticsService()
        // Note: Using real StoreManager since it's final and can't be mocked
        // It won't actually make purchases in tests
        let storeManager = StoreManager(logger: mockLogger, analytics: analytics)

        // Simulate subscription state via UserDefaults if needed
        if let productID = productID {
            UserDefaults.standard.set(productID.rawValue, forKey: "subscription_current_product_id")
            // Set subscription status based on product type
            let status: String = productID == .lifetime ? "lifetime" : productID.rawValue
            UserDefaults.standard.set(status, forKey: "subscription_status")
        }

        // Create SubscriptionManager
        let manager = SubscriptionManager(
            storeManager: storeManager,
            logger: mockLogger,
            analytics: analytics
        )

        return manager
    }

    // MARK: - Cleanup

    /// Clear all subscription-related UserDefaults
    private func clearUserDefaults() {
        let keys = [
            "subscription_status",
            "first_launch_date",
            "trial_expiry_date",
            "subscription_expiry_date",
            "last_subscription_status_refresh",
            "cached_product_id",
            "debug_force_non_premium"
        ]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - Convenience Presets

extension TrialStateBuilder {

    /// Day 1 of trial (14 days remaining)
    static func day1() -> SubscriptionManager {
        return TrialStateBuilder()
            .withDaysIntoTrial(0)
            .build()
    }

    /// Day 7 of trial (soft wall trigger point)
    static func day7() -> SubscriptionManager {
        return TrialStateBuilder()
            .withDaysIntoTrial(7)
            .build()
    }

    /// Day 13 of trial (urgency wall trigger point)
    static func day13() -> SubscriptionManager {
        return TrialStateBuilder()
            .withDaysIntoTrial(13)
            .build()
    }

    /// Day 14 of trial (last day)
    static func day14() -> SubscriptionManager {
        return TrialStateBuilder()
            .withDaysIntoTrial(14)
            .build()
    }

    /// Expired trial (day 15+)
    static func expired() -> SubscriptionManager {
        return TrialStateBuilder()
            .withExpiredTrial()
            .build()
    }

    /// No trial started
    static func noTrial() -> SubscriptionManager {
        return TrialStateBuilder()
            .withNoExistingTrial()
            .build()
    }

    /// Active monthly subscription
    static func monthly() -> SubscriptionManager {
        return TrialStateBuilder()
            .withActiveSubscription(.monthly)
            .build()
    }

    /// Active annual subscription
    static func annual() -> SubscriptionManager {
        return TrialStateBuilder()
            .withActiveSubscription(.annual)
            .build()
    }

    /// Lifetime purchase
    static func lifetime() -> SubscriptionManager {
        return TrialStateBuilder()
            .withActiveSubscription(.lifetime)
            .build()
    }
}
