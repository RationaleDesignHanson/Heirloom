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

        // CRITICAL: Handle empty extraction case (title-only)
        // If we have NO ingredients AND NO steps, use web search results directly
        let hasNoContent = extractedRecipe.ingredients.isEmpty && extractedRecipe.steps.isEmpty

        if hasNoContent {
            print("🔍 EMPTY EXTRACTION DETECTED - Recipe has title only: \"\(extractedRecipe.title)\"")
            print("🔍 Attempting web search fallback enrichment...")

            // Require web recipes for empty extraction
            guard !webRecipes.isEmpty else {
                print("❌ No web recipes found - cannot enrich empty extraction")
                print("💡 User should try ASMR mode for vision-based extraction")
                throw AugmentationError.noWebRecipesForEmptyExtraction(title: extractedRecipe.title)
            }

            print("✅ Found \(webRecipes.count) web recipes - using best match to fill content")
            return try await enrichFromWebRecipes(
                extractedRecipe: extractedRecipe,
                webRecipes: webRecipes
            )
        }

        // 1. Identify ingredients needing augmentation (normal flow)
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

        // CRITICAL: Proceed with augmentation even if no similar recipes found
        // Claude has extensive culinary knowledge and can infer standard quantities
        if similarRecipes.isEmpty && webRecipes.isEmpty {
            print("⚠️ No similar recipes found - using Claude's culinary knowledge for inference")
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
            maxTokens: 2500, // Increased from 800 - need room for 10+ ingredients with reasoning
            systemMessage: augmentationSystemPrompt,
            stopSequences: nil
        )

        let response = try await aiService.complete(
            prompt: prompt,
            options: options
        )

        print("🔮 Received AI response (\(response.usage.outputTokens) tokens)")
        print("🔮 Response content (first 1000 chars):")
        print(String(response.content.prefix(1000)))
        print("...")

        // 4. Parse augmentation result
        let augmentationResult = try parseAugmentationResponse(response.content)

        print("📊 Parsed \(augmentationResult.augmentedIngredients.count) ingredients from AI")
        let withQty = augmentationResult.augmentedIngredients.filter { $0.inferredQuantity != nil }.count
        print("   With quantities: \(withQty)")
        print("   Without quantities: \(augmentationResult.augmentedIngredients.count - withQty)")

        if withQty == 0 {
            print("⚠️ WARNING: AI returned 0 ingredients with quantities!")
            print("   First ingredient example:")
            if let first = augmentationResult.augmentedIngredients.first {
                print("      originalText: \(first.originalText)")
                print("      inferredQuantity: \(first.inferredQuantity ?? "nil")")
                print("      inferredUnit: \(first.inferredUnit ?? "nil")")
                print("      confidence: \(first.confidence)")
            }
        }

        let processingTime = Date().timeIntervalSince(startTime)

        // 5. Create augmented recipe
        return createAugmentedRecipe(
            original: extractedRecipe,
            needsAugmentation: needsAugmentation,
            augmentationResult: augmentationResult,
            similarRecipes: similarRecipes,
            webRecipes: webRecipes,
            processingTime: processingTime
        )
    }

    // MARK: - Prompt Building

    private var augmentationSystemPrompt: String {
        """
        You are a culinary expert specializing in recipe standardization. Your task is to infer missing or imprecise ingredient quantities from video transcripts.

        CRITICAL: You MUST provide a quantity for EVERY ingredient. Use your culinary knowledge of standard recipes.

        Guidelines:
        - Use typical quantities for the dish type (e.g., "Butter Chicken" typically uses 1.5-2 lbs chicken, 1/4 cup butter, etc.)
        - Consider recipe servings when scaling quantities
        - For common ingredients without quantities, infer based on:
          * Standard ratios for this type of dish
          * Typical home cooking portions
          * Balance of flavors (e.g., soy sauce to honey ratio in Asian dishes)
        - If similar recipes are provided, use their consensus
        - If no similar recipes, use your knowledge of standard recipes

        Confidence Levels (BE GENEROUS - prefer medium/high over low):
        - HIGH: You're very confident based on standard recipes for this dish type
        - MEDIUM: Reasonable inference based on typical cooking ratios
        - LOW: Educated guess but could vary significantly
        - UNKNOWN: Only use if ingredient is truly ambiguous (e.g., "to taste")

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

        let hasReferences = !similarRecipeContext.contains("No similar recipes found")

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

        For each ingredient needing augmentation, infer the most likely quantity. \(hasReferences ? "Use similar recipes as primary guidance." : "Use your culinary knowledge of standard \(extractedRecipe.title) recipes.")

        CRITICAL REQUIREMENTS:
        - You MUST provide a quantity for EVERY ingredient in the augmentation list
        - Never return null for inferredQuantity unless ingredient is truly "to taste"
        - Use standard recipes for "\(extractedRecipe.title)" as your knowledge base
        - Consider serving size: \(extractedRecipe.servings ?? "not specified")
        - Use typical home cooking portions

        Return JSON:
        {
          "augmentedIngredients": [
            {
              "originalText": "string - exact match from needs augmentation list",
              "inferredQuantity": "string - amount (e.g., '2', '1.5', '1/4') - REQUIRED",
              "inferredUnit": "string - unit (e.g., 'pounds', 'cups', 'tablespoons') - REQUIRED",
              "confidence": "high|medium|low",
              "reasoning": "string - why this quantity was inferred",
              "sourceRecipes": ["string - similar recipes used, or 'Standard recipe knowledge'"]
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

        // DEBUG: Print the actual response
        print("🔮 DEBUG: Claude response (first 500 chars):")
        print(String(cleanedJSON.prefix(500)))

        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AugmentationError.invalidJSON
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(AugmentationResult.self, from: data)
        } catch {
            print("❌ JSON parsing failed: \(error)")
            print("🔮 Full response:")
            print(cleanedJSON)
            throw error
        }
    }

    // MARK: - Result Creation

    private func createAugmentedRecipe(
        original: StructuredRecipe,
        needsAugmentation: [ExtractedIngredient],
        augmentationResult: AugmentationResult,
        similarRecipes: [SimilarRecipeMatch],
        webRecipes: [WebRecipeResult],
        processingTime: TimeInterval
    ) -> AugmentedRecipe {
        // Convert raw augmentation results to AugmentedIngredient objects
        var augmentedIngredients = augmentationResult.augmentedIngredients.map { raw in
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

        // CRITICAL: Find ingredients that needed augmentation but weren't returned by AI
        // Create fallback AugmentedIngredient objects for them with explanatory reasoning
        let augmentedOriginalTexts = Set(augmentedIngredients.map { $0.originalIngredient.originalText })
        let missingIngredients = needsAugmentation.filter { !augmentedOriginalTexts.contains($0.originalText) }

        if !missingIngredients.isEmpty {
            print("⚠️ Creating fallback augmentation for \(missingIngredients.count) ingredients not returned by AI:")
            for ingredient in missingIngredients {
                print("   - \(ingredient.originalText)")
            }
        }

        for ingredient in missingIngredients {
            let hasReferences = !similarRecipes.isEmpty || !webRecipes.isEmpty
            let reasoning: String

            if hasReferences {
                reasoning = "Could not confidently infer quantity from \(similarRecipes.count + webRecipes.count) similar recipes. The ingredient appears in similar recipes but with significant variation in quantities. Please verify the amount based on the video or use standard recipe proportions for \(original.title)."
            } else {
                reasoning = "No similar recipes found in your collection to infer quantity from. Please verify the amount based on the video or use standard recipe proportions for \(original.title)."
            }

            let fallbackAugmentation = AugmentedIngredient(
                originalIngredient: ingredient,
                inferredQuantity: nil,
                inferredUnit: nil,
                inferredConfidence: .unknown,
                reasoning: reasoning,
                sourceRecipes: []
            )

            augmentedIngredients.append(fallbackAugmentation)
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

    // MARK: - Web Recipe Enrichment

    /// Enrich empty extraction using web recipe results
    /// Used when transcript extraction yields title-only (no ingredients/steps)
    private func enrichFromWebRecipes(
        extractedRecipe: StructuredRecipe,
        webRecipes: [WebRecipeResult]
    ) async throws -> AugmentedRecipe {
        let startTime = Date()

        // Use the best match (highest similarity score)
        let bestMatch = webRecipes.max(by: { $0.similarityScore < $1.similarityScore })!

        print("🌐 Using web recipe as fallback: \(bestMatch.title)")
        print("   Similarity score: \(String(format: "%.2f", bestMatch.similarityScore))")
        print("   Source: \(bestMatch.sourceURL)")
        print("   Ingredients: \(bestMatch.ingredients.count)")
        print("   Instructions: \(bestMatch.instructions?.count ?? 0) steps")

        // Convert web recipe ingredients to augmented format
        let augmentedIngredients = bestMatch.ingredients.map { webIngredient -> AugmentedIngredient in
            // Create ExtractedIngredient from web data
            let extractedIngredient = ExtractedIngredient(
                originalText: webIngredient.text,
                item: webIngredient.parsedName ?? webIngredient.text,
                quantity: webIngredient.parsedQuantity,
                unit: webIngredient.parsedUnit,
                preparation: nil, // Web recipes typically don't separate preparation
                confidence: .inferred
            )

            return AugmentedIngredient(
                originalIngredient: extractedIngredient,
                inferredQuantity: webIngredient.parsedQuantity,
                inferredUnit: webIngredient.parsedUnit,
                inferredConfidence: .medium, // Web recipes have medium confidence
                reasoning: "Enriched from web search: \(bestMatch.title)",
                sourceRecipes: [bestMatch.title]
            )
        }

        let processingTime = Date().timeIntervalSince(startTime)

        print("✅ Successfully enriched recipe from web search")
        print("   Added \(augmentedIngredients.count) ingredients")
        print("   Processing time: \(String(format: "%.2f", processingTime))s")

        return AugmentedRecipe(
            original: extractedRecipe,
            augmentedIngredients: augmentedIngredients,
            metadata: AugmentationMetadata(
                localRecipesUsed: 0,
                webRecipesUsed: 1,
                totalInferences: augmentedIngredients.count,
                averageConfidence: .medium,
                processingTime: processingTime
            )
        )
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
    case noWebRecipesForEmptyExtraction(title: String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Failed to parse AI augmentation response"
        case .parsingFailed:
            return "Failed to process augmentation data"
        case .noSimilarRecipes:
            return "No similar recipes found to infer from"
        case .noWebRecipesForEmptyExtraction(let title):
            return "Could not find web recipes for \"\(title)\". Audio transcription was insufficient and web search found no matches. Try ASMR mode for vision-based extraction."
        }
    }
}
