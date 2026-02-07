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

    /// Current migration version - increment to force re-run on all users
    static let currentVersion = 2

    /// Run the migration to reparse ingredients for all community-sourced recipes
    /// - Parameter context: The model context to use
    /// - Returns: Number of recipes fixed
    @discardableResult
    static func run(context: ModelContext) throws -> Int {
        // Check if migration has already run at current version
        let lastRunVersion = UserDefaults.standard.integer(forKey: UserDefaultsKeys.communityIngredientMigrationVersion)
        if lastRunVersion >= currentVersion {
            Log.debug("Community ingredient migration already at version \(currentVersion), skipping", category: .migration)
            return 0
        }

        Log.info("Starting community recipe ingredient migration v\(currentVersion)", category: .migration, metadata: [
            "previousVersion": lastRunVersion
        ])

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

            // Migration v2: Try parsing ALL ingredients that have nil quantity
            // Remove the restrictive looksLikeParseable filter - the parser handles all formats
            let ingredientsNeedingFix = ingredients.filter { $0.quantity == nil }

            guard !ingredientsNeedingFix.isEmpty else {
                continue
            }

            var ingredientsFixed = 0

            // Reparse all nil-quantity ingredients for this recipe
            for ingredient in ingredientsNeedingFix {
                if reparseIngredient(ingredient) {
                    ingredientsFixed += 1
                }
            }

            if ingredientsFixed > 0 {
                fixedCount += 1

                Log.debug("Fixed ingredients for recipe", category: .migration, metadata: [
                    "title": recipe.title,
                    "ingredients_fixed": ingredientsFixed,
                    "total_ingredients": ingredients.count
                ])
            }
        }

        if fixedCount > 0 {
            try context.save()
        }

        // Mark migration as complete at current version
        UserDefaults.standard.set(currentVersion, forKey: UserDefaultsKeys.communityIngredientMigrationVersion)

        Log.info("Community recipe ingredient migration v\(currentVersion) complete", category: .migration, metadata: [
            "recipes_fixed": fixedCount
        ])

        return fixedCount
    }

    /// Reparse an ingredient's originalText to extract quantity, unit, and name
    /// - Returns: true if quantity was successfully extracted
    @discardableResult
    private static func reparseIngredient(_ ingredient: Ingredient) -> Bool {
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
            return true
        }
        return false
    }
}
