//
//  OnboardingScreen1.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import SwiftUI

/// First onboarding screen - Value propositions
struct OnboardingScreen1: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            // Background
            HeirloomColors.cream
                .ignoresSafeArea()

            VStack(spacing: 48) {
                Spacer()

                // App Icon & Title
                VStack(spacing: 16) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Heirloom")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundStyle(HeirloomColors.charcoal)

                    Text("Recipes worth passing down")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                // Feature Rows
                VStack(spacing: 20) {
                    featureRow(
                        icon: "link.circle.fill",
                        title: "Import from anywhere",
                        description: "Recipe sites, cookbooks, or handwritten cards"
                    )

                    featureRow(
                        icon: "sparkles",
                        title: "Heritage Collections",
                        description: "Start with curated recipes from different cultures"
                    )

                    featureRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Sync across devices",
                        description: "Your recipes everywhere you cook"
                    )

                    featureRow(
                        icon: "square.and.arrow.up",
                        title: "Own your data",
                        description: "Export anytime—no lock-in"
                    )
                }
                .padding(.horizontal, 32)

                Spacer()

                // Get Started Button
                Button {
                    onContinue()
                } label: {
                    Text("Get Started")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(HeirloomFonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.charcoal)

                Text(description)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingScreen1(onContinue: {})
}
