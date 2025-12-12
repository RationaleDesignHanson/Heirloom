import XCTest
@testable import Heirloom

final class ScalingEngineTests: XCTestCase {

    var engine: ScalingEngine!

    override func setUp() {
        super.setUp()
        engine = ScalingEngine.shared
    }

    // MARK: - Basic Scaling Tests

    func test_scaleRecipe_doubles_ingredients() {
        let recipe = RecipeBuilder()
            .withTitle("Basic Recipe")
            .withServings("4 servings")
            .withIngredients(["1 cup flour", "2 eggs"])
            .withCategory(.cookies)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.targetServings, 8)
        XCTAssertEqual(scaled?.scaleFactor, 2.0)
        XCTAssertEqual(scaled?.scaledIngredients.count, 2)

        // Flour should be doubled
        let flourIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("flour") }
        XCTAssertEqual(flourIngredient?.scaledQuantity, 2.0)

        // Eggs should be doubled
        let eggsIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("eggs") }
        XCTAssertEqual(eggsIngredient?.scaledQuantity, 4.0)
    }

    func test_scaleRecipe_halvesIngredients() {
        let recipe = RecipeBuilder()
            .withTitle("Basic Recipe")
            .withServings("8 servings")
            .withIngredients(["2 cups flour", "4 eggs"])
            .withCategory(.cookies)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 4)

        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaleFactor, 0.5)

        // Flour should be halved
        let flourIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("flour") }
        XCTAssertEqual(flourIngredient?.scaledQuantity, 1.0)

        // Eggs should be halved
        let eggsIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("eggs") }
        XCTAssertEqual(eggsIngredient?.scaledQuantity, 2.0)
    }

    func test_scaleRecipe_triples_ingredients() {
        let recipe = RecipeBuilder()
            .withTitle("Triple Batch")
            .withServings("4 servings")
            .withIngredients(["1 cup sugar"])
            .withCategory(.cookies)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 12)

        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaleFactor, 3.0)

        let sugarIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("sugar") }
        XCTAssertEqual(sugarIngredient?.scaledQuantity, 3.0)
    }

    // MARK: - Non-Linear Scaling Tests

    func test_spiceScaling_reducesWhenScalingUp() {
        let recipe = RecipeBuilder()
            .withTitle("Spiced Recipe")
            .withServings("4 servings")
            .withIngredients(["1 tsp cinnamon"])
            .withCategory(.cookies)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        XCTAssertNotNil(scaled)

        let spiceIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("cinnamon") }

        // Spices scale at 0.66x when doubling (not full 2x)
        // 1 * 2 * 0.66 = 1.32 tsp
        XCTAssertNotNil(spiceIngredient)
        XCTAssertTrue(spiceIngredient!.wasAdjusted)
        XCTAssertEqual(spiceIngredient?.adjustmentReason, "Spices")
        XCTAssertLessThan(spiceIngredient!.scaledQuantity!, 2.0) // Less than full double
    }

    func test_leaveningScaling_reducesWhenScalingUp() {
        let recipe = RecipeBuilder()
            .withTitle("Baked Goods")
            .withServings("4 servings")
            .withIngredients(["2 tsp baking powder"])
            .withCategory(.cookies)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        XCTAssertNotNil(scaled)

        let leaveningIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("baking powder") }

        // Leavening scales at 0.75x when doubling
        // 2 * 2 * 0.75 = 3 tsp
        XCTAssertNotNil(leaveningIngredient)
        XCTAssertTrue(leaveningIngredient!.wasAdjusted)
        XCTAssertEqual(leaveningIngredient?.adjustmentReason, "Leavening")
        XCTAssertLessThan(leaveningIngredient!.scaledQuantity!, 4.0) // Less than full double
    }

    func test_liquidScaling_reducesSlightlyWhenScalingUp() {
        let recipe = RecipeBuilder()
            .withTitle("Soup")
            .withServings("4 servings")
            .withIngredients(["2 cups water"])
            .withCategory(.soupStew)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        XCTAssertNotNil(scaled)

        let liquidIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("water") }

        // Liquids scale at 0.9x when doubling (account for evaporation)
        // 2 * 2 * 0.9 = 3.6 cups
        XCTAssertNotNil(liquidIngredient)
        XCTAssertTrue(liquidIngredient!.wasAdjusted)
        XCTAssertEqual(liquidIngredient?.adjustmentReason, "Liquids")
        XCTAssertLessThan(liquidIngredient!.scaledQuantity!, 4.0)
    }

    func test_ingredientWithoutQuantity_handlesGracefully() {
        let recipe = RecipeBuilder()
            .withTitle("Recipe with taste items")
            .withServings("4 servings")
            .withIngredients(["Salt to taste"])
            .withCategory(.soupStew)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        XCTAssertNotNil(scaled)

        let saltIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("Salt") }

        XCTAssertNotNil(saltIngredient)
        XCTAssertNil(saltIngredient?.scaledQuantity)
        XCTAssertEqual(saltIngredient?.notes, "Adjust to taste")
    }

    // MARK: - Locked Recipe Tests

    func test_lockedRecipe_returnsNil() {
        let recipe = RecipeBuilder()
            .withTitle("Croissants")
            .withServings("12 croissants")
            .withIngredients(["500g flour", "250g butter"])
            .withCategory(.laminated)
            .withScalability(.locked)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 24)

        XCTAssertNil(scaled)
    }

    // MARK: - Serving Range Tests

    func test_scalingOutsideAllowedRange_returnsNil() {
        let recipe = RecipeBuilder()
            .withTitle("Limited Recipe")
            .withServings("4 servings")
            .withIngredients(["1 cup flour"])
            .withCategory(.cookies)
            .withServingRange(minimum: 2, maximum: 8)
            .build()

        // Try to scale above maximum
        let scaledAbove = engine.scaleRecipe(recipe, toServings: 16)
        XCTAssertNil(scaledAbove)

        // Try to scale below minimum
        let scaledBelow = engine.scaleRecipe(recipe, toServings: 1)
        XCTAssertNil(scaledBelow)
    }

    func test_scalingWithinAllowedRange_succeeds() {
        let recipe = RecipeBuilder()
            .withTitle("Limited Recipe")
            .withServings("4 servings")
            .withIngredients(["1 cup flour"])
            .withCategory(.cookies)
            .withServingRange(minimum: 2, maximum: 8)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 6)

        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.targetServings, 6)
    }

    // MARK: - Warning Tests

    func test_extremeScalingDown_generatesWarning() {
        let recipe = RecipeBuilder()
            .withTitle("Recipe")
            .withServings("8 servings")
            .withIngredients(["2 cups flour"])
            .withCategory(.cookies)
            .build()

        // Scale to 25% (0.25x factor)
        let scaled = engine.scaleRecipe(recipe, toServings: 2)

        XCTAssertNotNil(scaled)

        // Should have scaling floor warning (< 0.5x)
        let hasFloorWarning = scaled?.warnings.contains { warning in
            warning.type == .scalingFloor
        }
        XCTAssertTrue(hasFloorWarning ?? false)
    }

    func test_extremeScalingUp_generatesWarning() {
        let recipe = RecipeBuilder()
            .withTitle("Recipe")
            .withServings("4 servings")
            .withIngredients(["1 cup flour"])
            .withCategory(.cookies)
            .build()

        // Scale to 4x (scaleFactor = 4)
        let scaled = engine.scaleRecipe(recipe, toServings: 16)

        XCTAssertNotNil(scaled)

        // Should have scaling ceiling warning (> 3x)
        let hasCeilingWarning = scaled?.warnings.contains { warning in
            warning.type == .scalingCeiling
        }
        XCTAssertTrue(hasCeilingWarning ?? false)
    }

    func test_minimumServings_generatesWarning() {
        let recipe = RecipeBuilder()
            .withTitle("Layer Cake")
            .withServings("12 servings")
            .withIngredients(["2 cups flour"])
            .withCategory(.layerCake)
            .build()

        // Scale to minimum for layer cake (6 servings)
        let scaled = engine.scaleRecipe(recipe, toServings: 6)

        XCTAssertNotNil(scaled)

        // Should have category limit warning
        let hasCategoryWarning = scaled?.warnings.contains { warning in
            warning.type == .categoryLimit
        }
        XCTAssertTrue(hasCategoryWarning ?? false)
    }

    // MARK: - Equipment Suggestion Tests

    func test_largeBatch_generatesEquipmentSuggestion() {
        let recipe = RecipeBuilder()
            .withTitle("Cake")
            .withServings("8 servings")
            .withIngredients(["2 cups flour"])
            .withCategory(.layerCake)
            .build()

        // Scale up significantly
        let scaled = engine.scaleRecipe(recipe, toServings: 16)

        XCTAssertNotNil(scaled)
        XCTAssertNotNil(scaled?.equipmentSuggestions)
        XCTAssertFalse(scaled?.equipmentSuggestions?.isEmpty ?? true)
    }

    // MARK: - Cooking Time Adjustment Tests

    func test_bakingTimeAdjustment_scalingDown() {
        let recipe = RecipeBuilder()
            .withTitle("Cookies")
            .withServings("24 cookies")
            .withIngredients(["2 cups flour"])
            .withCookTime("12 min")
            .withCategory(.cookies)
            .build()

        // Scale down significantly
        let scaled = engine.scaleRecipe(recipe, toServings: 6)

        XCTAssertNotNil(scaled)
        // Cookies get time adjustment when scaled down
        XCTAssertNotNil(scaled?.adjustedCookTime)
        XCTAssertTrue(scaled?.adjustedCookTime?.contains("reduce") ?? false)
    }

    func test_bakingTimeAdjustment_scalingUp() {
        let recipe = RecipeBuilder()
            .withTitle("Muffins")
            .withServings("6 muffins")
            .withIngredients(["1 cup flour"])
            .withCookTime("18 min")
            .withCategory(.muffins)
            .build()

        // Scale up significantly
        let scaled = engine.scaleRecipe(recipe, toServings: 18)

        XCTAssertNotNil(scaled)
        // Muffins get time adjustment when scaled up
        XCTAssertNotNil(scaled?.adjustedCookTime)
        XCTAssertTrue(scaled?.adjustedCookTime?.contains("add") ?? false)
    }

    // MARK: - Rounding Tests

    func test_rounding_teaspoon() {
        let recipe = RecipeBuilder()
            .withTitle("Recipe")
            .withServings("3 servings")
            .withIngredients(["1 tsp salt"])
            .withCategory(.soupStew)
            .build()

        // Scale to get a fraction
        let scaled = engine.scaleRecipe(recipe, toServings: 2)

        XCTAssertNotNil(scaled)

        let saltIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("salt") }

        // Should round to nearest 1/8 tsp
        // 1 * (2/3) = 0.666... → should round to 0.625 (5/8)
        XCTAssertNotNil(saltIngredient?.scaledQuantity)
        let rounded = saltIngredient!.scaledQuantity!
        // Check it's a multiple of 1/8
        XCTAssertEqual((rounded * 8).truncatingRemainder(dividingBy: 1.0), 0.0, accuracy: 0.01)
    }

    func test_rounding_cup() {
        let recipe = RecipeBuilder()
            .withTitle("Recipe")
            .withServings("3 servings")
            .withIngredients(["2 cups flour"])
            .withCategory(.cookies)
            .build()

        // Scale to get a fraction
        let scaled = engine.scaleRecipe(recipe, toServings: 2)

        XCTAssertNotNil(scaled)

        let flourIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("flour") }

        // Should round to nearest 1/8 cup
        // 2 * (2/3) = 1.333... → should round to 1.375 (1 3/8)
        XCTAssertNotNil(flourIngredient?.scaledQuantity)
        let rounded = flourIngredient!.scaledQuantity!
        // Check it's a multiple of 1/8
        XCTAssertEqual((rounded * 8).truncatingRemainder(dividingBy: 1.0), 0.0, accuracy: 0.01)
    }

    // MARK: - Category-Specific Tests

    func test_cookiesCategory_usesCorrectPresets() {
        let recipe = RecipeBuilder()
            .withTitle("Chocolate Chip Cookies")
            .withServings("24 cookies")
            .withIngredients(["1 cup flour", "1 tsp vanilla"])
            .withCategory(.cookies)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 48)

        XCTAssertNotNil(scaled)
        XCTAssertEqual(scaled?.scaleFactor, 2.0)

        // Vanilla (extract/spice) should be scaled non-linearly
        let vanillaIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("vanilla") }
        XCTAssertTrue(vanillaIngredient?.wasAdjusted ?? false)
    }

    func test_soupCategory_scalesLinearly() {
        let recipe = RecipeBuilder()
            .withTitle("Chicken Soup")
            .withServings("4 servings")
            .withIngredients(["4 cups chicken broth", "1 cup vegetables"])
            .withCategory(.soupStew)
            .build()

        let scaled = engine.scaleRecipe(recipe, toServings: 8)

        XCTAssertNotNil(scaled)

        // Broth is liquid, should have adjustment
        let brothIngredient = scaled?.scaledIngredients.first { $0.originalIngredient.name.contains("broth") }
        XCTAssertTrue(brothIngredient?.wasAdjusted ?? false)
        XCTAssertEqual(brothIngredient?.adjustmentReason, "Liquids")
    }
}
