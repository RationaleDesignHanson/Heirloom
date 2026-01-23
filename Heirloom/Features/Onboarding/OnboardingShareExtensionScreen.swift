//
//  OnboardingShareExtensionScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//

import SwiftUI

/// Second onboarding screen - Share Extension tutorial
struct OnboardingShareExtensionScreen: View {
    let onContinue: () -> Void

    @State private var isAnimated = false

    var body: some View {
        ZStack {
            // Background with paper texture
            backgroundLayer

            VStack(spacing: 0) {
                Spacer()
                    .frame(minHeight: 30, maxHeight: 50)

                // Title
                Text("Share from anywhere")
                    .font(HeirloomFonts.title1)
                    .foregroundStyle(HeirloomColors.charcoal)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Subtitle
                Text("One tap from the apps you already use")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                // Share sheet mockup
                shareSheetMock
                    .padding(.top, 32)
                    .padding(.horizontal, 32)

                // Platform flow
                platformFlow
                    .padding(.top, 28)
                    .padding(.horizontal, 32)

                // 3-step tutorial
                tutorialSteps
                    .padding(.top, 28)
                    .padding(.horizontal, 40)

                Spacer()
                    .frame(minHeight: 20, maxHeight: 40)

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
                    .frame(minHeight: 30, maxHeight: 50)
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
                                .fill(HeirloomColors.tomato)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .strokeBorder(HeirloomColors.tomato, lineWidth: 2)
                                        .scaleEffect(isAnimated ? 1.3 : 1.0)
                                        .opacity(isAnimated ? 0.0 : 0.5)
                                )

                            Image(systemName: "book.fill")
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
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
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
            tutorialStep(number: "1", text: "Find recipe video")
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
