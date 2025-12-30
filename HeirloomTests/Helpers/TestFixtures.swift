import Foundation
import SwiftData
@testable import Heirloom

/// Test fixtures and mock data for Heirloom tests
@MainActor
class TestFixtures {

    // MARK: - Model Container

    /// Creates an in-memory model container for testing
    static func createTestContainer() throws -> ModelContainer {
        // Use simpler ModelContainer initializer for in-memory testing
        do {
            let container = try ModelContainer(
                for: Recipe.self, Ingredient.self, Tag.self,
                RecipeVersion.self, RecipeCollection.self,
                RecipeCardStyle.self, RecipeSticker.self,
                RecipeAnnotation.self, Substitution.self,
                DinnerParty.self, DinnerPartyRecipe.self,
                ShoppingCartRecipe.self, RecipeComment.self,
                RecipeCardBack.self,
                ImportJob.self, ImportItem.self,  // Added: Bulk import models
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            return container
        } catch {
            print("❌ TestFixtures: Failed to create container - \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            throw error
        }
    }

    // MARK: - ExtractedRecipe Mocks

    static func mockExtractedRecipe(
        title: String = "Test Recipe",
        confidence: Double? = 0.95,
        ingredientCount: Int = 3,
        instructionCount: Int = 3
    ) -> AIRecipeExtractor.ExtractedRecipe {
        return AIRecipeExtractor.ExtractedRecipe(
            title: title,
            servings: "4 servings",
            prepTime: "15 minutes",
            cookTime: "30 minutes",
            ingredients: mockIngredients(count: ingredientCount),
            instructions: mockInstructions(count: instructionCount),
            notes: "Test notes",
            confidence: confidence
        )
    }

    static func mockMultipleExtractedRecipes() -> [AIRecipeExtractor.ExtractedRecipe] {
        return [
            mockExtractedRecipe(title: "Cheese Straws", confidence: 0.95),
            mockExtractedRecipe(title: "Peanut Butter Bread", confidence: 0.88),
            mockExtractedRecipe(title: "Orange Fritters", confidence: 0.72)
        ]
    }

    // MARK: - Recipe Mocks

    static func mockRecipe(
        title: String = "Test Recipe",
        context: ModelContext
    ) -> Recipe {
        let recipe = Recipe(title: title, sourceType: .manual)
        recipe.servings = "4 servings"
        recipe.prepTime = "15 minutes"
        recipe.cookTime = "30 minutes"
        recipe.instructions = mockInstructions()

        context.insert(recipe)

        // Add ingredients
        for (index, ingredientText) in mockIngredients().enumerated() {
            let parsed = IngredientParser.parse(ingredientText)
            let ingredient = Ingredient(
                originalText: ingredientText,
                name: parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit,
                category: .other,
                orderIndex: index
            )
            ingredient.recipe = recipe
            context.insert(ingredient)
        }

        return recipe
    }

    static func mockRecipeWithVersions(context: ModelContext) -> Recipe {
        let recipe = mockRecipe(title: "Grandma's Lasagna", context: context)

        // Create base version
        let baseVersion = RecipeVersion(
            creatorUserID: "user-grandma",
            creatorDisplayName: "Grandma Kay",
            creationYear: "1987",
            isBaseVersion: true
        )
        baseVersion.title = recipe.title
        baseVersion.ingredients = recipe.ingredients?.map { $0.originalText } ?? []
        baseVersion.instructions = recipe.instructions
        context.insert(baseVersion)

        recipe.versions = [baseVersion]
        recipe.selectedVersionID = baseVersion.id

        // Create second version
        let momVersion = RecipeVersion(
            creatorUserID: "user-mom",
            creatorDisplayName: "Mom",
            creationYear: "2015"
        )
        momVersion.title = recipe.title
        momVersion.ingredients = ["1 lb ground turkey", "12 lasagna noodles", "2 cups ricotta"]
        momVersion.instructions = recipe.instructions
        momVersion.timesCooked = 5
        momVersion.recordChange(field: "ingredient-0", from: "1 lb ground beef", to: "1 lb ground turkey")
        context.insert(momVersion)

        recipe.versions?.append(momVersion)

        return recipe
    }

    // MARK: - Ingredient Mocks

    static func mockIngredients(count: Int = 3) -> [String] {
        let ingredients = [
            "1 cup all-purpose flour",
            "1/2 teaspoon baking soda",
            "1/4 teaspoon salt",
            "1/2 cup butter, softened",
            "3/4 cup brown sugar",
            "1 egg",
            "1 teaspoon vanilla extract",
            "1 cup chocolate chips"
        ]
        return Array(ingredients.prefix(count))
    }

    // MARK: - Instruction Mocks

    static func mockInstructions(count: Int = 3) -> [String] {
        let instructions = [
            "Preheat oven to 350°F",
            "Mix flour, baking soda, and salt in a bowl",
            "Cream butter and sugar until fluffy",
            "Add egg and vanilla, mix well",
            "Stir in dry ingredients",
            "Fold in chocolate chips",
            "Drop spoonfuls on baking sheet",
            "Bake for 10-12 minutes"
        ]
        return Array(instructions.prefix(count))
    }

    // MARK: - OCR Text Samples

    static let singleRecipeOCRText = """
    CHOCOLATE CHIP COOKIES

    Makes 12 cookies

    INGREDIENTS:
    - 1 cup all-purpose flour
    - 1/2 tsp baking soda
    - 1/4 tsp salt
    - 1/2 cup butter, softened
    - 3/4 cup brown sugar
    - 1 egg
    - 1 tsp vanilla
    - 1 cup chocolate chips

    DIRECTIONS:
    1. Preheat oven to 350F
    2. Mix flour, baking soda, salt
    3. Cream butter and sugar until fluffy
    4. Add egg and vanilla
    5. Stir in dry ingredients
    6. Fold in chocolate chips
    7. Bake 10-12 minutes
    """

    static let multiRecipeOCRText = """
    CHEESE STRAWS
    Makes 30 straws
    1 cup grated cheese
    1 cup flour
    1 tsp baking powder
    1/4 tsp salt
    Mix together and bake at 450°F for 10 minutes.

    PEANUT BUTTER BREAD
    Makes 1 loaf
    2 cups flour
    4 tsp baking powder
    1 tsp salt
    1/2 cup sugar
    1/3 cup peanut butter
    1 1/2 cups milk
    Sift dry ingredients, add peanut butter, mix in milk.
    Bake at 350°F for 1 hour.

    ORANGE FRITTERS
    3 oranges
    1 cup batter
    Powdered sugar
    Peel oranges, separate into sections.
    Dip in batter and deep fry.
    """

    static let emptyOCRText = ""

    static let malformedOCRText = """
    Some random text that doesn't look like a recipe
    at all. No ingredients. No instructions.
    Just meaningless content.
    """

    // MARK: - Confidence Scores

    static let highConfidence: Double = 0.95
    static let mediumConfidence: Double = 0.82
    static let lowConfidence: Double = 0.65

    // MARK: - Helper Methods

    static func createTestRecipes(count: Int, context: ModelContext) -> [Recipe] {
        return (0..<count).map { index in
            mockRecipe(title: "Test Recipe \(index + 1)", context: context)
        }
    }

    static func waitForAsyncOperation(timeout: TimeInterval = 2.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
}
