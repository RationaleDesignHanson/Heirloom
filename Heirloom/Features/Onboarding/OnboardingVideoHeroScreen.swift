//
//  OnboardingVideoHeroScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//

import SwiftUI

/// First onboarding screen - Video-to-Recipe hero with AI extraction showcase
struct OnboardingVideoHeroScreen: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            // Background with paper texture
            backgroundLayer

            VStack(spacing: 0) {
                Spacer()
                    .frame(minHeight: 30, maxHeight: 50)

                // Title
                Text("Recipes from your\nfavorite creators")
                    .font(HeirloomFonts.largeTitle)
                    .foregroundStyle(HeirloomColors.charcoal)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .kerning(-0.5)
                    .padding(.horizontal, HeirloomSpacing.onboardingScreenPadding)

                // Subtitle
                Text("AI extracts ingredients and steps from cooking videos")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, HeirloomSpacing.sm)

                // Mock video card
                videoCardMock
                    .padding(.top, HeirloomSpacing.onboardingSectionSpacing)
                    .padding(.horizontal, HeirloomSpacing.onboardingScreenPadding)

                // 3-Tier Extraction Showcase
                ThreeTierExtractionView()
                    .padding(.top, HeirloomSpacing.onboardingSectionSpacing)
                    .padding(.horizontal, HeirloomSpacing.lg)

                // Platform support
                platformSupport
                    .padding(.top, HeirloomSpacing.lg)

                Spacer()
                    .frame(minHeight: 20, maxHeight: 40)

                // Continue Button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onContinue()
                } label: {
                    Text("See How It Works")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
                .padding(.horizontal, HeirloomSpacing.onboardingScreenPadding)

                Spacer()
                    .frame(minHeight: 30, maxHeight: 50)
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

    private var videoCardMock: some View {
        ZStack {
            // Background gradient (pasta colors)
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.3),
                    Color.red.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Play button overlay
            Image(systemName: "play.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            // Creator attribution badge (top left)
            VStack {
                HStack {
                    CreatorAttributionBadge(
                        platform: .tiktok,
                        attribution: "@gordonramsay",
                        size: .medium
                    )
                    .padding(12)

                    Spacer()
                }
                Spacer()
            }

            // AI powered badge (top right)
            VStack {
                HStack {
                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("AI powered")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    .padding(12)
                }
                Spacer()
            }
        }
        .frame(height: 200)
        .frame(maxWidth: 180)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
        .cornerRadius(12)
        .heirloomShadow(HeirloomShadows.elevated)
    }

    private var platformSupport: some View {
        VStack(spacing: 8) {
            Text("Works with TikTok, Instagram, YouTube, and more")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            HStack(spacing: 16) {
                platformIcon("play.square.stack", color: .pink) // TikTok
                platformIcon("camera", color: .purple) // Instagram
                platformIcon("play.rectangle", color: .red) // YouTube
                platformIcon("safari", color: .blue) // Safari
            }
        }
    }

    private func platformIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20))
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background(color.opacity(0.1))
            .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    OnboardingVideoHeroScreen(onContinue: {})
}
