//
//  AudioExtractionService.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Real audio extraction from video using AVFoundation

import Foundation
import AVFoundation

/// Production audio extraction service using AVFoundation
class AudioExtractionService: AudioExtractionServiceProtocol {

    func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        // Verify video has audio track
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw VideoImportError.noAudioTrack
        }

        // Create composition with audio only
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioExtractionError.compositionFailed
        }

        // Insert audio track into composition
        let duration = try await asset.load(.duration)
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: audioTrack,
            at: .zero
        )

        // Configure export for optimal transcription quality
        // WhisperKit prefers 16kHz mono, but higher quality is better for accuracy
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioExtractionError.exportSessionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Export asynchronously
        // TODO: Update to new iOS 18+ export(to:as:) API when min deployment target increases
        if #available(iOS 18.0, *) {
            // Suppress deprecation warnings for now - we support iOS 16+
            await exportSession.export()
        } else {
            await exportSession.export()
        }

        // Check status
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            let error = exportSession.error
            throw AudioExtractionError.exportFailed(error)
        case .cancelled:
            throw VideoImportError.cancelled
        default:
            throw AudioExtractionError.exportFailed(nil)
        }
    }

    func estimateDuration(_ videoURL: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: videoURL)
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            return nil
        }
    }
}

// MARK: - Errors

enum AudioExtractionError: LocalizedError {
    case compositionFailed
    case exportSessionFailed
    case exportFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .compositionFailed:
            return "Failed to create audio composition"
        case .exportSessionFailed:
            return "Failed to initialize audio export session"
        case .exportFailed(let error):
            if let error = error {
                return "Audio export failed: \(error.localizedDescription)"
            }
            return "Audio export failed with unknown error"
        }
    }
}

// MARK: - Cleanup Utility

extension AudioExtractionService {
    /// Clean up temporary audio files after processing
    static func cleanupTemporaryAudio(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
