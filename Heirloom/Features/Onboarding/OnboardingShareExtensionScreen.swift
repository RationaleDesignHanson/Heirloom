//
//  OnboardingShareExtensionScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//  Updated for new 5-screen onboarding flow on 2026-02-01
//  Updated with real screenshots on 2026-02-06
//

import SwiftUI

/// Share Sheet Aha screen - Screen 3 of 5
/// Teaches the core one-tap save workflow with real screenshots
struct OnboardingShareExtensionScreen: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90), // Warm cream
                    Color(red: 0.95, green: 0.90, blue: 0.85)  // Soft beige
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                Text("3/5")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Scrollable content
                GeometryReader { geometry in
                    ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Save from anywhere")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("See a recipe? Share it to Heirloom.")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Side-by-side screenshots
                        screenshotPair
                            .padding(.horizontal, 16)

                        // Coach mark tip
                        coachMarkTip
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                }

                // Fixed bottom CTAs
                VStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onContinue()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(HeirloomColors.tomato)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: HeirloomColors.tomato.opacity(0.3), radius: 12, y: 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.90, blue: 0.85).opacity(0),
                            Color(red: 0.95, green: 0.90, blue: 0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    // MARK: - Screenshot Pair

    private var screenshotPair: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step 1: Share sheet
            VStack(spacing: 10) {
                phoneFrame(imageName: "onboarding-share-sheet")

                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(HeirloomColors.tomato)

                    Text("Tap Heirloom")
                        .font(HeirloomFonts.caption1)
                        .fontWeight(.semibold)
                        .foregroundColor(HeirloomColors.primaryText)
                }
            }

            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(HeirloomColors.tomato.opacity(0.6))
                .padding(.top, 140)

            // Step 2: Recipe saved
            VStack(spacing: 10) {
                phoneFrame(imageName: "onboarding-recipe-saved")

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)

                    Text("Recipe saved!")
                        .font(HeirloomFonts.caption1)
                        .fontWeight(.semibold)
                        .foregroundColor(HeirloomColors.primaryText)
                }
            }
        }
    }

    // MARK: - Phone Frame

    private func phoneFrame(imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    // MARK: - Coach Mark Tip

    private var coachMarkTip: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))

            Text("Tip: You can also tap + in Heirloom to paste a link")
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    OnboardingShareExtensionScreen(onContinue: {})
}
