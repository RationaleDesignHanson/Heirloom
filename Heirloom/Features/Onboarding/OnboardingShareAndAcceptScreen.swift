//
//  OnboardingShareAndAcceptScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import SwiftUI

/// Share and Accept screen - Screen 4 of 5
/// Shows the unique intentional sharing model
struct OnboardingShareAndAcceptScreen: View {
    let onContinue: () -> Void

    @State private var showFlow = false

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
                Text("4/5")
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
                            Text("Share recipes that stick")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("Send a recipe. They tap Accept. It's in their box.")
                                .font(HeirloomFonts.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Sharing flow diagram
                        sharingFlowDiagram
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 16)
                }

                // Fixed bottom CTAs
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

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onContinue()
                    }) {
                        Text("Not now")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 4)

                    // Microcopy
                    Text("Sharing is always intentional.")
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
            // Trigger flow animations
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showFlow = true
            }
        }
    }

    // MARK: - Sharing Flow Diagram

    private var sharingFlowDiagram: some View {
        VStack(spacing: 16) {
            // Step 1: You
            senderAvatar
                .opacity(showFlow ? 1 : 0)
                .offset(y: showFlow ? 0 : -20)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: showFlow)

            // Arrow down
            Image(systemName: "arrow.down")
                .font(.title3)
                .foregroundColor(HeirloomColors.tomato)
                .opacity(showFlow ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: showFlow)

            // Step 2: Recipe card with "From You" label
            recipeCard
                .opacity(showFlow ? 1 : 0)
                .offset(y: showFlow ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.7), value: showFlow)

            // Arrow down
            Image(systemName: "arrow.down")
                .font(.title3)
                .foregroundColor(HeirloomColors.tomato)
                .opacity(showFlow ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.9), value: showFlow)

            // Step 3: Recipient with Accept button
            recipientWithAccept
                .opacity(showFlow ? 1 : 0)
                .offset(y: showFlow ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(1.1), value: showFlow)

            // Step 4: Confirmation
            if showFlow {
                confirmationToast
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeOut(duration: 0.3).delay(1.5), value: showFlow)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }

    private var senderAvatar: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(HeirloomColors.warmGray.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundColor(HeirloomColors.warmGray)
                )

            Text("You")
                .font(HeirloomFonts.body)
                .foregroundColor(HeirloomColors.primaryText)
        }
    }

    private var recipeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Recipe image placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(HeirloomColors.warmGray.opacity(0.2))
                .frame(height: 80)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(HeirloomColors.warmGray.opacity(0.5))
                )

            // Recipe name
            Text("Banana Bread Recipe")
                .font(HeirloomFonts.bodyBold)
                .foregroundColor(HeirloomColors.primaryText)

            // From badge
            HStack(spacing: 4) {
                Image(systemName: "person.circle.fill")
                    .font(.caption2)
                Text("From You")
                    .font(HeirloomFonts.caption2)
            }
            .foregroundColor(HeirloomColors.tomato)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(HeirloomColors.tomato.opacity(0.1))
            .cornerRadius(6)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    private var recipientWithAccept: some View {
        VStack(spacing: 10) {
            // Recipient avatar
            Circle()
                .fill(HeirloomColors.tomato.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundColor(HeirloomColors.tomato)
                )

            Text("Them")
                .font(HeirloomFonts.body)
                .foregroundColor(HeirloomColors.primaryText)

            // Accept button mockup
            HStack {
                Text("Accept")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(HeirloomColors.familyGreen)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: HeirloomColors.familyGreen.opacity(0.3), radius: 6, y: 3)
        }
        .padding(.horizontal, 40)
    }

    private var confirmationToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundColor(.white)

            Text("Recipe added to your box")
                .font(HeirloomFonts.caption1)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(HeirloomColors.familyGreen)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview {
    OnboardingShareAndAcceptScreen(
        onContinue: { print("Continue tapped") }
    )
}
