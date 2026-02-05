import Foundation

/// Import attempt model matching Firestore schema
/// Tracks recipe import success/failure for analytics
struct ImportAttempt: Codable, Identifiable {
    let id: String
    let url: String
    let domain: String
    let timestamp: Date
    let userId: String?
    let status: ImportStatus
    let extracted: ExtractedRecipe?
    let parserUsed: ParserType
    let confidence: Double
    let errors: [ServerImportError]?
    let parseTimeMs: Int

    enum ImportStatus: String, Codable {
        case success
        case partial
        case failed
    }

    enum ParserType: String, Codable {
        case schemaOrg
        case heuristic
        case none
    }
}

/// Extracted recipe data from import
struct ExtractedRecipe: Codable {
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let totalTime: String?
    let imageUrl: String?
    let rating: Double?
    let ratingCount: Int?
    let description: String?
    let author: String?
    let category: String?
    let cuisine: String?
    let keywords: [String]?

    // Custom initializer with default values for optional parameters
    init(
        title: String,
        ingredients: [String],
        instructions: [String],
        servings: String? = nil,
        prepTime: String? = nil,
        cookTime: String? = nil,
        totalTime: String? = nil,
        imageUrl: String? = nil,
        rating: Double? = nil,
        ratingCount: Int? = nil,
        description: String? = nil,
        author: String? = nil,
        category: String? = nil,
        cuisine: String? = nil,
        keywords: [String]? = nil
    ) {
        self.title = title
        self.ingredients = ingredients
        self.instructions = instructions
        self.servings = servings
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.imageUrl = imageUrl
        self.rating = rating
        self.ratingCount = ratingCount
        self.description = description
        self.author = author
        self.category = category
        self.cuisine = cuisine
        self.keywords = keywords
    }
}

/// Import error from server (renamed to avoid conflict with local ImportError and CloudImportError)
struct ServerImportError: Codable {
    let type: ErrorType
    let message: String
    let field: String?

    enum ErrorType: String, Codable {
        case network
        case parsing
        case validation
        case timeout
        case unsupported
    }
}

/// Import response from Cloud Function
struct ImportResponse: Codable {
    let status: ImportAttempt.ImportStatus
    let importId: String
    let confidence: Double
    let recipe: ExtractedRecipe?
    let warnings: [String]?
    let errors: [ServerImportError]?
    let metadata: ImportMetadata
}

/// Import metadata
struct ImportMetadata: Codable {
    let parserUsed: ImportAttempt.ParserType
    let parseTimeMs: Int
    let hasSchemaOrg: Bool
    let needsFeedback: Bool
    let domain: String
    let sourceUrl: String
    let timestamp: Date
}

/// Feedback request to server
struct FeedbackRequest: Codable {
    let importId: String
    let userId: String?
    let wasAccurate: Bool
    let corrections: [Correction]?
    let rating: Int?
    let comment: String?

    struct Correction: Codable {
        let field: String
        let correctValue: String
    }
}

/// Feedback response from server
struct FeedbackResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Conversion Extensions

extension ImportResponse {
    /// Convert cloud import response to ImportedRecipe
    func toImportedRecipe() -> ImportedRecipe? {
        guard let recipe = self.recipe else { return nil }

        // Filter out comment-like instructions that may have been incorrectly parsed
        let filteredInstructions = recipe.instructions.filter { instruction in
            Self.looksLikeInstruction(instruction)
        }

        // If filtering removed most instructions (>80%), likely comments were mixed in
        // Fall back to original if we have very few filtered instructions
        let finalInstructions: [String]
        if filteredInstructions.count < 3 && recipe.instructions.count > 10 {
            // Too aggressive filtering - use original
            // (Likely the cloud parser returned mostly comments)
            finalInstructions = recipe.instructions
        } else if filteredInstructions.isEmpty && !recipe.instructions.isEmpty {
            // No instructions passed filter - use original
            finalInstructions = recipe.instructions
        } else {
            finalInstructions = filteredInstructions
        }

        return ImportedRecipe(
            title: recipe.title,
            description: recipe.description,
            imageURL: recipe.imageUrl,
            sourceURL: metadata.sourceUrl,
            author: recipe.author,
            servings: recipe.servings,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            ingredients: recipe.ingredients,
            instructions: finalInstructions
        )
    }

    /// Check if text looks like a recipe instruction (not a user comment)
    private static func looksLikeInstruction(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip very short text (likely not an instruction)
        guard trimmed.count > 10 else { return false }

        // Detect comment patterns (first-person narratives, reviews, personal anecdotes)
        let commentPatterns = [
            // Personal experiences and reviews
            "i love", "i loved", "i tried", "i made", "i recommend",
            "we love", "we loved", "we tried", "my favorite",
            "this is my go-to", "kaf is", "king arthur",
            "these are amazing", "these were amazing", "this is delicious",
            "thank you for", "thank you so much", "thanks for",
            "can't wait to", "just made this", "turned out great",
            "so good", "very delicious", "will make again",
            "my family loved", "my kids loved", "my husband loved",
            "great recipe", "amazing recipe", "wonderful recipe",
            // Comment metadata patterns
            "reply", "says:", "wrote:", "commented:",
            // Date patterns common in comments (e.g., "May 12, 2016")
            "january", "february", "march", "april", "may", "june",
            "july", "august", "september", "october", "november", "december",
            // Social patterns
            "i never thought", "i always", "growing up", "when i was",
            // Names followed by dates (common comment format)
        ]

        for pattern in commentPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }

        // Check for date patterns like "May 12, 2016" which indicate comments
        let datePattern = #"\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2},?\s+\d{4}\b"#
        if let _ = lowercased.range(of: datePattern, options: .regularExpression) {
            return false
        }

        // Check for time patterns like "at 12:21 pm" which indicate comments
        let timePattern = #"\bat\s+\d{1,2}:\d{2}\s*(am|pm)\b"#
        if let _ = lowercased.range(of: timePattern, options: .regularExpression) {
            return false
        }

        // Instruction-like patterns (imperative mood)
        let instructionPrefixes = [
            "preheat", "heat", "warm", "cool", "chill",
            "mix", "combine", "blend", "stir", "whisk", "beat", "fold",
            "add", "pour", "place", "put", "set", "arrange", "spread",
            "bake", "cook", "roast", "grill", "fry", "sauté", "boil", "simmer",
            "refrigerate", "freeze", "rest", "let sit", "let stand", "allow",
            "remove", "transfer", "drain", "strain", "sift",
            "cut", "chop", "slice", "dice", "mince", "julienne",
            "season", "sprinkle", "garnish", "top", "drizzle",
            "in a bowl", "in a pan", "in a pot", "in a skillet",
            "using a", "with a", "on a", "over", "into",
            "meanwhile", "next", "then", "finally", "first",
            "roll", "shape", "form", "flatten", "press",
            "cover", "wrap", "line", "grease", "butter"
        ]

        for prefix in instructionPrefixes {
            if lowercased.hasPrefix(prefix) || lowercased.contains(" \(prefix) ") {
                return true
            }
        }

        // Check for time/temperature measurements (strong indicator of instruction)
        let hasTimeOrTemp = lowercased.range(of: #"(\d+\s*(minute|hour|second|degree|°f|°c|fahrenheit|celsius))"#, options: .regularExpression) != nil

        return hasTimeOrTemp
    }
}
