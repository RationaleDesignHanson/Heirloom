//
//  OnboardingHowToSaveScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-25.
//  "Two ways to save recipes" - Share extension + In-app menu
//

import SwiftUI

/// How to Save screen - Screen 5 of 7
/// Shows two paths: Share extension (from any app) and In-app menu (inside Heirloom)
struct OnboardingHowToSaveScreen: View {
    let onContinue: () -> Void

    // Animation states
    @State private var showLeftCard = false
    @State private var showRightCard = false

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
                Text("5/7")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Scrollable content
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 12) {
                                Text("Two ways to save recipes")
                                    .font(HeirloomFonts.title1Elevated)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                                    .kerning(-0.5)

                                Text("Save from anywhere, or create inside the app.")
                                    .font(HeirloomFonts.body)
                                    .foregroundColor(HeirloomColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                            // Side-by-side cards
                            twoPathsView
                                .padding(.horizontal, 24)
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
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
            showLeftCard = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
            showRightCard = true
        }
    }

    // MARK: - Two Paths View

    private var twoPathsView: some View {
        HStack(spacing: 16) {
            // Left: Share Extension
            pathCard(
                icon: "square.and.arrow.up",
                iconColor: HeirloomColors.tomato,
                title: "Share Extension",
                subtitle: "From any app",
                examples: ["TikTok / IG videos", "Safari", "Photos", "Notes"],
                isLeft: true
            )
            .opacity(showLeftCard ? 1 : 0)
            .offset(x: showLeftCard ? 0 : -30)

            // Right: In-app Menu
            pathCard(
                icon: "plus.circle.fill",
                iconColor: HeirloomColors.familyGreen,
                title: "+ Menu",
                subtitle: "Inside Heirloom",
                examples: ["Video", "Voice", "Camera", "Generate"],
                isLeft: false
            )
            .opacity(showRightCard ? 1 : 0)
            .offset(x: showRightCard ? 0 : 30)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Path Card

    private func pathCard(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        examples: [String],
        isLeft: Bool
    ) -> some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
            }

            // Title & subtitle
            VStack(spacing: 4) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundColor(HeirloomColors.primaryText)

                Text(subtitle)
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
            }

            // Examples
            VStack(spacing: 6) {
                ForEach(examples, id: \.self) { example in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(iconColor.opacity(0.5))
                            .frame(width: 5, height: 5)
                        Text(example)
                            .font(.system(size: 12))
                            .foregroundColor(HeirloomColors.secondaryText)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview {
    OnboardingHowToSaveScreen(
        onContinue: { print("Continue tapped") }
    )
}
