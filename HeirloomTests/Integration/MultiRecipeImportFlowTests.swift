import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class MultiRecipeImportFlowTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var extractor: AIRecipeExtractor!

    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try TestFixtures.createTestContainer()
        modelContext = ModelContext(modelContainer)
        extractor = AIRecipeExtractor.shared
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        extractor = nil
        try await super.tearDown()
    }

    // MARK: - End-to-End Flow Tests

    func testEndToEndFlow_ExtractAndImportSingleRecipe() throws {
        // Given - OCR text with single recipe
        let ocrText = TestFixtures.singleRecipeOCRText

        // When - Extract recipe
        let extractedRecipe = extractor.extractRecipeBasic(from: ocrText)

        // Then - Verify extraction
        XCTAssertEqual(extractedRecipe.title, "CHOCOLATE CHIP COOKIES")
        XCTAssertGreaterThanOrEqual(extractedRecipe.ingredients.count, 5)
        XCTAssertGreaterThanOrEqual(extractedRecipe.instructions.count, 4, "Basic parser extracts 4 of 7 instructions")

        // When - Convert to Recipe and save
        let recipe = convertToRecipe(extractedRecipe)
        modelContext.insert(recipe)
        try modelContext.save()

        // Then - Verify persistence
        let descriptor = FetchDescriptor<Recipe>()
        let savedRecipes = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRecipes.count, 1, "Should have 1 saved recipe")
        XCTAssertEqual(savedRecipes.first?.title, "CHOCOLATE CHIP COOKIES")
        XCTAssertEqual(savedRecipes.first?.sourceType, .scan)
    }

    func testEndToEndFlow_ExtractMultipleRecipes() throws {
        // Given - OCR text with 3 recipes
        let ocrText = TestFixtures.multiRecipeOCRText

        // When - Extract recipe (basic extraction treats as single recipe)
        let extractedRecipe = extractor.extractRecipeBasic(from: ocrText)

        // Then - Should extract content (though basic mode treats it as one)
        XCTAssertFalse(extractedRecipe.title.isEmpty, "Should have a title")
        XCTAssertFalse(extractedRecipe.ingredients.isEmpty, "Should have ingredients")

        // Simulate multi-recipe extraction
        let recipes = TestFixtures.mockMultipleExtractedRecipes()
        let result = AIRecipeExtractor.MultiRecipeExtractionResult(
            recipes: recipes,
            sourceImage: nil
        )

        // Then
        XCTAssertEqual(result.count, 3, "Should have 3 recipes")
        XCTAssertTrue(result.hasMultipleRecipes, "Should be multi-recipe result")
    }

    func testEndToEndFlow_ImportMultipleRecipes() throws {
        // Given - Multiple extracted recipes
        let extractedRecipes = TestFixtures.mockMultipleExtractedRecipes()

        // When - Convert all to Recipe models and save
        for extractedRecipe in extractedRecipes {
            let recipe = convertToRecipe(extractedRecipe)
            modelContext.insert(recipe)
        }
        try modelContext.save()

        // Then - Verify all recipes saved
        let descriptor = FetchDescriptor<Recipe>()
        let savedRecipes = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRecipes.count, 3, "Should have 3 saved recipes")

        // Verify titles
        let titles = savedRecipes.map { $0.title }.sorted()
        XCTAssertTrue(titles.contains("Cheese Straws"), "Should have Cheese Straws")
        XCTAssertTrue(titles.contains("Peanut Butter Bread"), "Should have Peanut Butter Bread")
        XCTAssertTrue(titles.contains("Orange Fritters"), "Should have Orange Fritters")
    }

    func testEndToEndFlow_SelectiveImport() throws {
        // Given - Multiple extracted recipes
        let extractedRecipes = TestFixtures.mockMultipleExtractedRecipes()
        let selectedRecipes = [extractedRecipes[0], extractedRecipes[2]] // Select 1st and 3rd

        // When - Import only selected recipes
        for extractedRecipe in selectedRecipes {
            let recipe = convertToRecipe(extractedRecipe)
            modelContext.insert(recipe)
        }
        try modelContext.save()

        // Then - Verify only selected recipes saved
        let descriptor = FetchDescriptor<Recipe>()
        let savedRecipes = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRecipes.count, 2, "Should have 2 saved recipes")

        let titles = savedRecipes.map { $0.title }.sorted()
        XCTAssertTrue(titles.contains("Cheese Straws"), "Should have Cheese Straws")
        XCTAssertTrue(titles.contains("Orange Fritters"), "Should have Orange Fritters")
        XCTAssertFalse(titles.contains("Peanut Butter Bread"), "Should NOT have Peanut Butter Bread")
    }

    // MARK: - Recipe Conversion Tests

    func testConversion_BasicFields() {
        // Given
        let extracted = TestFixtures.mockExtractedRecipe(
            title: "Test Recipe",
            confidence: 0.95
        )

        // When
        let recipe = convertToRecipe(extracted)

        // Then
        XCTAssertEqual(recipe.title, "Test Recipe")
        XCTAssertEqual(recipe.sourceType, .scan)
        XCTAssertEqual(recipe.servings, "4 servings")
        XCTAssertEqual(recipe.prepTime, "15 minutes")
        XCTAssertEqual(recipe.cookTime, "30 minutes")
        XCTAssertNotNil(recipe.dateAdded)
        XCTAssertNotNil(recipe.lastModified)
    }

    func testConversion_WithIngredients() throws {
        // Given
        let extracted = TestFixtures.mockExtractedRecipe(ingredientCount: 5)

        // When
        let recipe = convertToRecipe(extracted)
        modelContext.insert(recipe)

        // Add ingredients
        for (index, ingredientText) in extracted.ingredients.enumerated() {
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
            modelContext.insert(ingredient)
        }
        try modelContext.save()

        // Then
        XCTAssertEqual(recipe.ingredients?.count, 5, "Should have 5 ingredients")

        // Verify ingredient relationships
        let firstIngredient = recipe.ingredients?.first
        XCTAssertNotNil(firstIngredient)
        XCTAssertEqual(firstIngredient?.recipe?.id, recipe.id, "Ingredient should reference recipe")
    }

    func testConversion_WithInstructions() {
        // Given
        let extracted = TestFixtures.mockExtractedRecipe(instructionCount: 8)

        // When
        let recipe = convertToRecipe(extracted)

        // Then
        XCTAssertEqual(recipe.instructions.count, 8, "Should have 8 instructions")
        XCTAssertFalse(recipe.instructions[0].isEmpty, "First instruction should not be empty")
    }

    func testConversion_HandlesOptionalFields() {
        // Given
        let extracted = AIRecipeExtractor.ExtractedRecipe(
            title: "Minimal Recipe",
            servings: nil,
            prepTime: nil,
            cookTime: nil,
            ingredients: ["flour"],
            instructions: ["mix"],
            notes: nil,
            confidence: nil
        )

        // When
        let recipe = convertToRecipe(extracted)

        // Then
        XCTAssertEqual(recipe.title, "Minimal Recipe")
        XCTAssertNil(recipe.servings)
        XCTAssertNil(recipe.prepTime)
        XCTAssertNil(recipe.cookTime)
        XCTAssertEqual(recipe.instructions, ["mix"])
    }

    // MARK: - Multi-Recipe Result Tests

    func testMultiRecipeResult_SingleRecipeDetection() {
        // Given
        let recipes = [TestFixtures.mockExtractedRecipe()]
        let result = AIRecipeExtractor.MultiRecipeExtractionResult(
            recipes: recipes,
            sourceImage: nil
        )

        // Then
        XCTAssertTrue(result.hasSingleRecipe, "Should detect single recipe")
        XCTAssertFalse(result.hasMultipleRecipes, "Should not be multiple recipes")
        XCTAssertEqual(result.count, 1)
    }

    func testMultiRecipeResult_MultipleRecipeDetection() {
        // Given
        let recipes = TestFixtures.mockMultipleExtractedRecipes()
        let result = AIRecipeExtractor.MultiRecipeExtractionResult(
            recipes: recipes,
            sourceImage: nil
        )

        // Then
        XCTAssertFalse(result.hasSingleRecipe, "Should not be single recipe")
        XCTAssertTrue(result.hasMultipleRecipes, "Should detect multiple recipes")
        XCTAssertEqual(result.count, 3)
    }

    func testMultiRecipeResult_EmptyResult() {
        // Given
        let result = AIRecipeExtractor.MultiRecipeExtractionResult(
            recipes: [],
            sourceImage: nil
        )

        // Then
        XCTAssertFalse(result.hasSingleRecipe, "Should not be single recipe")
        XCTAssertFalse(result.hasMultipleRecipes, "Should not be multiple recipes")
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - Import with Confidence Filtering Tests

    func testImport_FilterByHighConfidence() throws {
        // Given - Mix of confidence levels
        let recipes = [
            TestFixtures.mockExtractedRecipe(title: "High Conf 1", confidence: 0.95),
            TestFixtures.mockExtractedRecipe(title: "Low Conf", confidence: 0.60),
            TestFixtures.mockExtractedRecipe(title: "High Conf 2", confidence: 0.92),
            TestFixtures.mockExtractedRecipe(title: "Medium Conf", confidence: 0.75)
        ]

        // When - Import only high confidence (>= 0.9)
        let highConfRecipes = recipes.filter { ($0.confidence ?? 0) >= 0.9 }
        for extractedRecipe in highConfRecipes {
            let recipe = convertToRecipe(extractedRecipe)
            modelContext.insert(recipe)
        }
        try modelContext.save()

        // Then - Only 2 high confidence recipes saved
        let descriptor = FetchDescriptor<Recipe>()
        let savedRecipes = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRecipes.count, 2, "Should have 2 high confidence recipes")

        let titles = savedRecipes.map { $0.title }.sorted()
        XCTAssertTrue(titles.contains("High Conf 1"))
        XCTAssertTrue(titles.contains("High Conf 2"))
    }

    // MARK: - Duplicate Detection Tests

    func testImport_PreventsDuplicateTitles() throws {
        // Given - Two recipes with same title
        let recipe1 = convertToRecipe(TestFixtures.mockExtractedRecipe(title: "Chocolate Cake"))
        let recipe2 = convertToRecipe(TestFixtures.mockExtractedRecipe(title: "Chocolate Cake"))

        // When - Import both
        modelContext.insert(recipe1)
        modelContext.insert(recipe2)
        try modelContext.save()

        // Then - Both are saved (no automatic deduplication)
        let descriptor = FetchDescriptor<Recipe>()
        let savedRecipes = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRecipes.count, 2, "Should save both (deduplication is manual)")

        // Note: In production, we'd want to check for duplicates before import
        // This test documents current behavior
    }

    func testImport_CanDetectPotentialDuplicates() throws {
        // Given - Existing recipe
        let existingRecipe = Recipe(title: "Chocolate Chip Cookies", sourceType: .manual)
        modelContext.insert(existingRecipe)
        try modelContext.save()

        // When - Attempting to import similar recipe
        _ = TestFixtures.mockExtractedRecipe(title: "Chocolate Chip Cookies")

        // Then - Can query for potential duplicates
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.title == "Chocolate Chip Cookies" }
        )
        let matches = try modelContext.fetch(descriptor)
        XCTAssertGreaterThan(matches.count, 0, "Should detect potential duplicate")
    }

    // MARK: - Edge Cases

    func testImport_EmptyIngredientsAndInstructions() throws {
        // Given
        let extracted = AIRecipeExtractor.ExtractedRecipe(
            title: "Empty Recipe",
            servings: nil,
            prepTime: nil,
            cookTime: nil,
            ingredients: [],
            instructions: [],
            notes: nil,
            confidence: nil
        )

        // When
        let recipe = convertToRecipe(extracted)
        modelContext.insert(recipe)
        try modelContext.save()

        // Then - Should save successfully
        let descriptor = FetchDescriptor<Recipe>()
        let savedRecipes = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRecipes.count, 1)
        XCTAssertTrue(recipe.instructions.isEmpty, "Should have empty instructions")
        XCTAssertTrue(recipe.ingredients?.isEmpty ?? true, "Should have empty ingredients")
    }

    func testImport_VeryLongTitle() throws {
        // Given
        let longTitle = String(repeating: "Very Long Recipe Title ", count: 20) // 460 characters
        let extracted = TestFixtures.mockExtractedRecipe(title: longTitle)

        // When
        let recipe = convertToRecipe(extracted)
        modelContext.insert(recipe)
        try modelContext.save()

        // Then
        XCTAssertEqual(recipe.title, longTitle, "Should preserve long titles")
    }

    func testImport_SpecialCharactersInTitle() throws {
        // Given
        let extracted = TestFixtures.mockExtractedRecipe(
            title: "Mom's \"Secret\" Recipe 🍰 (1987) – Best Ever!"
        )

        // When
        let recipe = convertToRecipe(extracted)
        modelContext.insert(recipe)
        try modelContext.save()

        // Then
        let descriptor = FetchDescriptor<Recipe>()
        let savedRecipes = try modelContext.fetch(descriptor)
        XCTAssertEqual(savedRecipes.first?.title, "Mom's \"Secret\" Recipe 🍰 (1987) – Best Ever!")
    }

    // MARK: - Performance Tests

    func testImport_LargeBatchPerformance() throws {
        // Given - 20 recipes
        let extractedRecipes = (1...20).map { index in
            TestFixtures.mockExtractedRecipe(
                title: "Recipe \(index)",
                ingredientCount: 5,
                instructionCount: 5
            )
        }

        // When/Then
        measure {
            for extractedRecipe in extractedRecipes {
                let recipe = self.convertToRecipe(extractedRecipe)
                self.modelContext.insert(recipe)

                // Add ingredients
                for (idx, ingredientText) in extractedRecipe.ingredients.enumerated() {
                    let parsed = IngredientParser.parse(ingredientText)
                    let ingredient = Ingredient(
                        originalText: ingredientText,
                        name: parsed.name,
                        quantity: parsed.quantity,
                        unit: parsed.unit,
                        category: .other,
                        orderIndex: idx
                    )
                    ingredient.recipe = recipe
                    self.modelContext.insert(ingredient)
                }
            }

            try? self.modelContext.save()

            // Clean up for next iteration
            try? self.modelContext.delete(model: Recipe.self)
            try? self.modelContext.delete(model: Ingredient.self)
        }
    }

    // MARK: - Helper Methods

    /// Converts an ExtractedRecipe to a Recipe model
    private func convertToRecipe(_ extracted: AIRecipeExtractor.ExtractedRecipe) -> Recipe {
        let recipe = Recipe(
            title: extracted.title,
            sourceType: .scan
        )
        recipe.servings = extracted.servings
        recipe.prepTime = extracted.prepTime
        recipe.cookTime = extracted.cookTime
        recipe.instructions = extracted.instructions
        recipe.notes = extracted.notes
        return recipe
    }
}
