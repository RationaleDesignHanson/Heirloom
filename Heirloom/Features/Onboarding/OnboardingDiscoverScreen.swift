//
//  OnboardingDiscoverScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//  Task 5: Privacy controls with visibility pills
//

import SwiftUI

/// Discover screen - Screen 5 of 5
/// Introduces the visibility pills concept and privacy-first approach
struct OnboardingDiscoverScreen: View {
    let onStartSaving: () -> Void
    let onExploreDiscover: () -> Void

    @State private var selectedVisibility: VisibilityOption = .private
    @State private var animateSelection = false

    private enum VisibilityOption: String, CaseIterable {
        case `private` = "Private"
        case shared = "Shared"
        case `public` = "Public"

        var icon: String {
            switch self {
            case .private: return "lock.fill"
            case .shared: return "person.2.fill"
            case .public: return "globe"
            }
        }

        var description: String {
            switch self {
            case .private: return "Only you can see this"
            case .shared: return "Visible to people you share with"
            case .public: return "Visible in Discover feed"
            }
        }
    }

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
                GeometryReader { geometry in
                    ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Private by default")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("Your recipes are yours. Share only what you choose.")
                                .font(HeirloomFonts.body)
                                .foregroundColor(HeirloomColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Recipe card with visibility pills
                        visibilityDemoCard
                            .padding(.horizontal, 24)

                        // Trust contract callout
                        trustContractCallout
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
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
            startVisibilityAnimation()
        }
    }

    // MARK: - Visibility Animation

    private func startVisibilityAnimation() {
        // Animate through visibility options to demonstrate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedVisibility = .shared
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedVisibility = .public
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedVisibility = .private
                    }
                }
            }
        }
    }

    // MARK: - Visibility Demo Card

    private var visibilityDemoCard: some View {
        VStack(spacing: 16) {
            // Recipe preview
            HStack(spacing: 12) {
                // Recipe image - using bundled asset
                Image("onboarding-apple-pie")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Grandma's Apple Pie")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundColor(HeirloomColors.primaryText)

                    Text("Family recipe since 1952")
                        .font(HeirloomFonts.caption1)
                        .foregroundColor(HeirloomColors.secondaryText)
                }

                Spacer()
            }

            // Visibility pills
            HStack(spacing: 8) {
                ForEach(VisibilityOption.allCases, id: \.self) { option in
                    visibilityPill(option: option)
                }
            }

            // Description text
            Text(selectedVisibility.description)
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .animation(.easeInOut(duration: 0.2), value: selectedVisibility)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
    }

    private func visibilityPill(option: VisibilityOption) -> some View {
        let isSelected = selectedVisibility == option

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedVisibility = option
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 12))
                Text(option.rawValue)
                    .font(HeirloomFonts.caption1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? pillColor(for: option) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .white : HeirloomColors.secondaryText)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func pillColor(for option: VisibilityOption) -> Color {
        switch option {
        case .private: return HeirloomColors.familyGreen
        case .shared: return Color.blue
        case .public: return HeirloomColors.tomato
        }
    }

    // MARK: - Trust Contract Callout

    private var trustContractCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(HeirloomColors.familyGreen)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your privacy promise")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundColor(HeirloomColors.primaryText)

                Text("Your recipe box is private. We never share your recipes without your explicit action.")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(HeirloomColors.familyGreen.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    OnboardingDiscoverScreen(
        onStartSaving: { print("Start saving tapped") },
        onExploreDiscover: { print("Explore Discover tapped") }
    )
}
