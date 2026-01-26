//
//  OnboardingFlexibilityScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//

import SwiftUI

/// Third onboarding screen - Import flexibility + key features
struct OnboardingFlexibilityScreen: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            // Background with paper texture
            backgroundLayer

            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40)

                    // Title
                    Text("Import from any source")
                        .font(HeirloomFonts.largeTitle)
                        .foregroundStyle(HeirloomColors.charcoal)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .kerning(-0.5)
                        .padding(.horizontal, HeirloomSpacing.onboardingScreenPadding)

                    // Subtitle
                    Text("Plus powerful features to organize and share")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, HeirloomSpacing.sm)

                    // 2x2 Grid of Import Method Cards (compact)
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: HeirloomSpacing.md),
                        GridItem(.flexible(), spacing: HeirloomSpacing.md)
                    ], spacing: HeirloomSpacing.md) {
                        // Share Extension (emphasized)
                        ImportMethodCard(
                            icon: "square.and.arrow.up.fill",
                            title: "Share from apps",
                            subtitle: "TikTok, Instagram, YouTube",
                            accentColor: .purple,
                            isEmphasized: true
                        )

                        // Image Scan
                        ImportMethodCard(
                            icon: "camera.viewfinder",
                            title: "Cookbooks, notes, PDFs & URLs",
                            subtitle: "Scan or upload any format",
                            accentColor: .blue
                        )

                        // Website
                        ImportMethodCard(
                            icon: "globe",
                            title: "Recipe URLs",
                            subtitle: "Any recipe website",
                            accentColor: .green
                        )

                        // Manual
                        ImportMethodCard(
                            icon: "square.and.pencil",
                            title: "Write your own",
                            subtitle: "Create from scratch",
                            accentColor: .orange
                        )
                    }
                    .padding(.horizontal, HeirloomSpacing.lg)
                    .padding(.top, 24)

                    Spacer()
                        .frame(height: 40)

                    // Continue Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                    .padding(.horizontal, HeirloomSpacing.onboardingScreenPadding)

                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }

    // MARK: - Subviews

    private var backgroundLayer: some View {
        ZStack {
            HeirloomColors.cream
                .ignoresSafeArea()

            // Subtle paper texture overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.clear,
                            Color.black.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
                .blendMode(.overlay)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlexibilityScreen(onContinue: {})
}
