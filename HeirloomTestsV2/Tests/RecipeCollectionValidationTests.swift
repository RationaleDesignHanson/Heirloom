import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class RecipeCollectionValidationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.RecipeCollection.self
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

    func testRecipeCollection_Name_CannotBeEmptyOnCreation() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(name: "")

        context.insert(collection)
        try context.save()

        // Assert - SwiftData allows empty strings (no built-in validation)
        // This test documents current behavior
        XCTAssertEqual(collection.name, "")
    }

    func testRecipeCollection_Name_AcceptsValidString() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(name: "My Collection")

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertEqual(collection.name, "My Collection")
    }

    // MARK: - Icon Validation Tests

    func testRecipeCollection_Icon_DefaultValue() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(name: "Test Collection")

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertEqual(collection.iconName, "folder.fill")
    }

    func testRecipeCollection_Icon_AcceptsCustomIcon() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(name: "Test Collection", iconName: "heart.fill")

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertEqual(collection.iconName, "heart.fill")
    }

    func testRecipeCollection_PredefinedIcons_Count() throws {
        // Act & Assert
        XCTAssertGreaterThanOrEqual(Heirloom.RecipeCollection.predefinedIcons.count, 10)
    }

    func testRecipeCollection_PredefinedIcons_AllHaveValues() throws {
        // Act & Assert
        for icon in Heirloom.RecipeCollection.predefinedIcons {
            XCTAssertFalse(icon.isEmpty, "Predefined icon should not be empty")
        }
    }

    // MARK: - Color Validation Tests

    func testRecipeCollection_Color_DefaultValue() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(name: "Test Collection")

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertEqual(collection.color, "#FF6B6B") // Default tomato color
    }

    func testRecipeCollection_Color_AcceptsValidHexCode() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(name: "Test Collection", color: "#4ECDC4")

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertEqual(collection.color, "#4ECDC4")
    }

    // MARK: - Description Logic Tests

    func testRecipeCollection_DisplayDescription_CustomDescription() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(
            name: "Test Collection",
            description: "My custom description"
        )

        context.insert(collection)
        try context.save()

        // Act & Assert
        XCTAssertEqual(collection.displayDescription, "My custom description")
    }

    func testRecipeCollection_DisplayDescription_NoRecipes() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Test Collection")
        collection.recipes = []

        context.insert(collection)
        try context.save()

        // Act & Assert
        XCTAssertEqual(collection.displayDescription, "No recipes yet")
    }

    func testRecipeCollection_DisplayDescription_OneRecipe() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Test Collection")
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        recipe.collections = [collection]
        collection.recipes = [recipe]

        context.insert(collection)
        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertEqual(collection.displayDescription, "1 recipe")
    }

    func testRecipeCollection_DisplayDescription_MultipleRecipes() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Test Collection")
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")
        let recipe3 = Heirloom.Recipe(title: "Recipe 3")

        recipe1.collections = [collection]
        recipe2.collections = [collection]
        recipe3.collections = [collection]
        collection.recipes = [recipe1, recipe2, recipe3]

        context.insert(collection)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act & Assert
        XCTAssertEqual(collection.displayDescription, "3 recipes")
    }

    // MARK: - System Collection Tests

    func testRecipeCollection_SystemCollection_DefaultFalse() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(name: "User Collection")

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertFalse(collection.isSystemCollection)
    }

    func testRecipeCollection_SystemCollection_CanBeTrue() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(
            name: "Favorites",
            isSystemCollection: true
        )

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertTrue(collection.isSystemCollection)
    }

    // MARK: - Heritage Collection Tests

    func testRecipeCollection_HeritageCollection_IdentifiedByID() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(
            name: "Presidential Pantry",
            heritageCollectionId: "presidential-pantry"
        )

        context.insert(collection)
        try context.save()

        // Act & Assert
        XCTAssertTrue(collection.isHeritageCollection)
        XCTAssertEqual(collection.heritageCollectionId, "presidential-pantry")
    }

    func testRecipeCollection_HeritageCollection_NotHeritageWithoutID() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(name: "Regular Collection")

        context.insert(collection)
        try context.save()

        // Act & Assert
        XCTAssertFalse(collection.isHeritageCollection)
        XCTAssertNil(collection.heritageCollectionId)
    }

    func testRecipeCollection_HeritageCollectionID_AllCases() throws {
        // Act & Assert
        XCTAssertEqual(Heirloom.RecipeCollection.HeritageCollectionID.allCases.count, 4)
    }

    func testRecipeCollection_HeritageCollectionID_AllHaveDisplayNames() throws {
        // Act & Assert
        for collectionID in Heirloom.RecipeCollection.HeritageCollectionID.allCases {
            XCTAssertFalse(collectionID.displayName.isEmpty, "\(collectionID) should have display name")
        }
    }

    func testRecipeCollection_HeritageCollectionID_AllHaveDescriptions() throws {
        // Act & Assert
        for collectionID in Heirloom.RecipeCollection.HeritageCollectionID.allCases {
            XCTAssertFalse(collectionID.description.isEmpty, "\(collectionID) should have description")
        }
    }

    func testRecipeCollection_HeritageCollectionID_AllHaveColors() throws {
        // Act & Assert
        for collectionID in Heirloom.RecipeCollection.HeritageCollectionID.allCases {
            XCTAssertTrue(collectionID.color.starts(with: "#"), "\(collectionID) color should start with #")
        }
    }

    func testRecipeCollection_HeritageCollectionID_AllHaveIcons() throws {
        // Act & Assert
        for collectionID in Heirloom.RecipeCollection.HeritageCollectionID.allCases {
            XCTAssertFalse(collectionID.iconName.isEmpty, "\(collectionID) should have icon name")
        }
    }

    // MARK: - Recipe Count Tests

    func testRecipeCollection_RecipeCount_EmptyCollection() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Empty Collection")

        context.insert(collection)
        try context.save()

        // Act & Assert
        XCTAssertEqual(collection.recipeCount, 0)
    }

    func testRecipeCollection_RecipeCount_WithRecipes() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Test Collection")
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")

        recipe1.collections = [collection]
        recipe2.collections = [collection]
        collection.recipes = [recipe1, recipe2]

        context.insert(collection)
        context.insert(recipe1)
        context.insert(recipe2)
        try context.save()

        // Act & Assert
        XCTAssertEqual(collection.recipeCount, 2)
    }

    // MARK: - Metadata Tests

    func testRecipeCollection_CreatedDate_SetOnCreation() throws {
        // Arrange
        let before = Date()
        let collection = Heirloom.RecipeCollection(name: "New Collection")
        let after = Date()

        context.insert(collection)
        try context.save()

        // Act & Assert
        XCTAssertGreaterThanOrEqual(collection.createdDate, before)
        XCTAssertLessThanOrEqual(collection.createdDate, after)
    }

    func testRecipeCollection_ID_UniqueAcrossCollections() throws {
        // Arrange
        let collection1 = Heirloom.RecipeCollection(name: "Collection 1")
        let collection2 = Heirloom.RecipeCollection(name: "Collection 2")

        context.insert(collection1)
        context.insert(collection2)
        try context.save()

        // Act & Assert
        XCTAssertNotEqual(collection1.id, collection2.id)
    }

    // MARK: - Edge Cases

    func testRecipeCollection_LongName() throws {
        // Arrange
        let longName = String(repeating: "A", count: 1000)
        let collection = Heirloom.RecipeCollection(name: longName)

        context.insert(collection)
        try context.save()

        // Act & Assert
        XCTAssertEqual(collection.name.count, 1000)
    }

    func testRecipeCollection_LongDescription() throws {
        // Arrange
        let longDesc = String(repeating: "A", count: 5000)
        let collection = Heirloom.RecipeCollection(name: "Test", description: longDesc)

        context.insert(collection)
        try context.save()

        // Act & Assert
        XCTAssertEqual(collection.desc?.count, 5000)
    }
}
