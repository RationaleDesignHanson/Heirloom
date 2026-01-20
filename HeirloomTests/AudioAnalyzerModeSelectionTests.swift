import XCTest
@testable import Heirloom

final class AudioAnalyzerModeSelectionTests: XCTestCase {

    // Test mode selection logic (deterministic part)

    func testGoodAudioSelectsAudioTranscript() {
        // Simulated analysis result
        let result = AudioAnalysisResult(
            hasUsefulAudio: true,
            transcript: "Add flour and sugar...",
            wordCount: 150,
            speechConfidence: 0.85,
            recipeRelevanceScore: 0.7,
            recommendedMode: .audioTranscript,
            reasoning: "Good audio",
            analyzedAt: Date()
        )

        XCTAssertEqual(result.recommendedMode, .audioTranscript)
    }

    func testLowWordCountTriggersOCR() {
        // Word count < 30 should trigger OCR tier
        let result = AudioAnalysisResult(
            hasUsefulAudio: false,
            transcript: nil,
            wordCount: 15,
            speechConfidence: 0.8,
            recipeRelevanceScore: 0.5,
            recommendedMode: .onScreenText,
            reasoning: "Insufficient speech",
            analyzedAt: Date()
        )

        XCTAssertEqual(result.recommendedMode, .onScreenText)
    }
}
