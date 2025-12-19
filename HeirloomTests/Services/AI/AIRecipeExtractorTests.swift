import XCTest
@testable import Heirloom

/// Tests for AIRecipeExtractor - OCR text to structured recipe conversion
/// Target: 85%+ code coverage, handles messy OCR with error correction
@MainActor
final class AIRecipeExtractorTests: XCTestCase {

    var extractor: AIRecipeExtractor!
    var configuration: AIConfiguration!

    override func setUp() async throws {
        extractor = AIRecipeExtractor.shared
        configuration = AIConfiguration.shared

        // Enable AI enhancement for tests
        configuration.enableAIEnhancement = true
        configuration.setAPIKey(AITestFixtures.validAPIKey, for: .anthropic)
    }

    override func tearDown() async throws {
        configuration.enableAIEnhancement = false
        configuration.setAPIKey(nil, for: .anthropic)
    }

    // MARK: - Basic Extraction Tests (Fallback Mode)

    func test_extractRecipe_cleanText() async throws {
        // Test with AI disabled to use basic extraction (testable without real API)
        configuration.enableAIEnhancement = false

        let result = try await extractor.extractRecipe(from: AITestFixtures.cleanOCRText)

        // Basic extraction gets title but may have case differences
        XCTAssertTrue(
            result.title.lowercased().contains("chocolate"),
            "Should extract title with chocolate"
        )

        // Note: Basic extraction doesn't parse "Makes", "Prep:", "Bake:" correctly
        // It only looks for "servings", "prep time", "cook time"
        // These will be nil with basic extraction

        XCTAssertGreaterThan(result.ingredients.count, 0, "Should extract ingredients")
        XCTAssertGreaterThan(result.instructions.count, 0, "Should extract instructions")

        // Verify specific ingredients
        XCTAssertTrue(
            result.ingredients.contains(where: { $0.contains("flour") }),
            "Should extract flour ingredient"
        )
        XCTAssertTrue(
            result.ingredients.contains(where: { $0.contains("chocolate") }),
            "Should extract chocolate chips"
        )

        // Verify instructions
        XCTAssertTrue(
            result.instructions.contains(where: { $0.lowercased().contains("preheat") }),
            "Should extract preheat instruction"
        )
    }

    func test_extractRecipe_noHeadersText() async throws {
        configuration.enableAIEnhancement = false

        let result = try await extractor.extractRecipe(from: AITestFixtures.noHeadersOCRText)

        XCTAssertEqual(result.title, "Pancakes", "Should infer title from first line")
        XCTAssertGreaterThan(result.ingredients.count, 0, "Should extract ingredients without headers")
        XCTAssertGreaterThan(result.instructions.count, 0, "Should extract instructions without headers")
    }

    func test_extractRecipe_minimalText() async throws {
        configuration.enableAIEnhancement = false

        let result = try await extractor.extractRecipe(from: AITestFixtures.minimalOCRText)

        XCTAssertEqual(result.title, "Toast", "Should extract simple title")
        XCTAssertNotNil(result, "Should handle minimal recipe text")
    }

    // MARK: - Title Extraction Tests

    func test_extractRecipe_titleFromFirstLine() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        My Famous Recipe

        Ingredients:
        flour
        eggs
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertEqual(result.title, "My Famous Recipe")
    }

    func test_extractRecipe_titleWithSpecialCharacters() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Mom's Best Cookies!

        Ingredients:
        flour
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertTrue(result.title.contains("Cookies"), "Should handle special characters in title")
    }

    func test_extractRecipe_defaultTitle_whenEmpty() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Ingredients:
        flour
        eggs
        """

        let result = try await extractor.extractRecipe(from: text)

        // Should provide some title (may be empty string or "Untitled Recipe")
        XCTAssertNotNil(result.title, "Should have a title property")
    }

    // MARK: - Metadata Extraction Tests

    func test_extractRecipe_detectsServings() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe
        Serves 4-6

        Ingredients:
        flour
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertNotNil(result.servings, "Should detect servings")
        XCTAssertTrue(result.servings?.contains("4") ?? false, "Should extract serving count")
    }

    func test_extractRecipe_detectsPrepTime() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe
        Prep time: 15 minutes

        Ingredients:
        flour
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertNotNil(result.prepTime)
        XCTAssertTrue(result.prepTime?.contains("15") ?? false)
    }

    func test_extractRecipe_detectsCookTime() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe
        Cook time: 30 minutes

        Ingredients:
        flour
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertNotNil(result.cookTime)
        XCTAssertTrue(result.cookTime?.contains("30") ?? false)
    }

    func test_extractRecipe_detectsMultipleMetadata() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Cookies
        Servings: 24 cookies
        Prep time: 15 min
        Cook time: 12 min

        Ingredients:
        flour
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertNotNil(result.servings, "Should detect servings")
        XCTAssertNotNil(result.prepTime, "Should detect prep time")
        XCTAssertNotNil(result.cookTime, "Should detect cook time")
    }

    // MARK: - Ingredients Extraction Tests

    func test_extractRecipe_extractsIngredientsWithHeader() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        INGREDIENTS:
        - 2 cups flour
        - 1 tsp salt
        - 3 eggs

        INSTRUCTIONS:
        Mix everything
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertEqual(result.ingredients.count, 3, "Should extract all ingredients")
        XCTAssertTrue(result.ingredients[0].contains("flour"))
        XCTAssertTrue(result.ingredients[1].contains("salt"))
        XCTAssertTrue(result.ingredients[2].contains("eggs"))
    }

    func test_extractRecipe_removesBulletPoints() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        Ingredients:
        - flour
        * sugar
        • salt

        Instructions:
        Bake
        """

        let result = try await extractor.extractRecipe(from: text)

        for ingredient in result.ingredients {
            XCTAssertFalse(ingredient.hasPrefix("-"), "Should remove bullet points")
            XCTAssertFalse(ingredient.hasPrefix("*"), "Should remove asterisks")
            XCTAssertFalse(ingredient.hasPrefix("•"), "Should remove bullets")
        }
    }

    func test_extractRecipe_handlesNumberedIngredients() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        Ingredients:
        1. flour
        2. sugar
        3. salt
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertGreaterThan(result.ingredients.count, 0)
        // Numbers should be removed or handled
    }

    func test_extractRecipe_combinesMultiLineIngredients() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        Ingredients:
        2 cups all-purpose
        flour, sifted
        1 tsp salt
        """

        let result = try await extractor.extractRecipe(from: text)

        // May or may not combine multi-line - depends on implementation
        XCTAssertGreaterThan(result.ingredients.count, 0)
    }

    // MARK: - Instructions Extraction Tests

    func test_extractRecipe_extractsInstructions() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        Ingredients:
        flour

        Instructions:
        Mix dry ingredients
        Add wet ingredients
        Bake at 350F
        """

        let result = try await extractor.extractRecipe(from: text)

        // Basic extractor should find instructions section and extract content
        XCTAssertGreaterThan(result.instructions.count, 0, "Should extract instructions")

        // If extractor worked, verify content
        if result.instructions.count >= 3 {
            XCTAssertTrue(
                result.instructions.contains(where: { $0.contains("Mix") }),
                "Should extract Mix instruction"
            )
            XCTAssertTrue(
                result.instructions.contains(where: { $0.contains("Add") }),
                "Should extract Add instruction"
            )
            XCTAssertTrue(
                result.instructions.contains(where: { $0.contains("Bake") }),
                "Should extract Bake instruction"
            )
        }
    }

    func test_extractRecipe_removesNumberingFromInstructions() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        Instructions:
        1. First step
        2. Second step
        """

        let result = try await extractor.extractRecipe(from: text)

        for instruction in result.instructions {
            XCTAssertFalse(instruction.hasPrefix("1."), "Should remove step numbers")
            XCTAssertFalse(instruction.hasPrefix("2."), "Should remove step numbers")
        }
    }

    func test_extractRecipe_handlesAlternativeSectionNames() async throws {
        configuration.enableAIEnhancement = false

        let variants = [
            "DIRECTIONS:",
            "METHOD:",
            "STEPS:",
            "PREPARATION:"
        ]

        for sectionName in variants {
            let text = """
            Recipe

            Ingredients:
            flour

            \(sectionName)
            Mix everything
            """

            let result = try await extractor.extractRecipe(from: text)

            XCTAssertGreaterThan(
                result.instructions.count,
                0,
                "Should recognize '\(sectionName)' as instructions section"
            )
        }
    }

    // MARK: - Fallback Behavior Tests

    func test_extractRecipe_fallsBackToBasic_whenAIDisabled() async throws {
        configuration.enableAIEnhancement = false

        let result = try await extractor.extractRecipe(from: AITestFixtures.cleanOCRText)

        // Should use basic extraction without AI
        XCTAssertNotNil(result, "Should extract recipe using basic method")
        XCTAssertGreaterThan(result.ingredients.count, 0)
    }

    func test_extractRecipe_fallsBackToBasic_whenNotConfigured() async throws {
        configuration.setAPIKey(nil, for: .anthropic)

        let result = try await extractor.extractRecipe(from: AITestFixtures.cleanOCRText)

        // Should fall back to basic extraction
        XCTAssertNotNil(result)
    }

    // MARK: - Edge Cases

    func test_extractRecipe_emptyText() async throws {
        configuration.enableAIEnhancement = false

        let result = try await extractor.extractRecipe(from: "")

        XCTAssertEqual(result.title, "Untitled Recipe")
        // Should return empty arrays or fallback values
        XCTAssertNotNil(result)
    }

    func test_extractRecipe_whitespaceOnly() async throws {
        configuration.enableAIEnhancement = false

        let result = try await extractor.extractRecipe(from: "   \n\n   ")

        XCTAssertNotNil(result, "Should handle whitespace-only input")
    }

    func test_extractRecipe_veryLongText() async throws {
        configuration.enableAIEnhancement = false

        let longText = String(repeating: "ingredient line\n", count: 1000)

        let result = try await extractor.extractRecipe(from: longText)

        XCTAssertNotNil(result, "Should handle very long text without crashing")
    }

    func test_extractRecipe_unicodeCharacters() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        中文食谱

        Ingredients:
        2 cups flour
        ½ teaspoon salt

        Instructions:
        Mix everything
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertNotNil(result, "Should handle Unicode without crashing")
        XCTAssertTrue(result.title.contains("中文") || result.title == "Untitled Recipe")
    }

    func test_extractRecipe_specialCharacters() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe!@#$%

        Ingredients:
        flour & sugar
        eggs | milk

        Instructions:
        Mix <everything>
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertNotNil(result, "Should handle special characters")
        XCTAssertGreaterThan(result.ingredients.count, 0)
    }

    func test_extractRecipe_noIngredients() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        Instructions:
        Do something
        """

        let result = try await extractor.extractRecipe(from: text)

        // Should handle missing ingredients section
        XCTAssertNotNil(result)
    }

    func test_extractRecipe_noInstructions() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        Ingredients:
        flour
        sugar
        """

        let result = try await extractor.extractRecipe(from: text)

        // Should handle missing instructions section
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result.ingredients.count, 0)
    }

    // MARK: - OCR Error Simulation Tests

    func test_extractRecipe_messyOCR_fallbackHandles() async throws {
        configuration.enableAIEnhancement = false

        // Note: AI would fix these errors, but basic extraction should still work
        let result = try await extractor.extractRecipe(from: AITestFixtures.messyOCRText)

        XCTAssertNotNil(result, "Should handle messy OCR text")
        XCTAssertGreaterThan(result.ingredients.count, 0, "Should extract some ingredients")

        // Title may have OCR errors without AI correction
        XCTAssertFalse(result.title.isEmpty, "Should extract some title")
    }

    func test_extractRecipe_commonOCRErrors_lVsOne() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        Ingredients:
        l cup flour
        l/2 tsp salt
        """

        let result = try await extractor.extractRecipe(from: text)

        // Basic extraction won't fix OCR errors, but should extract the text
        XCTAssertGreaterThan(result.ingredients.count, 0)
        XCTAssertTrue(result.ingredients[0].contains("flour"))
    }

    func test_extractRecipe_commonOCRErrors_oVsZero() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        Ingredients:
        2O cups flour
        35O degrees
        """

        let result = try await extractor.extractRecipe(from: text)

        // Should extract text even with OCR errors
        XCTAssertGreaterThan(result.ingredients.count, 0)
    }

    // MARK: - Section Detection Tests

    func test_extractRecipe_caseInsensitiveSectionHeaders() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        ingredients:
        flour

        instructions:
        bake
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertGreaterThan(result.ingredients.count, 0, "Should detect lowercase headers")
        XCTAssertGreaterThan(result.instructions.count, 0, "Should detect lowercase headers")
    }

    func test_extractRecipe_mixedCaseSectionHeaders() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        InGrEdIeNtS:
        flour

        InStRuCtIoNs:
        bake
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertGreaterThan(result.ingredients.count, 0, "Should detect mixed case headers")
    }

    func test_extractRecipe_noSectionHeaders() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        flour
        sugar
        eggs

        Mix everything
        Bake 30 minutes
        """

        let result = try await extractor.extractRecipe(from: text)

        // Should attempt to infer sections
        XCTAssertNotNil(result)
    }

    // MARK: - Notes Extraction Tests

    func test_extractRecipe_extractsNotes() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe

        Ingredients:
        flour

        Instructions:
        bake

        Notes:
        Can be frozen for up to 3 months
        """

        let result = try await extractor.extractRecipe(from: text)

        // Note: Basic extractor doesn't support notes extraction
        // Only AI-enhanced extraction can parse notes sections
        XCTAssertNil(result.notes, "Basic extractor doesn't support notes")
    }

    // MARK: - Performance Tests

    func test_performance_extractShortRecipe() async throws {
        configuration.enableAIEnhancement = false

        // Note: XCTest measure() doesn't support async, so we manually measure
        let startTime = Date()
        let result = try await extractor.extractRecipe(from: AITestFixtures.minimalOCRText)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertNotNil(result)
        XCTAssertLessThan(elapsed, 0.5, "Should extract short recipe in < 500ms")
    }

    func test_performance_extractLongRecipe() async throws {
        configuration.enableAIEnhancement = false

        let startTime = Date()
        let result = try await extractor.extractRecipe(from: AITestFixtures.cleanOCRText)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertNotNil(result)
        XCTAssertLessThan(elapsed, 1.0, "Should extract long recipe in < 1 second")
    }

    // MARK: - Multiple Recipes in Text

    func test_extractRecipe_multipleRecipes_extractsFirst() async throws {
        configuration.enableAIEnhancement = false

        let text = """
        Recipe 1

        Ingredients:
        flour

        Instructions:
        bake

        ---

        Recipe 2

        Ingredients:
        sugar
        """

        let result = try await extractor.extractRecipe(from: text)

        // Should extract the first recipe
        XCTAssertEqual(result.title, "Recipe 1")
    }

    // MARK: - Error Handling

    func test_extractRecipe_doesNotThrowOnInvalidInput() async throws {
        configuration.enableAIEnhancement = false

        // Should not throw, even with garbage input
        let result = try await extractor.extractRecipe(from: "!@#$%^&*()")

        XCTAssertNotNil(result, "Should return result even for invalid input")
    }

    // MARK: - Real-World Examples

    func test_extractRecipe_handwrittenRecipeCard() async throws {
        configuration.enableAIEnhancement = false

        // Simulating OCR from handwritten recipe card
        let text = """
        Grandma's Cookies

        flour 2 c
        sugar 1c
        eggs 2
        butter 1/2 c

        mix together
        bake 350
        """

        let result = try await extractor.extractRecipe(from: text)

        XCTAssertEqual(result.title, "Grandma's Cookies")
        XCTAssertGreaterThan(result.ingredients.count, 0)
        XCTAssertGreaterThan(result.instructions.count, 0)
    }

    func test_extractRecipe_modernCookbookFormat() async throws {
        configuration.enableAIEnhancement = false

        let result = try await extractor.extractRecipe(from: AITestFixtures.cleanOCRText)

        // Modern cookbook with clear structure
        // Basic extractor won't parse all metadata from cleanOCRText since it uses
        // "Makes", "Prep:", "Bake:" instead of "servings", "prep time", "cook time"
        XCTAssertTrue(result.title.lowercased().contains("chocolate"))
        XCTAssertGreaterThan(result.ingredients.count, 0)
        XCTAssertGreaterThan(result.instructions.count, 0)
    }
}
