//
//  ASMRProcessingProtocols.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import Foundation
import UIKit

// MARK: - 5-Pass Processing Pipeline

/// Enum representing the 5-pass ASMR vision processing pipeline
enum ASMRProcessingPass: Int, CaseIterable, Codable {
    case identifying = 0    // Dish identification from final frames
    case detecting = 1      // Visible ingredient detection
    case inferring = 2      // Culinary inference (seasonings, techniques)
    case analyzing = 3      // Cooking action recognition
    case validating = 4     // Synthesis & validation

    var displayName: String {
        switch self {
        case .identifying: return "Identifying Dish"
        case .detecting: return "Detecting Ingredients"
        case .inferring: return "Inferring Techniques"
        case .analyzing: return "Analyzing Actions"
        case .validating: return "Validating Recipe"
        }
    }

    /// Weight of this pass for calculating overall progress (sums to 0.75 for all passes)
    var progressWeight: Double {
        switch self {
        case .identifying: return 0.15  // 15% of total progress
        case .detecting: return 0.25    // 25%
        case .inferring: return 0.25    // 25%
        case .analyzing: return 0.20    // 20%
        case .validating: return 0.15   // 15%
        }
    }
}

// MARK: - Processing State

/// State machine for ASMR processing pipeline
enum ASMRProcessingState: Equatable {
    case idle
    case preparingVideo(progress: Double)
    case analyzingSounds(progress: Double)
    case extractingFrames(progress: Double)
    case processingPass(ASMRProcessingPass, findings: [String])
    case completed(ASMRRecipeExtraction)
    case failed(Error)
    case cancelled

    static func == (lhs: ASMRProcessingState, rhs: ASMRProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.preparingVideo(let p1), .preparingVideo(let p2)): return p1 == p2
        case (.analyzingSounds(let p1), .analyzingSounds(let p2)): return p1 == p2
        case (.extractingFrames(let p1), .extractingFrames(let p2)): return p1 == p2
        case (.processingPass(let pass1, _), .processingPass(let pass2, _)): return pass1 == pass2
        case (.completed, .completed): return true
        case (.cancelled, .cancelled): return true
        case (.failed, .failed): return true
        default: return false
        }
    }
}

// MARK: - Processor Protocol

/// Protocol for ASMR video processing
/// Note: Credit handling is done by callers (VideoProcessingJobManager), not by the processor
@MainActor
protocol ASMRProcessorProtocol: AnyObject {
    var state: ASMRProcessingState { get }
    var progress: Double { get }
    var currentPass: ASMRProcessingPass? { get }

    func process(
        videoURL: URL,
        userCaption: String,
        videoHash: String?,
        skipSoundAnalysis: Bool,
        dishNameHint: String?
    ) async throws -> ASMRRecipeExtraction

    func cancel()
}

extension ASMRProcessorProtocol {
    func process(
        videoURL: URL,
        userCaption: String,
        videoHash: String?,
        skipSoundAnalysis: Bool = false,
        dishNameHint: String? = nil
    ) async throws -> ASMRRecipeExtraction {
        try await process(
            videoURL: videoURL,
            userCaption: userCaption,
            videoHash: videoHash,
            skipSoundAnalysis: skipSoundAnalysis,
            dishNameHint: dishNameHint
        )
    }
}

// MARK: - Pass Result

/// Result of a single ASMR processing pass
struct ASMRPassResult {
    let pass: ASMRProcessingPass
    let findings: [Finding]
    let confidence: Double
    let tokensUsed: Int
    let cost: Double

    struct Finding: Codable {
        let type: FindingType
        let value: String
        let timestamp: TimeInterval?
        let confidence: Double
        let reasoning: String?

        enum FindingType: String, Codable {
            case dishName
            case ingredient
            case technique
            case action
            case timing
            case temperature
            case equipment
        }
    }
}

// MARK: - Sound Analysis

/// Result of sound suitability analysis
struct SoundAnalysisResult {
    let hasSpeech: Bool
    let hasMusic: Bool
    let soundQuality: SoundQuality
    let confidence: Double
    let suitable: Bool
    let reasoning: String
}

/// Audio characteristics from analysis
struct AudioCharacteristics {
    let hasSpeech: Bool
    let hasMusic: Bool
    let quality: SoundQuality
    let speechConfidence: Double
    let musicConfidence: Double
    let confidence: Double
}

// MARK: - Frame Extraction

/// Result of frame extraction from video
struct FrameExtractionResult {
    let finalFrames: [ExtractedFrame]
    let cookingFrames: [ExtractedFrame]
    let setupFrames: [ExtractedFrame]
    let totalFrames: Int

    var allFrames: [ExtractedFrame] {
        setupFrames + cookingFrames + finalFrames
    }
}

/// Single extracted frame with metadata
struct ExtractedFrame {
    let image: UIImage
    let timestamp: TimeInterval
    let frameIndex: Int
    let frameType: FrameType
}

/// Type of frame based on position in video
enum FrameType: String, Codable {
    case setup      // First 60s - ingredients/prep
    case cooking    // Middle 60% - cooking actions
    case final      // Last 30s - finished dish
}

// MARK: - ASMR Extraction (Forward Declaration)

// Full definition in ASMRRecipeExtraction.swift
// This protocol file imports that file for the ASMRRecipeExtraction type
