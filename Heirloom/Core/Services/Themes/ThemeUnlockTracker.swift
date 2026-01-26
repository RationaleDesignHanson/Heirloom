//
//  ThemeUnlockTracker.swift
//  Heirloom
//
//  Refactored by Claude Code on 2026-01-26.
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import UIKit

/// Tracks recipe unlocking for user-selected themes during the 14-day trial
@MainActor
class ThemeUnlockTracker: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var currentTrialDay: Int = 1
    @Published private(set) var unlockedRecipeIds: Set<UUID> = []
    @Published private(set) var lastCheckDate: Date?
    @Published private(set) var hasNewUnlocks: Bool = false

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // UserDefaults Keys
    private enum Keys {
        static let trialStartDate = "theme_trial_start_date"
        static let selectedThemeIds = "selected_theme_ids"
        static let unlockedRecipeIds = "unlocked_recipe_ids"
        static let lastCheckDate = "last_unlock_check_date"
        static let lastUnlockDay = "last_unlock_day"

        // Legacy keys for migration
        static let legacyHeritageStart = "heritage_start_date"
    }

    // MARK: - Computed Properties

    /// Date the trial started
    var trialStartDate: Date {
        get {
            // Try new key first
            if let date = userDefaults.object(forKey: Keys.trialStartDate) as? Date {
                return date
            }
            // Migrate from legacy
            if let legacy = userDefaults.object(forKey: Keys.legacyHeritageStart) as? Date {
                userDefaults.set(legacy, forKey: Keys.trialStartDate)
                return legacy
            }
            return Date()
        }
        set {
            userDefaults.set(newValue, forKey: Keys.trialStartDate)
            updateCurrentTrialDay()
        }
    }

    /// IDs of themes the user selected during onboarding
    var selectedThemeIds: [String] {
        get {
            userDefaults.stringArray(forKey: Keys.selectedThemeIds) ?? []
        }
        set {
            userDefaults.set(newValue, forKey: Keys.selectedThemeIds)
            objectWillChange.send()
        }
    }

    /// Whether the user has completed theme selection
    var hasSelectedThemes: Bool {
        !selectedThemeIds.isEmpty
    }

    /// Days remaining in trial
    var daysRemaining: Int {
        max(0, 14 - currentTrialDay + 1)
    }

    /// Whether trial is complete
    var isTrialComplete: Bool {
        currentTrialDay > 14
    }

    // MARK: - Initialization

    init() {
        loadPersistedState()
        updateCurrentTrialDay()
        setupDayChangeObserver()
    }

    // MARK: - Public Methods

    /// Start the trial with selected themes
    func startTrial(withThemeIds themeIds: [String]) {
        guard !themeIds.isEmpty else {
            Log.warning("Attempted to start trial with no themes selected", category: .trial)
            return
        }

        trialStartDate = Date()
        selectedThemeIds = themeIds
        currentTrialDay = 1
        unlockedRecipeIds = []
        hasNewUnlocks = false

        Log.info("Trial started with \(themeIds.count) themes", category: .trial, metadata: [
            "themes": themeIds.joined(separator: ", ")
        ])

        savePersistedState()
    }

    /// Check if a theme is selected by the user
    func isThemeSelected(_ theme: RecipeTheme) -> Bool {
        selectedThemeIds.contains(theme.firebaseId)
    }

    /// Get recipes that should be unlocked today for a specific theme
    func unlockedRecipeCount(for theme: RecipeTheme) -> Int {
        guard isThemeSelected(theme) else { return 0 }

        // Count unlock days up to current day
        return theme.unlockSchedule.filter { $0 <= currentTrialDay }.count
    }

    /// Check for new unlocks since last check
    func checkForNewUnlocks() -> Bool {
        let lastDay = userDefaults.integer(forKey: Keys.lastUnlockDay)

        if currentTrialDay > lastDay {
            userDefaults.set(currentTrialDay, forKey: Keys.lastUnlockDay)
            hasNewUnlocks = true
            lastCheckDate = Date()
            return true
        }

        hasNewUnlocks = false
        return false
    }

    /// Mark new unlocks as seen
    func markUnlocksAsSeen() {
        hasNewUnlocks = false
        lastCheckDate = Date()
        userDefaults.set(Date(), forKey: Keys.lastCheckDate)
    }

    /// Get all themes that have new unlocks today
    func themesWithNewUnlocks(from themes: [RecipeTheme]) -> [RecipeTheme] {
        let selectedThemes = themes.filter { isThemeSelected($0) }

        return selectedThemes.filter { theme in
            theme.unlockSchedule.contains(currentTrialDay)
        }
    }

    /// Reset trial (for testing or re-onboarding)
    func resetTrial() {
        userDefaults.removeObject(forKey: Keys.trialStartDate)
        userDefaults.removeObject(forKey: Keys.selectedThemeIds)
        userDefaults.removeObject(forKey: Keys.unlockedRecipeIds)
        userDefaults.removeObject(forKey: Keys.lastCheckDate)
        userDefaults.removeObject(forKey: Keys.lastUnlockDay)

        currentTrialDay = 1
        selectedThemeIds = []
        unlockedRecipeIds = []
        hasNewUnlocks = false
        lastCheckDate = nil

        Log.info("Trial reset", category: .trial)
    }

    // MARK: - Debug Methods

    #if DEBUG
    /// Simulate advancing to a specific trial day (for testing)
    func debugSetTrialDay(_ day: Int) {
        let daysAgo = day - 1
        trialStartDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        updateCurrentTrialDay()
        Log.debug("Debug: Set trial day to \(day)", category: .trial)
    }
    #endif

    // MARK: - Private Methods

    private func updateCurrentTrialDay() {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: trialStartDate, to: Date()).day ?? 0
        currentTrialDay = min(max(days + 1, 1), 15) // Day 1-14, or 15 if complete
    }

    private func loadPersistedState() {
        if let data = userDefaults.data(forKey: Keys.unlockedRecipeIds),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            unlockedRecipeIds = ids
        }

        lastCheckDate = userDefaults.object(forKey: Keys.lastCheckDate) as? Date
    }

    private func savePersistedState() {
        if let data = try? JSONEncoder().encode(unlockedRecipeIds) {
            userDefaults.set(data, forKey: Keys.unlockedRecipeIds)
        }
    }

    private func setupDayChangeObserver() {
        // Check for day change when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateCurrentTrialDay()
                _ = self?.checkForNewUnlocks()
            }
            .store(in: &cancellables)
    }
}

