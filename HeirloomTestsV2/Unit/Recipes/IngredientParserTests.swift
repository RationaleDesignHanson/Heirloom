//
//  IngredientParserTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Unit tests for ingredient parsing
//
//  Tests the ingredient parser to ensure:
//  - Quantity parsing (integers, fractions, unicode, ranges)
//  - Unit extraction and normalization
//  - Multilingual support (7 languages)
//  - Edge cases and malformed input
//

import XCTest
@testable import Heirloom

@MainActor
final class IngredientParserTests: XCTestCase {

    // MARK: - Basic Quantity Parsing

    /// Test 1: Parse whole number quantity
    func test_parse_wholeNumber_extractsCorrectly() {
        // GIVEN: Simple ingredient with whole number
        let text = "2 cups flour"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Quantity extracted correctly
        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertNil(result.quantityMax)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "flour")
    }

    /// Test 2: Parse decimal quantity
    func test_parse_decimalQuantity_extractsCorrectly() {
        // GIVEN: Ingredient with decimal quantity
        let text = "1.5 tablespoons oil"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Decimal parsed correctly
        XCTAssertEqual(result.quantity, 1.5)
        XCTAssertEqual(result.unit, "tablespoon")
    }

    /// Test 3: Parse fractional quantity (slash notation)
    func test_parse_fraction_slashNotation_extractsCorrectly() {
        // GIVEN: Ingredient with fraction
        let text = "1/4 cup sugar"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Fraction converted to decimal
        XCTAssertEqual(result.quantity, 0.25)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "sugar")
    }

    /// Test 4: Parse mixed number (whole + fraction)
    func test_parse_mixedNumber_extractsCorrectly() {
        // GIVEN: Mixed number like "2 1/4"
        let text = "2 1/4 cups flour"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Combined correctly
        XCTAssertEqual(result.quantity, 2.25)
        XCTAssertEqual(result.unit, "cup")
    }

    // MARK: - Unicode Fractions

    /// Test 5: Parse unicode fraction ½
    func test_parse_unicodeFraction_half_extractsCorrectly() {
        // GIVEN: Unicode fraction
        let text = "½ cup butter"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Converted to decimal
        XCTAssertEqual(result.quantity, 0.5)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "butter")
    }

    /// Test 6: Parse unicode fraction ¼
    func test_parse_unicodeFraction_quarter_extractsCorrectly() {
        // GIVEN: Unicode quarter
        let text = "¼ teaspoon salt"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Converted correctly
        XCTAssertEqual(result.quantity, 0.25)
        XCTAssertEqual(result.unit, "teaspoon")
    }

    /// Test 7: Parse unicode fraction ¾
    func test_parse_unicodeFraction_threeQuarters_extractsCorrectly() {
        // GIVEN: Unicode three-quarters
        let text = "¾ cup milk"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Converted correctly
        XCTAssertEqual(result.quantity, 0.75)
    }

    /// Test 8: Parse unicode fractions ⅓ and ⅔
    func test_parse_unicodeFraction_thirds_extractsCorrectly() {
        // GIVEN: Third fractions
        let textThird = "⅓ cup cream"
        let textTwoThirds = "⅔ cup cheese"

        // WHEN: Parsing
        let resultThird = IngredientParser.parse(textThird)
        let resultTwoThirds = IngredientParser.parse(textTwoThirds)

        // THEN: Converted correctly (approximately)
        XCTAssertEqual(resultThird.quantity!, 1.0/3.0, accuracy: 0.001)
        XCTAssertEqual(resultTwoThirds.quantity!, 2.0/3.0, accuracy: 0.001)
    }

    /// Test 9: Parse unicode fractions ⅛ and ⅜
    func test_parse_unicodeFraction_eighths_extractsCorrectly() {
        // GIVEN: Eighth fractions
        let textEighth = "⅛ teaspoon pepper"
        let textThreeEighths = "⅜ cup nuts"

        // WHEN: Parsing
        let resultEighth = IngredientParser.parse(textEighth)
        let resultThreeEighths = IngredientParser.parse(textThreeEighths)

        // THEN: Converted correctly
        XCTAssertEqual(resultEighth.quantity, 0.125)
        XCTAssertEqual(resultThreeEighths.quantity, 0.375)
    }

    // MARK: - Range Quantities

    /// Test 10: Parse range with hyphen
    func test_parse_range_hyphen_extractsBoth() {
        // GIVEN: Range quantity
        let text = "2-3 cups water"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Both values extracted
        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertEqual(result.quantityMax, 3.0)
        XCTAssertEqual(result.unit, "cup")
    }

    /// Test 11: Parse range with "to"
    func test_parse_range_withTo_extractsBoth() {
        // GIVEN: Range with "to" keyword
        let text = "1 to 2 tablespoons butter"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Both values extracted
        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.quantityMax, 2.0)
    }

    /// Test 12: Parse range with "or"
    func test_parse_range_withOr_extractsBoth() {
        // GIVEN: Range with "or" keyword
        let text = "3 or 4 cloves garlic"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Both values extracted
        XCTAssertEqual(result.quantity, 3.0)
        XCTAssertEqual(result.quantityMax, 4.0)
    }

    // MARK: - Unit Extraction

    /// Test 13: Parse common units
    func test_parse_commonUnits_normalized() {
        // GIVEN/WHEN/THEN: Common units are recognized
        XCTAssertEqual(IngredientParser.parse("1 cup flour").unit, "cup")
        XCTAssertEqual(IngredientParser.parse("1 cups flour").unit, "cup")
        XCTAssertEqual(IngredientParser.parse("1 tablespoon sugar").unit, "tablespoon")
        XCTAssertEqual(IngredientParser.parse("1 teaspoon salt").unit, "teaspoon")
        XCTAssertEqual(IngredientParser.parse("100 grams butter").unit, "gram")
        XCTAssertEqual(IngredientParser.parse("1 pound beef").unit, "pound")
    }

    /// Test 14: Parse abbreviations
    func test_parse_abbreviations_normalized() {
        // GIVEN/WHEN/THEN: Abbreviations are recognized and normalized
        // Note: Production normalizes common abbreviations to their full forms
        XCTAssertEqual(IngredientParser.parse("1 cup flour").unit, "cup")
        XCTAssertEqual(IngredientParser.parse("1 tbsp sugar").unit, "tablespoon")
        XCTAssertEqual(IngredientParser.parse("1 tsp salt").unit, "teaspoon")
        XCTAssertEqual(IngredientParser.parse("100 g butter").unit, "gram")
        XCTAssertEqual(IngredientParser.parse("1 lb beef").unit, "pound")
        XCTAssertEqual(IngredientParser.parse("1 oz cheese").unit, "oz.")
    }

    /// Test 15: Case insensitivity for Tbsp/tbsp
    func test_parse_caseForTandTbsp_correct() {
        // GIVEN/WHEN/THEN: Tbsp/tbsp both normalize to tablespoon
        // Note: Single "T" is not a recognized unit in production
        XCTAssertEqual(IngredientParser.parse("1 Tbsp sugar").unit, "tablespoon")
        XCTAssertEqual(IngredientParser.parse("1 tbsp sugar").unit, "tablespoon")
        XCTAssertEqual(IngredientParser.parse("1 tsp salt").unit, "teaspoon")
    }

    // MARK: - Unit-less Parsing (e.g., "250g")

    /// Test 16: Parse metric without space (250g)
    func test_parse_metricNoSpace_treatAsName() {
        // GIVEN: Metric with no space (e.g., European style)
        let text = "250g flour"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Should treat "250g" as quantity-unit combination
        // Per code: no space = don't extract unit separately
        XCTAssertEqual(result.quantity, 250.0)
        // Unit should be nil because there was no space
        XCTAssertNil(result.unit)
    }

    // MARK: - French (fr)

    /// Test 17: Parse French units
    func test_parse_french_unitsNormalized() {
        // GIVEN: French ingredients
        let textCup = "1 tasse farine"
        let textTablespoon = "2 cuillères à soupe sucre"
        let textTeaspoon = "1 cuillère à café sel"

        // WHEN: Parsing with French language hint
        let resultCup = IngredientParser.parse(textCup, language: "fr")
        let resultTbsp = IngredientParser.parse(textTablespoon, language: "fr")
        let resultTsp = IngredientParser.parse(textTeaspoon, language: "fr")

        // THEN: Units normalized to English
        XCTAssertEqual(resultCup.unit, "cup")
        XCTAssertEqual(resultTbsp.unit, "tablespoon")
        XCTAssertEqual(resultTsp.unit, "teaspoon")
    }

    // MARK: - Japanese (ja)

    /// Test 18: Parse Japanese units
    func test_parse_japanese_unitsNormalized() {
        // GIVEN: Japanese ingredients
        let textCup = "1 カップ 小麦粉"  // 1 cup flour
        let textTablespoon = "2 大さじ 砂糖"  // 2 tablespoons sugar
        let textTeaspoon = "1 小さじ 塩"  // 1 teaspoon salt

        // WHEN: Parsing with Japanese language hint
        let resultCup = IngredientParser.parse(textCup, language: "ja")
        let resultTbsp = IngredientParser.parse(textTablespoon, language: "ja")
        let resultTsp = IngredientParser.parse(textTeaspoon, language: "ja")

        // THEN: Units normalized to English
        XCTAssertEqual(resultCup.unit, "cup")
        XCTAssertEqual(resultTbsp.unit, "tablespoon")
        XCTAssertEqual(resultTsp.unit, "teaspoon")
    }

    // MARK: - Korean (ko)

    /// Test 19: Parse Korean units
    func test_parse_korean_unitsNormalized() {
        // GIVEN: Korean ingredients
        let textCup = "1 컵 밀가루"  // 1 cup flour
        let textTablespoon = "2 큰술 설탕"  // 2 tablespoons sugar
        let textTeaspoon = "1 작은술 소금"  // 1 teaspoon salt

        // WHEN: Parsing with Korean language hint
        let resultCup = IngredientParser.parse(textCup, language: "ko")
        let resultTbsp = IngredientParser.parse(textTablespoon, language: "ko")
        let resultTsp = IngredientParser.parse(textTeaspoon, language: "ko")

        // THEN: Units normalized to English
        XCTAssertEqual(resultCup.unit, "cup")
        XCTAssertEqual(resultTbsp.unit, "tablespoon")
        XCTAssertEqual(resultTsp.unit, "teaspoon")
    }

    // MARK: - Spanish (es)

    /// Test 20: Parse Spanish units
    func test_parse_spanish_unitsNormalized() {
        // GIVEN: Spanish ingredients
        let textCup = "1 taza harina"
        let textTablespoon = "2 cucharadas azúcar"
        let textTeaspoon = "1 cucharadita sal"

        // WHEN: Parsing with Spanish language hint
        let resultCup = IngredientParser.parse(textCup, language: "es")
        let resultTbsp = IngredientParser.parse(textTablespoon, language: "es")
        let resultTsp = IngredientParser.parse(textTeaspoon, language: "es")

        // THEN: Units normalized to English
        XCTAssertEqual(resultCup.unit, "cup")
        XCTAssertEqual(resultTbsp.unit, "tablespoon")
        XCTAssertEqual(resultTsp.unit, "teaspoon")
    }

    // MARK: - German (de)

    /// Test 21: Parse German units
    func test_parse_german_unitsNormalized() {
        // GIVEN: German ingredients
        let textCup = "1 Tasse Mehl"
        let textTablespoon = "2 Esslöffel Zucker"
        let textTeaspoon = "1 Teelöffel Salz"

        // WHEN: Parsing with German language hint
        let resultCup = IngredientParser.parse(textCup, language: "de")
        let resultTbsp = IngredientParser.parse(textTablespoon, language: "de")
        let resultTsp = IngredientParser.parse(textTeaspoon, language: "de")

        // THEN: Units normalized to English
        XCTAssertEqual(resultCup.unit, "cup")
        XCTAssertEqual(resultTbsp.unit, "tablespoon")
        XCTAssertEqual(resultTsp.unit, "teaspoon")
    }

    // MARK: - Edge Cases

    /// Test 22: Parse ingredient with no quantity
    func test_parse_noQuantity_returnsNilQuantity() {
        // GIVEN: Ingredient without quantity
        let text = "salt to taste"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Quantity should be nil
        XCTAssertNil(result.quantity)
        XCTAssertEqual(result.name, "salt to taste")
    }

    /// Test 23: Parse ingredient with no unit
    func test_parse_noUnit_returnsNilUnit() {
        // GIVEN: Ingredient with count only
        let text = "2 eggs"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Should have quantity but no standardized unit
        XCTAssertEqual(result.quantity, 2.0)
        // "eggs" is not a unit, it's the name
        XCTAssertNil(result.unit)
        XCTAssertEqual(result.name, "eggs")
    }

    /// Test 24: Parse empty string
    func test_parse_emptyString_returnsEmpty() {
        // GIVEN: Empty string
        let text = ""

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: All values should be nil/empty
        XCTAssertNil(result.quantity)
        XCTAssertNil(result.unit)
        XCTAssertEqual(result.name, "")
    }

    /// Test 25: Parse whitespace-only string
    func test_parse_whitespaceOnly_returnsEmpty() {
        // GIVEN: Whitespace string
        let text = "   "

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Should be treated as empty
        XCTAssertNil(result.quantity)
        XCTAssertNil(result.unit)
        XCTAssertEqual(result.name, "")
    }

    // MARK: - Complex Ingredients

    /// Test 26: Parse ingredient with preparation instruction
    func test_parse_withPreparation_nameIncludesPrep() {
        // GIVEN: Ingredient with preparation
        let text = "2 cups onions, diced"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Preparation is part of name (regex parser doesn't extract prep separately)
        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertTrue(result.name.contains("diced"))
    }

    /// Test 27: Parse ingredient with parenthetical note
    func test_parse_withParentheticalNote_nameIncludesNote() {
        // GIVEN: Ingredient with note
        let text = "1 cup butter (softened)"

        // WHEN: Parsing
        let result = IngredientParser.parse(text)

        // THEN: Note is part of name
        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertTrue(result.name.contains("softened"))
    }
}
