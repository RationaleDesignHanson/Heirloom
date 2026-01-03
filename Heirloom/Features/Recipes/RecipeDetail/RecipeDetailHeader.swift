//
//  RecipeDetailHeader.swift
//  Heirloom
//
//  Phase 3: View Layer Decomposition
//  Header component for RecipeDetailView
//

import SwiftUI

/// Recipe detail header showing title, source, and action buttons
struct RecipeDetailHeader: View {
    // MARK: - Properties

    let recipe: Recipe
    let displayTitle: String
    let isInShoppingCart: Bool
    let onToggleFavorite: () -> Void
    let onAddToShoppingList: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Title
            Text(displayTitle)
                .font(HeirloomFonts.title1)
                .foregroundStyle(HeirloomColors.charcoal)

            // Source Badge
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: recipe.sourceType?.iconName ?? "square.and.pencil")
                    .font(.caption)
                Text(recipe.sourceDisplayName)
                    .font(HeirloomFonts.caption1)
            }
            .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

            // Action Buttons
            HStack(spacing: HeirloomSpacing.md) {
                // Favorite Button
                Button {
                    onToggleFavorite()
                } label: {
                    Label(
                        recipe.isFavorite ? "Favorited" : "Favorite",
                        systemImage: recipe.isFavorite ? "heart.fill" : "heart"
                    )
                    .font(HeirloomFonts.bodyBold)
                }
                .buttonStyle(SecondaryButtonStyle())

                // Add to Shopping List Button
                Button {
                    onAddToShoppingList()
                } label: {
                    Label(
                        isInShoppingCart ? "In List" : "Shopping List",
                        systemImage: isInShoppingCart ? "checkmark.circle.fill" : "cart"
                    )
                    .font(HeirloomFonts.bodyBold)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
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
    recipe.isFavorite = true

    return RecipeDetailHeader(
        recipe: recipe,
        displayTitle: "Classic Chocolate Chip Cookies",
        isInShoppingCart: false,
        onToggleFavorite: { print("Toggle favorite") },
        onAddToShoppingList: { print("Add to shopping list") }
    )
    .padding()
    .background(HeirloomColors.cream)
}
