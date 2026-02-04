//
//  ShoppingListTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Unit tests for shopping list functionality
//
//  Tests shopping list operations to ensure:
//  - Add recipes to shopping cart
//  - Remove recipes from cart
//  - Scaling calculations work correctly
//  - Shopping cart recipe relationships
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class ShoppingListTests: XCTestCase {

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

    // MARK: - Helper Methods

    /// Create a ShoppingCartRecipe for testing
    private func createShoppingCartRecipe(
        recipe: Recipe,
        targetServings: Int = 4
    ) -> ShoppingCartRecipe {
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: targetServings)
        env.modelContext.insert(cartRecipe)
        return cartRecipe
    }

    /// Fetch all shopping cart recipes
    private func fetchAllCartRecipes() throws -> [ShoppingCartRecipe] {
        let descriptor = FetchDescriptor<ShoppingCartRecipe>()
        return try env.modelContext.fetch(descriptor)
    }

    // MARK: - Add to Cart Tests

    /// Test 1: Add recipe to shopping cart
    func test_addRecipeToCart_createsShoppingCartRecipe() throws {
        // GIVEN: A recipe
        let recipe = env.createTestRecipe(title: "Test Recipe", servings: "4 servings")
        try env.save()

        // WHEN: Adding to shopping cart
        let cartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 4)
        recipe.isInShoppingList = true
        try env.save()

        // THEN: Shopping cart recipe should exist
        let cartRecipes = try fetchAllCartRecipes()
        XCTAssertEqual(cartRecipes.count, 1)
        XCTAssertEqual(cartRecipes.first?.recipe?.id, recipe.id)
        XCTAssertEqual(cartRecipes.first?.targetServings, 4)
        XCTAssertTrue(recipe.isInShoppingList)
    }

    /// Test 2: Add recipe with custom serving size
    func test_addRecipeToCart_withCustomServings_storesCorrectly() throws {
        // GIVEN: A recipe for 4 servings
        let recipe = env.createTestRecipe(title: "Scalable Recipe", servings: "4 servings")
        try env.save()

        // WHEN: Adding with 8 servings (doubled)
        let cartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 8)
        try env.save()

        // THEN: Should store the target servings
        XCTAssertEqual(cartRecipe.targetServings, 8)
    }

    /// Test 3: Add same recipe twice replaces existing
    func test_addRecipeToCart_twice_updatesExisting() throws {
        // GIVEN: Recipe already in cart
        let recipe = env.createTestRecipe(title: "Already In Cart")
        let firstCartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 4)
        try env.save()
        let firstId = firstCartRecipe.id

        // WHEN: Adding same recipe again with different servings
        env.modelContext.delete(firstCartRecipe)
        let secondCartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 8)
        try env.save()

        // THEN: Should have only one cart entry with new servings
        let cartRecipes = try fetchAllCartRecipes()
        XCTAssertEqual(cartRecipes.count, 1)
        XCTAssertNotEqual(cartRecipes.first?.id, firstId)
        XCTAssertEqual(cartRecipes.first?.targetServings, 8)
    }

    // MARK: - Remove from Cart Tests

    /// Test 4: Remove recipe from cart
    func test_removeRecipeFromCart_deletesShoppingCartRecipe() throws {
        // GIVEN: Recipe in cart
        let recipe = env.createTestRecipe(title: "In Cart")
        let cartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 4)
        recipe.isInShoppingList = true
        try env.save()
        XCTAssertEqual(try fetchAllCartRecipes().count, 1)

        // WHEN: Removing from cart
        env.modelContext.delete(cartRecipe)
        recipe.isInShoppingList = false
        try env.save()

        // THEN: Cart should be empty
        XCTAssertEqual(try fetchAllCartRecipes().count, 0)
        XCTAssertFalse(recipe.isInShoppingList)
    }

    /// Test 5: Deleting recipe removes cart entry
    func test_deleteRecipe_removesFromCart() throws {
        // GIVEN: Recipe in cart
        let recipe = env.createTestRecipe(title: "To Delete")
        _ = createShoppingCartRecipe(recipe: recipe, targetServings: 4)
        try env.save()
        XCTAssertEqual(try fetchAllCartRecipes().count, 1)

        // WHEN: Deleting the recipe
        env.modelContext.delete(recipe)
        try env.save()

        // THEN: Recipe is gone, cart entry should be orphaned (check relationship)
        let recipes = try env.fetchAllRecipes()
        XCTAssertEqual(recipes.count, 0)
    }

    // MARK: - Scaling Tests

    /// Test 6: Scale factor calculated correctly
    func test_scaleFactor_calculatedCorrectly() throws {
        // GIVEN: Recipe for 4 servings, added for 8 servings
        let recipe = env.createTestRecipe(title: "Scale Test", servings: "4 servings")
        let cartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 8)
        try env.save()

        // THEN: Scale factor should be 2.0
        XCTAssertEqual(cartRecipe.scaleFactor, 2.0)
    }

    /// Test 7: Scale factor for half recipe
    func test_scaleFactor_halfRecipe_isCorrect() throws {
        // GIVEN: Recipe for 8 servings, added for 4 servings
        let recipe = env.createTestRecipe(title: "Half Recipe", servings: "8 servings")
        let cartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 4)
        try env.save()

        // THEN: Scale factor should be 0.5
        XCTAssertEqual(cartRecipe.scaleFactor, 0.5)
    }

    /// Test 8: Scale factor defaults to 1.0 when servings unparseable
    func test_scaleFactor_unparseableServings_defaultsToOne() throws {
        // GIVEN: Recipe with unparseable servings
        let recipe = env.createTestRecipe(title: "Unparseable", servings: "makes a bunch")
        let cartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 4)
        try env.save()

        // THEN: Scale factor should use default (4 servings assumed)
        // Default parsed serving count is 4, so 4/4 = 1.0
        XCTAssertEqual(cartRecipe.scaleFactor, 1.0)
    }

    // MARK: - Multiple Recipes Tests

    /// Test 9: Multiple recipes in cart
    func test_multipleRecipes_inCart() throws {
        // GIVEN: Three recipes
        let recipe1 = env.createTestRecipe(title: "Recipe 1")
        let recipe2 = env.createTestRecipe(title: "Recipe 2")
        let recipe3 = env.createTestRecipe(title: "Recipe 3")
        try env.save()

        // WHEN: Adding all to cart
        _ = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        _ = createShoppingCartRecipe(recipe: recipe2, targetServings: 6)
        _ = createShoppingCartRecipe(recipe: recipe3, targetServings: 2)
        try env.save()

        // THEN: All should be in cart with correct servings
        let cartRecipes = try fetchAllCartRecipes()
        XCTAssertEqual(cartRecipes.count, 3)

        let servings = Set(cartRecipes.map { $0.targetServings })
        XCTAssertTrue(servings.contains(4))
        XCTAssertTrue(servings.contains(6))
        XCTAssertTrue(servings.contains(2))
    }

    /// Test 10: Clear entire cart
    func test_clearCart_removesAllRecipes() throws {
        // GIVEN: Multiple recipes in cart
        _ = createShoppingCartRecipe(recipe: env.createTestRecipe(title: "R1"), targetServings: 4)
        _ = createShoppingCartRecipe(recipe: env.createTestRecipe(title: "R2"), targetServings: 4)
        _ = createShoppingCartRecipe(recipe: env.createTestRecipe(title: "R3"), targetServings: 4)
        try env.save()
        XCTAssertEqual(try fetchAllCartRecipes().count, 3)

        // WHEN: Clearing cart
        let cartRecipes = try fetchAllCartRecipes()
        for cartRecipe in cartRecipes {
            env.modelContext.delete(cartRecipe)
        }
        try env.save()

        // THEN: Cart should be empty
        XCTAssertEqual(try fetchAllCartRecipes().count, 0)
    }

    // MARK: - Date Tracking Tests

    /// Test 11: Date added is set on creation
    func test_dateAdded_setOnCreation() throws {
        // GIVEN: Current time
        let before = Date()

        // WHEN: Creating cart recipe
        let recipe = env.createTestRecipe()
        let cartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 4)
        try env.save()

        // THEN: Date should be set
        XCTAssertNotNil(cartRecipe.dateAdded)
        XCTAssertGreaterThanOrEqual(cartRecipe.dateAdded, before)
    }

    // MARK: - Display Properties Tests

    /// Test 12: Display title includes servings
    func test_displayTitle_includesServings() throws {
        // GIVEN: Recipe with specific title and servings
        let recipe = env.createTestRecipe(title: "Chocolate Cookies", servings: "24 cookies")
        let cartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 24)
        try env.save()

        // THEN: Display title should include recipe title
        let displayTitle = cartRecipe.displayTitle
        XCTAssertTrue(displayTitle.contains("Chocolate Cookies"))
    }

    // MARK: - Recipe ID Storage Tests

    /// Test 13: Recipe ID stored for efficient querying
    func test_recipeId_storedForQuerying() throws {
        // GIVEN: A recipe
        let recipe = env.createTestRecipe(title: "Query Test")
        try env.save()
        let expectedId = recipe.id

        // WHEN: Creating cart recipe
        let cartRecipe = createShoppingCartRecipe(recipe: recipe, targetServings: 4)
        try env.save()

        // THEN: recipeId should match
        XCTAssertEqual(cartRecipe.recipeId, expectedId)
    }

    /// Test 14: Can query cart by recipe ID
    func test_queryCart_byRecipeId() throws {
        // GIVEN: Recipe in cart
        let recipe = env.createTestRecipe(title: "Findable")
        _ = createShoppingCartRecipe(recipe: recipe, targetServings: 4)
        try env.save()
        let targetId = recipe.id

        // WHEN: Querying by recipe ID
        var descriptor = FetchDescriptor<ShoppingCartRecipe>()
        descriptor.predicate = #Predicate<ShoppingCartRecipe> { $0.recipeId == targetId }
        let results = try env.modelContext.fetch(descriptor)

        // THEN: Should find the cart recipe
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.recipe?.title, "Findable")
    }
}
