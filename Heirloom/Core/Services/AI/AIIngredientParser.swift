import Foundation

/// AI-powered ingredient parser using Anthropic Claude
/// Provides significantly better accuracy than regex-based parsing
/// Gracefully falls back to IngredientParser on errors
@MainActor
class AIIngredientParser {
    static let shared = AIIngredientParser()
    private init() {}

    // MARK: - Parsed Result

    /// Result structure matching IngredientParser output
    struct ParsedIngredient: Codable {
        let quantity: Double?
        let quantityMax: Double?
        let unit: String?
        let name: String

        enum CodingKeys: String, CodingKey {
            case quantity
            case quantityMax = "quantity_max"
            case unit
            case name
        }
    }

    // MARK: - Public API

    /// Parse ingredient text using AI with fallback to regex parser
    /// - Parameter text: Raw ingredient text (e.g., "2 cups all-purpose flour")
    /// - Returns: Tuple matching IngredientParser output format
    func parse(_ text: String) async throws -> (quantity: Double?, quantityMax: Double?, unit: String?, name: String) {
        // Check if AI parsing is enabled
        guard AIConfiguration.shared.enableAIParsing,
              AIConfiguration.shared.isConfigured(provider: .anthropic) else {
            // Fall back to regex parser
            return IngredientParser.parse(text)
        }

        do {
            let result = try await parseWithAI(text)

            // Track success
            AnalyticsService.shared.track(event: .aiIngredientParseSuccess, properties: [
                "ingredient_text": text,
                "has_quantity": result.quantity != nil,
                "has_unit": result.unit != nil
            ])

            return (result.quantity, result.quantityMax, result.unit, result.name)

        } catch {
            // Track failure
            AnalyticsService.shared.track(event: .aiIngredientParseFailed, properties: [
                "ingredient_text": text,
                "error": error.localizedDescription
            ])

            Log.warning("AI ingredient parsing failed, falling back to regex parser", category: .ocr, metadata: ["ingredientText": text, "error": error.localizedDescription])

            // Graceful fallback to regex parser
            return IngredientParser.parse(text)
        }
    }

    // MARK: - AI Parsing

    private func parseWithAI(_ text: String) async throws -> ParsedIngredient {
        let service = AnthropicAIService.shared
        let model = AIConfiguration.shared.model(for: .parsing)

        let prompt = buildPrompt(for: text)

        let result = try await service.completeStructured(
            prompt: prompt,
            schema: ParsedIngredient.self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.3, // Low temperature for consistent parsing
                maxTokens: 150,
                systemMessage: """
                You are an expert culinary ingredient parser. Extract structured data from ingredient text.
                Be precise with quantities, units, and ingredient names.
                """,
                stopSequences: nil
            )
        )

        return result
    }

    private func buildPrompt(for text: String) -> String {
        return """
        Parse this ingredient into structured JSON:
        "\(text)"

        Extract:
        - quantity: The numeric amount (e.g., 2, 1.5, 0.25). Null if no quantity.
        - quantity_max: For ranges like "2-3 cups", set quantity=2 and quantity_max=3. Null if not a range.
        - unit: The measurement unit (e.g., "cup", "tablespoon", "ounce", "gram"). Null if no unit.
        - name: The ingredient name without quantity/unit (e.g., "all-purpose flour", "kosher salt")

        Guidelines:
        - Convert fractions to decimals: "1/2" → 0.5, "1/4" → 0.25, "3/4" → 0.75
        - Simplify units: "tbsp" → "tablespoon", "oz" → "ounce", "c" → "cup"
        - Handle mixed numbers: "2 1/2" → 2.5
        - Handle ranges: "2-3" → quantity=2, quantity_max=3
        - Handle "to" ranges: "2 to 3" → quantity=2, quantity_max=3
        - Remove descriptors from name: "2 cups flour, sifted" → name="flour"
        - Handle no quantity: "salt to taste" → quantity=null, name="salt"
        - Handle parenthetical notes: "1 cup (2 sticks) butter" → quantity=1, unit="cup", name="butter"

        Return ONLY valid JSON:
        {
          "quantity": <number or null>,
          "quantity_max": <number or null>,
          "unit": <string or null>,
          "name": <string>
        }

        Examples:

        Input: "2 cups all-purpose flour"
        Output: {"quantity": 2.0, "quantity_max": null, "unit": "cup", "name": "all-purpose flour"}

        Input: "1/2 teaspoon salt"
        Output: {"quantity": 0.5, "quantity_max": null, "unit": "teaspoon", "name": "salt"}

        Input: "2-3 tablespoons olive oil"
        Output: {"quantity": 2.0, "quantity_max": 3.0, "unit": "tablespoon", "name": "olive oil"}

        Input: "Salt and pepper to taste"
        Output: {"quantity": null, "quantity_max": null, "unit": null, "name": "salt and pepper"}

        Input: "1 (15 oz) can diced tomatoes"
        Output: {"quantity": 1.0, "quantity_max": null, "unit": null, "name": "can diced tomatoes"}

        Now parse: "\(text)"
        """
    }

    // MARK: - Batch Parsing

    /// Parse multiple ingredients in a single AI call (more efficient)
    /// - Parameter ingredients: Array of ingredient text strings
    /// - Returns: Array of parsed ingredient tuples
    func parseBatch(_ ingredients: [String]) async throws -> [(quantity: Double?, quantityMax: Double?, unit: String?, name: String)] {
        // Check if AI parsing is enabled
        guard AIConfiguration.shared.enableAIParsing,
              AIConfiguration.shared.isConfigured(provider: .anthropic) else {
            // Fall back to regex parser for all
            return ingredients.map { IngredientParser.parse($0) }
        }

        // For small batches, use individual parsing
        if ingredients.count <= 3 {
            var results: [(Double?, Double?, String?, String)] = []
            for ingredient in ingredients {
                let result = try await parse(ingredient)
                results.append(result)
            }
            return results
        }

        // For larger batches, use batch API call (more efficient)
        do {
            let batchResult = try await parseBatchWithAI(ingredients)

            AnalyticsService.shared.track(event: .aiIngredientParseSuccess, properties: [
                "batch_size": ingredients.count,
                "mode": "batch"
            ])

            return batchResult.map { ($0.quantity, $0.quantityMax, $0.unit, $0.name) }

        } catch {
            Log.warning("Batch AI ingredient parsing failed, falling back to individual parsing", category: .ocr, metadata: ["batchSize": ingredients.count, "error": error.localizedDescription])

            AnalyticsService.shared.track(event: .aiIngredientParseFailed, properties: [
                "batch_size": ingredients.count,
                "error": error.localizedDescription
            ])

            // Fall back to individual parsing
            var results: [(Double?, Double?, String?, String)] = []
            for ingredient in ingredients {
                let result = try await parse(ingredient)
                results.append(result)
            }
            return results
        }
    }

    private func parseBatchWithAI(_ ingredients: [String]) async throws -> [ParsedIngredient] {
        let service = AnthropicAIService.shared
        let model = AIConfiguration.shared.model(for: .parsing)

        let prompt = buildBatchPrompt(for: ingredients)

        let result = try await service.completeStructured(
            prompt: prompt,
            schema: [ParsedIngredient].self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.3,
                maxTokens: 500,
                systemMessage: """
                You are an expert culinary ingredient parser. Extract structured data from multiple ingredients.
                Return a JSON array with one object per ingredient in the same order.
                """,
                stopSequences: nil
            )
        )

        return result
    }

    private func buildBatchPrompt(for ingredients: [String]) -> String {
        let numberedIngredients = ingredients.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")

        return """
        Parse these \(ingredients.count) ingredients into a JSON array:

        \(numberedIngredients)

        For each ingredient, extract:
        - quantity: Numeric amount (convert fractions to decimals)
        - quantity_max: For ranges only (e.g., "2-3" → quantity=2, quantity_max=3)
        - unit: Measurement unit (simplify abbreviations)
        - name: Ingredient name only (no quantity/unit)

        Return a JSON array with \(ingredients.count) objects in the same order:
        [
          {"quantity": <number or null>, "quantity_max": <number or null>, "unit": <string or null>, "name": <string>},
          ...
        ]
        """
    }
}
