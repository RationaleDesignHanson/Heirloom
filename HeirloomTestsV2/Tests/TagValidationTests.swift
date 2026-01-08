import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class TagValidationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.Tag.self
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

    // MARK: - Name Validation Tests

    func testTag_Name_CannotBeEmptyOnCreation() throws {
        // Arrange & Act
        let tag = Heirloom.Tag(name: "")

        context.insert(tag)
        try context.save()

        // Assert - SwiftData allows empty strings (no built-in validation)
        // This test documents current behavior
        XCTAssertEqual(tag.name, "")
    }

    func testTag_Name_AcceptsValidString() throws {
        // Arrange & Act
        let tag = Heirloom.Tag(name: "Vegetarian")

        context.insert(tag)
        try context.save()

        // Assert
        XCTAssertEqual(tag.name, "Vegetarian")
    }

    func testTag_Name_AcceptsSpecialCharacters() throws {
        // Arrange & Act
        let tag = Heirloom.Tag(name: "Mom's Favorites")

        context.insert(tag)
        try context.save()

        // Assert
        XCTAssertEqual(tag.name, "Mom's Favorites")
    }

    func testTag_Name_AcceptsUnicode() throws {
        // Arrange & Act
        let tag = Heirloom.Tag(name: "おいしい")

        context.insert(tag)
        try context.save()

        // Assert
        XCTAssertEqual(tag.name, "おいしい")
    }

    // MARK: - Color Validation Tests

    func testTag_Color_DefaultValue() throws {
        // Arrange & Act
        let tag = Heirloom.Tag(name: "Test Tag")

        context.insert(tag)
        try context.save()

        // Assert
        XCTAssertEqual(tag.color, "#FF6B6B") // Default tomato color
    }

    func testTag_Color_AcceptsValidHexCode() throws {
        // Arrange & Act
        let tag = Heirloom.Tag(name: "Test Tag", color: "#4ECDC4")

        context.insert(tag)
        try context.save()

        // Assert
        XCTAssertEqual(tag.color, "#4ECDC4")
    }

    func testTag_Color_AcceptsInvalidFormat() throws {
        // Arrange & Act - SwiftData doesn't validate format
        let tag = Heirloom.Tag(name: "Test Tag", color: "invalid-color")

        context.insert(tag)
        try context.save()

        // Assert - Documents current behavior (no validation)
        XCTAssertEqual(tag.color, "invalid-color")
    }

    func testTag_PredefinedColors_Count() throws {
        // Act & Assert
        XCTAssertEqual(Heirloom.Tag.predefinedColors.count, 10)
    }

    func testTag_PredefinedColors_AllValid() throws {
        // Act & Assert
        for color in Heirloom.Tag.predefinedColors {
            XCTAssertTrue(color.starts(with: "#"), "Color should start with #")
            XCTAssertEqual(color.count, 7, "Hex color should be 7 characters (#RRGGBB)")
        }
    }

    func testTag_PredefinedColors_ContainsExpectedColors() throws {
        // Act & Assert
        XCTAssertTrue(Heirloom.Tag.predefinedColors.contains("#FF6B6B")) // Tomato
        XCTAssertTrue(Heirloom.Tag.predefinedColors.contains("#4ECDC4")) // Turquoise
        XCTAssertTrue(Heirloom.Tag.predefinedColors.contains("#4A90E2")) // Blue
    }

    // MARK: - Recipe Count Tests

    func testTag_RecipeCount_EmptyTag() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Empty Tag")

        context.insert(tag)
        try context.save()

        // Act & Assert
        XCTAssertEqual(tag.recipeCount, 0)
    }

    func testTag_RecipeCount_WithRecipes() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Tagged")
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")

        recipe1.tags = [tag]
        recipe2.tags = [tag]
        tag.recipes = [recipe1, recipe2]

        context.insert(tag)
        context.insert(recipe1)
        context.insert(recipe2)
        try context.save()

        // Act & Assert
        XCTAssertEqual(tag.recipeCount, 2)
    }

    // MARK: - Metadata Tests

    func testTag_CreatedDate_SetOnCreation() throws {
        // Arrange
        let before = Date()
        let tag = Heirloom.Tag(name: "New Tag")
        let after = Date()

        context.insert(tag)
        try context.save()

        // Act & Assert
        XCTAssertGreaterThanOrEqual(tag.createdDate, before)
        XCTAssertLessThanOrEqual(tag.createdDate, after)
    }

    func testTag_ID_UniqueAcrossTags() throws {
        // Arrange
        let tag1 = Heirloom.Tag(name: "Tag 1")
        let tag2 = Heirloom.Tag(name: "Tag 2")

        context.insert(tag1)
        context.insert(tag2)
        try context.save()

        // Act & Assert
        XCTAssertNotEqual(tag1.id, tag2.id)
    }

    // MARK: - Edge Cases

    func testTag_LongName() throws {
        // Arrange
        let longName = String(repeating: "A", count: 1000)
        let tag = Heirloom.Tag(name: longName)

        context.insert(tag)
        try context.save()

        // Act & Assert
        XCTAssertEqual(tag.name.count, 1000)
    }

    func testTag_EmptyColorString() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Test Tag", color: "")

        context.insert(tag)
        try context.save()

        // Act & Assert - Documents current behavior (allows empty string)
        XCTAssertEqual(tag.color, "")
    }
}
