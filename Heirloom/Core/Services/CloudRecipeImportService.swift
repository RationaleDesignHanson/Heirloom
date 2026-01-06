import Foundation

/// Cloud-based recipe import service using Firebase Cloud Functions
/// Provides more accurate parsing with fallback to local parser
@MainActor
class CloudRecipeImportService {
    private let importService: RecipeImportService

    init(importService: RecipeImportService) {
        self.importService = importService
    }

    // Cloud Function URLs (deployed to Cloud Run)
    private let baseURL = "https://importrecipe-7kk7et3yua-uc.a.run.app"
    private var importURL: URL {
        URL(string: baseURL)!
    }
    private var feedbackURL: URL {
        URL(string: "https://submitfeedback-7kk7et3yua-uc.a.run.app")!
    }

    /// Import recipe from URL using Cloud Function
    /// - Parameter url: Recipe URL to import
    /// - Returns: ImportResponse with parsed recipe data
    func importRecipe(from url: String, userId: String? = nil) async throws -> ImportResponse {
        Log.info("Starting cloud recipe import", category: .network, metadata: ["url": url])

        // Create request
        var request = URLRequest(url: importURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "url": url,
            "userId": userId ?? NSNull()
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudImportError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.error("Cloud import request failed", category: .network, metadata: ["statusCode": httpResponse.statusCode, "error": errorMessage])
            throw CloudImportError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Decode response with custom date strategy to handle fractional seconds
        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Create ISO8601 formatter with fractional seconds support
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            // Try with fractional seconds first
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Fallback formatter without fractional seconds
            let iso8601FormatterNoFractional = ISO8601DateFormatter()
            iso8601FormatterNoFractional.formatOptions = [.withInternetDateTime]

            if let date = iso8601FormatterNoFractional.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
        }

        let importResponse = try decoder.decode(ImportResponse.self, from: data)

        Log.info("Cloud import completed", category: .network, metadata: [
            "status": importResponse.status.rawValue,
            "importId": importResponse.importId,
            "confidence": importResponse.confidence * 100,
            "parser": importResponse.metadata.parserUsed.rawValue
        ])

        return importResponse
    }

    /// Import with fallback to local parser
    /// - Parameter url: Recipe URL to import
    /// - Returns: ImportResponse or throws if both fail
    func importWithFallback(from url: String, userId: String? = nil) async throws -> ImportResponse {
        do {
            // Try cloud import first
            return try await importRecipe(from: url, userId: userId)
        } catch {
            Log.warning("Cloud import failed, falling back to local parser", category: .network, metadata: ["error": error.localizedDescription])

            // Fall back to local parser
            do {
                let localRecipe = try await importService.importRecipe(from: url)

                // Convert to ImportResponse format
                return ImportResponse(
                    status: .success,
                    importId: "local-\(UUID().uuidString)",
                    confidence: 0.6, // Local parser has lower confidence
                    recipe: ExtractedRecipe(
                        title: localRecipe.title,
                        ingredients: localRecipe.ingredients,
                        instructions: localRecipe.instructions,
                        servings: localRecipe.servings,
                        prepTime: localRecipe.prepTime,
                        cookTime: localRecipe.cookTime,
                        totalTime: nil,
                        imageUrl: localRecipe.imageURL,
                        rating: nil,
                        ratingCount: nil,
                        description: nil,
                        author: nil,
                        category: nil,
                        cuisine: nil,
                        keywords: nil
                    ),
                    warnings: ["Imported using local parser (cloud service unavailable)"],
                    errors: nil,
                    metadata: ImportMetadata(
                        parserUsed: .heuristic,
                        parseTimeMs: 0,
                        hasSchemaOrg: false,
                        needsFeedback: true,
                        domain: URL(string: url)?.host ?? "unknown",
                        sourceUrl: url,
                        timestamp: Date()
                    )
                )
            } catch {
                Log.error("Local parser also failed after cloud import failure", category: .network, metadata: ["error": error.localizedDescription])
                throw error
            }
        }
    }

    /// Submit user feedback for import
    /// - Parameters:
    ///   - importId: Import attempt ID
    ///   - wasAccurate: Whether import was accurate
    ///   - corrections: Optional field corrections
    ///   - rating: Optional 1-5 star rating
    ///   - comment: Optional comment
    func submitFeedback(
        importId: String,
        userId: String? = nil,
        wasAccurate: Bool,
        corrections: [FeedbackRequest.Correction]? = nil,
        rating: Int? = nil,
        comment: String? = nil
    ) async throws {
        Log.info("Submitting import feedback", category: .network, metadata: ["importId": importId])

        var request = URLRequest(url: feedbackURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let feedback = FeedbackRequest(
            importId: importId,
            userId: userId,
            wasAccurate: wasAccurate,
            corrections: corrections,
            rating: rating,
            comment: comment
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(feedback)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudImportError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudImportError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        Log.info("Import feedback submitted successfully", category: .network)
    }

    /// Convert ExtractedRecipe to Recipe model
    /// - Parameters:
    ///   - extracted: Extracted recipe from import
    ///   - sourceURL: Original URL
    /// - Returns: Recipe ready to save
    func toRecipe(_ extracted: ExtractedRecipe, sourceURL: String) -> Recipe {
        let recipe = Recipe(
            title: extracted.title,
            sourceType: .url,
            sourceURL: sourceURL,
            instructions: extracted.instructions,
            servings: extracted.servings,
            prepTime: extracted.prepTime,
            cookTime: extracted.cookTime
        )

        // Set provenance
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceURL: sourceURL,
            sourceAttribution: extracted.author,
            generation: 0 // Imported recipes are generation 0
        )

        // Set description
        recipe.notes = extracted.description

        return recipe
    }
}

/// Cloud import errors
enum CloudImportError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
