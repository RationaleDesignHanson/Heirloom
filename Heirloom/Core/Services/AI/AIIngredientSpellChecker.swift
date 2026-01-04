import Foundation

/// AI-powered ingredient spell checker using Anthropic Claude
/// Detects misspellings and suggests corrections for ingredient text
@MainActor
class AIIngredientSpellChecker {
    static let shared = AIIngredientSpellChecker()
    private init() {}

    // MARK: - Result Structure

    struct SpellingResult: Codable {
        let hasIssues: Bool
        let suggestions: [Suggestion]

        enum CodingKeys: String, CodingKey {
            case hasIssues = "has_issues"
            case suggestions
        }
    }

    struct Suggestion: Codable, Identifiable {
        let id = UUID()
        let original: String
        let corrected: String
        let reason: String
        let confidence: Double // 0.0 - 1.0

        enum CodingKeys: String, CodingKey {
            case original
            case corrected
            case reason
            case confidence
        }
    }

    // MARK: - Public API

    /// Check ingredient text for spelling issues
    /// - Parameter text: Raw ingredient text (e.g., "2 cups fower")
    /// - Returns: SpellingResult with suggestions if issues found
    func check(_ text: String) async throws -> SpellingResult {
        // Check if AI parsing is enabled
        guard AIConfiguration.shared.enableAIParsing,
              AIConfiguration.shared.isConfigured(provider: .anthropic) else {
            // Return empty result if AI is disabled
            return SpellingResult(hasIssues: false, suggestions: [])
        }

        // Skip very short or empty text
        guard text.count > 2 else {
            return SpellingResult(hasIssues: false, suggestions: [])
        }

        do {
            let result = try await checkWithAI(text)

            // Track success
            AnalyticsService.shared.track(event: .aiSpellCheckSuccess, properties: [
                "ingredient_text": text,
                "has_issues": result.hasIssues,
                "suggestion_count": result.suggestions.count
            ])

            return result

        } catch {
            // Track failure
            AnalyticsService.shared.track(event: .aiSpellCheckFailed, properties: [
                "ingredient_text": text,
                "error": error.localizedDescription
            ])

            Log.warning("AI spell check failed", category: .ocr, metadata: ["ingredientText": text, "error": error.localizedDescription])

            // Return empty result on error
            return SpellingResult(hasIssues: false, suggestions: [])
        }
    }

    /// Check multiple ingredients in batch (more efficient)
    /// - Parameter ingredients: Array of ingredient text strings
    /// - Returns: Array of SpellingResult, one per ingredient
    func checkBatch(_ ingredients: [String]) async throws -> [SpellingResult] {
        // Check if AI parsing is enabled
        guard AIConfiguration.shared.enableAIParsing,
              AIConfiguration.shared.isConfigured(provider: .anthropic) else {
            return ingredients.map { _ in SpellingResult(hasIssues: false, suggestions: []) }
        }

        // Filter out empty/short ingredients
        let filteredIngredients = ingredients.filter { $0.count > 2 }

        guard !filteredIngredients.isEmpty else {
            return ingredients.map { _ in SpellingResult(hasIssues: false, suggestions: []) }
        }

        // For small batches, check individually
        if filteredIngredients.count <= 3 {
            var results: [SpellingResult] = []
            for ingredient in filteredIngredients {
                let result = try await check(ingredient)
                results.append(result)
            }
            return results
        }

        // For larger batches, use batch API call
        do {
            let batchResults = try await checkBatchWithAI(filteredIngredients)

            AnalyticsService.shared.track(event: .aiSpellCheckSuccess, properties: [
                "batch_size": filteredIngredients.count,
                "mode": "batch"
            ])

            return batchResults

        } catch {
            Log.warning("Batch AI spell check failed, falling back to individual checking", category: .ocr, metadata: ["error": error.localizedDescription, "batchSize": filteredIngredients.count])

            // Fall back to individual checking
            var results: [SpellingResult] = []
            for ingredient in filteredIngredients {
                let result = try await check(ingredient)
                results.append(result)
            }
            return results
        }
    }

    // MARK: - AI Spell Checking

    private func checkWithAI(_ text: String) async throws -> SpellingResult {
        let service = AnthropicAIService.shared
        let model = AIConfiguration.shared.model(for: .parsing)

        let prompt = buildPrompt(for: text)

        let result = try await service.completeStructured(
            prompt: prompt,
            schema: SpellingResult.self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.2, // Low temperature for consistent checking
                maxTokens: 200,
                systemMessage: """
                You are an expert culinary ingredient spell checker. Identify spelling errors,
                incorrect abbreviations, and common mistakes in ingredient text.
                Only suggest corrections when you are confident (confidence > 0.7).
                """,
                stopSequences: nil
            )
        )

        return result
    }

    private func buildPrompt(for text: String) -> String {
        return """
        Check this ingredient text for spelling errors and incorrect abbreviations:
        "\(text)"

        Common issues to check:
        - Misspellings: "fower" → "flour", "suger" → "sugar", "tomatoe" → "tomato"
        - Incorrect abbreviations: "tbs" → "tbsp", "teasp" → "tsp", "c" → "cup"
        - Common typos: "reciepe" → "recipe", "cinamon" → "cinnamon"
        - Inconsistent capitalization: "All-Purpose Flour" → "all-purpose flour"

        Guidelines:
        - Only flag actual errors (confidence > 0.7)
        - Don't flag brand names or proper nouns
        - Don't flag measurement variations like "cups" vs "cup"
        - Keep original formatting for quantities and units
        - Provide clear, helpful reasons for each suggestion

        Return JSON:
        {
          "has_issues": <boolean>,
          "suggestions": [
            {
              "original": "<exact text to replace>",
              "corrected": "<suggested replacement>",
              "reason": "<brief explanation>",
              "confidence": <0.0 to 1.0>
            }
          ]
        }

        Examples:

        Input: "2 cups fower"
        Output: {
          "has_issues": true,
          "suggestions": [{
            "original": "fower",
            "corrected": "flour",
            "reason": "Common misspelling of 'flour'",
            "confidence": 0.95
          }]
        }

        Input: "1 tbs olive oil"
        Output: {
          "has_issues": true,
          "suggestions": [{
            "original": "tbs",
            "corrected": "tbsp",
            "reason": "Standard abbreviation is 'tbsp'",
            "confidence": 0.85
          }]
        }

        Input: "2 cups all-purpose flour"
        Output: {
          "has_issues": false,
          "suggestions": []
        }

        Now check: "\(text)"
        """
    }

    private func checkBatchWithAI(_ ingredients: [String]) async throws -> [SpellingResult] {
        let service = AnthropicAIService.shared
        let model = AIConfiguration.shared.model(for: .parsing)

        let prompt = buildBatchPrompt(for: ingredients)

        let result = try await service.completeStructured(
            prompt: prompt,
            schema: [SpellingResult].self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.2,
                maxTokens: 500,
                systemMessage: """
                You are an expert culinary ingredient spell checker. Check multiple ingredients
                and return results in the same order. Only flag confident issues.
                """,
                stopSequences: nil
            )
        )

        return result
    }

    private func buildBatchPrompt(for ingredients: [String]) -> String {
        let numberedIngredients = ingredients.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")

        return """
        Check these \(ingredients.count) ingredient texts for spelling errors:

        \(numberedIngredients)

        For each ingredient, check for:
        - Misspellings (e.g., "fower" → "flour")
        - Incorrect abbreviations (e.g., "tbs" → "tbsp")
        - Common typos

        Return a JSON array with \(ingredients.count) results in the same order:
        [
          {
            "has_issues": <boolean>,
            "suggestions": [
              {
                "original": "<text to replace>",
                "corrected": "<replacement>",
                "reason": "<explanation>",
                "confidence": <0.0 to 1.0>
              }
            ]
          },
          ...
        ]
        """
    }
}
