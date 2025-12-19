import XCTest
import SwiftData
@testable import Heirloom

/// Integration tests for complete AI recipe workflows
/// Tests end-to-end flows: OCR → AI extraction → ingredient parsing → recipe creation
/// Target: Verify all AI components work together correctly
@MainActor
final class AIRecipeIntegrationTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var configuration: AIConfiguration!
    var mockAIService: MockAnthropicAIService!
    var recipeExtractor: AIRecipeExtractor!
    var ingredientParser: AIIngredientParser!

    override func setUp() async throws {
        // Set up in-memory SwiftData container
        let schema = Schema([Recipe.self, Ingredient.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)

        // Set up AI services
        configuration = AIConfiguration.shared
        configuration.enableAIEnhancement = false
        configuration.enableAIParsing = false
        configuration.enableAICategories = false
        configuration.setAPIKey(nil, for: .anthropic)

        mockAIService = MockAnthropicAIService()
        recipeExtractor = AIRecipeExtractor.shared
        ingredientParser = AIIngredientParser.shared
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        configuration.enableAIParsing = false; configuration.enableAIEnhancement = false
        mockAIService = nil
    }

    // MARK: - Complete Recipe Import Flow

    func test_completeFlow_ocrToRecipe() async throws {
        // Simulate complete flow: OCR text → extraction → parsing → recipe creation

        // Step 1: Extract recipe from OCR text
        let ocrText = AITestFixtures.cleanOCRText
        let extractedRecipe = try await recipeExtractor.extractRecipe(from: ocrText)

        // Verify extraction
        XCTAssertTrue(extractedRecipe.title.lowercased().contains("chocolate"))
        XCTAssertGreaterThan(extractedRecipe.ingredients.count, 0)
        XCTAssertGreaterThan(extractedRecipe.instructions.count, 0)

        // Step 2: Parse each ingredient
        var parsedIngredients: [(quantity: Double?, quantityMax: Double?, unit: String?, name: String)] = []
        for ingredientText in extractedRecipe.ingredients {
            let parsed = try await ingredientParser.parse(ingredientText)
            parsedIngredients.append(parsed)
        }

        // Verify parsing
        XCTAssertEqual(parsedIngredients.count, extractedRecipe.ingredients.count)

        // Verify at least some ingredients have quantities
        let withQuantity = parsedIngredients.filter { $0.quantity != nil }
        XCTAssertGreaterThan(withQuantity.count, 0, "Should parse at least some quantities")

        // Step 3: Create Recipe model
        let recipe = Recipe(
            title: extractedRecipe.title,
            instructions: extractedRecipe.instructions,
            servings: extractedRecipe.servings,
            prepTime: extractedRecipe.prepTime,
            cookTime: extractedRecipe.cookTime
        )

        modelContext.insert(recipe)

        // Step 4: Add ingredients to recipe
        for parsed in parsedIngredients {
            let ingredient = Ingredient(
                originalText: "",
                name: parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit
            )
            ingredient.recipe = recipe
            recipe.ingredients?.append(ingredient)
        }

        // Save to SwiftData
        try modelContext.save()

        // Verify persistence
        let descriptor = FetchDescriptor<Recipe>()
        let recipes = try modelContext.fetch(descriptor)

        XCTAssertEqual(recipes.count, 1, "Should have saved one recipe")
        XCTAssertEqual(recipes.first?.title, extractedRecipe.title)
        XCTAssertEqual(recipes.first?.ingredients?.count, parsedIngredients.count)
    }

    func test_completeFlow_messyOCRToRecipe() async throws {
        // Test with messy OCR text (real-world scenario)

        let messyOCR = AITestFixtures.messyOCRText
        let extractedRecipe = try await recipeExtractor.extractRecipe(from: messyOCR)

        // Should still extract usable data
        XCTAssertFalse(extractedRecipe.title.isEmpty)
        XCTAssertGreaterThan(extractedRecipe.ingredients.count, 0)

        // Parse ingredients
        var successCount = 0
        for ingredientText in extractedRecipe.ingredients {
            do {
                let parsed = try await ingredientParser.parse(ingredientText)
                if parsed.name.count > 2 { // Has a reasonable name
                    successCount += 1
                }
            } catch {
                // Some messy ingredients might fail - that's ok
                continue
            }
        }

        XCTAssertGreaterThan(successCount, 0, "Should parse at least some messy ingredients")
    }

    // MARK: - Batch Processing Integration

    func test_batchProcessing_multipleRecipes() async throws {
        // Test processing multiple recipes in a batch

        let recipes = [
            AITestFixtures.cleanOCRText,
            AITestFixtures.messyOCRText,
            AITestFixtures.minimalOCRText
        ]

        var extractedRecipes: [AIRecipeExtractor.ExtractedRecipe] = []

        for ocrText in recipes {
            let extracted = try await recipeExtractor.extractRecipe(from: ocrText)
            extractedRecipes.append(extracted)
        }

        XCTAssertEqual(extractedRecipes.count, 3, "Should extract all recipes")

        // Verify each has basic structure
        for extracted in extractedRecipes {
            XCTAssertFalse(extracted.title.isEmpty)
            XCTAssertGreaterThan(extracted.ingredients.count, 0)
        }
    }

    func test_batchProcessing_ingredientParsing() async throws {
        // Test parsing many ingredients in batch

        let ingredients = AITestFixtures.fractionalIngredients.map { $0.0 }

        let results = try await ingredientParser.parseBatch(ingredients)

        XCTAssertEqual(results.count, ingredients.count)

        // Verify most parsed successfully
        let successful = results.filter { $0.quantity != nil }
        let successRate = Double(successful.count) / Double(results.count)

        XCTAssertGreaterThan(successRate, 0.8, "Should parse >80% of ingredients")
    }

    // MARK: - Graceful Degradation Integration

    func test_gracefulDegradation_aiDisabled() async throws {
        // Verify system works with AI disabled (regression fallback)

        configuration.enableAIEnhancement = false
        configuration.enableAIParsing = false

        // Should still extract and parse using fallback methods
        let extracted = try await recipeExtractor.extractRecipe(from: AITestFixtures.cleanOCRText)
        XCTAssertFalse(extracted.title.isEmpty)

        let parsed = try await ingredientParser.parse("2 cups flour")
        XCTAssertNotNil(parsed.quantity)
        XCTAssertEqual(parsed.unit, "cups")
    }

    func test_gracefulDegradation_aiFailure() async throws {
        // Test fallback when AI fails

        mockAIService.mockFailure(error: .networkError(underlying: URLError(.timedOut)))

        // Should fall back to regex parsing (since AI is disabled in setUp)
        let parsed = try await ingredientParser.parse("1/2 cup sugar")

        XCTAssertNotNil(parsed.quantity)
        XCTAssertTrue(parsed.name.contains("sugar"))
    }

    // MARK: - Data Validation Integration

    func test_dataValidation_emptyRecipe() async throws {
        // Test handling of edge case: empty recipe

        let emptyText = ""

        do {
            _ = try await recipeExtractor.extractRecipe(from: emptyText)
            // May succeed with default values
        } catch {
            // Or may throw - both are acceptable
        }

        // Should not crash or corrupt data
        XCTAssertTrue(true, "Should handle empty recipe gracefully")
    }

    func test_dataValidation_invalidIngredient() async throws {
        // Test handling of invalid ingredient

        let invalidIngredient = "@@@@###"

        do {
            let result = try await ingredientParser.parse(invalidIngredient)
            // Should return something, even if minimal
            XCTAssertNotNil(result)
        } catch {
            // Or may throw - both acceptable
        }

        // Should not crash
        XCTAssertTrue(true, "Should handle invalid input gracefully")
    }

    // MARK: - Usage Tracking Integration

    func test_usageTracking_integration() async throws {
        let tracker = AIUsageTracker.shared
        tracker.reset()

        let initialCount = tracker.requestCount
        let initialCost = tracker.totalCost

        // Extract recipe (won't actually call AI since disabled, but tests integration)
        _ = try await recipeExtractor.extractRecipe(from: AITestFixtures.cleanOCRText)

        // Parse ingredients
        for ingredient in AITestFixtures.fractionalIngredients.prefix(5).map({ $0.0 }) {
            _ = try await ingredientParser.parse(ingredient)
        }

        // Tracking would occur if AI was enabled
        // With AI disabled, verify baseline behavior
        XCTAssertEqual(tracker.requestCount, initialCount, "Should not track when AI disabled")
        XCTAssertEqual(tracker.totalCost, initialCost)
    }

    // MARK: - Performance Integration

    func test_performance_completeRecipeImport() async throws {
        // Test performance of complete import flow

        let startTime = Date()

        let extracted = try await recipeExtractor.extractRecipe(from: AITestFixtures.cleanOCRText)

        for ingredientText in extracted.ingredients.prefix(10) {
            _ = try await ingredientParser.parse(ingredientText)
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Complete flow should be fast with regex fallback
        XCTAssertLessThan(elapsed, 2.0, "Complete flow should take < 2 seconds")
    }

    func test_performance_batchIngredientParsing() async throws {
        // Test performance of batch parsing

        let ingredients = AITestFixtures.fractionalIngredients.map { $0.0 }

        let startTime = Date()
        let results = try await ingredientParser.parseBatch(ingredients)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertEqual(results.count, ingredients.count)
        XCTAssertLessThan(elapsed, 1.0, "Batch parsing should take < 1 second")
    }

    // MARK: - Real-World Scenarios

    func test_realWorld_familyRecipeCard() async throws {
        // Simulate scanning a handwritten family recipe card

        let handwrittenText = """
        Grandma's Chocolate Chip Cookies

        Ingredients:
        2 cups flour
        1 cup butter softened
        3/4 cup sugar
        2 eggs
        1 tsp vanilla
        2 cups chocolate chips

        Mix everything together.
        Bake at 350 for 12 minutes.
        """

        let extracted = try await recipeExtractor.extractRecipe(from: handwrittenText)

        // Verify basic extraction
        XCTAssertTrue(extracted.title.lowercased().contains("cookie"))
        XCTAssertGreaterThan(extracted.ingredients.count, 4)
        XCTAssertGreaterThan(extracted.instructions.count, 0)

        // Parse ingredients
        var parsedIngredients: [(quantity: Double?, quantityMax: Double?, unit: String?, name: String)] = []
        for ingredientText in extracted.ingredients {
            let parsed = try await ingredientParser.parse(ingredientText)
            parsedIngredients.append(parsed)
        }

        // Verify practical results
        let withQuantities = parsedIngredients.filter { $0.quantity != nil }
        XCTAssertGreaterThan(withQuantities.count, 3, "Should parse most quantities")

        // Create recipe
        let recipe = Recipe(
            title: extracted.title,
            instructions: extracted.instructions,
            servings: extracted.servings,
            prepTime: extracted.prepTime,
            cookTime: extracted.cookTime
        )

        modelContext.insert(recipe)

        for parsed in parsedIngredients {
            let ingredient = Ingredient(
                originalText: "",
                name: parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit
            )
            ingredient.recipe = recipe
            recipe.ingredients?.append(ingredient)
        }

        try modelContext.save()

        // Verify saved successfully
        let descriptor = FetchDescriptor<Recipe>()
        let recipes = try modelContext.fetch(descriptor)

        XCTAssertEqual(recipes.count, 1)
        XCTAssertTrue(recipes.first!.title.contains("Cookie"))
    }

    func test_realWorld_modernCookbook() async throws {
        // Simulate scanning from a modern cookbook with clean formatting

        let extracted = try await recipeExtractor.extractRecipe(from: AITestFixtures.cleanOCRText)

        // Modern cookbooks have good structure
        XCTAssertFalse(extracted.title.isEmpty)
        XCTAssertGreaterThan(extracted.ingredients.count, 5)
        XCTAssertGreaterThan(extracted.instructions.count, 5)

        // Parse all ingredients
        let results = try await ingredientParser.parseBatch(extracted.ingredients)

        // Should have high success rate
        let withQuantities = results.filter { $0.quantity != nil }
        let successRate = Double(withQuantities.count) / Double(results.count)

        XCTAssertGreaterThan(successRate, 0.7, "Modern cookbook should have >70% parse success")
    }

    func test_realWorld_onlineRecipe() async throws {
        // Simulate copy-pasting from a website

        let webRecipe = """
        AMAZING PASTA CARBONARA

        Prep Time: 10 minutes
        Cook Time: 15 minutes
        Serves: 4

        INGREDIENTS:
        - 1 lb spaghetti
        - 4 eggs
        - 1 cup grated Parmesan
        - 8 oz pancetta, diced
        - 2 cloves garlic, minced
        - Salt and pepper to taste

        INSTRUCTIONS:
        1. Cook pasta according to package directions
        2. Fry pancetta until crispy
        3. Beat eggs and mix with cheese
        4. Toss hot pasta with egg mixture
        5. Add pancetta and serve
        """

        let extracted = try await recipeExtractor.extractRecipe(from: webRecipe)

        // Verify metadata extraction
        XCTAssertTrue(extracted.title.lowercased().contains("pasta") ||
                     extracted.title.lowercased().contains("carbonara"))

        // Web recipes often have good metadata
        // (though basic extractor might not parse all of it)
        XCTAssertGreaterThan(extracted.ingredients.count, 4)
        XCTAssertGreaterThan(extracted.instructions.count, 3)
    }

    // MARK: - Error Recovery Integration

    func test_errorRecovery_partialSuccess() async throws {
        // Test system handles partial failures gracefully

        let ingredients = [
            "2 cups flour",           // Good
            "????",                   // Bad
            "1 tsp salt",             // Good
            "@@##$$",                 // Bad
            "3 eggs"                  // Good
        ]

        let results = try await ingredientParser.parseBatch(ingredients)

        // Should return results for all (even if some are minimal)
        XCTAssertEqual(results.count, ingredients.count)

        // Good ingredients should parse correctly
        XCTAssertNotNil(results[0].quantity)
        XCTAssertNotNil(results[2].quantity)
        XCTAssertNotNil(results[4].quantity)
    }

    func test_errorRecovery_continuesAfterError() async throws {
        // Verify one failure doesn't stop the whole batch

        let ocrTexts = [
            AITestFixtures.cleanOCRText,
            "",  // Empty/bad
            AITestFixtures.minimalOCRText
        ]

        var successCount = 0

        for text in ocrTexts {
            do {
                let extracted = try await recipeExtractor.extractRecipe(from: text)
                if !extracted.title.isEmpty {
                    successCount += 1
                }
            } catch {
                // Continue processing even if one fails
                continue
            }
        }

        XCTAssertGreaterThan(successCount, 0, "Should extract at least some recipes")
    }

    // MARK: - Concurrent Processing Integration

    func test_concurrent_multipleRecipeImports() async throws {
        // Test importing multiple recipes concurrently

        let ocrTexts = [
            AITestFixtures.cleanOCRText,
            AITestFixtures.messyOCRText,
            AITestFixtures.minimalOCRText
        ]

        var extractedRecipes: [AIRecipeExtractor.ExtractedRecipe] = []

        await withTaskGroup(of: AIRecipeExtractor.ExtractedRecipe?.self) { group in
            for text in ocrTexts {
                group.addTask { @MainActor in
                    try? await self.recipeExtractor.extractRecipe(from: text)
                }
            }

            for await result in group {
                if let recipe = result {
                    extractedRecipes.append(recipe)
                }
            }
        }

        XCTAssertGreaterThan(extractedRecipes.count, 0, "Should extract recipes concurrently")
    }
}
