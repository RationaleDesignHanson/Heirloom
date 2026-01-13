//
//  TrialDebugView.swift
//  Heirloom
//
//  Phase 2: Paywall & Subscription System
//  Debug screen for testing trial period scenarios
//

import SwiftUI
import SwiftData

struct TrialDebugView: View {
    @Environment(\.modelContext) private var modelContext
    private var subscriptionManager: SubscriptionManager { ServiceContainer.shared.resolve(SubscriptionManager.self) }
    @State private var heritageUnlockTracker: HeritageUnlockTracker?
    @State private var paywallManager: PaywallManager?

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
    }

    // MARK: - Sections

    private var trialPeriodSection: some View {
        let startDateText = (UserDefaults.standard.object(forKey: "first_launch_date") as? Date)?.description ?? "Not set"
        let expiryDateText = subscriptionManager.trialExpiryDate?.description ?? "Not set"

        return Section("Trial Period") {
            LabeledContent("Start Date", value: startDateText)
            LabeledContent("Expiry Date", value: expiryDateText)
            LabeledContent("Days Remaining", value: "\(subscriptionManager.daysRemaining ?? 0)")
            LabeledContent("Status", value: subscriptionManager.status.rawValue)
            LabeledContent("Is In Trial", value: subscriptionManager.isInTrial ? "Yes" : "No")
            LabeledContent("Is Trial Expired", value: subscriptionManager.isTrialExpired ? "Yes" : "No")
            LabeledContent("Is Premium", value: subscriptionManager.isPremium ? "Yes" : "No")

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
        }
    }

    private var heritageUnlocksSection: some View {
        Section("Heritage Unlocks") {
            if let tracker = heritageUnlockTracker {
                LabeledContent("Unlocked", value: "\(tracker.totalUnlockedCount) / 100")
                LabeledContent("Daily Quota", value: "\(tracker.recipesToUnlockToday)")
                LabeledContent("Has Today's Unlock", value: tracker.hasUnlocksAvailableToday ? "Yes" : "No")

                Button("Trigger Daily Unlock") {
                    Task {
                        do {
                            try await tracker.unlockDailyBatch(context: modelContext)
                            Log.info("Manually triggered unlock", category: .general)
                        } catch {
                            Log.error("Failed to unlock", category: .general, metadata: ["error": error.localizedDescription])
                        }
                    }
                }
                .foregroundStyle(.blue)

                Button("Reset Unlock Tracking") {
                    tracker.resetTrialTracking()
                }
                .foregroundStyle(.orange)
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
        heritageUnlockTracker = HeritageUnlockTracker()
        paywallManager = ServiceContainer.shared.resolve(PaywallManager.self)
    }

    private func resetTrial() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: "first_launch_date")
        UserDefaults.standard.set(now.addingTimeInterval(14 * 24 * 60 * 60), forKey: "trial_expiry_date")

        Task {
            await subscriptionManager.refreshStatus(force: true)
        }

        Log.info("Trial reset to Day 1", category: .general)
    }

    private func skipToDay(_ day: Int) {
        let startDate = Date().addingTimeInterval(-TimeInterval(day * 24 * 60 * 60))
        UserDefaults.standard.set(startDate, forKey: "first_launch_date")
        UserDefaults.standard.set(startDate.addingTimeInterval(14 * 24 * 60 * 60), forKey: "trial_expiry_date")

        Task {
            await subscriptionManager.refreshStatus(force: true)
        }

        Log.info("Trial skipped to Day \(day)", category: .general)
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
