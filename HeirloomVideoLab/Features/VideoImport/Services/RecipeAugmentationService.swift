//
//  RecipeAugmentationService.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/9/26.
//
//  AI-powered service for inferring missing ingredient quantities
//  Uses Claude AI to analyze similar recipes and infer precise measurements

import Foundation

@MainActor
class RecipeAugmentationService {
    private let aiService: AIServiceProtocol

    init(aiService: AIServiceProtocol) {
        self.aiService = aiService
    }

    // MARK: - Public API

    /// Augment extracted recipe with inferred quantities from similar recipes
    /// - Parameters:
    ///   - extractedRecipe: Recipe from video transcription
    ///   - similarRecipes: Similar recipes from local database
    ///   - webRecipes: Similar recipes from web search
    /// - Returns: Augmented recipe with inferred quantities
    func augment(
        _ extractedRecipe: StructuredRecipe,
        similarRecipes: [SimilarRecipeMatch],
        webRecipes: [WebRecipeResult]
    ) async throws -> AugmentedRecipe {
        print("🔮 Augmenting recipe with AI inference...")

        // 1. Identify ingredients needing augmentation
        let needsAugmentation = extractedRecipe.ingredients.filter { ingredient in
            ingredient.confidence == .approximate ||
            ingredient.confidence == .unknown ||
            ingredient.quantity == nil
        }

        print("🔮 Found \(needsAugmentation.count) ingredients needing augmentation")

        if needsAugmentation.isEmpty {
            // No augmentation needed
            print("✅ No augmentation needed - all ingredients have good confidence")
            return AugmentedRecipe(
                original: extractedRecipe,
                augmentedIngredients: [],
                metadata: AugmentationMetadata(
                    localRecipesUsed: 0,
                    webRecipesUsed: 0,
                    totalInferences: 0,
                    averageConfidence: .high,
                    processingTime: 0
                )
            )
        }

        // 2. Build context from similar recipes
        let similarRecipeContext = buildSimilarRecipeContext(
            similarRecipes: similarRecipes,
            webRecipes: webRecipes
        )

        print("🔮 Built context from \(similarRecipes.count) local + \(webRecipes.count) web recipes")

        // 3. Use Claude AI to infer quantities
        let startTime = Date()

        let prompt = buildAugmentationPrompt(
            extractedRecipe: extractedRecipe,
            needsAugmentation: needsAugmentation,
            similarRecipeContext: similarRecipeContext
        )

        let options = AICompletionOptions(
            model: "claude-sonnet-4-20250514",
            temperature: 0.2, // Low for consistent inference
            maxTokens: 800,
            systemMessage: augmentationSystemPrompt,
            stopSequences: nil
        )

        let response = try await aiService.complete(
            prompt: prompt,
            options: options
        )

        print("🔮 Received AI response (\(response.usage.outputTokens) tokens)")

        // 4. Parse augmentation result
        let augmentationResult = try parseAugmentationResponse(response.content)

        let processingTime = Date().timeIntervalSince(startTime)

        // 5. Create augmented recipe
        return createAugmentedRecipe(
            original: extractedRecipe,
            augmentationResult: augmentationResult,
            similarRecipes: similarRecipes,
            webRecipes: webRecipes,
            processingTime: processingTime
        )
    }

    // MARK: - Prompt Building

    private var augmentationSystemPrompt: String {
        """
        You are a culinary expert specializing in recipe standardization. Your task is to infer missing or imprecise ingredient quantities from video transcripts by analyzing similar recipes.

        Guidelines:
        - Only provide quantities when there's strong consensus across similar recipes
        - Always include confidence level: high (3+ matching recipes), medium (2 matching), low (1 match or inference)
        - Cite which similar recipes support each inference
        - Consider recipe category, servings, and context
        - If no good inference exists, mark as "unknown" and explain why
        - For ranges in transcript ("some", "a bit"), use the median from similar recipes
        - Account for serving size differences (scale proportionally)

        Confidence Levels:
        - HIGH: 3+ similar recipes agree on quantity (±20% variance)
        - MEDIUM: 2 similar recipes agree, or strong contextual inference
        - LOW: Only 1 similar recipe, or high variance (>30%)
        - UNKNOWN: No similar recipes or conflicting data

        Respond ONLY with valid JSON matching the provided schema. No additional text.
        """
    }

    private func buildAugmentationPrompt(
        extractedRecipe: StructuredRecipe,
        needsAugmentation: [ExtractedIngredient],
        similarRecipeContext: String
    ) -> String {
        let ingredientList = needsAugmentation.map { ingredient in
            "- \"\(ingredient.originalText)\" (confidence: \(ingredient.confidence.rawValue))"
        }.joined(separator: "\n")

        return """
        Augment this recipe extracted from a video transcript:

        <extracted_recipe>
        Title: \(extractedRecipe.title)
        Servings: \(extractedRecipe.servings ?? "not specified")

        Ingredients needing augmentation:
        \(ingredientList)

        All ingredients:
        \(extractedRecipe.ingredients.map { "- \($0.item): \($0.quantity ?? "unknown") \($0.unit ?? "")" }.joined(separator: "\n"))
        </extracted_recipe>

        <similar_recipes>
        \(similarRecipeContext)
        </similar_recipes>

        For each ingredient needing augmentation, infer the most likely quantity based on similar recipes. Consider:
        - Consensus across similar recipes
        - Recipe serving size (extracted recipe: \(extractedRecipe.servings ?? "not specified"))
        - Typical ratios for this recipe type

        Return JSON:
        {
          "augmentedIngredients": [
            {
              "originalText": "string - exact match from needs augmentation list",
              "inferredQuantity": "string - amount (e.g., '2', '1/2', 'to taste') or null if unknown",
              "inferredUnit": "string - unit (e.g., 'cups', 'teaspoons') or null",
              "confidence": "high|medium|low|unknown",
              "reasoning": "string - why this quantity was inferred",
              "sourceRecipes": ["string - titles of supporting recipes"]
            }
          ]
        }
        """
    }

    private func buildSimilarRecipeContext(
        similarRecipes: [SimilarRecipeMatch],
        webRecipes: [WebRecipeResult]
    ) -> String {
        var context: [String] = []

        // Add local recipes
        for (index, match) in similarRecipes.prefix(5).enumerated() {
            var recipeText = "Recipe \(index + 1): \"\(match.recipe.title)\" (similarity: \(match.similarityPercentage)%)\n"

            if let ingredients = match.recipe.ingredients {
                recipeText += "Ingredients:\n"
                for ingredient in Array(ingredients).prefix(10) {
                    let name = ingredient.name
                    if !name.isEmpty {
                        if let quantity = ingredient.quantity,
                           let unit = ingredient.unit {
                            recipeText += "- \(quantity) \(unit) \(name)\n"
                        } else {
                            recipeText += "- \(name)\n"
                        }
                    }
                }
            }

            if let servings = match.recipe.servings {
                recipeText += "Servings: \(servings)\n"
            }

            context.append(recipeText)
        }

        // Add web recipes
        for (index, webRecipe) in webRecipes.prefix(3).enumerated() {
            let recipeNum = similarRecipes.count + index + 1
            var recipeText = "Recipe \(recipeNum): \"\(webRecipe.title)\" (from \(webRecipe.displayDomain), similarity: \(webRecipe.similarityPercentage)%)\n"

            recipeText += "Ingredients:\n"
            for ingredient in webRecipe.ingredients.prefix(10) {
                recipeText += "- \(ingredient.text)\n"
            }

            if let servings = webRecipe.servings {
                recipeText += "Servings: \(servings)\n"
            }

            context.append(recipeText)
        }

        return context.isEmpty ? "No similar recipes found." : context.joined(separator: "\n\n")
    }

    // MARK: - Response Parsing

    private func parseAugmentationResponse(_ responseText: String) throws -> AugmentationResult {
        // Clean potential markdown code blocks
        let cleanedJSON = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AugmentationError.invalidJSON
        }

        let decoder = JSONDecoder()
        return try decoder.decode(AugmentationResult.self, from: data)
    }

    // MARK: - Result Creation

    private func createAugmentedRecipe(
        original: StructuredRecipe,
        augmentationResult: AugmentationResult,
        similarRecipes: [SimilarRecipeMatch],
        webRecipes: [WebRecipeResult],
        processingTime: TimeInterval
    ) -> AugmentedRecipe {
        // Convert raw augmentation results to AugmentedIngredient objects
        let augmentedIngredients = augmentationResult.augmentedIngredients.map { raw in
            // Find corresponding original ingredient
            let originalIngredient = original.ingredients.first {
                $0.originalText == raw.originalText
            } ?? ExtractedIngredient(
                originalText: raw.originalText,
                item: raw.originalText,
                quantity: nil,
                unit: nil,
                preparation: nil,
                confidence: .unknown
            )

            let confidence = InferenceConfidence(rawValue: raw.confidence) ?? .unknown

            return AugmentedIngredient(
                originalIngredient: originalIngredient,
                inferredQuantity: raw.inferredQuantity,
                inferredUnit: raw.inferredUnit,
                inferredConfidence: confidence,
                reasoning: raw.reasoning,
                sourceRecipes: raw.sourceRecipes
            )
        }

        // Calculate average confidence
        let averageConfidence = calculateAverageConfidence(augmentedIngredients)

        let metadata = AugmentationMetadata(
            localRecipesUsed: similarRecipes.count,
            webRecipesUsed: webRecipes.count,
            totalInferences: augmentedIngredients.count,
            averageConfidence: averageConfidence,
            processingTime: processingTime
        )

        print("✅ Augmentation complete: \(augmentedIngredients.count) ingredients enhanced")
        print("   Average confidence: \(averageConfidence.shortDisplayText)")

        return AugmentedRecipe(
            original: original,
            augmentedIngredients: augmentedIngredients,
            metadata: metadata
        )
    }

    private func calculateAverageConfidence(_ ingredients: [AugmentedIngredient]) -> InferenceConfidence {
        guard !ingredients.isEmpty else { return .unknown }

        let confidenceValues: [Double] = ingredients.map { ingredient in
            switch ingredient.inferredConfidence {
            case .high: return 1.0
            case .medium: return 0.66
            case .low: return 0.33
            case .unknown: return 0.0
            }
        }

        let average = confidenceValues.reduce(0, +) / Double(confidenceValues.count)

        if average >= 0.8 {
            return .high
        } else if average >= 0.5 {
            return .medium
        } else if average >= 0.2 {
            return .low
        } else {
            return .unknown
        }
    }
}

// MARK: - Response Models

private struct AugmentationResult: Codable {
    let augmentedIngredients: [RawAugmentedIngredient]
}

private struct RawAugmentedIngredient: Codable {
    let originalText: String
    let inferredQuantity: String?
    let inferredUnit: String?
    let confidence: String
    let reasoning: String
    let sourceRecipes: [String]
}

// MARK: - Errors

enum AugmentationError: LocalizedError {
    case invalidJSON
    case parsingFailed
    case noSimilarRecipes

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Failed to parse AI augmentation response"
        case .parsingFailed:
            return "Failed to process augmentation data"
        case .noSimilarRecipes:
            return "No similar recipes found to infer from"
        }
    }
}
