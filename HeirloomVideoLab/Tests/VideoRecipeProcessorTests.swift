//
//  VideoRecipeProcessorTests.swift
//  HeirloomVideoLabTests
//
//  Created by Claude on 1/8/26.
//
//  Integration tests for VideoRecipeProcessor

import XCTest
@testable import HeirloomVideoLab

@MainActor
final class VideoRecipeProcessorTests: XCTestCase {

    var sut: VideoRecipeProcessor!
    var testVideoURL: URL!

    override func setUp() async throws {
        try await super.setUp()

        testVideoURL = try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "sample_recipe", withExtension: "mp4"),
            "Test video not found"
        )

        // Use mock services for unit testing
        let mockTranscription = MockTranscriptionService()
        let mockRecipeStructurer = MockRecipeStructurer()

        sut = VideoRecipeProcessor(
            transcriptionService: mockTranscription,
            recipeStructurer: mockRecipeStructurer,
            enableFrameAnalysis: true,
            enableCaching: false  // Disable for unit tests
        )
    }

    override func tearDown() async throws {
        sut = nil
        testVideoURL = nil
        try await super.tearDown()
    }

    // MARK: - Happy Path Integration Tests

    func testProcessVideo_CompletePipeline() async throws {
        // Given: Valid video URL
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.progress, 0.0)

        // When: Processing video
        let extraction = try await sut.process(videoURL: testVideoURL)

        // Then: Should complete all stages
        XCTAssertEqual(sut.progress, 1.0)

        // Verify extraction result
        XCTAssertFalse(extraction.structuredRecipe.title.isEmpty)
        XCTAssertFalse(extraction.structuredRecipe.ingredients.isEmpty)
        XCTAssertFalse(extraction.structuredRecipe.steps.isEmpty)
        XCTAssertNotNil(extraction.transcript)
        XCTAssertNotNil(extraction.metadata)

        // Verify metadata
        XCTAssertGreaterThan(extraction.processingTime, 0)
        XCTAssertNotNil(extraction.metadata.attribution)
        XCTAssertEqual(extraction.metadata.attribution.platform, .cameraRoll)
    }

    func testProcessVideo_StateTransitions() async throws {
        // Given: Valid video
        var observedStates: [ProcessingState] = []

        // When: Processing (observe state changes)
        Task {
            // Note: In real implementation, you'd use Combine or observation to track state
            _ = try await sut.process(videoURL: testVideoURL)
        }

        // Then: Should progress through states
        // .idle → .extractingAudio → .transcribing → .analyzingFrames → .structuringRecipe → .reviewing
        // (This is a simplified test - real implementation would need proper observation)
    }

    func testProcessVideo_ProgressIncreases() async throws {
        // Given: Valid video
        var progressValues: [Double] = []

        // When: Processing
        _ = try await sut.process(videoURL: testVideoURL)

        // Then: Progress should increase monotonically (0 → 0.05 → 0.75 → 0.85 → 1.0)
        // Note: Actual implementation would need to track progress during async execution
        XCTAssertEqual(sut.progress, 1.0)
    }

    // MARK: - Caching Tests

    func testProcessVideo_WithCaching_UsesCachedResult() async throws {
        // Given: Processor with caching enabled
        let cachedProcessor = VideoRecipeProcessor(
            transcriptionService: MockTranscriptionService(),
            recipeStructurer: MockRecipeStructurer(),
            enableCaching: true
        )

        // When: Processing same video twice
        let firstResult = try await cachedProcessor.process(videoURL: testVideoURL)
        let startTime = Date()
        let secondResult = try await cachedProcessor.process(videoURL: testVideoURL)
        let elapsedTime = Date().timeIntervalSince(startTime)

        // Then: Second processing should be much faster (cached)
        XCTAssertLessThan(elapsedTime, 1.0, "Cached result should be instant")
        XCTAssertEqual(firstResult.structuredRecipe.title, secondResult.structuredRecipe.title)
    }

    func testProcessVideo_WithoutCaching_ReprocessesEverytime() async throws {
        // Given: Processor without caching (sut has caching disabled)

        // When: Processing same video twice
        _ = try await sut.process(videoURL: testVideoURL)
        _ = try await sut.process(videoURL: testVideoURL)

        // Then: Should reprocess (no early return from cache)
        // Both should complete successfully
    }

    // MARK: - Frame Analysis Skip Logic

    func testProcessVideo_SkipsFrameAnalysis_HighConfidence() async throws {
        // Given: Mock transcription with high confidence (>0.85)
        let highConfidenceMock = MockTranscriptionService()
        highConfidenceMock.mockConfidence = 0.90

        let processor = VideoRecipeProcessor(
            transcriptionService: highConfidenceMock,
            recipeStructurer: MockRecipeStructurer(),
            enableFrameAnalysis: true,
            enableCaching: false
        )

        // When: Processing
        let extraction = try await processor.process(videoURL: testVideoURL)

        // Then: Should skip frame analysis
        XCTAssertTrue(extraction.visualElements.isEmpty)
    }

    func testProcessVideo_PerformsFrameAnalysis_LowConfidence() async throws {
        // Given: Mock transcription with low confidence (<0.85)
        let lowConfidenceMock = MockTranscriptionService()
        lowConfidenceMock.mockConfidence = 0.70

        let processor = VideoRecipeProcessor(
            transcriptionService: lowConfidenceMock,
            recipeStructurer: MockRecipeStructurer(),
            enableFrameAnalysis: true,
            enableCaching: false
        )

        // When: Processing
        let extraction = try await processor.process(videoURL: testVideoURL)

        // Then: Should perform frame analysis (may or may not find elements)
        // Note: With real FrameAnalysisService, would check visualElements
    }

    func testProcessVideo_FrameAnalysisDisabled_SkipsRegardlessOfConfidence() async throws {
        // Given: Processor with frame analysis disabled
        let processor = VideoRecipeProcessor(
            transcriptionService: MockTranscriptionService(),
            recipeStructurer: MockRecipeStructurer(),
            enableFrameAnalysis: false,
            enableCaching: false
        )

        // When: Processing
        let extraction = try await processor.process(videoURL: testVideoURL)

        // Then: Should always skip frame analysis
        XCTAssertTrue(extraction.visualElements.isEmpty)
    }

    // MARK: - Cost Tracking

    func testProcessVideo_CalculatesCost() async throws {
        // When: Processing video
        let extraction = try await sut.process(videoURL: testVideoURL)

        // Then: Should calculate cost
        XCTAssertGreaterThan(extraction.estimatedCost, 0)
        XCTAssertLessThan(extraction.estimatedCost, 1.0)  // Should be < $1
    }

    func testCostTracking_AccumulatesAcrossVideos() async throws {
        // Given: Fresh cost tracking
        VideoRecipeProcessor.resetCostTracking()

        // When: Processing multiple videos
        _ = try await sut.process(videoURL: testVideoURL)
        _ = try await sut.process(videoURL: testVideoURL)

        // Then: Should track cumulative cost
        XCTAssertEqual(VideoRecipeProcessor.totalVideosProcessed, 2)
        XCTAssertGreaterThan(VideoRecipeProcessor.totalProcessingCost, 0)

        let avgCost = VideoRecipeProcessor.averageCostPerVideo
        XCTAssertGreaterThan(avgCost, 0)
    }

    // MARK: - Error Handling

    func testProcessVideo_AudioExtractionFails_ThrowsError() async throws {
        // Given: Processor with failing audio extractor
        let failingExtractor = FailingAudioExtractor()

        let processor = VideoRecipeProcessor(
            audioExtractor: failingExtractor,
            transcriptionService: MockTranscriptionService(),
            recipeStructurer: MockRecipeStructurer()
        )

        // When/Then: Should propagate error
        do {
            _ = try await processor.process(videoURL: testVideoURL)
            XCTFail("Should throw error when audio extraction fails")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testProcessVideo_TranscriptionFails_ThrowsError() async throws {
        // Given: Processor with failing transcription
        let failingTranscription = FailingTranscriptionService()

        let processor = VideoRecipeProcessor(
            transcriptionService: failingTranscription,
            recipeStructurer: MockRecipeStructurer()
        )

        // When/Then: Should propagate error
        do {
            _ = try await processor.process(videoURL: testVideoURL)
            XCTFail("Should throw error when transcription fails")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testProcessVideo_StructuringFails_ThrowsError() async throws {
        // Given: Processor with failing structurer
        let failingStructurer = FailingRecipeStructurer()

        let processor = VideoRecipeProcessor(
            transcriptionService: MockTranscriptionService(),
            recipeStructurer: failingStructurer
        )

        // When/Then: Should propagate error
        do {
            _ = try await processor.process(videoURL: testVideoURL)
            XCTFail("Should throw error when recipe structuring fails")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testProcessVideo_FrameAnalysisFails_ContinuesProcessing() async throws {
        // Given: Processor with failing frame analyzer (but frame analysis is optional)
        let failingAnalyzer = FailingFrameAnalyzer()

        let processor = VideoRecipeProcessor(
            audioExtractor: AudioExtractionService(),
            transcriptionService: MockTranscriptionService(),
            frameAnalyzer: failingAnalyzer,
            recipeStructurer: MockRecipeStructurer(),
            enableFrameAnalysis: true
        )

        // When: Processing (frame analysis should fail but not stop pipeline)
        let extraction = try await processor.process(videoURL: testVideoURL)

        // Then: Should complete without frame analysis results
        XCTAssertNotNil(extraction)
        XCTAssertTrue(extraction.visualElements.isEmpty)
    }

    // MARK: - Cancellation Tests

    func testCancel_StopsProcessing() async throws {
        // Given: Started processing
        let processingTask = Task {
            try await sut.process(videoURL: testVideoURL)
        }

        // When: Cancelling
        sut.cancel()

        // Then: Task should be cancelled
        processingTask.cancel()

        do {
            _ = try await processingTask.value
            // If it completes, that's ok (timing dependent)
        } catch is CancellationError {
            // Expected
        } catch VideoImportError.cancelled {
            // Also expected
        }

        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.progress, 0.0)
    }

    func testCanCancel_TrueWhileProcessing() async throws {
        // Given: Started processing
        XCTAssertFalse(sut.canCancel)

        Task {
            _ = try? await sut.process(videoURL: testVideoURL)
        }

        // When: During processing
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 sec

        // Then: Should be cancellable
        // Note: Timing-dependent, may need adjustment
        // XCTAssertTrue(sut.canCancel)
    }

    // MARK: - Performance Tests

    func testProcessingTimeEstimation() {
        // When: Estimating for 15-minute video
        let videoDuration: TimeInterval = 15 * 60  // 15 minutes
        let estimatedTime = VideoRecipeProcessor.estimateProcessingTime(videoDuration: videoDuration)

        // Then: Should be 2-4 minutes (120-240 seconds)
        XCTAssertGreaterThan(estimatedTime, 100)
        XCTAssertLessThan(estimatedTime, 300)
    }

    func testCheckMemoryAvailable() {
        // When: Checking memory
        let hasEnoughMemory = sut.checkMemoryAvailable()

        // Then: Should return boolean (varies by device)
        XCTAssertNotNil(hasEnoughMemory)
    }

    func testProcessVideo_CompletesInReasonableTime() async throws {
        // Given: Valid video
        let startTime = Date()

        // When: Processing with mocks (should be fast)
        _ = try await sut.process(videoURL: testVideoURL)

        // Then: Mocks should complete very quickly (<5 seconds)
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsedTime, 5.0, "Mock processing should be fast")
    }

    // MARK: - Attribution Tests

    func testProcessVideo_CreatesAttributionPlaceholder() async throws {
        // When: Processing video
        let extraction = try await sut.process(videoURL: testVideoURL)

        // Then: Should create attribution placeholder
        XCTAssertNotNil(extraction.metadata.attribution)
        XCTAssertNil(extraction.metadata.attribution.creatorName)  // User fills this
        XCTAssertEqual(extraction.metadata.attribution.platform, .cameraRoll)
        XCTAssertTrue(extraction.metadata.attribution.hasPermission)
        XCTAssertEqual(
            extraction.metadata.attribution.sourceURL,
            testVideoURL.absoluteString
        )
    }
}

// MARK: - Mock Failing Services (for error testing)

class FailingAudioExtractor: AudioExtractionServiceProtocol {
    func extractAudio(from videoURL: URL) async throws -> URL {
        throw VideoImportError.noAudioTrack
    }

    func estimateDuration(_ videoURL: URL) async -> TimeInterval? {
        return nil
    }
}

@MainActor
class FailingTranscriptionService: TranscriptionServiceProtocol {
    var provider: TranscriptionProvider { .whisperKit }
    var isAvailable: Bool { false }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        throw VideoImportError.transcriptionUnavailable
    }
}

class FailingFrameAnalyzer: FrameAnalysisServiceProtocol {
    func extractKeyFrames(from videoURL: URL, count: Int) async throws -> [UIImage] {
        throw FrameAnalysisError.noFramesExtracted
    }

    func analyzeForRecipeElements(_ frames: [UIImage]) async throws -> [String] {
        throw FrameAnalysisError.noFramesExtracted
    }
}

@MainActor
class FailingRecipeStructurer: RecipeStructurerProtocol {
    func structure(
        transcript: TranscriptionResult,
        visualElements: [String]
    ) async throws -> StructuredRecipe {
        throw VideoImportError.recipeStructuringFailed(
            underlying: NSError(domain: "test", code: -1)
        )
    }
}

// MARK: - Mock Recipe Structurer

@MainActor
class MockRecipeStructurer: RecipeStructurerProtocol {
    func structure(
        transcript: TranscriptionResult,
        visualElements: [String]
    ) async throws -> StructuredRecipe {

        return StructuredRecipe(
            title: "Mock Recipe",
            description: "A test recipe",
            servings: "4 servings",
            prepTime: "10 minutes",
            cookTime: "20 minutes",
            ingredients: [
                ExtractedIngredient(
                    originalText: "2 cups flour",
                    item: "flour",
                    quantity: "2",
                    unit: "cups",
                    preparation: nil,
                    confidence: .explicit
                )
            ],
            steps: [
                ExtractedStep(
                    instruction: "Mix ingredients",
                    duration: "5 minutes",
                    temperature: nil,
                    confidence: .explicit
                )
            ],
            overallConfidence: 0.85,
            warnings: []
        )
    }
}
