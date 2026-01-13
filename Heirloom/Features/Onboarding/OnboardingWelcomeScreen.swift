//
//  OnboardingWelcomeScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-12.
//

import SwiftUI

/// First onboarding screen - Welcome and value proposition
struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            // Background with paper texture (identical to ImportMethodsScreen)
            backgroundLayer

            VStack(spacing: 0) {
                Spacer()

                // App Icon
                Image("ceramic-hero-book")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)

                // App Name
                Text("Heirloom")
                    .font(HeirloomFonts.largeTitle)
                    .foregroundStyle(HeirloomColors.charcoal)
                    .padding(.top, 16)

                // Tagline
                Text("Keep your favorite recipes and share with your community")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.charcoal)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 32)

                // Value Props
                VStack(alignment: .leading, spacing: 12) {
                    valueProposition(icon: "arrow.down.doc.fill", text: "Import from anywhere - videos, websites, photos")
                    valueProposition(icon: "square.grid.2x2.fill", text: "Organize with beautiful collections")
                    valueProposition(icon: "person.2.fill", text: "Share with your community")
                }
                .padding(.top, 40)
                .padding(.horizontal, 40)

                Spacer()
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

    /// Background layer matching ImportMethodsScreen styling
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

    private func valueProposition(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 20)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingWelcomeScreen(onContinue: {})
}
