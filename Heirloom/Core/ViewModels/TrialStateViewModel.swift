//
//  TrialStateViewModel.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation
import SwiftUI
import SwiftData

/// View model for displaying trial state in UI
@MainActor
class TrialStateViewModel: ObservableObject {

    @Published var trialDay: Int = 1
    @Published var daysRemaining: Int = 14
    @Published var selectedThemeCount: Int = 0
    @Published var totalUnlockedRecipes: Int = 0
    @Published var hasNewUnlocks: Bool = false

    private let unlockTracker: ThemeUnlockTracker
    private let modelContext: ModelContext

    init(unlockTracker: ThemeUnlockTracker, modelContext: ModelContext) {
        self.unlockTracker = unlockTracker
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        trialDay = unlockTracker.currentTrialDay
        daysRemaining = unlockTracker.daysRemaining
        selectedThemeCount = unlockTracker.selectedThemeIds.count
        hasNewUnlocks = unlockTracker.hasNewUnlocks

        // Count total unlocked recipes
        calculateTotalUnlocked()
    }

    private func calculateTotalUnlocked() {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe == true }
        )

        if let recipes = try? modelContext.fetch(descriptor) {
            totalUnlockedRecipes = recipes.count
        }
    }

    /// Formatted string for trial status
    var trialStatusText: String {
        if unlockTracker.isTrialComplete {
            return "Trial complete"
        }
        return "Day \(trialDay) of 14"
    }

    /// Progress value for progress bars (0.0 - 1.0)
    var trialProgress: Double {
        Double(trialDay) / 14.0
    }
}
