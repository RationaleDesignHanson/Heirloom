import Testing
import Foundation
import SwiftData

@testable import Heirloom

@Suite("Cross-Model Query Tests")
struct CrossModelQueryTests {
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
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        context = ModelContext(container)
    }

    // MARK: - Query by Tag Tests

    @Test("Find recipes by single tag name")
    func testQuery_RecipesByTag_FindsMatches() throws {
        // Arrange
        let dessertTag = Heirloom.Tag(name: "Dessert", color: "#FF6B6B")
        let dinnerTag = Heirloom.Tag(name: "Dinner", color: "#4ECDC4")

        let recipe1 = Heirloom.Recipe(title: "Chocolate Cake")
        let recipe2 = Heirloom.Recipe(title: "Brownies")
        let recipe3 = Heirloom.Recipe(title: "Grilled Chicken")

        recipe1.tags = [dessertTag]
        recipe2.tags = [dessertTag]
        recipe3.tags = [dinnerTag]

        context.insert(dessertTag)
        context.insert(dinnerTag)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act - query recipes with "Dessert" tag
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let dessertRecipes = allRecipes.filter { recipe in
            recipe.tags?.contains(where: { $0.name == "Dessert" }) ?? false
        }

        // Assert
        #expect(dessertRecipes.count == 2)
        #expect(dessertRecipes.contains(where: { $0.title == "Chocolate Cake" }))
        #expect(dessertRecipes.contains(where: { $0.title == "Brownies" }))
        #expect(!dessertRecipes.contains(where: { $0.title == "Grilled Chicken" }))
    }

    @Test("Query recipes by tag returns empty when no matches")
    func testQuery_RecipesByTag_NoMatches_ReturnsEmpty() throws {
        // Arrange
        let dessertTag = Heirloom.Tag(name: "Dessert", color: "#FF6B6B")
        let recipe = Heirloom.Recipe(title: "Grilled Chicken")

        context.insert(dessertTag)
        context.insert(recipe)
        try context.save()

        // Act - query recipes with non-existent tag
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let lunchRecipes = allRecipes.filter { recipe in
            recipe.tags?.contains(where: { $0.name == "Lunch" }) ?? false
        }

        // Assert
        #expect(lunchRecipes.isEmpty)
    }

    // MARK: - Query by Collection Tests

    @Test("Find recipes by collection name")
    func testQuery_RecipesByCollection_FindsMatches() throws {
        // Arrange
        let holidayCollection = Heirloom.RecipeCollection(name: "Holiday Favorites")
        let weeknightCollection = Heirloom.RecipeCollection(name: "Weeknight Dinners")

        let recipe1 = Heirloom.Recipe(title: "Roast Turkey")
        let recipe2 = Heirloom.Recipe(title: "Pumpkin Pie")
        let recipe3 = Heirloom.Recipe(title: "Pasta Primavera")

        recipe1.collections = [holidayCollection]
        recipe2.collections = [holidayCollection]
        recipe3.collections = [weeknightCollection]

        context.insert(holidayCollection)
        context.insert(weeknightCollection)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act - query recipes in "Holiday Favorites" collection
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let holidayRecipes = allRecipes.filter { recipe in
            recipe.collections?.contains(where: { $0.name == "Holiday Favorites" }) ?? false
        }

        // Assert
        #expect(holidayRecipes.count == 2)
        #expect(holidayRecipes.contains(where: { $0.title == "Roast Turkey" }))
        #expect(holidayRecipes.contains(where: { $0.title == "Pumpkin Pie" }))
        #expect(!holidayRecipes.contains(where: { $0.title == "Pasta Primavera" }))
    }

    @Test("Recipe in multiple collections appears in all queries")
    func testQuery_RecipeInMultipleCollections_AppearsInAll() throws {
        // Arrange
        let collection1 = Heirloom.RecipeCollection(name: "Collection 1")
        let collection2 = Heirloom.RecipeCollection(name: "Collection 2")

        let recipe = Heirloom.Recipe(title: "Versatile Recipe")
        recipe.collections = [collection1, collection2]

        context.insert(collection1)
        context.insert(collection2)
        context.insert(recipe)
        try context.save()

        // Act
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let collection1Recipes = allRecipes.filter { recipe in
            recipe.collections?.contains(where: { $0.name == "Collection 1" }) ?? false
        }
        let collection2Recipes = allRecipes.filter { recipe in
            recipe.collections?.contains(where: { $0.name == "Collection 2" }) ?? false
        }

        // Assert
        #expect(collection1Recipes.count == 1)
        #expect(collection2Recipes.count == 1)
        #expect(collection1Recipes.first?.title == "Versatile Recipe")
        #expect(collection2Recipes.first?.title == "Versatile Recipe")
    }

    // MARK: - Query by Multiple Tags Tests

    @Test("Find recipes with multiple tags (AND logic)")
    func testQuery_RecipesWithMultipleTags_AND_FindsMatches() throws {
        // Arrange
        let dessertTag = Heirloom.Tag(name: "Dessert", color: "#FF6B6B")
        let quickTag = Heirloom.Tag(name: "Quick", color: "#4ECDC4")

        let recipe1 = Heirloom.Recipe(title: "No-Bake Cookies")
        let recipe2 = Heirloom.Recipe(title: "Chocolate Cake")
        let recipe3 = Heirloom.Recipe(title: "Grilled Chicken")

        recipe1.tags = [dessertTag, quickTag]  // Both tags
        recipe2.tags = [dessertTag]             // Only dessert
        recipe3.tags = [quickTag]               // Only quick

        context.insert(dessertTag)
        context.insert(quickTag)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act - query recipes with BOTH "Dessert" AND "Quick" tags
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let filteredRecipes = allRecipes.filter { recipe in
            let tags = recipe.tags ?? []
            return tags.contains(where: { $0.name == "Dessert" }) &&
                   tags.contains(where: { $0.name == "Quick" })
        }

        // Assert
        #expect(filteredRecipes.count == 1)
        #expect(filteredRecipes.first?.title == "No-Bake Cookies")
    }

    @Test("Find recipes with multiple tags (OR logic)")
    func testQuery_RecipesWithMultipleTags_OR_FindsMatches() throws {
        // Arrange
        let dessertTag = Heirloom.Tag(name: "Dessert", color: "#FF6B6B")
        let quickTag = Heirloom.Tag(name: "Quick", color: "#4ECDC4")

        let recipe1 = Heirloom.Recipe(title: "No-Bake Cookies")
        let recipe2 = Heirloom.Recipe(title: "Chocolate Cake")
        let recipe3 = Heirloom.Recipe(title: "Grilled Chicken")

        recipe1.tags = [dessertTag, quickTag]  // Both tags
        recipe2.tags = [dessertTag]             // Only dessert
        recipe3.tags = []                       // No tags

        context.insert(dessertTag)
        context.insert(quickTag)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act - query recipes with EITHER "Dessert" OR "Quick" tags
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let filteredRecipes = allRecipes.filter { recipe in
            let tags = recipe.tags ?? []
            return tags.contains(where: { $0.name == "Dessert" || $0.name == "Quick" })
        }

        // Assert
        #expect(filteredRecipes.count == 2)
        #expect(filteredRecipes.contains(where: { $0.title == "No-Bake Cookies" }))
        #expect(filteredRecipes.contains(where: { $0.title == "Chocolate Cake" }))
        #expect(!filteredRecipes.contains(where: { $0.title == "Grilled Chicken" }))
    }

    // MARK: - Query by Ingredient Category Tests

    @Test("Find recipes with ingredients in specific category")
    func testQuery_RecipesByIngredientCategory_FindsMatches() throws {
        // Arrange
        let recipe1 = Heirloom.Recipe(title: "Salad")
        let recipe2 = Heirloom.Recipe(title: "Grilled Steak")
        let recipe3 = Heirloom.Recipe(title: "Pasta")

        let lettuce = Heirloom.Ingredient(originalText: "lettuce", name: "lettuce", category: .produce)
        let tomato = Heirloom.Ingredient(originalText: "tomato", name: "tomato", category: .produce)
        let steak = Heirloom.Ingredient(originalText: "steak", name: "steak", category: .meat)
        let pasta = Heirloom.Ingredient(originalText: "pasta", name: "pasta", category: .pantry)

        lettuce.recipe = recipe1
        tomato.recipe = recipe1
        steak.recipe = recipe2
        pasta.recipe = recipe3

        recipe1.ingredients = [lettuce, tomato]
        recipe2.ingredients = [steak]
        recipe3.ingredients = [pasta]

        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        context.insert(lettuce)
        context.insert(tomato)
        context.insert(steak)
        context.insert(pasta)
        try context.save()

        // Act - query recipes with produce ingredients
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let produceRecipes = allRecipes.filter { recipe in
            recipe.ingredients?.contains(where: { $0.category == .produce }) ?? false
        }

        // Assert
        #expect(produceRecipes.count == 1)
        #expect(produceRecipes.first?.title == "Salad")
    }

    @Test("Find recipes with ingredients in multiple categories")
    func testQuery_RecipesByMultipleIngredientCategories_FindsMatches() throws {
        // Arrange
        let recipe1 = Heirloom.Recipe(title: "Chicken Salad")
        let recipe2 = Heirloom.Recipe(title: "Pasta")

        let chicken = Heirloom.Ingredient(originalText: "chicken", name: "chicken", category: .meat)
        let lettuce = Heirloom.Ingredient(originalText: "lettuce", name: "lettuce", category: .produce)
        let pasta = Heirloom.Ingredient(originalText: "pasta", name: "pasta", category: .pantry)

        chicken.recipe = recipe1
        lettuce.recipe = recipe1
        pasta.recipe = recipe2

        recipe1.ingredients = [chicken, lettuce]
        recipe2.ingredients = [pasta]

        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(chicken)
        context.insert(lettuce)
        context.insert(pasta)
        try context.save()

        // Act - query recipes with BOTH meat AND produce ingredients
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let filteredRecipes = allRecipes.filter { recipe in
            let ingredients = recipe.ingredients ?? []
            return ingredients.contains(where: { $0.category == .meat }) &&
                   ingredients.contains(where: { $0.category == .produce })
        }

        // Assert
        #expect(filteredRecipes.count == 1)
        #expect(filteredRecipes.first?.title == "Chicken Salad")
    }

    // MARK: - Complex Multi-Filter Query Tests

    @Test("Query recipes by tag AND collection")
    func testQuery_RecipesByTagAndCollection_FindsMatches() throws {
        // Arrange
        let dessertTag = Heirloom.Tag(name: "Dessert", color: "#FF6B6B")
        let quickTag = Heirloom.Tag(name: "Quick", color: "#4ECDC4")
        let holidayCollection = Heirloom.RecipeCollection(name: "Holiday Favorites")

        let recipe1 = Heirloom.Recipe(title: "Holiday Cake")
        let recipe2 = Heirloom.Recipe(title: "Holiday Cookies")
        let recipe3 = Heirloom.Recipe(title: "Brownies")

        recipe1.tags = [dessertTag]
        recipe1.collections = [holidayCollection]

        recipe2.tags = [dessertTag, quickTag]
        recipe2.collections = [holidayCollection]

        recipe3.tags = [dessertTag]

        context.insert(dessertTag)
        context.insert(quickTag)
        context.insert(holidayCollection)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act - query recipes that are desserts AND in holiday collection
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let filteredRecipes = allRecipes.filter { recipe in
            let hasDessertTag = recipe.tags?.contains(where: { $0.name == "Dessert" }) ?? false
            let inHolidayCollection = recipe.collections?.contains(where: { $0.name == "Holiday Favorites" }) ?? false
            return hasDessertTag && inHolidayCollection
        }

        // Assert
        #expect(filteredRecipes.count == 2)
        #expect(filteredRecipes.contains(where: { $0.title == "Holiday Cake" }))
        #expect(filteredRecipes.contains(where: { $0.title == "Holiday Cookies" }))
        #expect(!filteredRecipes.contains(where: { $0.title == "Brownies" }))
    }

    @Test("Query recipes by tag, collection, and ingredient category")
    func testQuery_RecipesByTagCollectionAndIngredient_FindsMatches() throws {
        // Arrange
        let dessertTag = Heirloom.Tag(name: "Dessert", color: "#FF6B6B")
        let holidayCollection = Heirloom.RecipeCollection(name: "Holiday Favorites")

        let recipe1 = Heirloom.Recipe(title: "Chocolate Cake")
        let recipe2 = Heirloom.Recipe(title: "Apple Pie")
        let recipe3 = Heirloom.Recipe(title: "Grilled Steak")

        let chocolate = Heirloom.Ingredient(originalText: "chocolate", name: "chocolate", category: .pantry)
        let apple = Heirloom.Ingredient(originalText: "apple", name: "apple", category: .produce)
        let steak = Heirloom.Ingredient(originalText: "steak", name: "steak", category: .meat)

        chocolate.recipe = recipe1
        apple.recipe = recipe2
        steak.recipe = recipe3

        recipe1.ingredients = [chocolate]
        recipe1.tags = [dessertTag]
        recipe1.collections = [holidayCollection]

        recipe2.ingredients = [apple]
        recipe2.tags = [dessertTag]
        recipe2.collections = [holidayCollection]

        recipe3.ingredients = [steak]

        context.insert(dessertTag)
        context.insert(holidayCollection)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        context.insert(chocolate)
        context.insert(apple)
        context.insert(steak)
        try context.save()

        // Act - query desserts in holiday collection with produce ingredients
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let filteredRecipes = allRecipes.filter { recipe in
            let hasDessertTag = recipe.tags?.contains(where: { $0.name == "Dessert" }) ?? false
            let inHolidayCollection = recipe.collections?.contains(where: { $0.name == "Holiday Favorites" }) ?? false
            let hasProduceIngredient = recipe.ingredients?.contains(where: { $0.category == .produce }) ?? false
            return hasDessertTag && inHolidayCollection && hasProduceIngredient
        }

        // Assert
        #expect(filteredRecipes.count == 1)
        #expect(filteredRecipes.first?.title == "Apple Pie")
    }

    @Test("Query recipes excluding specific tag")
    func testQuery_RecipesExcludingTag_FindsMatches() throws {
        // Arrange
        let vegetarianTag = Heirloom.Tag(name: "Vegetarian", color: "#4ECDC4")
        let dinnerTag = Heirloom.Tag(name: "Dinner", color: "#FF6B6B")

        let recipe1 = Heirloom.Recipe(title: "Grilled Chicken")
        let recipe2 = Heirloom.Recipe(title: "Pasta Primavera")
        let recipe3 = Heirloom.Recipe(title: "Veggie Stir Fry")

        recipe1.tags = [dinnerTag]
        recipe2.tags = [vegetarianTag, dinnerTag]
        recipe3.tags = [vegetarianTag]

        context.insert(vegetarianTag)
        context.insert(dinnerTag)
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act - query dinner recipes that are NOT vegetarian
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let filteredRecipes = allRecipes.filter { recipe in
            let hasDinnerTag = recipe.tags?.contains(where: { $0.name == "Dinner" }) ?? false
            let hasVegetarianTag = recipe.tags?.contains(where: { $0.name == "Vegetarian" }) ?? false
            return hasDinnerTag && !hasVegetarianTag
        }

        // Assert
        #expect(filteredRecipes.count == 1)
        #expect(filteredRecipes.first?.title == "Grilled Chicken")
    }

    // MARK: - Edge Cases

    @Test("Query with no results returns empty array")
    func testQuery_NoMatches_ReturnsEmpty() throws {
        // Arrange
        let tag = Heirloom.Tag(name: "Breakfast", color: "#FF6B6B")
        let recipe = Heirloom.Recipe(title: "Grilled Chicken")

        context.insert(tag)
        context.insert(recipe)
        try context.save()

        // Act - query with non-matching criteria
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let filteredRecipes = allRecipes.filter { recipe in
            let hasBreakfastTag = recipe.tags?.contains(where: { $0.name == "Breakfast" }) ?? false
            let hasDessertIngredient = recipe.ingredients?.contains(where: { $0.category == .bakery }) ?? false
            return hasBreakfastTag && hasDessertIngredient
        }

        // Assert
        #expect(filteredRecipes.isEmpty)
    }

    @Test("Query recipes with no tags or collections")
    func testQuery_RecipesWithNoRelationships_FindsMatches() throws {
        // Arrange
        let recipe1 = Heirloom.Recipe(title: "Recipe with Tags")
        let recipe2 = Heirloom.Recipe(title: "Recipe without Tags")
        let tag = Heirloom.Tag(name: "Dessert", color: "#FF6B6B")

        recipe1.tags = [tag]

        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(tag)
        try context.save()

        // Act - query recipes with no tags
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let recipesWithoutTags = allRecipes.filter { recipe in
            recipe.tags?.isEmpty ?? true
        }

        // Assert
        #expect(recipesWithoutTags.count == 1)
        #expect(recipesWithoutTags.first?.title == "Recipe without Tags")
    }

    @Test("Query with large dataset maintains accuracy")
    func testQuery_LargeDataset_MaintainsAccuracy() throws {
        // Arrange - create 50 recipes with varying tags
        let dessertTag = Heirloom.Tag(name: "Dessert", color: "#FF6B6B")
        let dinnerTag = Heirloom.Tag(name: "Dinner", color: "#4ECDC4")

        context.insert(dessertTag)
        context.insert(dinnerTag)

        var dessertCount = 0
        for i in 0..<50 {
            let recipe = Heirloom.Recipe(title: "Recipe \(i)")
            if i % 3 == 0 {  // Every third recipe is a dessert
                recipe.tags = [dessertTag]
                dessertCount += 1
            } else {
                recipe.tags = [dinnerTag]
            }
            context.insert(recipe)
        }
        try context.save()

        // Act
        let recipeFetch = FetchDescriptor<Heirloom.Recipe>()
        let allRecipes = try context.fetch(recipeFetch)
        let dessertRecipes = allRecipes.filter { recipe in
            recipe.tags?.contains(where: { $0.name == "Dessert" }) ?? false
        }

        // Assert
        #expect(dessertRecipes.count == dessertCount)
        #expect(allRecipes.count == 50)
    }
}
