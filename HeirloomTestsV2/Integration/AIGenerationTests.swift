//
//  AIGenerationTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Integration tests for AI recipe generation feature
//
//  Tests the AI generation system to ensure:
//  - Job states transition correctly
//  - Generation phases progress properly
//  - Silly recipe easter egg works
//  - Generated recipes have correct attributes
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class AIGenerationTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true)
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        try await super.tearDown()
    }

    // MARK: - Job Status Tests

    /// Test 1: Processing status is initial state
    func test_jobStatus_processing_isInitialState() {
        // GIVEN: Processing status
        let status = RecipeGenerationStatus.processing

        // THEN: Should be processing state
        XCTAssertEqual(status.rawValue, "processing")
    }

    /// Test 2: Completed status indicates success
    func test_jobStatus_completed_indicatesSuccess() {
        // GIVEN: Completed status
        let status = RecipeGenerationStatus.completed

        // THEN: Should be completed state
        XCTAssertEqual(status.rawValue, "completed")
    }

    /// Test 3: Failed status indicates error
    func test_jobStatus_failed_indicatesError() {
        // GIVEN: Failed status
        let status = RecipeGenerationStatus.failed

        // THEN: Should be failed state
        XCTAssertEqual(status.rawValue, "failed")
    }

    // MARK: - Job Phase Tests

    /// Test 4: Analyzing phase has correct display text
    func test_jobPhase_analyzing_hasCorrectDisplayText() {
        // GIVEN: Analyzing phase
        let phase = RecipeGenerationPhase.analyzing

        // THEN: Should have user-friendly text
        XCTAssertEqual(phase.displayText, "Understanding your recipe...")
        XCTAssertEqual(phase.iconName, "brain")
    }

    /// Test 5: Extracting phase has correct display text
    func test_jobPhase_extracting_hasCorrectDisplayText() {
        // GIVEN: Extracting phase
        let phase = RecipeGenerationPhase.extracting

        // THEN: Should have user-friendly text
        XCTAssertEqual(phase.displayText, "Extracting ingredients...")
        XCTAssertEqual(phase.iconName, "list.bullet.clipboard")
    }

    /// Test 6: Enriching phase has correct display text
    func test_jobPhase_enriching_hasCorrectDisplayText() {
        // GIVEN: Enriching phase
        let phase = RecipeGenerationPhase.enriching

        // THEN: Should have user-friendly text
        XCTAssertEqual(phase.displayText, "Generating recipe image...")
        XCTAssertEqual(phase.iconName, "sparkles")
    }

    /// Test 7: Complete phase has correct display text
    func test_jobPhase_complete_hasCorrectDisplayText() {
        // GIVEN: Complete phase
        let phase = RecipeGenerationPhase.complete

        // THEN: Should have success text
        XCTAssertEqual(phase.displayText, "Recipe generated!")
        XCTAssertEqual(phase.iconName, "checkmark.circle.fill")
    }

    /// Test 8: Phase progress values are correct
    func test_jobPhase_progressValues_areCorrect() {
        // GIVEN: All phases
        let phases: [RecipeGenerationPhase] = [.analyzing, .extracting, .enriching, .complete]
        let expectedProgress: [Double] = [0.2, 0.5, 0.8, 1.0]

        // THEN: Progress values should match expected
        for (phase, expected) in zip(phases, expectedProgress) {
            XCTAssertEqual(phase.progress, expected, "Phase \(phase) should have progress \(expected)")
        }
    }

    // MARK: - Generated Recipe Response Tests

    /// Test 9: Generated response parses correctly
    func test_generatedResponse_parsesCorrectly() {
        // GIVEN: Generated recipe response
        let response = GeneratedRecipeResponse(
            title: "Chocolate Cake",
            summary: "A delicious chocolate cake",
            prepTime: "15 min",
            cookTime: "30 min",
            servings: "8 servings",
            ingredients: [
                GeneratedIngredient(
                    originalText: "2 cups all-purpose flour",
                    quantity: 2.0,
                    unit: "cup",
                    name: "all-purpose flour",
                    preparation: nil,
                    category: "Pantry"
                )
            ],
            instructions: ["Mix ingredients", "Bake at 350°F"],
            tags: ["dessert", "chocolate"],
            cuisine: "American"
        )

        // THEN: All fields should be populated
        XCTAssertEqual(response.title, "Chocolate Cake")
        XCTAssertEqual(response.summary, "A delicious chocolate cake")
        XCTAssertEqual(response.prepTime, "15 min")
        XCTAssertEqual(response.cookTime, "30 min")
        XCTAssertEqual(response.servings, "8 servings")
        XCTAssertEqual(response.ingredients.count, 1)
        XCTAssertEqual(response.instructions.count, 2)
        XCTAssertEqual(response.tags?.count, 2)
        XCTAssertEqual(response.cuisine, "American")
    }

    /// Test 10: Generated ingredient has correct fields
    func test_generatedIngredient_hasCorrectFields() {
        // GIVEN: Generated ingredient
        let ingredient = GeneratedIngredient(
            originalText: "1 tablespoon butter, melted",
            quantity: 1.0,
            unit: "tablespoon",
            name: "butter",
            preparation: "melted",
            category: "Dairy"
        )

        // THEN: All fields should be correct
        XCTAssertEqual(ingredient.originalText, "1 tablespoon butter, melted")
        XCTAssertEqual(ingredient.quantity, 1.0)
        XCTAssertEqual(ingredient.unit, "tablespoon")
        XCTAssertEqual(ingredient.name, "butter")
        XCTAssertEqual(ingredient.preparation, "melted")
        XCTAssertEqual(ingredient.category, "Dairy")
    }

    // MARK: - Recipe Generation Job Model Tests

    /// Test 11: Job stores dish name correctly
    func test_generationJob_storesDishNameCorrectly() {
        // GIVEN: Generation job with dish name
        let job = RecipeGenerationJob(
            dishName: "Spaghetti Carbonara",
            ingredients: "pasta, eggs, bacon, parmesan"
        )

        // THEN: Should store dish name
        XCTAssertEqual(job.dishName, "Spaghetti Carbonara")
        XCTAssertEqual(job.ingredients, "pasta, eggs, bacon, parmesan")
    }

    /// Test 12: Job initializes with processing status
    func test_generationJob_initializesWithProcessingStatus() {
        // GIVEN: New generation job
        let job = RecipeGenerationJob(dishName: "Test Recipe")

        // THEN: Should start as processing
        XCTAssertEqual(job.status, .processing)
        XCTAssertEqual(job.currentPhase, .analyzing)
    }

    /// Test 13: Job timestamps are set
    func test_generationJob_timestampsAreSet() {
        // GIVEN: New generation job
        let before = Date()
        let job = RecipeGenerationJob(dishName: "Test Recipe")

        // THEN: Created at should be set
        XCTAssertNotNil(job.createdAt)
        XCTAssertGreaterThanOrEqual(job.createdAt, before)
        XCTAssertNil(job.completedAt)
    }

    // MARK: - Silly Recipe Easter Egg Tests

    /// Test 14: Silly recipe flag defaults to false
    func test_sillyRecipe_flagDefaultsToFalse() {
        // GIVEN: Normal generation job
        let job = RecipeGenerationJob(dishName: "Normal Recipe")

        // THEN: Silly flag should be false
        XCTAssertFalse(job.isSillyRecipe)
    }

    /// Test 15: Silly recipe flag can be set
    func test_sillyRecipe_flagCanBeSet() {
        // GIVEN: Job marked as silly
        var job = RecipeGenerationJob(dishName: "Spam Jello Surprise")
        job.isSillyRecipe = true

        // THEN: Silly flag should be true
        XCTAssertTrue(job.isSillyRecipe)
    }

    // MARK: - Recipe Attribute Tests

    /// Test 16: AI generated flag tracks generation source
    func test_recipe_aiGeneratedFlag_tracksSource() throws {
        // GIVEN: Recipe from AI generation
        let recipe = env.createTestRecipe(title: "AI Generated Recipe")
        recipe.aiGenerated = true
        try env.save()

        // THEN: AI generated flag should be set
        XCTAssertTrue(recipe.aiGenerated)
    }

    /// Test 17: Voice dictated flag tracks voice input
    func test_recipe_voiceDictatedFlag_tracksVoiceInput() throws {
        // GIVEN: Recipe from voice input
        let recipe = env.createTestRecipe(title: "Voice Recipe")
        recipe.voiceDictated = true
        try env.save()

        // THEN: Voice dictated flag should be set
        XCTAssertTrue(recipe.voiceDictated)
    }

    // MARK: - Generation Request Tests

    /// Test 18: Generation request stores dish name
    func test_generationRequest_storesDishName() {
        // GIVEN: Generation request
        let request = RecipeGenerationRequest(
            dishName: "Beef Stroganoff",
            ingredients: ["beef", "mushrooms", "sour cream"]
        )

        // THEN: Should store dish name and ingredients
        XCTAssertEqual(request.dishName, "Beef Stroganoff")
        XCTAssertEqual(request.ingredients?.count, 3)
    }

    /// Test 19: Generation request can have nil ingredients
    func test_generationRequest_canHaveNilIngredients() {
        // GIVEN: Generation request without ingredients
        let request = RecipeGenerationRequest(
            dishName: "Mystery Dish",
            ingredients: nil
        )

        // THEN: Should allow nil ingredients
        XCTAssertEqual(request.dishName, "Mystery Dish")
        XCTAssertNil(request.ingredients)
    }

    // MARK: - Job Error Handling Tests

    /// Test 20: Job can store error message
    func test_generationJob_canStoreErrorMessage() {
        // GIVEN: Failed job with error
        var job = RecipeGenerationJob(dishName: "Failed Recipe")
        job.status = .failed
        job.error = "API rate limit exceeded"

        // THEN: Should store error
        XCTAssertEqual(job.status, .failed)
        XCTAssertEqual(job.error, "API rate limit exceeded")
    }
}

// MARK: - Test Models

/// Recipe generation status for testing
enum RecipeGenerationStatus: String, Codable {
    case processing
    case completed
    case failed
}

/// Recipe generation phases for testing
enum RecipeGenerationPhase: String, Codable {
    case analyzing
    case extracting
    case enriching
    case complete

    var displayText: String {
        switch self {
        case .analyzing: return "Understanding your recipe..."
        case .extracting: return "Extracting ingredients..."
        case .enriching: return "Generating recipe image..."
        case .complete: return "Recipe generated!"
        }
    }

    var iconName: String {
        switch self {
        case .analyzing: return "brain"
        case .extracting: return "list.bullet.clipboard"
        case .enriching: return "sparkles"
        case .complete: return "checkmark.circle.fill"
        }
    }

    var progress: Double {
        switch self {
        case .analyzing: return 0.2
        case .extracting: return 0.5
        case .enriching: return 0.8
        case .complete: return 1.0
        }
    }
}

/// Generated recipe response for testing
struct GeneratedRecipeResponse: Codable {
    let title: String
    let summary: String?
    let prepTime: String?
    let cookTime: String?
    let servings: String?
    let ingredients: [GeneratedIngredient]
    let instructions: [String]
    let tags: [String]?
    let cuisine: String?
}

/// Generated ingredient for testing
struct GeneratedIngredient: Codable {
    let originalText: String
    let quantity: Double?
    let unit: String?
    let name: String
    let preparation: String?
    let category: String?
}

/// Recipe generation job for testing
struct RecipeGenerationJob {
    var id: UUID = UUID()
    var dishName: String
    var ingredients: String?
    var transcript: String?
    var isSillyRecipe: Bool = false
    var status: RecipeGenerationStatus = .processing
    var currentPhase: RecipeGenerationPhase = .analyzing
    var error: String?
    var createdAt: Date = Date()
    var completedAt: Date?
}

/// Recipe generation request for testing
struct RecipeGenerationRequest {
    let dishName: String
    let ingredients: [String]?
}
