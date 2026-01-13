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
            let ingredient = Ingredient(
                originalText: text,
                name: text,
                quantity: nil,
                unit: nil,
                category: .other,
                orderIndex: index
            )
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
            let ingredient = Ingredient(
                originalText: text,
                name: text,
                quantity: nil,
                unit: nil,
                category: .other,
                orderIndex: index
            )
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
