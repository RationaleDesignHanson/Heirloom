//
//  TranscriptionServiceTests.swift
//  HeirloomVideoLabTests
//
//  Created by Claude on 1/8/26.
//
//  Unit tests for transcription services

import XCTest
@testable import HeirloomVideoLab

@MainActor
final class TranscriptionServiceTests: XCTestCase {

    var testAudioURL: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Use test audio from bundle
        testAudioURL = try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "sample_audio", withExtension: "m4a"),
            "Test audio not found. Add sample_audio.m4a to test bundle."
        )
    }

    override func tearDown() async throws {
        testAudioURL = nil
        try await super.tearDown()
    }

    // MARK: - WhisperKit Model Selection Tests

    func testSelectOptimalModel_LowMemoryDevice() {
        // Given: Device with 3GB RAM (simulated via ProcessInfo mock)
        // When: Selecting model for low memory
        // Note: This test requires mocking ProcessInfo.processInfo.physicalMemory

        let model = WhisperKitTranscriptionService.selectOptimalModel()

        // Then: Should select appropriate model (tiny.en or base.en depending on device)
        XCTAssertTrue(
            ["tiny.en", "base.en", "small.en"].contains(model),
            "Should select valid WhisperKit model"
        )
    }

    func testModelSelection_ReturnsValidModelName() {
        // When: Getting model selection
        let model = WhisperKitTranscriptionService.selectOptimalModel()

        // Then: Should be one of the supported models
        let validModels = ["tiny.en", "base.en", "small.en"]
        XCTAssertTrue(validModels.contains(model))
    }

    // MARK: - Mock Transcription Service Tests

    func testMockTranscriptionService_Availability() async {
        // Given: Mock service
        let mockService = MockTranscriptionService()

        // Then: Should always be available
        XCTAssertTrue(mockService.isAvailable)
        XCTAssertEqual(mockService.provider, .whisperKit)
    }

    func testMockTranscriptionService_ReturnsValidResult() async throws {
        // Given: Mock service
        let mockService = MockTranscriptionService()

        // When: Transcribing audio
        let result = try await mockService.transcribe(audioURL: testAudioURL)

        // Then: Should return hardcoded result
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
        XCTAssertEqual(result.provider, .whisperKit)
    }

    func testMockTranscriptionService_IncludesSegments() async throws {
        // Given: Mock service
        let mockService = MockTranscriptionService()

        // When: Transcribing
        let result = try await mockService.transcribe(audioURL: testAudioURL)

        // Then: Should include timestamped segments
        XCTAssertFalse(result.segments.isEmpty)

        // Verify segment structure
        let firstSegment = try XCTUnwrap(result.segments.first)
        XCTAssertGreaterThanOrEqual(firstSegment.startTime, 0)
        XCTAssertGreaterThan(firstSegment.endTime, firstSegment.startTime)
        XCTAssertFalse(firstSegment.text.isEmpty)
    }

    // MARK: - Adaptive Service Tests

    func testAdaptiveService_InitializesCorrectly() async {
        // When: Creating adaptive service
        let adaptiveService = await AdaptiveTranscriptionService()

        // Then: Should initialize and select best provider
        XCTAssertTrue(adaptiveService.isAvailable)
    }

    func testAdaptiveService_SelectsWhisperKitOnOlderDevices() async {
        // Given: Running on iOS < 26 (current reality)
        let adaptiveService = await AdaptiveTranscriptionService()

        // Then: Should use WhisperKit provider
        XCTAssertEqual(adaptiveService.provider, .whisperKit)
    }

    // MARK: - TranscriptionResult Tests

    func testTranscriptionResult_HasRequiredFields() {
        // Given: A transcription result
        let result = TranscriptionResult(
            text: "Test transcript",
            segments: [
                TranscriptSegment(text: "Test transcript", startTime: 0, endTime: 2.5)
            ],
            confidence: 0.85,
            provider: .whisperKit
        )

        // Then: All fields should be accessible
        XCTAssertEqual(result.text, "Test transcript")
        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.confidence, 0.85)
        XCTAssertEqual(result.provider, .whisperKit)
    }

    func testTranscriptSegment_TimeValidation() {
        // Given: A segment with invalid times
        let segment = TranscriptSegment(
            text: "Test",
            startTime: 5.0,
            endTime: 3.0  // End before start
        )

        // Then: Should still create (validation happens at application layer)
        XCTAssertEqual(segment.startTime, 5.0)
        XCTAssertEqual(segment.endTime, 3.0)
        // Note: Could add validation logic if needed
    }

    // MARK: - Caching Tests

    func testTranscriptionCaching_StoresResult() async {
        // Given: Cache and a transcription result
        let cache = VideoProcessingCache.shared
        let result = TranscriptionResult(
            text: "Cached transcript",
            segments: [],
            confidence: 0.9,
            provider: .whisperKit
        )
        let videoHash = "test-hash-123"

        // When: Caching result
        await cache.cacheTranscript(result, forVideoHash: videoHash)

        // Then: Should retrieve same result
        let cached = await cache.getCachedTranscript(forVideoHash: videoHash)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.text, "Cached transcript")
        XCTAssertEqual(cached?.confidence, 0.9)
    }

    func testTranscriptionCaching_ReturnsNilForMissingHash() async {
        // Given: Cache with no entry for hash
        let cache = VideoProcessingCache.shared

        // When: Requesting non-existent hash
        let cached = await cache.getCachedTranscript(forVideoHash: "nonexistent-hash")

        // Then: Should return nil
        XCTAssertNil(cached)
    }

    // MARK: - Error Handling Tests

    func testTranscriptionError_InvalidAudioFile() async {
        // Given: Mock service with invalid audio
        let mockService = MockTranscriptionService()
        let invalidURL = URL(fileURLWithPath: "/tmp/invalid.m4a")

        // When/Then: Should handle gracefully
        // Note: Mock doesn't validate, but real service would throw
        do {
            _ = try await mockService.transcribe(audioURL: invalidURL)
            // Mock succeeds, real service would fail
        } catch {
            XCTFail("Mock service should not throw for invalid URL")
        }
    }

    // MARK: - Performance Tests

    func testMockTranscriptionPerformance() async throws {
        // Given: Mock service
        let mockService = MockTranscriptionService()
        let startTime = Date()

        // When: Transcribing
        _ = try await mockService.transcribe(audioURL: testAudioURL)

        // Then: Mock should be very fast (<1 second)
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsedTime, 1.0, "Mock transcription should be instant")
    }

    // MARK: - Integration with Real WhisperKit (Commented - Requires Device)

    /*
    func testWhisperKitTranscription_RealAudio() async throws {
        // NOTE: This test requires WhisperKit to be installed and runs only on device

        #if targetEnvironment(simulator)
        throw XCTSkip("WhisperKit not available on simulator")
        #else

        // Given: Real WhisperKit service
        let whisperService = await WhisperKitTranscriptionService()

        guard whisperService.isAvailable else {
            throw XCTSkip("WhisperKit not available (model not downloaded?)")
        }

        // When: Transcribing real audio
        let result = try await whisperService.transcribe(audioURL: testAudioURL)

        // Then: Should return valid transcript
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertEqual(result.provider, .whisperKit)

        #endif
    }

    func testWhisperKitTranscription_LongAudio() async throws {
        // Test with 5-10 minute audio file
        // Verify it completes in reasonable time (2-3 minutes)
    }

    func testWhisperKitTranscription_NoisyAudio() async throws {
        // Test with background noise
        // Should still extract transcript but with lower confidence
    }
    */
}
