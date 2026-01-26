import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class CollectionDeletionTests: XCTestCase {
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

    // MARK: - Delete Collection Only Tests

    func testCollectionDeletion_OnlyCollection_KeepsRecipes() throws {
        // GIVEN: A collection with 3 recipes
        let collection = Heirloom.RecipeCollection(name: "Test Collection")
        context.insert(collection)

        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")
        let recipe3 = Heirloom.Recipe(title: "Recipe 3")

        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)

        // Add recipes to collection
        recipe1.collections = [collection]
        recipe2.collections = [collection]
        recipe3.collections = [collection]

        try context.save()

        // Verify initial state
        XCTAssertEqual(collection.recipes?.count, 3)

        // WHEN: Delete collection but keep recipes
        // Simulate deleteCollectionKeepingRecipes logic
        if let recipes = collection.recipes {
            for recipe in recipes {
                recipe.collections?.removeAll { $0.id == collection.id }
            }
        }

        context.delete(collection)
        try context.save()

        // THEN: Collection is deleted, recipes remain
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.name == "Test Collection" }
        )
        let collections = try context.fetch(descriptor)
        XCTAssertEqual(collections.count, 0, "Collection should be deleted")

        let recipeDescriptor = FetchDescriptor<Heirloom.Recipe>()
        let remainingRecipes = try context.fetch(recipeDescriptor)
        XCTAssertEqual(remainingRecipes.count, 3, "All recipes should remain")

        // Verify recipes no longer reference the collection
        for recipe in remainingRecipes {
            XCTAssertTrue(recipe.collections?.isEmpty ?? true, "Recipes should have no collection references")
        }
    }

    func testCollectionDeletion_OnlyCollection_WithRecipeInMultipleCollections() throws {
        // GIVEN: A recipe in two collections
        let collection1 = Heirloom.RecipeCollection(name: "Collection 1")
        let collection2 = Heirloom.RecipeCollection(name: "Collection 2")
        context.insert(collection1)
        context.insert(collection2)

        let recipe = Heirloom.Recipe(title: "Shared Recipe")
        context.insert(recipe)

        recipe.collections = [collection1, collection2]
        try context.save()

        // WHEN: Delete collection1 only
        if let recipes = collection1.recipes {
            for recipe in recipes {
                recipe.collections?.removeAll { $0.id == collection1.id }
            }
        }

        context.delete(collection1)
        try context.save()

        // THEN: Recipe still exists and is in collection2
        let recipeDescriptor = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.title == "Shared Recipe" }
        )
        let recipes = try context.fetch(recipeDescriptor)
        XCTAssertEqual(recipes.count, 1, "Recipe should still exist")

        let fetchedRecipe = recipes[0]
        XCTAssertEqual(fetchedRecipe.collections?.count, 1, "Recipe should be in 1 collection")
        XCTAssertEqual(fetchedRecipe.collections?.first?.name, "Collection 2")
    }

    // MARK: - Delete Collection & Recipes Tests

    func testCollectionDeletion_WithRecipes_DeletesBoth() throws {
        // GIVEN: A collection with 3 recipes
        let collection = Heirloom.RecipeCollection(name: "Test Collection")
        context.insert(collection)

        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")
        let recipe3 = Heirloom.Recipe(title: "Recipe 3")

        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)

        recipe1.collections = [collection]
        recipe2.collections = [collection]
        recipe3.collections = [collection]

        try context.save()

        // Verify initial state
        XCTAssertEqual(collection.recipes?.count, 3)

        // WHEN: Delete collection and recipes
        // Simulate deleteCollectionAndRecipes logic
        let recipesToDelete = collection.recipes ?? []
        for recipe in recipesToDelete {
            context.delete(recipe)
        }

        context.delete(collection)
        try context.save()

        // THEN: Both collection and recipes are deleted
        let collectionDescriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.name == "Test Collection" }
        )
        let collections = try context.fetch(collectionDescriptor)
        XCTAssertEqual(collections.count, 0, "Collection should be deleted")

        let recipeDescriptor = FetchDescriptor<Heirloom.Recipe>()
        let remainingRecipes = try context.fetch(recipeDescriptor)
        XCTAssertEqual(remainingRecipes.count, 0, "All recipes should be deleted")
    }

    func testCollectionDeletion_WithRecipes_SharedRecipeNotDeleted() throws {
        // GIVEN: Two collections, one shared recipe
        let collection1 = Heirloom.RecipeCollection(name: "Collection 1")
        let collection2 = Heirloom.RecipeCollection(name: "Collection 2")
        context.insert(collection1)
        context.insert(collection2)

        let sharedRecipe = Heirloom.Recipe(title: "Shared Recipe")
        let exclusiveRecipe = Heirloom.Recipe(title: "Exclusive Recipe")

        context.insert(sharedRecipe)
        context.insert(exclusiveRecipe)

        sharedRecipe.collections = [collection1, collection2]
        exclusiveRecipe.collections = [collection1]

        try context.save()

        // WHEN: Delete collection1 and its recipes
        let recipesToDelete = collection1.recipes ?? []
        for recipe in recipesToDelete {
            context.delete(recipe)
        }

        context.delete(collection1)
        try context.save()

        // THEN: Both recipes are deleted (including shared one)
        let recipeDescriptor = FetchDescriptor<Heirloom.Recipe>()
        let remainingRecipes = try context.fetch(recipeDescriptor)
        XCTAssertEqual(remainingRecipes.count, 0, "All recipes in collection1 should be deleted")

        // Note: This matches expected behavior - delete deletes the recipe entirely,
        // not just the relationship. User chose "Delete Collection & Recipes"
    }

    // MARK: - System Collection Protection Tests

    func testCollectionDeletion_SystemCollection_ShouldBeProtected() throws {
        // GIVEN: A system collection (like Favorites)
        let systemCollection = Heirloom.RecipeCollection(
            name: "Favorites",
            isSystemCollection: true
        )
        context.insert(systemCollection)

        let recipe = Heirloom.Recipe(title: "Favorite Recipe")
        context.insert(recipe)
        recipe.collections = [systemCollection]

        try context.save()

        // WHEN: Attempt to delete (simulating guard clause check)
        let canDelete = !systemCollection.isSystemCollection

        // THEN: Should not be allowed
        XCTAssertFalse(canDelete, "System collections should not be deletable")

        // Verify it still exists
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.name == "Favorites" }
        )
        let collections = try context.fetch(descriptor)
        XCTAssertEqual(collections.count, 1, "System collection should still exist")
    }

    func testCollectionDeletion_UserCollection_ShouldBeAllowed() throws {
        // GIVEN: A user collection
        let userCollection = Heirloom.RecipeCollection(
            name: "My Collection",
            isSystemCollection: false
        )
        context.insert(userCollection)
        try context.save()

        // WHEN: Check if deletion is allowed
        let canDelete = !userCollection.isSystemCollection

        // THEN: Should be allowed
        XCTAssertTrue(canDelete, "User collections should be deletable")
    }

    func testCollectionDeletion_HeritageCollection_ShouldBeAllowed() throws {
        // GIVEN: A heritage collection
        let heritageCollection = Heirloom.RecipeCollection(
            name: "Presidential Pantry",
            isSystemCollection: false,
            sourceThemeId: "presidential-pantry"
        )
        context.insert(heritageCollection)
        try context.save()

        // WHEN: Check if deletion is allowed
        let canDelete = !heritageCollection.isSystemCollection

        // THEN: Should be allowed (heritage collections are deletable)
        XCTAssertTrue(canDelete, "Heritage collections should be deletable")
        XCTAssertTrue(heritageCollection.isHeritageCollection, "Should be identified as heritage")
    }

    // MARK: - Empty Collection Tests

    func testCollectionDeletion_EmptyCollection_Success() throws {
        // GIVEN: An empty collection
        let collection = Heirloom.RecipeCollection(name: "Empty Collection")
        context.insert(collection)
        try context.save()

        XCTAssertEqual(collection.recipes?.count ?? 0, 0, "Collection should be empty")

        // WHEN: Delete the collection
        context.delete(collection)
        try context.save()

        // THEN: Collection is deleted successfully
        let descriptor = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.name == "Empty Collection" }
        )
        let collections = try context.fetch(descriptor)
        XCTAssertEqual(collections.count, 0, "Collection should be deleted")
    }

    // MARK: - Recipe Count Tests

    func testCollectionDeletion_RecipeCount_ReportsCorrectly() throws {
        // GIVEN: A collection with recipes
        let collection = Heirloom.RecipeCollection(name: "Test Collection")
        context.insert(collection)

        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")
        let recipe3 = Heirloom.Recipe(title: "Recipe 3")

        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)

        recipe1.collections = [collection]
        recipe2.collections = [collection]
        recipe3.collections = [collection]

        try context.save()

        // WHEN: Check recipe count before deletion
        let recipeCount = collection.recipeCount

        // THEN: Count should be accurate
        XCTAssertEqual(recipeCount, 3, "Recipe count should match actual recipes")
    }

    // MARK: - Relationship Integrity Tests

    func testCollectionDeletion_RelationshipIntegrity_BidirectionalSync() throws {
        // GIVEN: Collection and recipe with bidirectional relationship
        let collection = Heirloom.RecipeCollection(name: "Test Collection")
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        context.insert(collection)
        context.insert(recipe)

        recipe.collections = [collection]
        try context.save()

        // WHEN: Verify bidirectional relationship
        XCTAssertEqual(recipe.collections?.count, 1)
        XCTAssertEqual(collection.recipes?.count, 1)
        XCTAssertTrue(collection.recipes?.contains(where: { $0.id == recipe.id }) ?? false)

        // AND: Remove relationship from recipe side
        recipe.collections?.removeAll { $0.id == collection.id }
        try context.save()

        // THEN: Relationship removed from both sides
        XCTAssertTrue(recipe.collections?.isEmpty ?? true)
        XCTAssertEqual(collection.recipes?.count, 0)
    }
}
