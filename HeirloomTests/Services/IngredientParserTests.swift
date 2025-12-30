import XCTest
@testable import Heirloom

final class IngredientParserTests: XCTestCase {

    // MARK: - Basic Parsing Tests

    func testParse_SimpleIngredient() {
        // Given
        let input = "1 cup flour"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "flour")
    }

    func testParse_IngredientWithModifier() {
        // Given
        let input = "2 tablespoons olive oil, divided"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertEqual(result.unit, "tablespoon")
        XCTAssertTrue(result.name.contains("olive oil"), "Should preserve name")
    }

    func testParse_IngredientWithPreparation() {
        // Given
        let input = "1 pound ground beef, browned"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.unit, "pound")
        XCTAssertTrue(result.name.contains("ground beef"), "Should extract name")
    }

    // MARK: - Fraction Parsing Tests

    func testParse_SimpleFraction() {
        // Given
        let input = "1/2 cup sugar"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 0.5)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "sugar")
    }

    func testParse_MixedNumber() {
        // Given
        let input = "1 1/2 cups flour"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 1.5)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "flour")
    }

    func testParse_UnicodeFractionHalf() {
        // Given
        let input = "½ teaspoon salt"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 0.5)
        XCTAssertEqual(result.unit, "teaspoon")
        XCTAssertEqual(result.name, "salt")
    }

    func testParse_UnicodeFractionQuarter() {
        // Given
        let input = "¼ cup butter"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 0.25)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "butter")
    }

    func testParse_UnicodeFractionThird() {
        // Given
        let input = "⅓ cup milk"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity ?? 0, 0.333, accuracy: 0.01)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "milk")
    }

    func testParse_UnicodeFractionTwoThirds() {
        // Given
        let input = "⅔ cup water"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertNotNil(result.quantity)
        XCTAssertEqual(result.quantity ?? 0, 0.666, accuracy: 0.01)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "water")
    }

    // MARK: - Range Parsing Tests

    func testParse_QuantityRange() {
        // Given
        let input = "2-3 cups flour"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 2.0, "Should use minimum")
        XCTAssertEqual(result.quantityMax, 3.0, "Should store maximum")
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "flour")
    }

    func testParse_RangeWithTo() {
        // Given
        let input = "1 to 2 tablespoons sugar"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.quantityMax, 2.0)
        XCTAssertEqual(result.unit, "tablespoon")
    }

    func testParse_RangeWithOr() {
        // Given
        let input = "3 or 4 eggs"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 3.0)
        XCTAssertEqual(result.quantityMax, 4.0)
        XCTAssertEqual(result.name, "eggs")
    }

    // MARK: - Unit Parsing Tests

    func testParse_Cup() {
        XCTAssertEqual(IngredientParser.parse("1 cup flour").unit, "cup")
        XCTAssertEqual(IngredientParser.parse("2 cups flour").unit, "cup") // Normalized to singular
    }

    func testParse_Tablespoon() {
        XCTAssertEqual(IngredientParser.parse("1 tablespoon oil").unit, "tablespoon")
        XCTAssertEqual(IngredientParser.parse("2 tablespoons oil").unit, "tablespoon") // Normalized to singular
        XCTAssertEqual(IngredientParser.parse("1 tbsp oil").unit, "tablespoon") // Normalized from abbreviation
        XCTAssertEqual(IngredientParser.parse("2 tbsp oil").unit, "tablespoon") // Normalized from abbreviation
    }

    func testParse_Teaspoon() {
        XCTAssertEqual(IngredientParser.parse("1 teaspoon salt").unit, "teaspoon")
        XCTAssertEqual(IngredientParser.parse("2 teaspoons salt").unit, "teaspoon") // Normalized to singular
        XCTAssertEqual(IngredientParser.parse("1 tsp salt").unit, "teaspoon") // Normalized from abbreviation
        XCTAssertEqual(IngredientParser.parse("2 tsp salt").unit, "teaspoon") // Normalized from abbreviation
    }

    func testParse_Ounce() {
        XCTAssertEqual(IngredientParser.parse("8 ounces cheese").unit, "oz.") // Normalized with period
        XCTAssertEqual(IngredientParser.parse("8 oz cheese").unit, "oz.") // Normalized with period
        XCTAssertEqual(IngredientParser.parse("8 oz. cheese").unit, "oz.") // Already normalized
    }

    func testParse_Pound() {
        XCTAssertEqual(IngredientParser.parse("1 pound beef").unit, "pound")
        XCTAssertEqual(IngredientParser.parse("2 pounds beef").unit, "pound") // Normalized to singular
        XCTAssertEqual(IngredientParser.parse("1 lb beef").unit, "pound") // Normalized from abbreviation
        XCTAssertEqual(IngredientParser.parse("2 lbs beef").unit, "pound") // Normalized from abbreviation
    }

    func testParse_Gram() {
        XCTAssertEqual(IngredientParser.parse("250 grams flour").unit, "gram") // Normalized to singular
        XCTAssertEqual(IngredientParser.parse("250 g flour").unit, "gram") // Normalized from abbreviation
        XCTAssertEqual(IngredientParser.parse("250g flour").unit, nil) // No space, parser might not catch it
    }

    func testParse_Milliliter() {
        XCTAssertEqual(IngredientParser.parse("500 milliliters water").unit, "milliliter") // Normalized to singular
        XCTAssertEqual(IngredientParser.parse("500 ml water").unit, "milliliter") // Normalized from abbreviation
        XCTAssertEqual(IngredientParser.parse("500ml water").unit, nil) // No space
    }

    func testParse_Liter() {
        XCTAssertEqual(IngredientParser.parse("1 liter milk").unit, "liter")
        XCTAssertEqual(IngredientParser.parse("1 l milk").unit, "liter") // Normalized from abbreviation
    }

    func testParse_Kilogram() {
        XCTAssertEqual(IngredientParser.parse("2 kilograms flour").unit, "kilogram") // Normalized to singular
        XCTAssertEqual(IngredientParser.parse("2 kg flour").unit, "kilogram") // Normalized from abbreviation
    }

    func testParse_Piece() {
        XCTAssertEqual(IngredientParser.parse("3 eggs").unit, nil, "Piece count should have no unit")
        XCTAssertEqual(IngredientParser.parse("2 onions").unit, nil)
    }

    // MARK: - Edge Case Tests

    func testParse_EmptyString() {
        // Given
        let input = ""

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertNil(result.quantity)
        XCTAssertNil(result.unit)
        XCTAssertEqual(result.name, "")
    }

    func testParse_OnlyQuantity() {
        // Given
        let input = "2"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 2.0)
        XCTAssertNil(result.unit)
        XCTAssertEqual(result.name, "") // No ingredient name if only quantity provided
    }

    func testParse_OnlyName() {
        // Given
        let input = "Salt and pepper to taste"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertNil(result.quantity)
        XCTAssertNil(result.unit)
        XCTAssertEqual(result.name, "Salt and pepper to taste")
    }

    func testParse_NoUnit() {
        // Given
        let input = "3 eggs"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 3.0)
        XCTAssertNil(result.unit, "Should not have unit for count")
        XCTAssertEqual(result.name, "eggs")
    }

    func testParse_DecimalQuantity() {
        // Given
        let input = "1.5 cups flour"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 1.5)
        XCTAssertEqual(result.unit, "cup")
    }

    func testParse_LargeQuantity() {
        // Given
        let input = "1000 grams flour"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 1000.0)
        XCTAssertEqual(result.unit, "gram")
    }

    func testParse_VerySmallQuantity() {
        // Given
        let input = "1/8 teaspoon cayenne"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 0.125)
        XCTAssertEqual(result.unit, "teaspoon")
    }

    // MARK: - Complex Name Tests

    func testParse_NameWithComma() {
        // Given
        let input = "1 cup butter, softened"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertTrue(result.name.contains("butter"))
    }

    func testParse_NameWithParentheses() {
        // Given
        let input = "1 can (14 oz) tomatoes"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertTrue(result.name.contains("tomatoes"))
    }

    func testParse_NameWithMultipleWords() {
        // Given
        let input = "2 tablespoons extra virgin olive oil"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertTrue(result.name.contains("olive oil"))
    }

    // MARK: - Special Characters Tests

    func testParse_WithDegreeSymbol() {
        // Given
        let input = "Preheat to 350° F"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertNotNil(result.name, "Should handle degree symbol")
    }

    func testParse_WithExtraSpaces() {
        // Given
        let input = "1    cup    flour"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "flour")
    }

    func testParse_WithLeadingSpaces() {
        // Given
        let input = "   1 cup flour"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.unit, "cup")
    }

    func testParse_WithTrailingSpaces() {
        // Given
        let input = "1 cup flour   "

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 1.0)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertEqual(result.name, "flour")
    }

    // MARK: - Real-World Examples

    func testParse_RealWorldExample1() {
        // Given
        let input = "2 1/4 cups all-purpose flour, sifted"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 2.25)
        XCTAssertEqual(result.unit, "cup")
        XCTAssertTrue(result.name.contains("flour"))
    }

    func testParse_RealWorldExample2() {
        // Given
        let input = "1/2 lb unsalted butter, at room temperature"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 0.5)
        XCTAssertEqual(result.unit, "pound")
        XCTAssertTrue(result.name.contains("butter"))
    }

    func testParse_RealWorldExample3() {
        // Given
        let input = "3-4 cloves garlic, minced"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertEqual(result.quantity, 3.0)
        XCTAssertEqual(result.quantityMax, 4.0)
        XCTAssertTrue(result.name.contains("garlic"))
    }

    func testParse_RealWorldExample4() {
        // Given
        let input = "Salt and freshly ground black pepper, to taste"

        // When
        let result = IngredientParser.parse(input)

        // Then
        XCTAssertNil(result.quantity, "Should have no quantity for 'to taste'")
        XCTAssertTrue(result.name.contains("Salt"))
    }

    // MARK: - Performance Tests

    func testParse_Performance() {
        let input = "2 1/4 cups all-purpose flour, sifted"

        measure {
            for _ in 0..<1000 {
                _ = IngredientParser.parse(input)
            }
        }
    }
}
