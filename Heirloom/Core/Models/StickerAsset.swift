//
//  StickerAsset.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import Foundation
import SwiftData
import SwiftUI

/// Represents a sticker asset available for recipe card customization
@Model
final class StickerAsset {
    // MARK: - Identity

    /// Unique sticker ID (e.g., "vintage_spoon_01")
    @Attribute(.unique) var id: String

    /// Display name for the sticker
    var name: String

    /// Category this sticker belongs to
    var categoryRawValue: String

    var category: StickerCategory {
        get { StickerCategory(rawValue: categoryRawValue) ?? .vintage }
        set { categoryRawValue = newValue.rawValue }
    }

    // MARK: - Asset

    /// Asset catalog name or file name
    var assetName: String

    /// SVG data for resolution independence (optional)
    var svgData: Data?

    /// PNG thumbnail for preview
    var previewImageData: Data?

    // MARK: - Properties

    /// Whether this sticker supports tint color customization
    var supportsTinting: Bool

    /// Default size when first placed (normalized 0-1 coordinates)
    var defaultSizeWidth: Double
    var defaultSizeHeight: Double

    var defaultSize: CGSize {
        get { CGSize(width: defaultSizeWidth, height: defaultSizeHeight) }
        set {
            defaultSizeWidth = newValue.width
            defaultSizeHeight = newValue.height
        }
    }

    /// Search tags for filtering
    var tags: [String]

    // MARK: - Metadata

    /// Whether this is a premium sticker (requires purchase/subscription)
    var isPremium: Bool

    /// Sort order within category
    var sortOrder: Int

    /// Whether this sticker is enabled/visible
    var isEnabled: Bool

    // MARK: - User Preferences

    /// Whether user has favorited this sticker
    var isFavorited: Bool

    /// Number of times this sticker has been used
    var useCount: Int

    // MARK: - Initialization

    init(
        id: String,
        name: String,
        category: StickerCategory,
        assetName: String,
        supportsTinting: Bool = false,
        defaultSize: CGSize,
        tags: [String] = [],
        isPremium: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.categoryRawValue = category.rawValue
        self.assetName = assetName
        self.supportsTinting = supportsTinting
        self.defaultSizeWidth = defaultSize.width
        self.defaultSizeHeight = defaultSize.height
        self.tags = tags
        self.isPremium = isPremium
        self.sortOrder = sortOrder
        self.isEnabled = true
        self.isFavorited = false
        self.useCount = 0
    }
}

// MARK: - Sticker Category

enum StickerCategory: String, Codable, CaseIterable {
    case vintage           // Vintage kitchen items (rolling pins, mixers, etc.)
    case decorative        // Borders, corners, flourishes
    case seasonal          // Holiday-themed
    case icons             // Hearts, stars, checkmarks
    case botanical         // Herbs, flowers, leaves
    case utensils          // Spoons, forks, knives, whisks
    case typography        // Decorative letters, labels
    case frames            // Photo frame overlays

    var displayName: String {
        switch self {
        case .vintage: return "Vintage"
        case .decorative: return "Decorative"
        case .seasonal: return "Seasonal"
        case .icons: return "Icons"
        case .botanical: return "Botanical"
        case .utensils: return "Utensils"
        case .typography: return "Typography"
        case .frames: return "Frames"
        }
    }

    var icon: String {
        switch self {
        case .vintage: return "clock"
        case .decorative: return "sparkles"
        case .seasonal: return "snowflake"
        case .icons: return "heart.fill"
        case .botanical: return "leaf"
        case .utensils: return "fork.knife"
        case .typography: return "textformat"
        case .frames: return "photo"
        }
    }
}

// MARK: - Helper Extensions

extension StickerAsset {
    /// Check if sticker matches search query
    func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased()

        // Match name
        if name.lowercased().contains(query) {
            return true
        }

        // Match tags
        for tag in tags {
            if tag.lowercased().contains(query) {
                return true
            }
        }

        // Match category
        if category.displayName.lowercased().contains(query) {
            return true
        }

        return false
    }

    /// Increment use count
    func incrementUseCount() {
        useCount += 1
    }

    /// Toggle favorite status
    func toggleFavorite() {
        isFavorited.toggle()
    }
}
