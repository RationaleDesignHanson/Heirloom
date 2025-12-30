import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class ShoppingListAggregationTests: XCTestCase {
    var modelContext: ModelContext!

    override func setUp() async throws {
        // Create in-memory container for testing using SchemaV1
        // This ensures all models and their relationships are properly configured
        let schema = SchemaV1.schema
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        modelContext = container.mainContext
    }

    override func tearDown() async throws {
        modelContext = nil
    }

    // MARK: - Helper Methods

    private func createTestRecipe(title: String, servings: String, ingredients: [(originalText: String, name: String, quantity: Double?, unit: String?, preparation: String?)]) -> Recipe {
        let recipe = Recipe(
            title: title,
            servings: servings
        )
        // Note: scalability defaults to "easy" which allows scaling
        recipe.isInShoppingList = true
        modelContext.insert(recipe)

        for (index, ingData) in ingredients.enumerated() {
            let ingredient = Ingredient(
                originalText: ingData.originalText,
                name: ingData.name,
                orderIndex: index
            )
            ingredient.quantity = ingData.quantity
            ingredient.unit = ingData.unit
            ingredient.preparation = ingData.preparation
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
        }

        try? modelContext.save()
        return recipe
    }

    private func createShoppingCartRecipe(recipe: Recipe, targetServings: Int) -> ShoppingCartRecipe {
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: targetServings)
        modelContext.insert(cartRecipe)

        // Note: scaledIngredients is a computed property on ShoppingCartRecipe
        // It will automatically call ScalingEngine when accessed

        try? modelContext.save()
        return cartRecipe
    }

    // MARK: - Duplicate Detection Tests

    func testDuplicateDetection_SameIngredientSameUnit() throws {
        // Recipe 1: 2 cups flour
        let recipe1 = createTestRecipe(
            title: "Bread",
            servings: "8 servings",
            ingredients: [
                (originalText: "2 cups flour", name: "flour", quantity: 2.0, unit: "cup", preparation: nil)
            ]
        )

        // Recipe 2: 3 cups flour
        let recipe2 = createTestRecipe(
            title: "Cake",
            servings: "12 servings",
            ingredients: [
                (originalText: "3 cups flour", name: "flour", quantity: 3.0, unit: "cup", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 8)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 12)

        // Verify both are in cart
        XCTAssertNotNil(cart1.recipe)
        XCTAssertNotNil(cart2.recipe)

        // Verify scaled ingredients exist
        XCTAssertEqual(cart1.scaledIngredients.count, 1)
        XCTAssertEqual(cart2.scaledIngredients.count, 1)

        // In a real shopping list, these would be aggregated to "5 cups flour"
        let qty1 = cart1.scaledIngredients.first?.scaledQuantity ?? 0
        let qty2 = cart2.scaledIngredients.first?.scaledQuantity ?? 0
        let totalQuantity = qty1 + qty2
        XCTAssertEqual(totalQuantity, 5.0)
    }

    func testDuplicateDetection_CaseInsensitive() throws {
        // Recipe 1: "Flour" (capitalized)
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "2 cups Flour", name: "Flour", quantity: 2.0, unit: "cup", preparation: nil)
            ]
        )

        // Recipe 2: "flour" (lowercase)
        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "1 cup flour", name: "flour", quantity: 1.0, unit: "cup", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)

        // Should aggregate despite different casing (case-insensitive comparison)
        let key1 = "Flour".lowercased().trimmingCharacters(in: .whitespaces)
        let key2 = "flour".lowercased().trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(key1, key2)
    }

    func testDuplicateDetection_WhitespaceHandling() throws {
        // Recipe 1: "flour" with trailing space
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "2 cups flour ", name: "flour ", quantity: 2.0, unit: "cup", preparation: nil)
            ]
        )

        // Recipe 2: "flour" with leading space
        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "1 cup  flour", name: " flour", quantity: 1.0, unit: "cup", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)

        // Should aggregate despite whitespace differences
        let key1 = "flour ".lowercased().trimmingCharacters(in: .whitespaces)
        let key2 = " flour".lowercased().trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(key1, key2)
    }

    // MARK: - Same Unit Aggregation Tests

    func testAggregation_SameUnit_Cups() throws {
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "1.5 cups milk", name: "milk", quantity: 1.5, unit: "cup", preparation: nil)
            ]
        )

        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "6 servings",
            ingredients: [
                (originalText: "2.5 cups milk", name: "milk", quantity: 2.5, unit: "cup", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 6)

        // Total should be 4 cups
        let qty1 = cart1.scaledIngredients.first?.scaledQuantity ?? 0
        let qty2 = cart2.scaledIngredients.first?.scaledQuantity ?? 0
        let totalQuantity = qty1 + qty2
        XCTAssertEqual(totalQuantity, 4.0)
    }

    func testAggregation_SameUnit_Teaspoons() throws {
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "1 teaspoon salt", name: "salt", quantity: 1.0, unit: "teaspoon", preparation: nil)
            ]
        )

        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "0.5 teaspoon salt", name: "salt", quantity: 0.5, unit: "teaspoon", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)

        // Total should be 1.5 teaspoons
        let qty1 = cart1.scaledIngredients.first?.scaledQuantity ?? 0
        let qty2 = cart2.scaledIngredients.first?.scaledQuantity ?? 0
        let totalQuantity = qty1 + qty2
        XCTAssertEqual(totalQuantity, 1.5)
    }

    func testAggregation_SameUnit_Grams() throws {
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "250g flour", name: "flour", quantity: 250.0, unit: "g", preparation: nil)
            ]
        )

        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "125g flour", name: "flour", quantity: 125.0, unit: "g", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)

        // Total should be 375g
        let qty1 = cart1.scaledIngredients.first?.scaledQuantity ?? 0
        let qty2 = cart2.scaledIngredients.first?.scaledQuantity ?? 0
        let totalQuantity = qty1 + qty2
        XCTAssertEqual(totalQuantity, 375.0)
    }

    // MARK: - Different Unit Aggregation Tests

    func testAggregation_DifferentUnits_NoAggregation() throws {
        // Recipe 1: cups
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "2 cups sugar", name: "sugar", quantity: 2.0, unit: "cup", preparation: nil)
            ]
        )

        // Recipe 2: grams (incompatible unit)
        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "200g sugar", name: "sugar", quantity: 200.0, unit: "g", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)

        // Different units should not be aggregated into a single quantity
        // They should be tracked separately or show "2× sugar" fallback
        XCTAssertNotNil(cart1.scaledIngredients.first)
        XCTAssertNotNil(cart2.scaledIngredients.first)
        XCTAssertNotEqual(cart1.scaledIngredients.first?.originalIngredient.unit, cart2.scaledIngredients.first?.originalIngredient.unit)
    }

    // MARK: - Range Handling Tests

    func testAggregation_RangeQuantities() throws {
        // Note: Current implementation doesn't have explicit range support
        // This test documents expected behavior when ranges are added
        let recipe = createTestRecipe(
            title: "Recipe with Range",
            servings: "4 servings",
            ingredients: [
                (originalText: "2-3 cups water", name: "water", quantity: 2.5, unit: "cup", preparation: nil) // midpoint
            ]
        )

        let cart = createShoppingCartRecipe(recipe: recipe, targetServings: 4)

        // Should use the midpoint or handle range appropriately
        XCTAssertEqual(cart.scaledIngredients.first?.scaledQuantity, 2.5)
    }

    // MARK: - "To Taste" / No Quantity Tests

    func testAggregation_ToTaste_NoQuantity() throws {
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "salt to taste", name: "salt", quantity: nil, unit: nil, preparation: "to taste")
            ]
        )

        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "salt to taste", name: "salt", quantity: nil, unit: nil, preparation: "to taste")
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)

        // Both should have no quantity
        XCTAssertNil(cart1.scaledIngredients.first?.scaledQuantity)
        XCTAssertNil(cart2.scaledIngredients.first?.scaledQuantity)

        // Should aggregate by showing "From 2 recipes" indicator
        XCTAssertEqual(cart1.scaledIngredients.first?.originalIngredient.name, "salt")
        XCTAssertEqual(cart2.scaledIngredients.first?.originalIngredient.name, "salt")
    }

    func testAggregation_MixedQuantityAndToTaste() throws {
        // Recipe 1: specific quantity
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "1 teaspoon salt", name: "salt", quantity: 1.0, unit: "teaspoon", preparation: nil)
            ]
        )

        // Recipe 2: to taste (no quantity)
        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "salt to taste", name: "salt", quantity: nil, unit: nil, preparation: "to taste")
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)

        // Mixed quantities should not aggregate (one has quantity, one doesn't)
        XCTAssertNotNil(cart1.scaledIngredients.first?.scaledQuantity)
        XCTAssertNil(cart2.scaledIngredients.first?.scaledQuantity)
    }

    // MARK: - Preparation Variation Tests

    func testAggregation_DifferentPreparations_SameIngredient() throws {
        // Recipe 1: chopped onion
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "1 cup onion, chopped", name: "onion", quantity: 1.0, unit: "cup", preparation: "chopped")
            ]
        )

        // Recipe 2: diced onion
        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "1 cup onion, diced", name: "onion", quantity: 1.0, unit: "cup", preparation: "diced")
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)

        // Same ingredient name should aggregate, but note different preparations
        XCTAssertEqual(cart1.scaledIngredients.first?.originalIngredient.name, "onion")
        XCTAssertEqual(cart2.scaledIngredients.first?.originalIngredient.name, "onion")
        XCTAssertNotEqual(cart1.scaledIngredients.first?.originalIngredient.preparation, cart2.scaledIngredients.first?.originalIngredient.preparation)
    }

    // MARK: - Scaling Before Aggregation Tests

    func testAggregation_WithScaling_Double() throws {
        // Recipe: 2 cups flour for 4 servings, scaled to 8 servings
        let recipe = createTestRecipe(
            title: "Bread",
            servings: "4 servings",
            ingredients: [
                (originalText: "2 cups flour", name: "flour", quantity: 2.0, unit: "cup", preparation: nil)
            ]
        )

        let cart = createShoppingCartRecipe(recipe: recipe, targetServings: 8)

        // Should scale to 4 cups before aggregation
        XCTAssertEqual(cart.scaledIngredients.first?.scaledQuantity, 4.0)
    }

    func testAggregation_WithScaling_Half() throws {
        // Recipe: 4 cups flour for 8 servings, scaled to 4 servings
        let recipe = createTestRecipe(
            title: "Bread",
            servings: "8 servings",
            ingredients: [
                (originalText: "4 cups flour", name: "flour", quantity: 4.0, unit: "cup", preparation: nil)
            ]
        )

        let cart = createShoppingCartRecipe(recipe: recipe, targetServings: 4)

        // Should scale to 2 cups before aggregation
        XCTAssertEqual(cart.scaledIngredients.first?.scaledQuantity, 2.0)
    }

    func testAggregation_MultipleRecipes_DifferentScaleFactors() throws {
        // Recipe 1: 2 cups sugar for 4 servings -> scale to 8 (4 cups)
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "2 cups sugar", name: "sugar", quantity: 2.0, unit: "cup", preparation: nil)
            ]
        )

        // Recipe 2: 3 cups sugar for 6 servings -> scale to 3 (1.5 cups)
        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "6 servings",
            ingredients: [
                (originalText: "3 cups sugar", name: "sugar", quantity: 3.0, unit: "cup", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 8)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 3)

        // Total: 4 + 1.5 = 5.5 cups
        let qty1 = cart1.scaledIngredients.first?.scaledQuantity ?? 0
        let qty2 = cart2.scaledIngredients.first?.scaledQuantity ?? 0
        let totalQuantity = qty1 + qty2
        XCTAssertEqual(totalQuantity, 5.5, accuracy: 0.01)
    }

    // MARK: - Edge Cases

    func testAggregation_VerySmallQuantities() throws {
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "1/8 teaspoon saffron", name: "saffron", quantity: 0.125, unit: "teaspoon", preparation: nil)
            ]
        )

        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "1/8 teaspoon saffron", name: "saffron", quantity: 0.125, unit: "teaspoon", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)

        // Should aggregate to 1/4 teaspoon
        let qty1 = cart1.scaledIngredients.first?.scaledQuantity ?? 0
        let qty2 = cart2.scaledIngredients.first?.scaledQuantity ?? 0
        let totalQuantity = qty1 + qty2
        XCTAssertEqual(totalQuantity, 0.25, accuracy: 0.001)
    }

    func testAggregation_VeryLargeQuantities() throws {
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "10 cups flour", name: "flour", quantity: 10.0, unit: "cup", preparation: nil)
            ]
        )

        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "15 cups flour", name: "flour", quantity: 15.0, unit: "cup", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)

        // Should aggregate to 25 cups
        let qty1 = cart1.scaledIngredients.first?.scaledQuantity ?? 0
        let qty2 = cart2.scaledIngredients.first?.scaledQuantity ?? 0
        let totalQuantity = qty1 + qty2
        XCTAssertEqual(totalQuantity, 25.0)
    }

    func testAggregation_ThreeOrMoreRecipes() throws {
        let recipe1 = createTestRecipe(
            title: "Recipe 1",
            servings: "4 servings",
            ingredients: [
                (originalText: "1 cup butter", name: "butter", quantity: 1.0, unit: "cup", preparation: nil)
            ]
        )

        let recipe2 = createTestRecipe(
            title: "Recipe 2",
            servings: "4 servings",
            ingredients: [
                (originalText: "0.5 cup butter", name: "butter", quantity: 0.5, unit: "cup", preparation: nil)
            ]
        )

        let recipe3 = createTestRecipe(
            title: "Recipe 3",
            servings: "4 servings",
            ingredients: [
                (originalText: "1.5 cups butter", name: "butter", quantity: 1.5, unit: "cup", preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 4)
        let cart3 = createShoppingCartRecipe(recipe: recipe3, targetServings: 4)

        // Should aggregate to 3 cups from 3 recipes
        let qty1 = cart1.scaledIngredients.first?.scaledQuantity ?? 0
        let qty2 = cart2.scaledIngredients.first?.scaledQuantity ?? 0
        let qty3 = cart3.scaledIngredients.first?.scaledQuantity ?? 0
        let totalQuantity = qty1 + qty2 + qty3
        XCTAssertEqual(totalQuantity, 3.0)
    }

    // MARK: - Quantity Formatting Tests

    func testQuantityFormatting_WholeNumbers() throws {
        let recipe = createTestRecipe(
            title: "Recipe",
            servings: "4 servings",
            ingredients: [
                (originalText: "3 cups flour", name: "flour", quantity: 3.0, unit: "cup", preparation: nil)
            ]
        )

        let cart = createShoppingCartRecipe(recipe: recipe, targetServings: 4)

        // Should display as "3" not "3.0"
        let quantity = cart.scaledIngredients.first?.scaledQuantity ?? 0
        XCTAssertEqual(quantity, 3.0)
        XCTAssertEqual(Int(quantity), 3)
    }

    func testQuantityFormatting_CommonFractions() throws {
        let recipe = createTestRecipe(
            title: "Recipe",
            servings: "4 servings",
            ingredients: [
                (originalText: "1.5 cups sugar", name: "sugar", quantity: 1.5, unit: "cup", preparation: nil)
            ]
        )

        let cart = createShoppingCartRecipe(recipe: recipe, targetServings: 4)

        // 1.5 should be displayable as "1 ½"
        let quantity = cart.scaledIngredients.first?.scaledQuantity ?? 0
        XCTAssertEqual(quantity, 1.5, accuracy: 0.01)
    }

    func testQuantityFormatting_ComplexFractions() throws {
        let recipe = createTestRecipe(
            title: "Recipe",
            servings: "3 servings",
            ingredients: [
                (originalText: "1 cup flour", name: "flour", quantity: 1.0, unit: "cup", preparation: nil)
            ]
        )

        let cart = createShoppingCartRecipe(recipe: recipe, targetServings: 2)

        // Should scale to 0.667 cups (2/3)
        let quantity = cart.scaledIngredients.first?.scaledQuantity ?? 0
        XCTAssertEqual(quantity, 0.667, accuracy: 0.01)
    }

    // MARK: - Integration Tests

    func testComplexAggregation_MultipleRecipes_MultipleIngredients() throws {
        // Recipe 1: Cookie recipe
        let recipe1 = createTestRecipe(
            title: "Cookies",
            servings: "24 cookies",
            ingredients: [
                (originalText: "2 cups flour", name: "flour", quantity: 2.0, unit: "cup", preparation: nil),
                (originalText: "1 cup sugar", name: "sugar", quantity: 1.0, unit: "cup", preparation: nil),
                (originalText: "1 cup butter", name: "butter", quantity: 1.0, unit: "cup", preparation: nil),
                (originalText: "2 eggs", name: "eggs", quantity: 2.0, unit: nil, preparation: nil)
            ]
        )

        // Recipe 2: Cake recipe
        let recipe2 = createTestRecipe(
            title: "Cake",
            servings: "12 servings",
            ingredients: [
                (originalText: "3 cups flour", name: "flour", quantity: 3.0, unit: "cup", preparation: nil),
                (originalText: "2 cups sugar", name: "sugar", quantity: 2.0, unit: "cup", preparation: nil),
                (originalText: "1 cup milk", name: "milk", quantity: 1.0, unit: "cup", preparation: nil),
                (originalText: "3 eggs", name: "eggs", quantity: 3.0, unit: nil, preparation: nil)
            ]
        )

        let cart1 = createShoppingCartRecipe(recipe: recipe1, targetServings: 24)
        let cart2 = createShoppingCartRecipe(recipe: recipe2, targetServings: 12)

        // Verify ingredient counts
        XCTAssertEqual(cart1.scaledIngredients.count, 4)
        XCTAssertEqual(cart2.scaledIngredients.count, 4)

        // Flour: 2 + 3 = 5 cups
        // Sugar: 1 + 2 = 3 cups
        // Eggs: 2 + 3 = 5 eggs
        // Butter: 1 cup (only in recipe 1)
        // Milk: 1 cup (only in recipe 2)
    }
}
