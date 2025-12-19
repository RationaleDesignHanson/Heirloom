import XCTest
@testable import Heirloom

final class IngredientParserTests: XCTestCase {

    // MARK: - Whole Number Tests

    func test_parse_wholeNumber() {
        let result = IngredientParser.parse("2 cups flour")

        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertNil(result.quantityMax)
        XCTAssertEqual(result.unit, "cups")
        XCTAssertEqual(result.name, "flour")
    }

    func test_parse_wholeNumberWithAbbreviatedUnit() {
        let result = IngredientParser.parse("3 tbsp sugar")

        XCTAssertEqual(result.quantity, 3.0)
        XCTAssertEqual(result.unit, "tbsp")
        XCTAssertEqual(result.name, "sugar")
    }

    // MARK: - Decimal Tests

    func test_parse_decimal() {
        let result = IngredientParser.parse("1.5 tsp vanilla extract")

        XCTAssertEqual(result.quantity, 1.5)
        XCTAssertEqual(result.unit, "tsp")
        XCTAssertEqual(result.name, "vanilla extract")
    }

    func test_parse_decimalWithoutUnit() {
        let result = IngredientParser.parse("2.5 large eggs")

        XCTAssertEqual(result.quantity, 2.5)
        XCTAssertEqual(result.unit, "large")
        XCTAssertEqual(result.name, "eggs")
    }

    // MARK: - Fraction Tests

    func test_parse_simpleFraction() {
        let result = IngredientParser.parse("1/4 cup sugar")

        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity!, 0.25, accuracy: 0.01)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "sugar")
    }

    func test_parse_halfFraction() {
        let result = IngredientParser.parse("1/2 tsp salt")

        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity!, 0.5, accuracy: 0.01)
        XCTAssertEqual(result.unit, "tsp")
        XCTAssertEqual(result.name, "salt")
    }

    func test_parse_thirdFraction() {
        let result = IngredientParser.parse("1/3 cup milk")

        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity!, 0.333, accuracy: 0.01)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "milk")
    }

    // MARK: - Mixed Fraction Tests

    func test_parse_mixedFraction() {
        let result = IngredientParser.parse("2 1/4 cups flour")

        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity!, 2.25, accuracy: 0.01)
        XCTAssertEqual(result.unit, "cups")
        XCTAssertEqual(result.name, "flour")
    }

    func test_parse_mixedFractionOneAndHalf() {
        let result = IngredientParser.parse("1 1/2 cups water")

        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity!, 1.5, accuracy: 0.01)
        XCTAssertEqual(result.unit, "cups")
        XCTAssertEqual(result.name, "water")
    }

    func test_parse_mixedFractionThreeAndThreeQuarters() {
        let result = IngredientParser.parse("3 3/4 oz chocolate chips")

        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity!, 3.75, accuracy: 0.01)
        XCTAssertEqual(result.unit, "oz")
        XCTAssertEqual(result.name, "chocolate chips")
    }

    // MARK: - Unicode Fraction Tests

    func test_parse_unicodeFraction() {
        let result = IngredientParser.parse("½ cup milk")

        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity!, 0.5, accuracy: 0.01)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "milk")
    }

    // MARK: - Range Tests

    func test_parse_rangeWithDash() {
        let result = IngredientParser.parse("1-2 cups flour")

        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.quantityMax, 2.0)
        XCTAssertEqual(result.unit, "cups")
        XCTAssertEqual(result.name, "flour")
    }

    func test_parse_rangeWithTo() {
        let result = IngredientParser.parse("2 to 3 tbsp oil")

        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertEqual(result.quantityMax, 3.0)
        XCTAssertEqual(result.unit, "tbsp")
        XCTAssertEqual(result.name, "oil")
    }

    func test_parse_rangeWithFractions() {
        let result = IngredientParser.parse("1/4-1/2 tsp pepper")

        XCTAssertNotNil(result.quantity)
        XCTAssertNotNil(result.quantityMax)
        XCTAssertEqual(result.quantity!, 0.25, accuracy: 0.01)
        XCTAssertEqual(result.quantityMax!, 0.5, accuracy: 0.01)
        XCTAssertEqual(result.unit, "tsp")
        XCTAssertEqual(result.name, "pepper")
    }

    // MARK: - No Quantity Tests

    func test_parse_noQuantity() {
        let result = IngredientParser.parse("Salt to taste")

        XCTAssertNil(result.quantity)
        XCTAssertNil(result.unit)
        XCTAssertEqual(result.name, "Salt to taste")
    }

    func test_parse_noQuantityWithModifier() {
        let result = IngredientParser.parse("Pepper, freshly ground")

        XCTAssertNil(result.quantity)
        XCTAssertEqual(result.name, "Pepper, freshly ground")
    }

    // MARK: - Size Modifier Tests

    func test_parse_sizeModifier() {
        let result = IngredientParser.parse("2 large eggs")

        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertEqual(result.unit, "large")
        XCTAssertEqual(result.name, "eggs")
    }

    func test_parse_mediumSizeModifier() {
        let result = IngredientParser.parse("3 medium apples")

        XCTAssertEqual(result.quantity, 3.0)
        XCTAssertEqual(result.unit, "medium")
        XCTAssertEqual(result.name, "apples")
    }

    // MARK: - Complex Name Tests

    func test_parse_ingredientWithComma() {
        let result = IngredientParser.parse("2 cups all-purpose flour, sifted")

        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertEqual(result.unit, "cups")
        XCTAssertTrue(result.name.contains("all-purpose flour"))
    }

    func test_parse_ingredientWithParentheses() {
        let result = IngredientParser.parse("1 can (14 oz) crushed tomatoes")

        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.unit, "can")
        XCTAssertTrue(result.name.contains("crushed tomatoes"))
    }

    // MARK: - Edge Cases

    func test_parse_leadingWhitespace() {
        let result = IngredientParser.parse("   2 cups flour   ")

        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertEqual(result.unit, "cups")
        XCTAssertEqual(result.name, "flour")
    }

    func test_parse_multipleNumbers() {
        let result = IngredientParser.parse("2 14-ounce cans tomatoes")

        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertTrue(result.name.contains("14-ounce"))
    }

    func test_parse_emptyString() {
        let result = IngredientParser.parse("")

        XCTAssertNil(result.quantity)
        XCTAssertNil(result.unit)
        XCTAssertEqual(result.name, "")
    }

    // MARK: - Unit Abbreviation Tests

    func test_parse_teaspoonAbbreviations() throws {
        let variations = ["tsp", "tsp.", "t", "teaspoon", "teaspoons"]

        for abbr in variations {
            let result = IngredientParser.parse("1 \(abbr) salt")
            print("DEBUG: Testing abbr '\(abbr)' -> qty=\(String(describing: result.quantity)), unit=\(String(describing: result.unit)), name='\(result.name)'")
            XCTAssertEqual(result.quantity, 1.0, "Failed for '\(abbr)'")
            XCTAssertNotNil(result.unit, "Failed for '\(abbr)'")
            XCTAssertEqual(result.name, "salt", "Failed for '\(abbr)'")
        }
    }

    func test_parse_tablespoonAbbreviations() throws {
        let variations = ["tbsp", "tbsp.", "T", "tablespoon", "tablespoons"]

        for abbr in variations {
            let result = IngredientParser.parse("2 \(abbr) butter")
            XCTAssertEqual(result.quantity, 2.0)
            XCTAssertNotNil(result.unit)
            XCTAssertEqual(result.name, "butter")
        }
    }

    func test_parse_cupAbbreviations() throws {
        let variations = ["cup", "cups", "c", "c."]

        for abbr in variations {
            let result = IngredientParser.parse("1 \(abbr) sugar")
            XCTAssertEqual(result.quantity, 1.0)
            XCTAssertNotNil(result.unit)
            XCTAssertEqual(result.name, "sugar")
        }
    }
}
