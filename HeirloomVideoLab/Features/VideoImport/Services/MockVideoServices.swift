//
//  MockVideoServices.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Mock implementations for rapid UI development
//  These simulate the full video processing pipeline without real transcription

import Foundation
import AVFoundation
import UIKit
import Combine

// MARK: - Mock Audio Extractor

class MockAudioExtractionService: AudioExtractionServiceProtocol {
    func extractAudio(from videoURL: URL) async throws -> URL {
        // Simulate extraction delay
        try await Task.sleep(for: .seconds(2))

        // Return a fake audio URL (would be temp file in real implementation)
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("mock_audio.m4a")

        // Create empty file if it doesn't exist
        if !FileManager.default.fileExists(atPath: audioURL.path) {
            FileManager.default.createFile(atPath: audioURL.path, contents: nil)
        }

        return audioURL
    }

    func estimateDuration(_ videoURL: URL) async -> TimeInterval? {
        // Return mock duration
        return 180.0  // 3 minutes
    }
}

// MARK: - Mock Transcription Service

@MainActor
class MockTranscriptionService: TranscriptionServiceProtocol {
    let provider: TranscriptionProvider = .whisperKit
    let isAvailable: Bool = true

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        // Simulate transcription with progress updates
        // In real implementation, this would be WhisperKit processing

        try await Task.sleep(for: .seconds(3))

        let mockTranscript = """
        Today we're making chocolate chip cookies. You'll need two cups of all-purpose flour, one teaspoon of baking soda, one teaspoon of salt, one cup of softened butter, three quarters cup of granulated sugar, three quarters cup of packed brown sugar, one teaspoon of vanilla extract, two large eggs, and two cups of chocolate chips.

        First, preheat your oven to 375 degrees Fahrenheit. In a small bowl, combine the flour, baking soda, and salt. Set aside.

        In a large bowl, beat the softened butter with both sugars until creamy. This should take about two minutes. Add the vanilla and eggs, beating well.

        Gradually stir in the flour mixture until just combined. Don't overmix. Fold in the chocolate chips.

        Drop rounded tablespoons of dough onto ungreased baking sheets, spacing them about two inches apart.

        Bake for nine to eleven minutes, or until golden brown. The centers may look slightly underdone but they'll continue cooking on the sheet.

        Let cookies cool on the baking sheet for two minutes, then transfer to a wire rack. Makes about five dozen cookies. Enjoy!
        """

        let segments = [
            TranscriptSegment(text: "Today we're making chocolate chip cookies.", startTime: 0, endTime: 3),
            TranscriptSegment(text: "You'll need two cups of all-purpose flour...", startTime: 3, endTime: 15),
            TranscriptSegment(text: "First, preheat your oven to 375 degrees...", startTime: 15, endTime: 20),
            // ... more segments would be here
        ]

        return TranscriptionResult(
            text: mockTranscript,
            segments: segments,
            confidence: 0.87,
            provider: .whisperKit,
            language: "en"
        )
    }
}

// MARK: - Mock Frame Analysis Service

class MockFrameAnalysisService: FrameAnalysisServiceProtocol {
    func extractKeyFrames(from videoURL: URL, count: Int) async throws -> [UIImage] {
        // Simulate frame extraction
        try await Task.sleep(for: .seconds(1))

        // Return empty images (in real implementation, would extract from video)
        return []
    }

    func analyzeForRecipeElements(_ frames: [UIImage]) async throws -> [String] {
        // Simulate OCR detection
        try await Task.sleep(for: .seconds(1))

        // Return mock detected text
        return [
            "375°F",
            "9-11 minutes",
            "2 cups flour",
            "1 tsp salt"
        ]
    }
}

// MARK: - Mock Recipe Structurer

@MainActor
class MockRecipeStructurer: RecipeStructurerProtocol {
    func structure(
        transcript: TranscriptionResult,
        visualElements: [String]
    ) async throws -> StructuredRecipe {
        // Simulate AI processing
        try await Task.sleep(for: .seconds(2))

        // Return mock structured recipe
        let ingredients = [
            ExtractedIngredient(
                originalText: "two cups of all-purpose flour",
                item: "all-purpose flour",
                quantity: "2",
                unit: "cups",
                preparation: nil,
                confidence: .explicit
            ),
            ExtractedIngredient(
                originalText: "one teaspoon of baking soda",
                item: "baking soda",
                quantity: "1",
                unit: "teaspoon",
                preparation: nil,
                confidence: .explicit
            ),
            ExtractedIngredient(
                originalText: "one teaspoon of salt",
                item: "salt",
                quantity: "1",
                unit: "teaspoon",
                preparation: nil,
                confidence: .explicit
            ),
            ExtractedIngredient(
                originalText: "one cup of softened butter",
                item: "butter",
                quantity: "1",
                unit: "cup",
                preparation: "softened",
                confidence: .explicit
            ),
            ExtractedIngredient(
                originalText: "three quarters cup of granulated sugar",
                item: "granulated sugar",
                quantity: "3/4",
                unit: "cup",
                preparation: nil,
                confidence: .explicit
            ),
            ExtractedIngredient(
                originalText: "three quarters cup of packed brown sugar",
                item: "brown sugar",
                quantity: "3/4",
                unit: "cup",
                preparation: "packed",
                confidence: .explicit
            ),
            ExtractedIngredient(
                originalText: "one teaspoon of vanilla extract",
                item: "vanilla extract",
                quantity: "1",
                unit: "teaspoon",
                preparation: nil,
                confidence: .explicit
            ),
            ExtractedIngredient(
                originalText: "two large eggs",
                item: "eggs",
                quantity: "2",
                unit: nil,
                preparation: "large",
                confidence: .explicit
            ),
            ExtractedIngredient(
                originalText: "two cups of chocolate chips",
                item: "chocolate chips",
                quantity: "2",
                unit: "cups",
                preparation: nil,
                confidence: .explicit
            )
        ]

        let steps = [
            ExtractedStep(
                instruction: "Preheat oven to 375°F",
                duration: nil,
                temperature: "375°F",
                confidence: .explicit
            ),
            ExtractedStep(
                instruction: "In a small bowl, combine flour, baking soda, and salt. Set aside.",
                duration: nil,
                temperature: nil,
                confidence: .explicit
            ),
            ExtractedStep(
                instruction: "In a large bowl, beat softened butter with both sugars until creamy",
                duration: "2 minutes",
                temperature: nil,
                confidence: .explicit
            ),
            ExtractedStep(
                instruction: "Add vanilla and eggs, beating well",
                duration: nil,
                temperature: nil,
                confidence: .explicit
            ),
            ExtractedStep(
                instruction: "Gradually stir in flour mixture until just combined. Don't overmix.",
                duration: nil,
                temperature: nil,
                confidence: .explicit
            ),
            ExtractedStep(
                instruction: "Fold in chocolate chips",
                duration: nil,
                temperature: nil,
                confidence: .explicit
            ),
            ExtractedStep(
                instruction: "Drop rounded tablespoons of dough onto ungreased baking sheets, spacing about 2 inches apart",
                duration: nil,
                temperature: nil,
                confidence: .explicit
            ),
            ExtractedStep(
                instruction: "Bake until golden brown. Centers may look slightly underdone.",
                duration: "9-11 minutes",
                temperature: "375°F",
                confidence: .explicit
            ),
            ExtractedStep(
                instruction: "Let cookies cool on baking sheet, then transfer to wire rack",
                duration: "2 minutes",
                temperature: nil,
                confidence: .explicit
            )
        ]

        return StructuredRecipe(
            title: "Chocolate Chip Cookies",
            description: "Classic homemade chocolate chip cookies with a crispy edge and chewy center",
            servings: "5 dozen cookies",
            prepTime: "15 minutes",
            cookTime: "9-11 minutes per batch",
            ingredients: ingredients,
            steps: steps,
            overallConfidence: 0.87,
            warnings: []
        )
    }
}

// MARK: - Mock Video Recipe Processor

@MainActor
class MockVideoRecipeProcessor: VideoRecipeProcessorProtocol, ObservableObject {
    @Published var state: ProcessingState = .idle
    @Published var progress: Double = 0.0
    @Published var canCancel: Bool = false

    private var processingTask: Task<Void, Never>?

    private let audioExtractor = MockAudioExtractionService()
    private let transcriber = MockTranscriptionService()
    private let frameAnalyzer = MockFrameAnalysisService()
    private let structurer = MockRecipeStructurer()

    func process(videoURL: URL) async throws -> VideoRecipeExtraction {
        let startTime = Date()
        canCancel = true
        defer { canCancel = false }

        // Step 1: Extract audio
        state = .extractingAudio
        progress = 0.05
        let audioURL = try await audioExtractor.extractAudio(from: videoURL)
        try Task.checkCancellation()

        // Step 2: Transcribe (longest step)
        state = .transcribing(progress: 0.0)
        progress = 0.1

        // Simulate progressive transcription
        for i in 1...5 {
            try await Task.sleep(for: .milliseconds(600))
            let transcribeProgress = Double(i) / 5.0
            state = .transcribing(progress: transcribeProgress)
            progress = 0.1 + (0.6 * transcribeProgress)
            try Task.checkCancellation()
        }

        let transcript = try await transcriber.transcribe(audioURL: audioURL)
        progress = 0.7
        try Task.checkCancellation()

        // Step 3: Analyze frames (optional, parallel in real implementation)
        state = .analyzingFrames
        let frames = try await frameAnalyzer.extractKeyFrames(from: videoURL, count: 5)
        let visualElements = try await frameAnalyzer.analyzeForRecipeElements(frames)
        progress = 0.85
        try Task.checkCancellation()

        // Step 4: Structure recipe
        state = .structuringRecipe
        let structured = try await structurer.structure(
            transcript: transcript,
            visualElements: visualElements
        )
        progress = 1.0

        let processingTime = Date().timeIntervalSince(startTime)
        let estimatedCost = Decimal(0.02)  // $0.02 mock cost

        // Create mock attribution
        let attribution = VideoSourceAttribution(
            creatorName: nil,  // User will fill this in review
            videoTitle: nil,
            platform: .cameraRoll,
            sourceURL: videoURL.absoluteString,
            notes: nil,
            importDate: Date(),
            hasPermission: true
        )

        let metadata = VideoImportMetadata(
            attribution: attribution,
            videoDuration: await audioExtractor.estimateDuration(videoURL) ?? 0,
            transcriptionProvider: transcript.provider.rawValue,
            transcriptionConfidence: transcript.confidence,
            processingCost: estimatedCost,
            processingTime: processingTime,
            transcriptText: transcript.text,
            detectedVisualElements: visualElements
        )

        let extraction = VideoRecipeExtraction(
            structuredRecipe: structured,
            transcript: transcript,
            visualElements: visualElements,
            metadata: metadata,
            processingTime: processingTime,
            estimatedCost: estimatedCost
        )

        state = .reviewing(structured)
        return extraction
    }

    func cancel() {
        processingTask?.cancel()
        state = .idle
        progress = 0.0
    }
}
