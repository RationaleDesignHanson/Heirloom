//
//  AudioExtractionServiceTests.swift
//  HeirloomVideoLabTests
//
//  Created by Claude on 1/8/26.
//
//  Unit tests for AudioExtractionService

import XCTest
import AVFoundation
@testable import HeirloomVideoLab

@MainActor
final class AudioExtractionServiceTests: XCTestCase {

    var sut: AudioExtractionService!
    var testVideoURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        sut = AudioExtractionService()

        // Use test video from bundle
        testVideoURL = try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "sample_recipe", withExtension: "mp4"),
            "Test video not found. Add sample_recipe.mp4 to test bundle."
        )
    }

    override func tearDown() async throws {
        sut = nil
        testVideoURL = nil
        try await super.tearDown()
    }

    // MARK: - Happy Path Tests

    func testExtractAudioFromValidVideo() async throws {
        // Given: A valid video file with audio

        // When: Extracting audio
        let audioURL = try await sut.extractAudio(from: testVideoURL)

        // Then: Audio file should exist and be valid M4A
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))
        XCTAssertEqual(audioURL.pathExtension.lowercased(), "m4a")

        // Verify audio asset is readable
        let audioAsset = AVURLAsset(url: audioURL)
        let audioTracks = try await audioAsset.load(.tracks)
        XCTAssertFalse(audioTracks.isEmpty, "Extracted audio should have tracks")

        // Cleanup
        try? FileManager.default.removeItem(at: audioURL)
    }

    func testAudioDurationEstimation() async throws {
        // Given: A video file

        // When: Estimating duration
        let duration = await sut.estimateDuration(testVideoURL)

        // Then: Should return reasonable duration (>0 seconds)
        XCTAssertNotNil(duration)
        XCTAssertGreaterThan(duration ?? 0, 0)
        XCTAssertLessThan(duration ?? 0, 3600, "Test video should be under 1 hour")
    }

    func testExtractedAudioHasCorrectFormat() async throws {
        // Given: Valid video

        // When: Extracting audio
        let audioURL = try await sut.extractAudio(from: testVideoURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        // Then: Should be M4A format suitable for transcription
        let audioAsset = AVURLAsset(url: audioURL)
        let audioTracks = try await audioAsset.load(.tracks)
        let audioTrack = try XCTUnwrap(audioTracks.first)

        // Check format is audio
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        XCTAssertFalse(formatDescriptions.isEmpty)
    }

    // MARK: - Error Cases

    func testExtractAudioFromVideoWithoutAudio_ThrowsError() async throws {
        // Given: A video file without audio track
        // (You'll need to add a silent_video.mp4 test file)
        guard let silentVideoURL = Bundle(for: type(of: self))
            .url(forResource: "silent_video", withExtension: "mp4") else {
            throw XCTSkip("Silent video test file not available")
        }

        // When/Then: Should throw noAudioTrack error
        do {
            _ = try await sut.extractAudio(from: silentVideoURL)
            XCTFail("Should throw error for video without audio")
        } catch VideoImportError.noAudioTrack {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExtractAudioFromInvalidFile_ThrowsError() async throws {
        // Given: An invalid file URL
        let invalidURL = URL(fileURLWithPath: "/tmp/nonexistent_video.mp4")

        // When/Then: Should throw error
        do {
            _ = try await sut.extractAudio(from: invalidURL)
            XCTFail("Should throw error for invalid file")
        } catch {
            // Expected error (could be various AVFoundation errors)
            XCTAssertNotNil(error)
        }
    }

    func testExtractAudioFromCorruptedVideo_ThrowsError() async throws {
        // Given: A corrupted video file
        let corruptedVideoPath = NSTemporaryDirectory() + "corrupted.mp4"
        let corruptedVideoURL = URL(fileURLWithPath: corruptedVideoPath)

        // Create a fake corrupted file
        let fakeData = Data(repeating: 0xFF, count: 1024)
        try fakeData.write(to: corruptedVideoURL)
        defer { try? FileManager.default.removeItem(at: corruptedVideoURL) }

        // When/Then: Should handle gracefully
        do {
            _ = try await sut.extractAudio(from: corruptedVideoURL)
            XCTFail("Should throw error for corrupted video")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Performance Tests

    func testAudioExtractionPerformance() async throws {
        // Given: Valid video
        let startTime = Date()

        // When: Extracting audio
        let audioURL = try await sut.extractAudio(from: testVideoURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        // Then: Should complete reasonably fast (<15 seconds for typical video)
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsedTime, 15.0, "Audio extraction taking too long")
    }

    // MARK: - Cleanup Tests

    func testCleanupTemporaryAudio() async throws {
        // Given: Extracted audio file
        let audioURL = try await sut.extractAudio(from: testVideoURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))

        // When: Calling cleanup
        AudioExtractionService.cleanupTemporaryAudio(at: audioURL)

        // Then: File should be deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    }

    func testCleanupNonexistentFile_DoesNotThrow() {
        // Given: A non-existent file URL
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent_audio.m4a")

        // When/Then: Should not throw
        XCTAssertNoThrow(
            AudioExtractionService.cleanupTemporaryAudio(at: nonexistentURL)
        )
    }
}
