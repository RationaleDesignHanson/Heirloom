//
//  ASMRVideoProcessorIntegrationTests.swift
//  HeirloomTests
//
//  Created by Claude on 1/10/26.
//

import Testing
import Foundation
import AVFoundation
@testable import Heirloom

/// Integration tests for complete ASMR video processing pipeline
@Suite("ASMR Video Processor Integration Tests")
@MainActor
struct ASMRVideoProcessorIntegrationTests {

    // MARK: - Test Setup

    var processor: ASMRVideoProcessor
    var mockSoundAnalyzer: MockASMRSoundAnalysisService
    var mockFrameExtractor: MockASMRFrameExtractionService
    var mockStructurer: MockASMRRecipeStructurer
    var mockUsageManager: MockASMRUsageManager
    var mockCacheService: MockVideoCacheService

    init() {
        mockSoundAnalyzer = MockASMRSoundAnalysisService()
        mockFrameExtractor = MockASMRFrameExtractionService()
        mockStructurer = MockASMRRecipeStructurer()
        mockUsageManager = MockASMRUsageManager()
        mockCacheService = MockVideoCacheService()

        processor = ASMRVideoProcessor(
            soundAnalyzer: mockSoundAnalyzer,
            frameExtractor: mockFrameExtractor,
            structurer: mockStructurer,
            usageManager: mockUsageManager,
            cacheService: mockCacheService
        )
    }

    // MARK: - End-to-End Pipeline Tests

    @Test("Complete ASMR processing pipeline succeeds")
    func testCompleteProcessingPipeline() async throws {
        // Given: Mock video URL and caption
        let testVideoURL = createTestVideoURL()
        let userCaption = "Making carbonara pasta"

        // Configure mocks for successful processing
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.mockSuitabilityResult = SoundAnalysisResult(
            hasSpeech: false,
            hasMusic: false,
            soundQuality: .ambientOnly,
            confidence: 0.95,
            suitable: true,
            reasoning: "No speech detected, ambient sounds only"
        )

        mockFrameExtractor.mockFrames = createMockFrameExtractionResult()
        mockStructurer.mockExtraction = createMockASMRExtraction()

        // When: Process video
        let extraction = try await processor.process(
            videoURL: testVideoURL,
            userCaption: userCaption,
            videoHash: nil
        )

        // Then: Verify successful completion
        #expect(processor.progress == 1.0)
        #expect(processor.state == .completed(extraction))
        #expect(extraction.structuredRecipe.title == "Carbonara Pasta")
        #expect(extraction.overallConfidence > 0.0)
        #expect(extraction.totalCost > 0.0)
        #expect(extraction.totalCost < 0.50)  // Should be under budget

        // Verify credits were deducted
        #expect(mockUsageManager.extractionStarted == true)
        #expect(mockUsageManager.extractionRefunded == false)
    }

    @Test("Processing fails when insufficient credits")
    func testInsufficientCredits() async throws {
        // Given: No credits available
        mockUsageManager.shouldAllowExtraction = false

        let testVideoURL = createTestVideoURL()

        // When/Then: Processing should throw error
        await #expect(throws: ASMRUsageError.self) {
            try await processor.process(
                videoURL: testVideoURL,
                userCaption: "Test",
                videoHash: nil
            )
        }

        // Verify credits were not deducted
        #expect(mockUsageManager.extractionStarted == false)
    }

    @Test("Credits refunded on processing failure")
    func testCreditsRefundedOnFailure() async throws {
        // Given: Processing will fail
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.shouldThrowError = true

        let testVideoURL = createTestVideoURL()

        // When: Processing fails
        do {
            _ = try await processor.process(
                videoURL: testVideoURL,
                userCaption: "Test",
                videoHash: nil
            )
            Issue.record("Expected processing to fail")
        } catch {
            // Then: Credits should be refunded
            #expect(mockUsageManager.extractionStarted == true)
            #expect(mockUsageManager.extractionRefunded == true)
        }
    }

    @Test("Unsuitable video rejected early")
    func testUnsuitableVideoRejected() async throws {
        // Given: Video with speech (unsuitable)
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.mockSuitabilityResult = SoundAnalysisResult(
            hasSpeech: true,
            hasMusic: false,
            soundQuality: .unclear,
            confidence: 0.85,
            suitable: false,
            reasoning: "Speech detected - use standard video import instead"
        )

        let testVideoURL = createTestVideoURL()

        // When/Then: Processing should fail with unsuitable error
        await #expect(throws: ASMRProcessingError.self) {
            try await processor.process(
                videoURL: testVideoURL,
                userCaption: "Test",
                videoHash: nil
            )
        }

        // Verify credits were refunded (early failure)
        #expect(mockUsageManager.extractionRefunded == true)
    }

    @Test("Insufficient frames rejected")
    func testInsufficientFrames() async throws {
        // Given: Only 10 frames extracted (need 15+)
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.mockSuitabilityResult = createValidSuitabilityResult()
        mockFrameExtractor.mockFrames = FrameExtractionResult(
            finalFrames: [createMockExtractedFrame()],
            cookingFrames: Array(repeating: createMockExtractedFrame(), count: 5),
            setupFrames: Array(repeating: createMockExtractedFrame(), count: 4),
            totalFrames: 10
        )

        let testVideoURL = createTestVideoURL()

        // When/Then: Processing should fail
        await #expect(throws: ASMRProcessingError.self) {
            try await processor.process(
                videoURL: testVideoURL,
                userCaption: "Test",
                videoHash: nil
            )
        }

        // Verify credits were refunded
        #expect(mockUsageManager.extractionRefunded == true)
    }

    // MARK: - Progress Tracking Tests

    @Test("Progress updates through all stages")
    func testProgressUpdates() async throws {
        // Given: Valid setup
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.mockSuitabilityResult = createValidSuitabilityResult()
        mockFrameExtractor.mockFrames = createMockFrameExtractionResult()
        mockStructurer.mockExtraction = createMockASMRExtraction()

        var progressValues: [Double] = []
        var stateChanges: [String] = []

        // Track progress changes
        let observation = Task {
            while !Task.isCancelled {
                progressValues.append(processor.progress)
                stateChanges.append("\(processor.state)")
                try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
            }
        }

        // When: Process video
        _ = try await processor.process(
            videoURL: createTestVideoURL(),
            userCaption: "Test",
            videoHash: nil
        )

        observation.cancel()

        // Then: Progress should increase monotonically
        #expect(progressValues.first ?? 0 < progressValues.last ?? 0)
        #expect(progressValues.last ?? 0 == 1.0)

        // Should go through expected states
        #expect(stateChanges.contains { $0.contains("analyzingSounds") })
        #expect(stateChanges.contains { $0.contains("extractingFrames") })
        #expect(stateChanges.contains { $0.contains("processingPass") })
        #expect(stateChanges.contains { $0.contains("completed") })
    }

    @Test("Current pass updates through all 5 passes")
    func testCurrentPassProgression() async throws {
        // Given: Valid setup with pass tracking
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.mockSuitabilityResult = createValidSuitabilityResult()
        mockFrameExtractor.mockFrames = createMockFrameExtractionResult()

        // Track which passes we see
        var observedPasses: Set<ASMRProcessingPass> = []
        mockStructurer.onPassProgress = { pass, _ in
            observedPasses.insert(pass)
        }
        mockStructurer.mockExtraction = createMockASMRExtraction()

        // When: Process video
        _ = try await processor.process(
            videoURL: createTestVideoURL(),
            userCaption: "Test",
            videoHash: nil
        )

        // Then: All 5 passes should have been observed
        #expect(observedPasses.count == 5)
        #expect(observedPasses.contains(.identifying))
        #expect(observedPasses.contains(.detecting))
        #expect(observedPasses.contains(.inferring))
        #expect(observedPasses.contains(.analyzing))
        #expect(observedPasses.contains(.validating))
    }

    // MARK: - Caching Tests

    @Test("Cached extraction returned immediately")
    func testCachedExtraction() async throws {
        // Given: Extraction already cached
        let testHash = "test_video_hash_123"
        let cachedExtraction = createMockASMRExtraction()
        mockCacheService.cachedExtractions[testHash] = cachedExtraction
        mockUsageManager.shouldAllowExtraction = true

        // When: Process same video
        let extraction = try await processor.process(
            videoURL: createTestVideoURL(),
            userCaption: "Test",
            videoHash: testHash
        )

        // Then: Should return cached result immediately
        #expect(extraction.videoHash == cachedExtraction.videoHash)
        #expect(processor.progress == 1.0)

        // Should not have called sound analyzer or frame extractor
        #expect(mockSoundAnalyzer.analyzeCount == 0)
        #expect(mockFrameExtractor.extractCount == 0)
    }

    @Test("Successful extraction is cached")
    func testExtractionIsCached() async throws {
        // Given: Valid processing setup
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.mockSuitabilityResult = createValidSuitabilityResult()
        mockFrameExtractor.mockFrames = createMockFrameExtractionResult()
        mockStructurer.mockExtraction = createMockASMRExtraction()

        let testHash = "new_video_hash_456"

        // When: Process video
        let extraction = try await processor.process(
            videoURL: createTestVideoURL(),
            userCaption: "Test",
            videoHash: testHash
        )

        // Then: Should be cached
        #expect(mockCacheService.cachedExtractions[testHash] != nil)
        #expect(mockCacheService.cachedExtractions[testHash]?.videoHash == extraction.videoHash)
    }

    // MARK: - Cancellation Tests

    @Test("Cancellation stops processing")
    func testCancellation() async throws {
        // Given: Start processing
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.mockSuitabilityResult = createValidSuitabilityResult()
        mockFrameExtractor.mockFrames = createMockFrameExtractionResult()
        mockStructurer.mockExtraction = createMockASMRExtraction()
        mockStructurer.processingDelay = 2.0  // Long processing time

        // When: Cancel mid-processing
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            processor.cancel()
        }

        do {
            _ = try await processor.process(
                videoURL: createTestVideoURL(),
                userCaption: "Test",
                videoHash: nil
            )
        } catch {
            // Expected to throw cancellation error
        }

        // Then: State should be cancelled
        #expect(processor.state == .cancelled)
        #expect(processor.progress == 0.0)
        #expect(processor.currentPass == nil)
    }

    // MARK: - Cost Validation Tests

    @Test("Total cost stays under budget")
    func testCostWithinBudget() async throws {
        // Given: Realistic extraction with cost tracking
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.mockSuitabilityResult = createValidSuitabilityResult()
        mockFrameExtractor.mockFrames = createMockFrameExtractionResult()

        // Create extraction with realistic cost
        var mockExtraction = createMockASMRExtraction()
        mockExtraction.totalCost = 0.35  // Realistic cost
        mockExtraction.totalTokens = 15000
        mockStructurer.mockExtraction = mockExtraction

        // When: Process video
        let extraction = try await processor.process(
            videoURL: createTestVideoURL(),
            userCaption: "Test",
            videoHash: nil
        )

        // Then: Cost should be under $0.50 threshold
        #expect(extraction.totalCost < 0.50)
        #expect(extraction.totalCost > 0.10)  // Should be realistic
        #expect(extraction.totalTokens > 0)
    }

    // MARK: - Helper Methods

    private func createTestVideoURL() -> URL {
        // In real tests, this would point to actual test video files
        URL(fileURLWithPath: "/tmp/test_video.mov")
    }

    private func createValidSuitabilityResult() -> SoundAnalysisResult {
        SoundAnalysisResult(
            hasSpeech: false,
            hasMusic: false,
            soundQuality: .ambientOnly,
            confidence: 0.95,
            suitable: true,
            reasoning: "Silent video suitable for ASMR processing"
        )
    }

    private func createMockExtractedFrame() -> ExtractedFrame {
        let image = UIImage(systemName: "photo")!
        return ExtractedFrame(
            image: image,
            timestamp: 0.0,
            frameIndex: 0,
            frameType: .final
        )
    }

    private func createMockFrameExtractionResult() -> FrameExtractionResult {
        FrameExtractionResult(
            finalFrames: Array(repeating: createMockExtractedFrame(), count: 5),
            cookingFrames: Array(repeating: createMockExtractedFrame(), count: 10),
            setupFrames: Array(repeating: createMockExtractedFrame(), count: 5),
            totalFrames: 20
        )
    }

    private func createMockASMRExtraction() -> ASMRRecipeExtraction {
        ASMRRecipeExtraction(
            videoHash: "test_hash",
            userCaption: "Test caption",
            processingDate: Date(),
            dishIdentification: DishIdentificationResult(
                dishName: "Carbonara Pasta",
                dishType: "Italian pasta",
                servingStyle: "plated",
                visualComplexity: "moderate",
                confidence: 0.9,
                reasoning: "Clear carbonara presentation",
                analyzedFrames: [0, 1, 2, 3, 4]
            ),
            ingredientDetection: IngredientDetectionResult(
                detectedIngredients: [
                    IngredientDetectionResult.DetectedIngredient(
                        name: "Pasta",
                        visualState: "cooked",
                        estimatedQuantity: "400g",
                        confidence: 0.95,
                        firstSeen: 10.0,
                        lastSeen: 120.0,
                        frameIndices: [5, 6, 7]
                    )
                ],
                transformations: [],
                confidence: 0.85
            ),
            culinaryInference: CulinaryInferenceResult(
                inferredIngredients: [
                    CulinaryInferenceResult.InferredIngredient(
                        name: "Salt",
                        reasoning: "Essential for pasta water",
                        necessity: "essential",
                        estimatedQuantity: "to taste",
                        confidence: 0.9
                    )
                ],
                inferredSeasonings: [
                    CulinaryInferenceResult.InferredSeasoning(
                        name: "Black pepper",
                        reasoning: "Traditional carbonara seasoning",
                        necessity: "essential",
                        confidence: 0.95
                    )
                ],
                confidence: 0.8
            ),
            actionRecognition: ActionRecognitionResult(
                recognizedActions: [
                    ActionRecognitionResult.RecognizedAction(
                        action: "boiling",
                        target: "pasta",
                        timestamp: 30.0,
                        duration: 600.0,
                        technique: "vigorous boil",
                        confidence: 0.9
                    )
                ],
                cookingTechniques: ["boiling", "mixing"],
                equipment: ["pot", "pan", "whisk"],
                confidence: 0.85
            ),
            synthesis: SynthesisResult(
                finalRecipe: createMockStructuredRecipe(),
                validationNotes: [
                    SynthesisResult.ValidationNote(
                        type: .inferredQuantity,
                        message: "Egg quantity estimated from visual cues",
                        severity: .info
                    )
                ],
                confidence: 0.85,
                completeness: 0.9
            ),
            structuredRecipe: createMockStructuredRecipe(),
            overallConfidence: 0.85,
            totalCost: 0.35,
            totalTokens: 15000,
            processingTime: 180.0,
            hasSpeech: false,
            hasMusic: false,
            soundQuality: .ambientOnly
        )
    }

    private func createMockStructuredRecipe() -> StructuredRecipe {
        StructuredRecipe(
            title: "Carbonara Pasta",
            description: "Classic Italian pasta carbonara",
            ingredients: [
                StructuredIngredient(
                    name: "Pasta",
                    quantity: "400g",
                    preparation: "cooked al dente",
                    category: "Pasta & Grains"
                )
            ],
            steps: [
                StructuredStep(
                    stepNumber: 1,
                    instruction: "Boil pasta in salted water",
                    duration: "10 minutes",
                    temperature: nil,
                    technique: "boiling"
                )
            ],
            prepTime: "5 minutes",
            cookTime: "15 minutes",
            servings: "4",
            difficulty: "Medium",
            cuisine: "Italian",
            course: "Main Course",
            tags: ["pasta", "Italian"]
        )
    }
}

// MARK: - Mock Services

@MainActor
class MockASMRSoundAnalysisService: ASMRSoundAnalysisService {
    var mockSuitabilityResult: SoundAnalysisResult?
    var shouldThrowError = false
    var analyzeCount = 0

    override func analyzeSuitability(videoURL: URL) async throws -> SoundAnalysisResult {
        analyzeCount += 1

        if shouldThrowError {
            throw ASMRProcessingError.soundAnalysisFailed
        }

        return mockSuitabilityResult ?? SoundAnalysisResult(
            hasSpeech: false,
            hasMusic: false,
            soundQuality: .silent,
            confidence: 1.0,
            suitable: true,
            reasoning: "Mock result"
        )
    }
}

@MainActor
class MockASMRFrameExtractionService: ASMRFrameExtractionService {
    var mockFrames: FrameExtractionResult?
    var shouldThrowError = false
    var extractCount = 0

    override func extractFrames(from videoURL: URL) async throws -> FrameExtractionResult {
        extractCount += 1

        if shouldThrowError {
            throw FrameExtractionError.noFramesExtracted
        }

        guard let frames = mockFrames else {
            throw FrameExtractionError.noFramesExtracted
        }

        return frames
    }
}

@MainActor
class MockASMRRecipeStructurer: ASMRRecipeStructurer {
    var mockExtraction: ASMRRecipeExtraction?
    var shouldThrowError = false
    var processingDelay: TimeInterval = 0.0
    var onPassProgress: ((ASMRProcessingPass, [String]) -> Void)?

    override func structure(
        frames: FrameExtractionResult,
        userCaption: String,
        progressHandler: @escaping @Sendable (ASMRProcessingPass, [String]) -> Void
    ) async throws -> ASMRRecipeExtraction {

        if shouldThrowError {
            throw ASMRProcessingError.structuringFailed
        }

        // Simulate pass progression
        for pass in ASMRProcessingPass.allCases {
            let findings = ["Finding 1 for \(pass.displayName)", "Finding 2 for \(pass.displayName)"]
            progressHandler(pass, findings)
            onPassProgress?(pass, findings)

            if processingDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000) / 5)
            }
        }

        guard let extraction = mockExtraction else {
            throw ASMRProcessingError.structuringFailed
        }

        return extraction
    }
}

@MainActor
class MockASMRUsageManager: ASMRUsageManager {
    var shouldAllowExtraction = true
    var extractionStarted = false
    var extractionRefunded = false

    override func canStartExtraction() -> Bool {
        return shouldAllowExtraction
    }

    override func startExtraction() throws {
        if !shouldAllowExtraction {
            throw ASMRUsageError.insufficientCredits(needed: 5, available: 0)
        }
        extractionStarted = true
    }

    override func refundExtraction() {
        extractionRefunded = true
    }
}

@MainActor
class MockVideoCacheService: VideoCacheService {
    var cachedExtractions: [String: ASMRRecipeExtraction] = [:]

    override func getCachedASMRExtraction(hash: String) async throws -> ASMRRecipeExtraction? {
        return cachedExtractions[hash]
    }

    override func cacheASMRExtraction(_ extraction: ASMRRecipeExtraction, hash: String) async throws {
        cachedExtractions[hash] = extraction
    }
}
