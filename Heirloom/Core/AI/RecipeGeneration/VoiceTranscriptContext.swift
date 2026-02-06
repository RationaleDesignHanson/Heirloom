//
//  VoiceTranscriptContext.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-05.
//

import Foundation

/// Structured output from AI-powered voice transcript analysis.
/// Used as the schema for the transcript parsing AI call (low temp, cheap model).
struct VoiceTranscriptContext: Codable {
    /// The primary dish name extracted from the transcript
    let dishName: String

    /// Specific ingredients mentioned (e.g., ["fresh thyme", "chicken thighs"])
    let ingredients: [String]?

    /// Cuisine or regional style hints (e.g., ["Southern", "Creole"])
    let cuisineHints: [String]?

    /// Descriptive qualities mentioned (e.g., ["creamy", "crispy", "light"])
    let descriptions: [String]?

    /// Cooking technique preferences (e.g., ["slow-cooked", "grilled", "pan-seared"])
    let techniquePreferences: [String]?

    /// Serving size if mentioned (e.g., "6 people", "family of 4")
    let servingSize: String?

    /// Any additional context that doesn't fit other fields
    let additionalContext: String?

    /// Confidence score from 0.0 to 1.0 indicating how well the transcript was understood
    let confidence: Double
}
