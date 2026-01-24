//
//  OnboardingOrganizationScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//

import SwiftUI

/// Fourth onboarding screen - Organization with collections and sync
struct OnboardingOrganizationScreen: View {
    let onContinue: () -> Void

    // Static data (no SwiftData queries) - 4 diverse recipes (no scrolling needed)
    // Reuse OnboardingConceptScreen types for compatibility with OnboardingConceptRecipeCard
    private let sampleRecipes = [
        OnboardingConceptScreen.SampleRecipe(
            title: "Classic Grilled Cheese",
            collectionName: "Favorites",
            collectionIcon: "heart.fill",
            collectionColor: "#FF6B6B",
            imageName: "onboarding-grilled-cheese"
        ),
        OnboardingConceptScreen.SampleRecipe(
            title: "Tomato Soup",
            collectionName: "Favorites",
            collectionIcon: "heart.fill",
            collectionColor: "#FF6B6B",
            imageName: "onboarding-tomato-soup"
        ),
        OnboardingConceptScreen.SampleRecipe(
            title: "Pot Roast",
            collectionName: "Favorites",
            collectionIcon: "heart.fill",
            collectionColor: "#FF6B6B",
            imageName: "onboarding-pot-roast"
        ),
        OnboardingConceptScreen.SampleRecipe(
            title: "Apple Pie",
            collectionName: "Favorites",
            collectionIcon: "heart.fill",
            collectionColor: "#FF6B6B",
            imageName: "onboarding-apple-pie"
        )
    ]

    private let collections: [OnboardingConceptScreen.SampleCollection] = [
        OnboardingConceptScreen.SampleCollection(
            name: "Favorites",
            icon: "heart.fill",
            color: "#FF6B6B",
            count: 6,
            isHighlighted: true
        )
    ]

    @State private var showPulse = true

    var body: some View {
        ZStack {
            HeirloomColors.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    Spacer()
                        .frame(height: 30)

                    // Title
                    Text("Beautiful recipes,\nbeautifully organized")
                        .font(HeirloomFonts.largeTitle)
                        .foregroundStyle(HeirloomColors.charcoal)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .kerning(-0.5)
                        .padding(.horizontal, HeirloomSpacing.onboardingScreenPadding)

                    // Subtitle
                    Text("Collections, sync, and sharing built in")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    // Recipe Cards (static, non-tappable) - Match Recipes tab layout
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing),
                            GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing)
                        ],
                        spacing: HeirloomSpacing.gridSpacing
                    ) {
                        ForEach(sampleRecipes.indices, id: \.self) { index in
                            OnboardingConceptRecipeCard(recipe: sampleRecipes[index])
                        }
                    }
                    .padding(.horizontal, HeirloomSpacing.lg)
                    .allowsHitTesting(false) // Disable taps

                    // Collection Rows (static, non-tappable)
                    VStack(spacing: HeirloomSpacing.sm) {
                        ForEach(collections, id: \.name) { collection in
                            OnboardingConceptCollectionRow(
                                collection: collection,
                                showPulse: showPulse && collection.isHighlighted
                            )
                        }
                    }
                    .padding(.horizontal, HeirloomSpacing.lg)
                    .allowsHitTesting(false) // Disable taps

                    Spacer()
                        .frame(height: 20)

                    // Continue Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onContinue()
                    } label: {
                        Text("Get Started")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, HeirloomSpacing.onboardingScreenPadding)

                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .onAppear {
            // Pulse animation for Favorites (run twice, then stop)
            withAnimation(.easeInOut(duration: 1.0).repeatCount(2, autoreverses: true)) {
                showPulse = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showPulse = false
            }
        }
    }

}

// MARK: - Preview

#Preview {
    OnboardingOrganizationScreen(onContinue: {})
}
