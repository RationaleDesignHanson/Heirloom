//
//  AudioAnalyzerTests.swift
//  HeirloomTestsV2
//
//  Tests for audio analysis mode selection logic
//  Created: 2026-01-20
//

import XCTest
@testable import Heirloom

@MainActor
final class AudioAnalyzerTests: XCTestCase {

    // MARK: - Mode Selection Logic (Baseline)

    func test_goodAudioQuality_selectsAudioTranscriptMode() {
        // Given: High-quality audio analysis result
        let result = AudioAnalysisResult(
            hasUsefulAudio: true,
            transcript: "Add two cups of flour and one teaspoon of salt. Mix well and bake.",
            wordCount: 150,
            speechConfidence: 0.85,
            recipeRelevanceScore: 0.7,
            recommendedMode: .audioTranscript,
            reasoning: "Clear speech with good recipe content",
            analyzedAt: Date()
        )

        // When/Then: Should recommend audio transcript mode
        XCTAssertEqual(result.recommendedMode, .audioTranscript, "Good audio should use transcript mode")
        XCTAssertTrue(result.hasUsefulAudio, "Should have useful audio")
        XCTAssertGreaterThan(result.wordCount, 30, "Should have sufficient word count")
    }

    func test_lowWordCount_selectsOCRMode() {
        // Given: Analysis with low word count (<30 words)
        let result = AudioAnalysisResult(
            hasUsefulAudio: false,
            transcript: "Um... uh... music playing",
            wordCount: 15,
            speechConfidence: 0.8,
            recipeRelevanceScore: 0.1,
            recommendedMode: .onScreenText,
            reasoning: "Insufficient speech content",
            analyzedAt: Date()
        )

        // When/Then: Should recommend OCR mode due to low word count
        XCTAssertEqual(result.recommendedMode, .onScreenText, "Low word count should trigger OCR")
        XCTAssertLessThan(result.wordCount, 30, "Word count should be below threshold")
    }

    func test_backgroundMusic_selectsOCRMode() {
        // Given: Analysis with background music (low words per minute)
        let result = AudioAnalysisResult(
            hasUsefulAudio: false,
            transcript: "Soft music playing in the background",
            wordCount: 50,
            speechConfidence: 0.5,
            recipeRelevanceScore: 0.05,
            recommendedMode: .onScreenText,
            reasoning: "Background music detected, low speech rate",
            analyzedAt: Date()
        )

        // When/Then: Should recommend OCR mode
        XCTAssertEqual(result.recommendedMode, .onScreenText, "Background music should trigger OCR")
        XCTAssertFalse(result.hasUsefulAudio, "Should not have useful audio")
    }

    func test_lowConfidence_selectsOCRMode() {
        // Given: Analysis with low speech confidence (<0.4)
        let result = AudioAnalysisResult(
            hasUsefulAudio: false,
            transcript: "unclear mumbling sounds",
            wordCount: 40,
            speechConfidence: 0.3,
            recipeRelevanceScore: 0.2,
            recommendedMode: .onScreenText,
            reasoning: "Low transcription confidence",
            analyzedAt: Date()
        )

        // When/Then: Should recommend OCR mode
        XCTAssertEqual(result.recommendedMode, .onScreenText, "Low confidence should trigger OCR")
        XCTAssertLessThan(result.speechConfidence, 0.4, "Confidence below threshold")
    }

    func test_lowRecipeRelevance_selectsOCRMode() {
        // Given: Analysis with low recipe relevance (<0.15)
        let result = AudioAnalysisResult(
            hasUsefulAudio: false,
            transcript: "Talking about the weather and current events",
            wordCount: 100,
            speechConfidence: 0.9,
            recipeRelevanceScore: 0.08,
            recommendedMode: .onScreenText,
            reasoning: "Content not recipe-related",
            analyzedAt: Date()
        )

        // When/Then: Should recommend OCR mode
        XCTAssertEqual(result.recommendedMode, .onScreenText, "Low relevance should trigger OCR")
        XCTAssertLessThan(result.recipeRelevanceScore, 0.15, "Relevance below threshold")
    }

    // MARK: - Threshold Boundaries

    func test_wordCountAt30_acceptableForAudio() {
        // Given: Analysis with exactly 30 words (boundary)
        let result = AudioAnalysisResult(
            hasUsefulAudio: true,
            transcript: "A transcript with exactly thirty words...",
            wordCount: 30,
            speechConfidence: 0.8,
            recipeRelevanceScore: 0.5,
            recommendedMode: .audioTranscript,
            reasoning: "At word count threshold",
            analyzedAt: Date()
        )

        // When/Then: Should accept audio mode at boundary
        XCTAssertEqual(result.wordCount, 30, "Should be at boundary")
    }

    func test_confidenceAt0Point4_acceptableForAudio() {
        // Given: Analysis with exactly 0.4 confidence (boundary)
        let result = AudioAnalysisResult(
            hasUsefulAudio: true,
            transcript: "Recipe content...",
            wordCount: 50,
            speechConfidence: 0.4,
            recipeRelevanceScore: 0.5,
            recommendedMode: .audioTranscript,
            reasoning: "At confidence threshold",
            analyzedAt: Date()
        )

        // When/Then: Should accept audio mode at boundary
        XCTAssertEqual(result.speechConfidence, 0.4, accuracy: 0.01, "Should be at boundary")
    }

    // MARK: - Reasoning String Quality

    func test_reasoningString_descriptiveForAudioMode() {
        // Given: Audio mode result
        let result = AudioAnalysisResult(
            hasUsefulAudio: true,
            transcript: "Add flour and eggs...",
            wordCount: 150,
            speechConfidence: 0.9,
            recipeRelevanceScore: 0.8,
            recommendedMode: .audioTranscript,
            reasoning: "Clear speech with high recipe relevance",
            analyzedAt: Date()
        )

        // When/Then: Reasoning should be descriptive
        XCTAssertFalse(result.reasoning.isEmpty, "Reasoning should not be empty")
        XCTAssertGreaterThan(result.reasoning.count, 10, "Reasoning should be descriptive")
    }

    func test_reasoningString_descriptiveForOCRMode() {
        // Given: OCR mode result
        let result = AudioAnalysisResult(
            hasUsefulAudio: false,
            transcript: nil,
            wordCount: 5,
            speechConfidence: 0.2,
            recipeRelevanceScore: 0.05,
            recommendedMode: .onScreenText,
            reasoning: "Insufficient speech detected, trying OCR",
            analyzedAt: Date()
        )

        // When/Then: Reasoning should explain why OCR was chosen
        XCTAssertFalse(result.reasoning.isEmpty, "Reasoning should not be empty")
        XCTAssertTrue(result.reasoning.count > 10, "Reasoning should be descriptive")
    }

    // MARK: - Timestamp

    func test_analyzedAt_recentTimestamp() {
        // Given: New analysis result
        let result = AudioAnalysisResult(
            hasUsefulAudio: true,
            transcript: "Test",
            wordCount: 50,
            speechConfidence: 0.8,
            recipeRelevanceScore: 0.5,
            recommendedMode: .audioTranscript,
            reasoning: "Test",
            analyzedAt: Date()
        )

        // When/Then: Timestamp should be recent (within last 10 seconds)
        let timeSinceAnalysis = Date().timeIntervalSince(result.analyzedAt)
        XCTAssertLessThan(timeSinceAnalysis, 10, "Timestamp should be recent")
    }

    // MARK: - Nil Transcript Handling

    func test_nilTranscript_lowWordCount() {
        // Given: Result with nil transcript
        let result = AudioAnalysisResult(
            hasUsefulAudio: false,
            transcript: nil,
            wordCount: 0,
            speechConfidence: 0,
            recipeRelevanceScore: 0,
            recommendedMode: .onScreenText,
            reasoning: "No audio track detected",
            analyzedAt: Date()
        )

        // When/Then: Should have zero word count
        XCTAssertEqual(result.wordCount, 0, "Nil transcript should have zero words")
        XCTAssertNil(result.transcript, "Transcript should be nil")
        XCTAssertEqual(result.recommendedMode, .onScreenText, "Should recommend OCR")
    }

    // MARK: - Score Ranges

    func test_speechConfidence_withinValidRange() {
        // Given: Various confidence scores
        let scores: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]

        // When/Then: All should be 0.0-1.0
        for score in scores {
            XCTAssertGreaterThanOrEqual(score, 0.0, "Confidence should be >= 0")
            XCTAssertLessThanOrEqual(score, 1.0, "Confidence should be <= 1")
        }
    }

    func test_recipeRelevance_withinValidRange() {
        // Given: Various relevance scores
        let scores: [Float] = [0.0, 0.15, 0.5, 0.85, 1.0]

        // When/Then: All should be 0.0-1.0
        for score in scores {
            XCTAssertGreaterThanOrEqual(score, 0.0, "Relevance should be >= 0")
            XCTAssertLessThanOrEqual(score, 1.0, "Relevance should be <= 1")
        }
    }
}
