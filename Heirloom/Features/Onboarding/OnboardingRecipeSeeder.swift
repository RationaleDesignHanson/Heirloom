//
//  OnboardingRecipeSeeder.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-12.
//

import Foundation
import SwiftData
import UIKit

/// Service for creating the onboarding demonstration recipe
@MainActor
class OnboardingRecipeSeeder {
    private let modelContext: ModelContext
    private let imageService: ImageStorageService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.imageService = ServiceContainer.shared.resolve(ImageStorageService.self)
    }

    /// Check if onboarding recipe has been seeded
    func isSeeded() -> Bool {
        UserDefaults.standard.bool(forKey: "OnboardingRecipeSeeded")
    }

    /// Create 2 onboarding recipes (Grilled Cheese + Tomato Soup) in Favorites collection
    func seedOnboardingRecipe() async throws {
        guard !isSeeded() else {
            Log.info("Onboarding recipes already seeded", category: .storage)
            return
        }

        // Find Favorites collection first
        let favoritesDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate {
                $0.name == "Favorites" && $0.isSystemCollection == true
            }
        )

        guard let favorites = try modelContext.fetch(favoritesDescriptor).first else {
            Log.warning("Favorites collection not found - skipping onboarding recipe seeding", category: .storage)
            return
        }

        // Recipe 1: Classic Grilled Cheese
        let grilledCheese = Recipe(
            title: "Classic Grilled Cheese",
            sourceType: .manual,
            instructions: [
                "Butter one side of each bread slice generously.",
                "Place one slice butter-side down in skillet.",
                "Layer 2-3 slices of cheddar cheese on bread.",
                "Top with second slice, butter-side up.",
                "Cook over medium heat until golden brown (3-4 minutes).",
                "Flip carefully and cook other side until golden.",
                "Press gently with spatula while cooking.",
                "Cut diagonally and serve hot."
            ],
            servings: "1",
            prepTime: "5 minutes",
            cookTime: "8 minutes"
        )
        grilledCheese.sourceStory = "A timeless comfort food classic."
        grilledCheese.collections = [favorites]

        // Grilled Cheese ingredients
        let grilledCheeseIngredients = [
            "2 slices bread",
            "2 tablespoons butter, softened",
            "2-3 slices cheddar cheese"
        ]

        for (index, text) in grilledCheeseIngredients.enumerated() {
            // Parse ingredient to extract quantity, unit, and name
            let parsed = IngredientParser.parse(text)

            let ingredient = Ingredient(
                originalText: text,
                name: parsed.name.isEmpty ? text : parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit,
                category: GroceryCategory.categorize(parsed.name.isEmpty ? text : parsed.name),
                orderIndex: index
            )
            ingredient.quantityMax = parsed.quantityMax
            ingredient.recipe = grilledCheese
            modelContext.insert(ingredient)
        }

        // Create card back for grilled cheese
        let grilledCheeseCardBack = RecipeCardBack(recipe: grilledCheese)
        grilledCheeseCardBack.showAttribution = true
        grilledCheeseCardBack.noteToFriends = "Your first recipe! Try tapping different parts of the app."
        grilledCheeseCardBack.visibleSections = [.attribution, .noteToFriends]
        grilledCheeseCardBack.isComplete = true
        grilledCheese.cardBack = grilledCheeseCardBack

        modelContext.insert(grilledCheeseCardBack)
        modelContext.insert(grilledCheese)

        // Recipe 2: Tomato Soup
        let tomatoSoup = Recipe(
            title: "Tomato Soup",
            sourceType: .manual,
            instructions: [
                "In a large pot, heat butter over medium heat.",
                "Add diced onion and cook until softened (5 minutes).",
                "Add minced garlic and cook for 1 minute until fragrant.",
                "Add crushed tomatoes, vegetable broth, and dried basil.",
                "Bring to a boil, then reduce heat and simmer for 15 minutes.",
                "Use an immersion blender to puree soup until smooth.",
                "Stir in heavy cream and season with salt and pepper.",
                "Serve hot with grilled cheese on the side."
            ],
            servings: "2",
            prepTime: "5 minutes",
            cookTime: "20 minutes"
        )
        tomatoSoup.sourceStory = "Perfect pairing for a grilled cheese sandwich."
        tomatoSoup.collections = [favorites]

        // Tomato Soup ingredients
        let tomatoSoupIngredients = [
            "2 tablespoons butter",
            "1 medium onion, diced",
            "3 cloves garlic, minced",
            "2 cans (28 oz each) crushed tomatoes",
            "2 cups vegetable broth",
            "1 teaspoon dried basil",
            "1/2 cup heavy cream",
            "Salt and pepper to taste"
        ]

        for (index, text) in tomatoSoupIngredients.enumerated() {
            // Parse ingredient to extract quantity, unit, and name
            let parsed = IngredientParser.parse(text)

            let ingredient = Ingredient(
                originalText: text,
                name: parsed.name.isEmpty ? text : parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit,
                category: GroceryCategory.categorize(parsed.name.isEmpty ? text : parsed.name),
                orderIndex: index
            )
            ingredient.quantityMax = parsed.quantityMax
            ingredient.recipe = tomatoSoup
            modelContext.insert(ingredient)
        }

        // Create card back for tomato soup
        let tomatoSoupCardBack = RecipeCardBack(recipe: tomatoSoup)
        tomatoSoupCardBack.showAttribution = true
        tomatoSoupCardBack.noteToFriends = "Pairs perfectly with the grilled cheese!"
        tomatoSoupCardBack.visibleSections = [.attribution, .noteToFriends]
        tomatoSoupCardBack.isComplete = true
        tomatoSoup.cardBack = tomatoSoupCardBack

        modelContext.insert(tomatoSoupCardBack)
        modelContext.insert(tomatoSoup)

        try modelContext.save()

        // Mark as seeded
        UserDefaults.standard.set(true, forKey: "OnboardingRecipeSeeded")

        // Copy bundled images to file storage
        await copyBundledImageIfAvailable(assetName: "onboarding-grilled-cheese", recipe: grilledCheese)
        await copyBundledImageIfAvailable(assetName: "onboarding-tomato-soup", recipe: tomatoSoup)

        Log.info("Onboarding recipes seeded successfully (2 recipes)", category: .storage, metadata: [
            "recipe1": "Classic Grilled Cheese",
            "recipe2": "Tomato Soup"
        ])
    }

    // MARK: - Migration

    /// Migrate existing onboarding recipes to have parsed ingredients
    /// Call this to fix existing grilled cheese and tomato soup recipes
    func migrateOnboardingIngredients() async throws {
        // Check if migration already done
        guard !UserDefaults.standard.bool(forKey: "OnboardingIngredientsMigrated") else {
            Log.info("Onboarding ingredients already migrated", category: .storage)
            return
        }

        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.title == "Classic Grilled Cheese" || recipe.title == "Tomato Soup"
            }
        )

        let recipes = try modelContext.fetch(descriptor)
        var migratedCount = 0

        Log.info("Starting onboarding ingredient migration", category: .storage, metadata: [
            "recipesFound": recipes.count
        ])

        for recipe in recipes {
            guard let ingredients = recipe.ingredients else { continue }

            for ingredient in ingredients {
                // Only migrate if missing quantity/unit
                if ingredient.quantity == nil && ingredient.unit == nil && !ingredient.originalText.isEmpty {
                    let parsed = IngredientParser.parse(ingredient.originalText)

                    // Update ingredient with parsed values
                    ingredient.name = parsed.name.isEmpty ? ingredient.originalText : parsed.name
                    ingredient.quantity = parsed.quantity
                    ingredient.quantityMax = parsed.quantityMax
                    ingredient.unit = parsed.unit
                    ingredient.category = GroceryCategory.categorize(parsed.name.isEmpty ? ingredient.originalText : parsed.name)

                    migratedCount += 1

                    Log.debug("Migrated onboarding ingredient", category: .storage, metadata: [
                        "recipe": recipe.title,
                        "originalText": ingredient.originalText,
                        "quantity": parsed.quantity ?? 0,
                        "unit": parsed.unit ?? "none"
                    ])
                }
            }
        }

        try modelContext.save()

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: "OnboardingIngredientsMigrated")
        UserDefaults.standard.set(Date(), forKey: "OnboardingIngredientsMigrationDate")

        Log.info("Onboarding ingredient migration completed", category: .storage, metadata: [
            "migratedCount": migratedCount
        ])
    }

    // MARK: - Private Methods

    /// Copy bundled image from Assets.xcassets to file storage
    private func copyBundledImageIfAvailable(assetName: String, recipe: Recipe) async {
        guard let image = UIImage(named: assetName) else {
            Log.warning("Bundled image not found in assets", category: .storage, metadata: ["assetName": assetName])
            return
        }

        do {
            let fileName = try await imageService.saveImage(image, recipeId: recipe.id)
            recipe.imageFileName = fileName
            Log.info("Copied bundled image to storage", category: .storage, metadata: [
                "assetName": assetName,
                "fileName": fileName,
                "recipeTitle": recipe.title
            ])
        } catch {
            Log.error("Failed to copy bundled image", category: .storage, error: error, metadata: [
                "assetName": assetName,
                "recipeTitle": recipe.title
            ])
        }
    }
}
