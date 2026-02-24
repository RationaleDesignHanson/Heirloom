//
//  NeedCreditsSheet.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-19.
//

import SwiftUI

/// Reusable sheet shown when user tries to access a premium feature without enough credits
/// Explains what's needed and provides a path to purchase credits
struct NeedCreditsSheet: View {
    let creditsNeeded: Int
    let currentCredits: Int
    let featureName: String
    let onBuyCredits: () -> Void
    let onCancel: () -> Void
    /// Optional callback to show subscription plans (for non-premium users)
    var onViewSubscription: (() -> Void)?

    private var shortfall: Int {
        max(0, creditsNeeded - currentCredits)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header icon
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(HeirloomColors.tomato.gradient)
                .padding(.top, 20)

            // Title and explanation
            VStack(spacing: 12) {
                Text("Credits Needed")
                    .font(.title2.bold())

                Text("\(featureName) requires \(creditsNeeded) credit\(creditsNeeded == 1 ? "" : "s").")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Credit status card
            VStack(spacing: 12) {
                HStack {
                    Text("Your credits")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(currentCredits)")
                        .font(.headline)
                        .foregroundStyle(currentCredits > 0 ? HeirloomColors.familyGreen : .red)
                }

                HStack {
                    Text("Required")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(creditsNeeded)")
                        .font(.headline)
                }

                Divider()

                HStack {
                    Text("Need")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(shortfall) more credit\(shortfall == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    onBuyCredits()
                } label: {
                    HStack {
                        Image(systemName: "creditcard")
                        Text("Get Credits")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.tomato)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }

                // Subscription option (for non-premium users)
                if let onViewSubscription {
                    Button {
                        onViewSubscription()
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("View Subscription Plans")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(HeirloomColors.familyGreen)
                        .padding(.vertical, 8)
                    }
                }

                Button {
                    onCancel()
                } label: {
                    Text("Maybe Later")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Preview

#Preview {
    NeedCreditsSheet(
        creditsNeeded: 1,
        currentCredits: 0,
        featureName: "AI Background Generation",
        onBuyCredits: { print("Buy credits tapped") },
        onCancel: { print("Cancel tapped") },
        onViewSubscription: { print("View subscription tapped") }
    )
}
