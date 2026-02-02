//
//  OnboardingDiscoverScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import SwiftUI

/// Discover screen - Screen 5 of 5
/// Introduces optional community browsing with privacy emphasis
struct OnboardingDiscoverScreen: View {
    let onStartSaving: () -> Void
    let onExploreDiscover: () -> Void

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
                Text("5/5")
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
                            Text("Discover when you want")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("Browse community recipes—or keep everything private.")
                                .font(HeirloomFonts.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Discover feed mockup
                        discoverFeedMockup
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 16)
                }

                // Fixed bottom CTAs
                VStack(spacing: 12) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onStartSaving()
                    }) {
                        Text("Start saving")
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
                        onExploreDiscover()
                    }) {
                        Text("Explore Discover")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 4)

                    // Microcopy
                    Text("Publish only what you choose.")
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
    }

    // MARK: - Discover Feed Mockup

    private var discoverFeedMockup: some View {
        VStack(spacing: 16) {
            // Header with privacy indicator
            HStack {
                Text("Discover Feed")
                    .font(HeirloomFonts.title3)
                    .foregroundColor(HeirloomColors.primaryText)

                Spacer()

                // Private by default badge
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                    Text("Private by default")
                        .font(HeirloomFonts.caption2)
                }
                .foregroundColor(HeirloomColors.familyGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HeirloomColors.familyGreen.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()
                .padding(.horizontal)

            // Recipe cards
            VStack(spacing: 12) {
                discoverRecipeCard(name: "Classic Carbonara", author: "Italian Chef")
                discoverRecipeCard(name: "Chocolate Cake", author: "Home Baker")
                discoverRecipeCard(name: "Thai Green Curry", author: "Spice Master")
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(HeirloomColors.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }

    private func discoverRecipeCard(name: String, author: String) -> some View {
        HStack(spacing: 12) {
            // Recipe image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(HeirloomColors.warmGray.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundColor(HeirloomColors.warmGray.opacity(0.5))
                )

            // Recipe info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundColor(HeirloomColors.primaryText)

                Text("by \(author)")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
            }

            Spacer()

            // Save button
            Button(action: {}) {
                Text("Save")
                    .font(HeirloomFonts.caption1)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Preview

#Preview {
    OnboardingDiscoverScreen(
        onStartSaving: { print("Start saving tapped") },
        onExploreDiscover: { print("Explore Discover tapped") }
    )
}
