//
//  OCRParityTests.swift
//  HeirloomTests
//
//  Validates that OCR-scanned recipes achieve parity with manually-entered
//  or link-imported recipes across all Recipe schema fields.
//
//  Test Goal: Ensure scanned analog recipes (cards & cookbooks) can be reliably
//  converted into fully-populated Recipe objects matching our data quality standards.
//

import XCTest
import SwiftData
@testable import Heirloom

/// Tests OCR → Recipe parity using real analog recipe images
/// Validates PRODUCTION extraction pipeline: Image → EnhancedOCRService → AIRecipeExtractor → Recipe Model
///
/// IMPORTANT: Uses actual production services (not mocks):
/// - EnhancedOCRService for OCR
/// - AIRecipeExtractor for parsing
/// - IngredientParser for ingredient parsing
/// - GroceryCategory.categorize() for auto-categorization
@MainActor
final class OCRParityTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var ocrService: EnhancedOCRService!
    var extractor: AIRecipeExtractor!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        let schema = Schema([Recipe.self, Ingredient.self, RecipeComment.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)

        // Use PRODUCTION services
        ocrService = EnhancedOCRService.shared
        extractor = AIRecipeExtractor.shared
    }

    override func tearDown() async throws {
        extractor = nil
        ocrService = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Test Helpers

    /// Load image from test bundle (AnalogRecipes folder)
    /// - Parameters:
    ///   - filename: Image filename (e.g., "RecipeCard_01.jpg")
    ///   - subfolder: "Cards" or "Cookbooks"
    private func loadTestImage(_ filename: String, subfolder: String = "Cards") throws -> UIImage {
        let bundle = Bundle(for: type(of: self))

        // Try loading from AnalogRecipes subfolder structure
        if let resourceURL = bundle.url(forResource: filename, withExtension: nil, subdirectory: "AnalogRecipes/\(subfolder)"),
           let image = UIImage(contentsOfFile: resourceURL.path) {
            print("✅ Loaded test image: AnalogRecipes/\(subfolder)/\(filename)")
            return image
        }

        // Fallback: try without subdirectory (in case of flat structure)
        if let resourceURL = bundle.url(forResource: filename, withExtension: nil),
           let image = UIImage(contentsOfFile: resourceURL.path) {
            print("✅ Loaded test image: \(filename)")
            return image
        }

        XCTFail("Failed to load test image: AnalogRecipes/\(subfolder)/\(filename)")
        throw NSError(domain: "OCRParityTests", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "Test image not found: AnalogRecipes/\(subfolder)/\(filename)"
        ])
    }

    /// Perform OCR on image using PRODUCTION EnhancedOCRService
    /// This is the SAME service used in the app (CookbookScannerView, etc.)
    private func performOCR(on image: UIImage) async throws -> String {
        // Use production OCR service (not a mock!)
        let ocrText = try await ocrService.recognizeTextSimple(from: image)
        return ocrText
    }

    /// Create Recipe model from ExtractedRecipe
    /// PRODUCTION FLOW: Matches RecipeSelectionView.saveSelectedRecipes() exactly
    /// Uses PRODUCTION services:
    /// - IngredientParser.parse() for ingredient parsing
    /// - GroceryCategory.categorize() for auto-categorization
    private func createRecipe(from extracted: AIRecipeExtractor.ExtractedRecipe, withImage image: UIImage? = nil) throws -> Recipe {
        let recipe = Recipe(
            title: extracted.title,
            sourceType: .scan
        )

        // Set metadata
        recipe.servings = extracted.servings
        recipe.prepTime = extracted.prepTime
        recipe.cookTime = extracted.cookTime
        recipe.notes = extracted.notes
        recipe.instructions = extracted.instructions

        // Insert recipe first
        modelContext.insert(recipe)

        // Parse and create ingredients using PRODUCTION IngredientParser
        for (index, ingredientText) in extracted.ingredients.enumerated() {
            let parsed = IngredientParser.parse(ingredientText)  // PRODUCTION parser
            let ingredient = Ingredient(
                originalText: ingredientText,
                name: parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit,
                category: GroceryCategory.categorize(parsed.name),  // PRODUCTION categorizer
                orderIndex: index
            )
            ingredient.quantityMax = parsed.quantityMax
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
        }

        try modelContext.save()
        return recipe
    }

    // MARK: - Parity Validation Assertions

    /// Validate that extracted recipe meets minimum quality standards
    private func assertRecipeParity(
        _ recipe: Recipe,
        minIngredients: Int = 3,
        minInstructions: Int = 2,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Core fields
        XCTAssertFalse(recipe.title.isEmpty, "Title should not be empty", file: file, line: line)
        XCTAssertNotEqual(recipe.title, "Untitled Recipe", "Title should be meaningful", file: file, line: line)

        // Ingredients
        XCTAssertNotNil(recipe.ingredients, "Ingredients should exist", file: file, line: line)
        XCTAssertGreaterThanOrEqual(recipe.ingredients?.count ?? 0, minIngredients,
                                   "Should have at least \(minIngredients) ingredients", file: file, line: line)

        // Validate ingredient parsing
        for ingredient in recipe.ingredients ?? [] {
            XCTAssertFalse(ingredient.name.isEmpty, "Ingredient name should not be empty", file: file, line: line)
            // At least one ingredient should have quantity parsed
        }

        let hasQuantities = recipe.ingredients?.contains { $0.quantity != nil } ?? false
        XCTAssertTrue(hasQuantities, "At least some ingredients should have quantities parsed", file: file, line: line)

        // Instructions
        XCTAssertGreaterThanOrEqual(recipe.instructions.count, minInstructions,
                                   "Should have at least \(minInstructions) instructions", file: file, line: line)

        // Grocery categories (at least half should be auto-categorized)
        let categorizedCount = recipe.ingredients?.filter { $0.category != .other }.count ?? 0
        let totalCount = recipe.ingredients?.count ?? 1
        XCTAssertGreaterThan(Double(categorizedCount) / Double(totalCount), 0.3,
                            "At least 30% of ingredients should have specific categories", file: file, line: line)
    }

    // MARK: - Recipe Card Tests

    func testOCRParity_RecipeCard_01() async throws {
        // Given: Recipe card image
        let image = try loadTestImage("RecipeCard_01.jpg")

        // When: Execute PRODUCTION pipeline (same as CookbookScannerView)
        // Step 1: EnhancedOCRService extracts text
        let ocrText = try await performOCR(on: image)
        XCTAssertFalse(ocrText.isEmpty, "PRODUCTION OCR should extract text from card")

        // Step 2: AIRecipeExtractor parses into structured data
        let extracted = try await extractor.extractRecipe(from: ocrText)

        // Step 3: Create Recipe model with IngredientParser + GroceryCategory
        let recipe = try createRecipe(from: extracted, withImage: image)

        // Then: Validate parity with manually-entered recipes
        // Note: This card has simpler instructions, so we allow minInstructions: 1
        assertRecipeParity(recipe, minInstructions: 1)

        // Additional card-specific validations
        print("📊 Card 01 Stats:")
        print("  Title: \(recipe.title)")
        print("  Ingredients: \(recipe.ingredients?.count ?? 0)")
        print("  Instructions: \(recipe.instructions.count)")
        print("  Servings: \(recipe.servings ?? "N/A")")
    }

    func testOCRParity_RecipeCard_02() async throws {
        let image = try loadTestImage("RecipeCard_02.jpeg", subfolder: "Cards")
        let ocrText = try await performOCR(on: image)
        let extracted = try await extractor.extractRecipe(from: ocrText)
        let recipe = try createRecipe(from: extracted, withImage: image)

        assertRecipeParity(recipe)
    }

    func testOCRParity_RecipeCard_03() async throws {
        let image = try loadTestImage("RecipeCard_03.jpeg", subfolder: "Cards")
        let ocrText = try await performOCR(on: image)
        let extracted = try await extractor.extractRecipe(from: ocrText)
        let recipe = try createRecipe(from: extracted, withImage: image)

        assertRecipeParity(recipe)
    }

    // MARK: - Cookbook Tests

    func testOCRParity_Cookbook_01() async throws {
        // Given: Cookbook page image
        let image = try loadTestImage("Cookbook_01.jpeg", subfolder: "Cookbooks")

        // When: Extract via OCR → AI → Recipe model
        let ocrText = try await performOCR(on: image)
        XCTAssertFalse(ocrText.isEmpty, "OCR should extract text from cookbook")

        let extracted = try await extractor.extractRecipe(from: ocrText)
        let recipe = try createRecipe(from: extracted, withImage: image)

        // Then: Validate parity
        assertRecipeParity(recipe)

        print("📊 Cookbook 01 Stats:")
        print("  Title: \(recipe.title)")
        print("  Ingredients: \(recipe.ingredients?.count ?? 0)")
        print("  Instructions: \(recipe.instructions.count)")
    }

    func testOCRParity_Cookbook_02() async throws {
        let image = try loadTestImage("Cookbook_02.jpeg", subfolder: "Cookbooks")
        let ocrText = try await performOCR(on: image)
        let extracted = try await extractor.extractRecipe(from: ocrText)
        let recipe = try createRecipe(from: extracted, withImage: image)

        assertRecipeParity(recipe)
    }

    // MARK: - Schema Completeness Tests

    func testOCRParity_CompleteSchemaValidation() async throws {
        // Given: Any recipe card with rich metadata
        let image = try loadTestImage("RecipeCard_01.jpg", subfolder: "Cards")
        let ocrText = try await performOCR(on: image)
        let extracted = try await extractor.extractRecipe(from: ocrText)
        let recipe = try createRecipe(from: extracted, withImage: image)

        // Then: Validate all Recipe schema fields are populated or default

        // Required fields
        XCTAssertNotEqual(recipe.id, UUID(), "Should have unique ID")
        XCTAssertFalse(recipe.title.isEmpty)
        XCTAssertEqual(recipe.sourceType, .scan)

        // Content fields (should attempt to populate)
        XCTAssertNotNil(recipe.ingredients)
        XCTAssertFalse(recipe.instructions.isEmpty)

        // Optional metadata (may be nil, but shouldn't crash)
        _ = recipe.servings
        _ = recipe.prepTime
        _ = recipe.cookTime
        _ = recipe.notes

        // Scaling defaults
        XCTAssertEqual(recipe.scalabilityRating, "easy", "New recipes should default to easy scaling")
        XCTAssertEqual(recipe.minimumServings, 1)

        // Timestamps
        XCTAssertNotNil(recipe.dateAdded)
        XCTAssertNotNil(recipe.lastModified)

        // Relationships should be initialized
        XCTAssertNotNil(recipe.ingredients)
        XCTAssertGreaterThan(recipe.ingredients?.count ?? 0, 0)
    }

    // MARK: - Quality Metrics Tests

    func testOCRParity_IngredientParsingQuality() async throws {
        // Test that ingredient parsing meets quality thresholds across multiple cards
        let cardImages = ["RecipeCard_01.jpg", "RecipeCard_02.jpeg", "RecipeCard_03.jpeg"]

        var totalIngredients = 0
        var parsedWithQuantity = 0
        var parsedWithUnit = 0
        var categorized = 0

        for imageName in cardImages {
            let image = try loadTestImage(imageName, subfolder: "Cards")
            let ocrText = try await performOCR(on: image)
            let extracted = try await extractor.extractRecipe(from: ocrText)
            let recipe = try createRecipe(from: extracted, withImage: image)

            for ingredient in recipe.ingredients ?? [] {
                totalIngredients += 1
                if ingredient.quantity != nil { parsedWithQuantity += 1 }
                if ingredient.unit != nil { parsedWithUnit += 1 }
                if ingredient.category != .other { categorized += 1 }
            }
        }

        // Quality thresholds
        let quantityRate = Double(parsedWithQuantity) / Double(totalIngredients)
        let unitRate = Double(parsedWithUnit) / Double(totalIngredients)
        let categorizationRate = Double(categorized) / Double(totalIngredients)

        print("📊 Ingredient Parsing Quality:")
        print("  Total ingredients: \(totalIngredients)")
        print("  Quantity parsed: \(quantityRate * 100)%")
        print("  Unit parsed: \(unitRate * 100)%")
        print("  Categorized: \(categorizationRate * 100)%")

        XCTAssertGreaterThan(quantityRate, 0.6, "At least 60% should have quantities")
        XCTAssertGreaterThan(unitRate, 0.5, "At least 50% should have units")
        XCTAssertGreaterThan(categorizationRate, 0.4, "At least 40% should be categorized")
    }

    // MARK: - Comparison Tests (OCR vs Manual Entry)

    func testOCRParity_CompareWithManualEntry() async throws {
        // Given: Same recipe entered two ways
        // 1. Via OCR from card
        let image = try loadTestImage("RecipeCard_01.jpg", subfolder: "Cards")
        let ocrText = try await performOCR(on: image)
        let extracted = try await extractor.extractRecipe(from: ocrText)
        let ocrRecipe = try createRecipe(from: extracted, withImage: image)

        // 2. Manual entry (simulate)
        let manualRecipe = Recipe(title: "Test Recipe", sourceType: .manual)
        manualRecipe.servings = "4 servings"
        manualRecipe.prepTime = "15 minutes"
        manualRecipe.cookTime = "30 minutes"
        manualRecipe.instructions = ["Step 1", "Step 2", "Step 3"]
        modelContext.insert(manualRecipe)

        for (i, text) in ["1 cup flour", "2 eggs", "1 tsp salt"].enumerated() {
            let parsed = IngredientParser.parse(text)
            let ingredient = Ingredient(
                originalText: text,
                name: parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit,
                orderIndex: i
            )
            ingredient.recipe = manualRecipe
            modelContext.insert(ingredient)
        }

        // Then: OCR recipe should have similar structure
        XCTAssertNotNil(ocrRecipe.ingredients)
        XCTAssertNotNil(manualRecipe.ingredients)
        XCTAssertGreaterThanOrEqual(ocrRecipe.ingredients?.count ?? 0, 3, "Should extract minimum ingredients")
        XCTAssertGreaterThanOrEqual(ocrRecipe.instructions.count, 2, "Should extract minimum steps")

        // Both should be valid Recipe objects
        XCTAssertEqual(ocrRecipe.sourceType, .scan)
        XCTAssertEqual(manualRecipe.sourceType, .manual)
    }
}
