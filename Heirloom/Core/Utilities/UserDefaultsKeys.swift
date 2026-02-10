//
//  UserDefaultsKeys.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import Foundation

/// Centralized UserDefaults keys for the entire app
enum UserDefaultsKeys {

    // MARK: - Onboarding

    /// Has user completed the onboarding flow?
    static let hasCompletedOnboarding = "has_completed_onboarding"

    // MARK: - Coach Marks

    /// Has user seen the recipe interaction coach mark?
    static let hasSeenRecipeCoachMark = "has_seen_recipe_coach_mark"

    /// Has user seen the toolbar menu coach mark?
    static let hasSeenToolbarCoachMark = "has_seen_toolbar_coach_mark"

    /// Has user seen the share extension coach mark?
    static let hasSeenShareExtensionCoachMark = "has_seen_share_extension_coach_mark"

    /// Has user seen the card flip nudge animation?
    static let hasSeenCardFlipNudge = "has_seen_card_flip_nudge"

    // MARK: - Subscription & Trial

    /// Current subscription status (raw value of SubscriptionStatus enum)
    static let subscriptionStatus = "subscription_status"

    /// Date of first app launch (used to calculate trial period)
    static let firstLaunchDate = "first_launch_date"

    /// Trial expiry date
    static let trialExpiryDate = "trial_expiry_date"

    /// Subscription expiry date (for monthly/annual plans)
    static let subscriptionExpiryDate = "subscription_expiry_date"

    /// Last time subscription status was refreshed from StoreKit
    static let lastStatusRefresh = "last_subscription_status_refresh"

    /// Cached product ID for current subscription
    static let cachedProductID = "cached_product_id"

    // MARK: - Demo Social

    /// Whether user has locally disabled demo social mode (defaults to false = demo ON)
    static let demoSocialModeDisabled = "demo_social_mode_disabled"

    // MARK: - Screen Recording

    /// Whether to hide theme collections for screen recordings (defaults to false = show)
    static let hideThemeCollections = "hide_theme_collections_for_recording"

    /// Whether to hide user-created demo seed collections for screen recordings (defaults to false = show)
    static let hideDemoSeedCollections = "hide_demo_seed_collections_for_recording"

    // MARK: - Migrations

    /// Version of community recipe ingredient migration that was last run
    static let communityIngredientMigrationVersion = "community_ingredient_migration_version"

    /// Version of source attribution migration that was last run
    static let sourceAttributionMigrationVersion = "source_attribution_migration_version"

    // MARK: - Paywall

    /// Number of times user has dismissed soft-wall paywalls
    static let paywallSoftWallDismissCount = "paywall_soft_wall_dismiss_count"

    /// Date when first recipe paywall was last shown
    static let paywallFirstRecipeTriggerDate = "paywall_first_recipe_trigger_date"

    /// Date when five recipes/day 7 paywall was last shown
    static let paywallFiveRecipesTriggerDate = "paywall_five_recipes_trigger_date"

    /// Total number of recipes added (for paywall triggers)
    static let paywallRecipeCount = "paywall_recipe_count"

    /// Has first recipe paywall been triggered?
    static let paywallHasTriggeredFirstRecipe = "paywall_has_triggered_first_recipe"

    /// Has five recipes/day 7 paywall been triggered?
    static let paywallHasTriggeredFiveRecipes = "paywall_has_triggered_five_recipes"

    /// Has day 13 urgency paywall been triggered?
    static let paywallHasTriggeredDay13 = "paywall_has_triggered_day13"

    // MARK: - Helper Methods

    /// Reset all onboarding-related keys (for testing)
    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: hasCompletedOnboarding)
        UserDefaults.standard.removeObject(forKey: hasSeenRecipeCoachMark)
        UserDefaults.standard.removeObject(forKey: hasSeenToolbarCoachMark)
        UserDefaults.standard.removeObject(forKey: hasSeenShareExtensionCoachMark)
        UserDefaults.standard.removeObject(forKey: hasSeenCardFlipNudge)
    }

    /// Reset all subscription-related keys (for testing)
    static func resetSubscription() {
        UserDefaults.standard.removeObject(forKey: subscriptionStatus)
        UserDefaults.standard.removeObject(forKey: firstLaunchDate)
        UserDefaults.standard.removeObject(forKey: trialExpiryDate)
        UserDefaults.standard.removeObject(forKey: subscriptionExpiryDate)
        UserDefaults.standard.removeObject(forKey: lastStatusRefresh)
        UserDefaults.standard.removeObject(forKey: cachedProductID)
    }

    /// Reset all paywall-related keys (for testing)
    static func resetPaywall() {
        UserDefaults.standard.removeObject(forKey: paywallSoftWallDismissCount)
        UserDefaults.standard.removeObject(forKey: paywallFirstRecipeTriggerDate)
        UserDefaults.standard.removeObject(forKey: paywallFiveRecipesTriggerDate)
        UserDefaults.standard.removeObject(forKey: paywallRecipeCount)
        UserDefaults.standard.removeObject(forKey: paywallHasTriggeredFirstRecipe)
        UserDefaults.standard.removeObject(forKey: paywallHasTriggeredFiveRecipes)
        UserDefaults.standard.removeObject(forKey: paywallHasTriggeredDay13)
    }

    /// Reset demo social settings (for testing)
    static func resetDemoSocial() {
        UserDefaults.standard.removeObject(forKey: demoSocialModeDisabled)
    }

    /// Reset all keys (for complete app reset in testing)
    static func resetAll() {
        resetOnboarding()
        resetSubscription()
        resetPaywall()
        resetDemoSocial()
    }
}
