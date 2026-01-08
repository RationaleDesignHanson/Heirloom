//
//  VideoRecipeModels.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//

import Foundation

// MARK: - Video Source Attribution

/// Attribution information for video sources
struct VideoSourceAttribution: Codable, Equatable {
    /// Creator/channel name (e.g., "Binging with Babish", "Gordon Ramsay")
    var creatorName: String?

    /// Original video title
    var videoTitle: String?

    /// Platform where video was found (YouTube, Instagram, TikTok, etc.)
    var platform: VideoPlatform?

    /// Original video URL (if applicable and not a direct download)
    var sourceURL: String?

    /// Additional notes about the source
    var notes: String?

    /// Date when video was imported
    var importDate: Date

    /// Whether user has permission/rights to use this video
    /// (Important for App Store compliance)
    var hasPermission: Bool

    init(
        creatorName: String? = nil,
        videoTitle: String? = nil,
        platform: VideoPlatform? = nil,
        sourceURL: String? = nil,
        notes: String? = nil,
        importDate: Date = Date(),
        hasPermission: Bool = true  // Default true for camera roll videos
    ) {
        self.creatorName = creatorName
        self.videoTitle = videoTitle
        self.platform = platform
        self.sourceURL = sourceURL
        self.notes = notes
        self.importDate = importDate
        self.hasPermission = hasPermission
    }

    /// Display string for attribution (e.g., "Recipe by Gordon Ramsay")
    var displayString: String? {
        if let creator = creatorName {
            return "Recipe by \(creator)"
        }
        if let title = videoTitle {
            return "From: \(title)"
        }
        return nil
    }

    /// Full attribution text for recipe card
    var fullAttributionText: String {
        var parts: [String] = []

        if let creator = creatorName {
            parts.append("Creator: \(creator)")
        }
        if let title = videoTitle {
            parts.append("Video: \(title)")
        }
        if let platform = platform {
            parts.append("Platform: \(platform.displayName)")
        }
        if let url = sourceURL {
            parts.append("Source: \(url)")
        }

        return parts.isEmpty ? "Imported from video" : parts.joined(separator: "\n")
    }
}

/// Video platform enumeration
enum VideoPlatform: String, Codable, CaseIterable {
    case youtube = "youtube"
    case instagram = "instagram"
    case tiktok = "tiktok"
    case facebook = "facebook"
    case twitter = "twitter"
    case cameraRoll = "camera_roll"
    case other = "other"

    var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .facebook: return "Facebook"
        case .twitter: return "Twitter/X"
        case .cameraRoll: return "Camera Roll"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        case .facebook: return "f.square.fill"
        case .twitter: return "bubble.left.and.bubble.right.fill"
        case .cameraRoll: return "photo.fill"
        case .other: return "video.fill"
        }
    }
}

// MARK: - Video Import Metadata

/// Metadata about the video import process
struct VideoImportMetadata: Codable {
    /// Attribution information for the video source
    var attribution: VideoSourceAttribution

    /// Video duration in seconds
    var videoDuration: TimeInterval

    /// Transcription provider used
    var transcriptionProvider: String

    /// Transcription confidence (0.0 - 1.0)
    var transcriptionConfidence: Double

    /// Processing cost in USD
    var processingCost: Decimal

    /// Processing time in seconds
    var processingTime: TimeInterval

    /// Full transcript text (for debugging/reference)
    var transcriptText: String?

    /// Visual elements detected from frames
    var detectedVisualElements: [String]?

    /// When the video was processed
    var processedAt: Date

    init(
        attribution: VideoSourceAttribution,
        videoDuration: TimeInterval,
        transcriptionProvider: String,
        transcriptionConfidence: Double,
        processingCost: Decimal,
        processingTime: TimeInterval,
        transcriptText: String? = nil,
        detectedVisualElements: [String]? = nil,
        processedAt: Date = Date()
    ) {
        self.attribution = attribution
        self.videoDuration = videoDuration
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionConfidence = transcriptionConfidence
        self.processingCost = processingCost
        self.processingTime = processingTime
        self.transcriptText = transcriptText
        self.detectedVisualElements = detectedVisualElements
        self.processedAt = processedAt
    }

    /// Temporary storage in Recipe.notes (for VideoLab phase)
    func encodeForNotes() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let jsonData = try? encoder.encode(self),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "VIDEO_METADATA: [encoding failed]"
        }
        return "VIDEO_METADATA:\n\(jsonString)\n\n"
    }

    /// Decode from Recipe.notes (for VideoLab phase)
    static func decodeFromNotes(_ notes: String) -> VideoImportMetadata? {
        guard let range = notes.range(of: "VIDEO_METADATA:\n"),
              let endRange = notes.range(of: "\n\n", range: range.upperBound..<notes.endIndex) else {
            return nil
        }

        let jsonString = notes[range.upperBound..<endRange.lowerBound]
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(VideoImportMetadata.self, from: jsonData)
    }
}

// MARK: - Video Recipe Extraction (Complete Result)

/// Complete result from video processing pipeline
struct VideoRecipeExtraction {
    let structuredRecipe: StructuredRecipe
    let transcript: TranscriptionResult
    let visualElements: [String]
    let metadata: VideoImportMetadata
    let processingTime: TimeInterval
    let estimatedCost: Decimal

    init(
        structuredRecipe: StructuredRecipe,
        transcript: TranscriptionResult,
        visualElements: [String],
        metadata: VideoImportMetadata,
        processingTime: TimeInterval,
        estimatedCost: Decimal
    ) {
        self.structuredRecipe = structuredRecipe
        self.transcript = transcript
        self.visualElements = visualElements
        self.metadata = metadata
        self.processingTime = processingTime
        self.estimatedCost = estimatedCost
    }
}

// MARK: - Helper Extensions

extension VideoRecipeExtraction {
    /// Whether extraction quality is good enough to save without review
    var isHighQuality: Bool {
        return structuredRecipe.overallConfidence >= 0.8 &&
               transcript.confidence >= 0.8
    }

    /// Warning messages for user review
    var warnings: [String] {
        var warnings: [String] = []

        if structuredRecipe.overallConfidence < 0.6 {
            warnings.append("Low confidence extraction - please review carefully")
        }

        if transcript.confidence < 0.6 {
            warnings.append("Audio quality was poor - transcription may be inaccurate")
        }

        let lowConfidenceIngredients = structuredRecipe.ingredients.filter {
            $0.confidence == .approximate || $0.confidence == .unknown
        }
        if !lowConfidenceIngredients.isEmpty {
            warnings.append("\(lowConfidenceIngredients.count) ingredient(s) need verification")
        }

        if structuredRecipe.ingredients.isEmpty {
            warnings.append("No ingredients detected - please add them manually")
        }

        if structuredRecipe.steps.isEmpty {
            warnings.append("No instructions detected - please add them manually")
        }

        return warnings + structuredRecipe.warnings
    }
}

// MARK: - Structured Recipe Extensions

extension StructuredRecipe {
    /// Whether this recipe is complete enough to save
    var isComplete: Bool {
        return !title.isEmpty &&
               !ingredients.isEmpty &&
               !steps.isEmpty
    }

    /// Count of low-confidence fields requiring review
    var fieldsRequiringReview: Int {
        let lowConfidenceIngredients = ingredients.filter {
            $0.confidence == .approximate || $0.confidence == .unknown
        }.count

        let lowConfidenceSteps = steps.filter {
            $0.confidence == .approximate || $0.confidence == .unknown
        }.count

        return lowConfidenceIngredients + lowConfidenceSteps
    }
}

// MARK: - Extracted Ingredient Extensions

extension ExtractedIngredient {
    /// Display string for ingredient (e.g., "2 cups flour, sifted")
    var displayString: String {
        var parts: [String] = []

        if let quantity = quantity {
            parts.append(quantity)
        }
        if let unit = unit {
            parts.append(unit)
        }
        parts.append(item)
        if let prep = preparation {
            parts.append(prep)
        }

        return parts.joined(separator: " ")
    }

    /// Whether this ingredient needs user review
    var needsReview: Bool {
        return confidence == .approximate || confidence == .unknown
    }
}

// MARK: - Extracted Step Extensions

extension ExtractedStep {
    /// Display string for step with timing (e.g., "Mix ingredients (5 minutes)")
    var displayString: String {
        var text = instruction

        if let duration = duration {
            text += " (\(duration))"
        }
        if let temp = temperature {
            text += " at \(temp)"
        }

        return text
    }

    /// Whether this step needs user review
    var needsReview: Bool {
        return confidence == .approximate || confidence == .unknown
    }
}
