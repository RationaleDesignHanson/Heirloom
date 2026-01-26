//
//  ThemeLoader.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Loads available themes from Firebase
actor ThemeLoader {

    private let firestore = Firestore.firestore()

    /// Fetch all available themes from Firebase and save to local database
    func loadThemes(into context: ModelContext) async throws -> [RecipeTheme] {
        let snapshot = try await firestore
            .collection("themes")
            .order(by: "sortOrder")
            .getDocuments()

        var themes: [RecipeTheme] = []

        for document in snapshot.documents {
            if let theme = try? parseTheme(from: document) {
                // Check if already exists locally
                let firebaseId = theme.firebaseId
                let descriptor = FetchDescriptor<RecipeTheme>(
                    predicate: #Predicate { $0.firebaseId == firebaseId }
                )

                if let existing = try? context.fetch(descriptor).first {
                    // Update existing
                    updateTheme(existing, from: theme)
                    themes.append(existing)
                } else {
                    // Insert new
                    context.insert(theme)
                    themes.append(theme)
                }
            }
        }

        try context.save()
        return themes
    }

    private func parseTheme(from document: QueryDocumentSnapshot) throws -> RecipeTheme {
        let data = document.data()

        guard let name = data["name"] as? String,
              let tagline = data["tagline"] as? String,
              let description = data["description"] as? String,
              let iconName = data["iconName"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = ThemeCategory(rawValue: categoryRaw),
              let totalRecipes = data["totalRecipes"] as? Int,
              let unlockSchedule = data["unlockSchedule"] as? [Int]
        else {
            throw ThemeLoadError.invalidData(document.documentID)
        }

        let theme = RecipeTheme(
            firebaseId: document.documentID,
            name: name,
            tagline: tagline,
            themeDescription: description,
            iconName: iconName,
            category: category,
            totalRecipes: totalRecipes,
            unlockSchedule: unlockSchedule
        )

        // Optional fields
        theme.coverImageURL = data["coverImageURL"] as? String
        theme.source = data["source"] as? String
        theme.era = data["era"] as? String
        theme.region = data["region"] as? String
        theme.sortOrder = data["sortOrder"] as? Int ?? 0

        return theme
    }

    private func updateTheme(_ existing: RecipeTheme, from new: RecipeTheme) {
        existing.name = new.name
        existing.tagline = new.tagline
        existing.themeDescription = new.themeDescription
        existing.iconName = new.iconName
        existing.category = new.category
        existing.totalRecipes = new.totalRecipes
        existing.unlockSchedule = new.unlockSchedule
        existing.coverImageURL = new.coverImageURL
        existing.source = new.source
        existing.era = new.era
        existing.region = new.region
        existing.sortOrder = new.sortOrder
        existing.updatedAt = Date()
    }
}

enum ThemeLoadError: Error {
    case invalidData(String)
    case networkError(Error)
}

// MARK: - Theme Recipe Service

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
                let recipe = try await parseRecipe(from: document, themeId: themeId)

                // Check if recipe already exists locally
                let recipeId = recipe.id
                let descriptor = FetchDescriptor<Recipe>(
                    predicate: #Predicate { $0.id == recipeId }
                )

                if let existing = try? context.fetch(descriptor).first {
                    // Update existing recipe
                    updateRecipe(existing, from: recipe)
                    recipes.append(existing)
                } else {
                    // Insert new recipe
                    context.insert(recipe)
                    recipes.append(recipe)
                }
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

        return recipe
    }

    private func updateRecipe(_ existing: Recipe, from new: Recipe) {
        existing.title = new.title
        existing.notes = new.notes
        existing.prepTime = new.prepTime
        existing.cookTime = new.cookTime
        existing.servings = new.servings
        existing.firebaseImageURL = new.firebaseImageURL
        existing.instructions = new.instructions
        // Note: ingredients are complex to update, skip for now
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
