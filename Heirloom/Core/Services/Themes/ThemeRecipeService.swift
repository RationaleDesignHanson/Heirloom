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
actor ThemeRecipeService {

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
        // Get the theme to access unlock schedule
        let themeDescriptor = FetchDescriptor<RecipeTheme>(
            predicate: #Predicate { $0.firebaseId == themeId }
        )
        guard let theme = try? context.fetch(themeDescriptor).first else {
            throw ThemeRecipeError.invalidData("Theme not found: \(themeId)")
        }

        // Fetch recipes from Firebase
        let recipesSnapshot = try await firestore
            .collection("themes")
            .document(themeId)
            .collection("recipes")
            .order(by: "sortOrder")
            .getDocuments()

        var recipes: [Recipe] = []

        for (index, document) in recipesSnapshot.documents.enumerated() {
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
                    // Recipe already exists - skip to avoid duplicates
                    recipe = existing
                } else {
                    // Parse and insert new recipe
                    recipe = try await parseRecipe(from: document, themeId: themeId)
                    context.insert(recipe)
                }

                // Assign unlock day based on position and theme schedule
                recipe.unlockDay = assignUnlockDay(
                    recipeIndex: index,
                    totalRecipes: recipesSnapshot.documents.count,
                    unlockSchedule: theme.unlockSchedule
                )

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

    /// Assign unlock day to a recipe based on its position and theme schedule
    /// Distributes recipes evenly across unlock days
    private func assignUnlockDay(recipeIndex: Int, totalRecipes: Int, unlockSchedule: [Int]) -> Int {
        guard !unlockSchedule.isEmpty else { return 1 }

        // Distribute recipes evenly across unlock days
        let recipesPerDay = Double(totalRecipes) / Double(unlockSchedule.count)
        let dayIndex = Int(Double(recipeIndex) / recipesPerDay)
        let clampedIndex = min(dayIndex, unlockSchedule.count - 1)

        return unlockSchedule[clampedIndex]
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

        // Historical content for card back
        recipe.historicalText = data["story"] as? String
        recipe.sourceStory = data["source"] as? String

        // Download ingredients
        let ingredientsSnapshot = try await document.reference
            .collection("ingredients")
            .order(by: "order")
            .getDocuments()

        var ingredients: [Ingredient] = []
        for (index, ingDoc) in ingredientsSnapshot.documents.enumerated() {
            let ingData = ingDoc.data()

            let ingredient = Ingredient(
                originalText: ingData["text"] as? String ?? "",
                name: ingData["name"] as? String ?? "",
                quantity: ingData["amount"] as? Double,
                unit: ingData["unit"] as? String,
                category: .other,
                orderIndex: index
            )

            ingredient.recipe = recipe
            ingredients.append(ingredient)
        }

        recipe.ingredients = ingredients

        // Download instructions
        let instructionsSnapshot = try await document.reference
            .collection("instructions")
            .order(by: "order")
            .getDocuments()

        var instructions: [String] = []
        for instDoc in instructionsSnapshot.documents {
            if let text = instDoc.data()["text"] as? String {
                instructions.append(text)
            }
        }

        recipe.instructions = instructions

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
}

enum ThemeRecipeError: Error {
    case invalidData(String)
    case networkError(Error)
}
