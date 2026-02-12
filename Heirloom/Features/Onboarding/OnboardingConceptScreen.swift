//
//  OnboardingConceptScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-12.
//

import SwiftUI

/// Second onboarding screen - Concept introduction showing recipe + collections
struct OnboardingConceptScreen: View {
    let onContinue: () -> Void

    // Static data (no SwiftData queries) - 2 separate recipes
    private let sampleRecipes = [
        SampleRecipe(
            title: "Classic Grilled Cheese",
            collectionName: "Favorites",
            collectionIcon: "heart.fill",
            collectionColor: "#FF6B6B",
            imageName: "onboarding-grilled-cheese"
        ),
        SampleRecipe(
            title: "Tomato Soup",
            collectionName: "Favorites",
            collectionIcon: "heart.fill",
            collectionColor: "#FF6B6B",
            imageName: "onboarding-tomato-soup"
        )
    ]

    private let collections: [SampleCollection] = [
        SampleCollection(
            name: "Favorites",
            icon: "heart.fill",
            color: "#FF6B6B",
            count: 2,
            isHighlighted: true
        ),
        SampleCollection(
            name: "Quick Meals",
            icon: "clock.fill",
            color: "#4ECDC4",
            count: 0,
            isHighlighted: false
        ),
        SampleCollection(
            name: "Meal Prep",
            icon: "tray.2.fill",
            color: "#95E1D3",
            count: 0,
            isHighlighted: false
        )
    ]

    @State private var showPulse = true

    var body: some View {
        ZStack {
            HeirloomColors.cream.ignoresSafeArea()

            VStack(spacing: HeirloomSpacing.lg) {
                Spacer()
                    .frame(minHeight: 30, maxHeight: 50)

                // Title
                Text("Organize recipes you love")
                    .font(HeirloomFonts.title1)
                    .foregroundStyle(HeirloomColors.charcoal)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Recipe Cards (static, non-tappable) - Match Recipes tab layout
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing),
                        GridItem(.flexible())
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
                    .frame(minHeight: 20, maxHeight: 40)

                // Continue Button
                Button {
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
                .padding(.horizontal, 32)

                Spacer()
                    .frame(minHeight: 30, maxHeight: 50)
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

    // MARK: - Data Models

    struct SampleRecipe {
        let title: String
        let collectionName: String
        let collectionIcon: String
        let collectionColor: String
        let imageName: String
    }

    struct SampleCollection {
        let name: String
        let icon: String
        let color: String
        let count: Int
        let isHighlighted: Bool
    }
}

// MARK: - Static Recipe Card

/// Static recipe card for concept introduction (no SwiftData dependency)
struct OnboardingConceptRecipeCard: View {
    let recipe: OnboardingConceptScreen.SampleRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Image from bundled asset (with fallback)
            Group {
                if let image = UIImage(named: recipe.imageName) {
                    Image(uiImage: image)
                        .resizable()
                } else {
                    // Fallback to placeholder
                    ZStack {
                        Rectangle()
                            .fill(Color(hex: "#FFE5E5"))
                        Image(systemName: "fork.knife")
                            .font(.largeTitle)
                            .foregroundStyle(HeirloomColors.tomato.opacity(0.4))
                    }
                }
            }
            .aspectRatio(4/3, contentMode: .fill)
            .frame(height: 120)
            .clipped()
            .cornerRadius(12)

            // Title
            Text(recipe.title)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
                .lineLimit(2)
                .frame(height: 40, alignment: .topLeading)

            // Collection badge
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: recipe.collectionIcon)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(Color(hex: recipe.collectionColor))

                Text(recipe.collectionName)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HeirloomSpacing.sm)
        .background(Color(hex: "#F8F8F8"))
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
        .heirloomShadow(HeirloomShadows.card)
    }
}

// MARK: - Static Collection Row

/// Static collection row for concept introduction
struct OnboardingConceptCollectionRow: View {
    let collection: OnboardingConceptScreen.SampleCollection
    let showPulse: Bool

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Icon
            Image(systemName: collection.icon)
                .font(HeirloomFonts.title2)
                .fontWeight(collection.isHighlighted ? .semibold : .regular)
                .foregroundStyle(Color(hex: collection.color))
                .frame(width: 32)

            // Name & Count
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(HeirloomFonts.body)
                    .fontWeight(collection.isHighlighted ? .semibold : .regular)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("\(collection.count) recipe\(collection.count == 1 ? "" : "s")")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
        }
        .padding(HeirloomSpacing.md)
        .background(
            collection.isHighlighted
                ? Color(hex: collection.color).opacity(0.08)
                : Color(hex: "#F8F8F8")
        )
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
        .scaleEffect(showPulse ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 1.0), value: showPulse)
    }
}

// MARK: - Preview

#Preview {
    OnboardingConceptScreen(onContinue: {})
}
