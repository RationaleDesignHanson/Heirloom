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
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.charcoal)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // Subtitle
                    Text("Plus powerful features to organize and share")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)

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

                    // Divider
                    Rectangle()
                        .fill(HeirloomColors.secondaryText.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 24)

                    // Feature Pills Section
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("Key Features")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.charcoal)
                            .padding(.horizontal, HeirloomSpacing.lg)
                            .padding(.bottom, 8)

                        VStack(spacing: HeirloomSpacing.sm) {
                            FeaturePill(
                                icon: "arrow.triangle.branch",
                                title: "Recipe Lineage",
                                description: "Track recipe versions and edits"
                            )

                            FeaturePill(
                                icon: "person.text.rectangle",
                                title: "Creator Attribution",
                                description: "Auto-credits original creators"
                            )

                            FeaturePill(
                                icon: "calendar",
                                title: "Meal Planning",
                                description: "Plan weekly meals & dinner parties"
                            )
                        }
                        .padding(.horizontal, HeirloomSpacing.lg)
                    }

                    Spacer()
                        .frame(height: 24)

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
                    .padding(.horizontal, 32)

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
