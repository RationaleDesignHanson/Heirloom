import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class CategoryDetectionTests: XCTestCase {
    var service: CategoryDetectionService!
    var modelContext: ModelContext!

    override func setUp() async throws {
        service = CategoryDetectionService.shared

        // Create in-memory container for testing
        let container = try ModelContainer(
            for: Recipe.self, Ingredient.self, RecipeVersion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = container.mainContext
    }

    override func tearDown() async throws {
        service = nil
        modelContext = nil
    }

    // MARK: - Helper Methods

    private func createTestRecipe(title: String, ingredients: [String] = [], instructions: [String] = []) -> Recipe {
        let recipe = Recipe(
            title: title,
            instructions: instructions
        )
        modelContext.insert(recipe)

        for (index, ingName) in ingredients.enumerated() {
            let ingredient = Ingredient(
                originalText: ingName,
                name: ingName,
                orderIndex: index
            )
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
        }

        try? modelContext.save()
        return recipe
    }

    // MARK: - Title-Based Detection: Locked Categories

    func testTitleDetection_Laminated() throws {
        let recipe1 = createTestRecipe(title: "Classic Croissants")
        XCTAssertEqual(service.detectCategory(for: recipe1), .laminated)

        let recipe2 = createTestRecipe(title: "Homemade Puff Pastry")
        XCTAssertEqual(service.detectCategory(for: recipe2), .laminated)

        let recipe3 = createTestRecipe(title: "Danish Pastries")
        XCTAssertEqual(service.detectCategory(for: recipe3), .laminated)

        let recipe4 = createTestRecipe(title: "Kouign-Amann")
        XCTAssertEqual(service.detectCategory(for: recipe4), .laminated)
    }

    func testTitleDetection_Emulsion() throws {
        let recipe1 = createTestRecipe(title: "Homemade Mayonnaise")
        XCTAssertEqual(service.detectCategory(for: recipe1), .emulsion)

        let recipe2 = createTestRecipe(title: "Classic Hollandaise Sauce")
        XCTAssertEqual(service.detectCategory(for: recipe2), .emulsion)

        let recipe3 = createTestRecipe(title: "Garlic Aioli")
        XCTAssertEqual(service.detectCategory(for: recipe3), .emulsion)

        let recipe4 = createTestRecipe(title: "Béarnaise Sauce")
        XCTAssertEqual(service.detectCategory(for: recipe4), .emulsion)
    }

    func testTitleDetection_Sourdough() throws {
        let recipe1 = createTestRecipe(title: "Sourdough Bread")
        XCTAssertEqual(service.detectCategory(for: recipe1), .sourdough)

        let recipe2 = createTestRecipe(title: "Artisan Sourdough Boule")
        XCTAssertEqual(service.detectCategory(for: recipe2), .sourdough)

        let recipe3 = createTestRecipe(title: "Starter-Fed Loaf")
        XCTAssertEqual(service.detectCategory(for: recipe3), .sourdough)
    }

    func testTitleDetection_Candy() throws {
        let recipe1 = createTestRecipe(title: "Homemade Caramel")
        XCTAssertEqual(service.detectCategory(for: recipe1), .candy)

        let recipe2 = createTestRecipe(title: "English Toffee")
        XCTAssertEqual(service.detectCategory(for: recipe2), .candy)

        let recipe3 = createTestRecipe(title: "Chocolate Fudge")
        XCTAssertEqual(service.detectCategory(for: recipe3), .candy)

        let recipe4 = createTestRecipe(title: "Peanut Brittle")
        XCTAssertEqual(service.detectCategory(for: recipe4), .candy)
    }

    // MARK: - Title-Based Detection: Hard Scaling

    func testTitleDetection_YeastBread() throws {
        let recipe1 = createTestRecipe(title: "Crusty French Bread")
        XCTAssertEqual(service.detectCategory(for: recipe1), .yeastBread)

        let recipe2 = createTestRecipe(title: "Classic Baguette")
        XCTAssertEqual(service.detectCategory(for: recipe2), .yeastBread)

        let recipe3 = createTestRecipe(title: "Focaccia with Herbs")
        XCTAssertEqual(service.detectCategory(for: recipe3), .yeastBread)

        let recipe4 = createTestRecipe(title: "Braided Challah")
        XCTAssertEqual(service.detectCategory(for: recipe4), .yeastBread)

        let recipe5 = createTestRecipe(title: "Brioche Loaf")
        XCTAssertEqual(service.detectCategory(for: recipe5), .yeastBread)
    }

    func testTitleDetection_YeastBread_ExcludesQuickBreads() throws {
        // Should NOT be detected as yeast bread
        let recipe1 = createTestRecipe(title: "Banana Bread")
        XCTAssertNotEqual(service.detectCategory(for: recipe1), .yeastBread)

        let recipe2 = createTestRecipe(title: "Zucchini Bread")
        XCTAssertNotEqual(service.detectCategory(for: recipe2), .yeastBread)

        let recipe3 = createTestRecipe(title: "Pumpkin Bread")
        XCTAssertNotEqual(service.detectCategory(for: recipe3), .yeastBread)
    }

    // MARK: - Title-Based Detection: Moderate Scaling

    func testTitleDetection_LayerCake() throws {
        let recipe1 = createTestRecipe(title: "Classic Layer Cake")
        XCTAssertEqual(service.detectCategory(for: recipe1), .layerCake)

        let recipe2 = createTestRecipe(title: "Chocolate Cake with Buttercream")
        XCTAssertEqual(service.detectCategory(for: recipe2), .layerCake)
    }

    func testTitleDetection_LayerCake_ExcludesEasy() throws {
        // Should NOT be detected as layer cake (easier to scale)
        let recipe1 = createTestRecipe(title: "Chocolate Cupcakes")
        XCTAssertNotEqual(service.detectCategory(for: recipe1), .layerCake)

        let recipe2 = createTestRecipe(title: "Sheet Cake for a Crowd")
        XCTAssertNotEqual(service.detectCategory(for: recipe2), .layerCake)
    }

    func testTitleDetection_Pie() throws {
        let recipe1 = createTestRecipe(title: "Apple Pie")
        XCTAssertEqual(service.detectCategory(for: recipe1), .pie)

        let recipe2 = createTestRecipe(title: "Lemon Tart")
        XCTAssertEqual(service.detectCategory(for: recipe2), .pie)

        let recipe3 = createTestRecipe(title: "Quiche Lorraine")
        XCTAssertEqual(service.detectCategory(for: recipe3), .pie)
    }

    // MARK: - Title-Based Detection: Easy Scaling

    func testTitleDetection_SoupStew() throws {
        let recipe1 = createTestRecipe(title: "Chicken Noodle Soup")
        XCTAssertEqual(service.detectCategory(for: recipe1), .soupStew)

        let recipe2 = createTestRecipe(title: "Beef Stew")
        XCTAssertEqual(service.detectCategory(for: recipe2), .soupStew)

        let recipe3 = createTestRecipe(title: "White Bean Chili")
        XCTAssertEqual(service.detectCategory(for: recipe3), .soupStew)

        let recipe4 = createTestRecipe(title: "Lobster Bisque")
        XCTAssertEqual(service.detectCategory(for: recipe4), .soupStew)

        let recipe5 = createTestRecipe(title: "Corn Chowder")
        XCTAssertEqual(service.detectCategory(for: recipe5), .soupStew)
    }

    func testTitleDetection_Pasta() throws {
        let recipe1 = createTestRecipe(title: "Spaghetti Carbonara")
        XCTAssertEqual(service.detectCategory(for: recipe1), .pasta)

        let recipe2 = createTestRecipe(title: "Linguine with Clams")
        XCTAssertEqual(service.detectCategory(for: recipe2), .pasta)

        let recipe3 = createTestRecipe(title: "Fettuccine Alfredo")
        XCTAssertEqual(service.detectCategory(for: recipe3), .pasta)

        let recipe4 = createTestRecipe(title: "Penne Arrabbiata")
        XCTAssertEqual(service.detectCategory(for: recipe4), .pasta)

        let recipe5 = createTestRecipe(title: "Rigatoni Bolognese")
        XCTAssertEqual(service.detectCategory(for: recipe5), .pasta)
    }

    func testTitleDetection_StirFry() throws {
        let recipe1 = createTestRecipe(title: "Chicken Stir Fry")
        XCTAssertEqual(service.detectCategory(for: recipe1), .stirFry)

        let recipe2 = createTestRecipe(title: "Veggie Stir-Fry")
        XCTAssertEqual(service.detectCategory(for: recipe2), .stirFry)

        let recipe3 = createTestRecipe(title: "Fried Rice")
        XCTAssertEqual(service.detectCategory(for: recipe3), .stirFry)
    }

    func testTitleDetection_Casserole() throws {
        let recipe1 = createTestRecipe(title: "Green Bean Casserole")
        XCTAssertEqual(service.detectCategory(for: recipe1), .casserole)

        let recipe2 = createTestRecipe(title: "Tuna Bake")
        XCTAssertEqual(service.detectCategory(for: recipe2), .casserole)

        let recipe3 = createTestRecipe(title: "Classic Lasagna")
        XCTAssertEqual(service.detectCategory(for: recipe3), .casserole)

        let recipe4 = createTestRecipe(title: "Mac and Cheese")
        XCTAssertEqual(service.detectCategory(for: recipe4), .casserole)
    }

    func testTitleDetection_Cookies() throws {
        let recipe1 = createTestRecipe(title: "Chocolate Chip Cookies")
        XCTAssertEqual(service.detectCategory(for: recipe1), .cookies)

        let recipe2 = createTestRecipe(title: "Almond Biscotti")
        XCTAssertEqual(service.detectCategory(for: recipe2), .cookies)

        let recipe3 = createTestRecipe(title: "Buttery Shortbread")
        XCTAssertEqual(service.detectCategory(for: recipe3), .cookies)
    }

    func testTitleDetection_Muffins() throws {
        let recipe1 = createTestRecipe(title: "Blueberry Muffins")
        XCTAssertEqual(service.detectCategory(for: recipe1), .muffins)

        let recipe2 = createTestRecipe(title: "Chocolate Cupcakes")
        XCTAssertEqual(service.detectCategory(for: recipe2), .muffins)
    }

    func testTitleDetection_QuickBread() throws {
        let recipe1 = createTestRecipe(title: "Banana Bread")
        XCTAssertEqual(service.detectCategory(for: recipe1), .quickBread)

        let recipe2 = createTestRecipe(title: "Zucchini Bread")
        XCTAssertEqual(service.detectCategory(for: recipe2), .quickBread)

        let recipe3 = createTestRecipe(title: "Pumpkin Bread")
        XCTAssertEqual(service.detectCategory(for: recipe3), .quickBread)

        let recipe4 = createTestRecipe(title: "Cornbread")
        XCTAssertEqual(service.detectCategory(for: recipe4), .quickBread)

        let recipe5 = createTestRecipe(title: "Buttermilk Biscuits")
        XCTAssertEqual(service.detectCategory(for: recipe5), .quickBread)

        let recipe6 = createTestRecipe(title: "Cranberry Scones")
        XCTAssertEqual(service.detectCategory(for: recipe6), .quickBread)
    }

    // MARK: - Ingredient-Based Detection

    func testIngredientDetection_Laminated() throws {
        let recipe = createTestRecipe(
            title: "Pastry",
            ingredients: ["butter", "flour", "fold into layers"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .laminated)
    }

    func testIngredientDetection_Emulsion() throws {
        let recipe = createTestRecipe(
            title: "Sauce",
            ingredients: ["egg yolk", "olive oil", "lemon juice"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .emulsion)
    }

    func testIngredientDetection_Emulsion_ExcludesBaking() throws {
        // Has egg yolk + oil but also flour = baking recipe, NOT emulsion
        let recipe = createTestRecipe(
            title: "Cake",
            ingredients: ["egg yolk", "oil", "flour", "sugar"]
        )
        XCTAssertNotEqual(service.detectCategory(for: recipe), .emulsion)
    }

    func testIngredientDetection_Sourdough() throws {
        let recipe = createTestRecipe(
            title: "Bread",
            ingredients: ["sourdough starter", "flour", "salt", "water"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .sourdough)
    }

    func testIngredientDetection_YeastBread() throws {
        let recipe = createTestRecipe(
            title: "Bread",
            ingredients: ["active dry yeast", "flour", "water", "salt"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .yeastBread)
    }

    func testIngredientDetection_Cookies() throws {
        let recipe = createTestRecipe(
            title: "Dessert",
            ingredients: ["flour", "sugar", "butter"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .cookies)
    }

    func testIngredientDetection_Cookies_FewEggs() throws {
        // Has flour, sugar, butter, and 1-2 eggs = cookies
        let recipe = createTestRecipe(
            title: "Dessert",
            ingredients: ["flour", "sugar", "butter", "egg"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .cookies)
    }

    func testIngredientDetection_NotCookies_ManyEggs() throws {
        // Has flour, sugar, butter, but 3+ eggs = probably cake
        let recipe = createTestRecipe(
            title: "Dessert",
            ingredients: ["flour", "sugar", "butter", "eggs", "eggs", "eggs"]
        )
        XCTAssertNotEqual(service.detectCategory(for: recipe), .cookies)
    }

    // MARK: - Instruction-Based Detection

    func testInstructionDetection_Laminated() throws {
        let recipe = createTestRecipe(
            title: "Pastry",
            instructions: ["Roll out dough", "Spread butter", "Fold and turn", "Repeat folding process"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .laminated)
    }

    func testInstructionDetection_YeastBread() throws {
        let recipe1 = createTestRecipe(
            title: "Bread",
            instructions: ["Knead the dough for 10 minutes"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe1), .yeastBread)

        let recipe2 = createTestRecipe(
            title: "Bread",
            instructions: ["Let proof for 1 hour"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe2), .yeastBread)

        let recipe3 = createTestRecipe(
            title: "Bread",
            instructions: ["Cover and let rise until doubled"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe3), .yeastBread)
    }

    func testInstructionDetection_Emulsion() throws {
        let recipe1 = createTestRecipe(
            title: "Sauce",
            instructions: ["Whisk slowly while adding oil to emulsify"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe1), .emulsion)

        let recipe2 = createTestRecipe(
            title: "Sauce",
            instructions: ["Continue whisking until emulsified"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe2), .emulsion)
    }

    func testInstructionDetection_SoupStew() throws {
        let recipe = createTestRecipe(
            title: "Dinner",
            instructions: ["Add broth and simmer for 30 minutes"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .soupStew)
    }

    func testInstructionDetection_StirFry() throws {
        let recipe1 = createTestRecipe(
            title: "Dinner",
            instructions: ["Heat wok until smoking hot"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe1), .stirFry)

        let recipe2 = createTestRecipe(
            title: "Dinner",
            instructions: ["Stir fry vegetables for 3 minutes"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe2), .stirFry)
    }

    // MARK: - Detection Priority Tests

    func testDetectionPriority_TitleWins() throws {
        // Title says "Bread", ingredients say "cookies" - title should win
        let recipe = createTestRecipe(
            title: "Sourdough Bread",
            ingredients: ["flour", "sugar", "butter"]  // Would trigger cookies
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .sourdough)
    }

    func testDetectionPriority_IngredientsOverInstructions() throws {
        // No title match, but ingredients and instructions conflict
        let recipe = createTestRecipe(
            title: "Homemade Recipe",
            ingredients: ["active dry yeast", "flour", "water"],  // Yeast bread
            instructions: ["Fold and turn the dough"]  // Could suggest laminated
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .yeastBread)
    }

    func testDetectionPriority_FallbackToOther() throws {
        // No matches anywhere = .other
        let recipe = createTestRecipe(
            title: "Mystery Recipe",
            ingredients: ["salt", "pepper"],
            instructions: ["Mix together"]
        )
        XCTAssertEqual(service.detectCategory(for: recipe), .other)
    }

    // MARK: - detectAndApply Tests

    func testDetectAndApply_SetsCategory() throws {
        let recipe = createTestRecipe(title: "Chocolate Chip Cookies")
        service.detectAndApply(to: recipe)

        XCTAssertEqual(recipe.category, .cookies)
    }

    func testDetectAndApply_SetsScalability() throws {
        // Easy category
        let recipe1 = createTestRecipe(title: "Chicken Soup")
        service.detectAndApply(to: recipe1)
        XCTAssertEqual(recipe1.scalability, .easy)

        // Locked category
        let recipe2 = createTestRecipe(title: "Croissants")
        service.detectAndApply(to: recipe2)
        XCTAssertEqual(recipe2.scalability, .locked)
    }

    func testDetectAndApply_SetsMinimumServings() throws {
        let recipe1 = createTestRecipe(title: "Chocolate Chip Cookies")
        recipe1.servings = "24 cookies"
        service.detectAndApply(to: recipe1)

        XCTAssertEqual(recipe1.minimumServings, 4)
    }

    func testDetectAndApply_SetsMaximumServings_Easy() throws {
        let recipe = createTestRecipe(title: "Chicken Soup")
        recipe.servings = "4 servings"
        service.detectAndApply(to: recipe)

        // Should be 4x original = 16
        XCTAssertEqual(recipe.maximumServings, 16)
    }

    func testDetectAndApply_SetsMaximumServings_Locked() throws {
        let recipe = createTestRecipe(title: "Croissants")
        recipe.servings = "12 croissants"
        service.detectAndApply(to: recipe)

        // Locked categories: max = original
        XCTAssertEqual(recipe.maximumServings, 12)
    }

    func testDetectAndApply_SetsScalingNote_Locked() throws {
        let recipe = createTestRecipe(title: "Hollandaise Sauce")
        service.detectAndApply(to: recipe)

        XCTAssertNotNil(recipe.scalingNote)
        XCTAssertTrue(recipe.scalingNote?.contains("egg yolk") ?? false)
    }

    func testDetectAndApply_NoScalingNote_Easy() throws {
        let recipe = createTestRecipe(title: "Chicken Soup")
        service.detectAndApply(to: recipe)

        // Easy categories don't get scaling notes by default
        XCTAssertNil(recipe.scalingNote)
    }
}
