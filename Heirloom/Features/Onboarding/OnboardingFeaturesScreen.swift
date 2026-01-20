//
//  OnboardingFeaturesScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-13.
//

import SwiftUI

/// Third onboarding screen - Feature highlights showing what's possible
struct OnboardingFeaturesScreen: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            HeirloomColors.cream.ignoresSafeArea()

            VStack(spacing: HeirloomSpacing.lg) {
                Spacer()
                    .frame(minHeight: 40, maxHeight: 60)

                // Title
                VStack(spacing: HeirloomSpacing.sm) {
                    Text("What you can do")
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.charcoal)
                        .multilineTextAlignment(.center)

                    Text("Beyond just storing recipes")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()
                    .frame(minHeight: 20, maxHeight: 40)

                // Feature cards
                VStack(spacing: 20) {
                    featureCard(
                        icon: "person.2.fill",
                        title: "Share with friends",
                        description: "Send recipes to others and see their variations",
                        color: HeirloomColors.tomato
                    )

                    featureCard(
                        icon: "cart.fill",
                        title: "Smart shopping lists",
                        description: "Automatically generate ingredient lists",
                        color: Color(hex: "#4ECDC4")
                    )

                    featureCard(
                        icon: "calendar",
                        title: "Meal planning",
                        description: "Plan dinner parties or weekly meals",
                        color: Color(hex: "#95E1D3")
                    )
                }
                .padding(.horizontal, 32)

                Spacer()
                    .frame(minHeight: 30, maxHeight: 50)

                // Continue Button
                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                Spacer()
                    .frame(minHeight: 40, maxHeight: 60)
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func featureCard(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.15),
                                color.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            }

            // Text content
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(description)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(HeirloomSpacing.md)
        .background(Color.white.opacity(0.5))
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    OnboardingFeaturesScreen(onContinue: {})
}
