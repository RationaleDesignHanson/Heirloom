import Foundation

/// Language detection and translation service using Firebase Cloud Functions + Claude API
/// Supports 7 languages: English, French, Spanish, German, Japanese, Chinese, Korean
@MainActor
class LanguageDetectionService {

    // MARK: - Configuration

    // Cloud Function URLs (deployed to Cloud Run - update after deployment)
    private let baseURL = "https://detectlanguage-7kk7et3yua-uc.a.run.app"
    private var detectLanguageURL: URL {
        URL(string: "\(baseURL)/detectLanguage")!
    }
    private var translateTextURL: URL {
        URL(string: "\(baseURL.replacingOccurrences(of: "detectlanguage", with: "translatetext"))/translateText")!
    }

    // MARK: - Public API

    /// Detect language of recipe text
    /// - Parameters:
    ///   - text: Recipe text to analyze (title + ingredients + instructions combined)
    ///   - url: Optional source URL for additional context
    ///   - domain: Optional domain for regional hints
    /// - Returns: Language detection response with ISO code and confidence
    func detectLanguage(
        text: String,
        url: String? = nil,
        domain: String? = nil
    ) async throws -> LanguageDetectionResponse {
        Log.info("Detecting language for recipe text", category: .network, metadata: [
            "textLength": text.count,
            "url": url ?? "none",
            "domain": domain ?? "none"
        ])

        // Create request
        var request = URLRequest(url: detectLanguageURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Prepare request body
        var body: [String: Any] = ["text": text]
        if let url = url, let domain = domain {
            body["hints"] = [
                "url": url,
                "domain": domain
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LanguageServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.error("Language detection failed", category: .network, metadata: [
                "statusCode": httpResponse.statusCode,
                "error": errorMessage
            ])
            throw LanguageServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Decode response
        let decoder = JSONDecoder()
        let detectionResponse = try decoder.decode(LanguageDetectionResponse.self, from: data)

        Log.info("Language detected", category: .network, metadata: [
            "language": detectionResponse.language,
            "languageName": detectionResponse.languageName,
            "confidence": detectionResponse.confidence,
            "unitSystem": detectionResponse.detectedUnitSystem ?? "none",
            "needsTranslation": detectionResponse.needsTranslation
        ])

        return detectionResponse
    }

    /// Translate recipe text from source language to target language
    /// - Parameters:
    ///   - text: Text to translate
    ///   - sourceLanguage: ISO 639-1 source language code (e.g., "fr")
    ///   - targetLanguage: ISO 639-1 target language code (defaults to "en")
    ///   - context: Type of text for better translation (title, ingredient, instruction, note)
    /// - Returns: Translation response with translated text and confidence
    func translateText(
        _ text: String,
        from sourceLanguage: String,
        to targetLanguage: String = "en",
        context: TranslationContext? = nil
    ) async throws -> TranslationResponse {
        Log.info("Translating recipe text", category: .network, metadata: [
            "textLength": text.count,
            "sourceLanguage": sourceLanguage,
            "targetLanguage": targetLanguage,
            "context": context?.rawValue ?? "none"
        ])

        // Create request
        var request = URLRequest(url: translateTextURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Prepare request body
        var body: [String: Any] = [
            "text": text,
            "sourceLanguage": sourceLanguage,
            "targetLanguage": targetLanguage
        ]
        if let context = context {
            body["context"] = context.rawValue
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LanguageServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.error("Translation failed", category: .network, metadata: [
                "statusCode": httpResponse.statusCode,
                "error": errorMessage
            ])
            throw LanguageServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Decode response
        let decoder = JSONDecoder()
        let translationResponse = try decoder.decode(TranslationResponse.self, from: data)

        Log.info("Translation completed", category: .network, metadata: [
            "translatedLength": translationResponse.translatedText.count,
            "confidence": translationResponse.confidence,
            "engine": translationResponse.engine
        ])

        return translationResponse
    }

    /// Batch translate multiple texts (e.g., all ingredients at once)
    /// - Parameters:
    ///   - texts: Array of texts to translate
    ///   - sourceLanguage: Source language code
    ///   - targetLanguage: Target language code
    ///   - context: Translation context
    /// - Returns: Array of translation responses
    func batchTranslate(
        _ texts: [String],
        from sourceLanguage: String,
        to targetLanguage: String = "en",
        context: TranslationContext? = nil
    ) async throws -> [TranslationResponse] {
        Log.info("Batch translating texts", category: .network, metadata: [
            "count": texts.count,
            "sourceLanguage": sourceLanguage,
            "targetLanguage": targetLanguage
        ])

        // Translate in parallel with task groups
        return try await withThrowingTaskGroup(of: (Int, TranslationResponse).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask {
                    let response = try await self.translateText(
                        text,
                        from: sourceLanguage,
                        to: targetLanguage,
                        context: context
                    )
                    return (index, response)
                }
            }

            // Collect results and sort by original index
            var results: [(Int, TranslationResponse)] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }
}

// MARK: - Response Models

/// Response from language detection endpoint
struct LanguageDetectionResponse: Codable {
    let language: String              // ISO 639-1 code (e.g., "fr")
    let confidence: Double            // 0-1 confidence score
    let languageName: String          // Human-readable name (e.g., "French")
    let detectedUnitSystem: String?   // "metric", "imperial", or "mixed"
    let needsTranslation: Bool        // True if not English
}

/// Response from translation endpoint
struct TranslationResponse: Codable {
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let confidence: Double            // 0-1 translation confidence
    let engine: String                // "claude" or "fallback"
}

/// Translation context for better accuracy
enum TranslationContext: String, Codable {
    case title
    case ingredient
    case instruction
    case note
}

// MARK: - Errors

enum LanguageServiceError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from language service"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Language Utilities

extension LanguageDetectionService {
    /// Map of ISO 639-1 codes to human-readable names
    static let languageNames: [String: String] = [
        "en": "English",
        "fr": "French",
        "es": "Spanish",
        "de": "German",
        "ja": "Japanese",
        "zh": "Chinese",
        "ko": "Korean"
    ]

    /// Check if a language code is supported
    static func isSupported(_ languageCode: String) -> Bool {
        return languageNames.keys.contains(languageCode)
    }

    /// Get human-readable name for language code
    static func languageName(for code: String) -> String? {
        return languageNames[code]
    }
}
