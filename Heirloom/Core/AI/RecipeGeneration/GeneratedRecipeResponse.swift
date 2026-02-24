//
//  GeneratedRecipeResponse.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import Foundation

/// Response model from AI recipe generation that matches Recipe model structure
struct GeneratedRecipeResponse: Codable {
    let title: String
    let summary: String?
    let prepTime: String?    // e.g., "15 min" (matches Recipe.prepTime format)
    let cookTime: String?    // e.g., "30 min" (matches Recipe.cookTime format)
    let servings: String?    // e.g., "4 servings" (matches Recipe.servings format)
    let ingredients: [GeneratedIngredient]  // Will map to Ingredient model
    let instructions: [String]  // Direct match to Recipe.instructions
    let tags: [String]?      // Will create/link Tag models
    let cuisine: String?

    // MARK: - Card Back Content (displayed on flip side of recipe card)

    /// Interesting facts about the dish, its history, or ingredients
    let funFacts: [String]?

    /// Cultural background or historical significance of the dish
    let culturalContext: String?

    /// Professional cooking tips and suggestions
    let chefTips: [String]?
}

/// Generated ingredient that maps to Ingredient model structure
struct GeneratedIngredient: Codable {
    let originalText: String  // e.g., "2 cups all-purpose flour"
    let quantity: Double?
    let unit: String?
    let name: String
    let preparation: String?  // e.g., "chopped", "sifted"
    let category: String?     // Maps to GroceryCategory enum
}
