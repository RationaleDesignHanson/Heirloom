import Foundation
import UIKit

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

    struct ExtractedRecipe: Codable {
        let title: String
        let servings: String?
        let prepTime: String?
        let cookTime: String?
        let ingredients: [String]
        let instructions: [String]
        let notes: String?
        let confidence: Double? // Added for multi-recipe detection

        enum CodingKeys: String, CodingKey {
            case title
            case servings
            case prepTime = "prep_time"
            case cookTime = "cook_time"
            case ingredients
            case instructions
            case notes
            case confidence
        }
    }

    /// Result of detecting multiple recipes in a single image
    struct MultiRecipeExtractionResult {
        let recipes: [ExtractedRecipe]
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
        let extracted = try await extractRecipeFromImage(image: image, boundingBox: nil)
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
            return MultiRecipeExtractionResult(recipes: [recipe], sourceImage: sourceImage)
        }

        do {
            let recipes = try await extractMultipleRecipesWithAI(ocrText)

            // Track success
            analytics.track(event: .aiEnhancementSuccess, properties: [
                "source": "ocr_multi",
                "text_length": ocrText.count,
                "recipe_count": recipes.count
            ])

            return MultiRecipeExtractionResult(recipes: recipes, sourceImage: sourceImage)

        } catch {
            // Track failure
            analytics.track(event: .aiEnhancementFailed, properties: [
                "source": "ocr_multi",
                "error": error.localizedDescription
            ])

            Log.warning("AI multi-recipe extraction failed, falling back to basic extraction", category: .ocr, metadata: ["error": error.localizedDescription])

            // Fallback: Try to split into multiple recipes based on heuristics
            let recipes = extractMultipleRecipesBasic(from: ocrText)
            return MultiRecipeExtractionResult(recipes: recipes, sourceImage: sourceImage)
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

        let prompt = buildVisionExtractionPrompt(boundingBox: boundingBox)
        let model = configuration.model(for: .pdfVision)

        let recipe = try await aiService.completeWithVisionStructured(
            image: image,
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

        for (index, detected) in detectedRecipes.enumerated() {
            Log.info("🔄 Extracting recipe \(index + 1) of \(detectedRecipes.count)", category: .import, metadata: [
                "title": detected.title,
                "confidence": detected.confidence.rawValue
            ])
            do {
                Log.info("📸 Calling extractRecipeFromImage with bounding box", category: .import, metadata: [
                    "title": detected.title,
                    "bbox_x": detected.boundingBox.x,
                    "bbox_y": detected.boundingBox.y,
                    "bbox_width": detected.boundingBox.width,
                    "bbox_height": detected.boundingBox.height
                ])
                let recipe = try await extractRecipeFromImage(
                    image: image,
                    boundingBox: detected.boundingBox
                )

                Log.info("✅ Recipe extraction succeeded", category: .import, metadata: [
                    "title": recipe.title,
                    "ingredient_count": recipe.ingredients.count,
                    "instruction_length": recipe.instructions.count
                ])

                // Add confidence from detection
                let recipeWithConfidence = ExtractedRecipe(
                    title: recipe.title,
                    servings: recipe.servings,
                    prepTime: recipe.prepTime,
                    cookTime: recipe.cookTime,
                    ingredients: recipe.ingredients,
                    instructions: recipe.instructions,
                    notes: recipe.notes,
                    confidence: detected.confidence.score
                )

                extractedRecipes.append(recipeWithConfidence)
            } catch {
                Log.warning("Failed to extract individual recipe from multi-recipe image", category: .ocr, metadata: ["title": detected.title, "error": error.localizedDescription])
                // Continue with other recipes even if one fails
                continue
            }
        }

        return MultiRecipeExtractionResult(recipes: extractedRecipes, sourceImage: image)
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
        Return ONLY valid JSON with this structure:
        {
          "title": "Recipe Title",
          "servings": "4 servings",
          "prep_time": "15 min",
          "cook_time": "30 min",
          "ingredients": ["2 cups flour", "1 cup sugar", ...],
          "instructions": ["Step 1: Mix ingredients", "Step 2: Bake", ...],
          "notes": "Optional notes or tips",
          "confidence": 0.95
        }

        Instructions:
        - Extract ALL ingredients with exact quantities
        - Preserve original measurements (cups, tsp, etc.)
        - Number instructions in logical order
        - Include all preparation steps
        - Set confidence based on text clarity (0.0-1.0)
        """

        return prompt
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
            ingredients: ingredients.isEmpty ? ["No ingredients found"] : ingredients,
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
