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
    ) -> Recipe {
        let recipe = Recipe()
        if let id = id {
            recipe.id = UUID(uuidString: id) ?? UUID()
        }
        recipe.title = title
        recipe.isHeritageRecipe = true
        recipe.heritageCollectionId = collectionId
        recipe.servings = 4
        recipe.cookTime = 30
        recipe.ingredients = [
            Ingredient(quantity: "2", unit: "cups", name: "flour"),
            Ingredient(quantity: "1", unit: "tsp", name: "salt")
        ]
        recipe.instructions = [
            Instruction(text: "Mix ingredients", order: 0)
        ]

        context.insert(recipe)
        return recipe
    }

    /// Create multiple heritage recipes (Literary Kitchen collection)
    static func createLiteraryKitchenRecipes(
        count: Int,
        context: ModelContext
    ) -> [Recipe] {
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
    ) -> [Recipe] {
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
    ) -> Recipe {
        let recipe = Recipe()
        recipe.title = title
        recipe.isHeritageRecipe = false
        recipe.servings = 4
        recipe.cookTime = 30
        recipe.ingredients = [
            Ingredient(quantity: "1", unit: "cup", name: "water")
        ]
        recipe.instructions = [
            Instruction(text: "Boil water", order: 0)
        ]

        context.insert(recipe)
        return recipe
    }

    /// Create multiple regular recipes
    static func createRegularRecipes(
        count: Int,
        context: ModelContext
    ) -> [Recipe] {
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
    ) -> RecipeCollection {
        let collection = RecipeCollection()
        collection.title = title
        collection.heritageCollectionId = heritageId
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
    ) -> [RecipeCollection] {
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
    ) -> RecipeCollection {
        let collection = RecipeCollection()
        collection.title = title
        collection.isBlindBox = false

        context.insert(collection)
        return collection
    }

    // MARK: - Complete Test Scenarios

    /// Set up a complete onboarding scenario
    /// - Returns: Tuple of (blind box collections, onboarding recipe)
    static func setupOnboardingScenario(
        context: ModelContext
    ) -> (collections: [RecipeCollection], onboardingRecipe: Recipe) {
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
    ) -> (collections: [RecipeCollection], heritageRecipes: [Recipe], regularRecipes: [Recipe]) {
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
        let schema = Schema([
            Recipe.self,
            RecipeCollection.self,
            Ingredient.self,
            Instruction.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )

        return ModelContext(container)
    }
}
