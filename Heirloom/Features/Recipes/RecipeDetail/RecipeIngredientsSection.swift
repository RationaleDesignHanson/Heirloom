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
    let targetServings: Int

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
                }
            }
            .id(targetServings) // Force refresh when servings change
            .padding(HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
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
                .font(.caption)
                .foregroundStyle(HeirloomColors.tomato)
                .padding(.top, 4)

            Text(scaledIngredientText(ingredient))
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal)
        }
    }

    // MARK: - Scaling Logic

    private func scaledIngredientText(_ ingredient: Ingredient) -> String {
        // Calculate scale factor from target servings
        let originalServings = recipe.parsedServingCount
        let scaleFactor = Double(targetServings) / Double(originalServings)

        // If scaling is 1.0, just show original text
        guard scaleFactor != 1.0 else {
            return ingredient.displayText
        }

        // If ingredient has no quantity, can't scale it
        guard let quantity = ingredient.quantity else {
            return ingredient.displayText
        }

        // Scale the quantity
        let scaledQty = quantity * scaleFactor
        let scaledQtyMax = ingredient.quantityMax.map { $0 * scaleFactor }

        // Build scaled display text
        var parts: [String] = []

        // Format quantity with fractions
        parts.append(formatQuantity(scaledQty))

        if let max = scaledQtyMax {
            parts.append("-\(formatQuantity(max))")
        }

        if let unit = ingredient.unit {
            parts.append(unit)
        }

        parts.append(ingredient.name)

        if let prep = ingredient.preparation {
            parts.append("(\(prep))")
        }

        return parts.joined(separator: " ")
    }

    private func formatQuantity(_ value: Double) -> String {
        let fractions: [(Double, String)] = [
            (0.125, "⅛"), (0.25, "¼"), (0.333, "⅓"),
            (0.375, "⅜"), (0.5, "½"), (0.625, "⅝"),
            (0.666, "⅔"), (0.75, "¾"), (0.875, "⅞")
        ]

        let wholePart = Int(value)
        let fractionalPart = value - Double(wholePart)

        for (decimalValue, fractionSymbol) in fractions {
            if abs(fractionalPart - decimalValue) < 0.01 {
                if wholePart > 0 {
                    return "\(wholePart) \(fractionSymbol)"
                } else {
                    return fractionSymbol
                }
            }
        }

        if fractionalPart < 0.01 {
            return "\(wholePart)"
        }

        return String(format: "%.1f", value)
    }
}

// MARK: - Preview

#Preview {
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
        targetServings: 48 // Double the recipe
    )
    .padding()
    .background(HeirloomColors.cream)
}
