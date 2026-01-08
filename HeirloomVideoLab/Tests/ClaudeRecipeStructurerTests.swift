//
//  ClaudeRecipeStructurerTests.swift
//  HeirloomVideoLabTests
//
//  Created by Claude on 1/8/26.
//
//  Unit tests for ClaudeRecipeStructurer

import XCTest
@testable import HeirloomVideoLab

@MainActor
final class ClaudeRecipeStructurerTests: XCTestCase {

    var sut: ClaudeRecipeStructurer!
    var mockAIService: MockAIService!

    override func setUp() async throws {
        try await super.setUp()
        mockAIService = MockAIService()
        sut = ClaudeRecipeStructurer(aiService: mockAIService)
    }

    override func tearDown() async throws {
        sut = nil
        mockAIService = nil
        try await super.tearDown()
    }

    // MARK: - Happy Path Tests

    func testStructureRecipe_ValidTranscript() async throws {
        // Given: Valid transcript and visual elements
        let transcript = TranscriptionResult(
            text: """
            Today we're making chocolate chip cookies. You'll need 2 cups of flour,
            1 cup of sugar, half a cup of butter, and 2 eggs. First, preheat your
            oven to 350 degrees. Mix the dry ingredients, then add the wet ingredients.
            Bake for 10 to 12 minutes until golden brown.
            """,
            segments: [],
            confidence: 0.85,
            provider: .whisperKit
        )

        let visualElements = ["350°F", "10-12 minutes", "2 cups flour"]

        // Configure mock response
        mockAIService.mockResponse = createMockRecipeJSON()

        // When: Structuring recipe
        let recipe = try await sut.structure(
            transcript: transcript,
            visualElements: visualElements
        )

        // Then: Should return valid structured recipe
        XCTAssertFalse(recipe.title.isEmpty)
        XCTAssertFalse(recipe.ingredients.isEmpty)
        XCTAssertFalse(recipe.steps.isEmpty)
        XCTAssertGreaterThan(recipe.overallConfidence, 0.0)
        XCTAssertLessThanOrEqual(recipe.overallConfidence, 1.0)
    }

    func testStructureRecipe_WithoutVisualElements() async throws {
        // Given: Transcript only, no visual elements
        let transcript = TranscriptionResult(
            text: "Making simple scrambled eggs with butter and salt.",
            segments: [],
            confidence: 0.90,
            provider: .whisperKit
        )

        mockAIService.mockResponse = createMockRecipeJSON()

        // When: Structuring without visual elements
        let recipe = try await sut.structure(
            transcript: transcript,
            visualElements: []
        )

        // Then: Should still extract recipe
        XCTAssertFalse(recipe.title.isEmpty)
        XCTAssertFalse(recipe.ingredients.isEmpty)
    }

    func testStructureRecipe_AllFieldsPopulated() async throws {
        // Given: Complete transcript
        let transcript = createCompleteTranscript()
        mockAIService.mockResponse = createCompleteRecipeJSON()

        // When: Structuring
        let recipe = try await sut.structure(
            transcript: transcript,
            visualElements: ["375°F", "1 hour"]
        )

        // Then: All optional fields should be populated
        XCTAssertNotNil(recipe.description)
        XCTAssertNotNil(recipe.servings)
        XCTAssertNotNil(recipe.prepTime)
        XCTAssertNotNil(recipe.cookTime)
    }

    // MARK: - Ingredient Extraction Tests

    func testIngredientExtraction_WithQuantities() async throws {
        // Given: Transcript with clear quantities
        let transcript = TranscriptionResult(
            text: "You'll need 2 cups of flour and 3 tablespoons of butter.",
            segments: [],
            confidence: 0.85,
            provider: .whisperKit
        )

        mockAIService.mockResponse = """
        {
            "title": "Test Recipe",
            "ingredients": [
                {
                    "originalText": "2 cups of flour",
                    "item": "all-purpose flour",
                    "quantity": "2",
                    "unit": "cups",
                    "preparation": null,
                    "confidence": "explicit"
                },
                {
                    "originalText": "3 tablespoons of butter",
                    "item": "butter",
                    "quantity": "3",
                    "unit": "tablespoons",
                    "preparation": null,
                    "confidence": "explicit"
                }
            ],
            "steps": [{"instruction": "Mix ingredients", "duration": null, "temperature": null, "confidence": "explicit"}],
            "warnings": [],
            "overallConfidence": 0.85
        }
        """

        // When: Structuring
        let recipe = try await sut.structure(transcript: transcript, visualElements: [])

        // Then: Ingredients should have quantities and units
        XCTAssertEqual(recipe.ingredients.count, 2)
        XCTAssertEqual(recipe.ingredients[0].quantity, "2")
        XCTAssertEqual(recipe.ingredients[0].unit, "cups")
        XCTAssertEqual(recipe.ingredients[0].confidence, .explicit)
    }

    func testIngredientExtraction_ImpreciseMeasurements() async throws {
        // Given: Transcript with colloquial measurements
        let transcript = TranscriptionResult(
            text: "Add a pinch of salt and a handful of nuts.",
            segments: [],
            confidence: 0.80,
            provider: .whisperKit
        )

        mockAIService.mockResponse = """
        {
            "title": "Test Recipe",
            "ingredients": [
                {
                    "originalText": "a pinch of salt",
                    "item": "salt",
                    "quantity": "1/16",
                    "unit": "tsp",
                    "preparation": null,
                    "confidence": "approximate"
                },
                {
                    "originalText": "a handful of nuts",
                    "item": "nuts",
                    "quantity": "1/2",
                    "unit": "cup",
                    "preparation": null,
                    "confidence": "approximate"
                }
            ],
            "steps": [{"instruction": "Mix ingredients", "duration": null, "temperature": null, "confidence": "explicit"}],
            "warnings": ["Some measurements were approximate"],
            "overallConfidence": 0.70
        }
        """

        // When: Structuring
        let recipe = try await sut.structure(transcript: transcript, visualElements: [])

        // Then: Should convert to standard measurements with lower confidence
        XCTAssertEqual(recipe.ingredients[0].confidence, .approximate)
        XCTAssertEqual(recipe.ingredients[1].confidence, .approximate)
        XCTAssertFalse(recipe.warnings.isEmpty)
    }

    // MARK: - Step Extraction Tests

    func testStepExtraction_WithTimingAndTemp() async throws {
        // Given: Transcript with timing and temperature
        let transcript = TranscriptionResult(
            text: "Bake at 350 degrees for 25 minutes until golden.",
            segments: [],
            confidence: 0.90,
            provider: .whisperKit
        )

        mockAIService.mockResponse = """
        {
            "title": "Test Recipe",
            "ingredients": [{"originalText": "flour", "item": "flour", "quantity": null, "unit": null, "preparation": null, "confidence": "unknown"}],
            "steps": [
                {
                    "instruction": "Bake until golden brown",
                    "duration": "25 minutes",
                    "temperature": "350°F",
                    "confidence": "explicit"
                }
            ],
            "warnings": [],
            "overallConfidence": 0.90
        }
        """

        // When: Structuring
        let recipe = try await sut.structure(transcript: transcript, visualElements: [])

        // Then: Steps should include timing and temperature
        XCTAssertEqual(recipe.steps.count, 1)
        XCTAssertEqual(recipe.steps[0].duration, "25 minutes")
        XCTAssertEqual(recipe.steps[0].temperature, "350°F")
        XCTAssertEqual(recipe.steps[0].confidence, .explicit)
    }

    func testStepExtraction_LogicalOrdering() async throws {
        // Given: Transcript with multiple steps
        mockAIService.mockResponse = """
        {
            "title": "Multi-Step Recipe",
            "ingredients": [{"originalText": "ingredients", "item": "ingredients", "quantity": null, "unit": null, "preparation": null, "confidence": "unknown"}],
            "steps": [
                {"instruction": "First, mix dry ingredients", "duration": null, "temperature": null, "confidence": "explicit"},
                {"instruction": "Then, add wet ingredients", "duration": null, "temperature": null, "confidence": "explicit"},
                {"instruction": "Finally, bake", "duration": "20 minutes", "temperature": "350°F", "confidence": "explicit"}
            ],
            "warnings": [],
            "overallConfidence": 0.85
        }
        """

        let transcript = createSimpleTranscript()

        // When: Structuring
        let recipe = try await sut.structure(transcript: transcript, visualElements: [])

        // Then: Steps should be in logical order
        XCTAssertEqual(recipe.steps.count, 3)
        XCTAssertTrue(recipe.steps[0].instruction.contains("First"))
        XCTAssertTrue(recipe.steps[1].instruction.contains("Then"))
        XCTAssertTrue(recipe.steps[2].instruction.contains("Finally"))
    }

    // MARK: - Confidence Tests

    func testOverallConfidence_HighQuality() async throws {
        // Given: High quality transcript
        let transcript = TranscriptionResult(
            text: "Detailed recipe with clear measurements",
            segments: [],
            confidence: 0.95,
            provider: .whisperKit
        )

        mockAIService.mockResponse = createMockRecipeJSON(confidence: 0.90)

        // When: Structuring
        let recipe = try await sut.structure(transcript: transcript, visualElements: ["350°F"])

        // Then: Should have high overall confidence
        XCTAssertGreaterThan(recipe.overallConfidence, 0.80)
    }

    func testOverallConfidence_LowQuality_ThrowsError() async throws {
        // Given: Poor quality extraction
        let transcript = createSimpleTranscript()

        mockAIService.mockResponse = createMockRecipeJSON(confidence: 0.25)

        // When/Then: Should throw error for confidence too low
        do {
            _ = try await sut.structure(transcript: transcript, visualElements: [])
            XCTFail("Should throw error for low confidence")
        } catch RecipeParsingError.confidenceTooLow(let confidence) {
            XCTAssertLessThan(confidence, 0.3)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Validation Tests

    func testValidation_MissingTitle_ThrowsError() async throws {
        // Given: Response without title
        let transcript = createSimpleTranscript()

        mockAIService.mockResponse = """
        {
            "title": "",
            "ingredients": [{"originalText": "flour", "item": "flour", "quantity": null, "unit": null, "preparation": null, "confidence": "unknown"}],
            "steps": [{"instruction": "Mix", "duration": null, "temperature": null, "confidence": "explicit"}],
            "warnings": [],
            "overallConfidence": 0.80
        }
        """

        // When/Then: Should throw error
        do {
            _ = try await sut.structure(transcript: transcript, visualElements: [])
            XCTFail("Should throw error for missing title")
        } catch RecipeParsingError.missingTitle {
            // Expected error
        }
    }

    func testValidation_NoContent_ThrowsError() async throws {
        // Given: Response with no ingredients or steps
        let transcript = createSimpleTranscript()

        mockAIService.mockResponse = """
        {
            "title": "Empty Recipe",
            "ingredients": [],
            "steps": [],
            "warnings": [],
            "overallConfidence": 0.80
        }
        """

        // When/Then: Should throw error
        do {
            _ = try await sut.structure(transcript: transcript, visualElements: [])
            XCTFail("Should throw error for no content")
        } catch RecipeParsingError.noRecipeContent {
            // Expected error
        }
    }

    func testValidation_InvalidJSON_ThrowsError() async throws {
        // Given: Invalid JSON response
        let transcript = createSimpleTranscript()

        mockAIService.mockResponse = "This is not valid JSON"

        // When/Then: Should throw error
        do {
            _ = try await sut.structure(transcript: transcript, visualElements: [])
            XCTFail("Should throw error for invalid JSON")
        } catch RecipeParsingError.invalidJSON {
            // Expected error
        }
    }

    // MARK: - Cost Estimation Tests

    func testEstimateCost_ShortTranscript() {
        // Given: Short transcript (500 characters)
        let transcriptLength = 500

        // When: Estimating cost
        let cost = ClaudeRecipeStructurer.estimateCost(
            transcriptLength: transcriptLength,
            includeVisualElements: false
        )

        // Then: Should be very cheap
        XCTAssertLessThan(cost, 0.01)  // Less than 1 cent
    }

    func testEstimateCost_LongTranscript() {
        // Given: Long transcript (15,000 characters ≈ 15 min video)
        let transcriptLength = 15_000

        // When: Estimating cost
        let cost = ClaudeRecipeStructurer.estimateCost(
            transcriptLength: transcriptLength,
            includeVisualElements: true
        )

        // Then: Should be within target range
        XCTAssertGreaterThan(cost, 0.01)
        XCTAssertLessThan(cost, 0.05)  // Within target $0.03-0.04
    }

    func testEstimateCost_WithoutVisualElements() {
        // Given: Same transcript with and without visual elements
        let transcriptLength = 10_000

        // When: Estimating both
        let costWithVisual = ClaudeRecipeStructurer.estimateCost(
            transcriptLength: transcriptLength,
            includeVisualElements: true
        )
        let costWithoutVisual = ClaudeRecipeStructurer.estimateCost(
            transcriptLength: transcriptLength,
            includeVisualElements: false
        )

        // Then: Visual elements should add minimal cost
        XCTAssertLessThan(costWithoutVisual, costWithVisual)
        XCTAssertLessThan(costWithVisual - costWithoutVisual, 0.001)  // <0.1 cent
    }

    // MARK: - Edge Cases

    func testStructureRecipe_VeryShortTranscript() async throws {
        // Given: Very short transcript
        let transcript = TranscriptionResult(
            text: "Mix flour and water.",
            segments: [],
            confidence: 0.70,
            provider: .whisperKit
        )

        mockAIService.mockResponse = createMockRecipeJSON()

        // When: Structuring
        let recipe = try await sut.structure(transcript: transcript, visualElements: [])

        // Then: Should still attempt extraction
        XCTAssertNotNil(recipe)
    }

    func testStructureRecipe_VeryLongTranscript() async throws {
        // Given: Very long transcript (>30 minutes of content)
        let longText = String(repeating: "This is a cooking instruction. ", count: 1000)
        let transcript = TranscriptionResult(
            text: longText,
            segments: [],
            confidence: 0.85,
            provider: .whisperKit
        )

        mockAIService.mockResponse = createMockRecipeJSON()

        // When: Structuring
        let recipe = try await sut.structure(transcript: transcript, visualElements: [])

        // Then: Should handle long transcript
        XCTAssertNotNil(recipe)
    }

    // MARK: - Helper Methods

    private func createMockRecipeJSON(confidence: Double = 0.85) -> String {
        """
        {
            "title": "Chocolate Chip Cookies",
            "description": "Classic homemade cookies",
            "servings": "24 cookies",
            "prepTime": "15 minutes",
            "cookTime": "12 minutes",
            "ingredients": [
                {
                    "originalText": "2 cups flour",
                    "item": "all-purpose flour",
                    "quantity": "2",
                    "unit": "cups",
                    "preparation": null,
                    "confidence": "explicit"
                },
                {
                    "originalText": "1 cup sugar",
                    "item": "granulated sugar",
                    "quantity": "1",
                    "unit": "cup",
                    "preparation": null,
                    "confidence": "explicit"
                }
            ],
            "steps": [
                {
                    "instruction": "Preheat oven to 350°F",
                    "duration": null,
                    "temperature": "350°F",
                    "confidence": "explicit"
                },
                {
                    "instruction": "Mix dry ingredients together",
                    "duration": "5 minutes",
                    "temperature": null,
                    "confidence": "explicit"
                },
                {
                    "instruction": "Bake until golden brown",
                    "duration": "10-12 minutes",
                    "temperature": "350°F",
                    "confidence": "explicit"
                }
            ],
            "warnings": [],
            "overallConfidence": \(confidence)
        }
        """
    }

    private func createCompleteRecipeJSON() -> String {
        createMockRecipeJSON(confidence: 0.90)
    }

    private func createSimpleTranscript() -> TranscriptionResult {
        TranscriptionResult(
            text: "Simple cooking instructions.",
            segments: [],
            confidence: 0.80,
            provider: .whisperKit
        )
    }

    private func createCompleteTranscript() -> TranscriptionResult {
        TranscriptionResult(
            text: """
            Today I'm making my famous chocolate chip cookies. This makes about 24 cookies.
            You'll need 15 minutes for prep and 12 minutes for baking. Get 2 cups of
            all-purpose flour and 1 cup of sugar. First, preheat your oven to 350 degrees.
            Then mix your dry ingredients together. Finally, bake for 10 to 12 minutes.
            """,
            segments: [],
            confidence: 0.90,
            provider: .whisperKit
        )
    }
}

// MARK: - Mock AI Service

@MainActor
class MockAIService: AIServiceProtocol {
    var mockResponse: String = "{}"
    var mockError: Error?

    func complete(
        prompt: String,
        systemPrompt: String?,
        options: AICompletionOptions?
    ) async throws -> AICompletionResponse {

        if let error = mockError {
            throw error
        }

        return AICompletionResponse(
            text: mockResponse,
            usage: AICompletionResponse.TokenUsage(
                inputTokens: 500,
                outputTokens: 200
            )
        )
    }
}
