import Foundation
import UIKit
import Vision

/// AI-powered recipe extraction from OCR text or cookbook images
/// Handles messy OCR output and structures it into proper recipe format
@MainActor
class AIRecipeExtractor: AIRecipeExtractorProtocol {
    // MARK: - Dependencies

    private let aiService: AIServiceProtocol
    private let configuration: AIConfigurationProtocol
    private let analytics: AnalyticsService

    // MARK: - Initialization

    init(
        aiService: AIServiceProtocol,
        configuration: AIConfigurationProtocol,
        analytics: AnalyticsService
    ) {
        self.aiService = aiService
        self.configuration = configuration
        self.analytics = analytics
    }

    // MARK: - Detection Models (from AIRecipeDetector)

    struct DetectedRecipe: Codable {
        let id: String
        let title: String
        let boundingBox: BoundingBox
        let confidence: ConfidenceLevel

        /// Create a detected recipe covering the full image (fallback)
        static func fullImage() -> DetectedRecipe {
            return DetectedRecipe(
                id: "1",
                title: "Recipe",
                boundingBox: BoundingBox(x: 0, y: 0, width: 100, height: 100),
                confidence: .medium
            )
        }
    }

    struct BoundingBox: Codable {
        let x: Double      // % of image width (0-100)
        let y: Double      // % of image height (0-100)
        let width: Double  // % of image width (0-100)
        let height: Double // % of image height (0-100)

        /// Check if this bounding box covers the full image
        var isFullImage: Bool {
            return x <= 5 && y <= 5 && width >= 90 && height >= 90
        }

        /// Convert percentage coordinates to pixel coordinates
        func toPixelCoordinates(imageWidth: CGFloat, imageHeight: CGFloat) -> CGRect {
            let pixelX = (x / 100) * imageWidth
            let pixelY = (y / 100) * imageHeight
            let pixelWidth = (width / 100) * imageWidth
            let pixelHeight = (height / 100) * imageHeight

            return CGRect(x: pixelX, y: pixelY, width: pixelWidth, height: pixelHeight)
        }
    }

    enum ConfidenceLevel: String, Codable {
        case high = "high"
        case medium = "medium"
        case low = "low"

        var score: Double {
            switch self {
            case .high: return 0.9
            case .medium: return 0.7
            case .low: return 0.5
            }
        }

        var displayText: String {
            switch self {
            case .high: return "High Confidence"
            case .medium: return "Medium Confidence"
            case .low: return "Low Confidence"
            }
        }
    }

    // MARK: - Extracted Recipe Structure

    /// Flexible ingredient representation supporting multiple formats
    enum IngredientStructure: Codable, Equatable {
        /// Simple flat list: ["2 cups flour", "1 cup sugar"]
        case flat([String])

        /// Grouped by section: {"Cake": [...], "Frosting": [...]}
        case grouped([String: [String]])

        /// Recipe variants: {"Old Way": [...], "New Way": [...]}
        case variants([String: [String]])

        /// Decode from JSON (handles both array and object)
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            // Try array first (most common)
            if let array = try? container.decode([String].self) {
                self = .flat(array)
                return
            }

            // Try object (grouped/variants)
            if let dict = try? container.decode([String: [String]].self) {
                // Heuristic: if keys look like variants (Old Way, New Way, Version 1, etc)
                let variantKeywords = ["old", "new", "version", "variant", "option", "way", "method"]
                let hasVariantKeys = dict.keys.contains { key in
                    variantKeywords.contains(where: { key.lowercased().contains($0) })
                }

                if hasVariantKeys {
                    self = .variants(dict)
                } else {
                    self = .grouped(dict)
                }
                return
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Ingredients must be array or object"
            )
        }

        /// Encode to JSON (always as array or object)
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch self {
            case .flat(let items):
                try container.encode(items)
            case .grouped(let sections):
                try container.encode(sections)
            case .variants(let versions):
                try container.encode(versions)
            }
        }

        /// Get primary ingredient list (flattened for display)
        var flattened: [String] {
            switch self {
            case .flat(let items):
                return items
            case .grouped(let sections):
                // Flatten with section headers
                return sections.flatMap { section, items in
                    ["[\(section)]"] + items
                }
            case .variants(let versions):
                // Use first variant or combine all
                if let primary = versions.sorted(by: { $0.key < $1.key }).first?.value {
                    return primary
                }
                return []
            }
        }

        /// Check if has multiple groups
        var hasGroups: Bool {
            if case .grouped = self { return true }
            return false
        }

        /// Check if has variants
        var hasVariants: Bool {
            if case .variants = self { return true }
            return false
        }
    }

    struct ExtractedRecipe: Codable {
        let title: String
        let servings: String?
        let prepTime: String?
        let cookTime: String?
        let ingredientStructure: IngredientStructure
        let instructions: [String]
        let notes: String?
        let confidence: Double? // Added for multi-recipe detection

        /// Convenience accessor for flattened ingredients (backward compat)
        var ingredients: [String] {
            ingredientStructure.flattened
        }

        enum CodingKeys: String, CodingKey {
            case title
            case servings
            case prepTime = "prep_time"
            case cookTime = "cook_time"
            case ingredientStructure = "ingredients"
            case instructions
            case notes
            case confidence
        }
    }

    /// Result of detecting multiple recipes in a single image
    struct MultiRecipeExtractionResult {
        let recipes: [ExtractedRecipe]
        let extractionResults: [ExtractionResult]
        let sourceImage: UIImage?

        var count: Int {
            recipes.count
        }

        var hasSingleRecipe: Bool {
            recipes.count == 1
        }

        var hasMultipleRecipes: Bool {
            recipes.count > 1
        }

        var successfulCount: Int {
            extractionResults.filter { $0.success }.count
        }

        var failedCount: Int {
            extractionResults.filter { !$0.success }.count
        }
    }

    // MARK: - Recipe Detection (Vision API)

    /// Detect recipes in an image with bounding boxes
    func detectRecipes(from image: UIImage) async throws -> [DetectedRecipe] {
        Log.info("🔍 AIRecipeExtractor.detectRecipes() called", category: .import, metadata: [
            "image_width": image.size.width,
            "image_height": image.size.height
        ])

        let prompt = """
        Analyze this image and detect all distinct recipes present. For each recipe you find, provide:
        1. A descriptive title
        2. A bounding box (x, y, width, height as percentages 0-100 of image dimensions)
        3. A confidence level (high/medium/low)

        IMPORTANT: Only detect SEPARATE recipes that result in distinct final dishes.
        - DO NOT split a single recipe into multiple parts (e.g., "Crust" and "Filling" are ONE recipe, not two)
        - A recipe with subsections like "For the dough" and "For the topping" is still ONE recipe
        - Only return multiple recipes if there are truly distinct dishes (e.g., "Chocolate Chip Cookies" AND "Sugar Cookies")

        Common mistakes to avoid:
        - Splitting recipes by ingredients section and instructions section
        - Treating component recipes (dough, filling, frosting) as separate when they make one dish
        - Detecting section headers as separate recipes

        Return ONLY valid JSON in this exact format:
        {
          "recipes": [
            {
              "id": "1",
              "title": "Recipe Name",
              "boundingBox": {
                "x": 10,
                "y": 20,
                "width": 40,
                "height": 60
              },
              "confidence": "high"
            }
          ]
        }

        The bounding box should encompass the ENTIRE recipe including all sub-sections.
        Coordinates are percentages (0-100) of the image width/height.
        """

        let options = AICompletionOptions(
            model: configuration.model(for: .pdfVision),
            temperature: 0.3, // Lower temperature for more consistent detection
            maxTokens: 1000
        )

        do {
            Log.info("📡 Calling AI service for recipe detection", category: .import)
            let response: DetectionResponse = try await aiService.completeWithVisionStructured(
                image: image,
                prompt: prompt,
                schema: DetectionResponse.self,
                options: options,
                useCase: .ocr  // Use high-quality OCR settings
            )

            Log.info("✅ AI recipe detection succeeded", category: .import, metadata: [
                "detected_count": response.recipes.count,
                "titles": response.recipes.map { $0.title }.joined(separator: " | ")
            ])

            return response.recipes
        } catch {
            Log.warning("⚠️ Recipe detection failed, assuming single recipe", category: .ocr, metadata: [
                "error": error.localizedDescription,
                "error_type": "\(type(of: error))"
            ])
            // If detection fails, assume single recipe covering whole image
            let fallback = [DetectedRecipe.fullImage()]
            Log.info("📋 Using fallback: single full-image recipe", category: .import)
            return fallback
        }
    }

    private struct DetectionResponse: Codable {
        let recipes: [DetectedRecipe]
    }

    // MARK: - Protocol Conformance

    /// Extract recipe from text (Protocol)
    /// - Parameter text: Raw recipe text
    /// - Returns: Recipe object
    func extract(from text: String) async throws -> Recipe {
        let extracted = try await extractRecipe(from: text)
        return convertToRecipe(extracted, sourceText: text)
    }

    /// Extract recipe from image (Protocol)
    /// - Parameter image: Image containing recipe
    /// - Returns: Recipe object
    func extract(from image: UIImage) async throws -> Recipe {
        // Use enhanced extraction with handwriting detection (Phase 2)
        let extracted = try await extractRecipeEnhanced(from: image, text: nil, boundingBox: nil)
        return convertToRecipe(extracted, sourceImage: image)
    }

    /// Convert ExtractedRecipe to Recipe model
    private func convertToRecipe(_ extracted: ExtractedRecipe, sourceText: String? = nil, sourceImage: UIImage? = nil) -> Recipe {
        let recipe = Recipe(
            title: extracted.title,
            sourceType: sourceImage != nil ? .scan : .manual,
            sourceURL: nil,
            instructions: extracted.instructions,
            servings: extracted.servings,
            prepTime: extracted.prepTime,
            cookTime: extracted.cookTime
        )

        // Add ingredients
        for ingredientText in extracted.ingredients {
            let ingredient = Ingredient(
                originalText: ingredientText,
                name: ingredientText
            )
            ingredient.recipe = recipe
            recipe.ingredients?.append(ingredient)
        }

        // Add notes if present
        if let notes = extracted.notes, !notes.isEmpty {
            recipe.setNotes(notes)
        }

        return recipe
    }

    // MARK: - Public API

    /// Extract structured recipe from OCR text using AI
    /// - Parameter ocrText: Raw text from OCR (messy, may have errors)
    /// - Returns: Structured recipe with cleaned data
    func extractRecipe(from ocrText: String) async throws -> ExtractedRecipe {
        // Check if AI enhancement is enabled
        guard configuration.enableAIEnhancement,
              configuration.isConfigured(provider: .anthropic) else {
            // Fall back to basic text extraction
            return extractRecipeBasic(from: ocrText)
        }

        do {
            let recipe = try await extractWithAI(ocrText)

            // Track success
            analytics.track(event: .aiEnhancementSuccess, properties: [
                "source": "ocr",
                "text_length": ocrText.count,
                "ingredient_count": recipe.ingredients.count,
                "instruction_count": recipe.instructions.count
            ])

            return recipe

        } catch {
            // Track failure
            analytics.track(event: .aiEnhancementFailed, properties: [
                "source": "ocr",
                "error": error.localizedDescription
            ])

            Log.warning("AI recipe extraction failed, falling back to basic extraction", category: .ocr, metadata: ["error": error.localizedDescription])

            // Fallback to basic extraction
            return extractRecipeBasic(from: ocrText)
        }
    }

    /// Extract multiple recipes from OCR text (for images with multiple recipes)
    /// - Parameters:
    ///   - ocrText: Raw text from OCR
    ///   - sourceImage: Optional source image for reference
    /// - Returns: Result containing array of detected recipes
    func extractMultipleRecipes(from ocrText: String, sourceImage: UIImage? = nil) async throws -> MultiRecipeExtractionResult {
        // Check if AI enhancement is enabled
        guard configuration.enableAIEnhancement,
              configuration.isConfigured(provider: .anthropic) else {
            // Fall back to basic extraction (assumes single recipe)
            let recipe = extractRecipeBasic(from: ocrText)
            return MultiRecipeExtractionResult(recipes: [recipe], extractionResults: [], sourceImage: sourceImage)
        }

        do {
            let recipes = try await extractMultipleRecipesWithAI(ocrText)

            // Track success
            analytics.track(event: .aiEnhancementSuccess, properties: [
                "source": "ocr_multi",
                "text_length": ocrText.count,
                "recipe_count": recipes.count
            ])

            return MultiRecipeExtractionResult(recipes: recipes, extractionResults: [], sourceImage: sourceImage)

        } catch {
            // Track failure
            analytics.track(event: .aiEnhancementFailed, properties: [
                "source": "ocr_multi",
                "error": error.localizedDescription
            ])

            Log.warning("AI multi-recipe extraction failed, falling back to basic extraction", category: .ocr, metadata: ["error": error.localizedDescription])

            // Fallback: Try to split into multiple recipes based on heuristics
            let recipes = extractMultipleRecipesBasic(from: ocrText)
            return MultiRecipeExtractionResult(recipes: recipes, extractionResults: [], sourceImage: sourceImage)
        }
    }

    // MARK: - Vision API Extraction (Direct from Image)

    /// Extract recipe directly from image using Claude vision API (NEW - Web Demo parity)
    /// - Parameters:
    ///   - image: Recipe image
    ///   - boundingBox: Optional bounding box to focus on specific region
    /// - Returns: Structured recipe extracted via vision
    func extractRecipeFromImage(
        image: UIImage,
        boundingBox: BoundingBox? = nil
    ) async throws -> ExtractedRecipe {
        // Check if AI is configured
        guard configuration.enableAIEnhancement,
              configuration.isConfigured(provider: .anthropic) else {
            throw AIError.notConfigured(provider: "Anthropic")
        }

        // Crop image to bounding box if provided
        let imageToProcess: UIImage
        if let bbox = boundingBox, !bbox.isFullImage {
            Log.info("✂️ Cropping image to bounding box", category: .import, metadata: [
                "bbox_x": bbox.x,
                "bbox_y": bbox.y,
                "bbox_width": bbox.width,
                "bbox_height": bbox.height,
                "original_width": image.size.width,
                "original_height": image.size.height
            ])
            imageToProcess = cropImage(image, to: bbox)
            Log.info("✅ Image cropped successfully", category: .import, metadata: [
                "cropped_width": imageToProcess.size.width,
                "cropped_height": imageToProcess.size.height
            ])
        } else {
            imageToProcess = image
        }

        let prompt = buildVisionExtractionPrompt(boundingBox: nil) // No need to mention bbox in prompt anymore
        let model = configuration.model(for: .pdfVision)

        let recipe = try await aiService.completeWithVisionStructured(
            image: imageToProcess,
            prompt: prompt,
            schema: ExtractedRecipe.self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.3,
                maxTokens: 1500,
                systemMessage: "You are an expert at extracting recipes from images. Extract the recipe with high accuracy."
            ),
            useCase: .ocr  // Use high-quality OCR settings
        )

        // Track success
        analytics.track(event: .aiEnhancementSuccess, properties: [
            "source": "vision_api",
            "ingredient_count": recipe.ingredients.count,
            "instruction_count": recipe.instructions.count,
            "has_bounding_box": boundingBox != nil
        ])

        return recipe
    }

    /// Extract multiple recipes from image using vision API with bounding boxes
    /// - Parameters:
    ///   - image: Source image containing recipes
    ///   - detectedRecipes: Pre-detected recipes with bounding boxes from AIRecipeDetector
    /// - Returns: MultiRecipeExtractionResult with extracted recipes
    func extractRecipesFromImage(
        image: UIImage,
        detectedRecipes: [DetectedRecipe]
    ) async throws -> MultiRecipeExtractionResult {
        Log.info("📝 AIRecipeExtractor.extractRecipesFromImage() called", category: .import, metadata: [
            "detected_count": detectedRecipes.count,
            "detected_titles": detectedRecipes.map { $0.title }.joined(separator: " | ")
        ])

        var extractedRecipes: [ExtractedRecipe] = []
        var extractionResults: [ExtractionResult] = []

        for (index, detected) in detectedRecipes.enumerated() {
            let startTime = Date()

            Log.info("🔄 Extracting recipe \(index + 1) of \(detectedRecipes.count)", category: .import, metadata: [
                "title": detected.title,
                "confidence": detected.confidence.rawValue
            ])

            do {
                Log.info("📸 Calling extractRecipeEnhanced with bounding box", category: .import, metadata: [
                    "title": detected.title,
                    "bbox_x": detected.boundingBox.x,
                    "bbox_y": detected.boundingBox.y,
                    "bbox_width": detected.boundingBox.width,
                    "bbox_height": detected.boundingBox.height
                ])

                // Use enhanced extraction (Phase 2: handwriting detection + two-pass)
                let recipe = try await extractRecipeEnhanced(
                    from: image,
                    text: nil,
                    boundingBox: detected.boundingBox
                )

                Log.info("✅ Recipe extraction succeeded", category: .import, metadata: [
                    "title": recipe.title,
                    "ingredient_count": recipe.ingredients.count,
                    "instruction_length": recipe.instructions.count,
                    "has_variants": recipe.ingredientStructure.hasVariants,
                    "has_groups": recipe.ingredientStructure.hasGroups
                ])

                // Validate recipe quality
                if let validationError = validateRecipeQuality(recipe) {
                    Log.warning("⚠️ Recipe extraction failed (quality check)", category: .import, metadata: [
                        "recipe_index": index + 1,
                        "title": detected.title,
                        "error": validationError
                    ])

                    extractionResults.append(ExtractionResult(
                        detectedTitle: detected.title,
                        success: false,
                        recipeID: nil,
                        errorType: "incomplete_recipe",
                        errorMessage: validationError,
                        boundingBox: ExtractionResult.BoundingBox(
                            x: detected.boundingBox.x,
                            y: detected.boundingBox.y,
                            width: detected.boundingBox.width,
                            height: detected.boundingBox.height
                        ),
                        extractionDuration: Date().timeIntervalSince(startTime)
                    ))
                    continue  // Skip this recipe
                }

                // Normalize instructions (parse inline numbered lists)
                let normalizedInstructions = normalizeInstructions(recipe.instructions)

                // Add confidence from detection
                let recipeWithConfidence = ExtractedRecipe(
                    title: recipe.title,
                    servings: recipe.servings,
                    prepTime: recipe.prepTime,
                    cookTime: recipe.cookTime,
                    ingredientStructure: recipe.ingredientStructure,
                    instructions: normalizedInstructions,
                    notes: recipe.notes,
                    confidence: detected.confidence.score
                )

                extractedRecipes.append(recipeWithConfidence)

                // Track success
                extractionResults.append(ExtractionResult(
                    detectedTitle: detected.title,
                    success: true,
                    recipeID: nil,  // Will be set after Recipe model creation
                    errorType: nil,
                    errorMessage: nil,
                    boundingBox: ExtractionResult.BoundingBox(
                        x: detected.boundingBox.x,
                        y: detected.boundingBox.y,
                        width: detected.boundingBox.width,
                        height: detected.boundingBox.height
                    ),
                    extractionDuration: Date().timeIntervalSince(startTime)
                ))

            } catch DecodingError.dataCorrupted(let context) {
                // JSON schema mismatch
                let errorMsg = "Recipe format not supported: \(context.debugDescription)"
                Log.warning("⚠️ Recipe extraction failed (schema mismatch)", category: .import, metadata: [
                    "recipe_index": index + 1,
                    "title": detected.title,
                    "error": errorMsg
                ])

                extractionResults.append(ExtractionResult(
                    detectedTitle: detected.title,
                    success: false,
                    recipeID: nil,
                    errorType: "json_schema_mismatch",
                    errorMessage: errorMsg,
                    boundingBox: ExtractionResult.BoundingBox(
                        x: detected.boundingBox.x,
                        y: detected.boundingBox.y,
                        width: detected.boundingBox.width,
                        height: detected.boundingBox.height
                    ),
                    extractionDuration: Date().timeIntervalSince(startTime)
                ))

            } catch {
                // Unknown error
                let errorMsg = error.localizedDescription
                Log.warning("⚠️ Recipe extraction failed (unknown)", category: .import, metadata: [
                    "recipe_index": index + 1,
                    "title": detected.title,
                    "error": errorMsg
                ])

                extractionResults.append(ExtractionResult(
                    detectedTitle: detected.title,
                    success: false,
                    recipeID: nil,
                    errorType: "extraction_error",
                    errorMessage: errorMsg,
                    boundingBox: ExtractionResult.BoundingBox(
                        x: detected.boundingBox.x,
                        y: detected.boundingBox.y,
                        width: detected.boundingBox.width,
                        height: detected.boundingBox.height
                    ),
                    extractionDuration: Date().timeIntervalSince(startTime)
                ))
            }
        }

        Log.info("📊 Extraction summary", category: .import, metadata: [
            "total_detected": detectedRecipes.count,
            "successful": extractedRecipes.count,
            "failed": detectedRecipes.count - extractedRecipes.count
        ])

        return MultiRecipeExtractionResult(
            recipes: extractedRecipes,
            extractionResults: extractionResults,
            sourceImage: image
        )
    }

    private func buildVisionExtractionPrompt(boundingBox: BoundingBox?) -> String {
        var prompt = """
        Extract the recipe from this image and return it as structured JSON.

        """

        if let bbox = boundingBox, !bbox.isFullImage {
            prompt += """
            Focus on the recipe in this region:
            - X: \(bbox.x)% from left
            - Y: \(bbox.y)% from top
            - Width: \(bbox.width)%
            - Height: \(bbox.height)%

            """
        }

        prompt += """
        IMPORTANT: Handle various ingredient formats intelligently:

        1. Simple list (most common):
           "ingredients": ["2 cups flour", "1 cup sugar"]

        2. Grouped by section (Cake/Frosting/Sauce):
           "ingredients": {
             "Cake": ["2 cups flour", "1 cup sugar"],
             "Frosting": ["1 cup butter", "2 cups powdered sugar"]
           }

        3. Recipe variants (Old Way/New Way, Version 1/Version 2):
           "ingredients": {
             "Old Way": ["1 quart pumpkin", "1 cup milk"],
             "New Way": ["1 quart pumpkin", "1 cup evaporated milk"]
           }

        Return ONLY valid JSON:
        {
          "title": "Recipe Title",
          "servings": "4 servings",
          "prep_time": "15 min",
          "cook_time": "30 min",
          "ingredients": <array OR object with sections/variants>,
          "instructions": ["Step 1: Mix ingredients", "Step 2: Bake", ...],
          "notes": "Optional notes or tips",
          "confidence": 0.95
        }

        Instructions:
        - Extract ALL ingredients with exact quantities
        - Preserve original measurements (cups, tsp, etc.)
        - If ingredients are in columns (Old Way/New Way), use object format
        - If ingredients have sections (CAKE, FROSTING), use object format
        - Otherwise, use simple array format
        - Number instructions in logical order
        - Include all preparation steps
        - Set confidence based on text clarity (0.0-1.0)
        """

        return prompt
    }

    /// Crop UIImage to bounding box coordinates (percentages)
    private func cropImage(_ image: UIImage, to boundingBox: BoundingBox) -> UIImage {
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        let scale = image.scale

        // Convert percentage coordinates to pixel coordinates
        let x = (boundingBox.x / 100.0) * imageWidth
        let y = (boundingBox.y / 100.0) * imageHeight
        let width = (boundingBox.width / 100.0) * imageWidth
        let height = (boundingBox.height / 100.0) * imageHeight

        let cropRect = CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)

        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            Log.warning("Failed to crop image, returning original", category: .import)
            return image
        }

        return UIImage(cgImage: croppedCGImage, scale: scale, orientation: image.imageOrientation)
    }

    // MARK: - OCR Enhancement (Phase 2: Handwriting Support)

    /// Pre-process image for better OCR accuracy using CIFilter enhancements
    /// - Parameter image: Original recipe image
    /// - Returns: Enhanced image with better contrast and sharpness
    private func preprocessImageForOCR(_ image: UIImage) -> UIImage {
        // TEMPORARY: Disable preprocessing to debug hallucination issue
        // Will re-enable with gentler settings once we confirm extraction works
        #if DEBUG
        Log.info("⏭ Preprocessing disabled (debug mode)", category: .ocr)
        return image
        #else
        guard let ciImage = CIImage(image: image) else {
            Log.warning("Failed to create CIImage for preprocessing", category: .ocr)
            return image
        }

        var processedImage = ciImage

        // 1. Very subtle contrast boost for faded text (REDUCED - was too aggressive)
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.05, forKey: kCIInputContrastKey) // Gentle 5% contrast boost
            contrastFilter.setValue(1.02, forKey: kCIInputBrightnessKey) // Minimal brightness adjustment
            if let output = contrastFilter.outputImage {
                processedImage = output
            }
        }

        // 2. Gentle sharpening for handwriting (REDUCED - was over-sharpening)
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.3, forKey: kCIInputSharpnessKey) // Light sharpening only
            if let output = sharpenFilter.outputImage {
                processedImage = output
            }
        }

        // 3. Minimal noise reduction (REDUCED)
        if let noiseFilter = CIFilter(name: "CINoiseReduction") {
            noiseFilter.setValue(processedImage, forKey: kCIInputImageKey)
            noiseFilter.setValue(0.01, forKey: "inputNoiseLevel") // Very subtle
            if let output = noiseFilter.outputImage {
                processedImage = output
            }
        }

        // Convert back to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            Log.warning("Failed to create CGImage after preprocessing", category: .ocr)
            return image
        }

        let enhancedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        Log.info("✨ Image preprocessed for OCR", category: .ocr)
        return enhancedImage
        #endif
    }

    /// Detect if image contains primarily handwritten text using Vision API
    /// - Parameter image: Recipe image to analyze
    /// - Returns: True if handwriting detected (>40% of text has handwriting characteristics)
    private func detectHandwriting(in image: UIImage) async throws -> Bool {
        guard let cgImage = image.cgImage else {
            return false
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: false)
                    return
                }

                // Analyze confidence scores and bounding box characteristics
                var handwritingIndicators = 0
                var totalObservations = 0

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    totalObservations += 1

                    // Handwriting indicators:
                    // 1. Lower confidence scores (< 0.8)
                    // 2. Irregular bounding boxes (variable heights)
                    // 3. String length variance

                    let confidence = topCandidate.confidence
                    let boundingBox = observation.boundingBox

                    // Low confidence suggests handwriting
                    if confidence < 0.8 {
                        handwritingIndicators += 1
                    }

                    // Irregular bounding box heights (handwriting varies more)
                    if boundingBox.height > 0.05 || boundingBox.height < 0.02 {
                        handwritingIndicators += 1
                    }
                }

                // If >60% of observations have handwriting indicators, classify as handwritten
                // (Raised from 40% to avoid false positives on printed text with low OCR confidence)
                let handwritingRatio = totalObservations > 0 ? Double(handwritingIndicators) / Double(totalObservations * 2) : 0.0
                let isHandwritten = handwritingRatio > 0.6

                Log.info("🖊 Handwriting detection complete", category: .ocr, metadata: [
                    "total_observations": totalObservations,
                    "handwriting_indicators": handwritingIndicators,
                    "ratio": String(format: "%.2f", handwritingRatio),
                    "is_handwritten": isHandwritten
                ])

                continuation.resume(returning: isHandwritten)
            }

            // Use accurate recognition level for better detection
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Enhance handwritten recipe extraction using two-pass strategy
    /// - Parameters:
    ///   - recipe: First-pass extracted recipe
    ///   - originalImage: Original recipe image (for context)
    ///   - text: OCR text (may have errors)
    /// - Returns: Enhanced recipe with corrected instructions/ingredients
    private func enhanceHandwrittenExtraction(
        _ recipe: ExtractedRecipe,
        originalImage: UIImage,
        text: String
    ) async throws -> ExtractedRecipe {
        // Build prompt for Claude to enhance handwritten extraction
        let prompt = """
        This recipe was extracted from a handwritten image. The OCR may have missed some text or made errors.
        Please review and enhance the extraction, filling in any gaps or correcting obvious errors.

        CURRENT EXTRACTION:
        Title: \(recipe.title)
        Ingredients (\(recipe.ingredients.count)): \(recipe.ingredients.joined(separator: " | "))
        Instructions (\(recipe.instructions.count)): \(recipe.instructions.joined(separator: " | "))

        RAW OCR TEXT (for reference):
        \(text)

        TASK:
        1. Verify the title is correct
        2. Review ingredients list - add any missing ingredients you can see
        3. Review instructions - expand abbreviated steps, add missing steps
        4. Correct OCR errors (e.g., "l/2" → "1/2", "bake" → "Bake")
        5. If instructions are very short, infer complete steps based on typical recipes

        Return enhanced recipe in JSON format:
        {
          "title": "Recipe Title",
          "servings": "\(recipe.servings ?? "null")",
          "prep_time": "\(recipe.prepTime ?? "null")",
          "cook_time": "\(recipe.cookTime ?? "null")",
          "ingredients": ["ingredient 1", "ingredient 2", ...],
          "instructions": ["step 1", "step 2", ...],
          "notes": "\(recipe.notes ?? "null")"
        }

        IMPORTANT: Only add content you're confident about from the image or OCR text. Don't invent steps.
        """

        let model = configuration.model(for: .pdfVision)

        let enhanced = try await aiService.completeWithVisionStructured(
            image: originalImage,
            prompt: prompt,
            schema: ExtractedRecipe.self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.3,
                maxTokens: 2000,
                systemMessage: "You are an expert at correcting OCR errors in handwritten recipes."
            ),
            useCase: .ocr
        )

        Log.info("✨ Handwritten recipe enhanced", category: .ocr, metadata: [
            "original_ingredients": recipe.ingredients.count,
            "enhanced_ingredients": enhanced.ingredients.count,
            "original_instructions": recipe.instructions.count,
            "enhanced_instructions": enhanced.instructions.count
        ])

        return enhanced
    }

    /// Enhanced extraction for recipes (detects handwriting and applies two-pass strategy)
    /// - Parameters:
    ///   - image: Recipe image
    ///   - text: Pre-extracted OCR text (optional)
    ///   - boundingBox: Optional bounding box to focus on specific region
    /// - Returns: Extracted recipe (enhanced if handwriting detected)
    private func extractRecipeEnhanced(
        from image: UIImage,
        text: String? = nil,
        boundingBox: BoundingBox? = nil
    ) async throws -> ExtractedRecipe {
        // IMPORTANT: Crop FIRST if bounding box provided, THEN preprocess
        // (preprocessing the full image then cropping can cause over-exposure)
        let imageToProcess: UIImage
        if let bbox = boundingBox, !bbox.isFullImage {
            Log.info("✂️ Cropping image before preprocessing", category: .import, metadata: [
                "bbox_x": bbox.x,
                "bbox_y": bbox.y,
                "bbox_width": bbox.width,
                "bbox_height": bbox.height
            ])
            imageToProcess = cropImage(image, to: bbox)
        } else {
            imageToProcess = image
        }

        // Pre-process the cropped image for better OCR
        let preprocessedImage = preprocessImageForOCR(imageToProcess)

        // Detect if handwriting on the preprocessed region
        let isHandwritten = try await detectHandwriting(in: preprocessedImage)

        if isHandwritten {
            Log.info("🖊 Handwriting detected - using two-pass extraction", category: .ocr)

            // Pass 1: Standard extraction (use preprocessed image, no bounding box since already cropped)
            let firstPass = try await extractRecipeFromImage(
                image: preprocessedImage,
                boundingBox: nil
            )

            // Pass 2: Enhance with Claude using original cropped region + OCR context
            let enhanced = try await enhanceHandwrittenExtraction(
                firstPass,
                originalImage: imageToProcess,
                text: text ?? ""
            )

            // Track success
            analytics.track(event: .aiEnhancementSuccess, properties: [
                "source": "handwriting_enhanced",
                "first_pass_ingredients": firstPass.ingredients.count,
                "enhanced_ingredients": enhanced.ingredients.count,
                "first_pass_instructions": firstPass.instructions.count,
                "enhanced_instructions": enhanced.instructions.count
            ])

            return enhanced

        } else {
            Log.info("📝 Printed text detected - using standard extraction", category: .ocr)
            // Use standard extraction for printed text (no bounding box since already cropped)
            return try await extractRecipeFromImage(
                image: preprocessedImage,
                boundingBox: nil
            )
        }
    }

    // MARK: - AI Extraction (Text-Based - Legacy)

    private func extractWithAI(_ ocrText: String) async throws -> ExtractedRecipe {
        let model = configuration.model(for: .pdfEnhancement)

        let prompt = buildExtractionPrompt(for: ocrText)

        let result = try await aiService.completeStructured(
            prompt: prompt,
            schema: ExtractedRecipe.self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.3, // Low temperature for accuracy
                maxTokens: 2000, // Recipes can be long
                systemMessage: """
                You are an expert at extracting recipes from OCR text. The text may contain:
                - OCR errors (misread characters)
                - Formatting issues (inconsistent spacing, line breaks)
                - Missing or unclear section headers
                - Handwritten notes or annotations

                Your job is to identify recipe components and structure them correctly.
                """,
                stopSequences: nil
            )
        )

        return result
    }

    private func buildExtractionPrompt(for ocrText: String) -> String {
        return """
        Extract a structured recipe from this OCR text. The text may contain errors.

        OCR TEXT:
        \(ocrText)

        Extract and return JSON with:
        - title: Recipe name (required)
        - servings: How many servings (e.g., "4", "6-8 servings", null if not found)
        - prep_time: Preparation time (e.g., "15 minutes", null if not found)
        - cook_time: Cooking time (e.g., "30 minutes", null if not found)
        - ingredients: Array of ingredient strings (clean and standardize)
        - instructions: Array of instruction steps (clean, in order)
        - notes: Any additional notes or tips (null if none)

        Guidelines:
        - Fix OCR errors (e.g., "1/2" not "l/2", "flour" not "fIour")
        - Standardize measurements and units
        - Remove bullet points, numbers, formatting artifacts
        - Combine multi-line ingredients/instructions into single entries
        - Infer missing section headers from context
        - Preserve important details (temperatures, times, techniques)
        - Remove handwritten notes unless they're recipe-critical
        - If title isn't clear, infer from ingredients (e.g., "Chocolate Chip Cookies")

        Common OCR errors to fix:
        - "l" (lowercase L) → "1" (number one) in measurements
        - "O" (letter O) → "0" (zero) in measurements
        - "rn" → "m"
        - "vv" → "w"
        - Extra spaces, line breaks

        Return ONLY valid JSON:
        {
          "title": "Recipe Name",
          "servings": "4-6 servings" or null,
          "prep_time": "15 minutes" or null,
          "cook_time": "30 minutes" or null,
          "ingredients": ["1 cup flour", "2 eggs", ...],
          "instructions": ["Preheat oven to 350°F", "Mix dry ingredients", ...],
          "notes": "Can be made ahead" or null
        }

        Example Input (messy OCR):
        '''
        CHOC0LATE CHIP C00KIES

        Makes l2 cookies

        INGREDIENTS:
        - l cup all-purpose fIour
        - l/2 tsp baking soda
        - l/4 tsp salt
        - l/2 cup butter, softened
        - 3/4 cup brown sugar
        - l egg
        - l tsp vanilla
        - l cup chocolate chips

        DIRECTI0NS:
        l. Preheat oven to 350F
        2. Mix flour, baking
        soda, salt
        3. Cream butter and
        sugar until fluffy
        4. Add egg and vanilla
        5. Stir in dry ingredients
        6. Fold in chocolate chips
        7. Bake l0-l2 minutes
        '''

        Example Output:
        {
          "title": "Chocolate Chip Cookies",
          "servings": "12 cookies",
          "prep_time": null,
          "cook_time": "10-12 minutes",
          "ingredients": [
            "1 cup all-purpose flour",
            "1/2 teaspoon baking soda",
            "1/4 teaspoon salt",
            "1/2 cup butter, softened",
            "3/4 cup brown sugar",
            "1 egg",
            "1 teaspoon vanilla",
            "1 cup chocolate chips"
          ],
          "instructions": [
            "Preheat oven to 350°F",
            "Mix flour, baking soda, and salt",
            "Cream butter and sugar until fluffy",
            "Add egg and vanilla",
            "Stir in dry ingredients",
            "Fold in chocolate chips",
            "Bake 10-12 minutes"
          ],
          "notes": null
        }

        Now extract from the provided OCR text.
        """
    }

    private func extractMultipleRecipesWithAI(_ ocrText: String) async throws -> [ExtractedRecipe] {
        let model = configuration.model(for: .pdfEnhancement)

        let prompt = buildMultiRecipeExtractionPrompt(for: ocrText)

        // We need to handle array response differently
        let result = try await aiService.completeStructured(
            prompt: prompt,
            schema: [ExtractedRecipe].self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.3,
                maxTokens: 4000, // More tokens for multiple recipes
                systemMessage: """
                You are an expert at detecting and extracting multiple recipes from OCR text.
                The text may contain multiple recipes on the same page (common in vintage cookbooks).
                Each recipe may contain OCR errors and formatting issues.

                Your job is to:
                1. Detect how many distinct recipes are present
                2. Extract each recipe separately with proper structure
                3. Assign a confidence score (0.0-1.0) to each recipe based on clarity
                """,
                stopSequences: nil
            )
        )

        return result
    }

    private func buildMultiRecipeExtractionPrompt(for ocrText: String) -> String {
        return """
        Analyze this text and extract ALL recipes present. This may be from OCR (vintage cookbooks), pasted text from websites, or manually typed recipes from Notes.

        TEXT:
        \(ocrText)

        Instructions:
        1. Detect how many distinct recipes are present in the text
        2. Extract each recipe as a separate JSON object
        3. For each recipe, include a confidence score (0.0 to 1.0) based on:
           - How clear the recipe structure is
           - Completeness of ingredients and instructions
           - Whether it appears to be a complete recipe vs fragment
        4. Fix OCR errors and standardize formatting
        5. CRITICAL: Look for clear recipe boundaries - each new recipe typically starts with a title line followed by metadata (servings, time, source) or ingredients

        Return a JSON ARRAY of recipes, even if only one recipe is found:
        [
          {
            "title": "Recipe 1 Name",
            "servings": "4" or null,
            "prep_time": "15 minutes" or null,
            "cook_time": "30 minutes" or null,
            "ingredients": ["ingredient 1", "ingredient 2", ...],
            "instructions": ["step 1", "step 2", ...],
            "notes": "any notes" or null,
            "confidence": 0.95
          },
          {
            "title": "Recipe 2 Name",
            "servings": null,
            "prep_time": null,
            "cook_time": "20 minutes",
            "ingredients": ["ingredient 1", "ingredient 2", ...],
            "instructions": ["step 1", "step 2", ...],
            "notes": null,
            "confidence": 0.85
          }
        ]

        Guidelines for detection:
        - Look for clear recipe boundaries (blank lines, new titles, "makes X servings")
        - Each recipe typically has: title, ingredients list, instructions
        - Common separators: blank lines, horizontal rules, page breaks, or a new title followed by servings/time metadata
        - Vintage cookbooks often have 2-6 recipes per page
        - Modern typed recipes often have bullet points (•) for metadata and ingredients
        - Recipe titles are usually followed by metadata like "SERVINGS:", "TIME:", "SOURCE:" on the same or next line
        - When you see a new title followed by servings/time, that's a NEW recipe - don't combine it with the previous one
        - Sections like "SPICED CASHEWS", "ASSEMBLY", "CAKE", "BARK" are ingredient sub-groups within a recipe, NOT separate recipes
        - If uncertain whether something is a separate recipe, use confidence score
        - If only ONE recipe is detected, still return it in an array: [{recipe}]

        Common OCR errors to fix:
        - "l" (lowercase L) → "1" (number one) in measurements
        - "O" (letter O) → "0" (zero) in measurements
        - "rn" → "m"
        - "vv" → "w"

        Example with TWO recipes:
        [
          {
            "title": "Cheese Straws",
            "servings": "30 straws",
            "prep_time": null,
            "cook_time": "10 minutes",
            "ingredients": [
              "1 cup grated American cheese",
              "1 cup flour",
              "1 teaspoon Royal Baking Powder",
              "1/4 teaspoon salt",
              "1/8 teaspoon cayenne pepper",
              "1/4 teaspoon paprika",
              "1 egg",
              "2 tablespoons milk"
            ],
            "instructions": [
              "Mix together cheese, flour, baking powder, salt, cayenne pepper and paprika",
              "Add beaten egg; mix well; add milk enough to make a stiff dough",
              "Roll out one-eighth inch thick, on floured board",
              "Cut into strips five inches long and one-fourth inch wide",
              "Bake in hot oven at 450°F for ten minutes"
            ],
            "notes": null,
            "confidence": 0.95
          },
          {
            "title": "Peanut Butter Bread",
            "servings": "1 large loaf",
            "prep_time": null,
            "cook_time": "1 hour",
            "ingredients": [
              "2 cups flour",
              "4 teaspoons Royal Baking Powder",
              "1 teaspoon salt",
              "1/2 cup sugar",
              "1/3 cup peanut butter",
              "1 1/2 cups milk"
            ],
            "instructions": [
              "Sift flour, Royal Baking Powder, salt and sugar together into bowl",
              "Add peanut butter and mix in as for biscuits",
              "Add milk and beat thoroughly",
              "Put into one large or two small greased oblong loaf pans",
              "Smooth tops before baking",
              "Bake in moderate oven at 350°F for about one hour"
            ],
            "notes": null,
            "confidence": 0.92
          }
        ]

        Example with TWO modern recipes from Notes (with bullet points):
        [
          {
            "title": "Winter Cabbage Salad with Mandarins and Cashews",
            "servings": "4",
            "prep_time": null,
            "cook_time": "30 minutes",
            "ingredients": [
              "1 cup (115 grams) cashews",
              "2 tablespoons (25 grams) dark brown sugar",
              "1/2 teaspoon kosher salt",
              "1/4 teaspoon ground cayenne",
              "1/2 teaspoon smoked paprika",
              "1 pound (455 grams) red cabbage, thinly sliced",
              "1 small fennel bulb, halved and sliced thin (about 1 cup)",
              "3 scallions, thinly sliced",
              "Fresh mint leaves, thinly sliced",
              "3 mandarins, divided",
              "2 tablespoons white wine vinegar",
              "3 tablespoons olive oil",
              "1 teaspoon kosher salt",
              "Freshly ground black pepper",
              "1 teaspoon sumac"
            ],
            "instructions": [
              "Heat oven to 400°F. Rinse cashews with water and transfer to a bowl.",
              "Add sugar, salt, cayenne, and paprika and stir to coat evenly.",
              "Spread cashews on parchment-lined baking sheet and roast for 8-10 minutes.",
              "Let nuts cool completely.",
              "Combine cabbage, fennel, scallions, and mint in a large bowl.",
              "Juice one mandarin and pour 2 tablespoons juice into small bowl.",
              "Add vinegar, olive oil, salt, pepper, and sumac and whisk to combine.",
              "Pour over cabbage mixture.",
              "Peel remaining mandarins and separate into segments.",
              "Layer salad with mandarins and cashews on serving plate."
            ],
            "notes": "Source: Smitten Kitchen. Sumac adds a dark red color and slightly sour taste.",
            "confidence": 0.98
          },
          {
            "title": "Gingerbread Yule Log",
            "servings": "8 to 10",
            "prep_time": null,
            "cook_time": "2.5 hours",
            "ingredients": [
              "1 cup (200 grams) plus 1/3 cup (65 grams) granulated sugar",
              "1 cup (235 grams) water",
              "1 cup (100 grams) fresh cranberries",
              "3 large eggs",
              "3/4 cup (145 grams) dark brown sugar",
              "1/2 cup (150 grams) molasses or treacle",
              "3 tablespoons (45 grams) mascarpone",
              "1 teaspoon baking soda",
              "1/2 teaspoon ground cinnamon",
              "1 1/2 teaspoons ground ginger",
              "1/4 teaspoon ground cloves",
              "1/4 teaspoon kosher salt",
              "3/4 cup (100 grams) all-purpose flour",
              "6 ounces (170 grams) white chocolate chips",
              "1 1/2 cups (355 ml) heavy cream",
              "1 1/2 teaspoons vanilla extract",
              "1 1/2 to 3 tablespoons powdered sugar"
            ],
            "instructions": [
              "Make sugared cranberries: Bring 1 cup sugar and 1 cup water to simmer. Remove from heat and add cranberries. Chill for 1-2 hours.",
              "Drain cranberries and roll in remaining sugar. Chill until dry.",
              "Make cake: Heat oven to 350°F. Line 10x15-inch pan with parchment.",
              "Beat eggs until bubbly. Add brown sugar, molasses, and mascarpone and mix.",
              "Add baking soda, salt, and spices and whisk thoroughly.",
              "Add flour and stir with scraper until just combined.",
              "Pour into prepared pan and bake for 8-10 minutes until set.",
              "Cool 5 minutes, then dust with powdered sugar and roll into log. Cool completely.",
              "Make bark: Melt 2/3 of chocolate, then stir in remaining chips off heat. Spread on parchment and roll into log. Chill until firm.",
              "Make cream: Beat heavy cream, vanilla, and sugar until stiff peaks form. Whisk in mascarpone.",
              "Assemble: Unroll cake, spread with 2/3 cream, re-roll. Cover with remaining cream.",
              "Unroll chocolate bark and arrange pieces over cake to resemble bark.",
              "Dust with powdered sugar and decorate with sugared cranberries."
            ],
            "notes": "Source: Smitten Kitchen. Can simplify by skipping whipped cream exterior and white chocolate bark.",
            "confidence": 0.95
          }
        ]

        IMPORTANT PARSING RULES:
        - When you see a recipe title followed by bullet points with SERVINGS/TIME/SOURCE, that's metadata for THAT recipe
        - Sections like "SPICED CASHEWS", "ASSEMBLY", "CAKE" are ingredient groups, NOT new recipes
        - Each NEW recipe starts with a clear title (usually capitalized or prominent)
        - Instructions are the step-by-step cooking directions, usually starting with verbs (Heat, Mix, Add, etc.)
        - If you see multiple distinct recipe titles (like "Winter Cabbage Salad" then "Gingerbread Yule Log"), those are SEPARATE recipes

        Now analyze the text and return all detected recipes as a JSON array.
        """
    }

    // MARK: - Recipe Quality Validation

    /// Parses inline numbered or bulleted instructions into separate steps
    /// Handles formats like: "1. Mix flour 2. Add eggs 3. Bake"
    /// - Parameter instructions: Raw instruction strings (may contain inline lists)
    /// - Returns: Normalized array with each instruction as a separate element
    private func normalizeInstructions(_ instructions: [String]) -> [String] {
        var normalized: [String] = []

        for instruction in instructions {
            let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Check if this instruction contains multiple numbered steps on one line
            // Patterns to detect: "1.", "2.", "3." or "Step 1:", "Step 2:"
            let numberedPattern = #"(\d+\.\s+)"#
            let stepPattern = #"(Step\s+\d+:?\s+)"#

            // Try numbered pattern first (1., 2., 3.)
            if let regex = try? NSRegularExpression(pattern: numberedPattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))

                // If we found 2+ numbered markers, split by them
                if matches.count >= 2 {
                    var lastEnd = trimmed.startIndex
                    for match in matches {
                        if match.range.location > 0 {
                            // Extract the text between previous number and this number
                            let startIndex = trimmed.index(trimmed.startIndex, offsetBy: match.range.location)
                            let text = String(trimmed[lastEnd..<startIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                normalized.append(text)
                            }
                        }
                        lastEnd = trimmed.index(trimmed.startIndex, offsetBy: match.range.location)
                    }
                    // Add the last instruction
                    if lastEnd < trimmed.endIndex {
                        let text = String(trimmed[lastEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        // Remove leading number marker
                        if let cleanedText = text.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression, range: text.startIndex..<text.endIndex) as String?, !cleanedText.isEmpty {
                            normalized.append(cleanedText)
                        }
                    }
                    continue
                }
            }

            // Try "Step X:" pattern
            if let regex = try? NSRegularExpression(pattern: stepPattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))

                if matches.count >= 2 {
                    var lastEnd = trimmed.startIndex
                    for match in matches {
                        if match.range.location > 0 {
                            let startIndex = trimmed.index(trimmed.startIndex, offsetBy: match.range.location)
                            let text = String(trimmed[lastEnd..<startIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                normalized.append(text)
                            }
                        }
                        lastEnd = trimmed.index(trimmed.startIndex, offsetBy: match.range.location)
                    }
                    // Add the last instruction
                    if lastEnd < trimmed.endIndex {
                        let text = String(trimmed[lastEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if let cleanedText = text.replacingOccurrences(of: #"^Step\s+\d+:?\s*"#, with: "", options: .regularExpression, range: text.startIndex..<text.endIndex) as String?, !cleanedText.isEmpty {
                            normalized.append(cleanedText)
                        }
                    }
                    continue
                }
            }

            // No inline list detected - add as-is
            normalized.append(trimmed)
        }

        return normalized
    }

    /// Validates that an extracted recipe has sufficient content to be considered complete
    /// - Parameter recipe: The extracted recipe to validate
    /// - Returns: Error message if validation fails, nil if recipe is valid
    private func validateRecipeQuality(_ recipe: ExtractedRecipe) -> String? {
        let ingredients = recipe.ingredients
        // Normalize instructions before validation (parse inline numbered lists)
        let instructions = normalizeInstructions(recipe.instructions)

        // Check for placeholder text
        let hasPlaceholderIngredients = ingredients.contains { $0.contains("No ingredients found") }
        let hasPlaceholderInstructions = instructions.contains { $0.contains("No instructions found") }

        if hasPlaceholderIngredients {
            return "Recipe has no ingredients"
        }

        if hasPlaceholderInstructions {
            return "Recipe has no instructions"
        }

        // Check minimum ingredient count (at least 3 for a valid recipe)
        if ingredients.count < 3 {
            return "Recipe has too few ingredients (\(ingredients.count) found, need at least 3)"
        }

        // Check minimum instruction count (at least 2 for a valid recipe)
        if instructions.count < 2 {
            return "Recipe has too few instructions (\(instructions.count) found, need at least 2)"
        }

        // Check that ingredients aren't all very short (likely extraction error)
        let averageIngredientLength = ingredients.map { $0.count }.reduce(0, +) / max(ingredients.count, 1)
        if averageIngredientLength < 5 {
            return "Recipe ingredients appear incomplete (avg length: \(averageIngredientLength) chars)"
        }

        // Check that instructions aren't all very short (likely extraction error)
        let averageInstructionLength = instructions.map { $0.count }.reduce(0, +) / max(instructions.count, 1)
        if averageInstructionLength < 10 {
            return "Recipe instructions appear incomplete (avg length: \(averageInstructionLength) chars)"
        }

        // Recipe passes quality checks
        return nil
    }

    // MARK: - Fallback Basic Extraction

    func extractRecipeBasic(from text: String) -> ExtractedRecipe {
        let lines = text.components(separatedBy: .newlines)

        var title = "Untitled Recipe"
        var ingredients: [String] = []
        var instructions: [String] = []
        var servings: String?
        var prepTime: String?
        var cookTime: String?

        var currentSection: Section = .unknown

        // Try to find title from first few lines
        for (index, line) in lines.prefix(5).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed.count > 3 && index < 3 {
                // Likely a title if it's short-ish and near the top
                if !trimmed.lowercased().contains("ingredient") &&
                   !trimmed.lowercased().contains("direction") &&
                   !trimmed.lowercased().contains("instruction") {
                    title = trimmed
                    break
                }
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let lowercased = trimmed.lowercased()

            // Detect sections
            if lowercased.contains("ingredient") {
                currentSection = .ingredients
                continue
            } else if lowercased.contains("instruction") ||
                      lowercased.contains("direction") ||
                      lowercased.contains("method") ||
                      lowercased.contains("steps") {
                currentSection = .instructions
                continue
            }

            // Extract metadata
            if lowercased.contains("serves") || lowercased.contains("servings") {
                servings = trimmed
                continue
            }
            if lowercased.contains("prep time") {
                prepTime = trimmed
                continue
            }
            if lowercased.contains("cook time") {
                cookTime = trimmed
                continue
            }

            // Add to current section
            switch currentSection {
            case .ingredients:
                let cleaned = trimmed
                    .replacingOccurrences(of: "^[•\\-\\*]\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    ingredients.append(cleaned)
                }

            case .instructions:
                let cleaned = trimmed
                    .replacingOccurrences(of: "^\\d+[\\.\\)]\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    instructions.append(cleaned)
                }

            case .unknown:
                break
            }
        }

        return ExtractedRecipe(
            title: title,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime,
            ingredientStructure: .flat(ingredients.isEmpty ? ["No ingredients found"] : ingredients),
            instructions: instructions.isEmpty ? ["No instructions found"] : instructions,
            notes: nil,
            confidence: nil
        )
    }

    /// Extract multiple recipes using basic heuristics (fallback when AI fails)
    func extractMultipleRecipesBasic(from text: String) -> [ExtractedRecipe] {
        // Try to split text into multiple recipes based on common patterns
        let lines = text.components(separatedBy: .newlines)
        var recipeChunks: [[String]] = []
        var currentChunk: [String] = []

        // Look for recipe boundaries - new titles with metadata pattern
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if trimmed.isEmpty {
                if !currentChunk.isEmpty {
                    currentChunk.append(line)  // Keep structure
                }
                continue
            }

            // Detect new recipe start: Title-like line (not all caps section header)
            // followed by SERVINGS/TIME metadata within next 3 lines
            let isLikelyTitle = trimmed.count > 10 &&
                               trimmed.count < 100 &&
                               !trimmed.hasPrefix("•") &&
                               !trimmed.uppercased().contains("SERVINGS:") &&
                               !trimmed.uppercased().contains("SOURCE:") &&
                               !["CRANBERRIES", "CAKE", "BARK", "FILLING", "ASSEMBLY", "SPICED CASHEWS"].contains(trimmed.uppercased())

            if isLikelyTitle {
                // Look ahead for metadata markers
                let nextFewLines = lines.dropFirst(index + 1).prefix(3)
                let hasMetadata = nextFewLines.contains { nextLine in
                    let next = nextLine.uppercased()
                    return next.contains("SERVINGS:") || next.contains("TIME:") || next.contains("SOURCE:")
                }

                // If we have metadata following this title and we already have a chunk, start new recipe
                if hasMetadata && !currentChunk.isEmpty {
                    recipeChunks.append(currentChunk)
                    currentChunk = [line]
                    continue
                }
            }

            currentChunk.append(line)
        }

        // Add final chunk
        if !currentChunk.isEmpty {
            recipeChunks.append(currentChunk)
        }

        // If we only found one chunk, just use basic extraction
        if recipeChunks.count <= 1 {
            Log.info("Basic extraction found single recipe", category: .ocr)
            let recipe = extractRecipeBasic(from: text)
            return [recipe]
        }

        // Extract each chunk as a separate recipe
        Log.info("Basic extraction split into multiple recipes", category: .ocr, metadata: ["count": recipeChunks.count])

        return recipeChunks.map { chunk in
            let chunkText = chunk.joined(separator: "\n")
            return extractRecipeBasic(from: chunkText)
        }
    }

    private enum Section {
        case unknown
        case ingredients
        case instructions
    }
}

// MARK: - Global Convenience

extension AIRecipeExtractor {
    /// Global accessor that resolves from ServiceContainer for proper DI
    /// Maintains backward compatibility with existing .shared usage
    /// Note: Safe to use from any context - ServiceContainer is thread-safe
    nonisolated(unsafe) static var shared: AIRecipeExtractor {
        MainActor.assumeIsolated {
            ServiceContainer.shared.resolve(AIRecipeExtractor.self)
        }
    }
}
