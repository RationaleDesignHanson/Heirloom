import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class IngredientValidationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.Ingredient.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - Display Text Tests

    func testIngredient_DisplayText_FullFormat() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "2 cups all-purpose flour",
            name: "all-purpose flour",
            quantity: 2.0,
            unit: "cups"
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertEqual(displayText, "2 cups all-purpose flour")
    }

    func testIngredient_DisplayText_WithPreparation() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1 lb carrots, peeled and diced",
            name: "carrots",
            quantity: 1.0,
            unit: "lb"
        )
        ingredient.preparation = "peeled and diced"

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertEqual(displayText, "1 lb carrots (peeled and diced)")
    }

    func testIngredient_DisplayText_WithOptional() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1 pinch salt (optional)",
            name: "salt",
            quantity: 1.0,
            unit: "pinch"
        )
        ingredient.isOptional = true

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.contains("(optional)"))
    }

    func testIngredient_DisplayText_WithQuantityRange() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1-2 cups sugar",
            name: "sugar",
            quantity: 1.0,
            unit: "cups"
        )
        ingredient.quantityMax = 2.0

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.contains("1"))
        XCTAssertTrue(displayText.contains("2"))
    }

    func testIngredient_DisplayText_FallbackToOriginalText() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "Some unparsed ingredient",
            name: ""
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertEqual(displayText, "Some unparsed ingredient")
    }

    // MARK: - Quantity Formatting Tests (Imperial - Fractions)

    func testIngredient_FormatQuantity_WholeNumber() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "2 cups flour",
            name: "flour",
            quantity: 2.0,
            unit: "cups"
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.starts(with: "2 "))
    }

    func testIngredient_FormatQuantity_Quarter() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1/4 cup sugar",
            name: "sugar",
            quantity: 0.25,
            unit: "cup"
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.contains("¼"))
    }

    func testIngredient_FormatQuantity_Half() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1/2 cup milk",
            name: "milk",
            quantity: 0.5,
            unit: "cup"
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.contains("½"))
    }

    func testIngredient_FormatQuantity_ThreeQuarters() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "3/4 cup butter",
            name: "butter",
            quantity: 0.75,
            unit: "cup"
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.contains("¾"))
    }

    func testIngredient_FormatQuantity_MixedNumber() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1 1/2 cups water",
            name: "water",
            quantity: 1.5,
            unit: "cups"
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.contains("1") && displayText.contains("½"))
    }

    func testIngredient_FormatQuantity_Third() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1/3 cup oil",
            name: "oil",
            quantity: 0.333,
            unit: "cup"
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.contains("⅓"))
    }

    // MARK: - Quantity Formatting Tests (Metric - Decimals)

    func testIngredient_FormatQuantity_Metric_WholeGrams() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "250g flour",
            name: "flour",
            quantity: 250.0,
            unit: "g"
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.starts(with: "250 "))
    }

    func testIngredient_FormatQuantity_Metric_DecimalGrams() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "125.5g sugar",
            name: "sugar",
            quantity: 125.5,
            unit: "g"
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.contains("125.5"))
    }

    func testIngredient_FormatQuantity_Metric_Milliliters() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "500ml water",
            name: "water",
            quantity: 500.0,
            unit: "ml"
        )

        // Act
        let displayText = ingredient.displayText

        // Assert
        XCTAssertTrue(displayText.starts(with: "500 "))
    }

    // MARK: - GroceryCategory Auto-Categorization Tests

    func testGroceryCategory_Categorize_Produce() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.categorize("apple"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("tomato"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("onion"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("carrot"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("lettuce"), .produce)
    }

    func testGroceryCategory_Categorize_Dairy() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.categorize("milk"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("cheese"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("butter"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("cream"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("egg"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("yogurt"), .dairy)
    }

    func testGroceryCategory_Categorize_Meat() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.categorize("chicken"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("beef"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("pork"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("fish"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("salmon"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("bacon"), .meat)
    }

    func testGroceryCategory_Categorize_Bakery() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.categorize("bread"), .bakery)
        XCTAssertEqual(GroceryCategory.categorize("roll"), .bakery)
        XCTAssertEqual(GroceryCategory.categorize("bun"), .bakery)
        XCTAssertEqual(GroceryCategory.categorize("tortilla"), .bakery)
    }

    func testGroceryCategory_Categorize_Pantry() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.categorize("flour"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("sugar"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("rice"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("pasta"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("oil"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("honey"), .pantry)
    }

    func testGroceryCategory_Categorize_Spices() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.categorize("salt"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("pepper"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("cumin"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("cinnamon"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("vanilla extract"), .spices)
    }

    func testGroceryCategory_Categorize_Condiments() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.categorize("ketchup"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("mustard"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("mayonnaise"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("soy sauce"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("salad dressing"), .condiments)
    }

    func testGroceryCategory_Categorize_Beverages() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.categorize("juice"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("coffee"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("tea"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("soda"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("water"), .beverages)
    }

    func testGroceryCategory_Categorize_Frozen() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.categorize("frozen peas"), .frozen)
        XCTAssertEqual(GroceryCategory.categorize("ice cream"), .frozen)
    }

    // MARK: - GroceryCategory Edge Cases

    func testGroceryCategory_Categorize_Eggplant_NotDairy() throws {
        // Act & Assert - "eggplant" should NOT be categorized as dairy
        XCTAssertNotEqual(GroceryCategory.categorize("eggplant"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("eggplant"), .other)
    }

    func testGroceryCategory_Categorize_OrangeJuice_Beverage() throws {
        // Act & Assert - "orange juice" should be beverage, not produce
        XCTAssertEqual(GroceryCategory.categorize("orange juice"), .beverages)
    }

    func testGroceryCategory_Categorize_TomatoSauce_Condiment() throws {
        // Act & Assert - "tomato sauce" should be condiment, not produce
        XCTAssertEqual(GroceryCategory.categorize("tomato sauce"), .condiments)
    }

    func testGroceryCategory_Categorize_BakingSoda_Pantry() throws {
        // Act & Assert - "baking soda" should be pantry, not beverage
        XCTAssertEqual(GroceryCategory.categorize("baking soda"), .pantry)
    }

    func testGroceryCategory_Categorize_AppleCiderVinegar_Pantry() throws {
        // Act & Assert - "apple cider vinegar" should be pantry, not produce
        XCTAssertEqual(GroceryCategory.categorize("apple cider vinegar"), .pantry)
    }

    func testGroceryCategory_Categorize_FlourTortillas_Bakery() throws {
        // Act & Assert - "flour tortillas" should be bakery, not pantry
        XCTAssertEqual(GroceryCategory.categorize("flour tortillas"), .bakery)
    }

    func testGroceryCategory_Categorize_Steak_NotBeverage() throws {
        // Act & Assert - "steak" contains "tea" but should be meat, not beverage
        // Tests space-sensitive beverage check ("steak" vs " tea")
        XCTAssertEqual(GroceryCategory.categorize("steak"), .meat)
    }

    // MARK: - GroceryCategory Sort Order Tests

    func testGroceryCategory_SortOrder_Produce_First() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.produce.sortOrder, 0)
    }

    func testGroceryCategory_SortOrder_Frozen_Last() throws {
        // Act & Assert
        XCTAssertEqual(GroceryCategory.frozen.sortOrder, 8)
    }

    func testGroceryCategory_SortOrder_Logic() throws {
        // Act & Assert - Verify perimeter fresh items come before frozen
        XCTAssertLessThan(GroceryCategory.produce.sortOrder, GroceryCategory.frozen.sortOrder)
        XCTAssertLessThan(GroceryCategory.bakery.sortOrder, GroceryCategory.frozen.sortOrder)
        XCTAssertLessThan(GroceryCategory.meat.sortOrder, GroceryCategory.frozen.sortOrder)

        // Verify dairy comes before frozen but after pantry
        XCTAssertLessThan(GroceryCategory.pantry.sortOrder, GroceryCategory.dairy.sortOrder)
        XCTAssertLessThan(GroceryCategory.dairy.sortOrder, GroceryCategory.frozen.sortOrder)
    }

    // MARK: - GroceryCategory Icon Tests

    func testGroceryCategory_AllCategories_HaveIcons() throws {
        // Act & Assert
        for category in GroceryCategory.allCases {
            XCTAssertFalse(category.iconName.isEmpty, "\(category) should have an icon name")
        }
    }

    func testGroceryCategory_AllCategories_HaveAisleHints() throws {
        // Act & Assert
        for category in GroceryCategory.allCases {
            XCTAssertFalse(category.aisleHint.isEmpty, "\(category) should have an aisle hint")
        }
    }

    // MARK: - Quantity Validation Tests

    func testIngredient_Quantity_NegativeValue() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "-1 cup sugar",
            name: "sugar",
            quantity: -1.0,
            unit: "cup"
        )

        context.insert(ingredient)
        try context.save()

        // Act & Assert - SwiftData allows negative values (no built-in validation)
        // This test documents current behavior
        XCTAssertEqual(ingredient.quantity, -1.0)
    }

    func testIngredient_QuantityMax_GreaterThanMin() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1-2 cups sugar",
            name: "sugar",
            quantity: 1.0,
            unit: "cup"
        )
        ingredient.quantityMax = 2.0

        context.insert(ingredient)
        try context.save()

        // Act & Assert
        XCTAssertNotNil(ingredient.quantityMax)
        XCTAssertGreaterThan(ingredient.quantityMax!, ingredient.quantity!)
    }

    // MARK: - Multilingual Support Tests

    func testIngredient_Conversion_FlagConsistency() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1カップ 小麦粉",
            name: "小麦粉",
            quantity: 1,
            unit: "カップ"
        )
        ingredient.convertedQuantity = 0.83
        ingredient.convertedUnit = "cup"
        ingredient.wasConverted = true

        context.insert(ingredient)
        try context.save()

        // Act & Assert
        XCTAssertTrue(ingredient.wasConverted)
        XCTAssertNotNil(ingredient.convertedQuantity)
        XCTAssertNotNil(ingredient.convertedUnit)
    }

    func testIngredient_Conversion_NoConversionNeeded() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1 cup flour",
            name: "flour",
            quantity: 1,
            unit: "cup"
        )
        ingredient.wasConverted = false

        context.insert(ingredient)
        try context.save()

        // Act & Assert
        XCTAssertFalse(ingredient.wasConverted)
        XCTAssertNil(ingredient.convertedQuantity)
        XCTAssertNil(ingredient.convertedUnit)
    }

    // MARK: - State Validation Tests

    func testIngredient_ShoppingList_InitialState() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1 cup flour",
            name: "flour",
            quantity: 1
        )

        context.insert(ingredient)
        try context.save()

        // Act & Assert
        XCTAssertTrue(ingredient.isSelected, "Should be selected by default")
        XCTAssertFalse(ingredient.isCheckedOff, "Should not be checked off by default")
        XCTAssertFalse(ingredient.isOptional, "Should not be optional by default")
    }

    func testIngredient_ShoppingList_StateTransition() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1 cup flour",
            name: "flour",
            quantity: 1
        )
        ingredient.isSelected = true
        ingredient.isCheckedOff = false

        context.insert(ingredient)
        try context.save()

        // Act
        ingredient.isCheckedOff = true
        try context.save()

        // Assert
        XCTAssertTrue(ingredient.isSelected)
        XCTAssertTrue(ingredient.isCheckedOff)
    }
}
