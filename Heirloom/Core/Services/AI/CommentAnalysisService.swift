import Foundation

/// Service for AI-powered comment analysis using Claude API
/// Extracts sentiment, topics, and structured data from recipe comments
@MainActor
final class CommentAnalysisService {
    static let shared = CommentAnalysisService()
    private init() {}

    // MARK: - Configuration

    private let apiKey: String = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    private let apiEndpoint = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-haiku-20240307" // Fast and affordable

    // MARK: - Comment Analysis

    /// Analyze a single comment for sentiment, topics, and classification
    func analyzeComment(_ comment: RecipeComment) async throws -> CommentAnalysis {
        let prompt = buildAnalysisPrompt(for: comment.text)

        let response = try await callClaude(with: prompt)
        return try parseAnalysisResponse(response, originalComment: comment.text)
    }

    /// Batch analyze multiple comments
    func analyzeComments(_ comments: [RecipeComment]) async throws -> [CommentAnalysis] {
        var results: [CommentAnalysis] = []

        for comment in comments {
            do {
                let analysis = try await analyzeComment(comment)
                results.append(analysis)
            } catch {
                Log.warning("Failed to analyze comment", category: .general, metadata: ["commentId": comment.id.uuidString, "error": error.localizedDescription])
                // Continue with other comments
            }
        }

        return results
    }

    /// Extract insights from a collection of comments
    /// Finds common themes, popular modifications, and helpful tips
    func extractInsights(from comments: [RecipeComment]) async throws -> RecipeInsights {
        let commentTexts = comments.map { $0.text }.joined(separator: "\n---\n")
        let prompt = buildInsightsPrompt(for: commentTexts)

        let response = try await callClaude(with: prompt)
        return try parseInsightsResponse(response)
    }

    // MARK: - Prompt Building

    private func buildAnalysisPrompt(for commentText: String) -> String {
        """
        Analyze this recipe comment and provide structured analysis:

        Comment: "\(commentText)"

        Provide your analysis in JSON format with these fields:
        {
          "sentiment": <number between -1 and 1, where -1 is very negative, 0 is neutral, 1 is very positive>,
          "confidence": <number between 0 and 1 indicating confidence in analysis>,
          "commentType": "<one of: general, tip, modification, timing, technique, substitution, scaling, storage, pairing, warning, question, review>",
          "topics": ["<array of 1-5 relevant topics like 'texture', 'flavor', 'timing'>"],
          "structuredData": {
            "originalIngredient": "<if mentioned, the original ingredient>",
            "replacementIngredient": "<if mentioned, the suggested replacement>",
            "originalTiming": "<if mentioned, the original timing>",
            "adjustedTiming": "<if mentioned, the suggested timing>",
            "successRating": <1-5 if a rating is implied>
          }
        }

        Focus on extracting actionable information. Return ONLY the JSON, no other text.
        """
    }

    private func buildInsightsPrompt(for commentTexts: String) -> String {
        """
        Analyze these recipe comments and extract key insights:

        Comments:
        \(commentTexts)

        Provide insights in JSON format:
        {
          "commonThemes": ["<array of 3-5 recurring themes>"],
          "popularModifications": [
            {
              "modification": "<description>",
              "frequency": <number of mentions>,
              "sentiment": <-1 to 1>
            }
          ],
          "topTips": [
            {
              "tip": "<helpful tip>",
              "confidence": <0 to 1>
            }
          ],
          "warnings": ["<array of any warnings or cautions>"],
          "overallSentiment": <-1 to 1>,
          "successRate": <percentage if inferable from comments>
        }

        Return ONLY the JSON, no other text.
        """
    }

    // MARK: - API Communication

    private func callClaude(with prompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw CommentAnalysisError.missingAPIKey
        }

        let url = URL(string: apiEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CommentAnalysisError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw CommentAnalysisError.apiError(statusCode: httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw CommentAnalysisError.invalidResponse
        }

        return text
    }

    // MARK: - Response Parsing

    private func parseAnalysisResponse(
        _ response: String,
        originalComment: String
    ) throws -> CommentAnalysis {
        guard let data = response.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CommentAnalysisError.invalidJSON
        }

        let sentiment = json["sentiment"] as? Double ?? 0.0
        let confidence = json["confidence"] as? Double ?? 0.0
        let commentTypeString = json["commentType"] as? String ?? "general"
        let commentType = CommentType(rawValue: commentTypeString) ?? .general
        let topics = json["topics"] as? [String] ?? []

        var structuredData: CommentStructuredData? = nil
        if let structuredDict = json["structuredData"] as? [String: Any] {
            structuredData = CommentStructuredData(
                originalIngredient: structuredDict["originalIngredient"] as? String,
                replacementIngredient: structuredDict["replacementIngredient"] as? String,
                originalTiming: structuredDict["originalTiming"] as? String,
                adjustedTiming: structuredDict["adjustedTiming"] as? String,
                temperatureAdjustment: structuredDict["temperatureAdjustment"] as? String,
                servingContext: structuredDict["servingContext"] as? String,
                successRating: structuredDict["successRating"] as? Int
            )
        }

        return CommentAnalysis(
            commentText: originalComment,
            sentiment: sentiment,
            confidence: confidence,
            commentType: commentType,
            topics: topics,
            structuredData: structuredData
        )
    }

    private func parseInsightsResponse(_ response: String) throws -> RecipeInsights {
        guard let data = response.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CommentAnalysisError.invalidJSON
        }

        let commonThemes = json["commonThemes"] as? [String] ?? []
        let warnings = json["warnings"] as? [String] ?? []
        let overallSentiment = json["overallSentiment"] as? Double ?? 0.0
        let successRate = json["successRate"] as? Double

        // Parse modifications
        var modifications: [PopularModification] = []
        if let modsArray = json["popularModifications"] as? [[String: Any]] {
            for modDict in modsArray {
                if let description = modDict["modification"] as? String {
                    let modification = PopularModification(
                        description: description,
                        frequency: modDict["frequency"] as? Int ?? 1,
                        sentiment: modDict["sentiment"] as? Double ?? 0.0
                    )
                    modifications.append(modification)
                }
            }
        }

        // Parse tips
        var tips: [RecipeTip] = []
        if let tipsArray = json["topTips"] as? [[String: Any]] {
            for tipDict in tipsArray {
                if let tipText = tipDict["tip"] as? String {
                    let tip = RecipeTip(
                        text: tipText,
                        confidence: tipDict["confidence"] as? Double ?? 0.0
                    )
                    tips.append(tip)
                }
            }
        }

        return RecipeInsights(
            commonThemes: commonThemes,
            popularModifications: modifications,
            topTips: tips,
            warnings: warnings,
            overallSentiment: overallSentiment,
            successRate: successRate
        )
    }
}

// MARK: - Supporting Types

struct CommentAnalysis {
    let commentText: String
    let sentiment: Double               // -1.0 to 1.0
    let confidence: Double              // 0.0 to 1.0
    let commentType: CommentType
    let topics: [String]
    let structuredData: CommentStructuredData?

    var isPositive: Bool { sentiment > 0.2 }
    var isNegative: Bool { sentiment < -0.2 }
    var isHighConfidence: Bool { confidence > 0.75 }
}

struct RecipeInsights {
    let commonThemes: [String]
    let popularModifications: [PopularModification]
    let topTips: [RecipeTip]
    let warnings: [String]
    let overallSentiment: Double
    let successRate: Double?

    var isGenerallyPositive: Bool {
        overallSentiment > 0.2
    }

    var hasWarnings: Bool {
        !warnings.isEmpty
    }

    var topModification: PopularModification? {
        popularModifications.max { $0.frequency < $1.frequency }
    }

    var mostPopularTheme: String? {
        commonThemes.first
    }
}

struct PopularModification {
    let description: String
    let frequency: Int
    let sentiment: Double
}

struct RecipeTip {
    let text: String
    let confidence: Double
}

// MARK: - Errors

enum CommentAnalysisError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int)
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key not configured"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let code):
            return "API error: HTTP \(code)"
        case .invalidJSON:
            return "Failed to parse response JSON"
        }
    }
}

// MARK: - Testing Helper

#if DEBUG
extension CommentAnalysisService {
    /// Mock analysis for testing without API calls
    static func mockAnalysis(for commentText: String) -> CommentAnalysis {
        CommentAnalysis(
            commentText: commentText,
            sentiment: 0.75,
            confidence: 0.85,
            commentType: .modification,
            topics: ["flavor", "texture", "garlic"],
            structuredData: CommentStructuredData(
                originalIngredient: "garlic",
                replacementIngredient: nil,
                originalTiming: nil,
                adjustedTiming: nil,
                temperatureAdjustment: nil,
                servingContext: nil,
                successRating: 5
            )
        )
    }
}
#endif
