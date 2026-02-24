//
//  ASMRUsageBadge.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import SwiftUI
import SwiftData

/// Shows current credit balance for ASMR operations
/// Uses unified UserCredits system (no more ASMRUsageManager)
struct ASMRUsageBadge: View {
    @Query private var allUserCredits: [UserCredits]
    @State private var showPaywall = false

    private var subscriptionManager: SubscriptionManager { ServiceContainer.shared.resolve(SubscriptionManager.self) }

    private var userCredits: UserCredits? {
        allUserCredits.first
    }

    private var availableCredits: Int {
        userCredits?.availableCredits ?? 0
    }

    private var canAffordASMR: Bool {
        availableCredits >= 5
    }

    var body: some View {
        HStack(spacing: 12) {
            // Waveform icon for ASMR
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    canAffordASMR
                        ? Color.orange.gradient
                        : Color.gray.gradient
                )

            // Usage info - unified display for all tiers
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: HeirloomSpacing.xs) {
                    Text("\(availableCredits)")
                        .font(.title3.bold())
                        .foregroundStyle(canAffordASMR ? .primary : .secondary)
                    Text("credits available")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(.secondary)
                }

                Text("ASMR extraction costs 5 credits")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Upgrade/status button
            Button {
                showPaywall = true
            } label: {
                Image(systemName: subscriptionManager.isPremium ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(subscriptionManager.isPremium ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ASMR: \(availableCredits) credits available, costs 5 per extraction")
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

#Preview {
    VStack(spacing: HeirloomSpacing.md) {
        ASMRUsageBadge()
            .padding()

        Text("Preview")
            .font(HeirloomFonts.caption1)
            .foregroundStyle(.secondary)
    }
}
