//
//  ASMRUsageBadge.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import SwiftUI

/// Shows current ASMR usage and credits remaining
struct ASMRUsageBadge: View {
    @StateObject private var usageManager = ASMRUsageManager.shared
    @State private var showPaywall = false

    private var subscriptionManager: SubscriptionManager { ServiceContainer.shared.resolve(SubscriptionManager.self) }

    var body: some View {
        let summary = usageManager.getUsageSummary()

        HStack(spacing: 12) {
            // Waveform icon for ASMR
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    summary.extractionsRemaining > 0
                        ? Color.orange.gradient
                        : Color.gray.gradient
                )

            // Usage info
            VStack(alignment: .leading, spacing: 2) {
                if subscriptionManager.isPremium {
                    Text("Unlimited")
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                } else {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Text("\(summary.extractionsRemaining)")
                            .font(.title3.bold())
                            .foregroundStyle(summary.extractionsRemaining > 0 ? .primary : .secondary)
                        Text("/ \(summary.extractionsTotal) left this month")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(subscriptionManager.isPremium ? "Premium ASMR access" : "Resets \(summary.resetDate, format: .dateTime.month().day())")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Upgrade button / Info button
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
        .accessibilityLabel("ASMR extractions: \(summary.extractionsRemaining) of \(summary.extractionsTotal) remaining")
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
