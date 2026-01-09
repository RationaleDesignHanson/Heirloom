//
//  ClaudeRecipeStructurer.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  AI-powered recipe structuring using Anthropic Claude API
//  Integrates with existing AnthropicAIService from main Heirloom app

import Foundation

// MARK: - Claude Recipe Structurer
// Uses real AIServiceProtocol and AIConfiguration from Core/Services/AI/

@MainActor
class ClaudeRecipeStructurer: RecipeStructurerProtocol {
    private let aiService: AIServiceProtocol

    /// Initialize with AI service (will use AnthropicAIService from main app)
    init(aiService: AIServiceProtocol) {
        self.aiService = aiService
    }

    /// Convenience initializer for production use
    /// Will use shared AnthropicAIService when available
    convenience init() {
        // When Core services are linked, use:
        // self.init(aiService: AnthropicAIService.shared)

        // For now, this will fail until linked
        fatalError("Use init(aiService:) until Core services linked")
    }

    func structure(
        transcript: TranscriptionResult,
        visualElements: [String]
    ) async throws -> StructuredRecipe {

        let prompt = buildPrompt(transcript: transcript, visualElements: visualElements)

        let options = AICompletionOptions(
            model: "claude-sonnet-4-20250514",  // Claude Sonnet 4 with vision
            temperature: 0.3,  // Lower temperature for structured extraction
            maxTokens: 2048,
            systemMessage: systemPrompt,
            stopSequences: nil
        )

        do {
            let response = try await aiService.complete(
                prompt: prompt,
                options: options
            )

            // Log token usage for cost tracking
            logTokenUsage(
                inputTokens: response.usage.inputTokens,
                outputTokens: response.usage.outputTokens
            )

            // Parse JSON response
            return try parseRecipeJSON(response.content)

        } catch {
            throw VideoImportError.recipeStructuringFailed(underlying: error)
        }
    }

    // MARK: - Prompt Building

    private var systemPrompt: String {
        """
        You are a recipe extraction specialist. Your task is to extract structured recipe data from cooking video transcripts.

        IMPORTANT GUIDELINES:
        - Extract ALL ingredients mentioned, even if quantities are imprecise
        - Convert colloquial measurements to standard units where possible
        - Mark confidence level for each extracted item based on how clearly it was stated
        - **CRITICAL**: Leave quantity as null (empty) if not clearly stated - DO NOT default to "to taste"
        - Only use "to taste" for true seasonings (salt, pepper) where personal preference matters
        - For other ingredients with vague quantities, leave quantity as null so AI augmentation can infer from similar recipes
        - Preserve the original spoken text for reference
        - Steps should be actionable and in logical order
        - Include timing and temperature information when mentioned
        - If visual elements (OCR text) confirm or contradict transcript, note this in confidence

        MEASUREMENT CONVERSIONS:
        - "a pinch" → "1/16 tsp" (medium confidence)
        - "a handful" → "1/2 cup" for dry ingredients (approximate confidence)
        - "a dollop" → "1-2 tbsp" (approximate confidence)
        - "a knob" (butter) → "1-2 tbsp" (approximate confidence)
        - "a splash" → "1-2 tbsp" (approximate confidence)

        HANDLING VAGUE QUANTITIES:
        - "some flour" → quantity: null (unknown confidence) - augmentation will infer
        - "a bit of honey" → quantity: null (unknown confidence) - augmentation will infer
        - "salt" or "pepper" → quantity: "to taste" (inferred confidence) - these are seasonings
        - "cooking spray" → quantity: "as needed" (inferred confidence)

        CONFIDENCE LEVELS:
        - explicit: Clearly stated with specific measurement (e.g., "2 cups of flour")
        - visual: Confirmed by on-screen text or visual demonstration
        - inferred: Derived from context or standard recipes (e.g., "eggs" → likely "2 eggs" for cookies)
        - approximate: Converted from imprecise description (e.g., "a handful" → "1/2 cup")
        - unknown: Mentioned but no quantity given (quantity should be null, not "to taste")

        RESPOND ONLY WITH VALID JSON matching the provided schema. No additional text before or after.
        """
    }

    private func buildPrompt(transcript: TranscriptionResult, visualElements: [String]) -> String {
        var prompt = """
        Extract a structured recipe from the following cooking video transcript.

        <transcript>
        \(transcript.text)
        </transcript>
        """

        if !visualElements.isEmpty {
            prompt += """


            <visual_text_detected>
            The following text was detected on-screen in the video:
            \(visualElements.joined(separator: "\n"))
            </visual_text_detected>
            """
        }

        prompt += """


        <output_schema>
        {
            "title": "string - recipe name (required)",
            "description": "string - brief description (optional)",
            "servings": "string or null - e.g., '4 servings', '2 dozen cookies'",
            "prepTime": "string or null - e.g., '15 minutes'",
            "cookTime": "string or null - e.g., '30 minutes'",
            "ingredients": [
                {
                    "originalText": "string - exact words from transcript",
                    "item": "string - ingredient name (e.g., 'all-purpose flour')",
                    "quantity": "string or null - MUST be null if not clearly stated (augmentation will infer). Use 'to taste' ONLY for salt/pepper",
                    "unit": "string or null - unit (e.g., 'cups', 'teaspoons', null for count)",
                    "preparation": "string or null - e.g., 'diced', 'room temperature', 'sifted'",
                    "confidence": "explicit|visual|inferred|approximate|unknown"
                }
            ],
            "steps": [
                {
                    "instruction": "string - clear, actionable step",
                    "duration": "string or null - time for this step (e.g., '10 minutes', 'until golden')",
                    "temperature": "string or null - temperature if mentioned (e.g., '350°F', 'medium heat')",
                    "confidence": "explicit|inferred"
                }
            ],
            "warnings": [
                "string - any warnings about low confidence, missing info, or ambiguities"
            ],
            "overallConfidence": number between 0.0-1.0
        }
        </output_schema>

        Extract the recipe as JSON following the schema above.
        """

        return prompt
    }

    // MARK: - Response Parsing

    private func parseRecipeJSON(_ responseText: String) throws -> StructuredRecipe {
        // Clean potential markdown code blocks
        let cleanedJSON = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedJSON.data(using: .utf8) else {
            throw RecipeParsingError.invalidJSON
        }

        let decoder = JSONDecoder()
        let rawRecipe = try decoder.decode(RawExtractedRecipe.self, from: data)

        // Validate extracted data
        try validate(rawRecipe)

        return rawRecipe.toStructuredRecipe()
    }

    private func validate(_ recipe: RawExtractedRecipe) throws {
        // Must have at least a title
        guard !recipe.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RecipeParsingError.missingTitle
        }

        // Should have at least one ingredient or step
        guard !recipe.ingredients.isEmpty || !recipe.steps.isEmpty else {
            throw RecipeParsingError.noRecipeContent
        }

        // Check for suspiciously low confidence
        if recipe.overallConfidence < 0.3 {
            throw RecipeParsingError.confidenceTooLow(recipe.overallConfidence)
        }
    }

    // MARK: - Cost Tracking

    private func logTokenUsage(inputTokens: Int, outputTokens: Int) {
        // Cost calculation for Claude 3.5 Sonnet (as of Jan 2026):
        // Input: $3.00 per million tokens
        // Output: $15.00 per million tokens

        let inputCost = Double(inputTokens) * 3.00 / 1_000_000
        let outputCost = Double(outputTokens) * 15.00 / 1_000_000
        let totalCost = inputCost + outputCost

        print("""
        Claude API Usage:
          Input tokens: \(inputTokens) ($\(String(format: "%.4f", inputCost)))
          Output tokens: \(outputTokens) ($\(String(format: "%.4f", outputCost)))
          Total cost: $\(String(format: "%.4f", totalCost))
        """)
    }
}

// MARK: - Raw Response Models

private struct RawExtractedRecipe: Codable {
    let title: String
    let description: String?
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let ingredients: [RawIngredient]
    let steps: [RawStep]
    let warnings: [String]
    let overallConfidence: Double

    func toStructuredRecipe() -> StructuredRecipe {
        StructuredRecipe(
            title: title,
            description: description,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime,
            ingredients: ingredients.map { $0.toExtractedIngredient() },
            steps: steps.map { $0.toExtractedStep() },
            overallConfidence: overallConfidence,
            warnings: warnings
        )
    }
}

private struct RawIngredient: Codable {
    let originalText: String
    let item: String
    let quantity: String?
    let unit: String?
    let preparation: String?
    let confidence: String

    func toExtractedIngredient() -> ExtractedIngredient {
        let confidenceLevel = ExtractionConfidence(rawValue: confidence) ?? .unknown

        return ExtractedIngredient(
            originalText: originalText,
            item: item,
            quantity: quantity,
            unit: unit,
            preparation: preparation,
            confidence: confidenceLevel
        )
    }
}

private struct RawStep: Codable {
    let instruction: String
    let duration: String?
    let temperature: String?
    let confidence: String

    func toExtractedStep() -> ExtractedStep {
        let confidenceLevel = ExtractionConfidence(rawValue: confidence) ?? .unknown

        return ExtractedStep(
            instruction: instruction,
            duration: duration,
            temperature: temperature,
            confidence: confidenceLevel
        )
    }
}

// MARK: - Errors

enum RecipeParsingError: LocalizedError {
    case invalidJSON
    case missingTitle
    case noRecipeContent
    case confidenceTooLow(Double)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Failed to parse recipe data from AI response"
        case .missingTitle:
            return "Could not determine recipe name"
        case .noRecipeContent:
            return "No ingredients or steps could be extracted"
        case .confidenceTooLow(let confidence):
            return "Extraction confidence too low (\(Int(confidence * 100))%). Please try a different video."
        }
    }
}

// MARK: - Cost Estimation

extension ClaudeRecipeStructurer {
    /// Estimate cost for processing a transcript
    static func estimateCost(transcriptLength: Int, includeVisualElements: Bool = true) -> Decimal {
        // Approximate token counts:
        // - System prompt: ~400 tokens
        // - User prompt template: ~200 tokens
        // - Transcript: ~1 token per 4 characters
        // - Visual elements: ~50 tokens
        // - Output: ~500 tokens average

        let systemTokens = 400
        let promptTokens = 200
        let transcriptTokens = transcriptLength / 4
        let visualTokens = includeVisualElements ? 50 : 0
        let outputTokens = 500

        let inputTokens = systemTokens + promptTokens + transcriptTokens + visualTokens

        // Claude 3.5 Sonnet pricing (Jan 2026)
        let inputCost = Decimal(inputTokens) * 3.00 / 1_000_000
        let outputCost = Decimal(outputTokens) * 15.00 / 1_000_000

        return inputCost + outputCost
    }
}
