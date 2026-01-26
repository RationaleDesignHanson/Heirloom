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
    // TODO: Re-enable for theme unlocking in Phase A3
    // @State private var heritageUnlockTracker: ThemeUnlockTracker?
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

    // TODO: Re-implement for theme unlocking in Phase A3
    private var heritageUnlocksSection: some View {
        Section("Theme Unlocks") {
            Text("Theme unlock tracking will be available in Phase A3")
                .foregroundStyle(.secondary)
            // if let tracker = heritageUnlockTracker {
            //     LabeledContent("Unlocked", value: "\(tracker.totalUnlockedCount) / 100")
            //     LabeledContent("Daily Quota", value: "\(tracker.recipesToUnlockToday)")
            //     LabeledContent("Has Today's Unlock", value: tracker.hasUnlocksAvailableToday ? "Yes" : "No")
            //
            //     Button("Trigger Daily Unlock") {
            //         Task {
            //             do {
            //                 try await tracker.unlockDailyBatch(context: modelContext)
            //                 Log.info("Manually triggered unlock", category: .general)
            //
            //                 // Force view refresh
            //                 await MainActor.run {
            //                     refreshTrigger.toggle()
            //                 }
            //             } catch {
            //                 Log.error("Failed to unlock", category: .general, metadata: ["error": error.localizedDescription])
            //             }
            //         }
            //     }
            //     .foregroundStyle(.blue)
            //
            //     Button("Reset Unlock Tracking") {
            //         tracker.resetTrialTracking()
            //         refreshTrigger.toggle()
            //     }
            //     .foregroundStyle(.orange)
            // } else {
            //     Text("Loading...")
            //         .foregroundStyle(.secondary)
            // }
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
        // TODO: Re-enable for theme unlocking in Phase A3
        // heritageUnlockTracker = ServiceContainer.shared.resolve(ThemeUnlockTracker.self)
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

        // CRITICAL: Also update heritage trial start date (stored separately)
        if let heritageTrialStart = UserDefaults.standard.object(forKey: "heritageTrialStartDate") as? Date {
            let newHeritageStart = heritageTrialStart.addingTimeInterval(-24 * 60 * 60)
            UserDefaults.standard.set(newHeritageStart, forKey: "heritageTrialStartDate")
            print("✅ Updated heritageTrialStartDate from \(heritageTrialStart) to \(newHeritageStart)")
        }

        UserDefaults.standard.synchronize()

        let daysSinceStart = Calendar.current.dateComponents([.day], from: newStartDate, to: Date()).day ?? 0
        let currentDay = daysSinceStart + 1

        print("✅ Skipped ahead 1 day: now on Day \(currentDay)")
        print("✅ Days remaining should be: \(14 - currentDay)")

        // TODO: Re-enable for theme unlocking in Phase A3
        // CRITICAL: Reset lastUnlockDate to yesterday so today's unlock becomes available
        // if let tracker = heritageUnlockTracker {
        //     let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
        //     tracker.lastUnlockDate = yesterday
        //
        //     // Reload trialStartDate from UserDefaults after we updated it
        //     tracker.trialStartDate = UserDefaults.standard.object(forKey: "themeTrialStartDate") as? Date
        //
        //     tracker.saveToStorage()
        //
        //     print("✅ Reset theme lastUnlockDate to yesterday")
        //     print("✅ Theme tracker now shows \(tracker.recipesToUnlockToday) recipes available")
        //     Log.info("Reset theme lastUnlockDate to yesterday", category: .general)
        // }

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
