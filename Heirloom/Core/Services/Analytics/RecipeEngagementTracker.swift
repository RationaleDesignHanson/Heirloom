import Foundation
import SwiftData
import CloudKit

/// Tracks recipe engagement metrics for trending algorithm
@MainActor
final class RecipeEngagementTracker {

    // MARK: - Singleton

    static let shared = RecipeEngagementTracker()

    private init() {}

    // MARK: - Engagement Tracking

    /// Track when a user views a recipe
    /// - Parameters:
    ///   - recipe: The recipe being viewed
    ///   - context: SwiftData model context
    func trackView(recipe: Recipe, context: ModelContext) async {
        let engagement = RecipeEngagement(
            recipeID: recipe.id,
            provenanceHash: recipe.provenance?.rootProvenanceHash,
            engagementType: .view,
            timestamp: Date()
        )

        context.insert(engagement)
        try? context.save()

        // Track in analytics
        AnalyticsService.shared.track(event: .recipeEngaged, properties: [
            "recipe_id": recipe.id.uuidString,
            "recipe_title": recipe.title,
            "engagement_type": "view"
        ])

        // Sync to CloudKit if consent given
        if PrivacyConsentService.shared.hasAnalyticsConsent {
            await syncEngagementToCloudKit(engagement)
        }
    }

    /// Track when a user saves/bookmarks a recipe
    /// - Parameters:
    ///   - recipe: The recipe being saved
    ///   - context: SwiftData model context
    func trackSave(recipe: Recipe, context: ModelContext) async {
        let engagement = RecipeEngagement(
            recipeID: recipe.id,
            provenanceHash: recipe.provenance?.rootProvenanceHash,
            engagementType: .save,
            timestamp: Date()
        )

        context.insert(engagement)
        try? context.save()

        // Track in analytics
        AnalyticsService.shared.track(event: .recipeSaved, properties: [
            "recipe_id": recipe.id.uuidString,
            "recipe_title": recipe.title
        ])

        if PrivacyConsentService.shared.hasAnalyticsConsent {
            await syncEngagementToCloudKit(engagement)
        }
    }

    /// Track when a user cooks a recipe
    /// - Parameters:
    ///   - recipe: The recipe being cooked
    ///   - context: SwiftData model context
    func trackCook(recipe: Recipe, context: ModelContext) async {
        let engagement = RecipeEngagement(
            recipeID: recipe.id,
            provenanceHash: recipe.provenance?.rootProvenanceHash,
            engagementType: .cook,
            timestamp: Date()
        )

        context.insert(engagement)
        try? context.save()

        // Track in analytics
        AnalyticsService.shared.track(event: .cookingCompleted, properties: [
            "recipe_id": recipe.id.uuidString,
            "recipe_title": recipe.title,
            "times_cooked": recipe.timesCooked
        ])

        if PrivacyConsentService.shared.hasAnalyticsConsent {
            await syncEngagementToCloudKit(engagement)
        }
    }

    /// Track when a user shares a recipe
    /// - Parameters:
    ///   - recipe: The recipe being shared
    ///   - method: Share method (link, qr_code, etc.)
    ///   - context: SwiftData model context
    func trackShare(recipe: Recipe, method: String, context: ModelContext) async {
        let engagement = RecipeEngagement(
            recipeID: recipe.id,
            provenanceHash: recipe.provenance?.rootProvenanceHash,
            engagementType: .share,
            timestamp: Date(),
            metadata: ["method": method]
        )

        context.insert(engagement)
        try? context.save()

        // Track in analytics
        AnalyticsService.shared.track(event: .recipeShared, properties: [
            "recipe_id": recipe.id.uuidString,
            "recipe_title": recipe.title,
            "method": method
        ])

        if PrivacyConsentService.shared.hasAnalyticsConsent {
            await syncEngagementToCloudKit(engagement)
        }
    }

    /// Track time spent viewing a recipe
    /// - Parameters:
    ///   - recipe: The recipe being viewed
    ///   - duration: Time spent in seconds
    ///   - context: SwiftData model context
    func trackTimeSpent(recipe: Recipe, duration: TimeInterval, context: ModelContext) async {
        // Only track if meaningful time (more than 3 seconds)
        guard duration > 3 else { return }

        let engagement = RecipeEngagement(
            recipeID: recipe.id,
            provenanceHash: recipe.provenance?.rootProvenanceHash,
            engagementType: .timeSpent,
            timestamp: Date(),
            metadata: ["duration": duration]
        )

        context.insert(engagement)
        try? context.save()

        // Track in analytics
        AnalyticsService.shared.track(event: .recipeTimeSpent, properties: [
            "recipe_id": recipe.id.uuidString,
            "recipe_title": recipe.title,
            "duration": duration
        ])

        if PrivacyConsentService.shared.hasAnalyticsConsent {
            await syncEngagementToCloudKit(engagement)
        }
    }

    // MARK: - Trending Score Calculation

    /// Calculate trending score for a recipe
    /// - Parameters:
    ///   - recipe: The recipe to score
    ///   - context: SwiftData model context
    /// - Returns: Trending score (0-100)
    func calculateTrendingScore(for recipe: Recipe, context: ModelContext) async -> Double {
        let now = Date()
        let timeWindow: TimeInterval = 7 * 24 * 60 * 60 // 7 days

        // Fetch recent engagements for this recipe
        let engagements = try? await fetchRecentEngagements(
            recipeID: recipe.id,
            since: now.addingTimeInterval(-timeWindow),
            context: context
        )

        guard let engagements = engagements, !engagements.isEmpty else {
            return 0
        }

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
    /// - Parameters:
    ///   - recipe: The recipe to analyze
    ///   - context: SwiftData model context
    /// - Returns: Velocity score (positive = growing, negative = declining)
    func calculateVelocity(for recipe: Recipe, context: ModelContext) async -> Double {
        let now = Date()

        // Compare recent 3 days vs previous 3 days
        let recentStart = now.addingTimeInterval(-3 * 24 * 60 * 60)
        let previousStart = now.addingTimeInterval(-6 * 24 * 60 * 60)

        let recentEngagements = try? await fetchRecentEngagements(
            recipeID: recipe.id,
            since: recentStart,
            context: context
        )

        let previousEngagements = try? await fetchEngagementsBetween(
            recipeID: recipe.id,
            start: previousStart,
            end: recentStart,
            context: context
        )

        let recentCount = Double(recentEngagements?.count ?? 0)
        let previousCount = Double(previousEngagements?.count ?? 0)

        // Calculate percent change
        guard previousCount > 0 else {
            return recentCount > 0 ? 100 : 0
        }

        let velocity = ((recentCount - previousCount) / previousCount) * 100
        return velocity
    }

    // MARK: - Data Fetching

    /// Fetch recent engagements for a recipe
    private func fetchRecentEngagements(
        recipeID: UUID,
        since date: Date,
        context: ModelContext
    ) async throws -> [RecipeEngagement] {
        let descriptor = FetchDescriptor<RecipeEngagement>(
            predicate: #Predicate { engagement in
                engagement.recipeID == recipeID && engagement.timestamp >= date
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        return try context.fetch(descriptor)
    }

    /// Fetch engagements between two dates
    private func fetchEngagementsBetween(
        recipeID: UUID,
        start: Date,
        end: Date,
        context: ModelContext
    ) async throws -> [RecipeEngagement] {
        let descriptor = FetchDescriptor<RecipeEngagement>(
            predicate: #Predicate { engagement in
                engagement.recipeID == recipeID &&
                engagement.timestamp >= start &&
                engagement.timestamp < end
            }
        )

        return try context.fetch(descriptor)
    }

    // MARK: - CloudKit Sync

    /// Sync engagement to CloudKit for trending analysis
    private func syncEngagementToCloudKit(_ engagement: RecipeEngagement) async {
        guard let provenanceHash = engagement.provenanceHash else {
            print("⚠️ Cannot sync engagement without provenance hash")
            return
        }

        do {
            let record = CKRecord(recordType: "RecipeEngagement")
            record["recipeID"] = engagement.recipeID.uuidString
            record["provenanceHash"] = provenanceHash
            record["engagementType"] = engagement.engagementType.rawValue
            record["timestamp"] = engagement.timestamp

            if let metadata = engagement.metadata {
                record["metadata"] = try? JSONSerialization.data(withJSONObject: metadata)
            }

            let database = CKContainer.default().publicCloudDatabase
            _ = try await database.save(record)

            print("✅ Synced engagement to CloudKit: \(engagement.engagementType.rawValue)")

        } catch {
            print("❌ Failed to sync engagement to CloudKit: \(error)")
        }
    }

    // MARK: - Privacy Compliance

    /// Delete all engagement data for a user (GDPR/CCPA compliance)
    func deleteAllEngagementData(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<RecipeEngagement>()
        let engagements = try context.fetch(descriptor)

        for engagement in engagements {
            context.delete(engagement)
        }

        try context.save()

        print("✅ Deleted all engagement data")
    }
}

// MARK: - Engagement Data Model

/// Local engagement tracking model
@Model
final class RecipeEngagement {
    var id: UUID
    var recipeID: UUID
    var provenanceHash: String?
    var engagementType: EngagementType
    var timestamp: Date
    var metadata: [String: Any]?

    init(
        recipeID: UUID,
        provenanceHash: String?,
        engagementType: EngagementType,
        timestamp: Date,
        metadata: [String: Any]? = nil
    ) {
        self.id = UUID()
        self.recipeID = recipeID
        self.provenanceHash = provenanceHash
        self.engagementType = engagementType
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Types of engagement events
enum EngagementType: String, Codable {
    case view = "view"
    case save = "save"
    case cook = "cook"
    case share = "share"
    case timeSpent = "time_spent"
}

// MARK: - Trending Recipe Result

/// Result from trending algorithm
struct TrendingRecipe: Identifiable {
    let id = UUID()
    let recipe: Recipe
    let trendingScore: Double
    let velocity: Double
    let recentViews: Int
    let recentCooks: Int
    let recentShares: Int

    var displayBadge: String {
        if velocity > 50 {
            return "🔥 Hot"
        } else if velocity > 20 {
            return "📈 Rising"
        } else if trendingScore > 70 {
            return "⭐ Popular"
        } else {
            return ""
        }
    }
}
