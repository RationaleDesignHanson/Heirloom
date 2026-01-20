import Foundation

/// Result of audio analysis for mode selection
struct AudioAnalysisResult: Codable {
    let hasUsefulAudio: Bool
    let transcript: String?
    let wordCount: Int
    let speechConfidence: Float      // 0-1
    let recipeRelevanceScore: Float  // 0-1
    let recommendedMode: ExtractionMode
    let reasoning: String
    let analyzedAt: Date

    init(hasUsefulAudio: Bool,
         transcript: String? = nil,
         wordCount: Int = 0,
         speechConfidence: Float = 0,
         recipeRelevanceScore: Float = 0,
         recommendedMode: ExtractionMode,
         reasoning: String) {
        self.hasUsefulAudio = hasUsefulAudio
        self.transcript = transcript
        self.wordCount = wordCount
        self.speechConfidence = speechConfidence
        self.recipeRelevanceScore = recipeRelevanceScore
        self.recommendedMode = recommendedMode
        self.reasoning = reasoning
        self.analyzedAt = Date()
    }
}
