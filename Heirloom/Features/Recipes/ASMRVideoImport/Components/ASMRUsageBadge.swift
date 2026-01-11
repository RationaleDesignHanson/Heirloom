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

    var body: some View {
        let summary = usageManager.getUsageSummary()

        HStack(spacing: 12) {
            // Star icon
            Image(systemName: "star.circle.fill")
                .font(.title2)
                .foregroundStyle(.yellow.gradient)

            // Usage info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(summary.extractionsRemaining)")
                        .font(.title3.bold())
                    Text("/ \(summary.extractionsTotal) left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Resets \(summary.resetDate, format: .dateTime.month().day())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Upgrade button for free users
            if !summary.isProUser {
                Button {
                    // TODO: Show subscription paywall
                } label: {
                    Text("Upgrade")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ASMR extractions: \(summary.extractionsRemaining) of \(summary.extractionsTotal) remaining")
    }
}

#Preview {
    VStack(spacing: 16) {
        ASMRUsageBadge()
            .padding()

        Text("Preview")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
