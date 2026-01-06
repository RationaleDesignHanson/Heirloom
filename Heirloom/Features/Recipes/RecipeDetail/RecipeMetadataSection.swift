//
//  RecipeMetadataSection.swift
//  Heirloom
//
//  Phase 3: View Layer Decomposition
//  Metadata component for RecipeDetailView - servings, prep/cook times
//

import SwiftUI

/// Recipe metadata displaying servings selector, prep time, and cook time
struct RecipeMetadataSection: View {
    // MARK: - Properties

    let recipe: Recipe
    @Binding var targetServings: Int
    @Binding var showScalingExplanation: Bool

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    // MARK: - Body

    var body: some View {
        HStack(spacing: HeirloomSpacing.lg) {
            // Servings with dropdown
            servingsMetadataItem

            if let prepTime = recipe.prepTime {
                metadataItem(icon: "clock.fill", label: "Prep", value: prepTime)
            }

            if let cookTime = recipe.cookTime {
                metadataItem(icon: "flame.fill", label: "Cook", value: cookTime)
            }
        }
        .padding(HeirloomSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: HeirloomColors.cardShadow, radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Servings Item

    private var servingsMetadataItem: some View {
        VStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.title3)
                .foregroundStyle(HeirloomColors.tomato)

            Text("Servings")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

            // Dropdown menu for serving sizes
            Menu {
                let availableSizes = recipe.availableServingSizes

                if recipe.isScalingAllowed {
                    // Scalable recipe: show all preset options
                    ForEach(availableSizes, id: \.self) { size in
                        Button {
                            let originalServings = recipe.parsedServingCount
                            targetServings = size

                            // Track scaling event
                            if size != originalServings {
                                analytics.track(event: .recipeScaled, properties: [
                                    "recipe_title": recipe.title,
                                    "category": recipe.category?.rawValue ?? "unknown",
                                    "original_servings": originalServings,
                                    "target_servings": size,
                                    "scale_factor": Double(size) / Double(originalServings)
                                ])
                            }
                        } label: {
                            HStack {
                                Text("\(size) \(servingUnitText(size))")
                                if size == targetServings {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } else {
                    // Locked recipe: show explanation when tapped
                    Button {
                        showScalingExplanation = true

                        // Track explanation view
                        analytics.track(event: .scalingExplanationViewed, properties: [
                            "recipe_title": recipe.title,
                            "category": recipe.category?.rawValue ?? "unknown"
                        ])
                    } label: {
                        Label("Why can't I scale this?", systemImage: "info.circle")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(targetServings) \(servingUnitText(targetServings))")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.charcoal)

                    Image(systemName: recipe.isScalingAllowed ? "chevron.down" : "lock.fill")
                        .font(.caption)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showScalingExplanation) {
            ScalingExplanationSheet(recipe: recipe)
        }
    }

    // MARK: - Helper Methods

    private func servingUnitText(_ count: Int) -> String {
        if let servings = recipe.servings {
            // Try to extract unit from original servings string
            let lowercased = servings.lowercased()
            if lowercased.contains("cookie") {
                return count == 1 ? "cookie" : "cookies"
            } else if lowercased.contains("muffin") {
                return count == 1 ? "muffin" : "muffins"
            } else if lowercased.contains("serving") {
                return count == 1 ? "serving" : "servings"
            } else if lowercased.contains("portion") {
                return count == 1 ? "portion" : "portions"
            }
        }
        return count == 1 ? "serving" : "servings"
    }

    private func metadataItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(HeirloomColors.tomato)

            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

            Text(value)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.charcoal)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var targetServings = 24
    @Previewable @State var showScalingExplanation = false

    let recipe = Recipe(
        title: "Classic Chocolate Chip Cookies",
        sourceType: .manual,
        sourceURL: nil,
        instructions: ["Mix ingredients", "Bake at 350°F"],
        servings: "24 cookies",
        prepTime: "15 min",
        cookTime: "12 min"
    )

    RecipeMetadataSection(
        recipe: recipe,
        targetServings: $targetServings,
        showScalingExplanation: $showScalingExplanation
    )
    .padding()
    .background(HeirloomColors.cream)
}
