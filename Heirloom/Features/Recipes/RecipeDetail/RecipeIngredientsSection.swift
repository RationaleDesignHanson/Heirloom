//
//  RecipeIngredientsSection.swift
//  Heirloom
//
//  Phase 3: View Layer Decomposition
//  Ingredients component for RecipeDetailView with scaling support
//

import SwiftUI

/// Recipe ingredients list with automatic scaling based on serving size
struct RecipeIngredientsSection: View {
    // MARK: - Properties

    let recipe: Recipe
    let ingredients: [Ingredient]
    @Binding var targetServings: Int

    // Dependency injection for formatter
    private var formatter: IngredientFormatter {
        ServiceContainer.shared.resolve(IngredientFormatter.self)
    }

    // Observe UnitsConfiguration for reactive updates
    @ObservedObject private var unitsConfig: UnitsConfiguration = ServiceContainer.shared.resolve(UnitsConfiguration.self)

    // Check if any ingredients are missing quantities
    private var hasIngredientsMissingQuantities: Bool {
        ingredients.contains { $0.quantity == nil }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            sectionHeader(
                title: "Ingredients",
                icon: "list.bullet",
                count: ingredients.count
            )

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                ForEach(ingredients.sorted(by: { $0.orderIndex < $1.orderIndex })) { ingredient in
                    ingredientRow(ingredient)
                        .id("\(ingredient.id)-\(targetServings)") // Force unique ID per serving size
                }

                // Footnote for ingredients without measurements
                if hasIngredientsMissingQuantities {
                    Text("* no measurement provided")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.top, HeirloomSpacing.xs)
                }
            }
            .padding(HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .fill(.white)
            )
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, icon: String, count: Int? = nil) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(HeirloomColors.tomato)

            Text(title)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.charcoal)

            if let count = count {
                Text("(\(count))")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
            }

            Spacer()
        }
    }

    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
            Image(systemName: "circle")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.tomato)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text(scaledIngredientText(ingredient))
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal)

                // Show unit conversion note if ingredient was converted
                if ingredient.wasConverted, let conversionNote = ingredient.conversionNote {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "info.circle")
                            .font(HeirloomFonts.caption2)
                        Text(conversionNote)
                            .font(HeirloomFonts.caption1)
                    }
                    .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
    }

    // MARK: - Scaling Logic

    private func scaledIngredientText(_ ingredient: Ingredient) -> String {
        // Check if quantity exists
        guard ingredient.quantity != nil else {
            // Convert word numbers (e.g., "Two large eggs" → "2 large eggs")
            let converted = formatter.convertWordNumbers(ingredient.originalText)
            // If word number was converted, the quantity is effectively known — scale and no asterisk
            if converted != ingredient.originalText {
                let originalServings = recipe.parsedServingCount
                let scaleFactor = Double(targetServings) / Double(originalServings)
                if scaleFactor != 1.0 {
                    return formatter.scaleLeadingNumber(in: converted, scaleFactor: scaleFactor)
                }
                return converted
            }
            // Show original text with asterisk when quantity truly missing (footnote explains)
            return "\(ingredient.originalText)*"
        }

        // Calculate scale factor from target servings
        let originalServings = recipe.parsedServingCount
        let scaleFactor = Double(targetServings) / Double(originalServings)

        // Use IngredientFormatter to format with scaling and unit conversion
        let scaled = formatter.format(ingredient, scaleFactor: scaleFactor, convertUnits: true)

        // Log successful scaling attempt
        if targetServings != originalServings {
            ScalingDiagnostics.shared.logScalingAttempt(
                recipe: recipe,
                targetServings: targetServings,
                success: true
            )
        }

        return scaled
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var targetServings = 48

    let recipe = Recipe(
        title: "Classic Chocolate Chip Cookies",
        sourceType: .manual,
        sourceURL: nil,
        instructions: ["Mix ingredients", "Bake at 350°F"],
        servings: "24 cookies",
        prepTime: "15 min",
        cookTime: "12 min"
    )

    let ingredients: [Ingredient] = [
        Ingredient(originalText: "2 cups flour", name: "flour", quantity: 2, unit: "cups", category: .pantry, orderIndex: 0),
        Ingredient(originalText: "1 cup butter", name: "butter", quantity: 1, unit: "cup", category: .dairy, orderIndex: 1),
        Ingredient(originalText: "2 cups chocolate chips", name: "chocolate chips", quantity: 2, unit: "cups", category: .bakery, orderIndex: 2)
    ]

    RecipeIngredientsSection(
        recipe: recipe,
        ingredients: ingredients,
        targetServings: $targetServings
    )
    .padding()
    .background(HeirloomColors.cream)
}
