import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class RecipeTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.Ingredient.self,
            Heirloom.Tag.self,
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

    // MARK: - Creation Tests

    func testRecipe_Create_BasicProperties() throws {
        // Arrange & Act
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Test Recipe"
        recipe.servings = "4"
        recipe.prepTime = "15 minutes"
        recipe.cookTime = "30 minutes"

        context.insert(recipe)
        try context.save()

        // Assert
        XCTAssertEqual(recipe.title, "Test Recipe")
        XCTAssertEqual(recipe.servings, "4")
        XCTAssertEqual(recipe.prepTime, "15 minutes")
        XCTAssertEqual(recipe.cookTime, "30 minutes")
        XCTAssertNotNil(recipe.id)
        XCTAssertNotNil(recipe.dateAdded)
    }

    func testRecipe_Create_WithIngredients() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Pasta Carbonara"

        let ingredient1 = Heirloom.Ingredient(
            originalText: "1 lb pasta",
            name: "pasta",
            quantity: 1,
            unit: "lb"
        )

        let ingredient2 = Heirloom.Ingredient(
            originalText: "4 eggs",
            name: "eggs",
            quantity: 4
        )

        recipe.ingredients = [ingredient1, ingredient2]
        ingredient1.recipe = recipe
        ingredient2.recipe = recipe

        // Act
        context.insert(recipe)
        context.insert(ingredient1)
        context.insert(ingredient2)
        try context.save()

        // Assert
        XCTAssertEqual(recipe.ingredients?.count, 2)
        XCTAssertEqual(ingredient1.recipe?.id, recipe.id)
        XCTAssertEqual(ingredient2.recipe?.id, recipe.id)
    }

    func testRecipe_Create_WithInstructions() throws {
        // Arrange & Act
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Simple Recipe"
        recipe.instructions = [
            "Preheat oven to 350F",
            "Mix ingredients",
            "Bake for 30 minutes"
        ]

        context.insert(recipe)
        try context.save()

        // Assert
        XCTAssertEqual(recipe.instructions.count, 3)
        XCTAssertEqual(recipe.instructions[0], "Preheat oven to 350F")
        XCTAssertEqual(recipe.instructions[2], "Bake for 30 minutes")
    }

    // MARK: - Update Tests

    func testRecipe_Update_Title() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Original Title"
        context.insert(recipe)
        try context.save()

        // Act
        recipe.title = "Updated Title"
        recipe.lastModified = Date()
        try context.save()

        // Assert
        XCTAssertEqual(recipe.title, "Updated Title")
    }

    func testRecipe_Update_AddIngredient() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Test Recipe"
        recipe.ingredients = []
        context.insert(recipe)
        try context.save()

        // Act
        let newIngredient = Heirloom.Ingredient(
            originalText: "1 cup sugar",
            name: "sugar",
            quantity: 1,
            unit: "cup"
        )
        newIngredient.recipe = recipe
        recipe.ingredients?.append(newIngredient)
        context.insert(newIngredient)
        try context.save()

        // Assert
        XCTAssertEqual(recipe.ingredients?.count, 1)
        XCTAssertEqual(recipe.ingredients?.first?.name, "sugar")
    }

    func testRecipe_Update_ModifyMetadata() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Test Recipe"
        recipe.timesCooked = 0
        recipe.isFavorite = false
        context.insert(recipe)
        try context.save()

        // Act
        recipe.timesCooked = 3
        recipe.isFavorite = true
        recipe.lastCooked = Date()
        try context.save()

        // Assert
        XCTAssertEqual(recipe.timesCooked, 3)
        XCTAssertTrue(recipe.isFavorite)
        XCTAssertNotNil(recipe.lastCooked)
    }

    // MARK: - Delete Tests

    func testRecipe_Delete_RemovesFromContext() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "To Be Deleted"
        context.insert(recipe)
        try context.save()

        let recipeID = recipe.id

        // Act
        context.delete(recipe)
        try context.save()

        // Assert
        let descriptor = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.id == recipeID }
        )
        let results = try context.fetch(descriptor)
        XCTAssertTrue(results.isEmpty)
    }

    func testRecipe_Delete_CascadesIngredients() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Test Recipe"

        let ingredient = Heirloom.Ingredient(
            originalText: "1 cup flour",
            name: "flour",
            quantity: 1,
            unit: "cup"
        )
        ingredient.recipe = recipe
        recipe.ingredients = [ingredient]

        context.insert(recipe)
        context.insert(ingredient)
        try context.save()

        let ingredientID = ingredient.id

        // Act - delete recipe should cascade to ingredients
        context.delete(recipe)
        try context.save()

        // Assert
        let descriptor = FetchDescriptor<Heirloom.Ingredient>(
            predicate: #Predicate { $0.id == ingredientID }
        )
        let results = try context.fetch(descriptor)
        XCTAssertTrue(results.isEmpty, "Ingredient should be deleted via cascade")
    }

    // MARK: - Query Tests

    func testRecipe_Query_ByTitle() throws {
        // Arrange
        let recipe1 = Heirloom.Recipe(title: "")
        recipe1.title = "Chocolate Cake"

        let recipe2 = Heirloom.Recipe(title: "")
        recipe2.title = "Vanilla Cake"

        let recipe3 = Heirloom.Recipe(title: "")
        recipe3.title = "Chocolate Cookies"

        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act
        let descriptor = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { recipe in
                recipe.title.contains("Chocolate")
            }
        )
        let results = try context.fetch(descriptor)

        // Assert
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.title == "Chocolate Cake" })
        XCTAssertTrue(results.contains { $0.title == "Chocolate Cookies" })
    }

    func testRecipe_Query_Favorites() throws {
        // Arrange
        let recipe1 = Heirloom.Recipe(title: "")
        recipe1.title = "Favorite 1"
        recipe1.isFavorite = true

        let recipe2 = Heirloom.Recipe(title: "")
        recipe2.title = "Not Favorite"
        recipe2.isFavorite = false

        let recipe3 = Heirloom.Recipe(title: "")
        recipe3.title = "Favorite 2"
        recipe3.isFavorite = true

        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)
        try context.save()

        // Act
        let descriptor = FetchDescriptor<Heirloom.Recipe>(
            predicate: #Predicate { $0.isFavorite == true }
        )
        let results = try context.fetch(descriptor)

        // Assert
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.isFavorite })
    }

    // MARK: - Source Information Tests

    func testRecipe_SourceType_URL() throws {
        // Arrange & Act
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Web Recipe"
        recipe.sourceType = .url
        recipe.sourceURL = "https://example.com/recipe"

        context.insert(recipe)
        try context.save()

        // Assert
        XCTAssertEqual(recipe.sourceType, .url)
        XCTAssertEqual(recipe.sourceURL, "https://example.com/recipe")
    }

    func testRecipe_SourceType_Book() throws {
        // Arrange & Act
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Book Recipe"
        recipe.sourceType = .cookbook
        recipe.sourceBookTitle = "The Joy of Cooking"
        recipe.sourceBookAuthor = "Irma Rombauer"
        recipe.sourceBookPage = 234

        context.insert(recipe)
        try context.save()

        // Assert
        XCTAssertEqual(recipe.sourceType, .cookbook)
        XCTAssertEqual(recipe.sourceBookTitle, "The Joy of Cooking")
        XCTAssertEqual(recipe.sourceBookAuthor, "Irma Rombauer")
        XCTAssertEqual(recipe.sourceBookPage, 234)
    }

    func testRecipe_SourceType_Person() throws {
        // Arrange & Act
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Grandma's Recipe"
        recipe.sourceType = .family
        recipe.sourcePerson = "Grandma Rose"
        recipe.sourceStory = "Passed down for generations"

        context.insert(recipe)
        try context.save()

        // Assert
        XCTAssertEqual(recipe.sourceType, .family)
        XCTAssertEqual(recipe.sourcePerson, "Grandma Rose")
        XCTAssertEqual(recipe.sourceStory, "Passed down for generations")
    }

    // MARK: - Scaling Tests

    func testRecipe_Scaling_Properties() throws {
        // Arrange & Act
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Scalable Recipe"
        recipe.scalabilityRating = "easy"
        recipe.minimumServings = 2
        recipe.maximumServings = 12
        recipe.scalingNote = "Doubles well, but don't triple"

        context.insert(recipe)
        try context.save()

        // Assert
        XCTAssertEqual(recipe.scalabilityRating, "easy")
        XCTAssertEqual(recipe.minimumServings, 2)
        XCTAssertEqual(recipe.maximumServings, 12)
        XCTAssertEqual(recipe.scalingNote, "Doubles well, but don't triple")
    }

    // MARK: - Heritage Recipe Tests

    func testRecipe_Heritage_Properties() throws {
        // Arrange & Act
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Historic Recipe"
        recipe.isHeritageRecipe = true
        recipe.heritageCollectionId = "french-classics"
        recipe.historicalText = "Original recipe from 1850"
        recipe.historicalContext = "Popular in French countryside"
        recipe.blurhash = "L6PZfSi_.AyE_3t7t7R**0o#DgR4"

        context.insert(recipe)
        try context.save()

        // Assert
        XCTAssertTrue(recipe.isHeritageRecipe)
        XCTAssertEqual(recipe.heritageCollectionId, "french-classics")
        XCTAssertEqual(recipe.historicalText, "Original recipe from 1850")
        XCTAssertEqual(recipe.historicalContext, "Popular in French countryside")
        XCTAssertNotNil(recipe.blurhash)
    }

    // MARK: - Metadata & Tracking Tests

    func testRecipe_TimesCooked_Increment() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Frequently Cooked"
        recipe.timesCooked = 0
        context.insert(recipe)
        try context.save()

        // Act
        recipe.timesCooked += 1
        recipe.lastCooked = Date()
        try context.save()

        // Assert
        XCTAssertEqual(recipe.timesCooked, 1)
        XCTAssertNotNil(recipe.lastCooked)
    }

    func testRecipe_LastViewed_Update() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Viewed Recipe"
        context.insert(recipe)
        try context.save()

        let initialViewDate = recipe.lastViewed

        // Act
        recipe.lastViewed = Date()
        try context.save()

        // Assert
        XCTAssertNotEqual(recipe.lastViewed, initialViewDate)
    }

    // MARK: - Shopping List Tests

    func testRecipe_ShoppingList_Toggle() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "")
        recipe.title = "Shopping List Recipe"
        recipe.isInShoppingList = false
        context.insert(recipe)
        try context.save()

        // Act
        recipe.isInShoppingList = true
        try context.save()

        // Assert
        XCTAssertTrue(recipe.isInShoppingList)
    }
}
