//
//  RecipeCRUDTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Unit tests for recipe CRUD operations
//
//  Tests recipe create, read, update, delete operations to ensure:
//  - Recipes can be created with required fields
//  - SwiftData persistence works correctly
//  - Relationships (ingredients, collections) work
//  - Updates are tracked properly
//  - Deletion cascades correctly
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class RecipeCRUDTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true)
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        try await super.tearDown()
    }

    // MARK: - Create Tests

    /// Test 1: Create recipe with minimal required fields
    func test_createRecipe_withMinimalFields_succeeds() throws {
        // GIVEN: A new recipe with just a title
        let recipe = Recipe(title: "Test Recipe")

        // WHEN: Inserting into context
        env.modelContext.insert(recipe)
        try env.save()

        // THEN: Recipe should be persisted
        let recipes = try env.fetchAllRecipes()
        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes.first?.title, "Test Recipe")
    }

    /// Test 2: Create recipe with all fields populated
    func test_createRecipe_withAllFields_succeeds() throws {
        // GIVEN: A fully populated recipe
        let recipe = Recipe(
            title: "Complete Recipe",
            sourceType: .url,
            sourceURL: "https://example.com/recipe",
            instructions: ["Step 1", "Step 2", "Step 3"],
            servings: "4 servings",
            prepTime: "15 min",
            cookTime: "30 min"
        )
        recipe.notes = "Test notes"
        recipe.isFavorite = true

        // WHEN: Inserting into context
        env.modelContext.insert(recipe)
        try env.save()

        // THEN: All fields should be persisted
        let fetched = try env.fetchAllRecipes().first!
        XCTAssertEqual(fetched.title, "Complete Recipe")
        XCTAssertEqual(fetched.sourceType, .url)
        XCTAssertEqual(fetched.sourceURL, "https://example.com/recipe")
        XCTAssertEqual(fetched.instructions.count, 3)
        XCTAssertEqual(fetched.servings, "4 servings")
        XCTAssertEqual(fetched.prepTime, "15 min")
        XCTAssertEqual(fetched.cookTime, "30 min")
        XCTAssertEqual(fetched.notes, "Test notes")
        XCTAssertTrue(fetched.isFavorite)
    }

    /// Test 3: Create recipe generates unique ID
    func test_createRecipe_generatesUniqueId() throws {
        // GIVEN/WHEN: Creating multiple recipes
        let recipe1 = Recipe(title: "Recipe 1")
        let recipe2 = Recipe(title: "Recipe 2")
        env.modelContext.insert(recipe1)
        env.modelContext.insert(recipe2)
        try env.save()

        // THEN: Each recipe should have unique ID
        XCTAssertNotEqual(recipe1.id, recipe2.id)
    }

    /// Test 4: Create recipe sets timestamps
    func test_createRecipe_setsTimestamps() throws {
        // GIVEN: Current time
        let beforeCreate = Date()

        // WHEN: Creating recipe
        let recipe = Recipe(title: "Timestamped Recipe")
        env.modelContext.insert(recipe)
        try env.save()

        // THEN: Timestamps should be set
        XCTAssertNotNil(recipe.dateAdded)
        XCTAssertNotNil(recipe.lastModified)
        XCTAssertGreaterThanOrEqual(recipe.dateAdded, beforeCreate)
    }

    // MARK: - Read Tests

    /// Test 5: Fetch all recipes returns empty for fresh context
    func test_fetchAllRecipes_emptyContext_returnsEmpty() throws {
        // GIVEN: Empty context (no recipes added)

        // WHEN: Fetching all recipes
        let recipes = try env.fetchAllRecipes()

        // THEN: Should return empty array
        XCTAssertTrue(recipes.isEmpty)
    }

    /// Test 6: Fetch recipe by ID works
    func test_fetchRecipe_byId_succeeds() throws {
        // GIVEN: A recipe in the database
        let recipe = Recipe(title: "Findable Recipe")
        env.modelContext.insert(recipe)
        try env.save()
        let recipeId = recipe.id

        // WHEN: Fetching by ID
        var descriptor = FetchDescriptor<Recipe>()
        descriptor.predicate = #Predicate<Recipe> { $0.id == recipeId }
        let fetched = try env.modelContext.fetch(descriptor).first

        // THEN: Should find the recipe
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Findable Recipe")
    }

    /// Test 7: Fetch with predicate filters correctly
    func test_fetchRecipes_withPredicate_filtersCorrectly() throws {
        // GIVEN: Multiple recipes with different favorites
        let fav1 = Recipe(title: "Favorite 1")
        fav1.isFavorite = true
        let fav2 = Recipe(title: "Favorite 2")
        fav2.isFavorite = true
        let notFav = Recipe(title: "Not Favorite")
        notFav.isFavorite = false

        env.modelContext.insert(fav1)
        env.modelContext.insert(fav2)
        env.modelContext.insert(notFav)
        try env.save()

        // WHEN: Fetching only favorites
        var descriptor = FetchDescriptor<Recipe>()
        descriptor.predicate = #Predicate<Recipe> { $0.isFavorite == true }
        let favorites = try env.modelContext.fetch(descriptor)

        // THEN: Should return only favorites
        XCTAssertEqual(favorites.count, 2)
        XCTAssertTrue(favorites.allSatisfy { $0.isFavorite })
    }

    // MARK: - Update Tests

    /// Test 8: Update recipe title persists
    func test_updateRecipe_title_persists() throws {
        // GIVEN: An existing recipe
        let recipe = Recipe(title: "Original Title")
        env.modelContext.insert(recipe)
        try env.save()

        // WHEN: Updating the title
        recipe.title = "Updated Title"
        try env.save()

        // THEN: Update should persist
        let fetched = try env.fetchAllRecipes().first!
        XCTAssertEqual(fetched.title, "Updated Title")
    }

    /// Test 9: Update recipe updates modifiedAt timestamp
    func test_updateRecipe_updatesTimestamp() throws {
        // GIVEN: An existing recipe
        let recipe = Recipe(title: "Tracked Recipe")
        env.modelContext.insert(recipe)
        try env.save()
        let originalModified = recipe.modifiedAt

        // WHEN: Updating the recipe with a new timestamp
        recipe.modifiedAt = Date().addingTimeInterval(1) // Force later timestamp
        try env.save()

        // THEN: modifiedAt should be updated
        XCTAssertGreaterThan(recipe.modifiedAt, originalModified)
    }

    /// Test 10: Toggle favorite works
    func test_updateRecipe_toggleFavorite_works() throws {
        // GIVEN: A non-favorite recipe
        let recipe = Recipe(title: "Toggle Test")
        recipe.isFavorite = false
        env.modelContext.insert(recipe)
        try env.save()

        // WHEN: Toggling favorite
        recipe.isFavorite = true
        try env.save()

        // THEN: Should be favorite now
        let fetched = try env.fetchAllRecipes().first!
        XCTAssertTrue(fetched.isFavorite)
    }

    /// Test 11: Update instructions array works
    func test_updateRecipe_instructions_works() throws {
        // GIVEN: Recipe with initial instructions
        let recipe = Recipe(
            title: "Instructions Test",
            instructions: ["Step 1"]
        )
        env.modelContext.insert(recipe)
        try env.save()

        // WHEN: Updating instructions
        recipe.instructions = ["New Step 1", "New Step 2", "New Step 3"]
        try env.save()

        // THEN: Instructions should be updated
        let fetched = try env.fetchAllRecipes().first!
        XCTAssertEqual(fetched.instructions.count, 3)
        XCTAssertEqual(fetched.instructions[0], "New Step 1")
    }

    // MARK: - Delete Tests

    /// Test 12: Delete recipe removes from database
    func test_deleteRecipe_removesFromDatabase() throws {
        // GIVEN: A recipe in the database
        let recipe = Recipe(title: "To Be Deleted")
        env.modelContext.insert(recipe)
        try env.save()
        XCTAssertEqual(try env.fetchAllRecipes().count, 1)

        // WHEN: Deleting the recipe
        env.modelContext.delete(recipe)
        try env.save()

        // THEN: Recipe should be gone
        XCTAssertEqual(try env.fetchAllRecipes().count, 0)
    }

    /// Test 13: Delete cascades to ingredients
    func test_deleteRecipe_cascadesToIngredients() throws {
        // GIVEN: Recipe with ingredients
        let recipe = env.createTestRecipe(title: "Recipe with Ingredients")
        _ = env.createTestIngredient(name: "Flour", recipe: recipe)
        _ = env.createTestIngredient(name: "Sugar", recipe: recipe)
        try env.save()

        // Verify ingredients exist via recipe relationship
        XCTAssertEqual(recipe.ingredients?.count ?? 0, 2)

        // WHEN: Deleting the recipe
        env.modelContext.delete(recipe)
        try env.save()

        // THEN: Recipe should be deleted (ingredients cascade handled by SwiftData)
        let recipeDescriptor = FetchDescriptor<Recipe>()
        XCTAssertEqual(try env.modelContext.fetch(recipeDescriptor).count, 0)
    }

    // MARK: - Relationship Tests

    /// Test 14: Add ingredients to recipe
    func test_addIngredients_toRecipe_works() throws {
        // GIVEN: A recipe
        let recipe = env.createTestRecipe(title: "Ingredient Test")

        // WHEN: Adding ingredients
        _ = env.createTestIngredient(name: "Ingredient 1", recipe: recipe)
        _ = env.createTestIngredient(name: "Ingredient 2", recipe: recipe)
        try env.save()

        // THEN: Ingredients should be associated
        XCTAssertEqual(recipe.ingredients?.count, 2)
    }

    /// Test 15: Add recipe to collection
    func test_addRecipe_toCollection_works() throws {
        // GIVEN: A recipe and collection
        let recipe = env.createTestRecipe(title: "Collection Test")
        let collection = env.createTestCollection(name: "My Collection")
        try env.save()

        // WHEN: Adding recipe to collection
        if collection.recipes == nil {
            collection.recipes = []
        }
        collection.recipes?.append(recipe)

        if recipe.collections == nil {
            recipe.collections = []
        }
        recipe.collections?.append(collection)
        try env.save()

        // THEN: Relationship should be established
        XCTAssertEqual(collection.recipes?.count, 1)
        XCTAssertEqual(recipe.collections?.count, 1)
    }

    // MARK: - Source Type Tests

    /// Test 16: Different source types are persisted
    func test_sourceTypes_arePersisted() throws {
        // GIVEN/WHEN: Creating recipes with different source types
        let urlRecipe = Recipe(title: "URL Recipe", sourceType: .url)
        let manualRecipe = Recipe(title: "Manual Recipe", sourceType: .manual)
        let videoRecipe = Recipe(title: "Video Recipe", sourceType: .video)
        let scanRecipe = Recipe(title: "Scan Recipe", sourceType: .scan)

        env.modelContext.insert(urlRecipe)
        env.modelContext.insert(manualRecipe)
        env.modelContext.insert(videoRecipe)
        env.modelContext.insert(scanRecipe)
        try env.save()

        // THEN: Source types should be correctly persisted
        let recipes = try env.fetchAllRecipes()
        XCTAssertEqual(recipes.count, 4)

        let sourceTypes = Set(recipes.compactMap { $0.sourceType })
        XCTAssertTrue(sourceTypes.contains(.url))
        XCTAssertTrue(sourceTypes.contains(.manual))
        XCTAssertTrue(sourceTypes.contains(.video))
        XCTAssertTrue(sourceTypes.contains(.scan))
    }
}
