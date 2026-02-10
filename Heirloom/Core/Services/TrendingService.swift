import Foundation
import SwiftData

/// Service for trending recipes with source quality signal
/// Scores recipes based on engagement, recency, source attribution confidence, and version activity
@MainActor
final class TrendingService {

    private var cachedTrending: [UUID: Double]?
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutes

    init() {}

    // MARK: - Public API

    /// Fetch trending recipes scored by engagement + source quality + version activity
    func fetchTrendingRecipes(limit: Int, context: ModelContext) async throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        let scored = allRecipes.map { recipe -> (Recipe, Double) in
            (recipe, trendingScore(for: recipe))
        }
        .sorted { $0.1 > $1.1 }

        return Array(scored.prefix(limit).map { $0.0 })
    }

    /// Fetch recently added recipes
    func fetchRecentRecipes(limit: Int, context: ModelContext) async throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        let allRecipes = try context.fetch(descriptor)
        return Array(allRecipes.prefix(limit))
    }

    /// Fetch popular recipes scored by cooking frequency + source quality
    func fetchPopularRecipes(limit: Int, context: ModelContext) async throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        let scored = allRecipes.map { recipe -> (Recipe, Double) in
            let cookScore = Double(recipe.timesCooked)
            let sourceBoost = recipe.knownSource?.confidence ?? 0.0
            return (recipe, cookScore + sourceBoost * 2.0)
        }
        .sorted { $0.1 > $1.1 }

        return Array(scored.prefix(limit).map { $0.0 })
    }

    /// Clear trending cache
    func clearCache() {
        cachedTrending = nil
        cacheTimestamp = nil
    }

    // MARK: - Scoring

    /// Calculate trending score for a recipe
    /// Factors: recency, cooking frequency, source confidence, version activity
    private func trendingScore(for recipe: Recipe) -> Double {
        var score = 0.0

        // Recency: recipes added/modified recently score higher (0-10 points)
        let daysSinceAdded = Date().timeIntervalSince(recipe.dateAdded) / 86400
        let recencyScore = max(0, 10.0 - daysSinceAdded * 0.1)
        score += recencyScore

        // Cooking frequency (0-10 points)
        let cookScore = min(10.0, Double(recipe.timesCooked) * 2.0)
        score += cookScore

        // Source quality boost: well-attributed recipes rank higher (0-5 points)
        if let source = recipe.knownSource {
            score += source.confidence * 5.0

            // Bonus for catalog-verified sources
            if source.isSyncedToFirebase {
                score += 1.0
            }
        }

        // Version activity: recipes with active modifications are engaging (0-3 points)
        let versionCount = recipe.versions?.count ?? 0
        if versionCount > 1 {
            score += min(3.0, Double(versionCount - 1) * 1.0)
        }

        // Substitution richness: recipes with known substitutions are more useful (0-2 points)
        let subCount = recipe.ingredients?.reduce(0) { $0 + ($1.substitutions?.count ?? 0) } ?? 0
        if subCount > 0 {
            score += min(2.0, Double(subCount) * 0.5)
        }

        return score
    }
}

// MARK: - Global Convenience

extension TrendingService {
    /// Global accessor that resolves from ServiceContainer for proper DI
    /// Maintains backward compatibility with existing .shared usage
    nonisolated(unsafe) static var shared: TrendingService {
        MainActor.assumeIsolated {
            ServiceContainer.shared.resolve(TrendingService.self)
        }
    }
}
