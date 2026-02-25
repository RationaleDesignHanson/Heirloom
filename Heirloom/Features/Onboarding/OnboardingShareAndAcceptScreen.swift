//
//  OnboardingShareAndAcceptScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//  Generational lineage timeline animation
//

import SwiftUI

/// Lineage screen - shows generational recipe history
/// "Recipes have history" - the emotional core of preservation
struct OnboardingShareAndAcceptScreen: View {
    let onContinue: () -> Void

    // Timeline animation states
    @State private var showRecipeCard = false
    @State private var showGrandma = false
    @State private var showMom = false
    @State private var showYou = false
    @State private var showFuture = false

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
                Text("4/5")
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
                                Text("Recipes have history")
                                    .font(HeirloomFonts.title1Elevated)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                                    .kerning(-0.5)

                                Text("Track where they came from — and who you'll pass them to.")
                                    .font(HeirloomFonts.body)
                                    .foregroundColor(HeirloomColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                            // Timeline demo
                            timelineView
                                .padding(.horizontal, 24)

                            // Differentiator callout
                            differentiatorCallout
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
        // Show recipe card
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                showRecipeCard = true
            }
        }

        // Show Grandma Kay (origin)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showGrandma = true
            }
        }

        // Show Mom (adaptation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showMom = true
            }
        }

        // Show You (current)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showYou = true
            }
        }

        // Show future hint
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeOut(duration: 0.5)) {
                showFuture = true
            }
        }
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        HStack(alignment: .top, spacing: 20) {
            // Recipe card
            recipeCard
                .opacity(showRecipeCard ? 1 : 0)
                .scaleEffect(showRecipeCard ? 1 : 0.9)

            // Timeline
            VStack(alignment: .leading, spacing: 0) {
                // Future hint
                if showFuture {
                    timelineFutureNode
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // You (current)
                if showYou {
                    timelineNode(
                        name: "You",
                        detail: "Your version",
                        isCurrentUser: true
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Mom
                if showMom {
                    timelineNode(
                        name: "Mom",
                        detail: "Added red wine",
                        isCurrentUser: false
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Grandma Kay (origin)
                if showGrandma {
                    timelineNode(
                        name: "Grandma Kay",
                        detail: "The original",
                        isCurrentUser: false,
                        isOrigin: true
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Recipe Card

    private var recipeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recipe thumbnail
            Image("onboarding-pot-roast")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("Nana's Pot Roast")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("A family classic")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 144)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Timeline Node

    private func timelineNode(
        name: String,
        detail: String,
        isCurrentUser: Bool,
        isOrigin: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline connector
            VStack(spacing: 0) {
                // Dot
                Circle()
                    .fill(isCurrentUser ? HeirloomColors.tomato : HeirloomColors.familyGreen)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(color: (isCurrentUser ? HeirloomColors.tomato : HeirloomColors.familyGreen).opacity(0.3), radius: 4)

                // Line (not shown for origin)
                if !isOrigin {
                    Rectangle()
                        .fill(HeirloomColors.warmGray.opacity(0.3))
                        .frame(width: 2, height: 32)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HeirloomColors.primaryText)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(HeirloomColors.secondaryText)
                    .italic()
            }
            .padding(.bottom, isOrigin ? 0 : 20)
        }
    }

    // MARK: - Future Node

    private var timelineFutureNode: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline connector (dashed)
            VStack(spacing: 0) {
                // Dashed line going up
                Rectangle()
                    .fill(HeirloomColors.warmGray.opacity(0.2))
                    .frame(width: 2, height: 24)
                    .mask(
                        VStack(spacing: 4) {
                            ForEach(0..<4, id: \.self) { _ in
                                Rectangle()
                                    .frame(height: 4)
                            }
                        }
                    )

                // Empty dot (future)
                Circle()
                    .stroke(HeirloomColors.warmGray.opacity(0.4), lineWidth: 2)
                    .frame(width: 12, height: 12)

                // Line down to "You"
                Rectangle()
                    .fill(HeirloomColors.warmGray.opacity(0.3))
                    .frame(width: 2, height: 16)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text("Pass it on...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(HeirloomColors.secondaryText.opacity(0.7))
                    .italic()
            }
            .padding(.top, 20)
            .padding(.bottom, 8)
        }
        .opacity(0.8)
    }

    // MARK: - Differentiator Callout

    private var differentiatorCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(HeirloomColors.familyGreen)
                .font(.system(size: 18))

            Text("Every recipe remembers where it came from")
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(HeirloomColors.familyGreen.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    OnboardingShareAndAcceptScreen(
        onContinue: { print("Continue tapped") }
    )
}
