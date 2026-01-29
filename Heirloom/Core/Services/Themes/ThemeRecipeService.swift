//
//  ThemeRecipeService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Service for downloading theme recipes from Firebase
/// CRITICAL: Uses ModelContext which requires MainActor
@MainActor
class ThemeRecipeService {

    private let firestore = Firestore.firestore()

    /// Download recipes for selected themes from Firebase
    func downloadRecipes(for themeIds: [String], into context: ModelContext) async throws -> [Recipe] {
        var allRecipes: [Recipe] = []

        for themeId in themeIds {
            let recipes = try await downloadRecipesForTheme(themeId: themeId, into: context)
            allRecipes.append(contentsOf: recipes)
        }

        return allRecipes
    }

    /// Download all recipes for a specific theme
    func downloadRecipesForTheme(themeId: String, into context: ModelContext) async throws -> [Recipe] {
        // Fetch recipes from Firebase
        let recipesSnapshot = try await firestore
            .collection("themes")
            .document(themeId)
            .collection("recipes")
            .order(by: "sortOrder")
            .getDocuments()

        var recipes: [Recipe] = []

        for document in recipesSnapshot.documents {
            do {
                // Check if recipe already exists locally by Firebase document ID
                let firebaseDocId = document.documentID
                let existingDescriptor = FetchDescriptor<Recipe>(
                    predicate: #Predicate { recipe in
                        recipe.themeRecipeId == firebaseDocId && recipe.sourceThemeId == themeId
                    }
                )

                let recipe: Recipe
                if let existing = try? context.fetch(existingDescriptor).first {
                    // Recipe already exists - update it instead of skipping
                    recipe = existing

                    // Delete existing ingredients by accessing relationship directly
                    // (can't use predicates with optional relationships)
                    if let existingIngredients = existing.ingredients {
                        for ingredient in existingIngredients {
                            context.delete(ingredient)
                        }
                    }

                    // Clear the relationship
                    existing.ingredients = nil

                    // Force save to commit deletions before adding new data
                    try context.save()

                    // Update recipe data
                    try await updateRecipe(existing, from: document, themeId: themeId, context: context)
                } else {
                    // Parse and insert new recipe
                    recipe = try await parseRecipe(from: document, themeId: themeId)
                    context.insert(recipe)
                }

                // Get unlock day from Firebase document (already set during seeding)
                let unlockDay = document.data()["unlockDay"] as? Int ?? 1
                recipe.unlockDay = unlockDay

                Log.debug("Recipe '\(recipe.title)' has unlockDay: \(unlockDay)", category: .onboarding)

                recipes.append(recipe)
            } catch {
                Log.error("Failed to parse recipe", category: .onboarding, metadata: [
                    "themeId": themeId,
                    "recipeId": document.documentID,
                    "error": error.localizedDescription
                ])
            }
        }

        try context.save()

        Log.info("Downloaded \(recipes.count) recipes for theme", category: .onboarding, metadata: [
            "themeId": themeId,
            "recipeCount": recipes.count
        ])

        return recipes
    }

    /// Update existing recipe with fresh data from Firestore
    private func updateRecipe(_ recipe: Recipe, from document: QueryDocumentSnapshot, themeId: String, context: ModelContext) async throws {
        let data = document.data()

        // Update basic fields
        recipe.title = data["title"] as? String ?? recipe.title
        recipe.notes = data["description"] as? String
        recipe.prepTime = formatTime(data["prepTime"])
        recipe.cookTime = formatTime(data["cookTime"])
        recipe.servings = formatServings(data["servings"])
        recipe.firebaseImageURL = data["imageURL"] as? String
        recipe.historicalText = data["story"] as? String
        recipe.sourceStory = data["source"] as? String
        recipe.unlockDay = data["unlockDay"] as? Int ?? recipe.unlockDay ?? 1

        // Get ingredients from document array
        if let ingredientsArray = data["ingredients"] as? [[String: Any]] {
            for (index, ingData) in ingredientsArray.enumerated() {
                // Format ingredient into readable text (like "1 pound elbow macaroni")
                let originalText = formatIngredientText(ingData)

                let ingredient = Ingredient(
                    originalText: originalText,
                    name: ingData["name"] as? String ?? "",
                    quantity: ingData["amount"] as? Double,
                    unit: ingData["unit"] as? String,
                    category: .other,
                    orderIndex: index
                )

                ingredient.recipe = recipe
                context.insert(ingredient)
            }
        }

        // Get instructions from document array
        if let instructionsArray = data["instructions"] as? [String] {
            recipe.instructions = instructionsArray
        }
    }

    private func parseRecipe(from document: QueryDocumentSnapshot, themeId: String) async throws -> Recipe {
        let data = document.data()

        guard let title = data["title"] as? String else {
            throw ThemeRecipeError.invalidData("Missing title")
        }

        // Create recipe
        let recipe = Recipe()
        recipe.id = UUID() // Generate new UUID for SwiftData
        recipe.title = title
        recipe.notes = data["description"] as? String
        recipe.prepTime = formatTime(data["prepTime"])
        recipe.cookTime = formatTime(data["cookTime"])
        recipe.servings = formatServings(data["servings"])
        recipe.sourceType = .heritage
        recipe.isThemeRecipe = true
        recipe.sourceThemeId = themeId
        recipe.themeRecipeId = document.documentID
        recipe.firebaseImageURL = data["imageURL"] as? String
        recipe.unlockDay = data["unlockDay"] as? Int ?? 1

        // Historical content for card back
        recipe.historicalText = data["story"] as? String
        recipe.sourceStory = data["source"] as? String

        // Get ingredients from document array
        var ingredients: [Ingredient] = []
        if let ingredientsArray = data["ingredients"] as? [[String: Any]] {
            for (index, ingData) in ingredientsArray.enumerated() {
                // Format ingredient into readable text (like "1 pound elbow macaroni")
                let originalText = formatIngredientText(ingData)

                let ingredient = Ingredient(
                    originalText: originalText,
                    name: ingData["name"] as? String ?? "",
                    quantity: ingData["amount"] as? Double,
                    unit: ingData["unit"] as? String,
                    category: .other,
                    orderIndex: index
                )

                ingredient.recipe = recipe
                ingredients.append(ingredient)
            }
        }

        recipe.ingredients = ingredients

        // Get instructions from document array
        if let instructionsArray = data["instructions"] as? [String] {
            recipe.instructions = instructionsArray
        }

        // Create and configure card back for theme recipes
        let cardBack = RecipeCardBack(recipe: recipe)
        cardBack.configureForHeritageRecipe()
        recipe.cardBack = cardBack

        return recipe
    }

    private func formatTime(_ value: Any?) -> String? {
        if let minutes = value as? Int {
            return "\(minutes) min"
        }
        if let str = value as? String {
            return str
        }
        return nil
    }

    private func formatServings(_ value: Any?) -> String? {
        if let servings = value as? Int {
            return "\(servings)"
        }
        if let str = value as? String {
            return str
        }
        return nil
    }

    /// Format ingredient data into readable text like "1 pound elbow macaroni"
    private func formatIngredientText(_ ingData: [String: Any]) -> String {
        var parts: [String] = []

        // Add amount
        if let amount = ingData["amount"] as? Double {
            // Format nicely (no unnecessary decimals)
            if amount.truncatingRemainder(dividingBy: 1) == 0 {
                parts.append(String(format: "%.0f", amount))
            } else {
                parts.append(String(format: "%.2f", amount).replacingOccurrences(of: ".00", with: ""))
            }
        }

        // Add unit
        if let unit = ingData["unit"] as? String, !unit.isEmpty {
            parts.append(unit)
        }

        // Add name
        if let name = ingData["name"] as? String, !name.isEmpty {
            parts.append(name)
        }

        return parts.joined(separator: " ")
    }
}

enum ThemeRecipeError: Error {
    case invalidData(String)
    case networkError(Error)
}
