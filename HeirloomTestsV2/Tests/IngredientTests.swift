import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class IngredientTests: XCTestCase {
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

    // MARK: - Creation Tests

    func testIngredient_Create_BasicProperties() throws {
        // Arrange & Act
        let ingredient = Heirloom.Ingredient(
            originalText: "2 cups all-purpose flour",
            name: "all-purpose flour",
            quantity: 2.0,
            unit: "cups"
        )

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.originalText, "2 cups all-purpose flour")
        XCTAssertEqual(ingredient.name, "all-purpose flour")
        XCTAssertEqual(ingredient.quantity, 2)
        XCTAssertEqual(ingredient.unit, "cups")
        XCTAssertNotNil(ingredient.id)
    }

    func testIngredient_Create_WithQuantityRange() throws {
        // Arrange & Act
        let ingredient = Heirloom.Ingredient(
            originalText: "1-2 cups sugar",
            name: "sugar",
            quantity: 1.0,
            unit: "cups"
        )
        ingredient.quantityMax = 2.0

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.quantity, 1)
        XCTAssertEqual(ingredient.quantityMax, 2)
        XCTAssertEqual(ingredient.unit, "cups")
    }

    func testIngredient_Create_WithPreparation() throws {
        // Arrange & Act
        let ingredient = Heirloom.Ingredient(
            originalText: "1 lb carrots, peeled and diced",
            name: "carrots",
            quantity: 1.0,
            unit: "lb"
        )
        ingredient.preparation = "peeled and diced"

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.name, "carrots")
        XCTAssertEqual(ingredient.preparation, "peeled and diced")
    }

    func testIngredient_Create_WithSize() throws {
        // Arrange & Act
        let ingredient = Heirloom.Ingredient(
            originalText: "4 large eggs",
            name: "eggs",
            quantity: 4.0
        )
        ingredient.size = "large"

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.quantity, 4)
        XCTAssertEqual(ingredient.size, "large")
    }

    // MARK: - Unit Normalization Tests

    func testIngredient_NormalizedUnit_Singular() throws {
        // Arrange & Act
        let ingredient = Heirloom.Ingredient(
            originalText: "2 cups flour",
            name: "flour",
            quantity: 2.0,
            unit: "cups"
        )
        ingredient.normalizedUnit = "cup"

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.unit, "cups")
        XCTAssertEqual(ingredient.normalizedUnit, "cup")
    }

    // MARK: - Multilingual/Conversion Tests

    func testIngredient_RegionalConversion_JapaneseCup() throws {
        // Arrange & Act - Japanese cup (200ml) to US cup (240ml)
        let ingredient = Heirloom.Ingredient(
            originalText: "1カップ 小麦粉",
            name: "小麦粉", // flour in Japanese
            quantity: 1,
            unit: "カップ"
        )
        ingredient.originalLanguageName = "小麦粉"
        ingredient.translatedName = "flour"
        ingredient.originalLanguageUnit = "カップ"
        ingredient.convertedQuantity = 0.83
        ingredient.convertedUnit = "cup"
        ingredient.conversionNote = "Japanese cup (200ml) converted to 0.83 US cups (240ml)"
        ingredient.wasConverted = true

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.originalLanguageName, "小麦粉")
        XCTAssertEqual(ingredient.translatedName, "flour")
        XCTAssertEqual(ingredient.convertedQuantity, 0.83)
        XCTAssertEqual(ingredient.convertedUnit, "cup")
        XCTAssertTrue(ingredient.wasConverted)
        XCTAssertNotNil(ingredient.conversionNote)
    }

    func testIngredient_RegionalConversion_KoreanTablespoon() throws {
        // Arrange & Act - Korean tablespoon (15ml) = 1 US tablespoon
        let ingredient = Heirloom.Ingredient(
            originalText: "2큰술 참기름",
            name: "참기름", // sesame oil in Korean
            quantity: 2,
            unit: "큰술"
        )
        ingredient.originalLanguageName = "참기름"
        ingredient.translatedName = "sesame oil"
        ingredient.originalLanguageUnit = "큰술"
        ingredient.convertedQuantity = 2
        ingredient.convertedUnit = "tablespoon"
        ingredient.wasConverted = true

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.translatedName, "sesame oil")
        XCTAssertEqual(ingredient.convertedQuantity, 2)
        XCTAssertTrue(ingredient.wasConverted)
    }

    func testIngredient_NoConversion_EnglishIngredient() throws {
        // Arrange & Act
        let ingredient = Heirloom.Ingredient(
            originalText: "1 cup flour",
            name: "flour",
            quantity: 1,
            unit: "cup"
        )
        ingredient.wasConverted = false

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertNil(ingredient.originalLanguageName)
        XCTAssertNil(ingredient.translatedName)
        XCTAssertNil(ingredient.convertedQuantity)
        XCTAssertNil(ingredient.convertedUnit)
        XCTAssertFalse(ingredient.wasConverted)
    }

    // MARK: - Category Tests

    func testIngredient_Category_Produce() throws {
        // Arrange & Act
        let ingredient = Heirloom.Ingredient(
            originalText: "2 tomatoes",
            name: "tomatoes",
            quantity: 2,
            category: .produce
        )

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.category, .produce)
    }

    func testIngredient_Category_Dairy() throws {
        // Arrange & Act
        let ingredient = Heirloom.Ingredient(
            originalText: "1 cup milk",
            name: "milk",
            quantity: 1,
            unit: "cup",
            category: .dairy
        )

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.category, .dairy)
    }

    // MARK: - Shopping List Tests

    func testIngredient_ShoppingList_Selection() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1 lb beef",
            name: "beef",
            quantity: 1,
            unit: "lb"
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

    func testIngredient_ShoppingList_Optional() throws {
        // Arrange & Act
        let ingredient = Heirloom.Ingredient(
            originalText: "1 pinch cayenne pepper (optional)",
            name: "cayenne pepper",
            quantity: 1,
            unit: "pinch"
        )
        ingredient.isOptional = true

        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertTrue(ingredient.isOptional)
    }

    // MARK: - Relationship Tests

    func testIngredient_Recipe_Relationship() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Test Recipe"

        let ingredient = Heirloom.Ingredient(
            originalText: "1 cup flour",
            name: "flour",
            quantity: 1,
            unit: "cup"
        )

        // Act
        ingredient.recipe = recipe
        recipe.ingredients = [ingredient]

        context.insert(recipe)
        context.insert(ingredient)
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.recipe?.id, recipe.id)
        XCTAssertEqual(recipe.ingredients?.first?.id, ingredient.id)
    }

    // MARK: - Order Index Tests

    func testIngredient_OrderIndex_Sequence() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Recipe with Multiple Ingredients"

        let ingredient1 = Heirloom.Ingredient(originalText: "First", name: "first", orderIndex: 0)
        let ingredient2 = Heirloom.Ingredient(originalText: "Second", name: "second", orderIndex: 1)
        let ingredient3 = Heirloom.Ingredient(originalText: "Third", name: "third", orderIndex: 2)

        ingredient1.recipe = recipe
        ingredient2.recipe = recipe
        ingredient3.recipe = recipe
        recipe.ingredients = [ingredient1, ingredient2, ingredient3]

        // Act
        context.insert(recipe)
        context.insert(ingredient1)
        context.insert(ingredient2)
        context.insert(ingredient3)
        try context.save()

        // Assert
        let sortedIngredients = recipe.ingredients?.sorted { $0.orderIndex < $1.orderIndex }
        XCTAssertEqual(sortedIngredients?.count, 3)
        XCTAssertEqual(sortedIngredients?[0].name, "first")
        XCTAssertEqual(sortedIngredients?[1].name, "second")
        XCTAssertEqual(sortedIngredients?[2].name, "third")
    }

    // MARK: - Query Tests

    func testIngredient_Query_ByName() throws {
        // Arrange
        let ingredient1 = Heirloom.Ingredient(originalText: "sugar", name: "sugar", quantity: 1)
        let ingredient2 = Heirloom.Ingredient(originalText: "salt", name: "salt", quantity: 1)
        let ingredient3 = Heirloom.Ingredient(originalText: "brown sugar", name: "brown sugar", quantity: 1)

        context.insert(ingredient1)
        context.insert(ingredient2)
        context.insert(ingredient3)
        try context.save()

        // Act
        let descriptor = FetchDescriptor<Heirloom.Ingredient>(
            predicate: #Predicate { ingredient in
                ingredient.name.contains("sugar")
            }
        )
        let results = try context.fetch(descriptor)

        // Assert
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.name == "sugar" })
        XCTAssertTrue(results.contains { $0.name == "brown sugar" })
    }

    func testIngredient_CategoryFilter() throws {
        // Test filtering ingredients by their grocery category
        // Arrange
        let ingredient1 = Heirloom.Ingredient(originalText: "carrots", name: "carrots", quantity: 1.0)
        let ingredient2 = Heirloom.Ingredient(originalText: "milk", name: "milk", quantity: 1.0)

        ingredient1.category = .produce
        ingredient2.category = .dairy

        context.insert(ingredient1)
        context.insert(ingredient2)
        try context.save()

        // Act - Fetch all and manually count by category
        let descriptor = FetchDescriptor<Heirloom.Ingredient>()
        let allIngredients = try context.fetch(descriptor)

        var produceCount = 0
        var dairyCount = 0
        for ing in allIngredients {
            if ing.category == .produce {
                produceCount += 1
            } else if ing.category == .dairy {
                dairyCount += 1
            }
        }

        // Assert
        XCTAssertEqual(allIngredients.count, 2, "Should have 2 total ingredients")
        XCTAssertEqual(produceCount, 1, "Should have 1 produce ingredient")
        XCTAssertEqual(dairyCount, 1, "Should have 1 dairy ingredient")
    }

    // MARK: - Delete Tests

    func testIngredient_Delete_RemovesFromContext() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1 cup flour",
            name: "flour",
            quantity: 1
        )
        context.insert(ingredient)
        try context.save()

        let ingredientID = ingredient.id

        // Act
        context.delete(ingredient)
        try context.save()

        // Assert
        let descriptor = FetchDescriptor<Heirloom.Ingredient>(
            predicate: #Predicate { $0.id == ingredientID }
        )
        let results = try context.fetch(descriptor)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Update Tests

    func testIngredient_Update_Quantity() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "1 cup sugar",
            name: "sugar",
            quantity: 1,
            unit: "cup"
        )
        context.insert(ingredient)
        try context.save()

        // Act
        ingredient.quantity = 2
        ingredient.originalText = "2 cups sugar"
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.quantity, 2)
        XCTAssertEqual(ingredient.originalText, "2 cups sugar")
    }

    func testIngredient_Update_Category() throws {
        // Arrange
        let ingredient = Heirloom.Ingredient(
            originalText: "tofu",
            name: "tofu",
            category: .other
        )
        context.insert(ingredient)
        try context.save()

        // Act
        ingredient.category = .meat
        try context.save()

        // Assert
        XCTAssertEqual(ingredient.category, .meat)
    }
}
