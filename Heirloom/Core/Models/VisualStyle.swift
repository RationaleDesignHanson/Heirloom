//
//  VisualStyle.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import Foundation
import SwiftUI

/// Visual style for AI-generated collection images
enum VisualStyle: String, CaseIterable, Identifiable {
    case classicCookbook = "classic_cookbook"
    case studioPhotography = "studio_photography"
    case watercolorArt = "watercolor_art"
    case modernMinimal = "modern_minimal"
    case vintageIllustration = "vintage_illustration"

    var id: String { rawValue }

    /// Display name shown in UI
    var displayName: String {
        switch self {
        case .classicCookbook:
            return "Classic Cookbook"
        case .studioPhotography:
            return "Studio Photography"
        case .watercolorArt:
            return "Watercolor Art"
        case .modernMinimal:
            return "Modern Minimal"
        case .vintageIllustration:
            return "Vintage Illustration"
        }
    }

    /// Short description of the style
    var description: String {
        switch self {
        case .classicCookbook:
            return "Warm, nostalgic cookbook photography"
        case .studioPhotography:
            return "Clean, professional food photography"
        case .watercolorArt:
            return "Soft, artistic watercolor paintings"
        case .modernMinimal:
            return "Sleek, contemporary aesthetic"
        case .vintageIllustration:
            return "Retro-style hand-drawn illustrations"
        }
    }

    /// Icon representing the style
    var iconName: String {
        switch self {
        case .classicCookbook:
            return "book.closed.fill"
        case .studioPhotography:
            return "camera.fill"
        case .watercolorArt:
            return "paintbrush.fill"
        case .modernMinimal:
            return "square.grid.2x2"
        case .vintageIllustration:
            return "paintpalette.fill"
        }
    }

    /// AI prompt modifier for this style
    var promptModifier: String {
        switch self {
        case .classicCookbook:
            return "Style: vintage cookbook photography, warm sepia tones, soft natural lighting, nostalgic atmosphere, heirloom quality, traditional culinary aesthetic, no text or words"
        case .studioPhotography:
            return "Style: professional food photography, overhead shot, studio lighting, clean white background, sharp focus, commercial quality, minimalist composition, no text or words"
        case .watercolorArt:
            return "Style: watercolor illustration, soft brushstrokes, gentle color washes, artistic interpretation, painted aesthetic, warm muted tones, hand-painted quality, no text or words"
        case .modernMinimal:
            return "Style: modern minimalist aesthetic, clean lines, bright natural lighting, contemporary design, sleek presentation, airy composition, Scandinavian influence, no text or words"
        case .vintageIllustration:
            return "Style: vintage hand-drawn illustration, retro cookbook style, pen and ink with color, classic culinary artwork, 1950s-1970s aesthetic, nostalgic charm, no text or words"
        }
    }

    /// Optional card color scheme modifications
    var cardAccentColor: Color? {
        switch self {
        case .classicCookbook:
            return Color(red: 0.6, green: 0.4, blue: 0.2) // Warm brown
        case .studioPhotography:
            return nil // Use default
        case .watercolorArt:
            return Color(red: 0.7, green: 0.5, blue: 0.7) // Soft purple
        case .modernMinimal:
            return Color(red: 0.2, green: 0.2, blue: 0.2) // Charcoal
        case .vintageIllustration:
            return Color(red: 0.8, green: 0.6, blue: 0.4) // Vintage cream
        }
    }

    /// Text overlay opacity adjustment
    var textOverlayOpacity: Double {
        switch self {
        case .classicCookbook:
            return 0.85
        case .studioPhotography:
            return 0.75
        case .watercolorArt:
            return 0.8
        case .modernMinimal:
            return 0.7
        case .vintageIllustration:
            return 0.85
        }
    }
}

/// Configuration manager for visual style preferences
@Observable
class VisualStyleConfiguration {
    private static let storageKey = "visual_style_preference"

    var selectedStyle: VisualStyle {
        didSet {
            UserDefaults.standard.set(selectedStyle.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        // Load saved preference or default to watercolor
        if let savedRawValue = UserDefaults.standard.string(forKey: Self.storageKey),
           let savedStyle = VisualStyle(rawValue: savedRawValue) {
            self.selectedStyle = savedStyle
        } else {
            self.selectedStyle = .watercolorArt // Default
        }
    }
}
