//
//  PaywallStateBuilder.swift
//  HeirloomTestsV2
//
//  Fluent builder for creating PaywallManager instances in specific states
//  Created: 2026-01-13
//

import Foundation
@testable import Heirloom

/// Builder for creating PaywallManager instances with specific paywall states
///
/// Usage:
/// ```swift
/// let manager = PaywallStateBuilder()
///     .withDismissCount(2)
///     .withCooldownActive(.firstRecipeAdded)
///     .build()
/// ```
@MainActor
final class PaywallStateBuilder {

    // MARK: - Configuration

    private var dismissCount: Int = 0
    private var recipeCount: Int = 0
    private var firstRecipeTriggerDate: Date?
    private var fiveRecipesTriggerDate: Date?
    private var hasTriggeredFirstRecipe: Bool = false
    private var hasTriggeredFiveRecipes: Bool = false
    private var hasTriggeredDay13: Bool = false
    private var trialStateBuilder: TrialStateBuilder?

    // MARK: - Dismiss Count

    /// Set soft wall dismiss count (3 dismissals activate strike rule)
    func withDismissCount(_ count: Int) -> Self {
        self.dismissCount = count
        return self
    }

    /// Set dismiss count to 3 (activates strike rule)
    func withStrikeRuleActive() -> Self {
        self.dismissCount = 3
        return self
    }

    // MARK: - Recipe Count

    /// Set recipe count (affects fiveRecipesOrDay7 trigger)
    func withRecipeCount(_ count: Int) -> Self {
        self.recipeCount = count
        return self
    }

    // MARK: - Cooldown Configuration

    /// Set cooldown as active for a trigger (recently dismissed)
    func withCooldownActive(_ trigger: PaywallTrigger, hoursAgo: Int = 1) -> Self {
        let cooldownDate = Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: Date())!

        switch trigger {
        case .firstRecipeAdded:
            self.firstRecipeTriggerDate = cooldownDate
            self.hasTriggeredFirstRecipe = true
        case .fiveRecipesOrDay7:
            self.fiveRecipesTriggerDate = cooldownDate
            self.hasTriggeredFiveRecipes = true
        case .day13Urgency:
            self.hasTriggeredDay13 = true
        default:
            break
        }

        return self
    }

    /// Set cooldown as expired for a trigger (can trigger again)
    func withCooldownExpired(_ trigger: PaywallTrigger) -> Self {
        let expiredDate = Calendar.current.date(byAdding: .hour, value: -100, to: Date())!

        switch trigger {
        case .firstRecipeAdded:
            self.firstRecipeTriggerDate = expiredDate
            self.hasTriggeredFirstRecipe = true
        case .fiveRecipesOrDay7:
            self.fiveRecipesTriggerDate = expiredDate
            self.hasTriggeredFiveRecipes = true
        default:
            break
        }

        return self
    }

    // MARK: - Trigger History

    /// Mark a trigger as already triggered
    func withTriggeredHistory(_ trigger: PaywallTrigger) -> Self {
        switch trigger {
        case .firstRecipeAdded:
            self.hasTriggeredFirstRecipe = true
        case .fiveRecipesOrDay7:
            self.hasTriggeredFiveRecipes = true
        case .day13Urgency:
            self.hasTriggeredDay13 = true
        default:
            break
        }
        return self
    }

    // MARK: - Subscription State

    /// Configure subscription manager state
    func withSubscriptionState(_ builder: TrialStateBuilder) -> Self {
        self.trialStateBuilder = builder
        return self
    }

    // MARK: - Build

    /// Build PaywallManager with configured state
    func build() -> PaywallManager {
        // Clear any existing state
        clearUserDefaults()

        // Configure dismiss count
        if dismissCount > 0 {
            UserDefaults.standard.set(dismissCount, forKey: "paywall_soft_wall_dismiss_count")
        }

        // Configure recipe count
        if recipeCount > 0 {
            UserDefaults.standard.set(recipeCount, forKey: "paywall_recipe_count")
        }

        // Configure trigger dates
        if let date = firstRecipeTriggerDate {
            UserDefaults.standard.set(date, forKey: "paywall_first_recipe_trigger_date")
        }
        if let date = fiveRecipesTriggerDate {
            UserDefaults.standard.set(date, forKey: "paywall_five_recipes_trigger_date")
        }

        // Configure trigger history
        UserDefaults.standard.set(hasTriggeredFirstRecipe, forKey: "paywall_has_triggered_first_recipe")
        UserDefaults.standard.set(hasTriggeredFiveRecipes, forKey: "paywall_has_triggered_five_recipes")
        UserDefaults.standard.set(hasTriggeredDay13, forKey: "paywall_has_triggered_day13")

        // Create or use provided subscription manager
        let subscriptionManager = trialStateBuilder?.build() ?? TrialStateBuilder.noTrial()

        // Create mock dependencies
        let mockLogger = MockLoggingService()
        // Use real AnalyticsService for tests (falls back to console logging)
        let analytics = AnalyticsService()

        // Create PaywallManager
        let manager = PaywallManager(
            subscriptionManager: subscriptionManager,
            logger: mockLogger,
            analytics: analytics
        )

        return manager
    }

    // MARK: - Cleanup

    /// Clear all paywall-related UserDefaults
    private func clearUserDefaults() {
        let keys = [
            "paywall_first_recipe_trigger_date",
            "paywall_five_recipes_trigger_date",
            "paywall_soft_wall_dismiss_count",
            "paywall_recipe_count",
            "paywall_has_triggered_first_recipe",
            "paywall_has_triggered_five_recipes",
            "paywall_has_triggered_day13"
        ]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - Convenience Presets

extension PaywallStateBuilder {

    /// Fresh state (no dismissals, no triggers)
    static func fresh() -> PaywallManager {
        return PaywallStateBuilder().build()
    }

    /// One dismissal (2 strikes left)
    static func oneDismissal() -> PaywallManager {
        return PaywallStateBuilder()
            .withDismissCount(1)
            .build()
    }

    /// Two dismissals (1 strike left)
    static func twoDismissals() -> PaywallManager {
        return PaywallStateBuilder()
            .withDismissCount(2)
            .build()
    }

    /// Strike rule active (3 dismissals, hard wall enabled)
    static func strikeRuleActive() -> PaywallManager {
        return PaywallStateBuilder()
            .withStrikeRuleActive()
            .build()
    }

    /// First recipe cooldown active (cannot trigger again yet)
    static func firstRecipeCooldown() -> PaywallManager {
        return PaywallStateBuilder()
            .withCooldownActive(.firstRecipeAdded, hoursAgo: 1)
            .build()
    }

    /// First recipe cooldown expired (can trigger again)
    static func firstRecipeCooldownExpired() -> PaywallManager {
        return PaywallStateBuilder()
            .withCooldownExpired(.firstRecipeAdded)
            .build()
    }

    /// Day 7 with 5 recipes (trigger condition met)
    static func day7With5Recipes() -> PaywallManager {
        return PaywallStateBuilder()
            .withRecipeCount(5)
            .withSubscriptionState(TrialStateBuilder().withDaysIntoTrial(7))
            .build()
    }
}
