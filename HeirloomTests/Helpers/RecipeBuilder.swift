import Foundation
@testable import Heirloom

/// Test data builder for creating Recipe instances with fluent API
class RecipeBuilder {
    private var title: String = "Test Recipe"
    private var sourceType: RecipeSourceType = .manual
    private var ingredients: [Ingredient] = []
    private var instructions: [String] = []
    private var servings: String? = "4 servings"
    private var prepTime: String? = nil
    private var cookTime: String? = nil
    private var category: RecipeCategory? = nil
    private var scalability: ScalabilityRating = .easy
    private var minimumServings: Int = 1
    private var maximumServings: Int? = nil

    func withTitle(_ title: String) -> Self {
        self.title = title
        return self
    }

    func withSourceType(_ type: RecipeSourceType) -> Self {
        self.sourceType = type
        return self
    }

    func withIngredients(_ ingredientTexts: [String]) -> Self {
        self.ingredients = ingredientTexts.enumerated().map { index, text in
            let parsed = IngredientParser.parse(text)
            let ingredient = Ingredient(
                originalText: text,
                name: parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit,
                orderIndex: index
            )
            return ingredient
        }
        return self
    }

    func withInstructions(_ instructions: [String]) -> Self {
        self.instructions = instructions
        return self
    }

    func withServings(_ servings: String) -> Self {
        self.servings = servings
        return self
    }

    func withPrepTime(_ time: String) -> Self {
        self.prepTime = time
        return self
    }

    func withCookTime(_ time: String) -> Self {
        self.cookTime = time
        return self
    }

    func withCategory(_ category: RecipeCategory) -> Self {
        self.category = category
        return self
    }

    func withScalability(_ scalability: ScalabilityRating) -> Self {
        self.scalability = scalability
        return self
    }

    func withServingRange(minimum: Int, maximum: Int?) -> Self {
        self.minimumServings = minimum
        self.maximumServings = maximum
        return self
    }

    func build() -> Recipe {
        let recipe = Recipe(
            title: title,
            sourceType: sourceType,
            instructions: instructions,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime
        )

        // Set ingredients (need to handle SwiftData relationship properly in tests)
        recipe.ingredients = ingredients
        ingredients.forEach { $0.recipe = recipe }

        // Set scaling properties
        recipe.category = category
        recipe.scalability = scalability
        recipe.minimumServings = minimumServings
        recipe.maximumServings = maximumServings

        return recipe
    }
}
