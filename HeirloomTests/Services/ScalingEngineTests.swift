import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class ScalingEngineTests: XCTestCase {

    var engine: ScalingEngine!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        engine = ScalingEngine()

        // Set up in-memory model context for testing using SchemaV1
        // This ensures all models and their relationships are properly configured
        let schema = SchemaV1.schema
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(container)
    }

    override func tearDown() async throws {
        engine = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Basic Scaling Tests

    func testLinearScaling_Double() throws {
        // Given: Recipe for 4 servings with 2 cups flour
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [("2", "cup", "flour")]
        )

        // When: Scale to 8 servings (2x)
        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        // Then
        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaleFactor, 2.0)
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity, 4.0)
    }

    func testLinearScaling_Half() throws {
        // Given: Recipe for 12 servings with 6 cups sugar
        let recipe = createTestRecipe(
            servings: "12 servings",
            ingredients: [("6", "cup", "sugar")]
        )

        // When: Scale to 6 servings (0.5x)
        let scaled = engine.scaleRecipe(recipe, toServings: 6)

        // Then
        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaleFactor, 0.5)
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity, 3.0)
    }

    func testLinearScaling_NoChange() throws {
        // Given: Recipe for 6 servings
        let recipe = createTestRecipe(
            servings: "6 servings",
            ingredients: [("2", "cup", "flour")]
        )

        // When: Scale to 6 servings (1x - no change)
        let scaled = engine.scaleRecipe(recipe, toServings: 6)

        // Then
        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaleFactor, 1.0)
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity, 2.0)
    }

    // MARK: - Non-Linear Adjustment Tests

    func testSpiceScaling_ScaledDown() throws {
        // Given: Recipe with cinnamon for 8 servings
        let recipe = createTestRecipe(
            servings: "8 servings",
            ingredients: [("2", "teaspoon", "cinnamon")]
        )

        // When: Scale up to 16 servings (2x)
        let scaled = engine.scaleRecipe(recipe, toServings: 16)

        // Then: Spices scale at 0.66x when scaling up
        XCTAssertNotNil(scaled)
        let expectedQty = 2.0 * 2.0 * 0.66 // base * scaleFactor * spice multiplier
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity ?? 0, expectedQty, accuracy: 0.01)
        XCTAssertTrue(scaled?.scaledIngredients.first?.wasAdjusted ?? false)
        XCTAssertEqual(scaled?.scaledIngredients.first?.adjustmentReason, "Spices")
    }

    func testLeaveningScaling() throws {
        // Given: Recipe with baking powder
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [("2", "teaspoon", "baking powder")]
        )

        // When: Scale up to 12 servings (3x)
        let scaled = engine.scaleRecipe(recipe, toServings: 12)

        // Then: Leavening scales at 0.75x when scaling up
        XCTAssertNotNil(scaled)
        let expectedQty = 2.0 * 3.0 * 0.75 // base * scaleFactor * leavening multiplier
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity ?? 0, expectedQty, accuracy: 0.01)
        XCTAssertTrue(scaled?.scaledIngredients.first?.wasAdjusted ?? false)
    }

    func testLiquidScaling() throws {
        // Given: Recipe with water
        let recipe = createTestRecipe(
            servings: "2 servings",
            ingredients: [("1", "cup", "water")]
        )

        // When: Scale up to 6 servings (3x)
        let scaled = engine.scaleRecipe(recipe, toServings: 6)

        // Then: Liquids scale at 0.9x when scaling up (evaporation)
        // Note: Result is rounded to nearest 1/8 cup (2.7 → 2.75)
        XCTAssertNotNil(scaled)
        let expectedQty = 2.75 // 1.0 * 3.0 * 0.9 = 2.7, rounded to 1/8 cup = 2.75
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity ?? 0, expectedQty, accuracy: 0.01)
        XCTAssertTrue(scaled?.scaledIngredients.first?.wasAdjusted ?? false)
    }

    func testSeasoningLinear() throws {
        // Given: Recipe with salt
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [("1", "teaspoon", "salt")]
        )

        // When: Scale to 8 servings (2x)
        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        // Then: Seasoning scales linearly
        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity, 2.0)
        XCTAssertFalse(scaled?.scaledIngredients.first?.wasAdjusted ?? true)
    }

    // MARK: - Rounding Tests

    func testRounding_Teaspoons() throws {
        // Given: Recipe that will produce 1.6 tsp after scaling
        let recipe = createTestRecipe(
            servings: "5 servings",
            ingredients: [("2", "teaspoon", "vanilla extract")]
        )

        // When: Scale to 4 servings (0.8x -> 1.6 tsp)
        let scaled = engine.scaleRecipe(recipe, toServings: 4)

        // Then: Should round to 2 decimal places (1.6)
        XCTAssertNotNil(scaled)
        let rounded = scaled?.scaledIngredients.first?.scaledQuantity ?? 0
        XCTAssertEqual(rounded, 1.6) // 2 * 0.8 = 1.6
    }

    func testRounding_Tablespoons() throws {
        // Given: Recipe
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [("3", "tablespoon", "butter")]
        )

        // When: Scale to 3 servings (0.75x -> 2.25 tbsp)
        let scaled = engine.scaleRecipe(recipe, toServings: 3)

        // Then: Should round to nearest 1/4 tbsp (2.25)
        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity, 2.25)
    }

    func testRounding_Cups() throws {
        // Given: Recipe
        let recipe = createTestRecipe(
            servings: "8 servings",
            ingredients: [("4", "cup", "flour")]
        )

        // When: Scale to 5 servings (0.625x -> 2.5 cups)
        let scaled = engine.scaleRecipe(recipe, toServings: 5)

        // Then: Should round to nearest 1/8 cup (2.5)
        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity, 2.5)
    }

    func testRounding_Grams() throws {
        // Given: Recipe with grams
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [("247", "gram", "flour")]
        )

        // When: Scale to 3 servings (0.75x -> 185.25g)
        let scaled = engine.scaleRecipe(recipe, toServings: 3)

        // Then: Should round to nearest 5g (185)
        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity, 185.0)
    }

    func testRounding_Ounces() throws {
        // Given: Recipe with ounces
        let recipe = createTestRecipe(
            servings: "6 servings",
            ingredients: [("12", "oz.", "cheese")]
        )

        // When: Scale to 4 servings (0.667x -> 8oz)
        let scaled = engine.scaleRecipe(recipe, toServings: 4)

        // Then: Should round to nearest 0.5oz (8.0)
        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity ?? 0, 8.0, accuracy: 0.1)
    }

    // MARK: - Range Scaling Tests

    func testRangeScaling() throws {
        // Given: Recipe with quantity range
        let ingredient = createIngredientWithRange(
            quantityMin: 2.0,
            quantityMax: 3.0,
            unit: "cup",
            name: "flour"
        )
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [],
            customIngredients: [ingredient]
        )

        // When: Scale to 8 servings (2x)
        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        // Then: Both min and max should scale
        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantity, 4.0)
        XCTAssertEqual(scaled?.scaledIngredients.first?.scaledQuantityMax, 6.0)
    }

    // MARK: - "To Taste" Ingredients

    func testToTasteIngredient() throws {
        // Given: Recipe with "salt to taste" (no quantity)
        let ingredient = createIngredient(quantity: nil, unit: nil, name: "salt to taste")
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [],
            customIngredients: [ingredient]
        )

        // When: Scale to 8 servings
        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        // Then: Should have note to adjust to taste
        XCTAssertNotNil(scaled)
        XCTAssertNil(scaled?.scaledIngredients.first?.scaledQuantity)
        XCTAssertEqual(scaled?.scaledIngredients.first?.notes, "Adjust to taste")
    }

    // MARK: - Scaling Validation Tests

    func testScalingDisallowed() throws {
        // Given: Recipe with scaling disabled
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [("2", "cup", "flour")],
            scalingAllowed: false
        )

        // When: Attempt to scale
        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        // Then: Should return nil
        XCTAssertNil(scaled)
    }

    func testScalingOutOfRange_TooLow() throws {
        // Given: Recipe with minimum servings = 4
        let recipe = createTestRecipe(
            servings: "8 servings",
            ingredients: [("2", "cup", "flour")],
            minimumServings: 4,
            maximumServings: 16
        )

        // When: Attempt to scale to 2 servings (below minimum)
        let scaled = engine.scaleRecipe(recipe, toServings: 2)

        // Then: Should return nil
        XCTAssertNil(scaled)
    }

    func testScalingOutOfRange_TooHigh() throws {
        // Given: Recipe with maximum servings = 16
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [("2", "cup", "flour")],
            minimumServings: 2,
            maximumServings: 16
        )

        // When: Attempt to scale to 24 servings (above maximum)
        let scaled = engine.scaleRecipe(recipe, toServings: 24)

        // Then: Should return nil
        XCTAssertNil(scaled)
    }

    // MARK: - Warning Tests

    func testWarning_SmallScale() throws {
        // Given: Recipe
        let recipe = createTestRecipe(
            servings: "8 servings",
            ingredients: [("2", "cup", "flour")]
        )

        // When: Scale to 2 servings (0.25x, below 0.5 threshold)
        let scaled = engine.scaleRecipe(recipe, toServings: 2)

        // Then: Should have scaling floor warning
        XCTAssertNotNil(scaled)
        XCTAssertTrue(scaled?.warnings.contains { $0.type == .scalingFloor } ?? false)
    }

    func testWarning_LargeScale() throws {
        // Given: Recipe
        let recipe = createTestRecipe(
            servings: "2 servings",
            ingredients: [("1", "cup", "flour")]
        )

        // When: Scale to 8 servings (4x, above 3.0 threshold)
        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        // Then: Should have scaling ceiling warning
        XCTAssertNotNil(scaled)
        XCTAssertTrue(scaled?.warnings.contains { $0.type == .scalingCeiling } ?? false)
    }

    func testWarning_CategoryMinimum() throws {
        // Given: Cookie recipe (minimum 12 cookies)
        let recipe = createTestRecipe(
            servings: "24 cookies",
            ingredients: [("2", "cup", "flour")],
            minimumServings: 12,
            category: .cookies
        )

        // When: Scale to 12 cookies (minimum threshold)
        let scaled = engine.scaleRecipe(recipe, toServings: 12)

        // Then: Should have category limit warning
        XCTAssertNotNil(scaled)
        XCTAssertTrue(scaled?.warnings.contains { $0.type == .categoryLimit } ?? false)
    }

    // MARK: - Equipment Suggestion Tests

    func testEquipmentSuggestion_SmallScale_Cake() throws {
        // Given: Layer cake recipe
        let recipe = createTestRecipe(
            servings: "12 servings",
            ingredients: [("2", "cup", "flour")],
            category: .layerCake
        )

        // When: Scale to 6 servings (0.5x)
        let scaled = engine.scaleRecipe(recipe, toServings: 6)

        // Then: Should suggest smaller pan
        XCTAssertNotNil(scaled?.equipmentSuggestions)
        XCTAssertTrue(scaled?.equipmentSuggestions?.contains { $0.contains("smaller pan") } ?? false)
    }

    func testEquipmentSuggestion_LargeScale_Cake() throws {
        // Given: Pie recipe
        let recipe = createTestRecipe(
            servings: "8 servings",
            ingredients: [("2", "cup", "flour")],
            category: .pie
        )

        // When: Scale to 16 servings (2x)
        let scaled = engine.scaleRecipe(recipe, toServings: 16)

        // Then: Should suggest larger pan or multiple pans
        XCTAssertNotNil(scaled?.equipmentSuggestions)
        XCTAssertTrue(scaled?.equipmentSuggestions?.contains { $0.contains("larger pan") } ?? false)
    }

    func testEquipmentSuggestion_VeryLargeScale() throws {
        // Given: Any recipe
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [("2", "cup", "flour")]
        )

        // When: Scale to 12 servings (3x, above 2.0 threshold)
        let scaled = engine.scaleRecipe(recipe, toServings: 12)

        // Then: Should suggest larger mixing bowl
        XCTAssertNotNil(scaled?.equipmentSuggestions)
        XCTAssertTrue(scaled?.equipmentSuggestions?.contains { $0.contains("mixing bowl") } ?? false)
    }

    // MARK: - Cooking Time Adjustment Tests

    func testCookingTime_Cookies_ScaleDown() throws {
        // Given: Cookie recipe with cook time
        let recipe = createTestRecipe(
            servings: "24 cookies",
            ingredients: [("2", "cup", "flour")],
            category: .cookies,
            cookTime: "12 minutes"
        )

        // When: Scale down (0.5x)
        let scaled = engine.scaleRecipe(recipe, toServings: 12)

        // Then: Should suggest reducing time
        XCTAssertNotNil(scaled?.adjustedCookTime)
        XCTAssertTrue(scaled?.adjustedCookTime?.contains("reduce") ?? false)
    }

    func testCookingTime_Muffins_ScaleUp() throws {
        // Given: Muffin recipe with cook time (10 servings base, so 16/10 = 1.6x triggers >= 1.5)
        let recipe = createTestRecipe(
            servings: "10 muffins",
            ingredients: [("2", "cup", "flour")],
            category: .muffins,
            cookTime: "20 minutes"
        )

        // When: Scale up to default max (16/10 = 1.6x, triggers >= 1.5 threshold)
        let scaled = engine.scaleRecipe(recipe, toServings: 16)

        // Then: Should suggest adding time
        XCTAssertNotNil(scaled?.adjustedCookTime)
        XCTAssertTrue(scaled?.adjustedCookTime?.contains("add") ?? false)
    }

    func testCookingTime_NoAdjustment() throws {
        // Given: Recipe with moderate scaling
        let recipe = createTestRecipe(
            servings: "12 cookies",
            ingredients: [("2", "cup", "flour")],
            category: .cookies,
            cookTime: "12 minutes"
        )

        // When: Scale moderately (1.25x)
        let scaled = engine.scaleRecipe(recipe, toServings: 15)

        // Then: No time adjustment needed
        XCTAssertNil(scaled?.adjustedCookTime)
    }

    // MARK: - Complex Scenarios

    func testComplexRecipe_MultipleIngredients() throws {
        // Given: Recipe with multiple ingredient types
        let recipe = createTestRecipe(
            servings: "4 servings",
            ingredients: [
                ("2", "cup", "flour"),
                ("1", "teaspoon", "cinnamon"),
                ("2", "teaspoon", "baking powder"),
                ("1", "cup", "milk"),
                ("2", "tablespoon", "sugar")
            ]
        )

        // When: Scale to 8 servings (2x)
        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        // Then: All ingredients should scale appropriately
        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaledIngredients.count, 5)

        // Flour (bulk) - linear scaling
        XCTAssertEqual(scaled?.scaledIngredients[0].scaledQuantity, 4.0)

        // Cinnamon (spice) - 0.66x multiplier
        XCTAssertEqual(scaled?.scaledIngredients[1].scaledQuantity ?? 0, 1.0 * 2.0 * 0.66, accuracy: 0.01)

        // Baking powder (leavening) - 0.75x multiplier
        XCTAssertEqual(scaled?.scaledIngredients[2].scaledQuantity ?? 0, 2.0 * 2.0 * 0.75, accuracy: 0.01)

        // Milk (liquid) - 0.9x multiplier, rounded to 1/8 cup
        XCTAssertEqual(scaled?.scaledIngredients[3].scaledQuantity ?? 0, 1.75, accuracy: 0.01) // 1.8 → 1.75

        // Sugar (bulk) - linear scaling
        XCTAssertEqual(scaled?.scaledIngredients[4].scaledQuantity, 4.0)
    }

    // MARK: - Helper Methods

    private func createTestRecipe(
        servings: String,
        ingredients: [(quantity: String, unit: String, name: String)],
        customIngredients: [Ingredient] = [],
        scalingAllowed: Bool = true,
        minimumServings: Int = 1,
        maximumServings: Int? = nil,
        category: RecipeCategory? = nil,
        cookTime: String? = nil
    ) -> Recipe {
        let recipe = Recipe()
        recipe.title = "Test Recipe"
        recipe.servings = servings
        recipe.scalabilityRating = scalingAllowed ? "easy" : "locked"
        recipe.minimumServings = minimumServings
        recipe.maximumServings = maximumServings
        recipe.recipeCategory = category?.rawValue
        recipe.cookTime = cookTime

        modelContext.insert(recipe)

        // Add ingredients
        for (index, tuple) in ingredients.enumerated() {
            let ingredient = createIngredient(
                quantity: Double(tuple.quantity),
                unit: tuple.unit,
                name: tuple.name
            )
            ingredient.orderIndex = index
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
        }

        // Add custom ingredients
        for (index, ingredient) in customIngredients.enumerated() {
            ingredient.orderIndex = ingredients.count + index
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
        }

        return recipe
    }

    private func createIngredient(
        quantity: Double?,
        unit: String?,
        name: String
    ) -> Ingredient {
        let ingredient = Ingredient()
        ingredient.quantity = quantity
        ingredient.quantityMax = nil
        ingredient.unit = unit
        ingredient.name = name
        return ingredient
    }

    private func createIngredientWithRange(
        quantityMin: Double,
        quantityMax: Double,
        unit: String,
        name: String
    ) -> Ingredient {
        let ingredient = Ingredient()
        ingredient.quantity = quantityMin
        ingredient.quantityMax = quantityMax
        ingredient.unit = unit
        ingredient.name = name
        return ingredient
    }
}
