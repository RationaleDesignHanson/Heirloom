import Foundation

/// AI-powered ingredient parser using Anthropic Claude
/// Provides significantly better accuracy than regex-based parsing
/// Gracefully falls back to IngredientParser on errors
@MainActor
class AIIngredientParser: AIIngredientParserProtocol {
    // MARK: - Dependencies

    private let aiService: AIServiceProtocol
    private let configuration: AIConfigurationProtocol
    private let analytics: AnalyticsServiceProtocol

    // MARK: - Initialization

    init(
        aiService: AIServiceProtocol,
        configuration: AIConfigurationProtocol,
        analytics: AnalyticsServiceProtocol
    ) {
        self.aiService = aiService
        self.configuration = configuration
        self.analytics = analytics
    }

    // MARK: - Parsed Result

    /// Result structure matching IngredientParser output
    struct ParsedIngredient: Codable {
        let quantity: Double?
        let quantityMax: Double?
        let unit: String?
        let name: String
        let preparation: String?

        enum CodingKeys: String, CodingKey {
            case quantity
            case quantityMax = "quantity_max"
            case unit
            case name
            case preparation
        }
    }

    // MARK: - Public API

    // MARK: - Protocol Conformance

    /// Parse ingredient text using AI with fallback to regex parser (Protocol)
    /// - Parameter text: Raw ingredient text (e.g., "2 cups all-purpose flour")
    /// - Returns: Ingredient object
    func parse(_ text: String) async throws -> Ingredient {
        let tuple = try await parseToTuple(text)
        let ingredient = Ingredient(
            originalText: text,
            name: tuple.name,
            quantity: tuple.quantity,
            unit: tuple.unit
        )
        ingredient.preparation = tuple.preparation
        return ingredient
    }

    /// Parse multiple ingredients in batch (Protocol)
    /// - Parameter texts: Array of ingredient texts
    /// - Returns: Array of Ingredient objects
    func parseBatch(_ texts: [String]) async throws -> [Ingredient] {
        let tuples = try await parseBatchToTuple(texts)
        return zip(texts, tuples).map { text, tuple in
            let ingredient = Ingredient(
                originalText: text,
                name: tuple.name,
                quantity: tuple.quantity,
                unit: tuple.unit
            )
            ingredient.preparation = tuple.preparation
            return ingredient
        }
    }

    // MARK: - Tuple API (Legacy compatibility)

    /// Parse ingredient text using AI with fallback to regex parser
    /// - Parameter text: Raw ingredient text (e.g., "2 cups all-purpose flour")
    /// - Returns: Tuple matching IngredientParser output format
    func parseToTuple(_ text: String) async throws -> (quantity: Double?, quantityMax: Double?, unit: String?, name: String, preparation: String?) {
        // Check if AI parsing is enabled
        guard configuration.enableAIParsing,
              configuration.isConfigured(provider: .anthropic) else {
            // Fall back to regex parser
            let result = IngredientParser.parse(text)
            return (result.0, result.1, result.2, result.3, nil) // regex parser doesn't extract preparation
        }

        do {
            let result = try await parseWithAI(text)

            // Track success
            analytics.track(event: .aiIngredientParseSuccess, properties: [
                "ingredient_text": text,
                "has_quantity": result.quantity != nil,
                "has_unit": result.unit != nil,
                "has_preparation": result.preparation != nil
            ])

            return (result.quantity, result.quantityMax, result.unit, result.name, result.preparation)

        } catch {
            // Track failure
            analytics.track(event: .aiIngredientParseFailed, properties: [
                "ingredient_text": text,
                "error": error.localizedDescription
            ])

            Log.warning("AI ingredient parsing failed, falling back to regex parser", category: .ocr, metadata: ["ingredientText": text, "error": error.localizedDescription])

            // Graceful fallback to regex parser
            let result = IngredientParser.parse(text)
            return (result.0, result.1, result.2, result.3, nil)
        }
    }

    // MARK: - AI Parsing

    private func parseWithAI(_ text: String) async throws -> ParsedIngredient {
        let model = configuration.model(for: .parsing)

        let prompt = buildPrompt(for: text)

        // Add timeout protection for AI API calls (30 seconds)
        let result = try await TaskTimeout.withTimeout(seconds: TaskTimeout.firebaseStandard) { [self] in
            try await self.aiService.completeStructured(
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
        }

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
        - name: The ingredient name without quantity/unit/preparation (e.g., "all-purpose flour", "garlic", "onion")
        - preparation: How to prepare the ingredient (e.g., "thinly sliced", "diced", "minced", "chopped", "sifted", "melted"). Null if no preparation specified.

        Guidelines:
        - Convert fractions to decimals: "1/2" → 0.5, "1/4" → 0.25, "3/4" → 0.75
        - Simplify units: "tbsp" → "tablespoon", "oz" → "ounce", "c" → "cup"
        - Handle mixed numbers: "2 1/2" → 2.5
        - Handle ranges: "2-3" → quantity=2, quantity_max=3
        - Handle "to" ranges: "2 to 3" → quantity=2, quantity_max=3
        - PRESERVE preparation instructions: "2 cloves garlic, thinly sliced" → name="garlic", preparation="thinly sliced"
        - Common preparations: "diced", "chopped", "minced", "sliced", "grated", "shredded", "melted", "softened", "beaten", "sifted"
        - Handle no quantity: "salt to taste" → quantity=null, name="salt", preparation=null
        - Handle parenthetical notes: "1 cup (2 sticks) butter" → quantity=1, unit="cup", name="butter"

        Return ONLY valid JSON:
        {
          "quantity": <number or null>,
          "quantity_max": <number or null>,
          "unit": <string or null>,
          "name": <string>,
          "preparation": <string or null>
        }

        Examples:

        Input: "2 cups all-purpose flour"
        Output: {"quantity": 2.0, "quantity_max": null, "unit": "cup", "name": "all-purpose flour", "preparation": null}

        Input: "1/2 teaspoon salt"
        Output: {"quantity": 0.5, "quantity_max": null, "unit": "teaspoon", "name": "salt", "preparation": null}

        Input: "2 cloves garlic, thinly sliced"
        Output: {"quantity": 2.0, "quantity_max": null, "unit": "clove", "name": "garlic", "preparation": "thinly sliced"}

        Input: "1 medium onion, diced"
        Output: {"quantity": 1.0, "quantity_max": null, "unit": null, "name": "onion", "preparation": "diced"}

        Input: "2 cups flour, sifted"
        Output: {"quantity": 2.0, "quantity_max": null, "unit": "cup", "name": "flour", "preparation": "sifted"}

        Input: "Salt and pepper to taste"
        Output: {"quantity": null, "quantity_max": null, "unit": null, "name": "salt and pepper", "preparation": null}

        Now parse: "\(text)"
        """
    }

    // MARK: - Batch Parsing (Legacy compatibility)

    /// Parse multiple ingredients in a single AI call (more efficient)
    /// - Parameter ingredients: Array of ingredient text strings
    /// - Returns: Array of parsed ingredient tuples
    func parseBatchToTuple(_ ingredients: [String]) async throws -> [(quantity: Double?, quantityMax: Double?, unit: String?, name: String, preparation: String?)] {
        // Check if AI parsing is enabled
        guard configuration.enableAIParsing,
              configuration.isConfigured(provider: .anthropic) else {
            // Fall back to regex parser for all
            return ingredients.map {
                let result = IngredientParser.parse($0)
                return (result.0, result.1, result.2, result.3, nil as String?)
            }
        }

        // For small batches, use individual parsing
        if ingredients.count <= 3 {
            var results: [(Double?, Double?, String?, String, String?)] = []
            for ingredient in ingredients {
                let result = try await parseToTuple(ingredient)
                results.append(result)
            }
            return results
        }

        // For larger batches, use batch API call (more efficient)
        do {
            let batchResult = try await parseBatchWithAI(ingredients)

            analytics.track(event: .aiIngredientParseSuccess, properties: [
                "batch_size": ingredients.count,
                "mode": "batch"
            ])

            return batchResult.map { ($0.quantity, $0.quantityMax, $0.unit, $0.name, $0.preparation) }

        } catch {
            Log.warning("Batch AI ingredient parsing failed, falling back to individual parsing", category: .ocr, metadata: ["batchSize": ingredients.count, "error": error.localizedDescription])

            analytics.track(event: .aiIngredientParseFailed, properties: [
                "batch_size": ingredients.count,
                "error": error.localizedDescription
            ])

            // Fall back to individual parsing
            var results: [(Double?, Double?, String?, String, String?)] = []
            for ingredient in ingredients {
                let result = try await parseToTuple(ingredient)
                results.append(result)
            }
            return results
        }
    }

    private func parseBatchWithAI(_ ingredients: [String]) async throws -> [ParsedIngredient] {
        let model = configuration.model(for: .parsing)

        let prompt = buildBatchPrompt(for: ingredients)

        // Add timeout protection for AI API calls (60 seconds for batch operations)
        let result = try await TaskTimeout.withTimeout(seconds: TaskTimeout.firebaseLong) { [self] in
            try await self.aiService.completeStructured(
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
        }

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
        - name: Ingredient name only (no quantity/unit/preparation)
        - preparation: How to prepare (e.g., "thinly sliced", "diced", "minced", "chopped"). Null if none.

        IMPORTANT: PRESERVE preparation instructions like "thinly sliced", "diced", "minced", "chopped", "sifted", etc.

        Return a JSON array with \(ingredients.count) objects in the same order:
        [
          {"quantity": <number or null>, "quantity_max": <number or null>, "unit": <string or null>, "name": <string>, "preparation": <string or null>},
          ...
        ]
        """
    }
}
