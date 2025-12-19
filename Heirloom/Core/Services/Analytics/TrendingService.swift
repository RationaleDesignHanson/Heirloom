import Foundation
import SwiftData
import CloudKit

/// Service for calculating and fetching trending recipes
@MainActor
final class TrendingService {

    // MARK: - Singleton

    static let shared = TrendingService()

    private init() {}

    // Cache for trending results
    private var cachedTrendingRecipes: [TrendingRecipe] = []
    private var lastCacheUpdate: Date?
    private let cacheExpirationInterval: TimeInterval = 60 * 60 // 1 hour

    // MARK: - Fetch Trending Recipes

    /// Fetch trending recipes from CloudKit public database
    /// - Parameters:
    ///   - limit: Maximum number of recipes to return (default: 20)
    ///   - context: SwiftData model context
    /// - Returns: Array of trending recipes sorted by score
    func fetchTrendingRecipes(limit: Int = 20, context: ModelContext) async throws -> [TrendingRecipe] {
        // Check cache
        if let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheExpirationInterval {
            print("✅ Returning cached trending recipes (\(cachedTrendingRecipes.count) items)")
            return Array(cachedTrendingRecipes.prefix(limit))
        }

        print("🔥 Fetching trending recipes from CloudKit...")

        // Fetch engagement data from CloudKit public database
        let engagementData = try await fetchRecentEngagements()

        // Group engagement by provenance hash
        let engagementsByProvenance = groupEngagementsByProvenance(engagementData)

        // Calculate trending scores
        var trendingResults: [TrendingRecipe] = []

        for (provenanceHash, engagements) in engagementsByProvenance {
            // Find local recipe with this provenance
            guard let recipe = try await findRecipeByProvenance(provenanceHash, context: context) else {
                continue
            }

            // Calculate metrics
            let trendingScore = calculateTrendingScore(engagements: engagements)
            let velocity = calculateVelocity(engagements: engagements)
            let stats = calculateEngagementStats(engagements: engagements)

            let trending = TrendingRecipe(
                recipe: recipe,
                trendingScore: trendingScore,
                velocity: velocity,
                recentViews: stats.views,
                recentCooks: stats.cooks,
                recentShares: stats.shares
            )

            trendingResults.append(trending)
        }

        // Sort by trending score
        trendingResults.sort { $0.trendingScore > $1.trendingScore }

        // Cache results
        cachedTrendingRecipes = trendingResults
        lastCacheUpdate = Date()

        print("✅ Calculated trending scores for \(trendingResults.count) recipes")

        return Array(trendingResults.prefix(limit))
    }

    /// Fetch popular recipes (all-time most engaged)
    /// - Parameters:
    ///   - limit: Maximum number of recipes to return
    ///   - context: SwiftData model context
    /// - Returns: Array of popular recipes
    func fetchPopularRecipes(limit: Int = 20, context: ModelContext) async throws -> [TrendingRecipe] {
        // Fetch all-time engagement data (last 30 days for performance)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let engagementData = try await fetchEngagementsSince(thirtyDaysAgo)

        // Group and calculate scores
        let engagementsByProvenance = groupEngagementsByProvenance(engagementData)

        var popularResults: [TrendingRecipe] = []

        for (provenanceHash, engagements) in engagementsByProvenance {
            guard let recipe = try await findRecipeByProvenance(provenanceHash, context: context) else {
                continue
            }

            let score = calculatePopularityScore(engagements: engagements)
            let stats = calculateEngagementStats(engagements: engagements)

            let popular = TrendingRecipe(
                recipe: recipe,
                trendingScore: score,
                velocity: 0, // Not applicable for all-time popular
                recentViews: stats.views,
                recentCooks: stats.cooks,
                recentShares: stats.shares
            )

            popularResults.append(popular)
        }

        // Sort by popularity score
        popularResults.sort { $0.trendingScore > $1.trendingScore }

        return Array(popularResults.prefix(limit))
    }

    /// Fetch recently shared recipes
    /// - Parameters:
    ///   - limit: Maximum number of recipes to return
    ///   - context: SwiftData model context
    /// - Returns: Array of recently shared recipes
    func fetchRecentRecipes(limit: Int = 20, context: ModelContext) async throws -> [Recipe] {
        // Query CloudKit for recently shared recipes
        let database = CKContainer.default().publicCloudDatabase
        let query = CKQuery(recordType: "SharedRecipe", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: limit)

            var recipes: [Recipe] = []

            for (_, result) in results {
                switch result {
                case .success(let record):
                    // Convert CloudKit record to Recipe
                    if let recipe = try? await convertCloudKitRecordToRecipe(record, context: context) {
                        recipes.append(recipe)
                    }
                case .failure(let error):
                    print("⚠️ Failed to fetch record: \(error)")
                }
            }

            return recipes

        } catch {
            print("❌ Failed to fetch recent recipes: \(error)")
            throw TrendingError.fetchFailed(error)
        }
    }

    // MARK: - CloudKit Queries

    /// Fetch recent engagement records from CloudKit
    private func fetchRecentEngagements() async throws -> [CloudKitEngagement] {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return try await fetchEngagementsSince(sevenDaysAgo)
    }

    /// Fetch engagements since a specific date
    private func fetchEngagementsSince(_ date: Date) async throws -> [CloudKitEngagement] {
        let database = CKContainer.default().publicCloudDatabase
        let predicate = NSPredicate(format: "timestamp >= %@", date as NSDate)
        let query = CKQuery(recordType: "RecipeEngagement", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 1000)

            var engagements: [CloudKitEngagement] = []

            for (_, result) in results {
                switch result {
                case .success(let record):
                    if let engagement = parseEngagementRecord(record) {
                        engagements.append(engagement)
                    }
                case .failure(let error):
                    print("⚠️ Failed to fetch engagement: \(error)")
                }
            }

            return engagements

        } catch {
            print("❌ Failed to fetch engagements from CloudKit: \(error)")
            throw TrendingError.fetchFailed(error)
        }
    }

    /// Parse CloudKit engagement record
    private func parseEngagementRecord(_ record: CKRecord) -> CloudKitEngagement? {
        guard let recipeID = record["recipeID"] as? String,
              let provenanceHash = record["provenanceHash"] as? String,
              let engagementTypeRaw = record["engagementType"] as? String,
              let timestamp = record["timestamp"] as? Date else {
            return nil
        }

        guard let engagementType = EngagementType(rawValue: engagementTypeRaw) else {
            return nil
        }

        return CloudKitEngagement(
            recipeID: recipeID,
            provenanceHash: provenanceHash,
            engagementType: engagementType,
            timestamp: timestamp
        )
    }

    // MARK: - Score Calculation

    /// Calculate trending score with time decay
    private func calculateTrendingScore(engagements: [CloudKitEngagement]) -> Double {
        let now = Date()

        // Weight different engagement types
        let weights: [EngagementType: Double] = [
            .view: 1.0,
            .save: 3.0,
            .cook: 5.0,
            .share: 8.0,
            .timeSpent: 2.0
        ]

        var totalScore: Double = 0

        for engagement in engagements {
            let weight = weights[engagement.engagementType] ?? 1.0
            let age = now.timeIntervalSince(engagement.timestamp)
            let decayFactor = exp(-age / (3 * 24 * 60 * 60)) // 3-day half-life

            totalScore += weight * decayFactor
        }

        // Normalize to 0-100 scale (logarithmic)
        let normalizedScore = min(100, log10(totalScore + 1) * 50)

        return normalizedScore
    }

    /// Calculate engagement velocity (rate of change)
    private func calculateVelocity(engagements: [CloudKitEngagement]) -> Double {
        let now = Date()
        let recentWindow: TimeInterval = 3 * 24 * 60 * 60 // 3 days
        let previousWindow: TimeInterval = 6 * 24 * 60 * 60 // 6 days total

        let recentEngagements = engagements.filter {
            now.timeIntervalSince($0.timestamp) < recentWindow
        }

        let previousEngagements = engagements.filter {
            let age = now.timeIntervalSince($0.timestamp)
            return age >= recentWindow && age < previousWindow
        }

        let recentCount = Double(recentEngagements.count)
        let previousCount = Double(previousEngagements.count)

        // Calculate percent change
        guard previousCount > 0 else {
            return recentCount > 0 ? 100 : 0
        }

        let velocity = ((recentCount - previousCount) / previousCount) * 100
        return velocity
    }

    /// Calculate all-time popularity score (no time decay)
    private func calculatePopularityScore(engagements: [CloudKitEngagement]) -> Double {
        let weights: [EngagementType: Double] = [
            .view: 1.0,
            .save: 3.0,
            .cook: 5.0,
            .share: 8.0,
            .timeSpent: 2.0
        ]

        var totalScore: Double = 0

        for engagement in engagements {
            let weight = weights[engagement.engagementType] ?? 1.0
            totalScore += weight
        }

        // Normalize to 0-100 scale
        let normalizedScore = min(100, log10(totalScore + 1) * 50)

        return normalizedScore
    }

    /// Calculate engagement statistics
    private func calculateEngagementStats(engagements: [CloudKitEngagement]) -> (views: Int, cooks: Int, shares: Int) {
        var views = 0
        var cooks = 0
        var shares = 0

        for engagement in engagements {
            switch engagement.engagementType {
            case .view:
                views += 1
            case .cook:
                cooks += 1
            case .share:
                shares += 1
            default:
                break
            }
        }

        return (views, cooks, shares)
    }

    // MARK: - Helper Methods

    /// Group engagements by provenance hash
    private func groupEngagementsByProvenance(_ engagements: [CloudKitEngagement]) -> [String: [CloudKitEngagement]] {
        var grouped: [String: [CloudKitEngagement]] = [:]

        for engagement in engagements {
            grouped[engagement.provenanceHash, default: []].append(engagement)
        }

        return grouped
    }

    /// Find local recipe by provenance hash
    private func findRecipeByProvenance(_ provenanceHash: String, context: ModelContext) async throws -> Recipe? {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.provenance?.rootProvenanceHash == provenanceHash
            }
        )

        let recipes = try context.fetch(descriptor)
        return recipes.first
    }

    /// Convert CloudKit shared recipe to local Recipe
    private func convertCloudKitRecordToRecipe(_ record: CKRecord, context: ModelContext) async throws -> Recipe? {
        guard let provenanceHash = record["provenanceHash"] as? String else {
            return nil
        }

        // Check if recipe already exists locally
        if let existing = try await findRecipeByProvenance(provenanceHash, context: context) {
            return existing
        }

        // TODO: Import recipe from CloudKit if not found locally
        // For now, return nil for recipes not in local database
        return nil
    }

    // MARK: - Cache Management

    /// Clear trending cache
    func clearCache() {
        cachedTrendingRecipes = []
        lastCacheUpdate = nil
        print("🗑️ Trending cache cleared")
    }
}

// MARK: - CloudKit Engagement Record

/// Simplified engagement record from CloudKit
struct CloudKitEngagement {
    let recipeID: String
    let provenanceHash: String
    let engagementType: EngagementType
    let timestamp: Date
}

// MARK: - Errors

enum TrendingError: LocalizedError {
    case fetchFailed(Error)
    case noDataAvailable
    case invalidData

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to fetch trending data: \(error.localizedDescription)"
        case .noDataAvailable:
            return "No trending data available"
        case .invalidData:
            return "Invalid trending data received"
        }
    }
}
