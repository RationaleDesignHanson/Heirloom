import Foundation

/// Result of on-screen text detection (middle tier)
struct OnScreenTextResult: Codable {
    let hasRecipeText: Bool
    let detectedText: String?
    let recipeRelevanceScore: Float  // 0-1
    let confidence: Float            // 0-1
    let frameCount: Int              // Number of frames analyzed
    let reasoning: String
}
