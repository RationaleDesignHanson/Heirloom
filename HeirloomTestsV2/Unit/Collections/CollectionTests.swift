//
//  CollectionTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Unit tests for recipe collection management
//
//  Tests collection operations to ensure:
//  - Create, edit, delete collections
//  - Recipe membership and relationships
//  - Collection types and categories
//  - NEW badge detection
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class CollectionTests: XCTestCase {

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

    /// Test 1: Create collection with name only
    func test_createCollection_withNameOnly_succeeds() throws {
        // GIVEN: Collection name
        let collection = RecipeCollection(name: "My Collection")

        // WHEN: Inserting into context
        env.modelContext.insert(collection)
        try env.save()

        // THEN: Collection should be persisted
        let collections = try env.fetchAllCollections()
        XCTAssertEqual(collections.count, 1)
        XCTAssertEqual(collections.first?.name, "My Collection")
    }

    /// Test 2: Create collection with all fields
    func test_createCollection_withAllFields_succeeds() throws {
        // GIVEN: Fully configured collection
        let collection = RecipeCollection(
            name: "Holiday Recipes",
            description: "Special occasion recipes",
            iconName: "star.fill",
            color: "#FF0000",
            isSystemCollection: false,
            collectionType: .userCreated
        )

        // WHEN: Inserting
        env.modelContext.insert(collection)
        try env.save()

        // THEN: All fields persisted
        let fetched = try env.fetchAllCollections().first!
        XCTAssertEqual(fetched.name, "Holiday Recipes")
        XCTAssertEqual(fetched.desc, "Special occasion recipes")
        XCTAssertEqual(fetched.iconName, "star.fill")
        XCTAssertEqual(fetched.color, "#FF0000")
        XCTAssertFalse(fetched.isSystemCollection)
        XCTAssertEqual(fetched.type, .userCreated)
    }

    /// Test 3: Create collection generates unique ID
    func test_createCollection_generatesUniqueId() throws {
        // GIVEN/WHEN: Creating multiple collections
        let collection1 = RecipeCollection(name: "Collection 1")
        let collection2 = RecipeCollection(name: "Collection 2")
        env.modelContext.insert(collection1)
        env.modelContext.insert(collection2)
        try env.save()

        // THEN: IDs should be unique
        XCTAssertNotEqual(collection1.id, collection2.id)
    }

    // MARK: - Update Tests

    /// Test 4: Update collection name
    func test_updateCollection_name_persists() throws {
        // GIVEN: Existing collection
        let collection = RecipeCollection(name: "Original Name")
        env.modelContext.insert(collection)
        try env.save()

        // WHEN: Updating name
        collection.name = "Updated Name"
        try env.save()

        // THEN: Name should be updated
        let fetched = try env.fetchAllCollections().first!
        XCTAssertEqual(fetched.name, "Updated Name")
    }

    /// Test 5: Update collection color
    func test_updateCollection_color_persists() throws {
        // GIVEN: Collection with default color
        let collection = RecipeCollection(name: "Test")
        env.modelContext.insert(collection)
        try env.save()

        // WHEN: Changing color
        collection.color = "#00FF00"
        try env.save()

        // THEN: Color should be updated
        let fetched = try env.fetchAllCollections().first!
        XCTAssertEqual(fetched.color, "#00FF00")
    }

    // MARK: - Delete Tests

    /// Test 6: Delete collection removes from database
    func test_deleteCollection_removesFromDatabase() throws {
        // GIVEN: Collection in database
        let collection = RecipeCollection(name: "To Delete")
        env.modelContext.insert(collection)
        try env.save()
        XCTAssertEqual(try env.fetchAllCollections().count, 1)

        // WHEN: Deleting
        env.modelContext.delete(collection)
        try env.save()

        // THEN: Collection should be gone
        XCTAssertEqual(try env.fetchAllCollections().count, 0)
    }

    /// Test 7: Delete collection does not delete recipes (nullify relationship)
    func test_deleteCollection_keepsRecipes() throws {
        // GIVEN: Collection with recipe
        let collection = RecipeCollection(name: "Test Collection")
        let recipe = env.createTestRecipe(title: "Test Recipe")

        collection.recipes = [recipe]
        recipe.collections = [collection]
        env.modelContext.insert(collection)
        try env.save()

        // WHEN: Deleting collection
        env.modelContext.delete(collection)
        try env.save()

        // THEN: Recipe should still exist
        let recipes = try env.fetchAllRecipes()
        XCTAssertEqual(recipes.count, 1)
        XCTAssertTrue(recipes.first?.collections?.isEmpty ?? true)
    }

    // MARK: - Recipe Membership Tests

    /// Test 8: Add recipe to collection
    func test_addRecipe_toCollection_succeeds() throws {
        // GIVEN: Collection and recipe
        let collection = RecipeCollection(name: "My Collection")
        let recipe = env.createTestRecipe(title: "My Recipe")
        env.modelContext.insert(collection)
        try env.save()

        // WHEN: Adding recipe to collection
        if collection.recipes == nil { collection.recipes = [] }
        if recipe.collections == nil { recipe.collections = [] }
        collection.recipes?.append(recipe)
        recipe.collections?.append(collection)
        try env.save()

        // THEN: Relationship should be established
        XCTAssertEqual(collection.recipes?.count, 1)
        XCTAssertEqual(recipe.collections?.count, 1)
    }

    /// Test 9: Recipe count computed property
    func test_recipeCount_computedCorrectly() throws {
        // GIVEN: Collection
        let collection = RecipeCollection(name: "Test")
        env.modelContext.insert(collection)
        collection.recipes = []
        try env.save()

        XCTAssertEqual(collection.recipeCount, 0)

        // WHEN: Adding recipes
        let recipe1 = env.createTestRecipe(title: "Recipe 1")
        let recipe2 = env.createTestRecipe(title: "Recipe 2")
        collection.recipes?.append(recipe1)
        collection.recipes?.append(recipe2)
        try env.save()

        // THEN: Count should update
        XCTAssertEqual(collection.recipeCount, 2)
    }

    /// Test 10: Recipe can belong to multiple collections
    func test_recipe_belongsToMultipleCollections() throws {
        // GIVEN: Two collections and a recipe
        let collection1 = RecipeCollection(name: "Favorites")
        let collection2 = RecipeCollection(name: "Quick Meals")
        let recipe = env.createTestRecipe(title: "Quick Favorite")

        collection1.recipes = []
        collection2.recipes = []
        recipe.collections = []

        env.modelContext.insert(collection1)
        env.modelContext.insert(collection2)
        try env.save()

        // WHEN: Adding recipe to both collections
        collection1.recipes?.append(recipe)
        collection2.recipes?.append(recipe)
        recipe.collections?.append(collection1)
        recipe.collections?.append(collection2)
        try env.save()

        // THEN: Recipe belongs to both
        XCTAssertEqual(recipe.collections?.count, 2)
        XCTAssertTrue(collection1.recipes?.contains(where: { $0.id == recipe.id }) ?? false)
        XCTAssertTrue(collection2.recipes?.contains(where: { $0.id == recipe.id }) ?? false)
    }

    // MARK: - Collection Type Tests

    /// Test 11: User created collection type
    func test_collectionType_userCreated_isDefault() throws {
        // GIVEN: Default collection
        let collection = RecipeCollection(name: "Test")
        env.modelContext.insert(collection)
        try env.save()

        // THEN: Should be user created
        XCTAssertEqual(collection.type, .userCreated)
    }

    /// Test 12: Collection type affects visibility
    func test_collectionType_systemCollection_notVisibleInMainList() throws {
        // GIVEN: System collection
        let systemCollection = RecipeCollection(
            name: "Favorites",
            isSystemCollection: true,
            collectionType: .system
        )
        env.modelContext.insert(systemCollection)
        try env.save()

        // THEN: Should not be visible in main list
        XCTAssertFalse(systemCollection.isVisibleInMainList)
    }

    /// Test 13: Theme collection is visible
    func test_collectionType_themeCollection_isVisible() throws {
        // GIVEN: Theme collection
        let themeCollection = RecipeCollection(
            name: "American Classics",
            collectionType: .theme
        )
        themeCollection.recipes = [env.createTestRecipe()]
        env.modelContext.insert(themeCollection)
        try env.save()

        // THEN: Should be visible
        XCTAssertTrue(themeCollection.isVisibleInMainList)
    }

    // MARK: - Display Properties Tests

    /// Test 14: Display description for empty collection
    func test_displayDescription_emptyCollection() throws {
        // GIVEN: Empty collection
        let collection = RecipeCollection(name: "Empty")
        collection.recipes = []
        env.modelContext.insert(collection)
        try env.save()

        // THEN: Should say "No recipes yet"
        XCTAssertEqual(collection.displayDescription, "No recipes yet")
    }

    /// Test 15: Display description for single recipe
    func test_displayDescription_singleRecipe() throws {
        // GIVEN: Collection with one recipe
        let collection = RecipeCollection(name: "One Recipe")
        collection.recipes = [env.createTestRecipe()]
        env.modelContext.insert(collection)
        try env.save()

        // THEN: Should be singular
        XCTAssertEqual(collection.displayDescription, "1 recipe")
    }

    /// Test 16: Display description for multiple recipes
    func test_displayDescription_multipleRecipes() throws {
        // GIVEN: Collection with multiple recipes
        let collection = RecipeCollection(name: "Multiple")
        collection.recipes = [
            env.createTestRecipe(title: "Recipe 1"),
            env.createTestRecipe(title: "Recipe 2"),
            env.createTestRecipe(title: "Recipe 3")
        ]
        env.modelContext.insert(collection)
        try env.save()

        // THEN: Should be plural
        XCTAssertEqual(collection.displayDescription, "3 recipes")
    }

    // MARK: - NEW Badge Tests

    /// Test 17: Has new recipes returns false for empty collection
    func test_hasNewRecipes_emptyCollection_returnsFalse() throws {
        // GIVEN: Empty collection
        let collection = RecipeCollection(name: "Empty")
        collection.recipes = []
        env.modelContext.insert(collection)
        try env.save()

        // THEN: No new recipes
        XCTAssertFalse(collection.hasNewRecipes)
    }

    /// Test 18: Mark as viewed clears new badge
    func test_markAsViewed_clearsNewBadge() throws {
        // GIVEN: Collection with new recipe
        let collection = RecipeCollection(name: "Test")
        let recipe = env.createTestRecipe()
        recipe.createdAt = Date() // Just created
        collection.recipes = [recipe]
        collection.lastViewedDate = nil
        env.modelContext.insert(collection)
        try env.save()

        // Pre-condition: Should have new recipes
        XCTAssertTrue(collection.hasNewRecipes)

        // WHEN: Marking as viewed
        collection.markAsViewed()
        try env.save()

        // THEN: Should no longer have new recipes (future recipes would be new)
        XCTAssertNotNil(collection.lastViewedDate)
    }
}
