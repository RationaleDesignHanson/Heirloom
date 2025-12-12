import XCTest
@testable import Heirloom

final class RecipeModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_recipe_initialization_with_defaults() {
        let recipe = Recipe()

        XCTAssertNotNil(recipe.id)
        XCTAssertEqual(recipe.title, "")
        XCTAssertEqual(recipe.timesCooked, 0)
        XCTAssertEqual(recipe.isFavorite, false)
        XCTAssertEqual(recipe.generationCount, 1)
        XCTAssertNotNil(recipe.dateAdded)
        XCTAssertNotNil(recipe.lastModified)
    }

    func test_recipe_initialization_with_parameters() {
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .url,
            sourceURL: "https://example.com/recipe",
            instructions: ["Step 1", "Step 2"],
            servings: "4 servings",
            prepTime: "15 min",
            cookTime: "30 min"
        )

        XCTAssertEqual(recipe.title, "Test Recipe")
        XCTAssertEqual(recipe.sourceType, .url)
        XCTAssertEqual(recipe.sourceURL, "https://example.com/recipe")
        XCTAssertEqual(recipe.instructions.count, 2)
        XCTAssertEqual(recipe.servings, "4 servings")
        XCTAssertEqual(recipe.prepTime, "15 min")
        XCTAssertEqual(recipe.cookTime, "30 min")
    }

    // MARK: - Source Display Name Tests

    func test_sourceDisplayName_url() {
        let recipe = Recipe(
            title: "Recipe",
            sourceType: .url,
            sourceURL: "https://www.allrecipes.com/recipe/123/cookies"
        )

        XCTAssertEqual(recipe.sourceDisplayName, "allrecipes.com")
    }

    func test_sourceDisplayName_cookbook_with_page() {
        let recipe = Recipe(title: "Recipe", sourceType: .cookbook)
        recipe.sourceBookTitle = "The Joy of Cooking"
        recipe.sourceBookPage = 42

        XCTAssertEqual(recipe.sourceDisplayName, "The Joy of Cooking, p. 42")
    }

    func test_sourceDisplayName_cookbook_without_page() {
        let recipe = Recipe(title: "Recipe", sourceType: .cookbook)
        recipe.sourceBookTitle = "The Joy of Cooking"

        XCTAssertEqual(recipe.sourceDisplayName, "The Joy of Cooking")
    }

    func test_sourceDisplayName_family_with_date() {
        let recipe = Recipe(title: "Recipe", sourceType: .family)
        recipe.sourcePerson = "Grandma Rose"
        recipe.sourceDate = "1987"

        XCTAssertEqual(recipe.sourceDisplayName, "Grandma Rose, 1987")
    }

    func test_sourceDisplayName_family_without_date() {
        let recipe = Recipe(title: "Recipe", sourceType: .family)
        recipe.sourcePerson = "Grandma Rose"

        XCTAssertEqual(recipe.sourceDisplayName, "Grandma Rose")
    }

    func test_sourceDisplayName_manual() {
        let recipe = Recipe(title: "Recipe", sourceType: .manual)

        XCTAssertEqual(recipe.sourceDisplayName, "My Recipe")
    }

    // MARK: - Love Marks Tests

    func test_shouldShowLoveMarks_false_when_below_threshold() {
        let recipe = Recipe()
        recipe.timesCooked = 4

        XCTAssertFalse(recipe.shouldShowLoveMarks)
    }

    func test_shouldShowLoveMarks_true_when_at_threshold() {
        let recipe = Recipe()
        recipe.timesCooked = 5

        XCTAssertTrue(recipe.shouldShowLoveMarks)
    }

    func test_loveMarkIntensity_increases_with_cook_count() {
        let recipe = Recipe()

        recipe.timesCooked = 5
        let intensity5 = recipe.loveMarkIntensity

        recipe.timesCooked = 10
        let intensity10 = recipe.loveMarkIntensity

        recipe.timesCooked = 20
        let intensity20 = recipe.loveMarkIntensity

        XCTAssertLessThan(intensity5, intensity10)
        XCTAssertLessThan(intensity10, intensity20)
        XCTAssertEqual(intensity20, 1.0) // Maxes out at 1.0
    }

    // MARK: - Time Parsing Tests

    func test_parsedPrepTime_minutes_only() {
        let recipe = Recipe()
        recipe.prepTime = "30 min"

        XCTAssertEqual(recipe.parsedPrepTime, 30)
    }

    func test_parsedPrepTime_hours_and_minutes() {
        let recipe = Recipe()
        recipe.prepTime = "1 hr 30 min"

        XCTAssertEqual(recipe.parsedPrepTime, 90)
    }

    func test_parsedPrepTime_hours_only() {
        let recipe = Recipe()
        recipe.prepTime = "2 hours"

        XCTAssertEqual(recipe.parsedPrepTime, 120)
    }

    func test_parsedPrepTime_plain_number() {
        let recipe = Recipe()
        recipe.prepTime = "45"

        XCTAssertEqual(recipe.parsedPrepTime, 45)
    }

    func test_parsedCookTime_variations() {
        let recipe = Recipe()

        recipe.cookTime = "20 minutes"
        XCTAssertEqual(recipe.parsedCookTime, 20)

        recipe.cookTime = "1 hour"
        XCTAssertEqual(recipe.parsedCookTime, 60)

        recipe.cookTime = "2 hr 15 min"
        XCTAssertEqual(recipe.parsedCookTime, 135)
    }

    // MARK: - Serving Count Parsing Tests

    func test_parsedServingCount_simple_number() {
        let recipe = Recipe()
        recipe.servings = "6 servings"

        XCTAssertEqual(recipe.parsedServingCount, 6)
    }

    func test_parsedServingCount_makes_format() {
        let recipe = Recipe()
        recipe.servings = "Makes 12 cookies"

        XCTAssertEqual(recipe.parsedServingCount, 12)
    }

    func test_parsedServingCount_range() {
        let recipe = Recipe()
        recipe.servings = "4-6 servings"

        // Should return first number in range
        XCTAssertEqual(recipe.parsedServingCount, 4)
    }

    func test_parsedServingCount_default_when_nil() {
        let recipe = Recipe()
        recipe.servings = nil

        XCTAssertEqual(recipe.parsedServingCount, 4) // Default assumption
    }

    func test_parsedServingCount_default_when_no_numbers() {
        let recipe = Recipe()
        recipe.servings = "One batch"

        XCTAssertEqual(recipe.parsedServingCount, 4) // Default assumption
    }

    // MARK: - Scaling Properties Tests

    func test_isScalingAllowed_true_for_easy() {
        let recipe = Recipe()
        recipe.scalability = .easy

        XCTAssertTrue(recipe.isScalingAllowed)
    }

    func test_isScalingAllowed_false_for_locked() {
        let recipe = Recipe()
        recipe.scalability = .locked

        XCTAssertFalse(recipe.isScalingAllowed)
    }

    func test_allowedServingRange_returns_nil_when_locked() {
        let recipe = Recipe()
        recipe.scalability = .locked

        XCTAssertNil(recipe.allowedServingRange)
    }

    func test_allowedServingRange_with_explicit_max() {
        let recipe = Recipe()
        recipe.scalability = .easy
        recipe.minimumServings = 2
        recipe.maximumServings = 12

        let range = recipe.allowedServingRange

        XCTAssertNotNil(range)
        XCTAssertEqual(range?.lowerBound, 2)
        XCTAssertEqual(range?.upperBound, 12)
    }

    func test_allowedServingRange_with_default_max() {
        let recipe = Recipe()
        recipe.scalability = .easy
        recipe.minimumServings = 1
        recipe.maximumServings = nil

        let range = recipe.allowedServingRange

        XCTAssertNotNil(range)
        XCTAssertEqual(range?.lowerBound, 1)
        XCTAssertEqual(range?.upperBound, 16) // Default max
    }

    func test_availableServingSizes_includes_original() {
        let recipe = Recipe()
        recipe.servings = "7 servings"
        recipe.category = .soupStew // Has presets: [2, 4, 6, 8]

        let sizes = recipe.availableServingSizes

        // Should include original (7) even though it's not in presets
        XCTAssertTrue(sizes.contains(7))
    }

    func test_availableServingSizes_filters_by_range() {
        let recipe = Recipe()
        recipe.servings = "4 servings"
        recipe.category = .cookies // Has presets: [12, 24, 48, 96]
        recipe.minimumServings = 12
        recipe.maximumServings = 50

        let sizes = recipe.availableServingSizes

        // Should include 4 (original) and presets within range
        XCTAssertTrue(sizes.contains(4)) // Original always included
        XCTAssertTrue(sizes.contains(12))
        XCTAssertTrue(sizes.contains(24))
        XCTAssertTrue(sizes.contains(48))
        XCTAssertFalse(sizes.contains(96)) // Outside range
    }

    func test_availableServingSizes_locked_returns_only_original() {
        let recipe = Recipe()
        recipe.servings = "12 servings"
        recipe.category = .laminated
        recipe.scalability = .locked

        let sizes = recipe.availableServingSizes

        XCTAssertEqual(sizes.count, 1)
        XCTAssertEqual(sizes.first, 12)
    }

    // MARK: - Category Tests

    func test_category_enum_conversion() {
        let recipe = Recipe()

        recipe.category = .cookies
        XCTAssertEqual(recipe.recipeCategory, "Cookies")

        recipe.category = .soupStew
        XCTAssertEqual(recipe.recipeCategory, "Soup & Stew")
    }

    func test_scalingDisplayString_for_fixed_recipe() {
        let recipe = Recipe()
        recipe.servings = "12 cookies"
        recipe.scalability = .locked

        XCTAssertTrue(recipe.scalingDisplayString.contains("fixed"))
    }
}
