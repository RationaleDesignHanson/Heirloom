//
//  ASMRRecipeExtraction.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import Foundation

// Note: VideoRecipeModels.swift defines VideoRecipeExtraction, VideoImportMetadata, VideoSourceAttribution
// Note: VideoProcessingProtocols.swift defines StructuredRecipe, ExtractedIngredient, ExtractedStep, TranscriptionResult

// MARK: - Main Extraction Result

/// ASMR video processing uses the same VideoRecipeExtraction as regular videos
/// The only difference is the processing method (vision-only vs audio transcription)
typealias ASMRRecipeExtraction = VideoRecipeExtraction

// MARK: - ASMR-Specific Metadata Extension

extension VideoImportMetadata {
    /// Create metadata for ASMR (vision-only) processing
    static func forASMR(
        userCaption: String,
        videoDuration: TimeInterval,
        passResults: ASMR5PassResults,
        processingTime: TimeInterval,
        processingCost: Decimal
    ) -> VideoImportMetadata {
        return VideoImportMetadata(
            attribution: VideoSourceAttribution(
                platform: .cameraRoll,
                captionText: userCaption,
                notes: "ASMR/Silent video - vision-only processing",
                importDate: Date(),
                hasPermission: true
            ),
            videoDuration: videoDuration,
            transcriptionProvider: "Vision-Only (ASMR)",
            transcriptionConfidence: passResults.overallConfidence,
            processingCost: processingCost,
            processingTime: processingTime,
            transcriptText: nil, // No audio transcription
            detectedVisualElements: passResults.visualElementsSummary,
            processedAt: Date()
        )
    }
}

// MARK: - Sound Quality Enum (moved from old ASMRRecipeExtraction)

enum SoundQuality: String, Codable {
    case silent          // Pure ASMR, minimal sound
    case ambientOnly     // Kitchen sounds, no speech
    case musicOnly       // Background music, no speech
    case unclear         // Can't determine
}

// MARK: - ASMR 5-Pass Results (Internal Processing Details)

/// Detailed results from 5-pass vision processing
/// Used during processing, then summarized into VideoRecipeExtraction
struct ASMR5PassResults: Codable {
    let dishIdentification: DishIdentificationResult
    let ingredientDetection: IngredientDetectionResult
    let culinaryInference: CulinaryInferenceResult
    let actionRecognition: ActionRecognitionResult
    let synthesis: SynthesisResult

    var overallConfidence: Double
    var totalCost: Double
    var totalTokens: Int

    /// Summarize pass findings as visual elements for metadata
    var visualElementsSummary: [String] {
        var elements: [String] = []
        elements.append("Dish: \(dishIdentification.dishName) (\(dishIdentification.dishType))")
        elements.append("Visible ingredients: \(ingredientDetection.detectedIngredients.count)")
        elements.append("Inferred ingredients: \(culinaryInference.inferredIngredients.count)")
        elements.append("Actions detected: \(actionRecognition.recognizedActions.count)")
        elements.append("Techniques: \(actionRecognition.cookingTechniques.joined(separator: ", "))")
        return elements
    }
}

// MARK: - Pass 1: Dish Identification

/// Result of Pass 1: Dish identification from final frames
struct DishIdentificationResult: Codable {
    let dishName: String
    let dishType: String           // "Italian pasta", "Asian stir-fry", etc.
    let servingStyle: String       // "plated", "family-style", "bowl"
    let visualComplexity: String   // "simple", "moderate", "complex"
    let confidence: Double
    let reasoning: String
    let analyzedFrames: [Int]      // Frame indices analyzed
}

// MARK: - Pass 2: Ingredient Detection

/// Result of Pass 2: Visible ingredient detection
struct IngredientDetectionResult: Codable {
    let detectedIngredients: [DetectedIngredient]
    let transformations: [IngredientTransformation]
    let confidence: Double

    struct DetectedIngredient: Codable {
        let name: String
        let visualState: String        // "raw", "chopped", "cooked"
        let estimatedQuantity: String? // "1 cup", "2 pieces", "handful"
        let confidence: Double
        let firstSeen: TimeInterval
        let lastSeen: TimeInterval
        let frameIndices: [Int]
    }

    struct IngredientTransformation: Codable {
        let ingredient: String
        let from: String               // "raw"
        let to: String                 // "caramelized"
        let timestamp: TimeInterval
        let technique: String?         // "sautéing"
    }
}

// MARK: - Pass 3: Culinary Inference

/// Result of Pass 3: Culinary inference for hidden ingredients
struct CulinaryInferenceResult: Codable {
    let inferredIngredients: [InferredIngredient]
    let inferredSeasonings: [InferredSeasoning]
    let confidence: Double

    struct InferredIngredient: Codable {
        let name: String
        let reasoning: String          // "Typical for this dish type"
        let necessity: String          // "essential", "likely", "possible"
        let estimatedQuantity: String?
        let confidence: Double
    }

    struct InferredSeasoning: Codable {
        let name: String
        let timing: String             // "during cooking", "at end", "to taste"
        let reasoning: String
        let confidence: Double
    }
}

// MARK: - Pass 4: Action Recognition

/// Result of Pass 4: Cooking action recognition
struct ActionRecognitionResult: Codable {
    let recognizedActions: [RecognizedAction]
    let cookingTechniques: [String]
    let equipment: [String]
    let confidence: Double

    struct RecognizedAction: Codable {
        let action: String             // "sautéing", "chopping", "stirring"
        let target: String?            // What's being acted upon
        let timestamp: TimeInterval
        let duration: TimeInterval?
        let technique: String?
        let confidence: Double
    }
}

// MARK: - Pass 5: Synthesis & Validation

/// Result of Pass 5: Final synthesis & validation
struct SynthesisResult: Codable {
    let finalRecipe: StructuredRecipe
    let validationNotes: [ValidationNote]
    let confidence: Double
    let completeness: Double           // 0.0-1.0, how complete the recipe is

    struct ValidationNote: Codable {
        let type: NoteType
        let message: String
        let severity: Severity

        enum NoteType: String, Codable {
            case missingIngredient
            case ambiguousTiming
            case inferredQuantity
            case technicalGap
        }

        enum Severity: String, Codable {
            case info
            case warning
            case critical
        }
    }
}

// MARK: - ASMR Processing Error

/// Errors specific to ASMR processing
enum ASMRProcessingError: LocalizedError {
    case unsuitable(reason: String)
    case insufficientFrames
    case structuringFailed(underlying: Error)
    case cacheError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsuitable(let reason):
            return "Video not suitable for ASMR processing: \(reason)"
        case .insufficientFrames:
            return "Could not extract enough frames for analysis"
        case .structuringFailed(let error):
            return "Recipe structuring failed: \(error.localizedDescription)"
        case .cacheError(let error):
            return "Cache error: \(error.localizedDescription)"
        }
    }
}
