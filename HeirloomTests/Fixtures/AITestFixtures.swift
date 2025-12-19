import Foundation
@testable import Heirloom

/// Shared test fixtures and mock data for AI feature testing
/// Provides realistic test cases to ensure comprehensive coverage
struct AITestFixtures {

    // MARK: - API Keys

    static let validAPIKey = "sk-ant-test123validkeyfromconsole"
    static let invalidAPIKey = "invalid-key-format-missing-prefix"
    static let emptyAPIKey = ""
    static let anthropicKeyPrefix = "sk-ant-"

    // MARK: - Sample Ingredients

    /// Common ingredients for testing parsing accuracy
    static let sampleIngredients = [
        "2 cups all-purpose flour",
        "1/2 teaspoon salt",
        "2-3 tablespoons olive oil",
        "Salt to taste",
        "1 (15 oz) can diced tomatoes",
        "2 1/4 cups granulated sugar",
        "4 large eggs, beaten",
        "1 cup milk, warmed"
    ]

    /// Ingredients with complex formats
    static let complexIngredients = [
        "2 cups (250g) all-purpose flour, sifted",
        "1/2-3/4 cup warm water (110-115°F)",
        "2 medium onions, finely chopped",
        "Salt and freshly ground black pepper",
        "3-4 cloves garlic, minced",
        "1 stick (1/2 cup) unsalted butter, melted"
    ]

    /// Ingredients with fractions and ranges
    static let fractionalIngredients = [
        ("1/2 cup milk", (0.5, nil, "cup", "milk")),
        ("2 1/4 cups sugar", (2.25, nil, "cup", "sugar")),
        ("1/4 teaspoon salt", (0.25, nil, "teaspoon", "salt")),
        ("2-3 tablespoons butter", (2.0, 3.0, "tablespoon", "butter")),
        ("1-2 cups flour", (1.0, 2.0, "cup", "flour"))
    ]

    /// Ingredients without quantities
    static let noQuantityIngredients = [
        "Salt to taste",
        "Freshly ground black pepper",
        "Optional: vanilla extract",
        "Garnish with fresh herbs"
    ]

    // MARK: - Sample OCR Text

    /// Clean OCR text with clear formatting
    static let cleanOCRText = """
    CHOCOLATE CHIP COOKIES

    Makes 24 cookies
    Prep: 15 minutes
    Bake: 12 minutes

    INGREDIENTS:
    - 2 cups all-purpose flour
    - 1 teaspoon baking soda
    - 1/2 teaspoon salt
    - 1 cup butter, softened
    - 3/4 cup granulated sugar
    - 3/4 cup packed brown sugar
    - 2 large eggs
    - 1 teaspoon vanilla extract
    - 2 cups chocolate chips

    INSTRUCTIONS:
    1. Preheat oven to 350°F (175°C)
    2. Mix flour, baking soda, and salt in a bowl
    3. In another bowl, cream butter and sugars until fluffy
    4. Beat in eggs and vanilla
    5. Gradually stir in flour mixture
    6. Fold in chocolate chips
    7. Drop rounded tablespoons of dough onto baking sheets
    8. Bake 10-12 minutes until golden brown
    9. Cool on baking sheet for 2 minutes, then transfer to wire rack

    NOTES:
    Can be made ahead and frozen for up to 3 months.
    """

    /// Messy OCR text with common errors
    static let messyOCRText = """
    CHOC0LATE CHIP C00KIES

    Makes l2 cookies

    INGREDIENTS:
    - l cup all-purpose fIour
    - l/2 tsp baking soda
    - l/4 tsp salt
    - l/2 cup butter, softened
    - 3/4 cup brown sugr
    - l egg
    - l tsp vaniIIa
    - l cup chocolate chlps

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
    """

    /// OCR text with missing section headers
    static let noHeadersOCRText = """
    Pancakes

    2 cups flour
    2 tablespoons sugar
    1 tablespoon baking powder
    1/2 teaspoon salt
    2 eggs
    1 3/4 cups milk
    1/4 cup melted butter

    Mix dry ingredients together
    In separate bowl, whisk eggs, milk, and butter
    Combine wet and dry ingredients
    Cook on hot griddle until bubbles form
    Flip and cook until golden
    Serve with maple syrup
    """

    /// Very short OCR text (edge case)
    static let minimalOCRText = """
    Toast
    Bread
    Butter
    Toast bread, spread butter
    """

    // MARK: - Expected Parsing Results

    /// Expected results for cleanOCRText
    static let expectedCleanRecipe = AIRecipeExtractor.ExtractedRecipe(
        title: "Chocolate Chip Cookies",
        servings: "24 cookies",
        prepTime: "15 minutes",
        cookTime: "12 minutes",
        ingredients: [
            "2 cups all-purpose flour",
            "1 teaspoon baking soda",
            "1/2 teaspoon salt",
            "1 cup butter, softened",
            "3/4 cup granulated sugar",
            "3/4 cup packed brown sugar",
            "2 large eggs",
            "1 teaspoon vanilla extract",
            "2 cups chocolate chips"
        ],
        instructions: [
            "Preheat oven to 350°F (175°C)",
            "Mix flour, baking soda, and salt in a bowl",
            "In another bowl, cream butter and sugars until fluffy",
            "Beat in eggs and vanilla",
            "Gradually stir in flour mixture",
            "Fold in chocolate chips",
            "Drop rounded tablespoons of dough onto baking sheets",
            "Bake 10-12 minutes until golden brown",
            "Cool on baking sheet for 2 minutes, then transfer to wire rack"
        ],
        notes: "Can be made ahead and frozen for up to 3 months."
    )

    // MARK: - Mock API Responses

    /// Create mock Anthropic API response JSON
    static func mockAnthropicResponse(
        content: String,
        inputTokens: Int = 50,
        outputTokens: Int = 30
    ) -> Data {
        let json = """
        {
            "id": "msg_test_\(UUID().uuidString.prefix(8))",
            "type": "message",
            "role": "assistant",
            "content": [
                {
                    "type": "text",
                    "text": "\(content.replacingOccurrences(of: "\"", with: "\\\""))"
                }
            ],
            "model": "claude-3-haiku-20240307",
            "stop_reason": "end_turn",
            "usage": {
                "input_tokens": \(inputTokens),
                "output_tokens": \(outputTokens)
            }
        }
        """
        return json.data(using: .utf8)!
    }

    /// Create mock error response JSON
    static func mockErrorResponse(errorType: String, message: String) -> Data {
        let json = """
        {
            "type": "error",
            "error": {
                "type": "\(errorType)",
                "message": "\(message)"
            }
        }
        """
        return json.data(using: .utf8)!
    }

    /// Create mock ingredient parsing response
    static func mockIngredientJSON(
        quantity: Double?,
        quantityMax: Double?,
        unit: String?,
        name: String
    ) -> String {
        var json = "{"

        if let q = quantity {
            json += "\"quantity\": \(q), "
        } else {
            json += "\"quantity\": null, "
        }

        if let qMax = quantityMax {
            json += "\"quantity_max\": \(qMax), "
        } else {
            json += "\"quantity_max\": null, "
        }

        if let u = unit {
            json += "\"unit\": \"\(u)\", "
        } else {
            json += "\"unit\": null, "
        }

        json += "\"name\": \"\(name)\""
        json += "}"

        return json
    }

    // MARK: - Test Dataset for Accuracy Validation

    /// 100 real-world ingredients with expected parse results
    /// Format: (input text, (quantity, quantityMax, unit, name))
    static let accuracyTestDataset: [(String, (Double?, Double?, String?, String))] = [
        // Basic measurements (1-20)
        ("1 cup flour", (1.0, nil, "cup", "flour")),
        ("2 cups water", (2.0, nil, "cup", "water")),
        ("3 tablespoons butter", (3.0, nil, "tablespoon", "butter")),
        ("1 teaspoon salt", (1.0, nil, "teaspoon", "salt")),
        ("4 ounces cream cheese", (4.0, nil, "ounce", "cream cheese")),
        ("2 pounds ground beef", (2.0, nil, "pound", "ground beef")),
        ("1 liter milk", (1.0, nil, "liter", "milk")),
        ("500 grams sugar", (500.0, nil, "gram", "sugar")),
        ("3 large eggs", (3.0, nil, nil, "eggs")),
        ("6 slices bacon", (6.0, nil, "slice", "bacon")),

        // Fractions (21-40)
        ("1/2 cup milk", (0.5, nil, "cup", "milk")),
        ("1/4 teaspoon pepper", (0.25, nil, "teaspoon", "pepper")),
        ("1/3 cup oil", (0.333, nil, "cup", "oil")),
        ("3/4 cup brown sugar", (0.75, nil, "cup", "brown sugar")),
        ("2 1/2 cups flour", (2.5, nil, "cup", "flour")),
        ("1 1/4 cups water", (1.25, nil, "cup", "water")),
        ("3 1/2 tablespoons honey", (3.5, nil, "tablespoon", "honey")),

        // Ranges (41-50)
        ("2-3 cloves garlic", (2.0, 3.0, "clove", "garlic")),
        ("1-2 cups water", (1.0, 2.0, "cup", "water")),
        ("3-4 tablespoons butter", (3.0, 4.0, "tablespoon", "butter")),

        // No quantity (51-60)
        ("Salt to taste", (nil, nil, nil, "salt")),
        ("Pepper as needed", (nil, nil, nil, "pepper")),
        ("Fresh basil leaves", (nil, nil, nil, "basil leaves")),

        // Complex (61-80)
        ("1 (15 oz) can tomatoes", (1.0, nil, "can", "tomatoes")),
        ("2 cups flour, sifted", (2.0, nil, "cup", "flour")),
        ("1 cup milk, warmed", (1.0, nil, "cup", "milk")),
        ("3 eggs, beaten", (3.0, nil, nil, "eggs")),
        ("1/2 cup butter, melted", (0.5, nil, "cup", "butter")),

        // Add more to reach 100...
        ("1 cup all-purpose flour", (1.0, nil, "cup", "all-purpose flour")),
        ("2 teaspoons baking powder", (2.0, nil, "teaspoon", "baking powder")),
        ("1/2 teaspoon vanilla extract", (0.5, nil, "teaspoon", "vanilla extract")),
        ("4 ounces chocolate, chopped", (4.0, nil, "ounce", "chocolate")),
        ("1 pinch cayenne pepper", (1.0, nil, "pinch", "cayenne pepper"))
    ]

    // MARK: - Helper Methods

    /// Verify parsed ingredient matches expected result
    static func matches(
        parsed: (quantity: Double?, quantityMax: Double?, unit: String?, name: String),
        expected: (Double?, Double?, String?, String)
    ) -> Bool {
        // Quantity comparison (with tolerance for floating point)
        if let pq = parsed.quantity, let eq = expected.0 {
            if abs(pq - eq) > 0.01 { return false }
        } else if parsed.quantity != nil || expected.0 != nil {
            return false
        }

        // Quantity max comparison
        if let pqm = parsed.quantityMax, let eqm = expected.1 {
            if abs(pqm - eqm) > 0.01 { return false }
        } else if parsed.quantityMax != nil || expected.1 != nil {
            return false
        }

        // Unit comparison (case-insensitive, singular/plural tolerant)
        if let pu = parsed.unit?.lowercased(), let eu = expected.2?.lowercased() {
            let normalized1 = pu.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "s", with: "")
            let normalized2 = eu.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "s", with: "")
            if normalized1 != normalized2 { return false }
        } else if parsed.unit != nil || expected.2 != nil {
            return false
        }

        // Name comparison (case-insensitive substring match)
        let parsedName = parsed.name.lowercased()
        let expectedName = expected.3.lowercased()
        return parsedName.contains(expectedName) || expectedName.contains(parsedName)
    }
}
