//
//  CommunityRecipeIngredientMigration.swift
//  Heirloom
//
//  Migration to reparse ingredient quantities for recipes saved from community/discover.
//  These recipes were saved before the fix that parses ingredient text into quantity/unit/name.
//

import Foundation
import SwiftData

/// Migration service to fix ingredients for community-sourced recipes that were saved
/// before ingredient parsing was implemented. These recipes have quantity=nil on all
/// ingredients, which breaks scaling functionality.
@MainActor
class CommunityRecipeIngredientMigration {

    /// Run the migration to reparse ingredients for all community-sourced recipes
    /// - Parameter context: The model context to use
    /// - Returns: Number of recipes fixed
    @discardableResult
    static func run(context: ModelContext) throws -> Int {
        Log.info("Starting community recipe ingredient migration", category: .migration)

        // Find all recipes that came from community/discover (have sourcePublicRecipeId)
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.sourcePublicRecipeId != nil
            }
        )

        let communityRecipes = try context.fetch(descriptor)

        Log.info("Found community recipes to check", category: .migration, metadata: [
            "count": communityRecipes.count
        ])

        var fixedCount = 0

        for recipe in communityRecipes {
            guard let ingredients = recipe.ingredients, !ingredients.isEmpty else {
                continue
            }

            // Check if any ingredients need fixing (quantity is nil but originalText looks parseable)
            let needsFixing = ingredients.contains { ingredient in
                ingredient.quantity == nil && looksLikeParseable(ingredient.originalText)
            }

            guard needsFixing else {
                continue
            }

            // Reparse all ingredients for this recipe
            for ingredient in ingredients {
                reparseIngredient(ingredient)
            }

            fixedCount += 1

            Log.debug("Fixed ingredients for recipe", category: .migration, metadata: [
                "title": recipe.title,
                "ingredient_count": ingredients.count
            ])
        }

        if fixedCount > 0 {
            try context.save()
        }

        Log.info("Community recipe ingredient migration complete", category: .migration, metadata: [
            "recipes_fixed": fixedCount
        ])

        return fixedCount
    }

    /// Check if ingredient text looks like it should have been parsed (has a number at the start)
    private static func looksLikeParseable(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let firstChar = trimmed.first else { return false }

        // Check if starts with a digit or fraction character
        let fractionChars: Set<Character> = ["¼", "½", "¾", "⅓", "⅔", "⅕", "⅖", "⅗", "⅘", "⅙", "⅚", "⅛", "⅜", "⅝", "⅞"]
        return firstChar.isNumber || fractionChars.contains(firstChar)
    }

    /// Reparse an ingredient's originalText to extract quantity, unit, and name
    private static func reparseIngredient(_ ingredient: Ingredient) {
        let parsed = IngredientParser.parse(ingredient.originalText)

        // Only update if we actually extracted a quantity
        if let quantity = parsed.quantity {
            ingredient.quantity = quantity
            ingredient.quantityMax = parsed.quantityMax
            ingredient.unit = parsed.unit

            // Update name if parsed name is more specific
            if !parsed.name.isEmpty {
                ingredient.name = parsed.name
            }
        }
    }
}
