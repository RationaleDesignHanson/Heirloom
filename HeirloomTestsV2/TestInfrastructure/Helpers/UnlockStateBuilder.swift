//
//  UnlockStateBuilder.swift
//  HeirloomTestsV2
//
//  Fluent builder for creating ThemeUnlockTracker instances in specific states
//  Created: 2026-01-13
//

import Foundation
@testable import Heirloom

/// Builder for creating ThemeUnlockTracker instances with specific unlock states
///
/// Usage:
/// ```swift
/// let tracker = UnlockStateBuilder()
///     .withUnlockedCount(50)
///     .withTrialDay(7)
///     .build()
/// ```
@MainActor
final class UnlockStateBuilder {

    // MARK: - Configuration

    private var unlockedRecipeIds: Set<String> = []
    private var lastUnlockDate: Date?
    private var trialStartDate: Date?
    private var unlockedCount: Int?

    // MARK: - Unlock Count

    /// Set number of unlocked recipes (will generate recipe IDs)
    func withUnlockedCount(_ count: Int) -> Self {
        self.unlockedCount = count
        return self
    }

    /// Set specific unlocked recipe IDs
    func withUnlockedRecipeIds(_ ids: Set<String>) -> Self {
        self.unlockedRecipeIds = ids
        self.unlockedCount = nil // Override count
        return self
    }

    // MARK: - Unlock Timing

    /// Set last unlock date
    func withLastUnlockDate(_ date: Date) -> Self {
        self.lastUnlockDate = date
        return self
    }

    /// Set last unlock to today (no unlocks available)
    func withUnlockToday() -> Self {
        self.lastUnlockDate = Date()
        return self
    }

    /// Set last unlock to yesterday (unlocks available)
    func withUnlockYesterday() -> Self {
        self.lastUnlockDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        return self
    }

    // MARK: - Trial Configuration

    /// Set trial start date (for calculating expected unlocks)
    func withTrialStartDate(_ date: Date) -> Self {
        self.trialStartDate = date
        return self
    }

    /// Set trial to specific day (0 = started today, 7 = day 7, etc.)
    func withTrialDay(_ day: Int) -> Self {
        self.trialStartDate = Calendar.current.date(byAdding: .day, value: -day, to: Date())
        return self
    }

    /// No trial started yet
    func withNoTrial() -> Self {
        self.trialStartDate = nil
        return self
    }

    // MARK: - Build

    /// Build ThemeUnlockTracker with configured state
    func build() -> ThemeUnlockTracker {
        // Clear any existing state
        clearUserDefaults()

        // Generate recipe IDs if count specified
        if let count = unlockedCount {
            unlockedRecipeIds = Set((0..<count).map { "recipe_\($0)" })
        }

        // Configure unlocked recipes
        if !unlockedRecipeIds.isEmpty {
            let idsArray = Array(unlockedRecipeIds)
            UserDefaults.standard.set(idsArray, forKey: "heritageUnlockedRecipeIds")
        }

        // Configure last unlock date
        if let date = lastUnlockDate {
            UserDefaults.standard.set(date, forKey: "heritageLastUnlockDate")
        }

        // Configure trial start date
        if let date = trialStartDate {
            UserDefaults.standard.set(date, forKey: "heritageTrialStartDate")
        }

        // Create ThemeUnlockTracker (will load from UserDefaults)
        let tracker = ThemeUnlockTracker()

        return tracker
    }

    // MARK: - Cleanup

    /// Clear all unlock-related UserDefaults
    private func clearUserDefaults() {
        let keys = [
            "heritageUnlockedRecipeIds",
            "heritageLastUnlockDate",
            "heritageTrialStartDate"
        ]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - Convenience Presets

extension UnlockStateBuilder {

    /// Fresh state (no unlocks, no trial)
    static func fresh() -> ThemeUnlockTracker {
        return UnlockStateBuilder().build()
    }

    /// Trial started today, no unlocks yet
    static func trialStarted() -> ThemeUnlockTracker {
        return UnlockStateBuilder()
            .withTrialDay(0)
            .build()
    }

    /// Day 1: 7 recipes unlocked
    static func day1Complete() -> ThemeUnlockTracker {
        return UnlockStateBuilder()
            .withTrialDay(1)
            .withUnlockedCount(7)
            .withUnlockToday()
            .build()
    }

    /// Day 7: 49 recipes unlocked (7 per day)
    static func day7Complete() -> ThemeUnlockTracker {
        return UnlockStateBuilder()
            .withTrialDay(7)
            .withUnlockedCount(49)
            .withUnlockToday()
            .build()
    }

    /// Day 14: 98 recipes unlocked (near quota)
    static func day14Complete() -> ThemeUnlockTracker {
        return UnlockStateBuilder()
            .withTrialDay(14)
            .withUnlockedCount(98)
            .withUnlockToday()
            .build()
    }

    /// Quota met: 100 recipes unlocked
    static func quotaMet() -> ThemeUnlockTracker {
        return UnlockStateBuilder()
            .withTrialDay(14)
            .withUnlockedCount(100)
            .withUnlockToday()
            .build()
    }

    /// Day 7 but hasn't unlocked yesterday (catch-up available)
    static func day7WithCatchup() -> ThemeUnlockTracker {
        return UnlockStateBuilder()
            .withTrialDay(7)
            .withUnlockedCount(35) // Only 5 days worth
            .withUnlockYesterday()
            .build()
    }

    /// Boundary: 0 unlocked
    static func zeroUnlocked() -> ThemeUnlockTracker {
        return UnlockStateBuilder()
            .withTrialDay(0)
            .withUnlockedCount(0)
            .build()
    }

    /// Boundary: 50 unlocked (halfway)
    static func fiftyUnlocked() -> ThemeUnlockTracker {
        return UnlockStateBuilder()
            .withTrialDay(7)
            .withUnlockedCount(50)
            .withUnlockYesterday()
            .build()
    }
}
