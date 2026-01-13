import Testing
import Foundation
import SwiftData

@testable import Heirloom

@Suite("Shopping Cart Recipe Tests")
struct ShoppingCartRecipeTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.ShoppingCartRecipe.self,
            Heirloom.Ingredient.self,
            Heirloom.Tag.self,
            Heirloom.RecipeCollection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Initialization Tests

    @Test("ShoppingCartRecipe initializes with recipe and target servings")
    func testInit_WithRecipeAndServings_SetsProperties() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "4 servings"
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 8)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(cartRecipe.recipeId == recipe.id)
        #expect(cartRecipe.recipe?.id == recipe.id)
        #expect(cartRecipe.targetServings == 8)
    }

    @Test("ShoppingCartRecipe sets dateAdded on initialization")
    func testInit_SetsDateAdded() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)
        let before = Date()

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 4)
        context.insert(cartRecipe)
        let after = Date()

        // Assert
        #expect(cartRecipe.dateAdded >= before)
        #expect(cartRecipe.dateAdded <= after)
    }

    // MARK: - Property Tests

    @Test("ShoppingCartRecipe stores target servings")
    func testTargetServings_StoresValue() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 12)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.targetServings == 12)
    }

    @Test("ShoppingCartRecipe stores recipe relationship")
    func testRecipe_StoresRelationship() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Chocolate Cake")
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 4)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.recipe?.title == "Chocolate Cake")
        #expect(cartRecipe.recipeId == recipe.id)
    }

    // MARK: - Scale Factor Tests

    @Test("ShoppingCartRecipe scaleFactor returns correct ratio")
    func testScaleFactor_MatchingServings_ReturnsOne() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "4 servings"
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 4)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.scaleFactor == 1.0)
    }

    @Test("ShoppingCartRecipe scaleFactor doubles when servings doubled")
    func testScaleFactor_DoubledServings_ReturnsTwo() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "6 servings"
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 12)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.scaleFactor == 2.0)
    }

    @Test("ShoppingCartRecipe scaleFactor halves when servings halved")
    func testScaleFactor_HalvedServings_ReturnsHalf() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "8 servings"
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 4)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.scaleFactor == 0.5)
    }

    @Test("ShoppingCartRecipe scaleFactor handles non-standard servings strings")
    func testScaleFactor_NonStandardServings_ParsesCorrectly() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "Makes 10"
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 20)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.scaleFactor == 2.0)
    }

    @Test("ShoppingCartRecipe scaleFactor returns 1.0 when recipe is nil")
    func testScaleFactor_NilRecipe_ReturnsOne() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 8)
        context.insert(cartRecipe)

        // Act - Remove recipe relationship
        cartRecipe.recipe = nil

        // Assert
        #expect(cartRecipe.scaleFactor == 1.0)
    }

    // MARK: - Display Title Tests

    @Test("ShoppingCartRecipe displayTitle shows recipe title when servings match")
    func testDisplayTitle_MatchingServings_ShowsTitle() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Grandma's Cookies")
        recipe.servings = "24 cookies"
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 24)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.displayTitle == "Grandma's Cookies")
    }

    @Test("ShoppingCartRecipe displayTitle includes servings when different")
    func testDisplayTitle_DifferentServings_IncludesServings() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Grandma's Cookies")
        recipe.servings = "24 cookies"
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 48)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.displayTitle == "Grandma's Cookies (for 48)")
    }

    @Test("ShoppingCartRecipe displayTitle returns default when recipe is nil")
    func testDisplayTitle_NilRecipe_ReturnsDefault() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test")
        context.insert(recipe)

        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 4)
        context.insert(cartRecipe)

        // Act
        cartRecipe.recipe = nil

        // Assert
        #expect(cartRecipe.displayTitle == "Unknown Recipe")
    }

    // MARK: - Recipe Extension Tests

    @Test("Recipe isInShoppingCart returns false when not in cart")
    func testRecipe_IsInShoppingCart_ReturnsFalseWhenNotInCart() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act
        let isInCart = recipe.isInShoppingCart(context: context)

        // Assert
        #expect(isInCart == false)
    }

    @Test("Recipe isInShoppingCart returns true when in cart")
    func testRecipe_IsInShoppingCart_ReturnsTrueWhenInCart() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 4)
        context.insert(cartRecipe)

        try! context.save()

        // Act
        let isInCart = recipe.isInShoppingCart(context: context)

        // Assert
        #expect(isInCart == true)
    }

    @Test("Recipe shoppingCartRecipe returns nil when not in cart")
    func testRecipe_ShoppingCartRecipe_ReturnsNilWhenNotInCart() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act
        let cartRecipe = recipe.shoppingCartRecipe(context: context)

        // Assert
        #expect(cartRecipe == nil)
    }

    @Test("Recipe shoppingCartRecipe returns cart recipe when in cart")
    func testRecipe_ShoppingCartRecipe_ReturnsCartRecipeWhenInCart() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 8)
        context.insert(cartRecipe)

        try! context.save()

        // Act
        let foundCartRecipe = recipe.shoppingCartRecipe(context: context)

        // Assert
        #expect(foundCartRecipe != nil)
        #expect(foundCartRecipe?.targetServings == 8)
        #expect(foundCartRecipe?.recipeId == recipe.id)
    }

    // MARK: - Edge Case Tests

    @Test("ShoppingCartRecipe handles zero target servings")
    func testEdgeCase_ZeroTargetServings() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "4 servings"
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 0)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.targetServings == 0)
        #expect(cartRecipe.scaleFactor == 0.0)
    }

    @Test("ShoppingCartRecipe handles very large target servings")
    func testEdgeCase_LargeTargetServings() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "4 servings"
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 1000)
        context.insert(cartRecipe)

        // Assert
        #expect(cartRecipe.targetServings == 1000)
        #expect(cartRecipe.scaleFactor == 250.0)
    }

    @Test("ShoppingCartRecipe handles recipe with no servings specified")
    func testEdgeCase_NoServingsSpecified() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        // Don't set servings property (defaults to nil)
        context.insert(recipe)

        // Act
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 4)
        context.insert(cartRecipe)

        // Assert - Should use default serving count (parsedServingCount defaults to 1)
        #expect(cartRecipe.scaleFactor == 4.0)
    }

    @Test("ShoppingCartRecipe can be removed from context")
    func testEdgeCase_CanBeRemoved() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: 4)
        context.insert(cartRecipe)

        try! context.save()

        // Act
        context.delete(cartRecipe)
        try! context.save()

        // Assert
        let isInCart = recipe.isInShoppingCart(context: context)
        #expect(isInCart == false)
    }

    @Test("ShoppingCartRecipe multiple recipes can be in cart")
    func testEdgeCase_MultipleRecipesInCart() {
        // Arrange
        let context = createTestContext()
        let recipe1 = Heirloom.Recipe(title: "Recipe 1")
        let recipe2 = Heirloom.Recipe(title: "Recipe 2")
        let recipe3 = Heirloom.Recipe(title: "Recipe 3")
        context.insert(recipe1)
        context.insert(recipe2)
        context.insert(recipe3)

        let cartRecipe1 = ShoppingCartRecipe(recipe: recipe1, targetServings: 4)
        let cartRecipe2 = ShoppingCartRecipe(recipe: recipe2, targetServings: 6)
        let cartRecipe3 = ShoppingCartRecipe(recipe: recipe3, targetServings: 8)
        context.insert(cartRecipe1)
        context.insert(cartRecipe2)
        context.insert(cartRecipe3)

        try! context.save()

        // Act & Assert
        #expect(recipe1.isInShoppingCart(context: context) == true)
        #expect(recipe2.isInShoppingCart(context: context) == true)
        #expect(recipe3.isInShoppingCart(context: context) == true)
        #expect(recipe1.shoppingCartRecipe(context: context)?.targetServings == 4)
        #expect(recipe2.shoppingCartRecipe(context: context)?.targetServings == 6)
        #expect(recipe3.shoppingCartRecipe(context: context)?.targetServings == 8)
    }
}
