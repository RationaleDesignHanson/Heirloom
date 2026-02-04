//
//  TestEnvironment.swift
//  HeirloomTestsV2
//
//  Minimal test environment for creating in-memory SwiftData containers
//  Following the DailyUnlockIntegrationTest pattern
//

import XCTest
import SwiftData
@testable import Heirloom

/// Minimal test environment providing in-memory SwiftData context
@MainActor
struct TestEnvironment {

    // MARK: - Properties

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    // MARK: - Initialization

    /// Create a test environment with optional authentication and credits
    static func create(
        authenticated: Bool = false,
        credits: Int = 25
    ) async throws -> TestEnvironment {
        // Minimal schema - add models as needed
        let schema = Schema([
            Recipe.self,
            RecipeCollection.self,
            Ingredient.self,
            RecipeLineage.self,
            UserCredits.self
        ])

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        return TestEnvironment(
            modelContainer: container,
            modelContext: context
        )
    }

    // MARK: - Cleanup

    func tearDown() {
        // Reset any test state
        let keys = [
            "heritageUnlockedRecipeIds",
            "heritageLastUnlockDate",
            "heritageTrialStartDate",
            "trialStartDate",
            "lastUnlockDate"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Save Helper

    func save() throws {
        try modelContext.save()
    }

    // MARK: - Recipe Helpers

    /// Create a basic test recipe
    @discardableResult
    func createTestRecipe(
        title: String = "Test Recipe",
        servings: String? = "4 servings"
    ) -> Recipe {
        let recipe = Recipe(
            title: title,
            instructions: ["Step 1", "Step 2"],
            servings: servings
        )
        modelContext.insert(recipe)
        return recipe
    }

    /// Create a test ingredient attached to a recipe
    @discardableResult
    func createTestIngredient(
        name: String = "Test Ingredient",
        quantity: Double? = 1.0,
        unit: String? = "cup",
        recipe: Recipe
    ) -> Ingredient {
        let ingredient = Ingredient(
            originalText: "\(quantity ?? 0) \(unit ?? "") \(name)",
            name: name,
            quantity: quantity,
            unit: unit
        )
        ingredient.recipe = recipe
        modelContext.insert(ingredient)

        if recipe.ingredients == nil {
            recipe.ingredients = []
        }
        recipe.ingredients?.append(ingredient)

        return ingredient
    }

    /// Create a test collection
    @discardableResult
    func createTestCollection(
        name: String = "Test Collection",
        type: CollectionType = .userCreated
    ) -> RecipeCollection {
        let collection = RecipeCollection(name: name, collectionType: type)
        modelContext.insert(collection)
        return collection
    }

    /// Create test user credits
    @discardableResult
    func createUserCredits(
        userId: String = "test-user-123",
        purchasedCredits: Int = 0,
        dailyQuotaUsed: Int = 0
    ) -> UserCredits {
        let credits = UserCredits(userId: userId)
        credits.creditsBalance = purchasedCredits
        credits.dailyQuotaUsed = dailyQuotaUsed
        modelContext.insert(credits)
        return credits
    }

    // MARK: - Fetch Helpers

    func fetchAllRecipes() throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>()
        return try modelContext.fetch(descriptor)
    }

    func fetchAllCollections() throws -> [RecipeCollection] {
        let descriptor = FetchDescriptor<RecipeCollection>()
        return try modelContext.fetch(descriptor)
    }

    func fetchUserCredits() throws -> UserCredits? {
        let descriptor = FetchDescriptor<UserCredits>()
        return try modelContext.fetch(descriptor).first
    }
}
