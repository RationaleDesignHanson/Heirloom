import Testing
import Foundation
import SwiftData
@testable import Heirloom

/// Integration tests for Recipe many-to-many relationships with Tags and RecipeCollections
/// Tests bidirectional updates, deletion behavior, and relationship integrity
@Suite("Recipe Relationship Tests")
struct RecipeRelationshipTests {
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.Tag.self,
            Heirloom.RecipeCollection.self,
            Heirloom.Ingredient.self,
            Heirloom.CardStyle.self,
            Heirloom.Sticker.self,
            Heirloom.Annotation.self,
            Heirloom.Substitution.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        context = ModelContext(container)
    }

    // MARK: - Recipe-Tag Relationship Tests

    @Test("Adding tag to recipe updates both sides of relationship")
    func testRecipeTag_AddTag_UpdatesBothSides() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let tag = Heirloom.Tag(name: "Dessert", color: "#FF6B6B")

        context.insert(recipe)
        context.insert(tag)
        try context.save()

        // Act - add tag to recipe
        if recipe.tags == nil {
            recipe.tags = []
        }
        recipe.tags?.append(tag)
        try context.save()

        // Assert - both sides should be updated
        #expect(recipe.tags?.count == 1, "Recipe should have 1 tag")
        #expect(recipe.tags?.first?.id == tag.id, "Recipe should have the correct tag")
        #expect(tag.recipes?.count == 1, "Tag should have 1 recipe")
        #expect(tag.recipes?.first?.id == recipe.id, "Tag should reference the recipe")
    }

    @Test("Adding recipe to tag updates both sides of relationship")
    func testRecipeTag_AddRecipeToTag_UpdatesBothSides() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let tag = Heirloom.Tag(name: "Breakfast", color: "#4ECDC4")

        context.insert(recipe)
        context.insert(tag)
        try context.save()

        // Act - add recipe to tag
        if tag.recipes == nil {
            tag.recipes = []
        }
        tag.recipes?.append(recipe)
        try context.save()

        // Assert - both sides should be updated
        #expect(tag.recipes?.count == 1, "Tag should have 1 recipe")
        #expect(tag.recipes?.first?.id == recipe.id, "Tag should reference the recipe")
        #expect(recipe.tags?.count == 1, "Recipe should have 1 tag")
        #expect(recipe.tags?.first?.id == tag.id, "Recipe should have the tag")
    }

    @Test("Recipe can have multiple tags")
    func testRecipeTag_MultipleTags() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Breakfast Smoothie")
        let tag1 = Heirloom.Tag(name: "Breakfast", color: "#FF6B6B")
        let tag2 = Heirloom.Tag(name: "Healthy", color: "#4ECDC4")
        let tag3 = Heirloom.Tag(name: "Quick", color: "#FFD93D")

        context.insert(recipe)
        context.insert(tag1)
        context.insert(tag2)
        context.insert(tag3)
        try context.save()

        // Act - add multiple tags
        recipe.tags = [tag1, tag2, tag3]
        try context.save()

        // Assert
        #expect(recipe.tags?.count == 3, "Recipe should have 3 tags")
        #expect(tag1.recipes?.contains(where: { $0.id == recipe.id }) == true)
        #expect(tag2.recipes?.contains(where: { $0.id == recipe.id }) == true)
        #expect(tag3.recipes?.contains(where: { $0.id == recipe.id }) == true)
    }

    @Test("Tag can have multiple recipes")
    func testRecipeTag_MultipleRecipes() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Vegetarian", color: "#6BCF7F")
        let recipe1 = Heirloom.Recipe(title: "Veggie Pasta")
        let recipe2 = Heirloom.Recipe(title: "Garden Salad")
        let recipe3 = Heirloom.Recipe(title: "Tofu Stir Fry")

        context.insert(tag)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act - add multiple recipes to tag
        tag.recipes = [recipe1, recipe2, recipe3]
        try context.save()

        // Assert
        #expect(tag.recipes?.count == 3, "Tag should have 3 recipes")
        #expect(recipe1.tags?.contains(where: { $0.id == tag.id }) == true)
        #expect(recipe2.tags?.contains(where: { $0.id == tag.id }) == true)
        #expect(recipe3.tags?.contains(where: { $0.id == tag.id }) == true)
    }

    @Test("Removing tag from recipe updates both sides")
    func testRecipeTag_RemoveTag_UpdatesBothSides() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let tag1 = Heirloom.Tag(name: "Keep", color: "#FF6B6B")
        let tag2 = Heirloom.Tag(name: "Remove", color: "#4ECDC4")

        context.insert(recipe)
        context.insert(tag1)
        context.insert(tag2)
        recipe.tags = [tag1, tag2]
        try context.save()

        let tag2Id = tag2.id

        // Act - remove tag2 from recipe
        recipe.tags = recipe.tags?.filter { $0.id != tag2Id }
        try context.save()

        // Assert
        #expect(recipe.tags?.count == 1, "Recipe should have 1 tag remaining")
        #expect(recipe.tags?.first?.name == "Keep", "Recipe should keep tag1")

        // Fetch tag2 to verify its recipes list is updated
        let tag2Fetch = FetchDescriptor<Heirloom.Tag>(
            predicate: #Predicate { $0.id == tag2Id }
        )
        let fetchedTag2 = try #require(try context.fetch(tag2Fetch).first)
        #expect(fetchedTag2.recipes?.contains(where: { $0.id == recipe.id }) == false,
                "Tag2 should not reference the recipe anymore")
    }

    @Test("Deleting recipe removes it from tag's recipes list")
    func testRecipeTag_DeleteRecipe_RemovesFromTag() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let tag = Heirloom.Tag(name: "Test Tag", color: "#FF6B6B")

        context.insert(recipe)
        context.insert(tag)
        recipe.tags = [tag]
        try context.save()

        let recipeId = recipe.id
        let tagId = tag.id

        // Act - delete recipe
        context.delete(recipe)
        try context.save()

        // Assert - recipe is deleted
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipeId }
        )
        #expect(try context.fetch(recipeFetch).isEmpty, "Recipe should be deleted")

        // Tag should still exist but without the recipe
        let tagFetch = FetchDescriptor<Heirloom.Tag>(
            predicate: #Predicate { $0.id == tagId }
        )
        let fetchedTag = try #require(try context.fetch(tagFetch).first)
        #expect(fetchedTag.recipes?.isEmpty ?? true, "Tag should have no recipes")
    }

    @Test("Deleting tag removes it from recipe's tags list")
    func testRecipeTag_DeleteTag_RemovesFromRecipe() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let tag = Heirloom.Tag(name: "Test Tag", color: "#FF6B6B")

        context.insert(recipe)
        context.insert(tag)
        recipe.tags = [tag]
        try context.save()

        let recipeId = recipe.id
        let tagId = tag.id

        // Act - delete tag
        context.delete(tag)
        try context.save()

        // Assert - tag is deleted
        let tagFetch = FetchDescriptor<Heirloom.Tag>(
            predicate: #Predicate { $0.id == tagId }
        )
        #expect(try context.fetch(tagFetch).isEmpty, "Tag should be deleted")

        // Recipe should still exist but without the tag
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipeId }
        )
        let fetchedRecipe = try #require(try context.fetch(recipeFetch).first)
        #expect(fetchedRecipe.tags?.isEmpty ?? true, "Recipe should have no tags")
    }

    // MARK: - Recipe-Collection Relationship Tests

    @Test("Adding recipe to collection updates both sides of relationship")
    func testRecipeCollection_AddRecipe_UpdatesBothSides() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let collection = Heirloom.RecipeCollection(name: "Favorites", color: "#FF6B6B")

        context.insert(recipe)
        context.insert(collection)
        try context.save()

        // Act - add recipe to collection
        if collection.recipes == nil {
            collection.recipes = []
        }
        collection.recipes?.append(recipe)
        try context.save()

        // Assert - both sides should be updated
        #expect(collection.recipes?.count == 1, "Collection should have 1 recipe")
        #expect(collection.recipes?.first?.id == recipe.id, "Collection should have the correct recipe")
        #expect(recipe.collections?.count == 1, "Recipe should be in 1 collection")
        #expect(recipe.collections?.first?.id == collection.id, "Recipe should reference the collection")
    }

    @Test("Adding collection to recipe updates both sides of relationship")
    func testRecipeCollection_AddCollectionToRecipe_UpdatesBothSides() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let collection = Heirloom.RecipeCollection(name: "Summer", color: "#FFD93D")

        context.insert(recipe)
        context.insert(collection)
        try context.save()

        // Act - add collection to recipe
        if recipe.collections == nil {
            recipe.collections = []
        }
        recipe.collections?.append(collection)
        try context.save()

        // Assert - both sides should be updated
        #expect(recipe.collections?.count == 1, "Recipe should be in 1 collection")
        #expect(recipe.collections?.first?.id == collection.id, "Recipe should reference the collection")
        #expect(collection.recipes?.count == 1, "Collection should have 1 recipe")
        #expect(collection.recipes?.first?.id == recipe.id, "Collection should have the recipe")
    }

    @Test("Recipe can be in multiple collections")
    func testRecipeCollection_MultipleCollections() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Classic Pasta")
        let collection1 = Heirloom.RecipeCollection(name: "Italian", color: "#FF6B6B")
        let collection2 = Heirloom.RecipeCollection(name: "Quick Meals", color: "#4ECDC4")
        let collection3 = Heirloom.RecipeCollection(name: "Family Favorites", color: "#FFD93D")

        context.insert(recipe)
        context.insert(collection1)
        context.insert(collection2)
        context.insert(collection3)
        try context.save()

        // Act - add recipe to multiple collections
        recipe.collections = [collection1, collection2, collection3]
        try context.save()

        // Assert
        #expect(recipe.collections?.count == 3, "Recipe should be in 3 collections")
        #expect(collection1.recipes?.contains(where: { $0.id == recipe.id }) == true)
        #expect(collection2.recipes?.contains(where: { $0.id == recipe.id }) == true)
        #expect(collection3.recipes?.contains(where: { $0.id == recipe.id }) == true)
    }

    @Test("Collection can have multiple recipes")
    func testRecipeCollection_MultipleRecipes() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Baking", color: "#FCBAD3")
        let recipe1 = Heirloom.Recipe(title: "Chocolate Cake")
        let recipe2 = Heirloom.Recipe(title: "Banana Bread")
        let recipe3 = Heirloom.Recipe(title: "Oatmeal Cookies")

        context.insert(collection)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act - add multiple recipes to collection
        collection.recipes = [recipe1, recipe2, recipe3]
        try context.save()

        // Assert
        #expect(collection.recipes?.count == 3, "Collection should have 3 recipes")
        #expect(recipe1.collections?.contains(where: { $0.id == collection.id }) == true)
        #expect(recipe2.collections?.contains(where: { $0.id == collection.id }) == true)
        #expect(recipe3.collections?.contains(where: { $0.id == collection.id }) == true)
    }

    @Test("Removing recipe from collection updates both sides")
    func testRecipeCollection_RemoveRecipe_UpdatesBothSides() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Test Collection", color: "#FF6B6B")
        let recipe1 = Heirloom.Recipe(title: "Keep Recipe")
        let recipe2 = Heirloom.Recipe(title: "Remove Recipe")

        context.insert(collection)
        context.insert(recipe1)
        context.insert(recipe2)
        collection.recipes = [recipe1, recipe2]
        try context.save()

        let recipe2Id = recipe2.id

        // Act - remove recipe2 from collection
        collection.recipes = collection.recipes?.filter { $0.id != recipe2Id }
        try context.save()

        // Assert
        #expect(collection.recipes?.count == 1, "Collection should have 1 recipe remaining")
        #expect(collection.recipes?.first?.title == "Keep Recipe", "Collection should keep recipe1")

        // Fetch recipe2 to verify its collections list is updated
        let recipe2Fetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipe2Id }
        )
        let fetchedRecipe2 = try #require(try context.fetch(recipe2Fetch).first)
        #expect(fetchedRecipe2.collections?.contains(where: { $0.id == collection.id }) == false,
                "Recipe2 should not be in the collection anymore")
    }

    @Test("Deleting recipe removes it from all collections")
    func testRecipeCollection_DeleteRecipe_RemovesFromAllCollections() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let collection1 = Heirloom.RecipeCollection(name: "Collection 1", color: "#FF6B6B")
        let collection2 = Heirloom.RecipeCollection(name: "Collection 2", color: "#4ECDC4")
        let collection3 = Heirloom.RecipeCollection(name: "Collection 3", color: "#FFD93D")

        context.insert(recipe)
        context.insert(collection1)
        context.insert(collection2)
        context.insert(collection3)
        recipe.collections = [collection1, collection2, collection3]
        try context.save()

        let recipeId = recipe.id
        let collectionIds = [collection1.id, collection2.id, collection3.id]

        // Act - delete recipe
        context.delete(recipe)
        try context.save()

        // Assert - recipe is deleted
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipeId }
        )
        #expect(try context.fetch(recipeFetch).isEmpty, "Recipe should be deleted")

        // All collections should still exist but without the recipe
        for collectionId in collectionIds {
            let collectionFetch = FetchDescriptor<Heirloom.RecipeCollection>(
                predicate: #Predicate { $0.id == collectionId }
            )
            let fetchedCollection = try #require(try context.fetch(collectionFetch).first)
            #expect(fetchedCollection.recipes?.isEmpty ?? true,
                    "Collection \(fetchedCollection.name) should have no recipes")
        }
    }

    @Test("Deleting collection does not delete recipes")
    func testRecipeCollection_DeleteCollection_PreservesRecipes() throws {
        // Arrange
        let collection = Heirloom.RecipeCollection(name: "Test Collection", color: "#FF6B6B")
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")

        context.insert(collection)
        context.insert(recipe1)
        context.insert(recipe2)
        collection.recipes = [recipe1, recipe2]
        try context.save()

        let collectionId = collection.id
        let recipe1Id = recipe1.id
        let recipe2Id = recipe2.id

        // Act - delete collection
        context.delete(collection)
        try context.save()

        // Assert - collection is deleted
        let collectionFetch = FetchDescriptor<Heirloom.RecipeCollection>(
            predicate: #Predicate { $0.id == collectionId }
        )
        #expect(try context.fetch(collectionFetch).isEmpty, "Collection should be deleted")

        // Recipes should still exist but without the collection
        let recipe1Fetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipe1Id }
        )
        let fetchedRecipe1 = try #require(try context.fetch(recipe1Fetch).first)
        #expect(fetchedRecipe1.collections?.isEmpty ?? true, "Recipe 1 should have no collections")

        let recipe2Fetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipe2Id }
        )
        let fetchedRecipe2 = try #require(try context.fetch(recipe2Fetch).first)
        #expect(fetchedRecipe2.collections?.isEmpty ?? true, "Recipe 2 should have no collections")
    }

    // MARK: - Complex Relationship Tests

    @Test("Recipe with both tags and collections maintains independent relationships")
    func testRecipe_TagsAndCollections_IndependentRelationships() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Complex Recipe")
        let tag1 = Heirloom.Tag(name: "Vegetarian", color: "#6BCF7F")
        let tag2 = Heirloom.Tag(name: "Quick", color: "#FFD93D")
        let collection1 = Heirloom.RecipeCollection(name: "Favorites", color: "#FF6B6B")
        let collection2 = Heirloom.RecipeCollection(name: "Weeknight", color: "#4ECDC4")

        context.insert(recipe)
        context.insert(tag1)
        context.insert(tag2)
        context.insert(collection1)
        context.insert(collection2)

        recipe.tags = [tag1, tag2]
        recipe.collections = [collection1, collection2]
        try context.save()

        // Assert - all relationships are established
        #expect(recipe.tags?.count == 2, "Recipe should have 2 tags")
        #expect(recipe.collections?.count == 2, "Recipe should be in 2 collections")

        // Remove a tag and verify collections are unaffected
        recipe.tags = [tag1]
        try context.save()

        #expect(recipe.tags?.count == 1, "Recipe should have 1 tag")
        #expect(recipe.collections?.count == 2, "Recipe should still be in 2 collections")

        // Remove a collection and verify tags are unaffected
        recipe.collections = [collection1]
        try context.save()

        #expect(recipe.tags?.count == 1, "Recipe should still have 1 tag")
        #expect(recipe.collections?.count == 1, "Recipe should be in 1 collection")
    }

    @Test("Multiple recipes sharing tags and collections maintain independent relationships")
    func testMultipleRecipes_SharedTagsAndCollections_IndependentRelationships() throws {
        // Arrange
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")
        let sharedTag = Heirloom.Tag(name: "Shared Tag", color: "#FF6B6B")
        let sharedCollection = Heirloom.RecipeCollection(name: "Shared Collection", color: "#4ECDC4")

        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(sharedTag)
        context.insert(sharedCollection)

        recipe1.tags = [sharedTag]
        recipe1.collections = [sharedCollection]
        recipe2.tags = [sharedTag]
        recipe2.collections = [sharedCollection]
        try context.save()

        // Assert - both recipes share the tag and collection
        #expect(sharedTag.recipes?.count == 2, "Tag should be used by 2 recipes")
        #expect(sharedCollection.recipes?.count == 2, "Collection should contain 2 recipes")

        // Remove tag from recipe1 and verify recipe2 still has it
        recipe1.tags = []
        try context.save()

        #expect(recipe1.tags?.isEmpty ?? true, "Recipe 1 should have no tags")
        #expect(recipe2.tags?.count == 1, "Recipe 2 should still have the tag")
        #expect(sharedTag.recipes?.count == 1, "Tag should now be used by 1 recipe")

        // Remove recipe2 from collection and verify recipe1 still in it
        recipe2.collections = []
        try context.save()

        #expect(recipe2.collections?.isEmpty ?? true, "Recipe 2 should not be in any collections")
        #expect(recipe1.collections?.count == 1, "Recipe 1 should still be in the collection")
        #expect(sharedCollection.recipes?.count == 1, "Collection should now contain 1 recipe")
    }
}
