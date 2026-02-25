//
//  OnboardingPrivacyScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-25.
//  "Private by default" - Trust building screen
//

import SwiftUI

/// Privacy screen - Screen 4 of 7
/// Establishes trust: "Private by default, shared on your terms"
struct OnboardingPrivacyScreen: View {
    let onContinue: () -> Void

    // Animation states
    @State private var showLock = false
    @State private var showPoints = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90),
                    Color(red: 0.95, green: 0.90, blue: 0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                Text("4/7")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Scrollable content
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 32) {
                            // Header
                            VStack(spacing: 12) {
                                Text("Private by default")
                                    .font(HeirloomFonts.title1Elevated)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                                    .kerning(-0.5)

                                Text("Your recipes stay yours. Share only when you choose.")
                                    .font(HeirloomFonts.body)
                                    .foregroundColor(HeirloomColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                            // Lock visual
                            privacyVisual
                                .opacity(showLock ? 1 : 0)
                                .scaleEffect(showLock ? 1 : 0.8)

                            // Privacy points
                            privacyPoints
                                .padding(.horizontal, 24)
                                .opacity(showPoints ? 1 : 0)
                                .offset(y: showPoints ? 0 : 20)

                            // Differentiator
                            differentiatorCallout
                                .padding(.horizontal, 24)
                                .opacity(showPoints ? 1 : 0)
                        }
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                }

                // Fixed bottom CTA
                VStack(spacing: 12) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onContinue()
                    }) {
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
        .onAppear {
            startAnimationSequence()
        }
    }

    // MARK: - Animation Sequence

    private func startAnimationSequence() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
            showLock = true
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            showPoints = true
        }
    }

    // MARK: - Privacy Visual

    private var privacyVisual: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(HeirloomColors.familyGreen.opacity(0.1))
                .frame(width: 140, height: 140)

            // Inner circle
            Circle()
                .fill(HeirloomColors.familyGreen.opacity(0.2))
                .frame(width: 100, height: 100)

            // Lock icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(HeirloomColors.familyGreen)
        }
    }

    // MARK: - Privacy Points

    private var privacyPoints: some View {
        VStack(spacing: 16) {
            privacyPointRow(
                icon: "eye.slash.fill",
                title: "Your recipes stay private",
                subtitle: "Nothing is public unless you share it"
            )

            privacyPointRow(
                icon: "person.2.fill",
                title: "Share with specific people",
                subtitle: "Family and friends you choose, not the world"
            )

            privacyPointRow(
                icon: "hand.raised.fill",
                title: "You control access",
                subtitle: "Revoke sharing anytime"
            )

            privacyPointRow(
                icon: "globe",
                title: "Share publicly if it's yours",
                subtitle: "Your original recipes can be published"
            )
        }
    }

    private func privacyPointRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(HeirloomColors.familyGreen.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(HeirloomColors.familyGreen)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundColor(HeirloomColors.primaryText)

                Text(subtitle)
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
            }

            Spacer()
        }
    }

    // MARK: - Differentiator Callout

    private var differentiatorCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .foregroundColor(HeirloomColors.tomato)
                .font(.system(size: 16))

            Text("Unlike social recipe apps, Heirloom is for your family first.")
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(HeirloomColors.tomato.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    OnboardingPrivacyScreen(
        onContinue: { print("Continue tapped") }
    )
}
