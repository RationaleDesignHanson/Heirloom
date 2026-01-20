import Foundation

/// Three-tier extraction cascade for video imports
enum ExtractionMode: String, Codable {
    case audioTranscript    // Tier 1: Free - good audio
    case onScreenText       // Tier 2: Free - OCR visible text
    case visualFrames       // Tier 3: Premium - full frame analysis

    var displayName: String {
        switch self {
        case .audioTranscript: return "Audio Narration"
        case .onScreenText: return "On-Screen Recipe"
        case .visualFrames: return "Visual Analysis"
        }
    }

    var iconSystemName: String {
        switch self {
        case .audioTranscript: return "waveform"
        case .onScreenText: return "text.viewfinder"
        case .visualFrames: return "eye"
        }
    }

    /// Whether this mode requires premium subscription
    var requiresPremium: Bool {
        switch self {
        case .audioTranscript, .onScreenText: return false
        case .visualFrames: return true
        }
    }

    /// User-facing description of why this mode is used
    var userDescription: String {
        switch self {
        case .audioTranscript:
            return "Extracting recipe from spoken instructions"
        case .onScreenText:
            return "Extracting recipe from visible text in video"
        case .visualFrames:
            return "Analyzing video frames to identify recipe (premium feature)"
        }
    }
}
