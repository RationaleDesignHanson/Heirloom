//
//  RecipeTheme.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation
import SwiftData

/// A curated theme of recipes users can select during onboarding
@Model
final class RecipeTheme: Identifiable {
    // MARK: - Identity
    var id: UUID = UUID()
    var firebaseId: String // Reference to Firebase document

    // MARK: - Display
    var name: String
    var tagline: String // Short hook: "Recipes from restaurants that no longer exist"
    var themeDescription: String // Note: 'description' is reserved in Swift
    var iconName: String // SF Symbol
    var coverImageURL: String?

    // MARK: - Classification
    var category: ThemeCategory
    var source: String? // "MSU Feeding America", "Horn & Hardart", etc.
    var era: String? // "1940s", "Victorian", etc.
    var region: String? // "American South", "Scandinavian", etc.

    // MARK: - Content
    var totalRecipes: Int
    var unlockSchedule: [Int] // Days on which recipes unlock [1, 3, 5, 7, 10, 14]

    // MARK: - User State
    var isSelected: Bool = false
    var sortOrder: Int = 0

    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify, inverse: \RecipeCollection.sourceTheme)
    var collection: RecipeCollection?

    init(
        firebaseId: String,
        name: String,
        tagline: String,
        themeDescription: String,
        iconName: String,
        category: ThemeCategory,
        totalRecipes: Int,
        unlockSchedule: [Int]
    ) {
        self.firebaseId = firebaseId
        self.name = name
        self.tagline = tagline
        self.themeDescription = themeDescription
        self.iconName = iconName
        self.category = category
        self.totalRecipes = totalRecipes
        self.unlockSchedule = unlockSchedule
    }
}

// MARK: - Theme Category

enum ThemeCategory: String, Codable, CaseIterable {
    case cuisine = "cuisine"
    case era = "era"
    case source = "source"
    case difficulty = "difficulty"
    case dietary = "dietary"

    var displayName: String {
        switch self {
        case .cuisine: return "World Cuisines"
        case .era: return "Eras & Nostalgia"
        case .source: return "Hidden Treasures"
        case .difficulty: return "By Effort"
        case .dietary: return "Dietary"
        }
    }

    var iconName: String {
        switch self {
        case .cuisine: return "globe"
        case .era: return "clock.arrow.circlepath"
        case .source: return "archivebox"
        case .difficulty: return "timer"
        case .dietary: return "leaf"
        }
    }

    /// Sort order for display
    var sortOrder: Int {
        switch self {
        case .source: return 0      // Hidden Treasures first (most unique)
        case .era: return 1
        case .cuisine: return 2
        case .difficulty: return 3
        case .dietary: return 4
        }
    }
}
