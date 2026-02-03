//
//  TrialDebugView.swift
//  Heirloom
//
//  Phase 2: Paywall & Subscription System
//  Debug screen for testing trial period scenarios
//

import SwiftUI
import SwiftData
import Foundation

struct TrialDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var subscriptionManager: SubscriptionManager?
    @State private var themeUnlockTracker: ThemeUnlockTracker?
    @State private var paywallManager: PaywallManager?
    @State private var refreshTrigger = false // Force view refresh

    var body: some View {
        List {
            trialPeriodSection
            heritageUnlocksSection
            unlockDiagnosticsSection
            unlockVerificationSection
            paywallTriggersSection
        }
        .navigationTitle("Trial Debug")
        .onAppear {
            setupServices()
        }
        .id(refreshTrigger) // Force view refresh when trigger changes
    }

    // MARK: - Sections

    private var trialPeriodSection: some View {
        let startDateText = (UserDefaults.standard.object(forKey: "first_launch_date") as? Date)?.description ?? "Not set"
        let expiryDateText = subscriptionManager?.trialExpiryDate?.description ?? "Not set"

        return Section("Trial Period") {
            LabeledContent("Start Date", value: startDateText)
            LabeledContent("Expiry Date", value: expiryDateText)
            LabeledContent("Days Remaining", value: "\(subscriptionManager?.daysRemaining ?? 0)")
            LabeledContent("Status", value: subscriptionManager?.status.rawValue ?? "Unknown")
            LabeledContent("Is In Trial", value: subscriptionManager?.isInTrial ?? false ? "Yes" : "No")
            LabeledContent("Is Trial Expired", value: subscriptionManager?.isTrialExpired ?? false ? "Yes" : "No")
            LabeledContent("Is Premium", value: subscriptionManager?.isPremium ?? false ? "Yes" : "No")

            Button("Reset Trial (Day 1)") {
                resetTrial()
            }
            .foregroundStyle(.orange)

            Button("Skip to Day 7") {
                skipToDay(7)
            }

            Button("Skip to Day 13") {
                skipToDay(13)
            }

            Button("Skip to Day 15 (Expired)") {
                skipToDay(15)
            }

            Divider()

            Button("⏩ Skip Ahead 1 Day") {
                skipAheadOneDay()
            }
            .foregroundStyle(.blue)
        }
    }

    private var heritageUnlocksSection: some View {
        let trialStartDateText = (UserDefaults.standard.object(forKey: "theme_trial_start_date") as? Date)?.description ?? "Not set"
        let selectedThemeIds = UserDefaults.standard.stringArray(forKey: "selected_theme_ids") ?? []

        return Section("Theme Unlocks") {
            if let tracker = themeUnlockTracker {
                LabeledContent("Trial Start", value: trialStartDateText)
                LabeledContent("Current Day", value: "\(tracker.currentTrialDay) / 14")
                LabeledContent("Days Remaining", value: "\(tracker.daysRemaining)")
                LabeledContent("Selected Themes", value: "\(selectedThemeIds.count)")
                LabeledContent("Has New Unlocks", value: tracker.hasNewUnlocks ? "Yes" : "No")
                LabeledContent("Is In Trial", value: tracker.isInTrialPeriod ? "Yes" : "No")
                LabeledContent("Is Complete", value: tracker.isTrialComplete ? "Yes" : "No")

                Divider()

                LabeledContent("Background Timer", value: tracker.isDayChangeTimerActive ? "✅ Active" : "⏸️ Paused")
                    .foregroundStyle(tracker.isDayChangeTimerActive ? .green : .secondary)

                if let lastTimerCheck = tracker.lastTimerCheckDate {
                    LabeledContent("Last Timer Check", value: formatDate(lastTimerCheck))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("Last Timer Check", value: "Never")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Trigger Daily Unlock Check") {
                    let hadUnlocks = tracker.checkForNewUnlocks()
                    Log.info("Manual unlock check", category: .trial, metadata: ["hadUnlocks": hadUnlocks])

                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    toastManager.show(
                        type: hadUnlocks ? .success : .info,
                        title: hadUnlocks ? "New recipes unlocked!" : "No new unlocks"
                    )

                    refreshTrigger.toggle()
                }
                .foregroundStyle(.blue)

                Button("Reset Trial Tracking") {
                    tracker.resetTrial()
                    refreshTrigger.toggle()

                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    toastManager.show(type: .success, title: "Trial tracking reset - restart app")
                }
                .foregroundStyle(.orange)

                #if DEBUG
                Button("Debug: Set Trial Day 2") {
                    tracker.debugSetTrialDay(2)
                    refreshTrigger.toggle()

                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    toastManager.show(type: .success, title: "Trial set to Day 2")
                }
                .foregroundStyle(.purple)

                Button("Debug: Set Trial Day 7") {
                    tracker.debugSetTrialDay(7)
                    refreshTrigger.toggle()

                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    toastManager.show(type: .success, title: "Trial set to Day 7")
                }
                .foregroundStyle(.purple)
                #endif
            } else {
                Text("Loading...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unlockDiagnosticsSection: some View {
        Section("Unlock Diagnostics") {
            if let tracker = themeUnlockTracker {
                // Fetch theme recipes for diagnostic counts
                let descriptor = FetchDescriptor<Recipe>(
                    predicate: #Predicate { $0.isThemeRecipe == true }
                )

                if let themeRecipes = try? modelContext.fetch(descriptor) {
                    let unlockedCount = themeRecipes.filter { tracker.isUnlocked($0) }.count
                    let totalCount = themeRecipes.count

                    LabeledContent("Total Theme Recipes", value: "\(totalCount)")
                    LabeledContent("Unlocked Recipes", value: "\(unlockedCount)")
                    LabeledContent("Locked Recipes", value: "\(totalCount - unlockedCount)")

                    if let lastCheck = tracker.lastCheckDate {
                        LabeledContent("Last Unlock Check", value: formatDate(lastCheck))
                    } else {
                        LabeledContent("Last Unlock Check", value: "Never")
                    }

                    // Show next unlock day
                    if tracker.currentTrialDay < 14 {
                        LabeledContent("Next Unlock Day", value: "\(tracker.currentTrialDay + 1)")
                    } else {
                        LabeledContent("Next Unlock Day", value: "Trial Complete")
                    }

                    // Show unlock timeline
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unlock Timeline")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(1...14, id: \.self) { day in
                            let recipesForDay = themeRecipes.filter { $0.unlockDay == day }
                            let isUnlocked = day <= tracker.currentTrialDay
                            let icon = isUnlocked ? "✅" : "🔒"

                            HStack {
                                Text("\(icon) Day \(day):")
                                    .font(.caption)
                                Text("\(recipesForDay.count) recipes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if day == tracker.currentTrialDay {
                                    Text("(today)")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("Unable to fetch recipes")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Loading...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unlockVerificationSection: some View {
        Section("Unlock Verification") {
            if let tracker = themeUnlockTracker {
                Button("🔍 Verify Unlock System") {
                    let result = tracker.verifyUnlockIntegrity(modelContext: modelContext)
                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)

                    if result.isValid {
                        toastManager.show(
                            type: .success,
                            title: "Verification Passed",
                            message: result.warnings.isEmpty ? "All checks passed" : "\(result.warnings.count) warnings"
                        )
                    } else {
                        toastManager.show(
                            type: .error,
                            title: "Verification Failed",
                            message: "\(result.errors.count) errors found"
                        )
                    }

                    // Log full results
                    Log.info("Verification completed", category: .trial, metadata: [
                        "isValid": result.isValid,
                        "errors": result.errors.joined(separator: " | "),
                        "warnings": result.warnings.joined(separator: " | ")
                    ])

                    print("=== Unlock System Verification ===")
                    print(result.summary)
                    print("=================================")
                }
                .foregroundStyle(.blue)

                Button("📊 Export Debug Log") {
                    exportDebugLog(tracker: tracker)
                }
                .foregroundStyle(.purple)
            } else {
                Text("Loading...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var paywallTriggersSection: some View {
        Section("Paywall Triggers") {
            if let manager = paywallManager {
                LabeledContent("Soft Wall Dismisses", value: "\(manager.softWallDismissCount) / 3")
                LabeledContent("Strike Rule Active", value: manager.isStrikeRuleActive ? "Yes" : "No")

                Button("Reset Paywall State") {
                    manager.reset()
                }
                .foregroundStyle(.red)

                Button("Print Paywall Status") {
                    manager.printDebugStatus()
                }
                .foregroundStyle(.blue)
            } else {
                Text("Loading...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func setupServices() {
        // CRITICAL: Use singleton from ServiceContainer, not new instance
        subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
        themeUnlockTracker = ServiceContainer.shared.resolve(ThemeUnlockTracker.self)
        paywallManager = ServiceContainer.shared.resolve(PaywallManager.self)
    }

    private func resetTrial() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: "first_launch_date")
        UserDefaults.standard.set(now.addingTimeInterval(14 * 24 * 60 * 60), forKey: "trial_expiry_date")
        UserDefaults.standard.synchronize()

        print("✅ Reset trial: first_launch_date = \(now)")
        print("✅ Reset trial: trial_expiry_date = \(now.addingTimeInterval(14 * 24 * 60 * 60))")

        Task {
            await subscriptionManager?.refreshStatus(force: true)

            // Force view refresh
            await MainActor.run {
                refreshTrigger.toggle()
                print("✅ View refreshed after reset")
            }
        }

        Log.info("Trial reset to Day 1", category: .general)
    }

    private func skipToDay(_ day: Int) {
        let startDate = Date().addingTimeInterval(-TimeInterval(day * 24 * 60 * 60))
        UserDefaults.standard.set(startDate, forKey: "first_launch_date")
        UserDefaults.standard.set(startDate.addingTimeInterval(14 * 24 * 60 * 60), forKey: "trial_expiry_date")
        UserDefaults.standard.synchronize()

        print("✅ Skipped to Day \(day): first_launch_date = \(startDate)")
        print("✅ Days remaining should be: \(14 - day)")

        Task {
            await subscriptionManager?.refreshStatus(force: true)

            // Force view refresh
            await MainActor.run {
                refreshTrigger.toggle()

                // Show toast confirmation
                let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                toastManager.success(title: "Jumped to Day \(day)", message: "\(14 - day) days remaining")

                print("✅ View refreshed after skip to day \(day)")
            }
        }

        Log.info("Trial skipped to Day \(day)", category: .general)
    }

    private func skipAheadOneDay() {
        // Get current trial start date
        guard let currentStartDate = UserDefaults.standard.object(forKey: "first_launch_date") as? Date else {
            print("❌ No trial start date found")
            Log.warning("No trial start date found", category: .general)

            // Show error toast
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            toastManager.error(title: "No trial found", message: "Reset trial first")
            return
        }

        // Move start date back by 1 day (making trial 1 day older)
        let newStartDate = currentStartDate.addingTimeInterval(-24 * 60 * 60)
        UserDefaults.standard.set(newStartDate, forKey: "first_launch_date")
        UserDefaults.standard.set(newStartDate.addingTimeInterval(14 * 24 * 60 * 60), forKey: "trial_expiry_date")

        // CRITICAL: Also update theme trial start date (stored separately)
        if let themeTrialStart = UserDefaults.standard.object(forKey: "theme_trial_start_date") as? Date {
            let newThemeStart = themeTrialStart.addingTimeInterval(-24 * 60 * 60)
            UserDefaults.standard.set(newThemeStart, forKey: "theme_trial_start_date")
            print("✅ Updated theme_trial_start_date from \(themeTrialStart) to \(newThemeStart)")
        }

        UserDefaults.standard.synchronize()

        let daysSinceStart = Calendar.current.dateComponents([.day], from: newStartDate, to: Date()).day ?? 0
        let currentDay = daysSinceStart + 1

        print("✅ Skipped ahead 1 day: now on Day \(currentDay)")
        print("✅ Days remaining should be: \(14 - currentDay)")

        // CRITICAL: Reset theme unlock tracking so today's unlock becomes available
        if themeUnlockTracker != nil {
            // Reset last unlock day to force new unlock check
            UserDefaults.standard.set(currentDay - 1, forKey: "last_unlock_day")

            print("✅ Reset theme last unlock day to \(currentDay - 1)")
            Log.info("Reset theme unlock tracking for day skip", category: .trial)
        }

        // Refresh subscription manager to trigger unlock checks with new date
        Task {
            await subscriptionManager?.refreshStatus(force: true)

            // Finally update UI
            await MainActor.run {
                refreshTrigger.toggle()

                // Show toast confirmation
                let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                toastManager.success(
                    title: "Advanced to Day \(currentDay)",
                    message: "Heritage unlock now available"
                )

                print("✅ View refreshed after skip ahead 1 day")
            }
        }

        Log.info("Skipped ahead 1 day (now on Day \(currentDay))", category: .general)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func exportDebugLog(tracker: ThemeUnlockTracker) {
        var logLines: [String] = []

        logLines.append("=== Daily Unlock Debug Log ===")
        logLines.append("Generated: \(Date())")
        logLines.append("")

        logLines.append("Trial Status:")
        logLines.append("  Current Day: \(tracker.currentTrialDay) / 14")
        logLines.append("  Days Remaining: \(tracker.daysRemaining)")
        logLines.append("  Trial Start: \(tracker.trialStartDate)")
        logLines.append("  Is In Trial: \(tracker.isInTrialPeriod)")
        logLines.append("  Is Complete: \(tracker.isTrialComplete)")
        logLines.append("")

        logLines.append("Selected Themes:")
        if tracker.selectedThemeIds.isEmpty {
            logLines.append("  None")
        } else {
            tracker.selectedThemeIds.forEach { logLines.append("  • \($0)") }
        }
        logLines.append("")

        // Fetch theme recipes
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe == true }
        )

        if let themeRecipes = try? modelContext.fetch(descriptor) {
            let unlockedCount = themeRecipes.filter { tracker.isUnlocked($0) }.count
            logLines.append("Recipe Status:")
            logLines.append("  Total Theme Recipes: \(themeRecipes.count)")
            logLines.append("  Unlocked: \(unlockedCount)")
            logLines.append("  Locked: \(themeRecipes.count - unlockedCount)")
            logLines.append("")

            logLines.append("Unlock Timeline:")
            for day in 1...14 {
                let recipesForDay = themeRecipes.filter { $0.unlockDay == day }
                let icon = day <= tracker.currentTrialDay ? "✅" : "🔒"
                logLines.append("  \(icon) Day \(day): \(recipesForDay.count) recipes")
            }
        }

        logLines.append("")
        logLines.append("Verification:")
        let result = tracker.verifyUnlockIntegrity(modelContext: modelContext)
        logLines.append(result.summary)

        logLines.append("")
        logLines.append("=== End Debug Log ===")

        let logText = logLines.joined(separator: "\n")

        // Copy to clipboard
        UIPasteboard.general.string = logText

        // Show confirmation
        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
        toastManager.show(type: .success, title: "Debug log copied to clipboard")

        print(logText)
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(for: Recipe.self, RecipeCollection.self)

    NavigationStack {
        TrialDebugView()
            .modelContainer(container)
    }
}
