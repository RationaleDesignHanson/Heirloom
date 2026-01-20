//
//  PaywallManager.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import Foundation
import SwiftUI
import Observation

/// Paywall trigger types
enum PaywallTrigger {
    case firstRecipeAdded           // After 1st recipe (48hr cooldown)
    case fiveRecipesOrDay7          // After 5 recipes OR day 7 (72hr cooldown)
    case day13Urgency               // Day 13 urgency nudge (no cooldown)
    case urlImport                  // Hard wall - URL import feature
    case cookbookScan               // Hard wall - cookbook scan feature
    case sync                       // Hard wall - sync feature
    case largePDFImport(pageCount: Int)  // Hard wall - PDF import 50+ pages
    case visualVideoExtraction      // Hard wall - visual/ASMR video extraction

    var displayName: String {
        switch self {
        case .firstRecipeAdded: return "First Recipe"
        case .fiveRecipesOrDay7: return "5 Recipes or Day 7"
        case .day13Urgency: return "Day 13 Urgency"
        case .urlImport: return "URL Import"
        case .cookbookScan: return "Cookbook Scan"
        case .sync: return "Sync"
        case .largePDFImport: return "Large PDF Import"
        case .visualVideoExtraction: return "Visual Video Extraction"
        }
    }

    var isSoftWall: Bool {
        switch self {
        case .firstRecipeAdded, .fiveRecipesOrDay7, .day13Urgency:
            return true
        case .urlImport, .cookbookScan, .sync, .largePDFImport, .visualVideoExtraction:
            return false
        }
    }

    var cooldownHours: Int? {
        switch self {
        case .firstRecipeAdded: return 48
        case .fiveRecipesOrDay7: return 72
        case .day13Urgency, .urlImport, .cookbookScan, .sync, .largePDFImport, .visualVideoExtraction: return nil
        }
    }
}

@MainActor
@Observable
final class PaywallManager {

    // MARK: - Published State

    /// Should paywall be shown?
    private(set) var shouldShowPaywall = false

    /// Current trigger for paywall
    private(set) var currentTrigger: PaywallTrigger?

    /// Number of soft-wall dismissals
    private(set) var softWallDismissCount = 0

    /// Has 3-strike rule been triggered?
    private(set) var isStrikeRuleActive = false

    // MARK: - Dependencies

    private let subscriptionManager: SubscriptionManager
    private let logger: LoggingService
    private let analytics: AnalyticsService

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let firstRecipeTriggerDate = "paywall_first_recipe_trigger_date"
        static let fiveRecipesTriggerDate = "paywall_five_recipes_trigger_date"
        static let softWallDismissCount = "paywall_soft_wall_dismiss_count"
        static let recipeCount = "paywall_recipe_count"
        static let firstLaunchDate = "first_launch_date" // Shared with SubscriptionManager
        static let hasTriggeredFirstRecipe = "paywall_has_triggered_first_recipe"
        static let hasTriggeredFiveRecipes = "paywall_has_triggered_five_recipes"
        static let hasTriggeredDay13 = "paywall_has_triggered_day13"
    }

    // MARK: - Initialization

    init(subscriptionManager: SubscriptionManager, logger: LoggingService, analytics: AnalyticsService) {
        self.subscriptionManager = subscriptionManager
        self.logger = logger
        self.analytics = analytics

        // Load persisted state
        loadState()

        logger.log("PaywallManager initialized", category: .store, level: .info, metadata: nil)
    }

    // MARK: - Trigger Evaluation

    /// Evaluate if paywall should be shown for a given trigger
    /// - Parameter trigger: Trigger to evaluate
    /// - Returns: true if paywall should be shown
    func shouldShow(for trigger: PaywallTrigger) -> Bool {
        // Premium users never see paywall
        if subscriptionManager.isPremium {
            return false
        }

        // Hard walls always show (unless 3-strike rule active)
        if !trigger.isSoftWall {
            if isStrikeRuleActive {
                logger.log(
                    "Hard wall blocked by 3-strike rule",
                    category: .store,
                    level: .debug,
                    metadata: nil
                )
                return false
            }
            return true
        }

        // Soft walls respect 3-strike rule
        if isStrikeRuleActive {
            logger.log(
                "Soft wall blocked by 3-strike rule",
                category: .store,
                level: .debug,
                metadata: nil
            )
            return false
        }

        // Check cooldown for soft walls
        if trigger.cooldownHours != nil {
            if !isCooldownExpired(for: trigger) {
                logger.log(
                    "Paywall on cooldown for \(trigger.displayName)",
                    category: .store,
                    level: .debug,
                    metadata: nil
                )
                return false
            }
        }

        // Check trigger-specific conditions
        switch trigger {
        case .firstRecipeAdded:
            return canTriggerFirstRecipe()

        case .fiveRecipesOrDay7:
            return canTriggerFiveRecipesOrDay7()

        case .day13Urgency:
            return canTriggerDay13()

        case .urlImport, .cookbookScan, .sync, .largePDFImport:
            return true // Hard walls always pass
        }
    }

    /// Show paywall for a specific trigger
    func show(for trigger: PaywallTrigger) {
        guard shouldShow(for: trigger) else {
            return
        }

        currentTrigger = trigger
        shouldShowPaywall = true

        // Mark trigger as shown
        markTriggerShown(trigger)

        logger.log(
            "Showing paywall: \(trigger.displayName)",
            category: .store,
            level: .info,
            metadata: nil
        )

        analytics.track(event: .paywallShown, properties: [
            "trigger": trigger.displayName,
            "is_soft_wall": trigger.isSoftWall,
            "dismiss_count": softWallDismissCount
        ])
    }

    /// Dismiss paywall
    func dismiss() {
        guard let trigger = currentTrigger else { return }

        // Increment dismiss count for soft walls
        if trigger.isSoftWall {
            softWallDismissCount += 1
            UserDefaults.standard.set(softWallDismissCount, forKey: Keys.softWallDismissCount)

            // Check 3-strike rule
            if softWallDismissCount >= 3 {
                isStrikeRuleActive = true

                logger.log(
                    "3-strike rule activated",
                    category: .store,
                    level: .info,
                    metadata: nil
                )

                analytics.track(event: .paywallStrikeRuleActivated)
            }
        }

        shouldShowPaywall = false
        currentTrigger = nil

        logger.log(
            "Paywall dismissed: \(trigger.displayName) (count: \(softWallDismissCount))",
            category: .store,
            level: .info,
            metadata: nil
        )

        analytics.track(event: .paywallDismissed, properties: [
            "trigger": trigger.displayName,
            "dismiss_count": softWallDismissCount,
            "strike_rule_active": isStrikeRuleActive
        ])
    }

    // MARK: - Recipe Tracking

    /// Track recipe addition
    func trackRecipeAdded() {
        let currentCount = UserDefaults.standard.integer(forKey: Keys.recipeCount)
        let newCount = currentCount + 1
        UserDefaults.standard.set(newCount, forKey: Keys.recipeCount)

        logger.log(
            "Recipe count: \(newCount)",
            category: .store,
            level: .debug,
            metadata: nil
        )

        // Check triggers
        if newCount == 1 {
            // First recipe trigger
            Task {
                await checkAndShowPaywall(for: .firstRecipeAdded)
            }
        } else if newCount == 5 {
            // Five recipes trigger
            Task {
                await checkAndShowPaywall(for: .fiveRecipesOrDay7)
            }
        }
    }

    /// Check and show paywall if conditions met
    private func checkAndShowPaywall(for trigger: PaywallTrigger) async {
        // Delay slightly to avoid interrupting user flow
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        if shouldShow(for: trigger) {
            show(for: trigger)
        }
    }

    // MARK: - Trigger Conditions

    private func canTriggerFirstRecipe() -> Bool {
        let recipeCount = UserDefaults.standard.integer(forKey: Keys.recipeCount)
        let hasTriggered = UserDefaults.standard.bool(forKey: Keys.hasTriggeredFirstRecipe)

        return recipeCount >= 1 && !hasTriggered
    }

    private func canTriggerFiveRecipesOrDay7() -> Bool {
        let recipeCount = UserDefaults.standard.integer(forKey: Keys.recipeCount)
        let hasTriggered = UserDefaults.standard.bool(forKey: Keys.hasTriggeredFiveRecipes)

        // Check recipe count
        if recipeCount >= 5 && !hasTriggered {
            return true
        }

        // Check day 7
        guard let firstLaunch = UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date else {
            return false
        }

        let daysSinceLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0

        return daysSinceLaunch >= 7 && !hasTriggered
    }

    private func canTriggerDay13() -> Bool {
        guard let firstLaunch = UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date else {
            return false
        }

        let daysSinceLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
        let hasTriggered = UserDefaults.standard.bool(forKey: Keys.hasTriggeredDay13)

        // Only trigger on day 13, and only once
        return daysSinceLaunch == 13 && !hasTriggered && subscriptionManager.isInTrial
    }

    // MARK: - Cooldown Management

    private func isCooldownExpired(for trigger: PaywallTrigger) -> Bool {
        guard let cooldownHours = trigger.cooldownHours else {
            return true // No cooldown
        }

        let key: String
        switch trigger {
        case .firstRecipeAdded:
            key = Keys.firstRecipeTriggerDate
        case .fiveRecipesOrDay7:
            key = Keys.fiveRecipesTriggerDate
        default:
            return true
        }

        guard let lastTrigger = UserDefaults.standard.object(forKey: key) as? Date else {
            return true // Never triggered
        }

        let hoursSinceTrigger = Date().timeIntervalSince(lastTrigger) / 3600
        return hoursSinceTrigger >= Double(cooldownHours)
    }

    private func markTriggerShown(_ trigger: PaywallTrigger) {
        let now = Date()

        switch trigger {
        case .firstRecipeAdded:
            UserDefaults.standard.set(now, forKey: Keys.firstRecipeTriggerDate)
            UserDefaults.standard.set(true, forKey: Keys.hasTriggeredFirstRecipe)

        case .fiveRecipesOrDay7:
            UserDefaults.standard.set(now, forKey: Keys.fiveRecipesTriggerDate)
            UserDefaults.standard.set(true, forKey: Keys.hasTriggeredFiveRecipes)

        case .day13Urgency:
            UserDefaults.standard.set(true, forKey: Keys.hasTriggeredDay13)

        case .urlImport, .cookbookScan, .sync, .largePDFImport:
            break // Hard walls don't track trigger date
        }
    }

    // MARK: - State Management

    private func loadState() {
        softWallDismissCount = UserDefaults.standard.integer(forKey: Keys.softWallDismissCount)
        isStrikeRuleActive = softWallDismissCount >= 3
    }

    /// Reset all paywall state (for testing)
    func reset() {
        UserDefaults.standard.removeObject(forKey: Keys.firstRecipeTriggerDate)
        UserDefaults.standard.removeObject(forKey: Keys.fiveRecipesTriggerDate)
        UserDefaults.standard.removeObject(forKey: Keys.softWallDismissCount)
        UserDefaults.standard.removeObject(forKey: Keys.recipeCount)
        UserDefaults.standard.removeObject(forKey: Keys.hasTriggeredFirstRecipe)
        UserDefaults.standard.removeObject(forKey: Keys.hasTriggeredFiveRecipes)
        UserDefaults.standard.removeObject(forKey: Keys.hasTriggeredDay13)

        softWallDismissCount = 0
        isStrikeRuleActive = false
        shouldShowPaywall = false
        currentTrigger = nil

        logger.log("Paywall state reset", category: .store, level: .info, metadata: nil)
    }

    /// Print debug status for troubleshooting
    func printDebugStatus() {
        print("=== PAYWALL MANAGER DEBUG ===")
        print("Soft Wall Dismiss Count: \(softWallDismissCount) / 3")
        print("Strike Rule Active: \(isStrikeRuleActive)")
        print("Should Show Paywall: \(shouldShowPaywall)")
        print("Current Trigger: \(currentTrigger?.displayName ?? "none")")

        let recipeCount = UserDefaults.standard.integer(forKey: Keys.recipeCount)
        print("Recipe Count: \(recipeCount)")

        if let firstRecipeDate = UserDefaults.standard.object(forKey: Keys.firstRecipeTriggerDate) as? Date {
            print("First Recipe Date: \(firstRecipeDate.description)")
        } else {
            print("First Recipe Date: none")
        }

        if let fiveRecipesDate = UserDefaults.standard.object(forKey: Keys.fiveRecipesTriggerDate) as? Date {
            print("Five Recipes Date: \(fiveRecipesDate.description)")
        } else {
            print("Five Recipes Date: none")
        }
        print("===========================")
    }
}
