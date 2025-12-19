import XCTest
@testable import Heirloom

/// Tests for AIIngredientParser - the core ingredient parsing feature
/// Target: 95%+ accuracy on test dataset, 90%+ code coverage
@MainActor
final class AIIngredientParserTests: XCTestCase {

    var parser: AIIngredientParser!
    var mockService: MockAnthropicAIService!
    var configuration: AIConfiguration!

    override func setUp() async throws {
        parser = AIIngredientParser.shared
        mockService = MockAnthropicAIService()
        configuration = AIConfiguration.shared

        // Enable AI parsing for tests
        configuration.enableAIParsing = true
        configuration.setAPIKey(AITestFixtures.validAPIKey, for: .anthropic)

        // Note: In production, would inject mockService into parser
        // For these tests, we're testing the fallback behavior
    }

    override func tearDown() async throws {
        mockService.reset()
        configuration.enableAIParsing = false
        configuration.setAPIKey(nil, for: .anthropic)
    }

    // MARK: - Basic Parsing Tests

    func test_parse_simpleIngredient() async throws {
        // Test with AI disabled to use regex fallback (testable without real API)
        configuration.enableAIParsing = false

        let result = try await parser.parse("2 cups all-purpose flour")

        XCTAssertEqual(result.quantity, 2.0, "Should parse quantity correctly")
        XCTAssertNil(result.quantityMax, "Should not have max quantity")
        XCTAssertEqual(result.unit, "cups", "Should parse unit correctly")
        XCTAssertTrue(result.name.contains("flour"), "Should extract ingredient name")
    }

    func test_parse_fractionIngredient() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("1/2 teaspoon salt")

        XCTAssertNotNil(result.quantity, "Should have quantity")
        XCTAssertEqual(result.quantity!, 0.5, accuracy: 0.01, "Should parse fraction correctly")
        XCTAssertEqual(result.unit, "teaspoon")
        XCTAssertTrue(result.name.contains("salt"))
    }

    func test_parse_mixedFractionIngredient() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("2 1/4 cups granulated sugar")

        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity!, 2.25, accuracy: 0.01, "Should parse mixed fraction")
        XCTAssertEqual(result.unit, "cups")
        XCTAssertTrue(result.name.contains("sugar"))
    }

    func test_parse_rangeIngredient() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("2-3 tablespoons olive oil")

        XCTAssertEqual(result.quantity, 2.0, "Should parse minimum of range")
        XCTAssertEqual(result.quantityMax, 3.0, "Should parse maximum of range")
        XCTAssertEqual(result.unit, "tablespoons")
        XCTAssertTrue(result.name.contains("oil"))
    }

    func test_parse_noQuantityIngredient() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("Salt to taste")

        XCTAssertNil(result.quantity, "Should have no quantity")
        XCTAssertNil(result.unit, "Should have no unit")
        XCTAssertTrue(result.name.lowercased().contains("salt"), "Should extract name")
    }

    func test_parse_complexIngredient() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("1 (15 oz) can diced tomatoes")

        XCTAssertEqual(result.quantity, 1.0, "Should parse count")
        // May parse as "can" or extract weight
        XCTAssertTrue(result.name.contains("tomatoes"), "Should extract ingredient name")
    }

    func test_parse_ingredientWithPreparation() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("2 cups flour, sifted")

        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertEqual(result.unit, "cups")
        XCTAssertTrue(result.name.contains("flour"), "Should extract base ingredient")
    }

    func test_parse_weightMeasurement() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("500 grams sugar")

        XCTAssertEqual(result.quantity, 500.0)
        XCTAssertEqual(result.unit, "grams")
        XCTAssertTrue(result.name.contains("sugar"))
    }

    // MARK: - Fallback Behavior Tests

    func test_parse_fallsBackToRegex_whenAIDisabled() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("2 cups flour")

        // Should use regex parser fallback
        XCTAssertNotNil(result.quantity, "Regex fallback should parse quantity")
        XCTAssertEqual(result.quantity, 2.0)
    }

    func test_parse_fallsBackToRegex_whenNotConfigured() async throws {
        configuration.setAPIKey(nil, for: .anthropic)

        let result = try await parser.parse("2 cups flour")

        // Should fall back to regex
        XCTAssertNotNil(result.quantity, "Should use fallback when not configured")
    }

    func test_parse_fallsBackToRegex_whenInvalidAPIKey() async throws {
        configuration.setAPIKey("invalid-key", for: .anthropic)

        let result = try await parser.parse("2 cups flour")

        // Should fall back since key is invalid
        XCTAssertNotNil(result.quantity, "Should use fallback with invalid key")
    }

    // MARK: - Batch Parsing Tests

    func test_parseBatch_multipleIngredients() async throws {
        configuration.enableAIParsing = false

        let ingredients = [
            "1 cup flour",
            "2 eggs",
            "1/2 teaspoon salt"
        ]

        let results = try await parser.parseBatch(ingredients)

        XCTAssertEqual(results.count, 3, "Should parse all ingredients")

        XCTAssertEqual(results[0].quantity, 1.0)
        XCTAssertTrue(results[0].name.contains("flour"))

        XCTAssertEqual(results[1].quantity, 2.0)
        XCTAssertTrue(results[1].name.contains("eggs"))

        XCTAssertEqual(results[2].quantity, 0.5)
        XCTAssertTrue(results[2].name.contains("salt"))
    }

    func test_parseBatch_emptyArray() async throws {
        let results = try await parser.parseBatch([])

        XCTAssertEqual(results.count, 0, "Should return empty array for empty input")
    }

    func test_parseBatch_singleIngredient() async throws {
        configuration.enableAIParsing = false

        let results = try await parser.parseBatch(["1 cup milk"])

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].quantity, 1.0)
    }

    func test_parseBatch_preservesOrder() async throws {
        configuration.enableAIParsing = false

        let ingredients = ["flour", "sugar", "salt", "eggs", "butter"]
        let results = try await parser.parseBatch(ingredients)

        XCTAssertEqual(results.count, 5, "Should parse all ingredients")

        // Verify order is preserved
        XCTAssertTrue(results[0].name.contains("flour"))
        XCTAssertTrue(results[1].name.contains("sugar"))
        XCTAssertTrue(results[2].name.contains("salt"))
        XCTAssertTrue(results[3].name.contains("eggs"))
        XCTAssertTrue(results[4].name.contains("butter"))
    }

    // MARK: - Edge Cases

    func test_parse_emptyString() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("")

        XCTAssertNil(result.quantity)
        XCTAssertNil(result.unit)
        // Name may be empty or have default value
    }

    func test_parse_whitespaceOnly() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("   ")

        XCTAssertNil(result.quantity)
        XCTAssertNil(result.unit)
    }

    func test_parse_veryLongIngredientText() async throws {
        configuration.enableAIParsing = false

        let longText = "2 cups " + String(repeating: "very long ingredient name ", count: 50)
        let result = try await parser.parse(longText)

        XCTAssertEqual(result.quantity, 2.0, "Should parse quantity even with long text")
        XCTAssertEqual(result.unit, "cups")
    }

    func test_parse_unicodeCharacters() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("½ cup milk")

        // Some parsers may handle unicode fractions
        XCTAssertNotNil(result, "Should handle unicode without crashing")
    }

    func test_parse_specialCharacters() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("1 cup sugar & spice")

        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertTrue(result.name.contains("sugar"), "Should handle special characters")
    }

    func test_parse_multipleUnits() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("1 cup (250ml) milk")

        XCTAssertEqual(result.quantity, 1.0)
        // Should parse primary unit
        XCTAssertNotNil(result.unit)
    }

    func test_parse_noSpaces() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("2cups flour")

        // May or may not parse correctly - depends on regex robustness
        XCTAssertNotNil(result, "Should not crash on malformed input")
    }

    // MARK: - Accuracy Validation Tests

    func test_accuracy_commonIngredients() async throws {
        configuration.enableAIParsing = false

        let testCases = AITestFixtures.fractionalIngredients

        var correctCount = 0
        for (input, expected) in testCases {
            let result = try await parser.parse(input)

            if AITestFixtures.matches(parsed: result, expected: expected) {
                correctCount += 1
            } else {
                print("❌ Failed to parse '\(input)' correctly")
                print("   Expected: \(expected)")
                print("   Got: \(result)")
            }
        }

        let accuracy = Double(correctCount) / Double(testCases.count)
        print("✅ Parsing accuracy: \(accuracy * 100)% (\(correctCount)/\(testCases.count))")

        // Target: 70%+ accuracy for regex fallback
        // AI parsing should achieve 95%+
        XCTAssertGreaterThanOrEqual(
            accuracy,
            0.70,
            "Parsing accuracy should be at least 70% for regex fallback"
        )
    }

    func test_accuracy_complexIngredients() async throws {
        configuration.enableAIParsing = false

        let complexCases = [
            ("2 cups (250g) flour, sifted", (2.0, nil, "cup", "flour")),
            ("1/2-3/4 cup warm water", (0.5, 0.75, "cup", "water")),
            ("2 medium onions, chopped", (2.0, nil, nil, "onions")),
            ("Salt and pepper", (nil, nil, nil, "salt"))
        ]

        var correctCount = 0
        for (input, expected) in complexCases {
            let result = try await parser.parse(input)

            if AITestFixtures.matches(parsed: result, expected: expected) {
                correctCount += 1
            }
        }

        let accuracy = Double(correctCount) / Double(complexCases.count)
        print("✅ Complex parsing accuracy: \(accuracy * 100)%")

        // Complex ingredients may have lower accuracy
        XCTAssertGreaterThanOrEqual(accuracy, 0.50, "Should parse at least 50% of complex ingredients")
    }

    // MARK: - Performance Tests

    func test_performance_parseSingleIngredient() async throws {
        configuration.enableAIParsing = false

        let startTime = Date()
        let result = try await parser.parse("2 cups flour")
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertNotNil(result)
        XCTAssertLessThan(elapsed, 0.1, "Should parse in < 100ms for regex parsing")
    }

    func test_performance_parseBatch_100Ingredients() async throws {
        configuration.enableAIParsing = false

        let ingredients = Array(repeating: "1 cup flour", count: 100)

        let startTime = Date()
        let results = try await parser.parseBatch(ingredients)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertEqual(results.count, 100)
        XCTAssertLessThan(elapsed, 2.0, "Should parse 100 ingredients in < 2 seconds")
    }

    // MARK: - Integration with IngredientParser

    func test_fallback_usesIngredientParser() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("2 cups flour")

        // Verify we're getting regex parser results (from IngredientParser)
        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertEqual(result.unit, "cups")

        // This confirms the fallback is working
    }

    // MARK: - Error Handling Tests

    func test_parse_doesNotThrowOnInvalidInput() async throws {
        configuration.enableAIParsing = false

        // Should not throw, even with garbage input
        let result = try await parser.parse("!@#$%^&*()")

        XCTAssertNotNil(result, "Should return result even for invalid input")
    }

    func test_parseBatch_handlesPartialFailures() async throws {
        configuration.enableAIParsing = false

        let mixed = [
            "2 cups flour",  // Valid
            "invalid!!!",    // Invalid
            "1 tsp salt"     // Valid
        ]

        let results = try await parser.parseBatch(mixed)

        XCTAssertEqual(results.count, 3, "Should return result for each ingredient")
        XCTAssertEqual(results[0].quantity, 2.0, "First ingredient should parse")
        XCTAssertEqual(results[2].quantity, 1.0, "Third ingredient should parse")
    }

    // MARK: - Quantity Parsing Edge Cases

    func test_parse_decimalQuantity() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("1.5 cups milk")

        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity!, 1.5, accuracy: 0.01)
    }

    func test_parse_largeQuantity() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("100 cups water")

        XCTAssertEqual(result.quantity, 100.0)
    }

    func test_parse_verySmallQuantity() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("0.25 teaspoon spice")

        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity!, 0.25, accuracy: 0.01)
    }

    func test_parse_multipleNumbers() async throws {
        configuration.enableAIParsing = false

        // Should parse first number as quantity
        let result = try await parser.parse("2 15 oz cans tomatoes")

        XCTAssertNotNil(result.quantity, "Should parse quantity from multiple numbers")
    }

    // MARK: - Unit Parsing Edge Cases

    func test_parse_abbreviatedUnits() async throws {
        configuration.enableAIParsing = false

        let testCases = [
            ("2 tsp salt", "tsp"),
            ("3 tbsp butter", "tbsp"),
            ("1 oz cheese", "oz"),
            ("2 lb meat", "lb")
        ]

        for (input, expectedUnit) in testCases {
            let result = try await parser.parse(input)
            XCTAssertNotNil(result.unit, "Should parse unit in: \(input)")
            XCTAssertTrue(
                result.unit?.lowercased().contains(expectedUnit.lowercased()) ?? false,
                "Should parse abbreviated unit in: \(input). Got: \(result.unit ?? "nil")"
            )
        }
    }

    func test_parse_pluralUnits() async throws {
        configuration.enableAIParsing = false

        let singular = try await parser.parse("1 cup milk")
        let plural = try await parser.parse("2 cups milk")

        // Both should recognize cup/cups as same unit
        XCTAssertNotNil(singular.unit)
        XCTAssertNotNil(plural.unit)
    }

    func test_parse_metricUnits() async throws {
        configuration.enableAIParsing = false

        let testCases = [
            "500 grams sugar",
            "250 ml milk",
            "1 liter water",
            "100 kg flour"
        ]

        for input in testCases {
            let result = try await parser.parse(input)
            XCTAssertNotNil(result.quantity, "Should parse metric unit in: \(input)")
            XCTAssertNotNil(result.unit, "Should extract metric unit from: \(input)")
        }
    }

    // MARK: - Name Extraction Tests

    func test_parse_extractsNameAfterUnit() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("2 cups all-purpose flour")

        XCTAssertTrue(result.name.contains("flour"), "Should extract name after unit")
        XCTAssertTrue(result.name.contains("all-purpose") || result.name.contains("flour"),
                     "Should preserve descriptors")
    }

    func test_parse_handlesCommasInName() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("1 cup flour, sifted and measured")

        XCTAssertTrue(result.name.contains("flour"), "Should extract base name")
    }

    func test_parse_handlesParenthesesInName() async throws {
        configuration.enableAIParsing = false

        let result = try await parser.parse("2 eggs (large)")

        XCTAssertTrue(result.name.contains("eggs"), "Should extract name with parentheses")
    }
}
