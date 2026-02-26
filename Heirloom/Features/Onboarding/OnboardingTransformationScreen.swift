//
//  OnboardingTransformationScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-25.
//  "Heirloom structures them for you" - AI transformation demo
//

import SwiftUI

/// Transformation screen - Screen 2 of 7
/// Shows messy input → clean recipe card transformation
struct OnboardingTransformationScreen: View {
    let onContinue: () -> Void

    // Animation states
    @State private var showMessy = false
    @State private var showArrow = false
    @State private var showClean = false
    @State private var pulseArrow = false

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
                Text("2/7")
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
                                Text("Heirloom structures them for you")
                                    .font(HeirloomFonts.title1Elevated)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                                    .kerning(-0.5)

                                Text("Heirloom reads, understands, and organizes — automatically.")
                                    .font(HeirloomFonts.body)
                                    .foregroundColor(HeirloomColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                            // Transformation visual
                            transformationVisual
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
        // Show messy input
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            showMessy = true
        }

        // Show arrow
        withAnimation(.easeOut(duration: 0.3).delay(0.7)) {
            showArrow = true
        }

        // Show clean result
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(1.0)) {
            showClean = true
        }

        // Pulse arrow
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseArrow = true
            }
        }
    }

    // MARK: - Transformation Visual

    private var transformationVisual: some View {
        HStack(spacing: 16) {
            // Left: Messy input
            messyInputCard
                .opacity(showMessy ? 1 : 0)
                .offset(x: showMessy ? 0 : -30)

            // Middle: Arrow
            transformArrow
                .opacity(showArrow ? 1 : 0)
                .scaleEffect(showArrow ? 1 : 0.5)

            // Right: Clean recipe
            cleanRecipeCard
                .opacity(showClean ? 1 : 0)
                .offset(x: showClean ? 0 : 30)
                .scaleEffect(showClean ? 1 : 0.95)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Messy Input Card

    private var messyInputCard: some View {
        VStack(spacing: 0) {
            // Simulated screenshot/photo
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)

                VStack(alignment: .leading, spacing: 4) {
                    // Messy text lines
                    messyTextLine(width: 0.9)
                    messyTextLine(width: 0.7)
                    messyTextLine(width: 0.85)
                    messyTextLine(width: 0.6)
                    messyTextLine(width: 0.75)
                    messyTextLine(width: 0.5)
                    messyTextLine(width: 0.8)
                }
                .padding(12)
            }
            .frame(width: 120, height: 160)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)

            // Label
            Text("Screenshot")
                .font(HeirloomFonts.caption2)
                .foregroundColor(HeirloomColors.secondaryText)
                .padding(.top, 8)
        }
    }

    private func messyTextLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.gray.opacity(0.3))
            .frame(height: 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaleEffect(x: width, anchor: .leading)
    }

    // MARK: - Transform Arrow

    private var transformArrow: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundColor(HeirloomColors.tomato)
                .opacity(pulseArrow ? 1 : 0.6)
                .scaleEffect(pulseArrow ? 1.1 : 1.0)

            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(HeirloomColors.tomato)
        }
        .frame(width: 36)
    }

    // MARK: - Clean Recipe Card

    private var cleanRecipeCard: some View {
        VStack(spacing: 0) {
            // Recipe card preview
            VStack(alignment: .leading, spacing: 8) {
                // Recipe image placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [HeirloomColors.tomato.opacity(0.3), HeirloomColors.tomato.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 60)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 20))
                            .foregroundColor(HeirloomColors.tomato.opacity(0.5))
                    )

                // Title
                Text("Grandma's Brisket")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(HeirloomColors.primaryText)

                // Meta info
                HStack(spacing: 8) {
                    Label("45m", systemImage: "clock")
                    Label("8", systemImage: "person.2")
                }
                .font(.system(size: 9))
                .foregroundColor(HeirloomColors.secondaryText)

                // Ingredients preview
                VStack(alignment: .leading, spacing: 2) {
                    ingredientLine("3 cups flour")
                    ingredientLine("1 cup butter")
                    ingredientLine("4 apples, sliced")
                }
            }
            .padding(10)
            .frame(width: 120)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

            // Label
            Text("Structured")
                .font(HeirloomFonts.caption2)
                .foregroundColor(HeirloomColors.secondaryText)
                .padding(.top, 8)
        }
    }

    private func ingredientLine(_ text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(HeirloomColors.familyGreen)
                .frame(width: 4, height: 4)
            Text(text)
                .font(.system(size: 8))
                .foregroundColor(HeirloomColors.secondaryText)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingTransformationScreen(
        onContinue: { print("Continue tapped") }
    )
}
