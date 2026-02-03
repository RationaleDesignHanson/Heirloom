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
    @Published private(set) var isDayChangeTimerActive: Bool = false
    @Published private(set) var lastTimerCheckDate: Date?

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private var dayChangeTimer: Timer?
    private var analyticsService: AnalyticsServiceProtocol?

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

    /// Whether user is currently in trial period (days 1-14)
    var isInTrialPeriod: Bool {
        guard hasSelectedThemes else { return false }
        return currentTrialDay >= 1 && currentTrialDay <= 14
    }

    // MARK: - Initialization

    init() {
        loadPersistedState()
        updateCurrentTrialDay()
        setupDayChangeObserver()
        setupDayChangeTimer()

        // Setup analytics (optional - app may not have analytics configured)
        Task { @MainActor in
            self.analyticsService = ServiceContainer.shared.resolveOptional(AnalyticsServiceProtocol.self)
        }
    }

    deinit {
        dayChangeTimer?.invalidate()
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

        // Track analytics
        analyticsService?.track(event: .themeTrialStarted, properties: [
            "theme_count": themeIds.count,
            "themes": themeIds.joined(separator: ","),
            "trial_start_date": ISO8601DateFormatter().string(from: trialStartDate),
            "current_day": currentTrialDay
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
        let hasNew = currentTrialDay > lastDay

        Log.info("Checking for new unlocks", category: .trial, metadata: [
            "currentDay": currentTrialDay,
            "lastUnlockDay": lastDay,
            "hasNewUnlocks": hasNew,
            "selectedThemes": selectedThemeIds.count
        ])

        if hasNew {
            userDefaults.set(currentTrialDay, forKey: Keys.lastUnlockDay)
            hasNewUnlocks = true
            lastCheckDate = Date()

            Log.info("New unlocks available", category: .trial, metadata: [
                "unlockedDay": currentTrialDay
            ])

            // Track unlock analytics
            analyticsService?.track(event: .dailyUnlockTriggered, properties: [
                "day": currentTrialDay,
                "days_remaining": daysRemaining,
                "is_trial_complete": isTrialComplete,
                "theme_count": selectedThemeIds.count
            ])

            // Track reaching specific milestones
            if currentTrialDay == 7 {
                analyticsService?.track(event: .unlockDayReached, properties: [
                    "milestone": "halfway",
                    "day": 7
                ])
            } else if currentTrialDay == 14 {
                analyticsService?.track(event: .themeTrialCompleted, properties: [
                    "theme_count": selectedThemeIds.count,
                    "completion_date": ISO8601DateFormatter().string(from: Date()),
                    "days_taken": 14
                ])
            }

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

    /// Check if a recipe is unlocked (based on unlockDay and current trial day)
    func isUnlocked(_ recipe: Recipe) -> Bool {
        // If recipe doesn't have an unlock day, it's unlocked by default
        guard let unlockDay = recipe.unlockDay else {
            return true
        }

        // Recipe is unlocked if its unlock day is <= current trial day
        return unlockDay <= currentTrialDay
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

    // MARK: - Verification Methods

    /// Verifies unlock system integrity - for testing/debug only
    func verifyUnlockIntegrity(modelContext: ModelContext) -> UnlockVerificationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Check 1: Trial date is set
        guard let trialStart = userDefaults.object(forKey: Keys.trialStartDate) as? Date else {
            errors.append("Trial start date not set")

            // Track verification failure
            analyticsService?.track(event: .unlockVerificationFailed, properties: [
                "error": "trial_start_date_not_set"
            ])

            return UnlockVerificationResult(isValid: false, errors: errors, warnings: warnings)
        }

        // Check 2: Current day calculation is sane
        let daysSinceStart = Calendar.current.dateComponents([.day], from: trialStart, to: Date()).day ?? 0
        if daysSinceStart < 0 {
            errors.append("Trial start date is in the future")
        }
        if daysSinceStart > 30 {
            warnings.append("Trial started more than 30 days ago (expired)")
        }

        // Check 3: Validate selected themes exist
        if selectedThemeIds.isEmpty {
            warnings.append("No themes selected - user may not have completed onboarding")
        }

        // Check 4: Recipe unlock days are valid
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe == true }
        )

        do {
            let themeRecipes = try modelContext.fetch(descriptor)

            if themeRecipes.isEmpty {
                warnings.append("No theme recipes found in database")
            }

            var invalidUnlockDays = 0
            var missingUnlockDays = 0

            for recipe in themeRecipes {
                guard let unlockDay = recipe.unlockDay else {
                    missingUnlockDays += 1
                    continue
                }

                if unlockDay < 1 || unlockDay > 14 {
                    errors.append("Recipe '\(recipe.title)' has invalid unlockDay: \(unlockDay)")
                    invalidUnlockDays += 1
                }
            }

            if missingUnlockDays > 0 {
                warnings.append("\(missingUnlockDays) theme recipes missing unlockDay property")
            }

            // Check 5: Expected unlock counts per day
            let unlockedCount = themeRecipes.filter { isUnlocked($0) }.count
            let totalThemeRecipes = themeRecipes.count

            Log.info("Unlock verification", category: .trial, metadata: [
                "totalThemeRecipes": totalThemeRecipes,
                "unlockedCount": unlockedCount,
                "currentDay": currentTrialDay,
                "selectedThemes": selectedThemeIds.count,
                "errors": errors.count,
                "warnings": warnings.count
            ])

            // Track verification failure if errors found
            if !errors.isEmpty {
                analyticsService?.track(event: .unlockVerificationFailed, properties: [
                    "error_count": errors.count,
                    "warning_count": warnings.count,
                    "errors": errors.joined(separator: " | ")
                ])
            }

        } catch {
            errors.append("Failed to fetch theme recipes: \(error.localizedDescription)")

            analyticsService?.track(event: .unlockVerificationFailed, properties: [
                "error": "recipe_fetch_failed",
                "detail": error.localizedDescription
            ])
        }

        return UnlockVerificationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
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

        Log.info("Trial day updated", category: .trial, metadata: [
            "currentDay": currentTrialDay,
            "trialStartDate": trialStartDate.description,
            "daysElapsed": days,
            "isComplete": isTrialComplete
        ])
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

        // Pause timer when app goes to background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.dayChangeTimer?.invalidate()
                self?.dayChangeTimer = nil
                self?.isDayChangeTimerActive = false
                Log.debug("Day change timer paused (backgrounded)", category: .trial)
            }
            .store(in: &cancellables)

        // Resume timer when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.setupDayChangeTimer()
                Log.debug("Day change timer resumed (foregrounded)", category: .trial)
            }
            .store(in: &cancellables)
    }

    /// Sets up a timer to check for day changes while app is active
    /// This ensures new recipes unlock even if user keeps app open overnight
    private func setupDayChangeTimer() {
        // Invalidate existing timer if any
        dayChangeTimer?.invalidate()
        isDayChangeTimerActive = false

        // Only setup timer if user is in trial period
        guard isInTrialPeriod else {
            Log.debug("Skipping day change timer setup (not in trial)", category: .trial)
            return
        }

        // Check for day changes every hour
        dayChangeTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Run on main actor since ThemeUnlockTracker is @MainActor
            Task { @MainActor in
                self.lastTimerCheckDate = Date()
                Log.debug("Day change timer fired - checking for new day", category: .trial)

                let previousDay = self.currentTrialDay
                self.updateCurrentTrialDay()

                // If day changed, check for new unlocks
                if self.currentTrialDay > previousDay {
                    Log.info("Day changed via timer", category: .trial, metadata: [
                        "previousDay": previousDay,
                        "currentDay": self.currentTrialDay
                    ])

                    let hasNewUnlocks = self.checkForNewUnlocks()

                    if hasNewUnlocks {
                        // Post notification that new recipes are available
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ThemeUnlocksAvailable"),
                            object: self,
                            userInfo: ["day": self.currentTrialDay]
                        )
                    }
                }
            }
        }

        isDayChangeTimerActive = true
        lastTimerCheckDate = Date() // Set initial check time

        Log.info("Day change timer started", category: .trial, metadata: [
            "checkInterval": "1 hour",
            "currentDay": currentTrialDay
        ])
    }
}

// MARK: - Verification Result

/// Result of unlock system integrity verification
struct UnlockVerificationResult {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]

    var summary: String {
        var lines: [String] = []
        if isValid {
            lines.append("✅ Unlock system is healthy")
        } else {
            lines.append("❌ Unlock system has errors")
        }

        if !errors.isEmpty {
            lines.append("\nErrors:")
            errors.forEach { lines.append("  • \($0)") }
        }

        if !warnings.isEmpty {
            lines.append("\nWarnings:")
            warnings.forEach { lines.append("  • \($0)") }
        }

        return lines.joined(separator: "\n")
    }
}

