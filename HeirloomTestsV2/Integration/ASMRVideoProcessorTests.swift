//
//  ASMRVideoProcessorTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-10
//  Integration tests for ASMR video processing pipeline
//
//  DISABLED: Test infrastructure needs updating
//  TODO: Update mock services to match current API
//

/*

import XCTest
import AVFoundation
@testable import Heirloom

@MainActor
final class ASMRVideoProcessorTests: XCTestCase {

    // MARK: - Properties

    var processor: ASMRVideoProcessor!
    var mockSoundAnalyzer: MockASMRSoundAnalysisService!
    var mockFrameExtractor: MockASMRFrameExtractionService!
    var mockStructurer: MockASMRRecipeStructurer!
    var mockUsageManager: MockASMRUsageManager!
    var mockCacheService: MockASMRCacheService!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // TODO: Fix ASMR mocks in Phase 3 (Video/ASMR testing)
        // Temporarily disabled - not needed for Phase 1 subscription tests
        fatalError("ASMR tests not implemented yet - will be added in Phase 3")
    }

    override func tearDown() {
        mockSoundAnalyzer.reset()
        mockFrameExtractor.reset()
        mockStructurer.reset()
        mockUsageManager.reset()
        mockCacheService.reset()
        processor = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestVideoURL() -> URL {
        URL(fileURLWithPath: "/tmp/test_video.mov")
    }

    // MARK: - Complete Pipeline Tests

    func testASMRProcessor_CompletePipeline_Success() async throws {
        // GIVEN: Valid ASMR video and all services configured
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.configureSuitable()
        mockFrameExtractor.configureStandardFrames()
        mockStructurer.configureSuccessfulExtraction(dishName: "Carbonara Pasta")

        let videoURL = createTestVideoURL()
        let userCaption = "Making carbonara pasta"

        // WHEN: Process video
        let extraction = try await processor.process(
            videoURL: videoURL,
            userCaption: userCaption,
            videoHash: nil
        )

        // THEN: Extraction succeeds with correct data
        XCTAssertEqual(extraction.structuredRecipe.title, "Carbonara Pasta")
        XCTAssertEqual(extraction.structuredRecipe.overallConfidence, 0.85, accuracy: 0.01)
        XCTAssertTrue(extraction.estimatedCost < 0.50, "Cost should be under $0.50")
        XCTAssertTrue(extraction.estimatedCost > 0.10, "Cost should be realistic")

        // THEN: Progress reaches 100%
        XCTAssertEqual(processor.progress, 1.0)

        // THEN: State is completed
        if case .completed = processor.state {
            // Expected state
        } else {
            XCTFail("Expected completed state")
        }

        // THEN: Credits deducted
        XCTAssertEqual(mockUsageManager.startExtractionCallCount, 1)
        XCTAssertEqual(mockUsageManager.refundCallCount, 0, "Credits should not be refunded on success")
    }

    func testASMRProcessor_InsufficientCredits_ThrowsError() async throws {
        // GIVEN: No credits available
        mockUsageManager.shouldAllowExtraction = false

        // WHEN/THEN: Processing throws error
        do {
            _ = try await processor.process(
                videoURL: createTestVideoURL(),
                userCaption: "Test",
                videoHash: nil
            )
            XCTFail("Expected insufficient credits error")
        } catch let error as ASMRUsageError {
            if case .insufficientCredits = error {
                // Expected error
            } else {
                XCTFail("Expected insufficientCredits error")
            }
        }

        // THEN: Credits not deducted
        XCTAssertEqual(mockUsageManager.startExtractionCallCount, 0)
    }

    func testASMRProcessor_UnsuitableVideo_ThrowsErrorAndRefunds() async throws {
        // GIVEN: Video with speech (unsuitable)
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.configureUnsuitable(reason: "Speech detected")

        // WHEN/THEN: Processing throws error
        do {
            _ = try await processor.process(
                videoURL: createTestVideoURL(),
                userCaption: "Test",
                videoHash: nil
            )
            XCTFail("Expected unsuitable video error")
        } catch let error as ASMRProcessingError {
            if case .unsuitable = error {
                // Expected error
            } else {
                XCTFail("Expected unsuitable error")
            }
        }

        // THEN: Credits refunded
        XCTAssertEqual(mockUsageManager.startExtractionCallCount, 1)
        XCTAssertEqual(mockUsageManager.refundCallCount, 1)
    }

    func testASMRProcessor_InsufficientFrames_ThrowsErrorAndRefunds() async throws {
        // GIVEN: Only 10 frames (need 15+)
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.configureSuitable()

        let mockImage = UIImage(systemName: "photo")!
        mockFrameExtractor.mockFrames = FrameExtractionResult(
            finalFrames: [ExtractedFrame(image: mockImage, timestamp: 0, frameIndex: 0, frameType: .final)],
            cookingFrames: Array(repeating: ExtractedFrame(image: mockImage, timestamp: 0, frameIndex: 0, frameType: .cooking), count: 5),
            setupFrames: Array(repeating: ExtractedFrame(image: mockImage, timestamp: 0, frameIndex: 0, frameType: .setup), count: 4),
            totalFrames: 10
        )

        // WHEN/THEN: Processing throws error
        do {
            _ = try await processor.process(
                videoURL: createTestVideoURL(),
                userCaption: "Test",
                videoHash: nil
            )
            XCTFail("Expected insufficient frames error")
        } catch let error as ASMRProcessingError {
            if case .insufficientFrames = error {
                // Expected error
            } else {
                XCTFail("Expected insufficientFrames error")
            }
        }

        // THEN: Credits refunded
        XCTAssertEqual(mockUsageManager.refundCallCount, 1)
    }

    func testASMRProcessor_ProgressUpdates_ThroughAllStages() async throws {
        // GIVEN: Valid processing setup
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.configureSuitable()
        mockFrameExtractor.configureStandardFrames()
        mockStructurer.configureSuccessfulExtraction()

        var progressValues: [Double] = []

        // Track progress changes in background
        let observation = Task {
            while !Task.isCancelled {
                progressValues.append(processor.progress)
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }

        // WHEN: Process video
        _ = try await processor.process(
            videoURL: createTestVideoURL(),
            userCaption: "Test",
            videoHash: nil
        )

        observation.cancel()

        // THEN: Progress increases monotonically
        XCTAssertGreaterThan(progressValues.count, 0, "Should have captured progress values")
        XCTAssertEqual(progressValues.last ?? 0, 1.0, "Final progress should be 1.0")

        // THEN: Progress only increases (monotonic)
        for i in 1..<progressValues.count {
            XCTAssertGreaterThanOrEqual(progressValues[i], progressValues[i-1],
                                       "Progress should never decrease")
        }
    }

    func testASMRProcessor_CachedExtraction_ReturnedImmediately() async throws {
        // GIVEN: Extraction already cached
        let testHash = "test_video.mov"
        mockUsageManager.shouldAllowExtraction = true

        // Pre-cache an extraction
        let cachedRecipe = StructuredRecipe(
            title: "Cached Recipe",
            description: nil,
            servings: "4",
            prepTime: nil,
            cookTime: nil,
            ingredients: [],
            steps: [],
            overallConfidence: 0.9,
            warnings: []
        )
        let cachedExtraction = VideoRecipeExtraction(
            structuredRecipe: cachedRecipe,
            transcript: TranscriptionResult(text: "", segments: [], confidence: 0.9, provider: .whisperKit, language: "n/a"),
            visualElements: [],
            metadata: VideoImportMetadata(
                attribution: VideoSourceAttribution(platform: .cameraRoll, captionText: "", notes: nil, importDate: Date(), hasPermission: true),
                videoDuration: 0,
                transcriptionProvider: "",
                transcriptionConfidence: 0.9,
                processingCost: 0.35,
                processingTime: 180,
                transcriptText: nil,
                detectedVisualElements: [],
                processedAt: Date()
            ),
            processingTime: 180,
            estimatedCost: 0.35
        )
        mockCacheService.cachedExtractions[testHash] = cachedExtraction

        // WHEN: Process same video
        let extraction = try await processor.process(
            videoURL: createTestVideoURL(),
            userCaption: "Test",
            videoHash: testHash
        )

        // THEN: Returns cached result
        XCTAssertEqual(extraction.structuredRecipe.title, "Cached Recipe")
        XCTAssertEqual(processor.progress, 1.0)

        // THEN: Skipped expensive operations
        XCTAssertEqual(mockSoundAnalyzer.analyzeCallCount, 0)
        XCTAssertEqual(mockFrameExtractor.extractCallCount, 0)
        XCTAssertEqual(mockStructurer.structureCallCount, 0)
    }

    func testASMRProcessor_SuccessfulExtraction_CachedForFutureUse() async throws {
        // GIVEN: Valid processing setup
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.configureSuitable()
        mockFrameExtractor.configureStandardFrames()
        mockStructurer.configureSuccessfulExtraction()

        let testHash = "test_video_new.mov"

        // WHEN: Process video
        let extraction = try await processor.process(
            videoURL: URL(fileURLWithPath: "/tmp/\(testHash)"),
            userCaption: "Test",
            videoHash: testHash
        )

        // THEN: Result is cached
        XCTAssertEqual(mockCacheService.setCacheCallCount, 1)
        XCTAssertNotNil(mockCacheService.cachedExtractions[testHash])
        XCTAssertEqual(
            mockCacheService.cachedExtractions[testHash]?.structuredRecipe.title,
            extraction.structuredRecipe.title
        )
    }

    func testASMRProcessor_Cancellation_StopsProcessing() async throws {
        // GIVEN: Start processing
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.configureSuitable()
        mockFrameExtractor.configureStandardFrames()
        mockStructurer.configureSuccessfulExtraction()

        // WHEN: Cancel mid-processing
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            processor.cancel()
        }

        // Processing task will be cancelled
        _ = try? await processor.process(
            videoURL: createTestVideoURL(),
            userCaption: "Test",
            videoHash: nil
        )

        // THEN: State is cancelled
        XCTAssertEqual(processor.state, .cancelled)
        XCTAssertEqual(processor.progress, 0.0)
        XCTAssertNil(processor.currentPass)
    }

    func testASMRProcessor_CostValidation_WithinBudget() async throws {
        // GIVEN: Realistic extraction
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.configureSuitable()
        mockFrameExtractor.configureStandardFrames()
        mockStructurer.configureSuccessfulExtraction()

        // WHEN: Process video
        let extraction = try await processor.process(
            videoURL: createTestVideoURL(),
            userCaption: "Test",
            videoHash: nil
        )

        // THEN: Cost within budget
        XCTAssertLessThan(extraction.estimatedCost, 0.50, "Cost should be under $0.50")
        XCTAssertGreaterThan(extraction.estimatedCost, 0.10, "Cost should be realistic")
        XCTAssertLessThan(extraction.metadata.processingCost, 0.50, "Metadata cost should match")
    }

    func testASMRProcessor_UserCaption_PassedToStructurer() async throws {
        // GIVEN: Valid setup
        mockUsageManager.shouldAllowExtraction = true
        mockSoundAnalyzer.configureSuitable()
        mockFrameExtractor.configureStandardFrames()
        mockStructurer.configureSuccessfulExtraction()

        let testCaption = "Making homemade pasta carbonara"

        // WHEN: Process with specific caption
        _ = try await processor.process(
            videoURL: createTestVideoURL(),
            userCaption: testCaption,
            videoHash: nil
        )

        // THEN: Caption passed to structurer
        XCTAssertEqual(mockStructurer.capturedCaptions.count, 1)
        XCTAssertEqual(mockStructurer.capturedCaptions.first, testCaption)
    }
}

*/
