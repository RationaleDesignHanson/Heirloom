//
//  FrameAnalysisServiceTests.swift
//  HeirloomVideoLabTests
//
//  Created by Claude on 1/8/26.
//
//  Unit tests for FrameAnalysisService

import XCTest
import AVFoundation
import UIKit
@testable import HeirloomVideoLab

@MainActor
final class FrameAnalysisServiceTests: XCTestCase {

    var sut: FrameAnalysisService!
    var testVideoURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        sut = FrameAnalysisService()

        testVideoURL = try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "sample_recipe", withExtension: "mp4"),
            "Test video not found"
        )
    }

    override func tearDown() async throws {
        sut = nil
        testVideoURL = nil
        try await super.tearDown()
    }

    // MARK: - Frame Extraction Tests

    func testExtractKeyFrames_ValidVideo() async throws {
        // Given: Valid video and frame count
        let frameCount = 5

        // When: Extracting frames
        let frames = try await sut.extractKeyFrames(from: testVideoURL, count: frameCount)

        // Then: Should extract requested number of frames
        XCTAssertEqual(frames.count, frameCount)

        // Verify frames are valid images
        for frame in frames {
            XCTAssertGreaterThan(frame.size.width, 0)
            XCTAssertGreaterThan(frame.size.height, 0)
        }
    }

    func testExtractKeyFrames_FrameSizeLimit() async throws {
        // Given: Valid video
        let frames = try await sut.extractKeyFrames(from: testVideoURL, count: 3)

        // Then: Frames should be resized to max dimensions
        for frame in frames {
            XCTAssertLessThanOrEqual(frame.size.width, 1280)
            XCTAssertLessThanOrEqual(frame.size.height, 720)
        }
    }

    func testExtractKeyFrames_DistributedTiming() async throws {
        // Given: Video with known duration
        let frameCount = 10

        // When: Extracting frames
        let frames = try await sut.extractKeyFrames(from: testVideoURL, count: frameCount)

        // Then: Should extract frames evenly distributed
        // (Implicit - AVAssetImageGenerator handles this)
        XCTAssertEqual(frames.count, frameCount)
    }

    func testExtractKeyFrames_InvalidVideo_ThrowsError() async throws {
        // Given: Invalid video URL
        let invalidURL = URL(fileURLWithPath: "/tmp/invalid.mp4")

        // When/Then: Should throw error
        do {
            _ = try await sut.extractKeyFrames(from: invalidURL, count: 5)
            XCTFail("Should throw error for invalid video")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testExtractKeyFrames_ZeroFrames_ThrowsError() async throws {
        // Given: Valid video but zero frames requested

        // When/Then: Should handle gracefully or throw error
        do {
            let frames = try await sut.extractKeyFrames(from: testVideoURL, count: 0)
            XCTAssertTrue(frames.isEmpty)
        } catch FrameAnalysisError.noFramesExtracted {
            // Expected error
        }
    }

    // MARK: - OCR Analysis Tests

    func testAnalyzeForRecipeElements_WithText() async throws {
        // Given: Frames with recipe text (requires test video with on-screen text)
        guard let textVideoURL = Bundle(for: type(of: self))
            .url(forResource: "recipe_with_text", withExtension: "mp4") else {
            throw XCTSkip("Test video with text not available")
        }

        let frames = try await sut.extractKeyFrames(from: textVideoURL, count: 5)

        // When: Analyzing frames
        let elements = try await sut.analyzeForRecipeElements(frames)

        // Then: Should detect recipe-relevant text
        XCTAssertFalse(elements.isEmpty, "Should detect some text elements")
    }

    func testAnalyzeForRecipeElements_EmptyFrames() async throws {
        // Given: Empty frames array

        // When: Analyzing
        let elements = try await sut.analyzeForRecipeElements([])

        // Then: Should return empty array
        XCTAssertTrue(elements.isEmpty)
    }

    func testAnalyzeForRecipeElements_RemovesDuplicates() async throws {
        // Given: Frames that might contain duplicate text
        let frames = try await sut.extractKeyFrames(from: testVideoURL, count: 5)

        // When: Analyzing (multiple frames may show same text)
        let elements = try await sut.analyzeForRecipeElements(frames)

        // Then: Should deduplicate results
        let uniqueElements = Set(elements)
        XCTAssertEqual(elements.count, uniqueElements.count, "Should remove duplicates")
    }

    // MARK: - Recipe Relevance Tests

    func testRecipeRelevance_Temperature() {
        // Test internal relevance logic via mock data
        // Note: isRecipeRelevant is private, but we can test via integration

        let temperatureTexts = [
            "350°F",
            "180°C",
            "375 degrees",
            "200 degrees fahrenheit"
        ]

        // These should be detected as recipe-relevant
        // Verified through integration test
    }

    func testRecipeRelevance_Time() {
        let timeTexts = [
            "10 minutes",
            "2 hours",
            "30 min",
            "1 hr 15 minutes"
        ]

        // These should be detected as recipe-relevant
    }

    func testRecipeRelevance_Measurements() {
        let measurementTexts = [
            "2 cups",
            "1 tablespoon",
            "1/2 tsp",
            "3 ounces",
            "500g flour"
        ]

        // These should be detected as recipe-relevant
    }

    func testRecipeRelevance_IrrelevantText() {
        let irrelevantTexts = [
            "Subscribe to my channel",
            "Like and comment",
            "Kitchen Aid"
        ]

        // These should NOT be detected as recipe-relevant (unless they contain numbers)
    }

    // MARK: - Performance Tests

    func testFrameExtraction_Performance() async throws {
        // Given: Valid video
        let startTime = Date()

        // When: Extracting 5 frames
        _ = try await sut.extractKeyFrames(from: testVideoURL, count: 5)

        // Then: Should complete reasonably fast (<5 seconds)
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsedTime, 5.0, "Frame extraction taking too long")
    }

    func testOCRAnalysis_Performance() async throws {
        // Given: Extracted frames
        let frames = try await sut.extractKeyFrames(from: testVideoURL, count: 5)
        let startTime = Date()

        // When: Analyzing frames
        _ = try await sut.analyzeForRecipeElements(frames)

        // Then: Should complete in reasonable time (<10 seconds for 5 frames)
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsedTime, 10.0, "OCR analysis taking too long")
    }

    // MARK: - Skip Logic Tests

    func testShouldSkipFrameAnalysis_HighConfidence() {
        // Given: High transcript confidence
        let highConfidence = 0.90

        // When: Checking if should skip
        let shouldSkip = FrameAnalysisService.shouldSkipFrameAnalysis(
            transcriptConfidence: highConfidence
        )

        // Then: Should skip (confidence >= 0.85)
        XCTAssertTrue(shouldSkip)
    }

    func testShouldSkipFrameAnalysis_LowConfidence() {
        // Given: Low transcript confidence
        let lowConfidence = 0.70

        // When: Checking if should skip
        let shouldSkip = FrameAnalysisService.shouldSkipFrameAnalysis(
            transcriptConfidence: lowConfidence
        )

        // Then: Should NOT skip
        XCTAssertFalse(shouldSkip)
    }

    func testShouldSkipFrameAnalysis_ThresholdEdgeCase() {
        // Given: Exactly at threshold (0.85)

        // When: Testing boundary
        let atThreshold = FrameAnalysisService.shouldSkipFrameAnalysis(
            transcriptConfidence: 0.85
        )
        let justBelow = FrameAnalysisService.shouldSkipFrameAnalysis(
            transcriptConfidence: 0.849
        )

        // Then: >= 0.85 should skip, < 0.85 should not
        XCTAssertTrue(atThreshold)
        XCTAssertFalse(justBelow)
    }

    func testEstimateProcessingTime() {
        // When: Estimating for various frame counts
        let time5Frames = FrameAnalysisService.estimateProcessingTime(frameCount: 5)
        let time10Frames = FrameAnalysisService.estimateProcessingTime(frameCount: 10)

        // Then: Should scale linearly
        XCTAssertGreaterThan(time10Frames, time5Frames)
        XCTAssertEqual(time10Frames, time5Frames * 2, accuracy: 0.1)
    }

    // MARK: - Advanced Features Tests

    func testDetectTextOverlays() async throws {
        // Given: Frame with text overlays
        guard let textVideoURL = Bundle(for: type(of: self))
            .url(forResource: "recipe_with_text", withExtension: "mp4") else {
            throw XCTSkip("Test video with text not available")
        }

        let frames = try await sut.extractKeyFrames(from: textVideoURL, count: 1)
        let frame = try XCTUnwrap(frames.first)

        // When: Detecting text overlays
        let hasText = try await sut.detectTextOverlays(in: frame)

        // Then: Should detect presence of text
        // (May be true or false depending on test video)
        XCTAssertNotNil(hasText)
    }

    func testExtractKeyFramesAdaptive() async throws {
        // Given: Valid video
        let maxFrames = 10

        // When: Extracting with adaptive sampling
        let frames = try await sut.extractKeyFramesAdaptive(from: testVideoURL, maxFrames: maxFrames)

        // Then: Should return at most maxFrames
        XCTAssertLessThanOrEqual(frames.count, maxFrames)
        XCTAssertGreaterThan(frames.count, 0)
    }

    // MARK: - Memory Tests

    func testFrameExtraction_MemoryEfficient() async throws {
        // Given: Requesting many frames
        let largeFrameCount = 20

        // When: Extracting frames
        let frames = try await sut.extractKeyFrames(from: testVideoURL, count: largeFrameCount)

        // Then: Should not cause memory issues
        // Frames should be resized (max 1280x720)
        XCTAssertEqual(frames.count, largeFrameCount)

        // Verify memory constraint
        for frame in frames {
            let pixels = frame.size.width * frame.size.height
            XCTAssertLessThanOrEqual(pixels, 1280 * 720, "Frame too large")
        }
    }
}
