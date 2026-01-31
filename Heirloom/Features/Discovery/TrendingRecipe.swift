//
//  TrendingRecipe.swift
//  Heirloom
//
//  Presentation model for trending recipes in discovery feed
//  Wraps Recipe with engagement metrics
//

import Foundation
import SwiftData

/// Trending recipe with engagement metrics for discovery UI
struct TrendingRecipe: Identifiable {
    let id: String
    let recipe: Recipe

    // MARK: - Engagement Metrics (7-day window)

    var recentViews: Int
    var recentCooks: Int
    var recentShares: Int

    // MARK: - Trending Score

    /// Calculated trending score (0-100)
    /// Based on: views, cooks, shares, recency
    var trendingScore: Double

    // MARK: - UI Helpers

    /// Badge text for trending indicator (e.g., "🔥 HOT", "⭐ RISING")
    var displayBadge: String {
        if trendingScore >= 80 {
            return "🔥 HOT"
        } else if trendingScore >= 60 {
            return "⭐ RISING"
        } else {
            return ""
        }
    }

    /// Formatted trending score for display
    var formattedScore: String {
        String(format: "%.0f", trendingScore)
    }

    // MARK: - Initialization

    init(
        recipe: Recipe,
        recentViews: Int = 0,
        recentCooks: Int = 0,
        recentShares: Int = 0,
        trendingScore: Double = 0
    ) {
        self.id = recipe.id.uuidString
        self.recipe = recipe
        self.recentViews = recentViews
        self.recentCooks = recentCooks
        self.recentShares = recentShares
        self.trendingScore = trendingScore
    }

    // MARK: - Trending Score Calculation

    /// Calculate trending score based on engagement metrics
    /// - Parameters:
    ///   - views: Number of recent views
    ///   - cooks: Number of times cooked recently
    ///   - shares: Number of recent shares
    ///   - recencyBoost: Bonus points for recently published (0-20)
    /// - Returns: Trending score (0-100)
    static func calculateTrendingScore(
        views: Int,
        cooks: Int,
        shares: Int,
        recencyBoost: Double = 0
    ) -> Double {
        // Tunable weights
        let viewWeight = 0.3
        let cookWeight = 5.0
        let shareWeight = 3.0

        let rawScore = (Double(views) * viewWeight) +
                      (Double(cooks) * cookWeight) +
                      (Double(shares) * shareWeight) +
                      recencyBoost

        // Normalize to 0-100 (cap at 100)
        return min(rawScore, 100.0)
    }

    /// Calculate recency boost based on publish date
    /// - Parameter publishedAt: When recipe was published
    /// - Returns: Boost score (0-20)
    static func calculateRecencyBoost(publishedAt: Date) -> Double {
        let daysSincePublish = Date().timeIntervalSince(publishedAt) / (24 * 60 * 60)

        // Exponential decay: full boost for 0-2 days, half at 7 days, minimal at 30 days
        if daysSincePublish <= 2 {
            return 20.0
        } else if daysSincePublish <= 7 {
            return 20.0 * exp(-daysSincePublish / 7.0)
        } else if daysSincePublish <= 30 {
            return 20.0 * exp(-daysSincePublish / 15.0)
        } else {
            return 0.0
        }
    }
}

// MARK: - Equatable & Comparable

extension TrendingRecipe: Equatable {
    static func == (lhs: TrendingRecipe, rhs: TrendingRecipe) -> Bool {
        lhs.id == rhs.id
    }
}

extension TrendingRecipe: Comparable {
    static func < (lhs: TrendingRecipe, rhs: TrendingRecipe) -> Bool {
        lhs.trendingScore < rhs.trendingScore
    }
}
