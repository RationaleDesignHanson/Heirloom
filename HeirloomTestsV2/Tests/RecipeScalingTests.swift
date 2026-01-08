import Testing
import Foundation

@testable import Heirloom

@Suite("Recipe Scaling Tests")
struct RecipeScalingTests {

    // MARK: - Scalability Enum Tests

    @Test("Scalability enum converts from raw value")
    func testScalability_EnumConversion_FromRawValue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.scalabilityRating = "easy"

        // Act & Assert
        #expect(recipe.scalability == .easy)
    }

    @Test("Scalability enum defaults to easy for invalid raw value")
    func testScalability_InvalidRawValue_DefaultsToEasy() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.scalabilityRating = "invalid"

        // Act & Assert
        #expect(recipe.scalability == .easy)
    }

    @Test("Scalability enum setter updates raw value")
    func testScalability_SetterUpdatesRawValue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        // Act
        recipe.scalability = .locked

        // Assert
        #expect(recipe.scalabilityRating == "locked")
    }

    // MARK: - Category Enum Tests

    @Test("Category enum converts from raw value")
    func testCategory_EnumConversion_FromRawValue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.recipeCategory = "Cookies"

        // Act & Assert
        #expect(recipe.category == .cookies)
    }

    @Test("Category enum returns nil for invalid raw value")
    func testCategory_InvalidRawValue_ReturnsNil() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.recipeCategory = "invalid"

        // Act & Assert
        #expect(recipe.category == nil)
    }

    @Test("Category enum setter updates raw value")
    func testCategory_SetterUpdatesRawValue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        // Act
        recipe.category = .cookies

        // Assert
        #expect(recipe.recipeCategory == "Cookies")
    }

    @Test("Category enum setter with nil clears raw value")
    func testCategory_SetNil_ClearsRawValue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.category = .cookies

        // Act
        recipe.category = nil

        // Assert
        #expect(recipe.recipeCategory == nil)
    }

    // MARK: - Scaling Allowed Tests

    @Test("Easy scalability allows scaling")
    func testIsScalingAllowed_Easy_ReturnsTrue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.scalability = .easy

        // Act & Assert
        #expect(recipe.isScalingAllowed == true)
    }

    @Test("Moderate scalability allows scaling")
    func testIsScalingAllowed_Moderate_ReturnsTrue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.scalability = .moderate

        // Act & Assert
        #expect(recipe.isScalingAllowed == true)
    }

    @Test("Hard scalability allows scaling")
    func testIsScalingAllowed_Hard_ReturnsTrue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.scalability = .hard

        // Act & Assert
        #expect(recipe.isScalingAllowed == true)
    }

    @Test("Locked scalability does not allow scaling")
    func testIsScalingAllowed_Locked_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.scalability = .locked

        // Act & Assert
        #expect(recipe.isScalingAllowed == false)
    }

    // MARK: - Allowed Serving Range Tests

    @Test("Allowed serving range with minimum and maximum")
    func testAllowedServingRange_WithMinAndMax() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.scalability = .easy
        recipe.minimumServings = 2
        recipe.maximumServings = 12

        // Act
        let range = recipe.allowedServingRange

        // Assert
        #expect(range == 2...12)
    }

    @Test("Allowed serving range defaults maximum to 16")
    func testAllowedServingRange_NoMaximum_Defaults16() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.scalability = .easy
        recipe.minimumServings = 1
        recipe.maximumServings = nil

        // Act
        let range = recipe.allowedServingRange

        // Assert
        #expect(range == 1...16)
    }

    @Test("Allowed serving range returns nil when locked")
    func testAllowedServingRange_Locked_ReturnsNil() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.scalability = .locked

        // Act
        let range = recipe.allowedServingRange

        // Assert
        #expect(range == nil)
    }

    // MARK: - Scaling Display String Tests

    @Test("Scaling display string for scalable recipe shows servings")
    func testScalingDisplayString_Scalable_ShowsServings() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "6 servings")
        recipe.scalability = .easy

        // Act & Assert
        #expect(recipe.scalingDisplayString == "6 servings")
    }

    @Test("Scaling display string for locked recipe shows fixed label")
    func testScalingDisplayString_Locked_ShowsFixed() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "6 servings")
        recipe.scalability = .locked

        // Act & Assert
        #expect(recipe.scalingDisplayString == "6 servings (fixed)")
    }

    @Test("Scaling display string with nil servings uses parsed count")
    func testScalingDisplayString_NilServings_UsesParsedCount() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: nil)
        recipe.scalability = .easy

        // Act & Assert
        #expect(recipe.scalingDisplayString == "4 servings")
    }

    // MARK: - Available Serving Sizes Tests

    @Test("Available serving sizes for cookies category")
    func testAvailableServingSizes_Cookies_ReturnsPresets() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "24 cookies")
        recipe.category = .cookies
        recipe.scalability = .easy
        recipe.minimumServings = 4
        recipe.maximumServings = 96

        // Act
        let sizes = recipe.availableServingSizes

        // Assert
        #expect(sizes.contains(12))
        #expect(sizes.contains(24))
        #expect(sizes.contains(48))
        #expect(sizes.contains(96))
    }

    @Test("Available serving sizes includes original serving count")
    func testAvailableServingSizes_IncludesOriginal() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "7 servings")
        recipe.category = .soupStew
        recipe.scalability = .easy

        // Act
        let sizes = recipe.availableServingSizes

        // Assert
        #expect(sizes.contains(7))  // Original count should always be included
    }

    @Test("Available serving sizes filters by allowed range")
    func testAvailableServingSizes_FiltersByRange() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "6 servings")
        recipe.category = .soupStew  // Presets: [2, 4, 6, 8]
        recipe.scalability = .easy
        recipe.minimumServings = 4
        recipe.maximumServings = 6

        // Act
        let sizes = recipe.availableServingSizes

        // Assert
        #expect(sizes.contains(4))
        #expect(sizes.contains(6))
        #expect(!sizes.contains(2))  // Below minimum
        #expect(!sizes.contains(8))  // Above maximum
    }

    @Test("Available serving sizes for locked recipe returns only original")
    func testAvailableServingSizes_Locked_ReturnsOnlyOriginal() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "6 servings")
        recipe.category = .laminated
        recipe.scalability = .locked

        // Act
        let sizes = recipe.availableServingSizes

        // Assert
        #expect(sizes.count == 1)
        #expect(sizes.first == 6)
    }

    @Test("Available serving sizes without category uses defaults")
    func testAvailableServingSizes_NoCategory_UsesDefaults() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "6 servings")
        recipe.category = nil
        recipe.scalability = .easy

        // Act
        let sizes = recipe.availableServingSizes

        // Assert
        #expect(sizes.contains(2))
        #expect(sizes.contains(4))
        #expect(sizes.contains(6))
        #expect(sizes.contains(8))
        #expect(sizes.contains(12))
    }

    @Test("Available serving sizes are sorted")
    func testAvailableServingSizes_AreSorted() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "15 servings")
        recipe.category = .soupStew
        recipe.scalability = .easy

        // Act
        let sizes = recipe.availableServingSizes

        // Assert - verify array is sorted
        for i in 0..<(sizes.count - 1) {
            #expect(sizes[i] < sizes[i + 1])
        }
    }

    // MARK: - Edge Cases

    @Test("Recipe with no servings string defaults to 4")
    func testParsedServingCount_NoServings_Defaults4() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: nil)

        // Act & Assert
        #expect(recipe.parsedServingCount == 4)
    }

    @Test("Recipe scaling with empty servings string defaults to 4")
    func testParsedServingCount_EmptyString_Defaults4() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", servings: "")

        // Act & Assert
        #expect(recipe.parsedServingCount == 4)
    }

    @Test("Minimum servings defaults to 1")
    func testMinimumServings_DefaultsTo1() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        // Act & Assert
        #expect(recipe.minimumServings == 1)
    }

    @Test("Maximum servings can be nil for unlimited")
    func testMaximumServings_CanBeNil() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.maximumServings = nil

        // Act & Assert
        #expect(recipe.maximumServings == nil)
        #expect(recipe.allowedServingRange == 1...16)  // Uses default max of 16
    }
}
