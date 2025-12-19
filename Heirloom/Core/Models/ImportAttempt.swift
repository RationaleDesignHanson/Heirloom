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
            instructions: recipe.instructions
        )
    }
}
