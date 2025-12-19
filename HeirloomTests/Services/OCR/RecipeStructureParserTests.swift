import XCTest
@testable import Heirloom

final class RecipeStructureParserTests: XCTestCase {

    var parser: RecipeStructureParser!

    override func setUp() {
        super.setUp()
        parser = RecipeStructureParser()
    }

    // MARK: - Title Extraction Tests

    func test_extractTitle_fromFirstLine() {
        let ocrText = """
        Chocolate Chip Cookies

        Ingredients:
        - 2 cups flour
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertEqual(result.title, "Chocolate Chip Cookies")
        XCTAssertGreaterThan(result.titleConfidence, 0.8)
    }

    func test_extractTitle_ignoresMetadata() {
        let ocrText = """
        Prep: 15 min
        Chocolate Chip Cookies

        Ingredients:
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertEqual(result.title, "Chocolate Chip Cookies")
    }

    func test_extractTitle_handlesAllCaps() {
        let ocrText = """
        CHOCOLATE CHIP COOKIES

        Ingredients:
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertEqual(result.title, "Chocolate Chip Cookies")
    }

    // MARK: - Ingredient Detection Tests

    func test_detectIngredients_withBullets() {
        let ocrText = """
        Ingredients:
        - 2 cups flour
        - 1 cup sugar
        - 2 eggs
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertEqual(result.ingredients.count, 3)
        XCTAssertTrue(result.ingredients.contains("2 cups flour"))
        XCTAssertTrue(result.ingredients.contains("1 cup sugar"))
        XCTAssertTrue(result.ingredients.contains("2 eggs"))
    }

    func test_detectIngredients_withNumbers() {
        let ocrText = """
        Ingredients:
        1. 2 cups flour
        2. 1 cup sugar
        3. 2 eggs
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertEqual(result.ingredients.count, 3)
        XCTAssertTrue(result.ingredients.contains("2 cups flour"))
    }

    func test_detectIngredients_mixedFormats() {
        let ocrText = """
        Ingredients:
        - 2 cups flour
        1 cup sugar
        • 2 eggs
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertGreaterThanOrEqual(result.ingredients.count, 2)
    }

    // MARK: - Instruction Detection Tests

    func test_detectInstructions_numbered() {
        let ocrText = """
        Instructions:
        1. Preheat oven to 350°F
        2. Mix dry ingredients
        3. Add wet ingredients
        4. Bake for 12 minutes
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertEqual(result.instructions.count, 4)
        XCTAssertEqual(result.instructions[0], "Preheat oven to 350°F")
        XCTAssertEqual(result.instructions[1], "Mix dry ingredients")
    }

    func test_detectInstructions_bulletPoints() {
        let ocrText = """
        Directions:
        - Preheat oven
        - Mix ingredients
        - Bake
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertGreaterThanOrEqual(result.instructions.count, 2)
    }

    func test_detectInstructions_removesNumbering() {
        let ocrText = """
        Instructions:
        1. Preheat oven to 350°F
        2. Mix ingredients
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        // Numbering should be stripped
        XCTAssertFalse(result.instructions[0].hasPrefix("1."))
        XCTAssertTrue(result.instructions[0].contains("Preheat"))
    }

    // MARK: - Metadata Extraction Tests

    func test_extractServings_various Formats() {
        let tests = [
            ("Serves 4", 4),
            ("Makes 12 cookies", 12),
            ("Yield: 6 servings", 6),
            ("Servings: 8", 8)
        ]

        for (text, expected) in tests {
            let result = parser.parseRecipeStructure(from: text)
            XCTAssertEqual(result.servings, "\(expected) servings")
        }
    }

    func test_extractPrepTime_variousFormats() {
        let tests = [
            "Prep time: 15 minutes",
            "Prep: 15 min",
            "Preparation: 15m"
        ]

        for text in tests {
            let result = parser.parseRecipeStructure(from: text)
            XCTAssertNotNil(result.prepTime)
            XCTAssertTrue(result.prepTime!.contains("15"))
        }
    }

    func test_extractCookTime_variousFormats() {
        let tests = [
            "Cook time: 30 minutes",
            "Bake: 30 min",
            "Cooking: 30m"
        ]

        for text in tests {
            let result = parser.parseRecipeStructure(from: text)
            XCTAssertNotNil(result.cookTime)
            XCTAssertTrue(result.cookTime!.contains("30"))
        }
    }

    // MARK: - Confidence Scoring Tests

    func test_confidence_wellStructuredRecipe() {
        let ocrText = """
        Chocolate Chip Cookies

        Ingredients:
        - 2 cups flour
        - 1 cup sugar
        - 2 eggs

        Instructions:
        1. Mix dry ingredients
        2. Add wet ingredients
        3. Bake at 350°F for 12 minutes
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertGreaterThan(result.titleConfidence, 0.7)
        XCTAssertGreaterThan(result.ingredientsConfidence, 0.8)
        XCTAssertGreaterThan(result.instructionsConfidence, 0.8)
    }

    func test_confidence_poorlyStructuredRecipe() {
        let ocrText = """
        Some random text
        2 cups flour 1 cup sugar
        mix and bake
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertLessThan(result.ingredientsConfidence, 0.6)
    }

    // MARK: - Section Detection Tests

    func test_detectSections_ingredients() {
        let ocrText = """
        Ingredients:
        - flour
        - sugar
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertGreaterThan(result.ingredients.count, 0)
    }

    func test_detectSections_instructionsVariations() {
        let variations = [
            "Instructions:",
            "Directions:",
            "Method:",
            "Steps:",
            "Preparation:"
        ]

        for header in variations {
            let ocrText = """
            \(header)
            1. Step one
            2. Step two
            """

            let result = parser.parseRecipeStructure(from: ocrText)
            XCTAssertGreaterThan(result.instructions.count, 0, "Failed for header: \(header)")
        }
    }

    // MARK: - Quality Assessment Tests

    func test_quality_excellent() {
        let ocrText = """
        Chocolate Chip Cookies
        Prep: 15 min | Cook: 12 min | Serves: 24

        Ingredients:
        - 2 cups all-purpose flour
        - 1 cup butter, softened
        - 1 cup sugar
        - 2 eggs

        Instructions:
        1. Preheat oven to 350°F
        2. Mix butter and sugar
        3. Add eggs and flour
        4. Bake for 12 minutes
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertGreaterThan(result.overallConfidence, 0.8)
    }

    func test_quality_poor() {
        let ocrText = """
        smudged text
        unclear measurements
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        XCTAssertLessThan(result.overallConfidence, 0.5)
    }

    // MARK: - Edge Cases

    func test_emptyText() {
        let result = parser.parseRecipeStructure(from: "")

        XCTAssertNil(result.title)
        XCTAssertEqual(result.ingredients.count, 0)
        XCTAssertEqual(result.instructions.count, 0)
    }

    func test_onlyTitle() {
        let result = parser.parseRecipeStructure(from: "Chocolate Chip Cookies")

        XCTAssertNotNil(result.title)
        XCTAssertEqual(result.ingredients.count, 0)
        XCTAssertEqual(result.instructions.count, 0)
    }

    func test_multipleIngredientSections() {
        let ocrText = """
        Dry Ingredients:
        - 2 cups flour
        - 1 tsp salt

        Wet Ingredients:
        - 2 eggs
        - 1 cup milk
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        // Should combine both sections
        XCTAssertGreaterThanOrEqual(result.ingredients.count, 3)
    }

    func test_handwrittenSimulation() {
        // Simulate OCR of handwritten text (more errors, less structure)
        let ocrText = """
        choc chip cookies

        flour 2c
        sugar lc
        eggs 2

        mix bake 350 12min
        """

        let result = parser.parseRecipeStructure(from: ocrText)

        // Should still extract something
        XCTAssertNotNil(result.title)
        XCTAssertGreaterThan(result.ingredients.count, 0)
    }
}
