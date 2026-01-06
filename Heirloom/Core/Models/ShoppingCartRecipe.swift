//
//  ShoppingCartRecipe.swift
//  Heirloom
//
//  Created for Smallify shopping cart integration
//  Stores recipe + target serving size for scaled shopping lists
//

import Foundation
import SwiftData

// MARK: - Shopping Cart Recipe

/// Wrapper model that stores a recipe with its target serving size
/// This allows shopping cart to display correctly scaled ingredient quantities
@Model
final class ShoppingCartRecipe {
    // MARK: - Properties

    var id: UUID = UUID()
    var recipeId: UUID = UUID() // Stored for efficient querying

    @Relationship(inverse: \Recipe.shoppingCartRecipes)
    var recipe: Recipe?

    var targetServings: Int = 0
    var dateAdded: Date = Date()

    // MARK: - Initialization

    init(recipe: Recipe, targetServings: Int) {
        self.id = UUID()
        self.recipeId = recipe.id
        self.recipe = recipe
        self.targetServings = targetServings
        self.dateAdded = Date()
    }

    // MARK: - Computed Properties

    /// The scale factor applied to this recipe
    var scaleFactor: Double {
        guard let recipe = recipe else { return 1.0 }
        let originalServings = recipe.parsedServingCount
        return Double(targetServings) / Double(originalServings)
    }

    /// Display string for the cart (e.g., "Grandma's Cookies (for 24 servings)")
    var displayTitle: String {
        guard let recipe = recipe else { return "Unknown Recipe" }
        if targetServings == recipe.parsedServingCount {
            return recipe.title
        } else {
            return "\(recipe.title) (for \(targetServings))"
        }
    }

    /// Get scaled ingredients using ScalingEngine
    nonisolated var scaledIngredients: [ScaledIngredient] {
        guard let recipe = recipe else { return [] }

        // Use ScalingEngine if the recipe supports scaling
        let scalingEngine = MainActor.assumeIsolated {
            ServiceContainer.shared.resolve(ScalingEngine.self)
        }
        if recipe.isScalingAllowed,
           let scaledRecipe = scalingEngine.scaleRecipe(recipe, toServings: targetServings) {
            return scaledRecipe.scaledIngredients
        }

        // Otherwise, return original ingredients wrapped as ScaledIngredients
        return (recipe.ingredients ?? []).map { ingredient in
            ScaledIngredient(
                originalIngredient: ingredient,
                scaledQuantity: ingredient.quantity,
                scaledQuantityMax: ingredient.quantityMax,
                wasAdjusted: false,
                adjustmentReason: nil
            )
        }
    }
}

// MARK: - Recipe Extension

extension Recipe {
    /// Check if this recipe is in the shopping cart
    func isInShoppingCart(context: ModelContext) -> Bool {
        let recipeId = self.id
        let descriptor = FetchDescriptor<ShoppingCartRecipe>(
            predicate: #Predicate { $0.recipeId == recipeId }
        )
        let results = (try? context.fetch(descriptor)) ?? []
        return !results.isEmpty
    }

    /// Get the ShoppingCartRecipe for this recipe if it exists
    func shoppingCartRecipe(context: ModelContext) -> ShoppingCartRecipe? {
        let recipeId = self.id
        let descriptor = FetchDescriptor<ShoppingCartRecipe>(
            predicate: #Predicate { $0.recipeId == recipeId }
        )
        return try? context.fetch(descriptor).first
    }
}
