//
//  ProcessingCheckpoint.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-11.
//

import Foundation
import SwiftData

/// Stores intermediate processing results for resume capability
@Model
final class ProcessingCheckpoint {
    // MARK: - Identity

    var id: UUID
    var createdAt: Date
    var lastUpdated: Date

    // MARK: - Phase 1: Audio Extraction

    /// Local file path to extracted audio file
    var audioFilePath: String?

    // MARK: - Phase 2: Transcription (CRITICAL - Most Expensive)

    /// Serialized TranscriptionResult JSON
    /// This is the most important checkpoint as transcription is ~70% of processing time
    var transcriptJSON: Data?

    // MARK: - Phase 3: Frame Analysis

    /// Serialized frame analysis data
    var framesJSON: Data?

    /// List of visual elements detected
    var visualElements: [String]?

    // MARK: - Phase 4: Structured Recipe

    /// Serialized structured recipe JSON (before augmentation)
    var structuredRecipeJSON: Data?

    // MARK: - ASMR Specific

    /// Serialized ASMR frame extraction data
    var asmrFramesJSON: Data?

    /// ASMR Pass 1 result (dish identification)
    var asmrDishIdentificationJSON: Data?

    /// ASMR Pass 2 result (ingredient analysis)
    var asmrIngredientAnalysisJSON: Data?

    // MARK: - Relationship

    /// Parent job this checkpoint belongs to
    var job: VideoProcessingJob?

    // MARK: - Initialization

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
}

// MARK: - Checkpoint Updates

extension ProcessingCheckpoint {
    /// Update checkpoint with audio extraction result
    func saveAudioExtraction(audioPath: String) {
        self.audioFilePath = audioPath
        self.lastUpdated = Date()
    }

    /// Update checkpoint with transcription result
    func saveTranscription(_ transcriptData: Data) {
        self.transcriptJSON = transcriptData
        self.lastUpdated = Date()
    }

    /// Update checkpoint with frame analysis result
    func saveFrameAnalysis(framesData: Data, visualElements: [String]) {
        self.framesJSON = framesData
        self.visualElements = visualElements
        self.lastUpdated = Date()
    }

    /// Update checkpoint with structured recipe
    func saveStructuredRecipe(_ recipeData: Data) {
        self.structuredRecipeJSON = recipeData
        self.lastUpdated = Date()
    }

    /// Update checkpoint with ASMR frame extraction
    func saveASMRFrames(_ framesData: Data) {
        self.asmrFramesJSON = framesData
        self.lastUpdated = Date()
    }

    /// Update checkpoint with ASMR dish identification
    func saveASMRDishIdentification(_ data: Data) {
        self.asmrDishIdentificationJSON = data
        self.lastUpdated = Date()
    }

    /// Update checkpoint with ASMR ingredient analysis
    func saveASMRIngredientAnalysis(_ data: Data) {
        self.asmrIngredientAnalysisJSON = data
        self.lastUpdated = Date()
    }
}

// MARK: - Checkpoint Validation

extension ProcessingCheckpoint {
    /// Check if audio extraction is complete
    var hasAudioExtraction: Bool {
        audioFilePath != nil
    }

    /// Check if transcription is complete (most important)
    var hasTranscription: Bool {
        transcriptJSON != nil
    }

    /// Check if frame analysis is complete
    var hasFrameAnalysis: Bool {
        framesJSON != nil
    }

    /// Check if structured recipe is complete
    var hasStructuredRecipe: Bool {
        structuredRecipeJSON != nil
    }

    /// Determine which phase to resume from
    var resumePhase: ProcessingPhase {
        if !hasAudioExtraction {
            return .extractingAudio
        } else if !hasTranscription {
            return .transcribing
        } else if !hasFrameAnalysis {
            return .analyzingFrames
        } else if !hasStructuredRecipe {
            return .structuringRecipe
        } else {
            return .augmenting
        }
    }

    /// Calculate progress based on completed checkpoints
    var estimatedProgress: Double {
        if hasStructuredRecipe {
            return 0.90
        } else if hasFrameAnalysis {
            return 0.80
        } else if hasTranscription {
            return 0.75
        } else if hasAudioExtraction {
            return 0.05
        } else {
            return 0.0
        }
    }
}
