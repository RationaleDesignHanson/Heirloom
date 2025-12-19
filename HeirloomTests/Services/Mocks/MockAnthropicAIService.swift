import Foundation
@testable import Heirloom

/// Mock implementation of AIServiceProtocol for testing
/// Allows tests to control AI service behavior without making real API calls
@MainActor
class MockAnthropicAIService: AIServiceProtocol {

    // MARK: - AIServiceProtocol Conformance

    var providerName: String = "MockAnthropic"

    var isConfigured: Bool = true

    // MARK: - Test Control Properties

    /// Set to true to make the mock throw an error
    var shouldFail: Bool = false

    /// The error to throw when shouldFail is true
    var errorToThrow: AIError?

    /// The response to return from complete()
    var responseToReturn: AICompletionResponse?

    /// The structured response to return from completeStructured()
    var structuredResponseToReturn: Any?

    /// Number of times any method was called
    var callCount: Int = 0

    /// The last prompt passed to complete() or completeStructured()
    var lastPrompt: String?

    /// The last options passed to complete() or completeStructured()
    var lastOptions: AICompletionOptions?

    /// Track all calls for detailed verification
    var callHistory: [(prompt: String, options: AICompletionOptions?)] = []

    // MARK: - AIServiceProtocol Methods

    func complete(
        prompt: String,
        options: AICompletionOptions?
    ) async throws -> AICompletionResponse {
        callCount += 1
        lastPrompt = prompt
        lastOptions = options
        callHistory.append((prompt, options))

        if shouldFail {
            throw errorToThrow ?? AIError.networkError(
                underlying: NSError(domain: "MockError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Mock error for testing"
                ])
            )
        }

        if let response = responseToReturn {
            return response
        }

        // Default mock response
        return AICompletionResponse(
            content: "Mock AI response for: \(prompt.prefix(50))",
            model: "claude-3-haiku-20240307",
            usage: TokenUsage(
                inputTokens: 10,
                outputTokens: 20,
                totalTokens: 30
            ),
            metadata: nil
        )
    }

    func completeStructured<T: Decodable>(
        prompt: String,
        schema: T.Type,
        options: AICompletionOptions?
    ) async throws -> T {
        callCount += 1
        lastPrompt = prompt
        lastOptions = options
        callHistory.append((prompt, options))

        if shouldFail {
            throw errorToThrow ?? AIError.jsonDecodingFailed(
                underlying: NSError(domain: "MockError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Mock JSON decode error"
                ])
            )
        }

        guard let response = structuredResponseToReturn as? T else {
            throw AIError.invalidResponse(
                reason: "Mock not configured with response of type \(T.self). Call mockService.structuredResponseToReturn = YourType(...)"
            )
        }

        return response
    }

    func estimateCost(inputTokens: Int, outputTokens: Int) -> Decimal {
        // Haiku pricing: $0.25 per 1M input, $1.25 per 1M output
        let inputCost = Decimal(inputTokens) / 1_000_000 * 0.25
        let outputCost = Decimal(outputTokens) / 1_000_000 * 1.25
        return inputCost + outputCost
    }

    // MARK: - Test Helper Methods

    /// Reset the mock to initial state
    func reset() {
        shouldFail = false
        errorToThrow = nil
        responseToReturn = nil
        structuredResponseToReturn = nil
        callCount = 0
        lastPrompt = nil
        lastOptions = nil
        callHistory.removeAll()
        isConfigured = true
    }

    /// Configure mock to succeed with specific response
    func mockSuccess(content: String, inputTokens: Int = 10, outputTokens: Int = 20) {
        shouldFail = false
        responseToReturn = AICompletionResponse(
            content: content,
            model: "claude-3-haiku-20240307",
            usage: TokenUsage(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                totalTokens: inputTokens + outputTokens
            ),
            metadata: nil
        )
    }

    /// Configure mock to fail with specific error
    func mockFailure(error: AIError) {
        shouldFail = true
        errorToThrow = error
    }

    /// Configure mock for structured completion
    func mockStructuredSuccess<T: Decodable>(_ value: T) {
        shouldFail = false
        structuredResponseToReturn = value
    }

    /// Verify a specific prompt was sent
    func verifyPromptContains(_ substring: String) -> Bool {
        guard let prompt = lastPrompt else {
            print("❌ No prompt recorded")
            return false
        }

        let contains = prompt.contains(substring)
        if !contains {
            print("❌ Prompt does not contain '\(substring)'")
            print("Actual prompt: \(prompt)")
        }
        return contains
    }

    /// Verify specific options were used
    func verifyOptions(temperature: Double? = nil, maxTokens: Int? = nil) -> Bool {
        guard let options = lastOptions else {
            print("❌ No options recorded")
            return false
        }

        var isValid = true

        if let expectedTemp = temperature {
            if options.temperature != expectedTemp {
                print("❌ Expected temperature \(expectedTemp), got \(options.temperature)")
                isValid = false
            }
        }

        if let expectedTokens = maxTokens {
            if options.maxTokens != expectedTokens {
                print("❌ Expected maxTokens \(expectedTokens), got \(options.maxTokens)")
                isValid = false
            }
        }

        return isValid
    }
}

// MARK: - Mock Response Builders

extension MockAnthropicAIService {

    /// Create a mock ingredient parsing response
    static func mockIngredientResponse(
        quantity: Double?,
        quantityMax: Double? = nil,
        unit: String?,
        name: String
    ) -> AIIngredientParser.ParsedIngredient {
        return AIIngredientParser.ParsedIngredient(
            quantity: quantity,
            quantityMax: quantityMax,
            unit: unit,
            name: name
        )
    }

    /// Create a mock recipe extraction response
    static func mockRecipeResponse(
        title: String,
        servings: String? = nil,
        prepTime: String? = nil,
        cookTime: String? = nil,
        ingredients: [String],
        instructions: [String],
        notes: String? = nil
    ) -> AIRecipeExtractor.ExtractedRecipe {
        return AIRecipeExtractor.ExtractedRecipe(
            title: title,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime,
            ingredients: ingredients,
            instructions: instructions,
            notes: notes
        )
    }
}
