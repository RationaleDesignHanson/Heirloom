//
//  VideoProcessingJob.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-11.
//

import Foundation
import SwiftData

/// Represents a video-to-recipe processing job that can run in the background
@Model
final class VideoProcessingJob {
    // MARK: - Identity

    var id: UUID
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?

    // MARK: - Video Information

    /// Local file path or PHAsset identifier
    var videoURL: String

    /// Type of video processing (standard or ASMR)
    var videoType: VideoType

    /// Optional user-provided caption/description
    var userCaption: String?

    /// Duration of the video in seconds
    var videoDuration: TimeInterval?

    /// SHA256 hash of video file for duplicate detection
    var videoHash: String?

    // MARK: - Status & Progress

    /// Current processing status
    var status: VideoProcessingStatus

    /// Current phase of processing
    var currentPhase: ProcessingPhase

    /// Progress from 0.0 to 1.0
    var progress: Double

    /// Error message if status is .failed
    var errorMessage: String?

    /// Number of times this job has been retried
    var retryCount: Int

    // MARK: - Checkpoints

    /// Checkpoint data for resume capability
    @Relationship(deleteRule: .cascade)
    var checkpoint: ProcessingCheckpoint?

    // MARK: - Results

    /// Serialized VideoRecipeExtraction result
    var extractionJSON: Data?

    /// Reference to saved Recipe (if user completed review)
    var recipeID: UUID?

    // MARK: - Credit Management (ASMR only)

    /// Number of credits charged (0 for standard, 5 for ASMR)
    var creditsCharged: Int

    /// Whether credits have been refunded after failure
    var creditsRefunded: Bool

    // MARK: - Attribution

    /// Original source URL (if from web)
    var sourceURL: String?

    /// Attribution text for source
    var sourceAttribution: String?

    // MARK: - Initialization

    init(
        videoURL: String,
        videoType: VideoType,
        userCaption: String? = nil,
        videoDuration: TimeInterval? = nil,
        videoHash: String? = nil,
        sourceURL: String? = nil,
        sourceAttribution: String? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.videoURL = videoURL
        self.videoType = videoType
        self.userCaption = userCaption
        self.videoDuration = videoDuration
        self.videoHash = videoHash
        self.sourceURL = sourceURL
        self.sourceAttribution = sourceAttribution

        // Initial state
        self.status = .pending
        self.currentPhase = .queued
        self.progress = 0.0
        self.retryCount = 0
        self.creditsCharged = 0
        self.creditsRefunded = false
    }
}

// MARK: - Enums

enum VideoProcessingStatus: String, Codable {
    case pending        // Job created, not started
    case processing     // Currently being processed
    case paused         // User paused processing
    case completed      // Processing finished, ready for review
    case saved          // User reviewed and saved recipe
    case failed         // Processing failed with error
    case cancelled      // User cancelled the job
}

enum VideoType: String, Codable {
    case standard       // Regular video processing
    case asmr           // ASMR video with 5-pass processing
}

enum ProcessingPhase: String, Codable {
    case queued                 // Waiting to start
    case extractingAudio        // Extracting audio from video
    case transcribing           // Transcribing audio to text
    case analyzingFrames        // Analyzing video frames
    case structuringRecipe      // Converting to structured recipe
    case augmenting            // Augmenting with similar recipes
    case complete              // All phases done
}

// MARK: - Computed Properties

extension VideoProcessingJob {
    /// Human-readable status text
    var statusText: String {
        switch status {
        case .pending:
            return "Waiting to start"
        case .processing:
            return currentPhase.displayName
        case .paused:
            return "Paused"
        case .completed:
            return "Ready to review"
        case .saved:
            return "Saved"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    /// Whether this job can be retried
    var canRetry: Bool {
        status == .failed && retryCount < 3
    }

    /// Whether this job can be cancelled
    var canCancel: Bool {
        status == .pending || status == .processing || status == .paused
    }

    /// Whether credits should be refunded for this job
    var shouldRefundCredits: Bool {
        guard videoType == .asmr else { return false }
        guard creditsCharged > 0 else { return false }
        guard !creditsRefunded else { return false }
        guard status == .failed else { return false }

        // Only refund if failure occurred BEFORE structuring phase
        // (i.e., during audio extraction, transcription, or frame analysis)
        let refundablePhases: [ProcessingPhase] = [
            .queued, .extractingAudio, .transcribing, .analyzingFrames
        ]
        return refundablePhases.contains(currentPhase)
    }
}

extension ProcessingPhase {
    /// Display name for UI
    var displayName: String {
        switch self {
        case .queued:
            return "Queued"
        case .extractingAudio:
            return "Extracting audio"
        case .transcribing:
            return "Transcribing"
        case .analyzingFrames:
            return "Analyzing frames"
        case .structuringRecipe:
            return "Structuring recipe"
        case .augmenting:
            return "Augmenting"
        case .complete:
            return "Complete"
        }
    }

    /// Approximate progress value for this phase
    var progressValue: Double {
        switch self {
        case .queued:
            return 0.0
        case .extractingAudio:
            return 0.05
        case .transcribing:
            return 0.40  // Middle of transcription (0.05 to 0.75)
        case .analyzingFrames:
            return 0.80
        case .structuringRecipe:
            return 0.90
        case .augmenting:
            return 0.95
        case .complete:
            return 1.0
        }
    }
}
