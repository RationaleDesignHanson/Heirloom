import Foundation

/// AI-powered recipe extraction from OCR text or cookbook images
/// Handles messy OCR output and structures it into proper recipe format
@MainActor
class AIRecipeExtractor {
    static let shared = AIRecipeExtractor()
    private init() {}

    // MARK: - Extracted Recipe Structure

    struct ExtractedRecipe: Codable {
        let title: String
        let servings: String?
        let prepTime: String?
        let cookTime: String?
        let ingredients: [String]
        let instructions: [String]
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case title
            case servings
            case prepTime = "prep_time"
            case cookTime = "cook_time"
            case ingredients
            case instructions
            case notes
        }
    }

    // MARK: - Public API

    /// Extract structured recipe from OCR text using AI
    /// - Parameter ocrText: Raw text from OCR (messy, may have errors)
    /// - Returns: Structured recipe with cleaned data
    func extractRecipe(from ocrText: String) async throws -> ExtractedRecipe {
        // Check if AI enhancement is enabled
        guard AIConfiguration.shared.enableAIEnhancement,
              AIConfiguration.shared.isConfigured(provider: .anthropic) else {
            // Fall back to basic text extraction
            return extractRecipeBasic(from: ocrText)
        }

        do {
            let recipe = try await extractWithAI(ocrText)

            // Track success
            AnalyticsService.shared.track(event: .aiEnhancementSuccess, properties: [
                "source": "ocr",
                "text_length": ocrText.count,
                "ingredient_count": recipe.ingredients.count,
                "instruction_count": recipe.instructions.count
            ])

            return recipe

        } catch {
            // Track failure
            AnalyticsService.shared.track(event: .aiEnhancementFailed, properties: [
                "source": "ocr",
                "error": error.localizedDescription
            ])

            print("⚠️ AI recipe extraction failed, using basic extraction: \(error.localizedDescription)")

            // Fallback to basic extraction
            return extractRecipeBasic(from: ocrText)
        }
    }

    // MARK: - AI Extraction

    private func extractWithAI(_ ocrText: String) async throws -> ExtractedRecipe {
        let service = AnthropicAIService.shared
        let model = AIConfiguration.shared.model(for: .enhancement)

        let prompt = buildExtractionPrompt(for: ocrText)

        let result = try await service.completeStructured(
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

    // MARK: - Fallback Basic Extraction

    private func extractRecipeBasic(from text: String) -> ExtractedRecipe {
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
            notes: nil
        )
    }

    private enum Section {
        case unknown
        case ingredients
        case instructions
    }
}
