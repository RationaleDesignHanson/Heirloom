import Foundation
import SwiftData

/// Stub service for trending recipes feature
/// TODO: Implement actual trending algorithm
@MainActor
final class TrendingService {
    init() {}

    // MARK: - Public API

    /// Fetch trending recipes based on recent activity
    func fetchTrendingRecipes(limit: Int, context: ModelContext) async throws -> [Recipe] {
        // TODO: Implement trending algorithm (likes, shares, views)
        // For now, return empty array
        return []
    }

    /// Fetch recently added recipes
    func fetchRecentRecipes(limit: Int, context: ModelContext) async throws -> [Recipe] {
        // Fetch most recently added recipes
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        let allRecipes = try context.fetch(descriptor)
        return Array(allRecipes.prefix(limit))
    }

    /// Fetch popular recipes (most favorited/shared)
    func fetchPopularRecipes(limit: Int, context: ModelContext) async throws -> [Recipe] {
        // TODO: Implement popularity scoring
        // For now, return recipes sorted by times cooked
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\.timesCooked, order: .reverse)]
        )
        let allRecipes = try context.fetch(descriptor)
        return Array(allRecipes.prefix(limit))
    }

    /// Clear trending cache
    func clearCache() {
        // TODO: Implement caching when trending is implemented
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
