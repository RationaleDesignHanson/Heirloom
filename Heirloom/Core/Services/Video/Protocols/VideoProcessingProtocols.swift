//
//  VideoProcessingProtocols.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Audio Extraction Protocol

/// Protocol for extracting audio from video files
protocol AudioExtractionServiceProtocol {
    /// Extract audio track from video file
    /// - Parameter videoURL: Local file URL to video
    /// - Returns: URL to extracted audio file (m4a format)
    func extractAudio(from videoURL: URL) async throws -> URL

    /// Estimate video duration without full processing
    /// - Parameter videoURL: Local file URL to video
    /// - Returns: Duration in seconds, or nil if unable to determine
    func estimateDuration(_ videoURL: URL) async -> TimeInterval?
}

// MARK: - Transcription Protocol

/// Provider for transcription services
enum TranscriptionProvider: String, Codable {
    case speechAnalyzer = "iOS SpeechAnalyzer"  // iOS 26+ (future)
    case whisperKit = "WhisperKit"              // Current fallback

    var displayName: String {
        return rawValue
    }
}

/// Result of audio transcription
struct TranscriptionResult: Codable {
    /// Full transcript text
    let text: String

    /// Segmented transcript with timestamps
    let segments: [TranscriptSegment]

    /// Overall confidence score (0.0 - 1.0)
    let confidence: Double

    /// Provider used for transcription
    let provider: TranscriptionProvider

    /// Language detected (ISO 639-1 code)
    let language: String

    init(text: String, segments: [TranscriptSegment], confidence: Double, provider: TranscriptionProvider, language: String = "en") {
        self.text = text
        self.segments = segments
        self.confidence = confidence
        self.provider = provider
        self.language = language
    }
}

/// Segment of transcript with timing information
struct TranscriptSegment: Codable {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

/// Protocol for transcription services (iOS 26 SpeechAnalyzer OR WhisperKit)
@MainActor
protocol TranscriptionServiceProtocol {
    /// Provider being used
    var provider: TranscriptionProvider { get }

    /// Whether this service is available on current device/OS
    var isAvailable: Bool { get }

    /// Transcribe audio file to text
    /// - Parameter audioURL: Local file URL to audio
    /// - Returns: Transcription result with text and metadata
    func transcribe(audioURL: URL) async throws -> TranscriptionResult
}

// MARK: - Frame Analysis Protocol

/// Protocol for extracting and analyzing video frames
protocol FrameAnalysisServiceProtocol {
    /// Extract key frames from video at specified intervals
    /// - Parameters:
    ///   - videoURL: Local file URL to video
    ///   - count: Number of frames to extract (evenly distributed)
    /// - Returns: Array of extracted frames as UIImages
    func extractKeyFrames(from videoURL: URL, count: Int) async throws -> [UIImage]

    /// Analyze frames for recipe-relevant text (temperatures, times, measurements)
    /// - Parameter frames: Images to analyze
    /// - Returns: Array of detected text strings
    func analyzeForRecipeElements(_ frames: [UIImage]) async throws -> [String]
}

// MARK: - Recipe Structuring Protocol

/// Structured recipe extracted from video
struct StructuredRecipe: Codable {
    let title: String
    let description: String?
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let ingredients: [ExtractedIngredient]
    let steps: [ExtractedStep]
    let overallConfidence: Double
    let warnings: [String]
}

/// Ingredient extracted from transcript
struct ExtractedIngredient: Codable {
    let originalText: String      // Raw text from transcript
    let item: String              // Parsed ingredient name
    let quantity: String?         // Parsed quantity (can be "to taste", "1-2", etc.)
    let unit: String?             // Parsed unit
    let preparation: String?      // "chopped", "diced", etc.
    let confidence: ExtractionConfidence
}

/// Step extracted from transcript
struct ExtractedStep: Codable {
    let instruction: String
    let duration: String?         // "10 minutes", "until golden", etc.
    let temperature: String?      // "350°F", "medium heat", etc.
    let confidence: ExtractionConfidence
}

/// Confidence level for extracted data
enum ExtractionConfidence: String, Codable {
    case explicit     // 0.95+ - clearly stated
    case visual       // 0.90+ - confirmed by video frames
    case inferred     // 0.70-0.85 - derived from context
    case approximate  // 0.50-0.70 - converted from imprecise
    case unknown      // <0.50 - needs review

    var numericValue: Double {
        switch self {
        case .explicit: return 0.95
        case .visual: return 0.90
        case .inferred: return 0.75
        case .approximate: return 0.60
        case .unknown: return 0.40
        }
    }

    var displayName: String {
        switch self {
        case .explicit: return "High"
        case .visual: return "High"
        case .inferred: return "Medium"
        case .approximate: return "Low"
        case .unknown: return "Very Low"
        }
    }
}

/// Protocol for structuring recipes from transcript + visual data
@MainActor
protocol RecipeStructurerProtocol {
    /// Structure a recipe from transcript and visual elements
    /// - Parameters:
    ///   - transcript: Transcription result from audio
    ///   - visualElements: Text detected from video frames
    /// - Returns: Structured recipe ready for review
    func structure(
        transcript: TranscriptionResult,
        visualElements: [String]
    ) async throws -> StructuredRecipe
}

// MARK: - Video Recipe Processor Protocol

/// Processing state for video import
enum ProcessingState {
    case idle
    case extractingAudio
    case transcribing(progress: Double)
    case analyzingFrames
    case structuringRecipe
    case augmentingWithSimilarRecipes  // NEW: Step 5.5
    case reviewing(StructuredRecipe)
    case completed
    case failed(String)  // Error message

    var displayTitle: String {
        switch self {
        case .idle: return "Ready"
        case .extractingAudio: return "Extracting Audio"
        case .transcribing: return "Transcribing Video"
        case .analyzingFrames: return "Analyzing Frames"
        case .structuringRecipe: return "Creating Recipe"
        case .augmentingWithSimilarRecipes: return "Finding Similar Recipes"
        case .reviewing: return "Review Recipe"
        case .completed: return "Complete"
        case .failed: return "Error"
        }
    }

    var displaySubtitle: String {
        switch self {
        case .idle: return "Select a video to begin"
        case .extractingAudio: return "Preparing audio for transcription..."
        case .transcribing(let progress):
            if progress > 0 {
                return "Listening to the video... \(Int(progress * 100))%"
            }
            return "This may take a few minutes for longer videos"
        case .analyzingFrames: return "Looking for on-screen text..."
        case .structuringRecipe: return "Organizing ingredients and steps..."
        case .augmentingWithSimilarRecipes: return "Improving recipe accuracy with similar recipes..."
        case .reviewing: return "Review the extracted recipe before saving"
        case .completed: return "Recipe ready to save"
        case .failed(let error): return error
        }
    }
}

/// Master coordinator for video recipe processing
@MainActor
protocol VideoRecipeProcessorProtocol: ObservableObject {
    /// Current processing state
    var state: ProcessingState { get }

    /// Overall progress (0.0 - 1.0)
    var progress: Double { get }

    /// Whether processing can be cancelled
    var canCancel: Bool { get }

    /// Process a video file to extract recipe
    /// - Parameter videoURL: Local file URL to video
    /// - Returns: Complete extraction result
    func process(videoURL: URL) async throws -> VideoRecipeExtraction

    /// Cancel ongoing processing
    func cancel()
}

// MARK: - Error Types

/// Errors that can occur during video import
enum VideoImportError: LocalizedError {
    case invalidVideoURL
    case noAudioTrack
    case transcriptionUnavailable
    case transcriptionFailed(underlying: Error)
    case framExtractionFailed(underlying: Error)
    case recipeStructuringFailed(underlying: Error)
    case cancelled
    case unsupportedSource(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidVideoURL:
            return "The video file is not valid or cannot be accessed"
        case .noAudioTrack:
            return "This video doesn't contain audio. Please select a video with spoken instructions."
        case .transcriptionUnavailable:
            return "Transcription service is not available on this device"
        case .transcriptionFailed(let error):
            return "Failed to transcribe audio: \(error.localizedDescription)"
        case .framExtractionFailed(let error):
            return "Failed to analyze video frames: \(error.localizedDescription)"
        case .recipeStructuringFailed(let error):
            return "Failed to extract recipe: \(error.localizedDescription)"
        case .cancelled:
            return "Processing was cancelled"
        case .unsupportedSource(let message):
            return message
        }
    }
}
