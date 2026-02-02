//
//  OnboardingShareExtensionScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//  Updated for new 5-screen onboarding flow on 2026-02-01
//

import SwiftUI

/// Share Sheet Aha screen - Screen 3 of 5
/// Teaches the core one-tap save workflow
struct OnboardingShareExtensionScreen: View {
    let onContinue: () -> Void

    @State private var isAnimated = false

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
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Save from anywhere")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("Tap Share → Save to Heirloom. Done.")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Share sheet mockup
                        shareSheetMock
                            .padding(.horizontal, 24)

                        // 3-step tutorial
                        tutorialSteps
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 16)
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

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onContinue()
                    } label: {
                        Text("Show me later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 4)

                    // Microcopy
                    Text("Works from Safari, PDFs, and videos.")
                        .font(HeirloomFonts.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                isAnimated = true
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

    private var shareSheetMock: some View {
        VStack(spacing: 12) {
            // Mock iOS share sheet
            VStack(spacing: 16) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)

                // Share sheet apps row
                HStack(spacing: 24) {
                    // Other apps (grayed out)
                    shareAppIcon("message.fill", color: .gray.opacity(0.4), label: "Messages")
                    shareAppIcon("mail.fill", color: .gray.opacity(0.4), label: "Mail")

                    // Heirloom app (highlighted)
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .strokeBorder(HeirloomColors.tomato, lineWidth: 2)
                                .scaleEffect(isAnimated ? 1.3 : 1.0)
                                .opacity(isAnimated ? 0.0 : 0.5)
                                .frame(width: 50, height: 50)

                            // Realistic Heirloom app icon representation
                            Circle()
                                .fill(HeirloomColors.tomato)
                                .frame(width: 50, height: 50)

                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }

                        Text("Heirloom")
                            .font(.caption2)
                            .foregroundStyle(HeirloomColors.charcoal)
                            .fontWeight(.medium)
                    }

                    // More apps (grayed out)
                    shareAppIcon("square.and.arrow.up.fill", color: .gray.opacity(0.4), label: "More")
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(.white)
            .cornerRadius(16)
            .heirloomShadow(HeirloomShadows.elevated)
        }
    }

    private func shareAppIcon(_ systemName: String, color: Color, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 50, height: 50)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.gray)
        }
    }

    private var platformFlow: some View {
        VStack(spacing: 12) {
            Text("Works from any app")
                .font(HeirloomFonts.caption1Bold)
                .foregroundStyle(HeirloomColors.charcoal)

            HStack(spacing: 12) {
                // Platform icons flowing to Heirloom
                platformIconSmall("play.square.stack", color: .pink)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundStyle(HeirloomColors.secondaryText)

                platformIconSmall("camera", color: .purple)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundStyle(HeirloomColors.secondaryText)

                platformIconSmall("play.rectangle", color: .red)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundStyle(HeirloomColors.secondaryText)

                // Heirloom icon (destination)
                ZStack {
                    Circle()
                        .fill(HeirloomColors.tomato)
                        .frame(width: 32, height: 32)

                    Image(systemName: "book.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func platformIconSmall(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.1))
            .cornerRadius(6)
    }

    private var tutorialSteps: some View {
        VStack(alignment: .leading, spacing: 16) {
            tutorialStep(number: "1", text: "See recipe")
            tutorialStep(number: "2", text: "Tap Share → Heirloom")
            tutorialStep(number: "3", text: "Recipe saved automatically")
        }
    }

    private func tutorialStep(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            // Number circle
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(HeirloomColors.tomato)
                .cornerRadius(14)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingShareExtensionScreen(onContinue: {})
}
