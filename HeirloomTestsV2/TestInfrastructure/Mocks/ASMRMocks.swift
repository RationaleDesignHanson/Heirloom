//
//  ASMRMocks.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-10
//

import Foundation
import AVFoundation
import UIKit
@testable import Heirloom

// MARK: - Mock ASMR Sound Analysis Service

@MainActor
class MockASMRSoundAnalysisService: ASMRSoundAnalysisService {
    var mockResult: SoundAnalysisResult?
    var shouldThrowError = false
    var analyzeCallCount = 0

    override func analyzeSuitability(videoURL: URL) async throws -> SoundAnalysisResult {
        analyzeCallCount += 1

        if shouldThrowError {
            throw ASMRProcessingError.structuringFailed(underlying: NSError(domain: "test", code: 1))
        }

        return mockResult ?? SoundAnalysisResult(
            hasSpeech: false,
            hasMusic: false,
            soundQuality: .silent,
            confidence: 1.0,
            suitable: true,
            reasoning: "Mock result - suitable for ASMR"
        )
    }

    func configureSuitable() {
        mockResult = SoundAnalysisResult(
            hasSpeech: false,
            hasMusic: false,
            soundQuality: .ambientOnly,
            confidence: 0.95,
            suitable: true,
            reasoning: "No speech detected - suitable for ASMR"
        )
    }

    func configureUnsuitable(reason: String) {
        mockResult = SoundAnalysisResult(
            hasSpeech: true,
            hasMusic: false,
            soundQuality: .unclear,
            confidence: 0.85,
            suitable: false,
            reasoning: reason
        )
    }

    func reset() {
        mockResult = nil
        shouldThrowError = false
        analyzeCallCount = 0
    }
}

// MARK: - Mock ASMR Frame Extraction Service

@MainActor
class MockASMRFrameExtractionService: ASMRFrameExtractionService {
    var mockFrames: FrameExtractionResult?
    var shouldThrowError = false
    var extractCallCount = 0

    override func extractFrames(from videoURL: URL) async throws -> FrameExtractionResult {
        extractCallCount += 1

        if shouldThrowError {
            throw FrameExtractionError.noFramesExtracted
        }

        guard let frames = mockFrames else {
            throw FrameExtractionError.noFramesExtracted
        }

        return frames
    }

    func configureStandardFrames() {
        let mockImage = UIImage(systemName: "photo")!
        let createFrame = { (index: Int, type: FrameType) -> ExtractedFrame in
            ExtractedFrame(
                image: mockImage,
                timestamp: Double(index) * 10.0,
                frameIndex: index,
                frameType: type
            )
        }

        mockFrames = FrameExtractionResult(
            finalFrames: (0..<5).map { createFrame($0, .final) },
            cookingFrames: (0..<10).map { createFrame($0, .cooking) },
            setupFrames: (0..<5).map { createFrame($0, .setup) },
            totalFrames: 20
        )
    }

    func reset() {
        mockFrames = nil
        shouldThrowError = false
        extractCallCount = 0
    }
}

// MARK: - Mock ASMR Recipe Structurer

@MainActor
class MockASMRRecipeStructurer: ASMRRecipeStructurer {
    var mockExtraction: VideoRecipeExtraction?
    var shouldThrowError = false
    var structureCallCount = 0
    var capturedCaptions: [String] = []

    override func structure(
        frames: FrameExtractionResult,
        userCaption: String,
        progressHandler: @Sendable (ASMRProcessingPass, [String]) -> Void
    ) async throws -> VideoRecipeExtraction {
        structureCallCount += 1
        capturedCaptions.append(userCaption)

        if shouldThrowError {
            throw ASMRProcessingError.structuringFailed(underlying: NSError(domain: "test", code: 1))
        }

        // Simulate pass progression
        for pass in ASMRProcessingPass.allCases {
            let findings = ["Finding 1 for \(pass.displayName)", "Finding 2 for \(pass.displayName)"]
            progressHandler(pass, findings)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        guard let extraction = mockExtraction else {
            throw ASMRProcessingError.structuringFailed(underlying: NSError(domain: "test", code: 2))
        }

        return extraction
    }

    func configureSuccessfulExtraction(dishName: String = "Carbonara Pasta") {
        mockExtraction = createMockExtraction(dishName: dishName)
    }

    func reset() {
        mockExtraction = nil
        shouldThrowError = false
        structureCallCount = 0
        capturedCaptions = []
    }

    private func createMockExtraction(dishName: String) -> VideoRecipeExtraction {
        let recipe = StructuredRecipe(
            title: dishName,
            description: "Test recipe extracted from ASMR video",
            servings: "4",
            prepTime: "10 minutes",
            cookTime: "20 minutes",
            ingredients: [
                ExtractedIngredient(
                    originalText: "400g pasta",
                    item: "Pasta",
                    quantity: "400",
                    unit: "g",
                    preparation: nil,
                    confidence: .explicit
                )
            ],
            steps: [
                ExtractedStep(
                    instruction: "Boil pasta in salted water",
                    duration: "10 minutes",
                    temperature: nil,
                    confidence: .explicit
                )
            ],
            overallConfidence: 0.85,
            warnings: []
        )

        let transcript = TranscriptionResult(
            text: "Vision-only processing - no audio",
            segments: [],
            confidence: 0.85,
            provider: .whisperKit,
            language: "n/a"
        )

        let metadata = VideoImportMetadata(
            attribution: VideoSourceAttribution(
                platform: .cameraRoll,
                captionText: "Test video",
                notes: "ASMR test extraction",
                importDate: Date(),
                hasPermission: true
            ),
            videoDuration: 180.0,
            transcriptionProvider: "Vision-Only (ASMR)",
            transcriptionConfidence: 0.85,
            processingCost: 0.35,
            processingTime: 180.0,
            transcriptText: nil,
            detectedVisualElements: ["pasta", "guanciale", "eggs"],
            processedAt: Date()
        )

        return VideoRecipeExtraction(
            structuredRecipe: recipe,
            transcript: transcript,
            visualElements: ["pasta", "guanciale", "eggs"],
            metadata: metadata,
            processingTime: 180.0,
            estimatedCost: 0.35
        )
    }
}

// MARK: - Mock ASMR Usage Manager

@MainActor
class MockASMRUsageManager: ASMRUsageManager {
    var shouldAllowExtraction = true
    var startExtractionCallCount = 0
    var refundCallCount = 0
    var canStartExtractionCallCount = 0

    override func canStartExtraction() -> Bool {
        canStartExtractionCallCount += 1
        return shouldAllowExtraction
    }

    override func startExtraction() throws {
        startExtractionCallCount += 1
        if !shouldAllowExtraction {
            throw ASMRUsageError.insufficientCredits(needed: 5, available: 0)
        }
    }

    override func refundExtraction() {
        refundCallCount += 1
    }

    func reset() {
        shouldAllowExtraction = true
        startExtractionCallCount = 0
        refundCallCount = 0
        canStartExtractionCallCount = 0
    }
}

// MARK: - Mock ASMR Cache Service

@MainActor
class MockASMRCacheService: ASMRCacheService {
    var cachedExtractions: [String: VideoRecipeExtraction] = [:]
    var computeHashCallCount = 0
    var getCacheCallCount = 0
    var setCacheCallCount = 0

    override init() {
        super.init()
    }

    override func computeHash(for videoURL: URL) async throws -> String {
        computeHashCallCount += 1
        return videoURL.lastPathComponent
    }

    override func getCachedASMRExtraction(hash: String) async throws -> VideoRecipeExtraction? {
        getCacheCallCount += 1
        return cachedExtractions[hash]
    }

    override func cacheASMRExtraction(_ extraction: VideoRecipeExtraction, hash: String) async throws {
        setCacheCallCount += 1
        cachedExtractions[hash] = extraction
    }

    func reset() {
        cachedExtractions = [:]
        computeHashCallCount = 0
        getCacheCallCount = 0
        setCacheCallCount = 0
    }
}
