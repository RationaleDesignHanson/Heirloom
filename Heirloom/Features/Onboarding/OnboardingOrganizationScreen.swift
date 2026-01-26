//
//  OnboardingOrganizationScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//

import SwiftUI

/// Fourth onboarding screen - Heirloom sharing feature
struct OnboardingOrganizationScreen: View {
    let onContinue: () -> Void

    @State private var animateShare = false
    @State private var showLineage = false

    var body: some View {
        ZStack {
            HeirloomColors.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Title
                Text("Share family recipes\nwith family")
                    .font(HeirloomFonts.largeTitle)
                    .foregroundStyle(HeirloomColors.charcoal)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .kerning(-0.5)
                    .padding(.horizontal, HeirloomSpacing.onboardingScreenPadding)

                // Subtitle
                Text("Every recipe remembers where it came from")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 12)

                Spacer()
                    .frame(height: 40)

                // Sharing visualization
                sharingVisualization
                    .padding(.horizontal, 40)

                Spacer()

                // Continue Button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                .padding(.horizontal, HeirloomSpacing.onboardingScreenPadding)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Animate sharing flow
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                animateShare = true
            }

            withAnimation(.easeInOut(duration: 0.6).delay(1.2)) {
                showLineage = true
            }
        }
    }

    // MARK: - Sharing Visualization

    private var sharingVisualization: some View {
        VStack(spacing: 32) {
            // Top person (sender)
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(HeirloomColors.warmGray.opacity(0.2))
                        .frame(width: 64, height: 64)

                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(HeirloomColors.warmGray)
                }

                Text("You")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Recipe card with lineage indicator
            VStack(spacing: 0) {
                // Recipe card
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(HeirloomColors.warmGray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(HeirloomColors.warmGray)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grandma's Apple Pie")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        if showLineage {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 10))
                                    .foregroundStyle(HeirloomColors.tomato)

                                Text("From Mom")
                                    .font(HeirloomFonts.caption2)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }

                    Spacer()
                }
                .padding(12)
                .background(HeirloomColors.cardBackground)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
            .opacity(animateShare ? 1 : 0)
            .offset(y: animateShare ? 0 : -20)

            // Arrow
            Image(systemName: "arrow.down")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(HeirloomColors.tomato)
                .opacity(animateShare ? 1 : 0)

            // Bottom person (recipient)
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(HeirloomColors.tomato.opacity(0.2))
                        .frame(width: 64, height: 64)

                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(HeirloomColors.tomato)
                }

                Text("Family & Friends")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .opacity(animateShare ? 1 : 0)
            .offset(y: animateShare ? 0 : 20)
        }
    }

}

// MARK: - Preview

#Preview {
    OnboardingOrganizationScreen(onContinue: {})
}
