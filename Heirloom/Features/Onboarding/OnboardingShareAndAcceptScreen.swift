//
//  OnboardingShareAndAcceptScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//  Task 4: Chat-style P2P sharing animation
//

import SwiftUI

/// Share and Accept screen - Screen 4 of 5
/// Shows the P2P sharing model with chat-style interaction
struct OnboardingShareAndAcceptScreen: View {
    let onContinue: () -> Void

    @State private var showRecipeCard = false
    @State private var showAcceptSheet = false
    @State private var showCheckmark = false
    @State private var showConfirmation = false

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

                            Text("Send to friends and family. They'll have it forever.")
                                .font(HeirloomFonts.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Chat-style mockup
                        chatMockup
                            .padding(.horizontal, 24)

                        // Differentiator callout
                        differentiatorCallout
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
        // Step 1: Recipe card slides in from right
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            showRecipeCard = true
        }

        // Step 2: Accept sheet slides up after 1s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showAcceptSheet = true
            }
        }

        // Step 3: Checkmark appears after 0.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCheckmark = true
            }
        }

        // Step 4: Confirmation text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfirmation = true
            }
        }
    }

    // MARK: - Chat Mockup

    private var chatMockup: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Circle()
                    .fill(HeirloomColors.tomato.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(HeirloomColors.tomato)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mom")
                        .font(.system(size: 15, weight: .semibold))
                    Text("via Heirloom")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)

            Divider()

            // Chat content area
            ZStack(alignment: .bottom) {
                // Chat background
                Color(UIColor.systemGroupedBackground)
                    .frame(height: 280)

                VStack(spacing: 12) {
                    // Sender message (recipe card from right)
                    if showRecipeCard {
                        HStack {
                            Spacer()
                            senderRecipeMessage
                        }
                        .padding(.horizontal, 12)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    Spacer()
                }
                .padding(.top, 16)

                // Accept sheet (slides up from bottom)
                if showAcceptSheet {
                    acceptSheet
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
    }

    // MARK: - Sender Recipe Message

    private var senderRecipeMessage: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Recipe card bubble
            VStack(alignment: .leading, spacing: 8) {
                // Recipe thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 160, height: 90)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.title)
                            .foregroundColor(.orange.opacity(0.6))
                    )

                Text("Pasta Carbonara")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Here's that pasta recipe you wanted!")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(16)

            Text("Just now")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Accept Sheet

    private var acceptSheet: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            // Content
            VStack(spacing: 16) {
                // Recipe preview
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .foregroundColor(.orange.opacity(0.6))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pasta Carbonara")
                            .font(.system(size: 15, weight: .semibold))
                        Text("From Mom")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)

                // Accept button
                Button(action: {}) {
                    HStack(spacing: 8) {
                        if showCheckmark {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text(showCheckmark ? "Added!" : "Accept Recipe")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(showCheckmark ? HeirloomColors.familyGreen : HeirloomColors.tomato)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .disabled(true)

                // Confirmation text
                if showConfirmation {
                    Text("Added to their recipe box")
                        .font(.system(size: 13))
                        .foregroundColor(HeirloomColors.familyGreen)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
    }

    // MARK: - Differentiator Callout

    private var differentiatorCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(HeirloomColors.familyGreen)
                .font(.system(size: 18))

            Text("Unlike screenshots, shared recipes stay organized and searchable")
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(HeirloomColors.familyGreen.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Corner Radius Extension

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    OnboardingShareAndAcceptScreen(
        onContinue: { print("Continue tapped") }
    )
}
