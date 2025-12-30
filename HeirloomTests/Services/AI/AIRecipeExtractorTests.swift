import XCTest
@testable import Heirloom

@MainActor
final class AIRecipeExtractorTests: XCTestCase {

    var extractor: AIRecipeExtractor!

    override func setUp() async throws {
        try await super.setUp()
        extractor = AIRecipeExtractor.shared
    }

    override func tearDown() async throws {
        extractor = nil
        try await super.tearDown()
    }

    // MARK: - Basic Extraction Tests (Fallback)

    func testExtractRecipeBasic_WithSingleRecipe() async throws {
        // Given
        let ocrText = TestFixtures.singleRecipeOCRText

        // When - Using basic extraction (when AI is disabled)
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertEqual(recipe.title, "CHOCOLATE CHIP COOKIES", "Should extract title")
        XCTAssertFalse(recipe.ingredients.isEmpty, "Should extract ingredients")
        XCTAssertFalse(recipe.instructions.isEmpty, "Should extract instructions")
        XCTAssertGreaterThanOrEqual(recipe.ingredients.count, 5, "Should extract multiple ingredients")
        XCTAssertGreaterThanOrEqual(recipe.instructions.count, 4, "Should extract instructions (basic parser gets 4/7)")
    }

    func testExtractRecipeBasic_WithEmptyText() {
        // Given
        let ocrText = TestFixtures.emptyOCRText

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertEqual(recipe.title, "Untitled Recipe", "Should have default title")
        XCTAssertEqual(recipe.ingredients, ["No ingredients found"], "Should have fallback ingredients")
        XCTAssertEqual(recipe.instructions, ["No instructions found"], "Should have fallback instructions")
        XCTAssertNil(recipe.confidence, "Basic extraction should not have confidence")
    }

    func testExtractRecipeBasic_WithMalformedText() {
        // Given
        let ocrText = TestFixtures.malformedOCRText

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertNotEqual(recipe.title, "", "Should have a title")
        XCTAssertFalse(recipe.ingredients.isEmpty, "Should have ingredients array")
        XCTAssertFalse(recipe.instructions.isEmpty, "Should have instructions array")
    }

    func testExtractRecipeBasic_ExtractsServings() {
        // Given
        let ocrText = "Test Recipe\nServes 4\nIngredients:\n1 cup flour"

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertNotNil(recipe.servings, "Should extract servings")
        XCTAssertTrue(recipe.servings?.contains("Serves 4") ?? false, "Should contain servings text")
    }

    func testExtractRecipeBasic_ExtractsPrepTime() {
        // Given
        let ocrText = "Test Recipe\nPrep time: 15 minutes\nIngredients:\n1 cup flour"

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertNotNil(recipe.prepTime, "Should extract prep time")
        XCTAssertTrue(recipe.prepTime?.contains("15 minutes") ?? false, "Should contain prep time")
    }

    func testExtractRecipeBasic_ExtractsCookTime() {
        // Given
        let ocrText = "Test Recipe\nCook time: 30 minutes\nIngredients:\n1 cup flour"

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertNotNil(recipe.cookTime, "Should extract cook time")
        XCTAssertTrue(recipe.cookTime?.contains("30 minutes") ?? false, "Should contain cook time")
    }

    // MARK: - Multi-Recipe Result Tests

    func testMultiRecipeExtractionResult_Count() {
        // Given
        let recipes = TestFixtures.mockMultipleExtractedRecipes()
        let result = AIRecipeExtractor.MultiRecipeExtractionResult(
            recipes: recipes,
            sourceImage: nil
        )

        // Then
        XCTAssertEqual(result.count, 3, "Should report correct count")
        XCTAssertFalse(result.hasSingleRecipe, "Should not be single recipe")
        XCTAssertTrue(result.hasMultipleRecipes, "Should be multiple recipes")
    }

    func testMultiRecipeExtractionResult_SingleRecipe() {
        // Given
        let recipes = [TestFixtures.mockExtractedRecipe()]
        let result = AIRecipeExtractor.MultiRecipeExtractionResult(
            recipes: recipes,
            sourceImage: nil
        )

        // Then
        XCTAssertEqual(result.count, 1, "Should report count of 1")
        XCTAssertTrue(result.hasSingleRecipe, "Should be single recipe")
        XCTAssertFalse(result.hasMultipleRecipes, "Should not be multiple recipes")
    }

    func testMultiRecipeExtractionResult_NoRecipes() {
        // Given
        let result = AIRecipeExtractor.MultiRecipeExtractionResult(
            recipes: [],
            sourceImage: nil
        )

        // Then
        XCTAssertEqual(result.count, 0, "Should report count of 0")
        XCTAssertFalse(result.hasSingleRecipe, "Should not be single recipe")
        XCTAssertFalse(result.hasMultipleRecipes, "Should not be multiple recipes")
    }

    // MARK: - Extracted Recipe Tests

    func testExtractedRecipe_Codable() throws {
        // Given
        let recipe = TestFixtures.mockExtractedRecipe(
            title: "Test Recipe",
            confidence: 0.95
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(recipe)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AIRecipeExtractor.ExtractedRecipe.self, from: data)

        // Then
        XCTAssertEqual(decoded.title, recipe.title)
        XCTAssertEqual(decoded.confidence, recipe.confidence)
        XCTAssertEqual(decoded.ingredients.count, recipe.ingredients.count)
        XCTAssertEqual(decoded.instructions.count, recipe.instructions.count)
    }

    func testExtractedRecipe_CodingKeys() throws {
        // Given - JSON with snake_case keys
        let json = """
        {
            "title": "Test Recipe",
            "servings": "4",
            "prep_time": "15 minutes",
            "cook_time": "30 minutes",
            "ingredients": ["1 cup flour"],
            "instructions": ["Mix ingredients"],
            "notes": "Test note",
            "confidence": 0.95
        }
        """

        // When
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let recipe = try decoder.decode(AIRecipeExtractor.ExtractedRecipe.self, from: data)

        // Then
        XCTAssertEqual(recipe.title, "Test Recipe")
        XCTAssertEqual(recipe.prepTime, "15 minutes", "Should decode prep_time")
        XCTAssertEqual(recipe.cookTime, "30 minutes", "Should decode cook_time")
        XCTAssertEqual(recipe.confidence, 0.95)
    }

    // MARK: - Confidence Score Tests

    func testConfidenceScores_HighConfidence() {
        // Given
        let recipe = TestFixtures.mockExtractedRecipe(confidence: TestFixtures.highConfidence)

        // Then
        XCTAssertNotNil(recipe.confidence)
        XCTAssertEqual(recipe.confidence ?? 0, 0.95, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(recipe.confidence ?? 0, 0.9, "High confidence should be >= 0.9")
    }

    func testConfidenceScores_MediumConfidence() {
        // Given
        let recipe = TestFixtures.mockExtractedRecipe(confidence: TestFixtures.mediumConfidence)

        // Then
        XCTAssertNotNil(recipe.confidence)
        XCTAssertEqual(recipe.confidence ?? 0, 0.82, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(recipe.confidence ?? 0, 0.7, "Medium confidence should be >= 0.7")
        XCTAssertLessThan(recipe.confidence ?? 1.0, 0.9, "Medium confidence should be < 0.9")
    }

    func testConfidenceScores_LowConfidence() {
        // Given
        let recipe = TestFixtures.mockExtractedRecipe(confidence: TestFixtures.lowConfidence)

        // Then
        XCTAssertNotNil(recipe.confidence)
        XCTAssertEqual(recipe.confidence ?? 0, 0.65, accuracy: 0.01)
        XCTAssertLessThan(recipe.confidence ?? 1.0, 0.7, "Low confidence should be < 0.7")
    }

    func testConfidenceScores_NoConfidence() {
        // Given
        let recipe = TestFixtures.mockExtractedRecipe(confidence: nil)

        // Then
        XCTAssertNil(recipe.confidence, "Recipe can have no confidence score")
    }

    // MARK: - Edge Case Tests

    func testExtractedRecipe_WithEmptyIngredients() {
        // Given
        let recipe = TestFixtures.mockExtractedRecipe(ingredientCount: 0)

        // Then
        XCTAssertTrue(recipe.ingredients.isEmpty, "Should handle empty ingredients")
    }

    func testExtractedRecipe_WithEmptyInstructions() {
        // Given
        let recipe = TestFixtures.mockExtractedRecipe(instructionCount: 0)

        // Then
        XCTAssertTrue(recipe.instructions.isEmpty, "Should handle empty instructions")
    }

    func testExtractedRecipe_WithManyIngredients() {
        // Given
        let recipe = TestFixtures.mockExtractedRecipe(ingredientCount: 8)

        // Then
        XCTAssertEqual(recipe.ingredients.count, 8, "Should handle many ingredients")
    }

    func testExtractedRecipe_WithOptionalFields() {
        // Given
        let recipe = AIRecipeExtractor.ExtractedRecipe(
            title: "Minimal Recipe",
            servings: nil,
            prepTime: nil,
            cookTime: nil,
            ingredients: ["flour"],
            instructions: ["mix"],
            notes: nil,
            confidence: nil
        )

        // Then
        XCTAssertNil(recipe.servings)
        XCTAssertNil(recipe.prepTime)
        XCTAssertNil(recipe.cookTime)
        XCTAssertNil(recipe.notes)
        XCTAssertNil(recipe.confidence)
        XCTAssertFalse(recipe.ingredients.isEmpty, "Should have ingredients")
        XCTAssertFalse(recipe.instructions.isEmpty, "Should have instructions")
    }

    // MARK: - Title Extraction Tests

    func testBasicExtraction_ExtractsTitleFromFirstLine() {
        // Given
        let ocrText = "CHOCOLATE CHIP COOKIES\n\nIngredients:\n1 cup flour"

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertEqual(recipe.title, "CHOCOLATE CHIP COOKIES")
    }

    func testBasicExtraction_SkipsIngredientHeaderAsTitle() {
        // Given
        let ocrText = "Ingredients\n1 cup flour\n2 eggs"

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertNotEqual(recipe.title, "Ingredients", "Should not use 'Ingredients' as title")
    }

    func testBasicExtraction_HandlesMissingTitle() {
        // Given
        let ocrText = "1 cup flour\n2 eggs"

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertNotEqual(recipe.title, "", "Should have some title")
    }

    // MARK: - Section Detection Tests

    func testBasicExtraction_DetectsIngredientSection() {
        // Given
        let ocrText = """
        Test Recipe
        Ingredients:
        1 cup flour
        2 eggs
        Instructions:
        Mix and bake
        """

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertGreaterThanOrEqual(recipe.ingredients.count, 2, "Should detect ingredient section")
        XCTAssertTrue(recipe.ingredients.contains { $0.contains("flour") }, "Should extract flour")
        XCTAssertTrue(recipe.ingredients.contains { $0.contains("eggs") }, "Should extract eggs")
    }

    func testBasicExtraction_DetectsInstructionSection() {
        // Given
        let ocrText = """
        Test Recipe
        Instructions:
        Mix ingredients
        Bake at 350F
        """

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        XCTAssertGreaterThanOrEqual(recipe.instructions.count, 1, "Should detect instruction section")
    }

    func testBasicExtraction_IgnoresBulletPoints() {
        // Given
        let ocrText = """
        Ingredients:
        - 1 cup flour
        * 2 eggs
        • Salt
        """

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        let firstIngredient = recipe.ingredients.first ?? ""
        XCTAssertFalse(firstIngredient.hasPrefix("-"), "Should remove leading dash")
        XCTAssertFalse(firstIngredient.hasPrefix("*"), "Should remove leading asterisk")
        XCTAssertFalse(firstIngredient.hasPrefix("•"), "Should remove leading bullet")
    }

    func testBasicExtraction_IgnoresNumbering() {
        // Given
        let ocrText = """
        Instructions:
        1. Mix ingredients
        2. Bake
        3) Cool
        """

        // When
        let recipe = extractor.extractRecipeBasic(from: ocrText)

        // Then
        let firstInstruction = recipe.instructions.first ?? ""
        XCTAssertFalse(firstInstruction.hasPrefix("1."), "Should remove leading number")
    }

    // MARK: - Performance Tests

    func testBasicExtraction_Performance() {
        // Given
        let ocrText = TestFixtures.singleRecipeOCRText

        // When/Then
        measure {
            _ = extractor.extractRecipeBasic(from: ocrText)
        }
    }
}
