//
//  ASMRRecipeStructurer.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import Foundation
import UIKit
import SwiftData

/// Orchestrates the 5-pass ASMR vision analysis pipeline
@MainActor
class ASMRRecipeStructurer {

    // MARK: - Dependencies

    private let aiService: AnthropicAIService
    private let frameExtractor: ASMRFrameExtractionService
    private let augmentationService: RecipeAugmentationService
    private let similarRecipeService: LocalRecipeSimilarityService?
    private let ingredientDeduplicator: IngredientDeduplicator

    // MARK: - State

    /// Last augmented recipe (for access by processor to create Enhanced extraction)
    var lastAugmentedRecipe: AugmentedRecipe?

    // MARK: - Initialization

    init(
        aiService: AnthropicAIService? = nil,
        frameExtractor: ASMRFrameExtractionService? = nil,
        augmentationService: RecipeAugmentationService? = nil,
        similarRecipeService: LocalRecipeSimilarityService? = nil,
        modelContext: ModelContext? = nil
    ) {
        if let aiService = aiService {
            self.aiService = aiService
        } else {
            self.aiService = ServiceContainer.shared.resolve(AnthropicAIService.self)
        }
        self.frameExtractor = frameExtractor ?? ASMRFrameExtractionService()

        // RecipeAugmentationService needs an AI service (cast to protocol)
        if let augmentationService = augmentationService {
            self.augmentationService = augmentationService
        } else {
            let aiServiceProtocol: AIServiceProtocol = self.aiService
            self.augmentationService = RecipeAugmentationService(aiService: aiServiceProtocol)
        }

        // LocalRecipeSimilarityService needs ModelContext
        // If not provided, we'll skip similar recipe search (fallback to AI knowledge only)
        if let similarRecipeService = similarRecipeService {
            self.similarRecipeService = similarRecipeService
        } else if let modelContext = modelContext {
            self.similarRecipeService = LocalRecipeSimilarityService(modelContext: modelContext)
        } else {
            // No ModelContext available - similar recipe search will be skipped
            self.similarRecipeService = nil
            print("⚠️ ASMRRecipeStructurer: No ModelContext provided, similar recipe search disabled")
        }

        // Initialize ingredient deduplicator
        self.ingredientDeduplicator = IngredientDeduplicator(aiService: self.aiService)
    }

    // MARK: - Public API

    /// Run complete 5-pass structure with progress callbacks
    func structure(
        frames: FrameExtractionResult,
        userCaption: String,
        progressHandler: @Sendable (ASMRProcessingPass, [String]) -> Void
    ) async throws -> ASMRRecipeExtraction {

        var totalTokens = 0
        var totalCost = 0.0
        let startTime = Date()

        // Pass 1: Dish Identification (analyze final frames first)
        let dishResult = try await identifyDish(
            frames: frames.finalFrames,
            userCaption: userCaption,
            progressHandler: progressHandler
        )
        totalTokens += dishResult.tokensUsed
        totalCost += dishResult.cost

        // Pass 2: Ingredient Detection (setup + cooking frames)
        let ingredientResult = try await detectIngredients(
            frames: frames.allFrames,
            dishContext: dishResult.result.dishName,
            progressHandler: progressHandler
        )
        totalTokens += ingredientResult.tokensUsed
        totalCost += ingredientResult.cost

        // Pass 3: Culinary Inference (infer hidden ingredients)
        let inferenceResult = try await inferHiddenIngredients(
            visibleIngredients: ingredientResult.result.detectedIngredients,
            dishType: dishResult.result.dishType,
            userCaption: userCaption,
            progressHandler: progressHandler
        )
        totalTokens += inferenceResult.tokensUsed
        totalCost += inferenceResult.cost

        // Pass 4: Action Recognition (cooking techniques)
        let actionResult = try await recognizeActions(
            frames: frames.cookingFrames,
            ingredients: ingredientResult.result.detectedIngredients,
            progressHandler: progressHandler
        )
        totalTokens += actionResult.tokensUsed
        totalCost += actionResult.cost

        // Pass 5: Synthesis & Validation
        let synthesisResult = try await synthesizeRecipe(
            dishResult: dishResult.result,
            ingredientResult: ingredientResult.result,
            inferenceResult: inferenceResult.result,
            actionResult: actionResult.result,
            progressHandler: progressHandler
        )
        totalTokens += synthesisResult.tokensUsed
        totalCost += synthesisResult.cost

        // Pass 6 (implicit): Augment recipe to fill missing quantities
        // Use the same augmentation system as regular video imports
        let augmentationResult = try await augmentRecipe(
            recipe: synthesisResult.result.finalRecipe,
            dishName: dishResult.result.dishName
        )
        totalTokens += augmentationResult.tokensUsed
        totalCost += augmentationResult.cost

        let processingTime = Date().timeIntervalSince(startTime)

        // Build ASMR5PassResults for metadata
        let passResults = ASMR5PassResults(
            dishIdentification: dishResult.result,
            ingredientDetection: ingredientResult.result,
            culinaryInference: inferenceResult.result,
            actionRecognition: actionResult.result,
            synthesis: synthesisResult.result,
            overallConfidence: calculateOverallConfidence(
                dish: dishResult.confidence,
                ingredients: ingredientResult.confidence,
                inference: inferenceResult.confidence,
                actions: actionResult.confidence,
                synthesis: synthesisResult.confidence
            ),
            totalCost: totalCost,
            totalTokens: totalTokens
        )

        // Create metadata for ASMR processing
        let metadata = VideoImportMetadata.forASMR(
            userCaption: userCaption,
            videoDuration: 0, // Set by processor
            passResults: passResults,
            processingTime: processingTime,
            processingCost: Decimal(totalCost)
        )

        // Create placeholder transcript (ASMR has no audio transcription)
        let transcript = TranscriptionResult(
            text: "Vision-only processing - no audio transcription",
            segments: [],
            confidence: passResults.overallConfidence,
            provider: .whisperKit, // Use existing provider as placeholder
            language: "n/a"
        )

        // Store augmented recipe for access by processor
        self.lastAugmentedRecipe = augmentationResult.augmentedRecipe

        // Return VideoRecipeExtraction (unified schema)
        return VideoRecipeExtraction(
            structuredRecipe: augmentationResult.recipe,
            transcript: transcript,
            visualElements: passResults.visualElementsSummary,
            metadata: metadata,
            processingTime: processingTime,
            estimatedCost: Decimal(totalCost)
        )
    }

    // MARK: - Pass 1: Dish Identification

    private func identifyDish(
        frames: [ExtractedFrame],
        userCaption: String,
        progressHandler: @Sendable (ASMRProcessingPass, [String]) -> Void
    ) async throws -> (result: DishIdentificationResult, tokensUsed: Int, cost: Double, confidence: Double) {

        let prompt = """
        You are analyzing the final frames of a silent cooking video to identify the completed dish.

        USER'S DESCRIPTION: "\(userCaption)"

        ⚠️ CRITICAL - TITLE PRESERVATION RULE ⚠️
        - The user explicitly described this dish as: "\(userCaption)"
        - You MUST use "\(userCaption)" as the EXACT dish name (word-for-word, including capitalization)
        - DO NOT change, rephrase, or "improve" the user's wording
        - DO NOT override based on minor visual differences in presentation
        - DO NOT let visual appearance override the user's explicit description
        - ONLY override if the video shows a COMPLETELY DIFFERENT food category

        EXAMPLES OF WHEN TO PRESERVE USER'S DESCRIPTION (DO NOT OVERRIDE):
        ❌ User: "crispy beef tacos" / Visual: looks folded like quesadillas → ✅ USE "crispy beef tacos"
        ❌ User: "fried rice" / Visual: looks like stir-fry → ✅ USE "fried rice"
        ❌ User: "chocolate brownies" / Visual: appears to be chocolate cake → ✅ USE "chocolate brownies"
        ❌ User: "chicken curry" / Visual: plated differently than expected → ✅ USE "chicken curry"
        ❌ User: "pasta carbonara" / Visual: different pasta shape → ✅ USE "pasta carbonara"

        ONLY OVERRIDE IN EXTREME CASES LIKE:
        ✅ User: "pasta carbonara" / Visual: clearly shows a hamburger → Override with explanation
        ✅ User: "chocolate cake" / Visual: clearly shows a salad → Override with explanation

        DEFAULT ACTION: When in doubt, ALWAYS trust and use the user's exact description.

        Analyze these final frames showing the finished dish and provide:

        1. **Dish Name**: Use "\(userCaption)" EXACTLY as written (explain in reasoning if you override)
        2. **Dish Type**: Cuisine and category based on visual analysis (e.g., "Mexican street food", "Italian pasta")
        3. **Serving Style**: How it's presented (e.g., "plated individually", "family-style in bowl", "layered in glass")
        4. **Visual Complexity**: The complexity of the dish (simple/moderate/complex)
        5. **Confidence**: Your confidence level (0.0-1.0)
        6. **Reasoning**: State "Used user's description: '\(userCaption)'" OR if you override, provide strong justification

        Focus on visual cues: plating style, garnishes, sauce distribution, portion size, cookware used.

        Respond in JSON:
        {
            "dishName": "string",
            "dishType": "string",
            "servingStyle": "string",
            "visualComplexity": "simple|moderate|complex",
            "confidence": 0.0-1.0,
            "reasoning": "string"
        }
        """

        // Combine final frames into grid
        let combinedImage = try await frameExtractor.createImageGrid(from: frames.map { $0.image })

        struct DishResponse: Codable {
            let dishName: String
            let dishType: String
            let servingStyle: String
            let visualComplexity: String
            let confidence: Double
            let reasoning: String
        }

        let response: DishResponse = try await aiService.completeWithVisionStructured(
            image: combinedImage,
            prompt: prompt,
            schema: DishResponse.self,
            options: AICompletionOptions(temperature: 0.3, maxTokens: 500),
            useCase: .display
        )

        let tokensUsed = 500
        let cost = calculateCost(inputTokens: 1500, outputTokens: tokensUsed)

        let findings = [
            "Identified: \(response.dishName)",
            "Type: \(response.dishType)",
            "Confidence: \(Int(response.confidence * 100))%"
        ]
        progressHandler(.identifying, findings)

        let result = DishIdentificationResult(
            dishName: response.dishName,
            dishType: response.dishType,
            servingStyle: response.servingStyle,
            visualComplexity: response.visualComplexity,
            confidence: response.confidence,
            reasoning: response.reasoning,
            analyzedFrames: frames.map { $0.frameIndex }
        )

        return (result, tokensUsed, cost, response.confidence)
    }

    // MARK: - Pass 2: Ingredient Detection

    private func detectIngredients(
        frames: [ExtractedFrame],
        dishContext: String,
        progressHandler: @Sendable (ASMRProcessingPass, [String]) -> Void
    ) async throws -> (result: IngredientDetectionResult, tokensUsed: Int, cost: Double, confidence: Double) {

        let prompt = """
        You are analyzing a silent cooking video to detect all visible ingredients.

        DISH CONTEXT: \(dishContext)

        For each ingredient you see:
        1. **Name**: What is it? (be specific: "spaghetti" not "pasta")
        2. **Visual State**: raw, chopped, sliced, minced, diced, whole, etc.
        3. **Estimated Quantity**: CRITICAL - Estimate from visual cues:
           - Count items: "2 eggs", "3 cloves garlic", "1 onion"
           - Compare to hands/bowls: "1 cup", "2 tablespoons", "handful"
           - Relative amounts: "small bunch", "large handful", "generous pinch"
           - Package sizes visible: "500g", "1 lb"
           - If uncertain, provide range: "1-2 cups", "2-3 tablespoons"
        4. **Confidence**: How certain you are (0.0-1.0)
        5. **First/Last Seen**: Timestamp range when visible

        QUANTITY EXTRACTION TIPS:
        - Look for measuring cups/spoons being used
        - Count discrete items (eggs, onions, garlic cloves)
        - Compare ingredient pile/bowl size to known references
        - Watch for repeated actions (3 scoops = 3 spoons)
        - Note package labels if visible

        Track transformations: "raw onions (whole) → caramelized onions (diced)" with timestamp.

        ⚠️ CRITICAL - DO NOT INCLUDE COOKING EQUIPMENT AS INGREDIENTS:
        - DO NOT include: spoons, spatulas, whisks, tongs, ladles, knives, cutting boards
        - DO NOT include: pans, pots, bowls (as ingredients - they're just containers)
        - DO NOT include: measuring cups/spoons themselves (just use them to estimate)
        - DO NOT include: plates, utensils, cookware, appliances
        - ONLY include actual FOOD ITEMS that go into the dish

        IMPORTANT: Only report ingredients you can CLEARLY SEE. Don't infer yet.

        Respond in JSON:
        {
            "detectedIngredients": [
                {
                    "name": "string",
                    "visualState": "string",
                    "estimatedQuantity": "string or null",
                    "confidence": 0.0-1.0,
                    "firstSeen": 0.0,
                    "lastSeen": 0.0,
                    "frameIndices": [0, 1, 2]
                }
            ],
            "transformations": [
                {
                    "ingredient": "string",
                    "from": "string",
                    "to": "string",
                    "timestamp": 0.0,
                    "technique": "string or null"
                }
            ],
            "overallConfidence": 0.0-1.0
        }
        """

        // Process in chunks (4 frames per call to stay under size limits)
        let chunkSize = 4
        var allIngredients: [IngredientDetectionResult.DetectedIngredient] = []
        var allTransformations: [IngredientDetectionResult.IngredientTransformation] = []
        var totalTokens = 0
        var totalCost = 0.0

        struct IngredientResponse: Codable {
            let detectedIngredients: [IngredientDetectionResult.DetectedIngredient]
            let transformations: [IngredientDetectionResult.IngredientTransformation]
            let overallConfidence: Double
        }

        for chunkIndex in stride(from: 0, to: frames.count, by: chunkSize) {
            let chunk = Array(frames[chunkIndex..<min(chunkIndex + chunkSize, frames.count)])
            let combinedImage = try await frameExtractor.createImageGrid(from: chunk.map { $0.image })

            let response: IngredientResponse = try await aiService.completeWithVisionStructured(
                image: combinedImage,
                prompt: prompt,
                schema: IngredientResponse.self,
                options: AICompletionOptions(temperature: 0.3, maxTokens: 1500),
                useCase: .display
            )

            allIngredients.append(contentsOf: response.detectedIngredients)
            allTransformations.append(contentsOf: response.transformations)

            totalTokens += 1500
            totalCost += calculateCost(inputTokens: 2000, outputTokens: 1500)

            // Update progress
            let findings = response.detectedIngredients.prefix(3).map { "Found: \($0.name)" }
            progressHandler(.detecting, findings)
        }

        // Deduplicate ingredients (same ingredient seen in multiple chunks)
        let dedupedIngredients = deduplicateIngredients(allIngredients)
        let avgConfidence = dedupedIngredients.isEmpty ? 0.5 :
            dedupedIngredients.map { $0.confidence }.reduce(0, +) / Double(dedupedIngredients.count)

        let result = IngredientDetectionResult(
            detectedIngredients: dedupedIngredients,
            transformations: allTransformations,
            confidence: avgConfidence
        )

        return (result, totalTokens, totalCost, avgConfidence)
    }

    // MARK: - Pass 3: Culinary Inference

    private func inferHiddenIngredients(
        visibleIngredients: [IngredientDetectionResult.DetectedIngredient],
        dishType: String,
        userCaption: String,
        progressHandler: @Sendable (ASMRProcessingPass, [String]) -> Void
    ) async throws -> (result: CulinaryInferenceResult, tokensUsed: Int, cost: Double, confidence: Double) {

        let visibleList = visibleIngredients.map { $0.name }.joined(separator: ", ")

        let prompt = """
        You are a culinary expert analyzing a recipe extraction.

        DISH TYPE: \(dishType)
        USER DESCRIPTION: "\(userCaption)"
        VISIBLE INGREDIENTS: \(visibleList)

        Based on your culinary knowledge, infer:

        1. **Hidden Ingredients**: Common ingredients not visible in video (e.g., salt, pepper, oil, garlic)
        2. **Seasonings**: Typical seasonings for this dish type
        3. **Estimated Quantities**: Based on dish type and serving size
        4. **Necessity Level**: essential/likely/possible
        5. **Reasoning**: Why you're inferring each ingredient

        Categories to consider:
        - Fats/oils (olive oil, butter, vegetable oil)
        - Seasonings (salt, pepper, herbs, spices, seasoning blends)
        - Liquids (water, stock, wine, broth)
        - Binding agents (eggs, flour, cornstarch)
        - Aromatics (garlic, onion, ginger, shallots)

        CRITICAL - BE SPECIFIC WITH SEASONING BLENDS:
        - If the dish type is Mexican/Tex-Mex (tacos, burritos, fajitas): infer "taco seasoning" or "fajita seasoning", NOT just "seasoning blend"
        - If the dish type is Italian (pasta, pizza): infer "Italian seasoning", NOT just "seasoning blend"
        - If the dish type is Cajun/Creole: infer "Cajun seasoning" or "Creole seasoning"
        - If the dish type is Asian stir-fry: infer "five-spice powder" or "stir-fry sauce mix"
        - If the dish type is Indian curry: infer "curry powder" or "garam masala"
        - Always match the seasoning blend name to the dish type/cuisine

        Be conservative - only infer ingredients that are TYPICAL for this dish type.

        Respond in JSON:
        {
            "inferredIngredients": [
                {
                    "name": "string",
                    "reasoning": "string",
                    "necessity": "essential|likely|possible",
                    "estimatedQuantity": "string or null",
                    "confidence": 0.0-1.0
                }
            ],
            "inferredSeasonings": [
                {
                    "name": "string",
                    "timing": "during cooking|at end|to taste",
                    "reasoning": "string",
                    "confidence": 0.0-1.0
                }
            ],
            "overallConfidence": 0.0-1.0
        }
        """

        struct InferenceResponse: Codable {
            let inferredIngredients: [CulinaryInferenceResult.InferredIngredient]
            let inferredSeasonings: [CulinaryInferenceResult.InferredSeasoning]
            let overallConfidence: Double
        }

        // Text-only API call (no images needed for inference)
        let response: InferenceResponse = try await aiService.completeStructured(
            prompt: prompt,
            schema: InferenceResponse.self,
            options: AICompletionOptions(temperature: 0.4, maxTokens: 1000)
        )

        let tokensUsed = 1000
        let cost = calculateCost(inputTokens: 500, outputTokens: tokensUsed)

        let findings = response.inferredIngredients.prefix(3).map { "Inferred: \($0.name) (\($0.necessity))" }
        progressHandler(.inferring, findings)

        let result = CulinaryInferenceResult(
            inferredIngredients: response.inferredIngredients,
            inferredSeasonings: response.inferredSeasonings,
            confidence: response.overallConfidence
        )

        return (result, tokensUsed, cost, response.overallConfidence)
    }

    // MARK: - Pass 4: Action Recognition

    private func recognizeActions(
        frames: [ExtractedFrame],
        ingredients: [IngredientDetectionResult.DetectedIngredient],
        progressHandler: @Sendable (ASMRProcessingPass, [String]) -> Void
    ) async throws -> (result: ActionRecognitionResult, tokensUsed: Int, cost: Double, confidence: Double) {

        let ingredientList = ingredients.map { $0.name }.joined(separator: ", ")

        let prompt = """
        You are analyzing cooking video frames to recognize actions and techniques.

        KNOWN INGREDIENTS: \(ingredientList)

        IMPORTANT VIDEO STRUCTURE:
        - Many cooking videos show the FINISHED DISH FIRST, then rewind to show cooking
        - Ignore final plating/presentation frames - focus ONLY on cooking process frames
        - Look for frames showing: prep work, chopping, cooking in pans, mixing, etc.
        - Skip frames that only show the final plated dish

        For each COOKING action (not plating), identify:
        1. **Cooking Actions**: chopping, sautéing, stirring, mixing, flipping, etc.
        2. **Techniques**: high-heat sear, low-and-slow braise, emulsification, etc.
        3. **Equipment Used**: pan, pot, knife, whisk, spatula, etc.
        4. **Target**: What ingredient/component is being acted upon
        5. **Timing**: Approximate duration of each action

        ONLY report actions that are part of the COOKING PROCESS (not final presentation).

        Respond in JSON:
        {
            "recognizedActions": [
                {
                    "action": "string",
                    "target": "string or null",
                    "timestamp": 0.0,
                    "duration": 0.0 or null,
                    "technique": "string or null",
                    "confidence": 0.0-1.0
                }
            ],
            "cookingTechniques": ["string"],
            "equipment": ["string"],
            "overallConfidence": 0.0-1.0
        }
        """

        // Analyze cooking frames
        let combinedImage = try await frameExtractor.createImageGrid(from: frames.map { $0.image })

        struct ActionResponse: Codable {
            let recognizedActions: [ActionRecognitionResult.RecognizedAction]
            let cookingTechniques: [String]
            let equipment: [String]
            let overallConfidence: Double
        }

        let response: ActionResponse = try await aiService.completeWithVisionStructured(
            image: combinedImage,
            prompt: prompt,
            schema: ActionResponse.self,
            options: AICompletionOptions(temperature: 0.3, maxTokens: 1500),
            useCase: .display
        )

        let tokensUsed = 1500
        let cost = calculateCost(inputTokens: 2500, outputTokens: tokensUsed)

        let findings = response.recognizedActions.prefix(3).map { "Action: \($0.action)" }
        progressHandler(.analyzing, findings)

        let result = ActionRecognitionResult(
            recognizedActions: response.recognizedActions,
            cookingTechniques: response.cookingTechniques,
            equipment: response.equipment,
            confidence: response.overallConfidence
        )

        return (result, tokensUsed, cost, response.overallConfidence)
    }

    // MARK: - Pass 5: Synthesis & Validation

    private func synthesizeRecipe(
        dishResult: DishIdentificationResult,
        ingredientResult: IngredientDetectionResult,
        inferenceResult: CulinaryInferenceResult,
        actionResult: ActionRecognitionResult,
        progressHandler: @Sendable (ASMRProcessingPass, [String]) -> Void
    ) async throws -> (result: SynthesisResult, tokensUsed: Int, cost: Double, confidence: Double) {

        let techniques = actionResult.cookingTechniques.joined(separator: ", ")

        // Build detailed ingredient context with quantities
        let ingredientDetails = ingredientResult.detectedIngredients.map { ing in
            let qty = ing.estimatedQuantity ?? "amount not visible"
            return "\(ing.name): \(qty) (\(ing.visualState))"
        }.joined(separator: "\n        ")

        let inferredDetails = inferenceResult.inferredIngredients.map { inf in
            "\(inf.name): \(inf.estimatedQuantity ?? "to taste") - \(inf.reasoning)"
        }.joined(separator: "\n        ")

        // Build action timeline
        let actionTimeline = actionResult.recognizedActions.sorted { $0.timestamp < $1.timestamp }.map { action in
            let duration = action.duration.map { " (\(Int($0))s)" } ?? ""
            return "[\(Int(action.timestamp))s] \(action.action)\(duration)"
        }.joined(separator: "\n        ")

        let prompt = """
        You are synthesizing a complete recipe from multi-pass vision analysis of a silent cooking video.

        DISH IDENTIFIED: \(dishResult.dishName) (\(dishResult.dishType))

        VISIBLE INGREDIENTS (with estimated quantities):
        \(ingredientDetails)

        INFERRED INGREDIENTS (typical for this dish):
        \(inferredDetails)

        ACTION TIMELINE (as detected, may include final dish presentation):
        \(actionTimeline)

        COOKING TECHNIQUES: \(techniques)

        CRITICAL VIDEO STRUCTURE WARNING:
        - Many cooking videos show the FINISHED DISH FIRST, then rewind to show cooking
        - The action timeline may have timestamps out of logical cooking order
        - You MUST sequence steps by COOKING LOGIC, not strictly by timestamp
        - Ignore any "plating" or "presentation" actions at the start

        Create a complete, executable recipe with these requirements:

        1. **Ingredients List**:
           - Include ALL visible and inferred ingredients
           - Use the estimated quantities from visual analysis where available
           - For inferred seasonings, use standard amounts for \(dishResult.dishType)
           - If quantity uncertain, provide typical amount with validation note

        2. **Step Sequencing** (CRITICAL - IGNORE TIMESTAMP ORDER IF ILLOGICAL):
           - Sequence steps in LOGICAL COOKING ORDER: prep → cook → finish (NOT video timestamp order)
           - Group ALL prep steps first: chopping, measuring, mixing dry ingredients
           - Then ALL cooking steps in logical sequence:
             * Heat pan/pot
             * Cook proteins (if any)
             * Add aromatics (garlic, onions, ginger)
             * Add main ingredients
             * Season and simmer
             * Final touches
           - End with serving/plating
           - If timestamps suggest "presentation first", REORDER to cooking logic
           - Each step should be a clear, single action

        3. **Timing Information**:
           - Extract cooking durations from the action timeline
           - Provide specific times for each cooking step (e.g., "5 minutes" not "until done")
           - Include temperatures where applicable

        4. **Validation Notes**:
           - Flag any ingredients where quantity is estimated/guessed
           - Note any timing ambiguities
           - Identify any missing typical ingredients for \(dishResult.dishType)
           - Highlight technique gaps

        5. **Completeness Score** (0.0-1.0):
           - 1.0 = All ingredients, quantities, and steps are clear
           - 0.7-0.9 = Most complete, some quantities/steps inferred
           - 0.5-0.7 = Reasonable but missing details
           - <0.5 = Significant gaps

        Respond in JSON matching this schema:
        {
            "title": "string",
            "servings": 4,
            "prepTime": 15,
            "cookTime": 30,
            "ingredients": [
                {
                    "name": "string",
                    "quantity": "string or null",
                    "unit": "string or null",
                    "preparation": "string or null",
                    "isOptional": false,
                    "notes": "string or null"
                }
            ],
            "steps": [
                {
                    "stepNumber": 1,
                    "instruction": "string",
                    "timing": "string or null",
                    "temperature": "string or null"
                }
            ],
            "validationNotes": [
                {
                    "type": "missingIngredient|ambiguousTiming|inferredQuantity|technicalGap",
                    "message": "string",
                    "severity": "info|warning|critical"
                }
            ],
            "completeness": 0.0-1.0,
            "overallConfidence": 0.0-1.0
        }
        """

        struct SynthesisResponse: Codable {
            let title: String
            let servings: Int
            let prepTime: Int
            let cookTime: Int
            let ingredients: [IngredientComponent]
            let steps: [StepComponent]
            let validationNotes: [SynthesisResult.ValidationNote]
            let completeness: Double
            let overallConfidence: Double

            struct IngredientComponent: Codable {
                let name: String
                let quantity: String?
                let unit: String?
                let preparation: String?
                let isOptional: Bool
                let notes: String?
            }

            struct StepComponent: Codable {
                let stepNumber: Int
                let instruction: String
                let timing: String?
                let temperature: String?
            }
        }

        // Increased token limit to prevent truncation of complex recipes
        // Previous limit of 2000 was causing truncated JSON responses
        let response: SynthesisResponse = try await aiService.completeStructured(
            prompt: prompt,
            schema: SynthesisResponse.self,
            options: AICompletionOptions(temperature: 0.4, maxTokens: 4000)
        )

        // Estimate token usage (actual varies by recipe complexity)
        let tokensUsed = 2500
        let cost = calculateCost(inputTokens: 1500, outputTokens: tokensUsed)

        let findings = [
            "Synthesized: \(response.title)",
            "Completeness: \(Int(response.completeness * 100))%",
            "Validation notes: \(response.validationNotes.count)"
        ]
        progressHandler(.validating, findings)

        // Convert to StructuredRecipe
        let structuredRecipe = StructuredRecipe(
            title: response.title,
            description: dishResult.dishType,
            servings: "\(response.servings)",
            prepTime: "\(response.prepTime) minutes",
            cookTime: "\(response.cookTime) minutes",
            ingredients: response.ingredients.map { ing in
                // Analyze quantity quality to determine if augmentation is needed
                // Detects ranges ("2-3"), vague terms ("some"), missing units, etc.
                let needsAugmentation = qualityNeedsAugmentation(
                    quantity: ing.quantity,
                    unit: ing.unit
                )

                return ExtractedIngredient(
                    originalText: ing.name,
                    item: ing.name,
                    quantity: ing.quantity,
                    unit: ing.unit,
                    preparation: ing.preparation,
                    confidence: needsAugmentation ? .unknown : .inferred
                )
            },
            steps: response.steps.map { step in
                ExtractedStep(
                    instruction: step.instruction,
                    duration: step.timing,
                    temperature: step.temperature,
                    confidence: .inferred
                )
            },
            overallConfidence: response.overallConfidence,
            warnings: response.validationNotes.map { $0.message }
        )

        // ========== INGREDIENT DEDUPLICATION PASS ==========
        print("\n🔍 Running ingredient deduplication pass...")
        print("Before deduplication: \(structuredRecipe.ingredients.count) ingredients")

        let deduplicatedIngredients = try await ingredientDeduplicator.deduplicateIngredients(
            structuredRecipe.ingredients
        )

        print("After deduplication: \(deduplicatedIngredients.count) ingredients")
        if structuredRecipe.ingredients.count > deduplicatedIngredients.count {
            let removed = structuredRecipe.ingredients.count - deduplicatedIngredients.count
            print("✅ Removed \(removed) duplicate ingredient\(removed == 1 ? "" : "s")")
        }

        // Create final recipe with deduplicated ingredients
        let finalRecipe = StructuredRecipe(
            title: structuredRecipe.title,
            description: structuredRecipe.description,
            servings: structuredRecipe.servings,
            prepTime: structuredRecipe.prepTime,
            cookTime: structuredRecipe.cookTime,
            ingredients: deduplicatedIngredients,  // ← Use deduplicated list
            steps: structuredRecipe.steps,
            overallConfidence: structuredRecipe.overallConfidence,
            warnings: structuredRecipe.warnings
        )
        // ========== END DEDUPLICATION PASS ==========

        let result = SynthesisResult(
            finalRecipe: finalRecipe,  // ← Use finalRecipe instead of structuredRecipe
            validationNotes: response.validationNotes,
            confidence: response.overallConfidence,
            completeness: response.completeness
        )

        return (result, tokensUsed, cost, response.overallConfidence)
    }

    // MARK: - Quality Analysis

    /// Determines if an ingredient quantity needs augmentation based on quality indicators
    /// Detects patterns that indicate uncertainty: ranges, vague terms, missing data
    /// For ASMR (vision-only), we're more conservative since ALL quantities are guesses
    private func qualityNeedsAugmentation(quantity: String?, unit: String?) -> Bool {
        // No quantity provided
        guard let quantity = quantity, !quantity.isEmpty else {
            print("   ❌ No quantity - needs augmentation")
            return true
        }

        // Check for range patterns (e.g., "2-3", "1-2", "1-1.5", "8-10")
        // This indicates Claude is uncertain about the exact amount
        if quantity.contains("-") && !quantity.contains("½") && !quantity.contains("¼") && !quantity.contains("¾") {
            // Allow fractions like "1-½" but not ranges like "2-3" or "1-1.5"
            let components = quantity.split(separator: "-")
            if components.count == 2 {
                let first = components[0].trimmingCharacters(in: .whitespaces)
                let second = components[1].trimmingCharacters(in: .whitespaces)

                // Try to parse as numbers (Int or Double)
                if let firstNum = Double(first), let secondNum = Double(second), secondNum > firstNum {
                    print("   ❌ Range detected '\(quantity)' - needs augmentation")
                    return true  // It's a range, needs augmentation
                }
            }
        }

        // Check for vague/uncertain terms
        let vagueTerms = ["some", "a bit", "handful", "to taste", "pinch", "amount", "about", "approximately"]
        let lowerQuantity = quantity.lowercased()
        if vagueTerms.contains(where: { lowerQuantity.contains($0) }) {
            print("   ❌ Vague term in '\(quantity)' - needs augmentation")
            return true
        }

        // Check for missing or vague unit
        if unit == nil || unit?.isEmpty == true {
            print("   ❌ Missing unit for '\(quantity)' - needs augmentation")
            return true  // Has quantity but no unit, incomplete
        }

        let vagueUnits = ["pieces", "amount", "some", "medium", "small", "large"]
        if let unit = unit?.lowercased(), vagueUnits.contains(unit) {
            print("   ❌ Vague unit '\(unit)' for '\(quantity)' - needs augmentation")
            return true
        }

        // For ASMR specifically: fractional quantities without explicit units are suspect
        // e.g., "0.5 cup cheese" might be a guess - but this has a unit so it's ok
        // However, very small quantities (<1) might be guesses
        if let numericQuantity = Double(quantity), numericQuantity < 1.0, numericQuantity > 0 {
            // Small fractional amounts in vision-only are often guesses
            print("   ⚠️ Small fractional quantity '\(quantity)' - borderline, allowing for now")
        }

        print("   ✅ Quality looks good: '\(quantity)' '\(unit ?? "")' - no augmentation needed")
        return false  // Quantity looks good, no augmentation needed
    }

    // MARK: - Helper Methods

    private func deduplicateIngredients(_ ingredients: [IngredientDetectionResult.DetectedIngredient]) -> [IngredientDetectionResult.DetectedIngredient] {
        var seen: [String: IngredientDetectionResult.DetectedIngredient] = [:]

        for ing in ingredients {
            let key = ing.name.lowercased().trimmingCharacters(in: .whitespaces)
            if let existing = seen[key] {
                // Merge frame indices, use higher confidence
                let merged = IngredientDetectionResult.DetectedIngredient(
                    name: existing.confidence > ing.confidence ? existing.name : ing.name,
                    visualState: existing.visualState,
                    estimatedQuantity: existing.estimatedQuantity ?? ing.estimatedQuantity,
                    confidence: max(existing.confidence, ing.confidence),
                    firstSeen: min(existing.firstSeen, ing.firstSeen),
                    lastSeen: max(existing.lastSeen, ing.lastSeen),
                    frameIndices: Array(Set(existing.frameIndices + ing.frameIndices)).sorted()
                )
                seen[key] = merged
            } else {
                seen[key] = ing
            }
        }

        return Array(seen.values).sorted { $0.firstSeen < $1.firstSeen }
    }

    private func calculateOverallConfidence(
        dish: Double,
        ingredients: Double,
        inference: Double,
        actions: Double,
        synthesis: Double
    ) -> Double {
        // Weighted average (dish and ingredients matter most)
        return (dish * 0.3) + (ingredients * 0.3) + (inference * 0.15) + (actions * 0.15) + (synthesis * 0.10)
    }

    /// Augment recipe with missing quantities using the same system as regular video imports
    private func augmentRecipe(
        recipe: StructuredRecipe,
        dishName: String
    ) async throws -> (recipe: StructuredRecipe, augmentedRecipe: AugmentedRecipe?, tokensUsed: Int, cost: Double) {

        var similarRecipes: [SimilarRecipeMatch] = []

        // Search for similar recipes if service is available
        if let similarRecipeService = similarRecipeService {
            print("🔍 Searching for similar recipes to '\(dishName)'...")

            similarRecipes = try await similarRecipeService.findSimilarRecipes(to: recipe, limit: 10)

            print("📊 Found \(similarRecipes.count) similar recipes:")
            for (index, match) in similarRecipes.prefix(5).enumerated() {
                print("   \(index + 1). \(match.recipe.title) (\(match.similarityPercentage)% match)")
            }
        } else {
            print("⚠️ Similar recipe search disabled (no ModelContext), using AI knowledge only")
        }

        // Call augmentation service with similar recipe context
        // This allows the AI to infer quantities based on actual recipes in the user's collection
        let augmentedResult: AugmentedRecipe = try await augmentationService.augment(
            recipe,
            similarRecipes: similarRecipes,
            webRecipes: []  // Web search not yet implemented for ASMR
        )

        // If no augmentation occurred, return original
        guard augmentedResult.hasAugmentations else {
            return (recipe, nil, 0, 0.0)
        }

        // Merge augmented quantities back into original recipe
        let mergedRecipe = try await mergeAugmentedRecipe(original: recipe, augmented: augmentedResult)

        // Estimate token usage and cost based on number of augmented ingredients
        // Augmentation typically uses ~100-150 tokens per ingredient
        let tokensPerIngredient = 120
        let estimatedTokens = augmentedResult.augmentedIngredients.count * tokensPerIngredient
        let estimatedCost = calculateCost(inputTokens: 800, outputTokens: estimatedTokens)

        return (mergedRecipe, augmentedResult, estimatedTokens, estimatedCost)
    }

    /// Merge augmented quantities back into original recipe (same pattern as regular video imports)
    private func mergeAugmentedRecipe(original: StructuredRecipe, augmented: AugmentedRecipe) async throws -> StructuredRecipe {
        var mergedIngredients = original.ingredients

        for augmentedIngredient in augmented.augmentedIngredients {
            // Find matching ingredient by original text
            if let index = mergedIngredients.firstIndex(where: {
                $0.originalText == augmentedIngredient.originalIngredient.originalText
            }) {
                // Use augmented quantity if confidence is high or medium
                if augmentedIngredient.inferredConfidence == .high ||
                   augmentedIngredient.inferredConfidence == .medium {

                    let updatedIngredient = ExtractedIngredient(
                        originalText: mergedIngredients[index].originalText,
                        item: mergedIngredients[index].item,
                        quantity: augmentedIngredient.inferredQuantity ?? mergedIngredients[index].quantity,
                        unit: augmentedIngredient.inferredUnit ?? mergedIngredients[index].unit,
                        preparation: mergedIngredients[index].preparation,
                        confidence: augmentedIngredient.inferredConfidence == .high ? .explicit : .inferred
                    )

                    mergedIngredients[index] = updatedIngredient
                }
            }
        }

        // ========== FINAL DEDUPLICATION PASS ==========
        // Run deduplication again in case augmentation introduced any duplicates
        print("\n🔍 Running post-augmentation deduplication pass...")
        print("Before final deduplication: \(mergedIngredients.count) ingredients")

        let finalDeduplicated = try await ingredientDeduplicator.deduplicateIngredients(mergedIngredients)

        print("After final deduplication: \(finalDeduplicated.count) ingredients")
        if mergedIngredients.count > finalDeduplicated.count {
            let removed = mergedIngredients.count - finalDeduplicated.count
            print("✅ Removed \(removed) duplicate ingredient\(removed == 1 ? "" : "s") after augmentation")
        }
        // ========== END FINAL DEDUPLICATION PASS ==========

        // Return new StructuredRecipe with merged and deduplicated ingredients
        return StructuredRecipe(
            title: original.title,
            description: original.description,
            servings: original.servings,
            prepTime: original.prepTime,
            cookTime: original.cookTime,
            ingredients: finalDeduplicated,  // ← Use deduplicated ingredients
            steps: original.steps,
            overallConfidence: max(original.overallConfidence, 0.8), // Boost confidence if augmented
            warnings: original.warnings
        )
    }

    private func calculateCost(inputTokens: Int, outputTokens: Int) -> Double {
        // Claude 3.5 Sonnet pricing (as of Jan 2026)
        let inputCost = Double(inputTokens) * 0.000003   // $3 per million input tokens
        let outputCost = Double(outputTokens) * 0.000015  // $15 per million output tokens
        return inputCost + outputCost
    }
}
