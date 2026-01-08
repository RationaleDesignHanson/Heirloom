import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class RecipeCollectionTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.RecipeCollection.self,
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

    func testRecipeCollection_Create_BasicProperties() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(name: "My Collection")

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertEqual(collection.name, "My Collection")
        XCTAssertNil(collection.desc)
        XCTAssertEqual(collection.iconName, "folder.fill") // Default icon
        XCTAssertEqual(collection.color, "#FF6B6B") // Default color
        XCTAssertFalse(collection.isSystemCollection)
        XCTAssertNil(collection.heritageCollectionId)
        XCTAssertNotNil(collection.id)
        XCTAssertNotNil(collection.createdDate)
    }

    func testRecipeCollection_Create_WithDescription() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(
            name: "Summer Favorites",
            description: "Light and refreshing recipes"
        )

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertEqual(collection.name, "Summer Favorites")
        XCTAssertEqual(collection.desc, "Light and refreshing recipes")
    }

    func testRecipeCollection_Create_WithCustomIconAndColor() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(
            name: "Desserts",
            iconName: "birthday.cake.fill",
            color: "#FCBAD3"
        )

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertEqual(collection.iconName, "birthday.cake.fill")
        XCTAssertEqual(collection.color, "#FCBAD3")
    }

    func testRecipeCollection_PredefinedIcons_ContainsExpectedIcons() throws {
        // Assert
        XCTAssertTrue(Heirloom.RecipeCollection.predefinedIcons.count >= 10)
        XCTAssertTrue(Heirloom.RecipeCollection.predefinedIcons.contains("folder.fill"))
        XCTAssertTrue(Heirloom.RecipeCollection.predefinedIcons.contains("heart.fill"))
        XCTAssertTrue(Heirloom.RecipeCollection.predefinedIcons.contains("fork.knife"))
    }

    // MARK: - Update Tests

    func testRecipeCollection_Update_Name() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Original Name")
        context.insert(collection)
        try context.save()

        // Act
        collection.name = "Updated Name"
        try context.save()

        // Assert
        XCTAssertEqual(collection.name, "Updated Name")
    }

    func testRecipeCollection_Update_Description() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Test")
        context.insert(collection)
        try context.save()

        // Act
        collection.desc = "New description"
        try context.save()

        // Assert
        XCTAssertEqual(collection.desc, "New description")
    }

    // MARK: - Delete Tests

    func testRecipeCollection_Delete_RemovesFromContext() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "To Delete")
        context.insert(collection)
        try context.save()

        let collectionID = collection.id

        // Act
        context.delete(collection)
        try context.save()

        // Assert
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.id == collectionID }
        )
        let results = try context.fetch(descriptor)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Relationship Tests

    func testRecipeCollection_Recipe_Relationship() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Italian Recipes")
        let recipe = Heirloom.Recipe(title: "Pasta Carbonara")

        // Act
        recipe.collections = [collection]
        collection.recipes = [recipe]

        context.insert(collection)
        context.insert(recipe)
        try context.save()

        // Assert
        XCTAssertEqual(collection.recipes?.count, 1)
        XCTAssertEqual(collection.recipes?.first?.id, recipe.id)
        XCTAssertEqual(recipe.collections?.first?.id, collection.id)
    }

    func testRecipeCollection_MultipleRecipes_Relationship() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Breakfast")
        let recipe1 = Heirloom.Recipe(title: "Pancakes")
        let recipe2 = Heirloom.Recipe(title: "Waffles")
        let recipe3 = Heirloom.Recipe(title: "French Toast")

        // Act
        recipe1.collections = [collection]
        recipe2.collections = [collection]
        recipe3.collections = [collection]
        collection.recipes = [recipe1, recipe2, recipe3]

        context.insert(collection)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Assert
        XCTAssertEqual(collection.recipes?.count, 3)
        XCTAssertEqual(collection.recipeCount, 3)
    }

    // MARK: - Computed Property Tests

    func testRecipeCollection_RecipeCount_WithNoRecipes() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Empty")
        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertEqual(collection.recipeCount, 0)
    }

    func testRecipeCollection_RecipeCount_WithRecipes() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Test")
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")

        recipe1.collections = [collection]
        recipe2.collections = [collection]
        collection.recipes = [recipe1, recipe2]

        context.insert(collection)
        context.insert(recipe1)
        context.insert(recipe2)
        try context.save()

        // Assert
        XCTAssertEqual(collection.recipeCount, 2)
    }

    func testRecipeCollection_DisplayDescription_WithCustomDescription() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(
            name: "Test",
            description: "Custom description"
        )

        // Assert
        XCTAssertEqual(collection.displayDescription, "Custom description")
    }

    func testRecipeCollection_DisplayDescription_WithNoRecipes() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(name: "Empty")
        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertEqual(collection.displayDescription, "No recipes yet")
    }

    func testRecipeCollection_DisplayDescription_WithOneRecipe() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Test")
        let recipe = Heirloom.Recipe(title: "Single Recipe")

        recipe.collections = [collection]
        collection.recipes = [recipe]

        context.insert(collection)
        context.insert(recipe)
        try context.save()

        // Assert
        XCTAssertEqual(collection.displayDescription, "1 recipe")
    }

    func testRecipeCollection_DisplayDescription_WithMultipleRecipes() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Test")
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

        // Assert
        XCTAssertEqual(collection.displayDescription, "3 recipes")
    }

    // MARK: - System Collection Tests

    func testRecipeCollection_SystemCollection_Creation() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(
            name: "Favorites",
            iconName: "heart.fill",
            isSystemCollection: true
        )

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertTrue(collection.isSystemCollection)
        XCTAssertFalse(collection.isHeritageCollection)
    }

    func testRecipeCollection_CreateSystemCollections_CreatesFavorites() throws {
        // Act
        Heirloom.RecipeCollection.createSystemCollections(context: context)

        // Assert
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { collection in
                collection.name == "Favorites" && collection.isSystemCollection == true
            }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        let favorites = results.first!
        XCTAssertEqual(favorites.iconName, "heart.fill")
        XCTAssertTrue(favorites.isSystemCollection)
    }

    func testRecipeCollection_CreateSystemCollections_CreatesThreeCollections() throws {
        // Act
        Heirloom.RecipeCollection.createSystemCollections(context: context)

        // Assert
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.isSystemCollection == true }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.contains { $0.name == "Favorites" })
        XCTAssertTrue(results.contains { $0.name == "Quick Meals" })
        XCTAssertTrue(results.contains { $0.name == "Meal Prep" })
    }

    func testRecipeCollection_CreateSystemCollections_IdempotentCall() throws {
        // Act - Call twice
        Heirloom.RecipeCollection.createSystemCollections(context: context)
        Heirloom.RecipeCollection.createSystemCollections(context: context)

        // Assert - Should still only have 3 system collections
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.isSystemCollection == true }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 3)
    }

    // MARK: - Heritage Collection Tests

    func testRecipeCollection_HeritageCollection_Creation() throws {
        // Arrange & Act
        let collection = Heirloom.RecipeCollection(
            name: "Presidential Pantry",
            heritageCollectionId: "presidential-pantry"
        )

        context.insert(collection)
        try context.save()

        // Assert
        XCTAssertTrue(collection.isHeritageCollection)
        XCTAssertEqual(collection.heritageCollectionId, "presidential-pantry")
    }

    func testRecipeCollection_HeritageCollectionID_AllCasesExist() throws {
        // Assert
        XCTAssertEqual(Heirloom.RecipeCollection.HeritageCollectionID.allCases.count, 4)
        XCTAssertNotNil(Heirloom.RecipeCollection.HeritageCollectionID.presidentialPantry)
        XCTAssertNotNil(Heirloom.RecipeCollection.HeritageCollectionID.literaryKitchen)
        XCTAssertNotNil(Heirloom.RecipeCollection.HeritageCollectionID.ancientTable)
        XCTAssertNotNil(Heirloom.RecipeCollection.HeritageCollectionID.americanFoundation)
    }

    func testRecipeCollection_HeritageCollectionID_DisplayNames() throws {
        // Assert
        XCTAssertEqual(Heirloom.RecipeCollection.HeritageCollectionID.presidentialPantry.displayName, "Presidential Pantry")
        XCTAssertEqual(Heirloom.RecipeCollection.HeritageCollectionID.literaryKitchen.displayName, "Literary Kitchen")
        XCTAssertEqual(Heirloom.RecipeCollection.HeritageCollectionID.ancientTable.displayName, "Ancient Table")
        XCTAssertEqual(Heirloom.RecipeCollection.HeritageCollectionID.americanFoundation.displayName, "American Foundation")
    }

    func testRecipeCollection_HeritageCollectionID_HasDescriptions() throws {
        // Assert - Verify all have non-empty descriptions
        for collectionID in Heirloom.RecipeCollection.HeritageCollectionID.allCases {
            XCTAssertFalse(collectionID.description.isEmpty)
            XCTAssertFalse(collectionID.color.isEmpty)
            XCTAssertFalse(collectionID.iconName.isEmpty)
        }
    }

    func testRecipeCollection_CreateHeritageCollections_CreatesFourCollections() throws {
        // Act
        Heirloom.RecipeCollection.createHeritageCollections(context: context)

        // Assert
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.heritageCollectionId != nil }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 4)
        XCTAssertTrue(results.allSatisfy { $0.isHeritageCollection })
        XCTAssertTrue(results.allSatisfy { $0.isSystemCollection })
    }

    func testRecipeCollection_CreateHeritageCollections_IdempotentCall() throws {
        // Act - Call twice
        Heirloom.RecipeCollection.createHeritageCollections(context: context)
        Heirloom.RecipeCollection.createHeritageCollections(context: context)

        // Assert - Should still only have 4 heritage collections
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.heritageCollectionId != nil }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 4)
    }

    func testRecipeCollection_HeritageCollection_HasCorrectProperties() throws {
        // Act
        Heirloom.RecipeCollection.createHeritageCollections(context: context)

        // Assert - Check Presidential Pantry specifically
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.heritageCollectionId == "presidential-pantry" }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        let collection = results.first!
        XCTAssertEqual(collection.name, "Presidential Pantry")
        XCTAssertEqual(collection.iconName, "building.columns.fill")
        XCTAssertEqual(collection.color, "#8B0000")
        XCTAssertTrue(collection.isSystemCollection)
        XCTAssertTrue(collection.isHeritageCollection)
    }

    // MARK: - Query Tests

    func testRecipeCollection_Query_ByName() throws {
        // Arrange
        let collection1 = Heirloom.RecipeCollection(name: "Italian Classics")
        let collection2 = Heirloom.RecipeCollection(name: "French Cuisine")
        let collection3 = Heirloom.RecipeCollection(name: "Italian Desserts")

        context.insert(collection1)
        context.insert(collection2)
        context.insert(collection3)
        try context.save()

        // Act
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { collection in
                collection.name.contains("Italian")
            }
        )
        let results = try context.fetch(descriptor)

        // Assert
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.name == "Italian Classics" })
        XCTAssertTrue(results.contains { $0.name == "Italian Desserts" })
    }

    func testRecipeCollection_Query_SystemCollections() throws {
        // Arrange
        Heirloom.RecipeCollection.createSystemCollections(context: context)
        let userCollection = Heirloom.RecipeCollection(name: "User Collection")
        context.insert(userCollection)
        try context.save()

        // Act
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.isSystemCollection == true }
        )
        let results = try context.fetch(descriptor)

        // Assert
        XCTAssertEqual(results.count, 3) // Should only return system collections
        XCTAssertFalse(results.contains { $0.id == userCollection.id })
    }

    func testRecipeCollection_Query_HeritageCollections() throws {
        // Arrange
        Heirloom.RecipeCollection.createHeritageCollections(context: context)
        let userCollection = Heirloom.RecipeCollection(name: "User Collection")
        context.insert(userCollection)
        try context.save()

        // Act
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.heritageCollectionId != nil }
        )
        let results = try context.fetch(descriptor)

        // Assert
        XCTAssertEqual(results.count, 4) // Should only return heritage collections
        XCTAssertTrue(results.allSatisfy { $0.isHeritageCollection })
    }

    // MARK: - Recipe Association Tests

    func testRecipeCollection_AddRemoveRecipe() throws {
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

        XCTAssertEqual(collection.recipeCount, 2)

        // Act - Remove one recipe
        collection.recipes?.removeAll { $0.id == recipe1.id }
        try context.save()

        // Assert
        XCTAssertEqual(collection.recipeCount, 1)
        XCTAssertEqual(collection.recipes?.first?.id, recipe2.id)
    }
}
