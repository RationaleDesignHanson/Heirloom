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
    /// Optimized for Flux model while maintaining DALL-E compatibility
    var promptModifier: String {
        switch self {
        case .classicCookbook:
            return "vintage cookbook food photography, warm golden hour lighting, rustic wooden table, soft focus background, nostalgic cozy atmosphere, high quality, detailed, 8k resolution, no text no labels no words"
        case .studioPhotography:
            return "professional food photography, overhead flat lay, studio lighting, clean white marble background, sharp focus, commercial advertising quality, minimalist composition, high quality, detailed, 8k resolution, no text no labels no words"
        case .watercolorArt:
            return "beautiful watercolor food illustration, soft artistic brushstrokes, gentle pastel color palette, hand-painted aesthetic, warm muted tones, artistic interpretation, high quality detailed artwork, no text no labels no words"
        case .modernMinimal:
            return "modern minimalist food photography, bright natural daylight, clean contemporary styling, negative space, Scandinavian aesthetic, sleek presentation, high quality, sharp detail, 8k resolution, no text no labels no words"
        case .vintageIllustration:
            return "vintage hand-drawn food illustration, 1960s cookbook style, pen and ink with watercolor, retro culinary artwork, nostalgic charm, warm colors, high quality detailed illustration, no text no labels no words"
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
class VisualStyleConfiguration: ObservableObject {
    private static let storageKey = "visual_style_preference"

    @Published var selectedStyle: VisualStyle {
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
