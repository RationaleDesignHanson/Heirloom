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
import FirebaseFirestore

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

                Button("Trigger Daily Unlock Check") {
                    let hadUnlocks = tracker.checkForNewUnlocks()
                    Log.info("Manual unlock check", category: .trial, metadata: ["hadUnlocks": hadUnlocks])

                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    toastManager.show(
                        hadUnlocks ? "New recipes unlocked!" : "No new unlocks",
                        type: hadUnlocks ? .success : .info
                    )

                    refreshTrigger.toggle()
                }
                .foregroundStyle(.blue)

                Button("Reset Trial Tracking") {
                    tracker.resetTrial()
                    refreshTrigger.toggle()

                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    toastManager.show("Trial tracking reset - restart app", type: .success)
                }
                .foregroundStyle(.orange)

                #if DEBUG
                Button("Debug: Set Trial Day 2") {
                    tracker.debugSetTrialDay(2)
                    refreshTrigger.toggle()

                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    toastManager.show("Trial set to Day 2", type: .success)
                }
                .foregroundStyle(.purple)

                Button("Debug: Set Trial Day 7") {
                    tracker.debugSetTrialDay(7)
                    refreshTrigger.toggle()

                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    toastManager.show("Trial set to Day 7", type: .success)
                }
                .foregroundStyle(.purple)
                #endif
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
        if let tracker = themeUnlockTracker {
            // Reset last unlock day to force new unlock check
            UserDefaults.standard.set(currentDay - 1, forKey: "last_unlock_day")

            print("✅ Reset theme last unlock day to \(currentDay - 1)")
            Log.info("Reset theme unlock tracking for day skip", category: .trial)
        }

        // CRITICAL: Reset Firebase lastDailyUnlock THEN refresh (must be sequential)
        Task {
            // First, update Firebase (if authenticated) - WAIT for this to complete
            do {
                if let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
                   authService.isAuthenticated,
                   let userId = authService.currentUser?.uid {
                    let db = Firestore.firestore()
                    let yesterday = Date().addingTimeInterval(-24 * 60 * 60)

                    // CRITICAL: Update the correct Firestore path where HeritageUnlockService reads from
                    try await db.collection("users")
                        .document(userId)
                        .collection("heritageState")
                        .document("current")
                        .updateData([
                            "lastDailyUnlock": Timestamp(date: yesterday)
                        ])

                    print("✅ Reset Firebase lastDailyUnlock to yesterday (users/{userId}/heritageState/current)")
                }
            } catch {
                print("⚠️ Failed to reset Firebase lastDailyUnlock: \(error)")
            }

            // Then refresh subscription manager (now it will read the updated date)
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
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(for: Recipe.self, RecipeCollection.self)

    NavigationStack {
        TrialDebugView()
            .modelContainer(container)
    }
}
