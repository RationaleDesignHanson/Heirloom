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
    var addedDate: Date? // When user added this theme (nil = not added)

    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Computed Properties

    /// Days since user added this theme (nil if not added)
    var daysSinceAdded: Int? {
        guard let addedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: addedDate, to: Date()).day
    }

    /// Current day in this theme's 14-day journey (1-14, or 15+ if complete)
    var currentDay: Int {
        guard let days = daysSinceAdded else { return 0 }
        return min(days + 1, 15) // Day 1 on add date, capped at 15
    }

    /// Whether this theme's 14-day unlock period is complete
    var isComplete: Bool {
        guard let days = daysSinceAdded else { return false }
        return days >= 14
    }

    /// Whether this theme is actively in progress (added but not complete)
    var isInProgress: Bool {
        addedDate != nil && !isComplete
    }

    /// Days remaining in this theme's journey (0 if complete)
    var daysRemaining: Int {
        guard let days = daysSinceAdded else { return 14 }
        return max(0, 14 - days)
    }

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
    case media = "media"
    case difficulty = "difficulty"

    var displayName: String {
        switch self {
        case .cuisine: return "World Cuisines"
        case .era: return "Eras & Nostalgia"
        case .source: return "Hidden Treasures"
        case .media: return "Books & Film"
        case .difficulty: return "By Effort"
        }
    }

    var iconName: String {
        switch self {
        case .cuisine: return "globe"
        case .era: return "clock.arrow.circlepath"
        case .source: return "archivebox"
        case .media: return "book.and.page"
        case .difficulty: return "timer"
        }
    }

    /// Sort order for display
    var sortOrder: Int {
        switch self {
        case .era: return 0         // Eras & Nostalgia first
        case .media: return 1       // Books & Film
        case .cuisine: return 2     // World Cuisines
        case .source: return 3      // Hidden Treasures
        case .difficulty: return 4  // By Effort
        }
    }
}
