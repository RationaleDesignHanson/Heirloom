//
//  IngredientFormatterTests.swift
//  HeirloomTestsV2
//
//  Unit tests for IngredientFormatter: quantity formatting, scaling,
//  embedded quantity scaling, unit singularization, and full format() output.
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class IngredientFormatterTests: XCTestCase {

    var env: TestEnvironment!
    var formatter: IngredientFormatter!

    override func setUp() async throws {
        env = try await TestEnvironment.create()
        formatter = IngredientFormatter(unitsConfig: UnitsConfiguration())
    }

    override func tearDown() async throws {
        env?.tearDown()
        env = nil
        formatter = nil
    }

    // MARK: - formatQuantity (Imperial)

    func test_formatQuantity_wholeNumber_returnsInteger() {
        // GIVEN: A whole number value
        // WHEN: Formatting as imperial
        let result = formatter.formatQuantity(2.0, unit: "cup")

        // THEN: Returns "2" without decimal
        XCTAssertEqual(result, "2")
    }

    func test_formatQuantity_half_returnsFraction() {
        // GIVEN: 0.5
        let result = formatter.formatQuantity(0.5, unit: "cup")

        // THEN: Returns unicode half
        XCTAssertEqual(result, "\u{00BD}")
    }

    func test_formatQuantity_quarter_returnsFraction() {
        let result = formatter.formatQuantity(0.25, unit: "cup")
        XCTAssertEqual(result, "\u{00BC}")
    }

    func test_formatQuantity_threeQuarters_returnsFraction() {
        let result = formatter.formatQuantity(0.75, unit: "cup")
        XCTAssertEqual(result, "\u{00BE}")
    }

    func test_formatQuantity_oneThird_returnsFraction() {
        let result = formatter.formatQuantity(1.0/3.0, unit: "cup")
        XCTAssertEqual(result, "\u{2153}")
    }

    func test_formatQuantity_twoThirds_returnsFraction() {
        let result = formatter.formatQuantity(2.0/3.0, unit: "cup")
        XCTAssertEqual(result, "\u{2154}")
    }

    func test_formatQuantity_oneEighth_returnsFraction() {
        let result = formatter.formatQuantity(0.125, unit: "teaspoon")
        XCTAssertEqual(result, "\u{215B}")
    }

    func test_formatQuantity_mixedNumber_returnsFraction() {
        // GIVEN: 1.5 (1 + 1/2)
        let result = formatter.formatQuantity(1.5, unit: "cup")

        // THEN: Returns "1 ½"
        XCTAssertEqual(result, "1 \u{00BD}")
    }

    func test_formatQuantity_twoAndQuarter_returnsFraction() {
        let result = formatter.formatQuantity(2.25, unit: "cup")
        XCTAssertEqual(result, "2 \u{00BC}")
    }

    func test_formatQuantity_verySmallValue_returnsEmpty() {
        // GIVEN: Value below threshold (< 0.05)
        let result = formatter.formatQuantity(0.01, unit: "cup")

        // THEN: Returns empty string
        XCTAssertEqual(result, "")
    }

    func test_formatQuantity_noFractionMatch_returnsDecimal() {
        // GIVEN: 1.4 doesn't match any practical fraction (0.4 is not within 0.05 of any)
        let result = formatter.formatQuantity(1.4, unit: "cup")

        // THEN: Falls back to decimal
        XCTAssertEqual(result, "1.4")
    }

    // MARK: - formatQuantity (Metric)

    func test_formatQuantity_metricWholeNumber_returnsInteger() {
        let result = formatter.formatQuantity(250.0, unit: "gram")
        XCTAssertEqual(result, "250")
    }

    func test_formatQuantity_metricDecimal_returnsOneDecimal() {
        let result = formatter.formatQuantity(250.5, unit: "gram")
        XCTAssertEqual(result, "250.5")
    }

    func test_formatQuantity_metricGrams_usesDecimals() {
        // GIVEN: 0.5 grams — metric should use decimals, not fractions
        let result = formatter.formatQuantity(0.5, unit: "gram")

        // THEN: Returns "0.5" not "½"
        XCTAssertEqual(result, "0.5")
    }

    func test_formatQuantity_metricMilliliters_usesDecimals() {
        let result = formatter.formatQuantity(100.3, unit: "ml")
        XCTAssertEqual(result, "100.3")
    }

    func test_formatQuantity_nilUnit_usesImperialFractions() {
        // GIVEN: No unit specified — defaults to imperial fractions
        let result = formatter.formatQuantity(0.5)

        // THEN: Uses fraction since no unit → not metric
        XCTAssertEqual(result, "\u{00BD}")
    }

    // MARK: - format() Basic

    func test_format_basicIngredient_formatsCorrectly() {
        // GIVEN: Ingredient with quantity, unit, and name
        let ingredient = env.createTestIngredient(
            name: "flour",
            quantity: 2.0,
            unit: "cups",
            recipe: env.createTestRecipe()
        )

        // WHEN: Formatting with no scaling
        let result = formatter.format(ingredient, convertUnits: false)

        // THEN: Quantity + unit + name
        XCTAssertEqual(result, "2 cups flour")
    }

    func test_format_noQuantity_returnsName() {
        // GIVEN: Ingredient with no quantity
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "salt to taste",
            quantity: nil,
            unit: nil,
            recipe: recipe
        )

        // WHEN: Formatting
        let result = formatter.format(ingredient, convertUnits: false)

        // THEN: Just the name
        XCTAssertEqual(result, "salt to taste")
    }

    func test_format_emptyNameFallsBackToOriginalText() {
        // GIVEN: Ingredient with empty name but has originalText
        let recipe = env.createTestRecipe()
        let ingredient = Ingredient(
            originalText: "2 cups all-purpose flour",
            name: "",
            quantity: 2.0,
            unit: "cups"
        )
        ingredient.recipe = recipe
        env.modelContext.insert(ingredient)

        // WHEN: Formatting
        let result = formatter.format(ingredient, convertUnits: false)

        // THEN: Falls back to originalText
        XCTAssertEqual(result, "2 cups all-purpose flour")
    }

    func test_format_withPreparation_includesParenthetical() {
        // GIVEN: Ingredient with preparation
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "onions",
            quantity: 2.0,
            unit: "cups",
            recipe: recipe
        )
        ingredient.preparation = "diced"

        // WHEN: Formatting
        let result = formatter.format(ingredient, convertUnits: false)

        // THEN: Includes preparation in parentheses
        XCTAssertEqual(result, "2 cups onions (diced)")
    }

    func test_format_optional_includesOptionalTag() {
        // GIVEN: Optional ingredient
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "vanilla extract",
            quantity: 1.0,
            unit: "teaspoon",
            recipe: recipe
        )
        ingredient.isOptional = true

        // WHEN: Formatting
        let result = formatter.format(ingredient, convertUnits: false)

        // THEN: Includes (optional)
        XCTAssertTrue(result.contains("(optional)"))
    }

    func test_format_quantityRange_showsBothValues() {
        // GIVEN: Ingredient with range
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "garlic",
            quantity: 2.0,
            unit: "cloves",
            recipe: recipe
        )
        ingredient.quantityMax = 3.0

        // WHEN: Formatting
        let result = formatter.format(ingredient, convertUnits: false)

        // THEN: Shows range
        XCTAssertEqual(result, "2 -3 cloves garlic")
    }

    // MARK: - format() Scaling

    func test_format_doubleScaling_doublesQuantity() {
        // GIVEN: 1 cup flour
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "flour",
            quantity: 1.0,
            unit: "cup",
            recipe: recipe
        )

        // WHEN: Scaling by 2x
        let result = formatter.format(ingredient, scaleFactor: 2.0, convertUnits: false)

        // THEN: Shows 2 cups
        XCTAssertEqual(result, "2 cup flour")
    }

    func test_format_halfScaling_halvesQuantity() {
        // GIVEN: 2 cups flour
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "flour",
            quantity: 2.0,
            unit: "cups",
            recipe: recipe
        )

        // WHEN: Scaling by 0.5x
        let result = formatter.format(ingredient, scaleFactor: 0.5, convertUnits: false)

        // THEN: Shows 1 cup (singularized)
        XCTAssertEqual(result, "1 cup flour")
    }

    func test_format_scalingProducesFraction_showsFraction() {
        // GIVEN: 1 cup butter
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "butter",
            quantity: 1.0,
            unit: "cup",
            recipe: recipe
        )

        // WHEN: Scaling by 0.5x → ½ cup
        let result = formatter.format(ingredient, scaleFactor: 0.5, convertUnits: false)

        // THEN: Shows ½
        XCTAssertTrue(result.contains("\u{00BD}"))
    }

    // MARK: - Embedded Quantity Scaling

    func test_format_embeddedQuantity_scalesNameQuantities() {
        // GIVEN: Ingredient "butter, divided" with embedded quantity in name
        // This simulates the pattern: "1/4 cup + 1 tablespoon butter"
        // where parser extracted 1/4 cup as main quantity and "plus 1 tablespoon butter" as name
        let recipe = env.createTestRecipe()
        let ingredient = Ingredient(
            originalText: "1/4 cup + 1 tablespoon butter",
            name: "plus 1 tablespoon butter",
            quantity: 0.25,
            unit: "cup"
        )
        ingredient.recipe = recipe
        env.modelContext.insert(ingredient)

        // WHEN: Scaling by 2x
        let result = formatter.format(ingredient, scaleFactor: 2.0, convertUnits: false)

        // THEN: Both quantities should be scaled
        // Main: 0.25 * 2 = 0.5 → "½"
        // Embedded: 1 tablespoon * 2 = 2 tablespoons
        XCTAssertTrue(result.contains("\u{00BD}"), "Main quantity should be scaled to ½")
        XCTAssertTrue(result.contains("2 tablespoon"), "Embedded quantity should be scaled to 2")
    }

    func test_format_embeddedQuantity_noScalingAtOne() {
        // GIVEN: Same compound ingredient
        let recipe = env.createTestRecipe()
        let ingredient = Ingredient(
            originalText: "1/4 cup + 1 tablespoon butter",
            name: "plus 1 tablespoon butter",
            quantity: 0.25,
            unit: "cup"
        )
        ingredient.recipe = recipe
        env.modelContext.insert(ingredient)

        // WHEN: No scaling (1x)
        let result = formatter.format(ingredient, scaleFactor: 1.0, convertUnits: false)

        // THEN: Name should be unchanged (no embedded scaling at 1x)
        XCTAssertTrue(result.contains("plus 1 tablespoon butter"))
    }

    func test_format_embeddedFraction_scalesCorrectly() {
        // GIVEN: Ingredient with embedded fraction in name
        let recipe = env.createTestRecipe()
        let ingredient = Ingredient(
            originalText: "1/2 cup + 1/4 cup butter",
            name: "plus 1/4 cup butter",
            quantity: 0.5,
            unit: "cup"
        )
        ingredient.recipe = recipe
        env.modelContext.insert(ingredient)

        // WHEN: Scaling by 2x
        let result = formatter.format(ingredient, scaleFactor: 2.0, convertUnits: false)

        // THEN: Embedded 1/4 * 2 = 1/2 → ½
        XCTAssertTrue(result.contains("\u{00BD}") || result.contains("½"),
                       "Embedded fraction should scale: got \(result)")
    }

    func test_format_noEmbeddedUnits_nameUnchanged() {
        // GIVEN: Ingredient where name has no quantity+unit pattern
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "all-purpose flour, sifted",
            quantity: 2.0,
            unit: "cups",
            recipe: recipe
        )

        // WHEN: Scaling by 2x
        let result = formatter.format(ingredient, scaleFactor: 2.0, convertUnits: false)

        // THEN: Name unchanged, only main quantity scaled
        XCTAssertTrue(result.contains("all-purpose flour, sifted"))
        XCTAssertTrue(result.contains("4"))
    }

    // MARK: - Unit Singularization (via format)

    func test_format_singularizesWhenQuantityIsOne() {
        // GIVEN: 1 cups flour (plural unit, singular quantity)
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "flour",
            quantity: 1.0,
            unit: "cups",
            recipe: recipe
        )

        // WHEN: Formatting
        let result = formatter.format(ingredient, convertUnits: false)

        // THEN: "cups" → "cup"
        XCTAssertEqual(result, "1 cup flour")
    }

    func test_format_singularizesWhenQuantityLessThanOne() {
        // GIVEN: ½ cups butter
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "butter",
            quantity: 0.5,
            unit: "cups",
            recipe: recipe
        )

        // WHEN: Formatting
        let result = formatter.format(ingredient, convertUnits: false)

        // THEN: "cups" → "cup"
        XCTAssertEqual(result, "\u{00BD} cup butter")
    }

    func test_format_keepsPluralWhenQuantityGreaterThanOne() {
        // GIVEN: 2 cups flour
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "flour",
            quantity: 2.0,
            unit: "cups",
            recipe: recipe
        )

        // WHEN: Formatting
        let result = formatter.format(ingredient, convertUnits: false)

        // THEN: "cups" stays "cups"
        XCTAssertEqual(result, "2 cups flour")
    }

    func test_format_singularizesTablespoons() {
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "oil",
            quantity: 1.0,
            unit: "tablespoons",
            recipe: recipe
        )
        let result = formatter.format(ingredient, convertUnits: false)
        XCTAssertEqual(result, "1 tablespoon oil")
    }

    func test_format_singularizesTeaspoons() {
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "salt",
            quantity: 0.5,
            unit: "teaspoons",
            recipe: recipe
        )
        let result = formatter.format(ingredient, convertUnits: false)
        XCTAssertEqual(result, "\u{00BD} teaspoon salt")
    }

    func test_format_singularizesLeaves() {
        // GIVEN: Special case "leaves" → "leaf"
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "bay",
            quantity: 1.0,
            unit: "leaves",
            recipe: recipe
        )
        let result = formatter.format(ingredient, convertUnits: false)
        XCTAssertEqual(result, "1 leaf bay")
    }

    func test_format_unknownUnit_returnsAsIs() {
        // GIVEN: Non-standard unit not in mapping
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "flour",
            quantity: 1.0,
            unit: "handful",
            recipe: recipe
        )
        let result = formatter.format(ingredient, convertUnits: false)
        XCTAssertEqual(result, "1 handful flour")
    }

    // MARK: - Edge Cases

    func test_format_zeroQuantity_handledGracefully() {
        // GIVEN: Quantity of 0 (below threshold)
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "flour",
            quantity: 0.0,
            unit: "cups",
            recipe: recipe
        )

        // WHEN: Formatting
        let result = formatter.format(ingredient, convertUnits: false)

        // THEN: Empty quantity string, just name
        // formatQuantity returns "" for values < 0.05
        XCTAssertTrue(result.contains("flour"))
    }

    func test_format_scalingRange_scalesBothValues() {
        // GIVEN: Range 2-3 cloves
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "garlic",
            quantity: 2.0,
            unit: "cloves",
            recipe: recipe
        )
        ingredient.quantityMax = 3.0

        // WHEN: Scaling by 2x
        let result = formatter.format(ingredient, scaleFactor: 2.0, convertUnits: false)

        // THEN: Both values doubled: 4-6
        XCTAssertTrue(result.contains("4"), "Min should be scaled to 4")
        XCTAssertTrue(result.contains("6"), "Max should be scaled to 6")
    }

    func test_format_withPreparationAndOptional_includesBoth() {
        let recipe = env.createTestRecipe()
        let ingredient = env.createTestIngredient(
            name: "parsley",
            quantity: 2.0,
            unit: "tablespoons",
            recipe: recipe
        )
        ingredient.preparation = "chopped"
        ingredient.isOptional = true

        let result = formatter.format(ingredient, convertUnits: false)
        XCTAssertEqual(result, "2 tablespoons parsley (chopped) (optional)")
    }
}
