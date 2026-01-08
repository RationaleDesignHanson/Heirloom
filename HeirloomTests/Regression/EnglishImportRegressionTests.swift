import XCTest
import SwiftData
@testable import Heirloom

/// English Import Regression Test Suite
///
/// **Purpose:** Establish baseline behavior for English recipe imports to verify ZERO REGRESSIONS
/// when adding multilingual support.
///
/// **Critical:** ALL tests in this file must continue passing after multilingual changes.
/// If any test fails, multilingual implementation has introduced a regression.
///
/// **Usage:**
/// - Run before multilingual implementation: Establish baseline
/// - Run after each multilingual phase: Verify no regressions
/// - Any failures are BLOCKING issues
@MainActor
final class EnglishImportRegressionTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try TestFixtures.createTestContainer()
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Ingredient Parsing Regression Tests

    /// Baseline: English ingredients parse correctly
    func testRegression_EnglishIngredientParsing_SimpleCup() {
        // Given: Standard English ingredient
        let input = "1 cup flour"

        // When: Parsed
        let result = IngredientParser.parse(input)

        // Then: Must parse correctly (BASELINE)
        XCTAssertEqual(result.quantity, 1.0, "English quantity parsing must not regress")
        XCTAssertEqual(result.unit, "cup", "English unit parsing must not regress")
        XCTAssertEqual(result.name, "flour", "English name extraction must not regress")
    }

    func testRegression_EnglishIngredientParsing_Fraction() {
        // Given: English fraction
        let input = "½ teaspoon salt"

        // When: Parsed
        let result = IngredientParser.parse(input)

        // Then: Fraction parsing must work (BASELINE)
        XCTAssertEqual(result.quantity, 0.5, "English fraction parsing must not regress")
        XCTAssertEqual(result.unit, "teaspoon", "English unit must not regress")
        XCTAssertEqual(result.name, "salt")
    }

    func testRegression_EnglishIngredientParsing_MixedNumber() {
        // Given: English mixed number
        let input = "1 1/2 cups flour"

        // When: Parsed
        let result = IngredientParser.parse(input)

        // Then: Mixed number must parse (BASELINE)
        XCTAssertEqual(result.quantity, 1.5, "English mixed numbers must not regress")
        XCTAssertEqual(result.unit, "cup")
    }

    func testRegression_EnglishIngredientParsing_Range() {
        // Given: English range
        let input = "2-3 cups flour"

        // When: Parsed
        let result = IngredientParser.parse(input)

        // Then: Range must parse (BASELINE)
        XCTAssertEqual(result.quantity, 2.0, "Range minimum must not regress")
        XCTAssertEqual(result.quantityMax, 3.0, "Range maximum must not regress")
    }

    func testRegression_EnglishIngredientParsing_NoQuantity() {
        // Given: English ingredient without quantity
        let input = "Salt to taste"

        // When: Parsed
        let result = IngredientParser.parse(input)

        // Then: Must handle gracefully (BASELINE)
        XCTAssertNil(result.quantity, "No-quantity ingredients must not regress")
        XCTAssertEqual(result.name, "Salt to taste")
    }

    func testRegression_EnglishIngredientParsing_WithPreparation() {
        // Given: English ingredient with preparation
        let input = "1 pound ground beef, browned and drained"

        // When: Parsed
        let result = IngredientParser.parse(input)

        // Then: Must extract correctly (BASELINE)
        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.unit, "pound")
        XCTAssertTrue(result.name.contains("ground beef"), "Name extraction must not regress")
    }

    func testRegression_EnglishIngredientParsing_MetricUnits() {
        // Given: English recipe with metric units (common in modern recipes)
        let inputs = [
            "250 grams flour",
            "500 ml water",
            "2 kg sugar"
        ]

        // When/Then: Must parse metric units correctly
        let result1 = IngredientParser.parse(inputs[0])
        XCTAssertEqual(result1.quantity, 250.0)
        XCTAssertEqual(result1.unit, "gram")

        let result2 = IngredientParser.parse(inputs[1])
        XCTAssertEqual(result2.quantity, 500.0)
        XCTAssertEqual(result2.unit, "milliliter")

        let result3 = IngredientParser.parse(inputs[2])
        XCTAssertEqual(result3.quantity, 2.0)
        XCTAssertEqual(result3.unit, "kilogram")
    }

    func testRegression_EnglishIngredientParsing_ImperialUnits() {
        // Given: Standard English imperial units
        let inputs = [
            "2 tablespoons butter",
            "1 teaspoon vanilla",
            "8 ounces cream cheese",
            "1 pound flour"
        ]

        // When/Then: Must parse imperial correctly
        let results = inputs.map { IngredientParser.parse($0) }

        XCTAssertEqual(results[0].unit, "tablespoon", "Tablespoon must not regress")
        XCTAssertEqual(results[1].unit, "teaspoon", "Teaspoon must not regress")
        XCTAssertEqual(results[2].unit, "oz.", "Ounce must not regress")
        XCTAssertEqual(results[3].unit, "pound", "Pound must not regress")
    }

    func testRegression_EnglishIngredientParsing_Abbreviations() {
        // Given: Common English abbreviations
        let inputs = [
            "1 tbsp oil",
            "1 tsp salt",
            "8 oz cheese",
            "1 lb beef"
        ]

        // When/Then: Abbreviations must normalize
        XCTAssertEqual(IngredientParser.parse(inputs[0]).unit, "tablespoon")
        XCTAssertEqual(IngredientParser.parse(inputs[1]).unit, "teaspoon")
        XCTAssertEqual(IngredientParser.parse(inputs[2]).unit, "oz.")
        XCTAssertEqual(IngredientParser.parse(inputs[3]).unit, "pound")
    }

    // MARK: - Recipe Model Regression Tests

    func testRegression_RecipeCreation_BasicEnglish() throws {
        // Given: Standard English recipe
        let recipe = Recipe(
            title: "Chocolate Chip Cookies",
            sourceType: .manual
        )
        recipe.instructions = [
            "Preheat oven to 350°F",
            "Mix dry ingredients",
            "Cream butter and sugar",
            "Combine and bake"
        ]
        recipe.servings = "24 cookies"
        recipe.prepTime = "15 minutes"
        recipe.cookTime = "12 minutes"

        // When: Saved to database
        modelContext.insert(recipe)
        try modelContext.save()

        // Then: Must persist correctly (BASELINE)
        let descriptor = FetchDescriptor<Recipe>()
        let saved = try modelContext.fetch(descriptor)

        XCTAssertEqual(saved.count, 1, "Recipe count must not regress")
        XCTAssertEqual(saved.first?.title, "Chocolate Chip Cookies")
        XCTAssertEqual(saved.first?.sourceType, .manual)
        XCTAssertEqual(saved.first?.instructions.count, 4)
        XCTAssertEqual(saved.first?.servings, "24 cookies")
    }

    func testRegression_RecipeWithIngredients_English() throws {
        // Given: English recipe with ingredients
        let recipe = Recipe(title: "Simple Cake", sourceType: .manual)
        modelContext.insert(recipe)

        let ingredientTexts = [
            "2 cups flour",
            "1 cup sugar",
            "½ cup butter",
            "2 eggs",
            "1 teaspoon vanilla"
        ]

        // When: Ingredients added
        for (index, text) in ingredientTexts.enumerated() {
            let parsed = IngredientParser.parse(text)
            let ingredient = Ingredient(
                originalText: text,
                name: parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit,
                category: .other,
                orderIndex: index
            )
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
        }
        try modelContext.save()

        // Then: Relationships must work (BASELINE)
        XCTAssertEqual(recipe.ingredients?.count, 5, "Ingredient count must not regress")
        XCTAssertNotNil(recipe.ingredients?.first?.recipe, "Recipe relationship must not regress")

        // Verify parsing didn't break
        let firstIngredient = recipe.ingredients?.first
        XCTAssertEqual(firstIngredient?.quantity, 2.0)
        XCTAssertEqual(firstIngredient?.unit, "cup")
    }

    // MARK: - OCR Baseline Tests

    func testRegression_EnglishOCRText_BasicExtraction() {
        // Given: English OCR text
        let ocrText = """
        CHOCOLATE CHIP COOKIES

        Ingredients:
        2 cups all-purpose flour
        1 cup butter, softened
        3/4 cup sugar
        2 eggs
        1 teaspoon vanilla extract

        Instructions:
        1. Preheat oven to 350°F
        2. Mix ingredients
        3. Bake for 12 minutes
        """

        // When: Extract recipe (basic mode)
        let extractor = AIRecipeExtractor.shared
        let extracted = extractor.extractRecipeBasic(from: ocrText)

        // Then: Must extract English content (BASELINE)
        XCTAssertFalse(extracted.title.isEmpty, "Title extraction must not regress")
        XCTAssertGreaterThan(extracted.ingredients.count, 0, "Ingredient extraction must not regress")
        XCTAssertGreaterThan(extracted.instructions.count, 0, "Instruction extraction must not regress")
    }

    // MARK: - Performance Regression Tests

    func testPerformance_EnglishIngredientParsing() {
        // Baseline: Measure English ingredient parsing speed
        let ingredients = [
            "2 cups all-purpose flour",
            "1 cup granulated sugar",
            "3/4 cup unsalted butter, softened",
            "2 large eggs",
            "1 teaspoon vanilla extract",
            "1/2 teaspoon baking soda",
            "1/4 teaspoon salt",
            "2 cups chocolate chips"
        ]

        measure {
            for _ in 0..<100 {
                for ingredient in ingredients {
                    _ = IngredientParser.parse(ingredient)
                }
            }
        }

        // NOTE: After multilingual, this must not be >10% slower
    }

    func testPerformance_EnglishRecipeSave() throws {
        // Baseline: Measure recipe save speed
        measure {
            let recipe = Recipe(title: "Test Recipe", sourceType: .manual)
            recipe.instructions = ["Step 1", "Step 2", "Step 3"]

            self.modelContext.insert(recipe)
            try? self.modelContext.save()

            // Clean up
            self.modelContext.delete(recipe)
            try? self.modelContext.save()
        }

        // NOTE: Save speed must not regress after multilingual
    }

    // MARK: - Edge Case Regression Tests

    func testRegression_EmptyRecipe_English() throws {
        // Given: Minimal English recipe
        let recipe = Recipe(title: "Empty Recipe", sourceType: .manual)

        // When: Saved with no ingredients/instructions
        modelContext.insert(recipe)
        try modelContext.save()

        // Then: Must handle gracefully (BASELINE)
        let descriptor = FetchDescriptor<Recipe>()
        let saved = try modelContext.fetch(descriptor)

        XCTAssertEqual(saved.count, 1, "Empty recipe must save")
        XCTAssertTrue(saved.first?.instructions.isEmpty ?? true)
        XCTAssertTrue(saved.first?.ingredients?.isEmpty ?? true)
    }

    func testRegression_SpecialCharacters_English() throws {
        // Given: English recipe with special characters
        let recipe = Recipe(
            title: "Mom's \"Secret\" Recipe (1987) – Best Ever!",
            sourceType: .manual
        )
        recipe.instructions = [
            "Preheat to 350° F",
            "Mix ½ cup sugar & ¼ tsp salt",
            "Bake @ 350°F for 10–12 min"
        ]

        // When: Saved
        modelContext.insert(recipe)
        try modelContext.save()

        // Then: Special characters must persist (BASELINE)
        let descriptor = FetchDescriptor<Recipe>()
        let saved = try modelContext.fetch(descriptor)

        XCTAssertEqual(saved.first?.title, recipe.title, "Special characters must not corrupt")
        XCTAssertTrue(saved.first!.instructions[0].contains("°"), "Degree symbol must persist")
        XCTAssertTrue(saved.first!.instructions[1].contains("½"), "Fractions must persist")
    }

    func testRegression_LongRecipe_English() throws {
        // Given: Very long English recipe
        let recipe = Recipe(title: "Complex Recipe", sourceType: .manual)
        recipe.instructions = (1...50).map { "Step \($0): Do something" }
        modelContext.insert(recipe)

        // When: Saved
        try modelContext.save()

        // Then: Large recipes must work (BASELINE)
        let descriptor = FetchDescriptor<Recipe>()
        let saved = try modelContext.fetch(descriptor)

        XCTAssertEqual(saved.first?.instructions.count, 50, "Large instruction count must not regress")
    }

    // MARK: - Unit Normalization Regression Tests

    func testRegression_UnitNormalization_Plurals() {
        // Given: Plural units
        let plurals = [
            "2 cups flour",
            "3 tablespoons oil",
            "4 teaspoons salt",
            "5 ounces cheese",
            "6 pounds beef"
        ]

        // When/Then: Must normalize to singular
        XCTAssertEqual(IngredientParser.parse(plurals[0]).unit, "cup", "Plural normalization must not regress")
        XCTAssertEqual(IngredientParser.parse(plurals[1]).unit, "tablespoon")
        XCTAssertEqual(IngredientParser.parse(plurals[2]).unit, "teaspoon")
        XCTAssertEqual(IngredientParser.parse(plurals[3]).unit, "oz.")
        XCTAssertEqual(IngredientParser.parse(plurals[4]).unit, "pound")
    }

    // MARK: - Test Documentation

    /// This test documents expected behavior that MUST NOT CHANGE
    func testDocumentation_EnglishParsingExpectedBehavior() {
        // Document: US cup is 240ml (will matter for Japanese/Korean 200ml comparison)
        // Document: Fractions convert to decimals
        // Document: Plurals normalize to singular
        // Document: Abbreviations expand

        let examples = [
            ("1 cup water", 1.0, "cup"),           // US cup (240ml implied)
            ("½ cup flour", 0.5, "cup"),           // Unicode fraction
            ("2 cups sugar", 2.0, "cup"),          // Plural → singular
            ("1 tbsp oil", 1.0, "tablespoon"),     // Abbreviation → full
            ("3 oz cheese", 3.0, "oz.")            // Period added
        ]

        for (input, expectedQty, expectedUnit) in examples {
            let result = IngredientParser.parse(input)
            XCTAssertEqual(result.quantity, expectedQty, "Baseline behavior changed for: \(input)")
            XCTAssertEqual(result.unit, expectedUnit, "Unit normalization changed for: \(input)")
        }
    }
}
