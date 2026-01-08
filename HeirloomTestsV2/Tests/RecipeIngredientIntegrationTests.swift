import Testing
import Foundation
import SwiftData
@testable import Heirloom

/// Integration tests for Recipe-Ingredient relationship
/// Tests cascade deletes, orphan cleanup, batch operations, and data isolation
@Suite("Recipe-Ingredient Integration Tests")
struct RecipeIngredientIntegrationTests {
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.Ingredient.self,
            Heirloom.Tag.self,
            Heirloom.RecipeCollection.self,
            Heirloom.CardStyle.self,
            Heirloom.Sticker.self,
            Heirloom.Annotation.self,
            Heirloom.Substitution.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        context = ModelContext(container)
    }

    // MARK: - Cascade Delete Tests

    @Test("Recipe deletion cascades to single ingredient")
    func testRecipe_Delete_CascadesSingleIngredient() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let ingredient = Heirloom.Ingredient(
            originalText: "2 cups flour",
            name: "flour",
            quantity: 2,
            unit: "cups"
        )
        ingredient.recipe = recipe
        recipe.ingredients = [ingredient]

        context.insert(recipe)
        context.insert(ingredient)
        try context.save()

        let recipeId = recipe.id
        let ingredientId = ingredient.id

        // Verify setup
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipeId }
        )
        #expect(try context.fetch(recipeFetch).count == 1)

        let ingredientFetch = FetchDescriptor<Heirloom.Ingredient>(
            predicate: #Predicate { $0.id == ingredientId }
        )
        #expect(try context.fetch(ingredientFetch).count == 1)

        // Act - delete recipe
        context.delete(recipe)
        try context.save()

        // Assert - ingredient should be cascade deleted
        let recipesAfter = try context.fetch(recipeFetch)
        #expect(recipesAfter.isEmpty, "Recipe should be deleted")

        let ingredientsAfter = try context.fetch(ingredientFetch)
        #expect(ingredientsAfter.isEmpty, "Ingredient should be cascade deleted with recipe")
    }

    @Test("Recipe deletion cascades to multiple ingredients")
    func testRecipe_Delete_CascadesMultipleIngredients() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Pasta Recipe")
        let ingredients = [
            Heirloom.Ingredient(originalText: "1 lb pasta", name: "pasta", quantity: 1, unit: "lb", orderIndex: 0),
            Heirloom.Ingredient(originalText: "2 cups sauce", name: "sauce", quantity: 2, unit: "cups", orderIndex: 1),
            Heirloom.Ingredient(originalText: "1/2 cup cheese", name: "cheese", quantity: 0.5, unit: "cup", orderIndex: 2)
        ]

        ingredients.forEach { $0.recipe = recipe }
        recipe.ingredients = ingredients

        context.insert(recipe)
        ingredients.forEach { context.insert($0) }
        try context.save()

        let recipeId = recipe.id
        let ingredientIds = ingredients.map { $0.id }

        // Verify setup
        let allIngredientsFetch = FetchDescriptor<Heirloom.Ingredient>()
        let initialCount = try context.fetch(allIngredientsFetch).count
        #expect(initialCount >= 3, "Should have at least 3 ingredients")

        // Act - delete recipe
        context.delete(recipe)
        try context.save()

        // Assert - all ingredients should be cascade deleted
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipeId }
        )
        #expect(try context.fetch(recipeFetch).isEmpty, "Recipe should be deleted")

        for ingredientId in ingredientIds {
            let ingredientFetch = FetchDescriptor<Heirloom.Ingredient>(
                predicate: #Predicate { $0.id == ingredientId }
            )
            let result = try context.fetch(ingredientFetch)
            #expect(result.isEmpty, "Ingredient \(ingredientId) should be cascade deleted")
        }
    }

    @Test("Recipe deletion with ingredients does not affect other recipes")
    func testRecipe_Delete_DoesNotAffectOtherRecipes() throws {
        // Arrange - create two recipes with ingredients
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let ingredient1 = Heirloom.Ingredient(originalText: "flour", name: "flour")
        ingredient1.recipe = recipe1
        recipe1.ingredients = [ingredient1]

        let recipe2 = Heirloom.Recipe(title: "Recipe 2")
        let ingredient2 = Heirloom.Ingredient(originalText: "sugar", name: "sugar")
        ingredient2.recipe = recipe2
        recipe2.ingredients = [ingredient2]

        context.insert(recipe1)
        context.insert(ingredient1)
        context.insert(recipe2)
        context.insert(ingredient2)
        try context.save()

        let recipe2Id = recipe2.id
        let ingredient2Id = ingredient2.id

        // Act - delete first recipe
        context.delete(recipe1)
        try context.save()

        // Assert - second recipe and its ingredient should remain
        let recipe2Fetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipe2Id }
        )
        let recipe2Result = try context.fetch(recipe2Fetch)
        #expect(recipe2Result.count == 1, "Recipe 2 should still exist")

        let ingredient2Fetch = FetchDescriptor<Heirloom.Ingredient>(
            predicate: #Predicate { $0.id == ingredient2Id }
        )
        let ingredient2Result = try context.fetch(ingredient2Fetch)
        #expect(ingredient2Result.count == 1, "Recipe 2's ingredient should still exist")
    }

    // MARK: - Orphan Ingredient Tests

    @Test("Ingredient without recipe can exist temporarily but should have nil recipe")
    func testIngredient_WithoutRecipe_HasNilRecipe() throws {
        // Arrange & Act - create ingredient without recipe
        let ingredient = Heirloom.Ingredient(originalText: "orphan ingredient", name: "orphan")

        context.insert(ingredient)
        try context.save()

        // Assert - ingredient exists but has no recipe
        #expect(ingredient.recipe == nil, "Ingredient should have nil recipe")

        let fetch = FetchDescriptor<Heirloom.Ingredient>()
        let allIngredients = try context.fetch(fetch)
        #expect(allIngredients.contains(where: { $0.id == ingredient.id }), "Orphan ingredient should exist in context")
    }

    @Test("Removing recipe reference from ingredient sets recipe to nil")
    func testIngredient_RemoveRecipeReference_SetsNil() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let ingredient = Heirloom.Ingredient(originalText: "test", name: "test")
        ingredient.recipe = recipe
        recipe.ingredients = [ingredient]

        context.insert(recipe)
        context.insert(ingredient)
        try context.save()

        #expect(ingredient.recipe != nil, "Ingredient should initially have recipe")

        // Act - remove recipe reference
        ingredient.recipe = nil
        recipe.ingredients = []
        try context.save()

        // Assert
        #expect(ingredient.recipe == nil, "Recipe reference should be nil")
    }

    // MARK: - OrderIndex Consistency Tests

    @Test("Multiple ingredients maintain correct orderIndex sequence")
    func testIngredients_MultipleIngredients_MaintainOrderIndex() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Multi-Ingredient Recipe")
        let ingredients = [
            Heirloom.Ingredient(originalText: "first", name: "first", orderIndex: 0),
            Heirloom.Ingredient(originalText: "second", name: "second", orderIndex: 1),
            Heirloom.Ingredient(originalText: "third", name: "third", orderIndex: 2),
            Heirloom.Ingredient(originalText: "fourth", name: "fourth", orderIndex: 3),
            Heirloom.Ingredient(originalText: "fifth", name: "fifth", orderIndex: 4)
        ]

        ingredients.forEach { $0.recipe = recipe }
        recipe.ingredients = ingredients

        context.insert(recipe)
        ingredients.forEach { context.insert($0) }
        try context.save()

        // Act - fetch recipe and verify order
        let recipeId = recipe.id
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipeId }
        )
        let fetchedRecipes = try context.fetch(recipeFetch)
        let fetchedRecipe = try #require(fetchedRecipes.first)

        // Assert - orderIndex should be sequential
        let sortedIngredients = (fetchedRecipe.ingredients ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(sortedIngredients.count == 5, "Should have 5 ingredients")

        for (index, ingredient) in sortedIngredients.enumerated() {
            #expect(ingredient.orderIndex == index, "Ingredient at position \(index) should have orderIndex \(index)")
        }
    }

    @Test("Adding ingredient maintains orderIndex sequence")
    func testIngredients_AddIngredient_MaintainsOrderIndex() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Recipe")
        let ingredient1 = Heirloom.Ingredient(originalText: "first", name: "first", orderIndex: 0)
        let ingredient2 = Heirloom.Ingredient(originalText: "second", name: "second", orderIndex: 1)
        ingredient1.recipe = recipe
        ingredient2.recipe = recipe
        recipe.ingredients = [ingredient1, ingredient2]

        context.insert(recipe)
        context.insert(ingredient1)
        context.insert(ingredient2)
        try context.save()

        // Act - add third ingredient
        let ingredient3 = Heirloom.Ingredient(originalText: "third", name: "third", orderIndex: 2)
        ingredient3.recipe = recipe
        recipe.ingredients?.append(ingredient3)
        context.insert(ingredient3)
        try context.save()

        // Assert
        let sortedIngredients = (recipe.ingredients ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(sortedIngredients.count == 3, "Should have 3 ingredients")
        #expect(sortedIngredients[0].orderIndex == 0)
        #expect(sortedIngredients[1].orderIndex == 1)
        #expect(sortedIngredients[2].orderIndex == 2)
    }

    @Test("Removing middle ingredient maintains orderIndex integrity")
    func testIngredients_RemoveMiddleIngredient_MaintainsIntegrity() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Recipe")
        let ingredient1 = Heirloom.Ingredient(originalText: "first", name: "first", orderIndex: 0)
        let ingredient2 = Heirloom.Ingredient(originalText: "second", name: "second", orderIndex: 1)
        let ingredient3 = Heirloom.Ingredient(originalText: "third", name: "third", orderIndex: 2)

        ingredient1.recipe = recipe
        ingredient2.recipe = recipe
        ingredient3.recipe = recipe
        recipe.ingredients = [ingredient1, ingredient2, ingredient3]

        context.insert(recipe)
        context.insert(ingredient1)
        context.insert(ingredient2)
        context.insert(ingredient3)
        try context.save()

        let ingredient2Id = ingredient2.id

        // Act - remove middle ingredient
        context.delete(ingredient2)
        recipe.ingredients = [ingredient1, ingredient3]
        try context.save()

        // Assert - deleted ingredient is gone
        let ingredient2Fetch = FetchDescriptor<Heirloom.Ingredient>(
            predicate: #Predicate { $0.id == ingredient2Id }
        )
        #expect(try context.fetch(ingredient2Fetch).isEmpty, "Middle ingredient should be deleted")

        // Remaining ingredients maintain their orderIndex
        #expect(ingredient1.orderIndex == 0)
        #expect(ingredient3.orderIndex == 2, "Third ingredient keeps orderIndex 2 (gap is acceptable)")
    }

    @Test("Reordering ingredients updates orderIndex correctly")
    func testIngredients_Reorder_UpdatesOrderIndex() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Recipe")
        let ingredient1 = Heirloom.Ingredient(originalText: "first", name: "first", orderIndex: 0)
        let ingredient2 = Heirloom.Ingredient(originalText: "second", name: "second", orderIndex: 1)
        let ingredient3 = Heirloom.Ingredient(originalText: "third", name: "third", orderIndex: 2)

        ingredient1.recipe = recipe
        ingredient2.recipe = recipe
        ingredient3.recipe = recipe
        recipe.ingredients = [ingredient1, ingredient2, ingredient3]

        context.insert(recipe)
        context.insert(ingredient1)
        context.insert(ingredient2)
        context.insert(ingredient3)
        try context.save()

        // Act - reorder: swap first and third
        ingredient1.orderIndex = 2
        ingredient3.orderIndex = 0
        // ingredient2 stays at 1
        try context.save()

        // Assert - new order should be: ingredient3(0), ingredient2(1), ingredient1(2)
        let sortedIngredients = (recipe.ingredients ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(sortedIngredients[0].name == "third")
        #expect(sortedIngredients[1].name == "second")
        #expect(sortedIngredients[2].name == "first")
    }

    // MARK: - Batch Operations Tests

    @Test("Adding multiple ingredients in batch preserves all ingredients")
    func testIngredients_BatchAdd_PreservesAll() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Batch Recipe")
        context.insert(recipe)
        try context.save()

        // Act - add 10 ingredients in batch
        var ingredients: [Heirloom.Ingredient] = []
        for i in 0..<10 {
            let ingredient = Heirloom.Ingredient(
                originalText: "ingredient \(i)",
                name: "ingredient \(i)",
                orderIndex: i
            )
            ingredient.recipe = recipe
            ingredients.append(ingredient)
            context.insert(ingredient)
        }
        recipe.ingredients = ingredients
        try context.save()

        // Assert
        let recipeId = recipe.id
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipeId }
        )
        let fetchedRecipes = try context.fetch(recipeFetch)
        let fetchedRecipe = try #require(fetchedRecipes.first)

        #expect(fetchedRecipe.ingredients?.count == 10, "Should have 10 ingredients")

        let sortedIngredients = (fetchedRecipe.ingredients ?? []).sorted { $0.orderIndex < $1.orderIndex }
        for (index, ingredient) in sortedIngredients.enumerated() {
            #expect(ingredient.orderIndex == index, "Ingredient should have orderIndex \(index)")
            #expect(ingredient.name == "ingredient \(index)", "Ingredient name should match")
        }
    }

    @Test("Deleting multiple ingredients in batch preserves remaining ingredients")
    func testIngredients_BatchDelete_PreservesRemaining() throws {
        // Arrange - create recipe with 5 ingredients
        let recipe = Heirloom.Recipe(title: "Recipe")
        var ingredients: [Heirloom.Ingredient] = []
        for i in 0..<5 {
            let ingredient = Heirloom.Ingredient(
                originalText: "ingredient \(i)",
                name: "ingredient \(i)",
                orderIndex: i
            )
            ingredient.recipe = recipe
            ingredients.append(ingredient)
            context.insert(ingredient)
        }
        recipe.ingredients = ingredients
        context.insert(recipe)
        try context.save()

        // Act - delete ingredients at index 1 and 3
        let toDelete = [ingredients[1], ingredients[3]]
        let toDeleteIds = toDelete.map { $0.id }
        toDelete.forEach { context.delete($0) }
        recipe.ingredients = [ingredients[0], ingredients[2], ingredients[4]]
        try context.save()

        // Assert - deleted ingredients are gone
        for id in toDeleteIds {
            let fetch = FetchDescriptor<Heirloom.Ingredient>(
                predicate: #Predicate { $0.id == id }
            )
            #expect(try context.fetch(fetch).isEmpty, "Deleted ingredient should not exist")
        }

        // Remaining ingredients still exist
        #expect(recipe.ingredients?.count == 3, "Should have 3 remaining ingredients")
        let remainingNames = Set(recipe.ingredients?.map { $0.name } ?? [])
        #expect(remainingNames.contains("ingredient 0"))
        #expect(remainingNames.contains("ingredient 2"))
        #expect(remainingNames.contains("ingredient 4"))
    }

    @Test("Updating multiple ingredients in batch preserves changes")
    func testIngredients_BatchUpdate_PreservesChanges() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Recipe")
        var ingredients: [Heirloom.Ingredient] = []
        var ingredientIds: [UUID] = []

        for i in 0..<3 {
            let ingredient = Heirloom.Ingredient(
                originalText: "ingredient \(i)",
                name: "ingredient \(i)",
                quantity: Double(i),
                unit: "unit",
                orderIndex: i
            )
            ingredient.recipe = recipe
            ingredients.append(ingredient)
            ingredientIds.append(ingredient.id)
            context.insert(ingredient)
        }
        recipe.ingredients = ingredients
        context.insert(recipe)
        try context.save()

        // Act - update all ingredient quantities directly through fetched instances
        for (index, id) in ingredientIds.enumerated() {
            let ingredientFetch = FetchDescriptor<Heirloom.Ingredient>(
                predicate: #Predicate<Heirloom.Ingredient> { $0.id == id }
            )
            if let fetchedIngredient = try context.fetch(ingredientFetch).first {
                fetchedIngredient.quantity = Double((index + 1) * 10)  // 10, 20, 30
            }
        }
        try context.save()

        // Assert - fetch recipe and verify updated quantities
        let recipeId = recipe.id
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipeId }
        )
        let fetchedRecipes = try context.fetch(recipeFetch)
        let fetchedRecipe = try #require(fetchedRecipes.first)

        let fetchedIngredients = (fetchedRecipe.ingredients ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(fetchedIngredients.count == 3, "Should have 3 ingredients")
        #expect(fetchedIngredients[0].quantity == 10.0, "First ingredient should be 10.0")
        #expect(fetchedIngredients[1].quantity == 20.0, "Second ingredient should be 20.0")
        #expect(fetchedIngredients[2].quantity == 30.0, "Third ingredient should be 30.0")
    }

    // MARK: - Isolation Tests

    @Test("Updating ingredient on one recipe does not affect another recipe")
    func testIngredient_Update_IsolatedToRecipe() throws {
        // Arrange - two recipes with similar ingredient names
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let ingredient1 = Heirloom.Ingredient(
            originalText: "2 cups flour",
            name: "flour",
            quantity: 2,
            unit: "cups"
        )
        ingredient1.recipe = recipe1
        recipe1.ingredients = [ingredient1]

        let recipe2 = Heirloom.Recipe(title: "Recipe 2")
        let ingredient2 = Heirloom.Ingredient(
            originalText: "3 cups flour",
            name: "flour",
            quantity: 3,
            unit: "cups"
        )
        ingredient2.recipe = recipe2
        recipe2.ingredients = [ingredient2]

        context.insert(recipe1)
        context.insert(ingredient1)
        context.insert(recipe2)
        context.insert(ingredient2)
        try context.save()

        let ingredient2Id = ingredient2.id

        // Act - update ingredient1
        ingredient1.quantity = 5.0
        ingredient1.name = "updated flour"
        try context.save()

        // Assert - ingredient2 should remain unchanged
        let ingredient2Fetch = FetchDescriptor<Heirloom.Ingredient>(
            predicate: #Predicate { $0.id == ingredient2Id }
        )
        let fetchedIngredient2 = try #require(try context.fetch(ingredient2Fetch).first)

        #expect(fetchedIngredient2.quantity == 3.0, "Recipe 2's ingredient should still have quantity 3")
        #expect(fetchedIngredient2.name == "flour", "Recipe 2's ingredient should still be named 'flour'")
        #expect(ingredient1.quantity == 5.0, "Recipe 1's ingredient should be updated")
    }

    @Test("Deleting recipe does not affect ingredients from other recipes")
    func testRecipe_Delete_IsolatedFromOtherRecipeIngredients() throws {
        // Arrange - three recipes
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let ingredient1a = Heirloom.Ingredient(originalText: "flour", name: "flour")
        let ingredient1b = Heirloom.Ingredient(originalText: "sugar", name: "sugar")
        ingredient1a.recipe = recipe1
        ingredient1b.recipe = recipe1
        recipe1.ingredients = [ingredient1a, ingredient1b]

        let recipe2 = Heirloom.Recipe(title: "Recipe 2")
        let ingredient2 = Heirloom.Ingredient(originalText: "eggs", name: "eggs")
        ingredient2.recipe = recipe2
        recipe2.ingredients = [ingredient2]

        let recipe3 = Heirloom.Recipe(title: "Recipe 3")
        let ingredient3 = Heirloom.Ingredient(originalText: "milk", name: "milk")
        ingredient3.recipe = recipe3
        recipe3.ingredients = [ingredient3]

        context.insert(recipe1)
        context.insert(ingredient1a)
        context.insert(ingredient1b)
        context.insert(recipe2)
        context.insert(ingredient2)
        context.insert(recipe3)
        context.insert(ingredient3)
        try context.save()

        let ingredient2Id = ingredient2.id
        let ingredient3Id = ingredient3.id

        // Act - delete recipe1
        context.delete(recipe1)
        try context.save()

        // Assert - recipe2 and recipe3 ingredients unaffected
        let ingredient2Fetch = FetchDescriptor<Heirloom.Ingredient>(
            predicate: #Predicate { $0.id == ingredient2Id }
        )
        #expect(try context.fetch(ingredient2Fetch).count == 1, "Recipe 2's ingredient should exist")

        let ingredient3Fetch = FetchDescriptor<Heirloom.Ingredient>(
            predicate: #Predicate { $0.id == ingredient3Id }
        )
        #expect(try context.fetch(ingredient3Fetch).count == 1, "Recipe 3's ingredient should exist")
    }

    @Test("Multiple recipes can have ingredients with same name independently")
    func testIngredients_SameName_IndependentAcrossRecipes() throws {
        // Arrange - 3 recipes all with "flour" ingredient but different quantities
        let recipes: [(Heirloom.Recipe, Heirloom.Ingredient)] = [
            (Heirloom.Recipe(title: "Cookies"), Heirloom.Ingredient(name: "flour", quantity: 2)),
            (Heirloom.Recipe(title: "Bread"), Heirloom.Ingredient(name: "flour", quantity: 4)),
            (Heirloom.Recipe(title: "Cake"), Heirloom.Ingredient(name: "flour", quantity: 3))
        ]

        for (recipe, ingredient) in recipes {
            ingredient.recipe = recipe
            recipe.ingredients = [ingredient]
            context.insert(recipe)
            context.insert(ingredient)
        }
        try context.save()

        // Act - update one ingredient
        recipes[0].1.quantity = 10.0
        try context.save()

        // Assert - each ingredient maintains its own quantity
        #expect(recipes[0].1.quantity == 10.0, "First recipe's flour should be updated")
        #expect(recipes[1].1.quantity == 4.0, "Second recipe's flour should be unchanged")
        #expect(recipes[2].1.quantity == 3.0, "Third recipe's flour should be unchanged")

        // All ingredients still named "flour"
        for (_, ingredient) in recipes {
            #expect(ingredient.name == "flour")
        }
    }
}
