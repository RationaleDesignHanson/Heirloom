import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class TagTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.Tag.self,
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

    func testTag_Create_BasicProperties() throws {
        // Arrange & Act
        let tag = Heirloom.Tag(name: "Vegetarian")

        context.insert(tag)
        try context.save()

        // Assert
        XCTAssertEqual(tag.name, "Vegetarian")
        XCTAssertEqual(tag.color, "#FF6B6B") // Default color
        XCTAssertNotNil(tag.id)
        XCTAssertNotNil(tag.createdDate)
    }

    func testTag_Create_WithCustomColor() throws {
        // Arrange & Act
        let tag = Heirloom.Tag(name: "Quick Meals", color: "#4ECDC4")

        context.insert(tag)
        try context.save()

        // Assert
        XCTAssertEqual(tag.name, "Quick Meals")
        XCTAssertEqual(tag.color, "#4ECDC4")
    }

    func testTag_PredefinedColors_ContainsTenOptions() throws {
        // Assert
        XCTAssertEqual(Heirloom.Tag.predefinedColors.count, 10)
        XCTAssertTrue(Heirloom.Tag.predefinedColors.contains("#FF6B6B")) // Tomato
        XCTAssertTrue(Heirloom.Tag.predefinedColors.contains("#4ECDC4")) // Turquoise
        XCTAssertTrue(Heirloom.Tag.predefinedColors.contains("#4A90E2")) // Blue
    }

    // MARK: - Update Tests

    func testTag_Update_Name() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Original")
        context.insert(tag)
        try context.save()

        // Act
        tag.name = "Updated Name"
        try context.save()

        // Assert
        XCTAssertEqual(tag.name, "Updated Name")
    }

    func testTag_Update_Color() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Test Tag", color: "#FF6B6B")
        context.insert(tag)
        try context.save()

        // Act
        tag.color = "#95E1D3"
        try context.save()

        // Assert
        XCTAssertEqual(tag.color, "#95E1D3")
    }

    // MARK: - Delete Tests

    func testTag_Delete_RemovesFromContext() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "To Delete")
        context.insert(tag)
        try context.save()

        let tagID = tag.id

        // Act
        context.delete(tag)
        try context.save()

        // Assert
        let descriptor = FetchDescriptor<Heirloom.Tag>(
            predicate: #Predicate { $0.id == tagID }
        )
        let results = try context.fetch(descriptor)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Relationship Tests

    func testTag_Recipe_Relationship() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Dessert")
        let recipe = Heirloom.Recipe(title: "Chocolate Cake")

        // Act
        recipe.tags = [tag]
        tag.recipes = [recipe]

        context.insert(tag)
        context.insert(recipe)
        try context.save()

        // Assert
        XCTAssertEqual(tag.recipes?.count, 1)
        XCTAssertEqual(tag.recipes?.first?.id, recipe.id)
        XCTAssertEqual(recipe.tags?.first?.id, tag.id)
    }

    func testTag_MultipleRecipes_Relationship() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Healthy")
        let recipe1 = Heirloom.Recipe(title: "Salad")
        let recipe2 = Heirloom.Recipe(title: "Smoothie")
        let recipe3 = Heirloom.Recipe(title: "Soup")

        // Act
        recipe1.tags = [tag]
        recipe2.tags = [tag]
        recipe3.tags = [tag]
        tag.recipes = [recipe1, recipe2, recipe3]

        context.insert(tag)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Assert
        XCTAssertEqual(tag.recipes?.count, 3)
        XCTAssertEqual(tag.recipeCount, 3)
    }

    // MARK: - Computed Property Tests

    func testTag_RecipeCount_WithNoRecipes() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Empty Tag")
        context.insert(tag)
        try context.save()

        // Assert
        XCTAssertEqual(tag.recipeCount, 0)
    }

    func testTag_RecipeCount_WithRecipes() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Popular")
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")

        recipe1.tags = [tag]
        recipe2.tags = [tag]
        tag.recipes = [recipe1, recipe2]

        context.insert(tag)
        context.insert(recipe1)
        context.insert(recipe2)
        try context.save()

        // Assert
        XCTAssertEqual(tag.recipeCount, 2)
    }

    // MARK: - Query Tests

    func testTag_Query_ByName() throws {
        // Arrange
        let tag1 = Heirloom.Tag(name: "Italian")
        let tag2 = Heirloom.Tag(name: "Mexican")
        let tag3 = Heirloom.Tag(name: "Italian-American")

        context.insert(tag1)
        context.insert(tag2)
        context.insert(tag3)
        try context.save()

        // Act
        let descriptor = FetchDescriptor<Heirloom.Tag>(
            predicate: #Predicate { tag in
                tag.name.contains("Italian")
            }
        )
        let results = try context.fetch(descriptor)

        // Assert
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.name == "Italian" })
        XCTAssertTrue(results.contains { $0.name == "Italian-American" })
    }

    func testTag_Query_AllTags() throws {
        // Arrange
        let tag1 = Heirloom.Tag(name: "Tag 1")
        let tag2 = Heirloom.Tag(name: "Tag 2")
        let tag3 = Heirloom.Tag(name: "Tag 3")

        context.insert(tag1)
        context.insert(tag2)
        context.insert(tag3)
        try context.save()

        // Act
        let descriptor = FetchDescriptor<Heirloom.Tag>()
        let results = try context.fetch(descriptor)

        // Assert
        XCTAssertEqual(results.count, 3)
    }

    // MARK: - Unique Tag Tests

    func testTag_MultipleTags_SameColor() throws {
        // Arrange & Act - Multiple tags can share the same color
        let tag1 = Heirloom.Tag(name: "Tag 1", color: "#FF6B6B")
        let tag2 = Heirloom.Tag(name: "Tag 2", color: "#FF6B6B")

        context.insert(tag1)
        context.insert(tag2)
        try context.save()

        // Assert
        XCTAssertEqual(tag1.color, tag2.color)
        XCTAssertNotEqual(tag1.id, tag2.id)
    }

    func testTag_MultipleTags_SameName() throws {
        // Arrange & Act - Multiple tags can theoretically have same name
        let tag1 = Heirloom.Tag(name: "Duplicate")
        let tag2 = Heirloom.Tag(name: "Duplicate")

        context.insert(tag1)
        context.insert(tag2)
        try context.save()

        // Assert
        XCTAssertEqual(tag1.name, tag2.name)
        XCTAssertNotEqual(tag1.id, tag2.id)
    }

    // MARK: - Recipe Association Tests

    func testTag_AddRemoveRecipe() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Test Tag")
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")

        recipe1.tags = [tag]
        recipe2.tags = [tag]
        tag.recipes = [recipe1, recipe2]

        context.insert(tag)
        context.insert(recipe1)
        context.insert(recipe2)
        try context.save()

        XCTAssertEqual(tag.recipeCount, 2)

        // Act - Remove one recipe
        tag.recipes?.removeAll { $0.id == recipe1.id }
        try context.save()

        // Assert
        XCTAssertEqual(tag.recipeCount, 1)
        XCTAssertEqual(tag.recipes?.first?.id, recipe2.id)
    }
}
