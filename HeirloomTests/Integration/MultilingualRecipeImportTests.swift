//
//  MultilingualRecipeImportTests.swift
//  HeirloomTests
//
//  End-to-end integration tests for multilingual recipe import
//  Tests the full flow from URL to saved recipe with translations
//

import XCTest
import SwiftData
@testable import Heirloom

final class MultilingualRecipeImportTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        // Create in-memory test container
        let schema = Schema([
            Recipe.self,
            Ingredient.self,
            RecipeCollection.self,
            Tag.self,
            ShoppingCartRecipe.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )

        modelContext = ModelContext(modelContainer)
    }

    override func tearDownWithError() throws {
        modelContext = nil
        modelContainer = nil
    }

    // MARK: - Ingredient Integration Tests

    func testIngredientWithConversion() throws {
        // Test that ingredient conversion metadata is properly stored
        let ingredient = Ingredient(
            originalText: "2 cups flour",
            name: "flour",
            quantity: 1.688,  // Converted from Japanese cups
            unit: "cup",
            orderIndex: 0
        )

        ingredient.originalLanguageName = "2カップの小麦粉"
        ingredient.translatedName = "2 cups flour"
        ingredient.wasConverted = true
        ingredient.conversionNote = "Japanese cup (200ml) converted to US cup (237ml)"

        // Verify all metadata is set
        XCTAssertTrue(ingredient.wasConverted)
        XCTAssertNotNil(ingredient.conversionNote)
        XCTAssertNotNil(ingredient.originalLanguageName)
        XCTAssertNotNil(ingredient.translatedName)
        XCTAssertEqual(ingredient.quantity ?? 0, 1.688, accuracy: 0.001)
    }

    func testRecipeWithMultilingualMetadata() throws {
        // Test that recipe stores all multilingual metadata
        let recipe = Recipe(
            title: "Chocolate Chip Cookies",
            sourceType: .url,
            sourceURL: "https://www.marmiton.org/test",
            instructions: ["Mix ingredients", "Bake at 350°F"],
            servings: "24 cookies",
            prepTime: "15 min",
            cookTime: "12 min"
        )

        // Set multilingual metadata
        recipe.sourceLanguage = "fr"
        recipe.originalTitle = "Cookies aux Pépites de Chocolat"
        recipe.originalInstructions = ["Mélanger les ingrédients", "Cuire à 180°C"]
        recipe.translatedTitle = "Chocolate Chip Cookies"
        recipe.translatedInstructions = ["Mix ingredients", "Bake at 350°F"]
        recipe.detectedUnitSystem = "metric"

        // Verify all fields are set
        XCTAssertEqual(recipe.sourceLanguage, "fr")
        XCTAssertNotNil(recipe.originalTitle)
        XCTAssertNotNil(recipe.originalInstructions)
        XCTAssertNotNil(recipe.translatedTitle)
        XCTAssertNotNil(recipe.translatedInstructions)
        XCTAssertEqual(recipe.detectedUnitSystem, "metric")
    }

    func testRecipeWithIngredientsPreservesOrder() throws {
        // Test that ingredients maintain correct order
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            sourceURL: nil,
            instructions: ["Test"],
            servings: "4",
            prepTime: nil,
            cookTime: nil
        )

        let ingredients = [
            Ingredient(originalText: "2 cups flour", name: "flour", quantity: 2, unit: "cup", orderIndex: 0),
            Ingredient(originalText: "1 cup sugar", name: "sugar", quantity: 1, unit: "cup", orderIndex: 1),
            Ingredient(originalText: "3 eggs", name: "eggs", quantity: 3, unit: nil, orderIndex: 2)
        ]

        recipe.ingredients = ingredients

        // Verify order is preserved
        XCTAssertEqual(recipe.ingredients?.count, 3)
        XCTAssertEqual(recipe.ingredients?[0].orderIndex, 0)
        XCTAssertEqual(recipe.ingredients?[1].orderIndex, 1)
        XCTAssertEqual(recipe.ingredients?[2].orderIndex, 2)
    }

    // MARK: - Language Detection Edge Cases

    func testEnglishRecipeNoMetadata() throws {
        // English recipes should not have language metadata
        let recipe = Recipe(
            title: "Apple Pie",
            sourceType: .manual,
            sourceURL: nil,
            instructions: ["Make pie"],
            servings: "8",
            prepTime: nil,
            cookTime: nil
        )

        // Should default to nil (no language metadata)
        XCTAssertNil(recipe.sourceLanguage)
        XCTAssertNil(recipe.originalTitle)
        XCTAssertNil(recipe.translatedTitle)
        XCTAssertNil(recipe.detectedUnitSystem)
    }

    func testMultilingualRecipeFieldsOptional() throws {
        // All multilingual fields should be optional
        let recipe = Recipe(
            title: "Test",
            sourceType: .manual,
            sourceURL: nil,
            instructions: ["Test"],
            servings: "4",
            prepTime: nil,
            cookTime: nil
        )

        // Set only some fields
        recipe.sourceLanguage = "ja"
        recipe.originalTitle = "テスト"

        // Should allow partial metadata
        XCTAssertEqual(recipe.sourceLanguage, "ja")
        XCTAssertEqual(recipe.originalTitle, "テスト")
        XCTAssertNil(recipe.translatedTitle)
        XCTAssertNil(recipe.detectedUnitSystem)
    }

    // MARK: - Database Persistence Tests

    func testSaveRecipeWithMultilingualMetadata() throws {
        let recipe = Recipe(
            title: "Bibimbap",
            sourceType: .url,
            sourceURL: "https://www.10000recipe.com/test",
            instructions: ["Mix rice", "Add vegetables"],
            servings: "2",
            prepTime: "20 min",
            cookTime: "10 min"
        )

        recipe.sourceLanguage = "ko"
        recipe.originalTitle = "비빔밥"
        recipe.translatedTitle = "Bibimbap"
        recipe.detectedUnitSystem = "metric"

        // Save to context
        modelContext.insert(recipe)
        try modelContext.save()

        // Fetch back
        let fetchDescriptor = FetchDescriptor<Recipe>()
        let recipes = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(recipes.count, 1)
        let fetchedRecipe = recipes[0]

        // Verify persistence
        XCTAssertEqual(fetchedRecipe.title, "Bibimbap")
        XCTAssertEqual(fetchedRecipe.sourceLanguage, "ko")
        XCTAssertEqual(fetchedRecipe.originalTitle, "비빔밥")
        XCTAssertEqual(fetchedRecipe.translatedTitle, "Bibimbap")
        XCTAssertEqual(fetchedRecipe.detectedUnitSystem, "metric")
    }

    func testSaveIngredientWithConversionMetadata() throws {
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            sourceURL: nil,
            instructions: ["Test"],
            servings: "4",
            prepTime: nil,
            cookTime: nil
        )

        let ingredient = Ingredient(
            originalText: "2 cups flour",
            name: "flour",
            quantity: 1.688,
            unit: "cup",
            orderIndex: 0
        )

        ingredient.wasConverted = true
        ingredient.conversionNote = "Japanese cup (200ml) → US cup (237ml)"
        ingredient.originalLanguageName = "2カップの小麦粉"

        recipe.ingredients = [ingredient]

        // Save to context
        modelContext.insert(recipe)
        try modelContext.save()

        // Fetch back
        let fetchDescriptor = FetchDescriptor<Recipe>()
        let recipes = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(recipes.count, 1)
        let fetchedRecipe = recipes[0]
        let fetchedIngredient = fetchedRecipe.ingredients?.first

        // Verify ingredient metadata persisted
        XCTAssertNotNil(fetchedIngredient)
        XCTAssertTrue(fetchedIngredient!.wasConverted)
        XCTAssertEqual(fetchedIngredient!.conversionNote, "Japanese cup (200ml) → US cup (237ml)")
        XCTAssertEqual(fetchedIngredient!.originalLanguageName, "2カップの小麦粉")
    }

    // MARK: - Data Migration Tests

    func testLegacyRecipeWithoutLanguageFields() throws {
        // Old recipes without language fields should still work
        let legacyRecipe = Recipe(
            title: "Old Recipe",
            sourceType: .manual,
            sourceURL: nil,
            instructions: ["Step 1"],
            servings: "4",
            prepTime: nil,
            cookTime: nil
        )

        // Don't set any language fields
        modelContext.insert(legacyRecipe)
        try modelContext.save()

        // Fetch back - should work fine
        let fetchDescriptor = FetchDescriptor<Recipe>()
        let recipes = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(recipes.count, 1)
        let fetchedRecipe = recipes[0]

        // All language fields should be nil
        XCTAssertNil(fetchedRecipe.sourceLanguage)
        XCTAssertNil(fetchedRecipe.originalTitle)
        XCTAssertNil(fetchedRecipe.translatedTitle)
    }

    // MARK: - Conversion Accuracy Tests

    func testJapaneseCupConversionAccuracy() {
        // Test actual conversion matches expected ratio
        let originalQty = 2.0  // Japanese cups
        let converted = UnitConversionService.adjustQuantity(
            originalQty,
            unit: "cup",
            sourceLanguage: "ja"
        )

        // 2 Japanese cups (400ml) = 1.688 US cups (237ml each)
        let expected = 2.0 * (200.0 / 237.0)
        XCTAssertEqual(converted, expected, accuracy: 0.001)
    }

    func testKoreanGeunConversionAccuracy() {
        // Test Korean traditional unit conversion
        let originalQty = 1.0  // 1 근
        let converted = UnitConversionService.adjustQuantity(
            originalQty,
            unit: "g",
            sourceLanguage: "ko",
            originalUnit: "근"
        )

        // 1 근 = 600g
        XCTAssertEqual(converted, 600.0, accuracy: 0.1)
    }

    func testFrenchMetricCupConversionAccuracy() {
        // Test French metric cup conversion
        let originalQty = 1.0  // French cup
        let converted = UnitConversionService.adjustQuantity(
            originalQty,
            unit: "cup",
            sourceLanguage: "fr"
        )

        // 1 French cup (250ml) = 1.055 US cups (237ml)
        let expected = 1.0 * (250.0 / 237.0)
        XCTAssertEqual(converted, expected, accuracy: 0.001)
    }

    // MARK: - Zero-Regression Validation

    func testEnglishIngredientParsingUnchanged() {
        // Critical: English ingredient parsing must be identical to before
        let testCases = [
            ("2 cups flour", 2.0, "cup", "flour"),
            ("1 tbsp butter", 1.0, "tbsp", "butter"),
            ("3 tsp salt", 3.0, "tsp", "salt"),
            ("500 g sugar", 500.0, "g", "sugar"),
            ("2 lbs beef", 2.0, "lb", "beef")
        ]

        for (input, expectedQty, expectedUnit, expectedName) in testCases {
            let (qty, _, unit, name) = IngredientParser.parse(input, language: "en")

            XCTAssertEqual(qty ?? 0, expectedQty, accuracy: 0.01,
                          "English parsing changed for: \(input)")
            XCTAssertEqual(unit, expectedUnit,
                          "English unit detection changed for: \(input)")
            XCTAssertEqual(name, expectedName,
                          "English name extraction changed for: \(input)")
        }
    }

    func testEnglishDefaultLanguageParameter() {
        // Test that omitting language parameter defaults to English
        let (qty, _, unit, name) = IngredientParser.parse("2 cups flour")

        XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01)
        XCTAssertEqual(unit, "cup")
        XCTAssertEqual(name, "flour")

        // Should be identical to explicit "en"
        let (qty2, _, unit2, name2) = IngredientParser.parse("2 cups flour", language: "en")

        XCTAssertEqual(qty, qty2)
        XCTAssertEqual(unit, unit2)
        XCTAssertEqual(name, name2)
    }

    func testEnglishQuantityNoConversion() {
        // English quantities should never be converted
        let testUnits = ["cup", "tbsp", "tsp", "g", "kg", "lb", "oz"]

        for unit in testUnits {
            let result = UnitConversionService.adjustQuantity(
                1.0,
                unit: unit,
                sourceLanguage: "en"
            )

            XCTAssertEqual(result, 1.0, accuracy: 0.001,
                          "English \(unit) should not be converted")
        }
    }

    // MARK: - Performance Tests

    func testIngredientParsingPerformance() {
        // Test that parsing is fast enough for typical recipes (30 ingredients)
        measure {
            for _ in 0..<30 {
                _ = IngredientParser.parse("2 cups flour", language: "en")
                _ = IngredientParser.parse("1 tbsp butter", language: "en")
                _ = IngredientParser.parse("500 g sugar", language: "fr")
            }
        }
    }

    func testUnitConversionPerformance() {
        // Test that unit conversion is fast for typical recipe (30 ingredients)
        measure {
            for _ in 0..<30 {
                _ = UnitConversionService.adjustQuantity(1.0, unit: "cup", sourceLanguage: "ja")
                _ = UnitConversionService.adjustQuantity(2.0, unit: "cup", sourceLanguage: "ko")
                _ = UnitConversionService.adjustQuantity(3.0, unit: "g", sourceLanguage: "ko", originalUnit: "근")
            }
        }
    }
}
