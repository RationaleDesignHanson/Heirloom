import Foundation

/// Cloud-based recipe import service using Firebase Cloud Functions
/// Provides more accurate parsing with fallback to local parser
@MainActor
class CloudRecipeImportService {
    private let importService: RecipeImportService
    private let languageService: LanguageDetectionService

    init(importService: RecipeImportService, languageService: LanguageDetectionService) {
        self.importService = importService
        self.languageService = languageService
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

    /// Convert ExtractedRecipe to Recipe model with multilingual support
    /// - Parameters:
    ///   - extracted: Extracted recipe from import
    ///   - sourceURL: Original URL
    /// - Returns: Recipe ready to save
    func toRecipe(_ extracted: ExtractedRecipe, sourceURL: String) async -> Recipe {
        // 1. Detect language
        let recipeText = "\(extracted.title) \(extracted.ingredients.joined(separator: " "))"
        let domain = URL(string: sourceURL)?.host

        var detectedLanguage: String = "en"
        var detectedUnitSystem: String? = nil
        var needsTranslation = false

        do {
            let detection = try await languageService.detectLanguage(
                text: recipeText,
                url: sourceURL,
                domain: domain
            )
            detectedLanguage = detection.language
            detectedUnitSystem = detection.detectedUnitSystem
            needsTranslation = detection.needsTranslation

            Log.info("Language detected", category: .network, metadata: [
                "language": detection.language,
                "confidence": detection.confidence,
                "needsTranslation": needsTranslation
            ])
        } catch {
            Log.warning("Language detection failed, defaulting to English",
                        category: .network,
                        metadata: ["error": error.localizedDescription])
        }

        // 2. Translate if needed
        var translatedTitle = extracted.title
        var translatedIngredients = extracted.ingredients
        var translatedInstructions = extracted.instructions
        var translatedNotes = extracted.description

        if needsTranslation {
            do {
                // Translate title
                let titleTranslation = try await languageService.translateText(
                    extracted.title,
                    from: detectedLanguage,
                    to: "en",
                    context: .title
                )
                translatedTitle = titleTranslation.translatedText

                // Translate ingredients (batch)
                let ingredientTranslations = try await languageService.batchTranslate(
                    extracted.ingredients,
                    from: detectedLanguage,
                    to: "en",
                    context: .ingredient
                )
                translatedIngredients = ingredientTranslations.map { $0.translatedText }

                // Translate instructions
                let instructionTranslations = try await languageService.batchTranslate(
                    extracted.instructions,
                    from: detectedLanguage,
                    to: "en",
                    context: .instruction
                )
                translatedInstructions = instructionTranslations.map { $0.translatedText }

                // Translate notes if present
                if let notes = extracted.description {
                    let notesTranslation = try await languageService.translateText(
                        notes,
                        from: detectedLanguage,
                        to: "en",
                        context: .note
                    )
                    translatedNotes = notesTranslation.translatedText
                }

                Log.info("Recipe translated successfully", category: .network, metadata: [
                    "ingredientCount": translatedIngredients.count,
                    "instructionCount": translatedInstructions.count
                ])
            } catch {
                Log.error("Translation failed, using original text",
                          category: .network,
                          metadata: ["error": error.localizedDescription])
                // Fall back to untranslated text
            }
        }

        // 3. Create Recipe with translated content
        let recipe = Recipe(
            title: translatedTitle,
            sourceType: .url,
            sourceURL: sourceURL,
            instructions: translatedInstructions,
            servings: extracted.servings,
            prepTime: extracted.prepTime,
            cookTime: extracted.cookTime
        )

        // 4. Set language metadata (SchemaV2 fields)
        recipe.sourceLanguage = detectedLanguage
        if needsTranslation {
            recipe.originalTitle = extracted.title
            recipe.originalInstructions = extracted.instructions
            recipe.translatedTitle = translatedTitle
            recipe.translatedInstructions = translatedInstructions
        }
        recipe.detectedUnitSystem = detectedUnitSystem

        // 5. Set provenance
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceURL: sourceURL,
            sourceAttribution: extracted.author,
            generation: 0
        )

        // 6. Set translated notes
        recipe.notes = translatedNotes

        // 7. Parse ingredients with language-aware parsing and unit conversion
        var parsedIngredients: [Ingredient] = []

        for (index, originalText) in extracted.ingredients.enumerated() {
            let translatedText = translatedIngredients[index]

            // Parse with original language for accurate unit detection
            let (qty, qtyMax, unit, name) = IngredientParser.parse(
                originalText,
                language: detectedLanguage
            )

            // Apply unit conversion if needed
            var adjustedQty = qty
            var conversionNote: String? = nil

            if let quantity = qty, let unitName = unit, detectedLanguage != "en" {
                adjustedQty = UnitConversionService.adjustQuantity(
                    quantity,
                    unit: unitName,
                    sourceLanguage: detectedLanguage,
                    originalUnit: unit  // Pass original for Korean traditional units
                )

                // Record conversion if quantity changed
                if abs(adjustedQty! - quantity) > 0.001 {
                    conversionNote = UnitConversionService.conversionInfo(
                        for: unitName,
                        sourceLanguage: detectedLanguage
                    )
                    Log.debug("Unit converted", category: .network, metadata: [
                        "original": quantity,
                        "adjusted": adjustedQty!,
                        "unit": unitName,
                        "language": detectedLanguage
                    ])
                }
            }

            let ingredient = Ingredient(
                originalText: translatedText,  // Use translated text for display
                name: name,
                quantity: adjustedQty,
                unit: unit,
                orderIndex: index
            )
            ingredient.quantityMax = qtyMax

            // Set SchemaV2 metadata fields
            if needsTranslation {
                ingredient.originalLanguageName = extracted.ingredients[index]
                ingredient.translatedName = translatedText
            }
            if conversionNote != nil {
                ingredient.wasConverted = true
                ingredient.conversionNote = conversionNote
            }

            parsedIngredients.append(ingredient)
        }

        // Add ingredients to recipe
        recipe.ingredients = parsedIngredients

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
