//
//  TestRecipeFactory.swift
//  HeirloomTestsV2
//
//  Factory for creating test Recipe instances
//  Created: 2026-01-13
//

import Foundation
import SwiftData
@testable import Heirloom

/// Factory for creating test recipes with configurable properties
@MainActor
final class TestRecipeFactory {

    // MARK: - Heritage Recipes

    /// Create a heritage recipe with specific collection ID
    static func createHeritageRecipe(
        id: String? = nil,
        title: String = "Test Heritage Recipe",
        collectionId: String = "literary_kitchen",
        context: ModelContext
    ) -> Heirloom.Recipe {
        // Create recipe using Heirloom module's custom init
        let recipe = Heirloom.Recipe(
            title: title,
            sourceType: .heritage,
            instructions: ["Mix ingredients", "Bake until done"],
            servings: "4",
            cookTime: "30"
        )

        if let id = id {
            recipe.id = UUID(uuidString: id) ?? UUID()
        }
        recipe.isThemeRecipe = true
        recipe.sourceThemeId = collectionId

        // Create ingredients using Heirloom module's init
        let ing1 = Heirloom.Ingredient(name: "flour", quantity: 2.0, unit: "cups")
        let ing2 = Heirloom.Ingredient(name: "salt", quantity: 1.0, unit: "tsp")

        // Insert into context first, then establish relationships
        context.insert(recipe)
        context.insert(ing1)
        context.insert(ing2)

        recipe.ingredients = [ing1, ing2]

        return recipe
    }

    /// Create multiple heritage recipes (Literary Kitchen collection)
    static func createLiteraryKitchenRecipes(
        count: Int,
        context: ModelContext
    ) -> [Heirloom.Recipe] {
        return (0..<count).map { index in
            createHeritageRecipe(
                title: "Literary Kitchen Recipe \(index + 1)",
                collectionId: "literary_kitchen",
                context: context
            )
        }
    }

    /// Create multiple heritage recipes (Regional collection)
    static func createRegionalRecipes(
        count: Int,
        collectionId: String = "regional_001",
        context: ModelContext
    ) -> [Heirloom.Recipe] {
        return (0..<count).map { index in
            createHeritageRecipe(
                title: "Regional Recipe \(index + 1)",
                collectionId: collectionId,
                context: context
            )
        }
    }

    // MARK: - Regular Recipes

    /// Create a regular (non-heritage) recipe
    static func createRegularRecipe(
        title: String = "Test Recipe",
        context: ModelContext
    ) -> Heirloom.Recipe {
        let recipe = Heirloom.Recipe(
            title: title,
            sourceType: .manual,
            instructions: ["Boil water"],
            servings: "4",
            cookTime: "30"
        )
        recipe.isThemeRecipe = false

        let ing = Heirloom.Ingredient(name: "water", quantity: 1.0, unit: "cup")

        // Insert into context first, then establish relationships
        context.insert(recipe)
        context.insert(ing)

        recipe.ingredients = [ing]

        return recipe
    }

    /// Create multiple regular recipes
    static func createRegularRecipes(
        count: Int,
        context: ModelContext
    ) -> [Heirloom.Recipe] {
        return (0..<count).map { index in
            createRegularRecipe(title: "Recipe \(index + 1)", context: context)
        }
    }

    // MARK: - Collections

    /// Create a blind box collection (heritage)
    static func createBlindBoxCollection(
        heritageId: String = "literary_kitchen",
        title: String = "Literary Kitchen",
        isRevealed: Bool = false,
        context: ModelContext
    ) -> Heirloom.RecipeCollection {
        let collection = RecipeCollection(
            name: title,
            sourceThemeId: heritageId
        )
        collection.isBlindBox = true
        collection.isRevealed = isRevealed

        context.insert(collection)
        return collection
    }

    /// Create multiple blind box collections
    static func createBlindBoxCollections(
        count: Int,
        revealed: Bool = false,
        context: ModelContext
    ) -> [Heirloom.RecipeCollection] {
        let collectionIds = [
            "literary_kitchen",
            "regional_001",
            "regional_002",
            "regional_003",
            "regional_004"
        ]

        return (0..<min(count, collectionIds.count)).map { index in
            createBlindBoxCollection(
                heritageId: collectionIds[index],
                title: "Heritage Collection \(index + 1)",
                isRevealed: revealed,
                context: context
            )
        }
    }

    /// Create a regular collection (non-blind box)
    static func createRegularCollection(
        title: String = "My Collection",
        context: ModelContext
    ) -> Heirloom.RecipeCollection {
        let collection = RecipeCollection(name: title)
        collection.isBlindBox = false

        context.insert(collection)
        return collection
    }

    // MARK: - Complete Test Scenarios

    /// Set up a complete onboarding scenario
    /// - Returns: Tuple of (blind box collections, onboarding recipe)
    static func setupOnboardingScenario(
        context: ModelContext
    ) -> (collections: [Heirloom.RecipeCollection], onboardingRecipe: Heirloom.Recipe) {
        // Create 5 blind box collections (not revealed yet)
        let collections = createBlindBoxCollections(count: 5, revealed: false, context: context)

        // Create onboarding recipe
        let onboardingRecipe = createRegularRecipe(title: "Welcome to Heirloom", context: context)

        return (collections, onboardingRecipe)
    }

    /// Set up a trial scenario with revealed collections and unlocked recipes
    /// - Returns: Tuple of (collections, heritage recipes, regular recipes)
    static func setupTrialScenario(
        day: Int,
        context: ModelContext
    ) -> (collections: [Heirloom.RecipeCollection], heritageRecipes: [Heirloom.Recipe], regularRecipes: [Heirloom.Recipe]) {
        // Create revealed blind box collections
        let collections = createBlindBoxCollections(count: 5, revealed: true, context: context)

        // Create heritage recipes (7 per day)
        let unlockedCount = day * 7
        let literaryCount = Int(Double(unlockedCount) * 0.7) // 70% Literary Kitchen
        let regionalCount = unlockedCount - literaryCount    // 30% Regional

        let literaryRecipes = createLiteraryKitchenRecipes(count: literaryCount, context: context)
        let regionalRecipes = createRegionalRecipes(count: regionalCount, context: context)
        let heritageRecipes = literaryRecipes + regionalRecipes

        // Create some regular user recipes
        let regularRecipes = createRegularRecipes(count: 3, context: context)

        return (collections, heritageRecipes, regularRecipes)
    }
}

// MARK: - In-Memory ModelContext Helper

extension TestRecipeFactory {

    /// Create an in-memory SwiftData ModelContext for testing
    /// - Returns: ModelContext configured for testing
    static func createTestModelContext() throws -> ModelContext {
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: Heirloom.Recipe.self, Heirloom.RecipeCollection.self, Heirloom.Ingredient.self,
            configurations: modelConfiguration
        )

        return ModelContext(container)
    }
}
