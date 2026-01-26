//
//  HeritageRecipeCleanupService.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import Foundation
import SwiftData

/// Service for managing cleanup of unmodified heritage recipes after 30 days
/// Helps users maintain a curated collection by removing unused heritage recipes
@MainActor
final class HeritageRecipeCleanupService: ObservableObject {

    // MARK: - Published State

    @Published var eligibleRecipes: [Recipe] = []
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Constants

    /// Number of days before a heritage recipe is eligible for cleanup
    static let cleanupEligibilityDays = 30

    // MARK: - Fetch Eligible Recipes

    /// Fetch all heritage recipes that are eligible for cleanup
    /// - Parameter context: ModelContext for SwiftData operations
    /// - Returns: Array of recipes eligible for cleanup
    func fetchRecipesForCleanup(context: ModelContext) async throws -> [Recipe] {
        isLoading = true
        error = nil

        defer { isLoading = false }

        Log.info("Fetching heritage recipes eligible for cleanup", category: .database)

        // Create fetch descriptor for heritage recipes
        let fetchDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.isThemeRecipe == true
            },
            sortBy: [SortDescriptor(\Recipe.dateAdded, order: .forward)]
        )

        let allHeritageRecipes = try context.fetch(fetchDescriptor)

        // Filter for eligible recipes
        let eligible = allHeritageRecipes.filter { recipe in
            recipe.shouldConsiderForCleanup
        }

        eligibleRecipes = eligible

        Log.info("Found eligible heritage recipes for cleanup", category: .database, metadata: [
            "totalHeritageRecipes": allHeritageRecipes.count,
            "eligibleForCleanup": eligible.count
        ])

        return eligible
    }

    // MARK: - Delete Recipes

    /// Delete specified recipes from the database
    /// - Parameters:
    ///   - recipes: Array of recipes to delete
    ///   - context: ModelContext for SwiftData operations
    func deleteRecipes(_ recipes: [Recipe], context: ModelContext) async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        Log.info("Deleting heritage recipes", category: .database, metadata: [
            "count": recipes.count
        ])

        for recipe in recipes {
            // Delete associated data first (handled by cascade delete rules)
            context.delete(recipe)

            Log.info("Deleted heritage recipe", category: .database, metadata: [
                "recipeId": recipe.id.uuidString,
                "title": recipe.title
            ])
        }

        // Save changes
        try context.save()

        // Refresh eligible recipes list
        eligibleRecipes.removeAll { recipe in
            recipes.contains { $0.id == recipe.id }
        }

        Log.info("Successfully deleted heritage recipes", category: .database, metadata: [
            "count": recipes.count
        ])
    }

    // MARK: - Keep Recipe

    /// Mark a recipe as "kept" by adding a note or making it a favorite
    /// This prevents it from appearing in cleanup suggestions
    /// - Parameters:
    ///   - recipe: Recipe to keep
    ///   - context: ModelContext for SwiftData operations
    func keepRecipe(_ recipe: Recipe, context: ModelContext) async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        Log.info("Marking heritage recipe as kept", category: .database, metadata: [
            "recipeId": recipe.id.uuidString,
            "title": recipe.title
        ])

        // Mark as favorite to prevent cleanup
        recipe.isFavorite = true

        // Save changes
        try context.save()

        // Remove from eligible list
        eligibleRecipes.removeAll { $0.id == recipe.id }

        Log.info("Successfully marked recipe as kept", category: .database)
    }

    // MARK: - Batch Operations

    /// Delete all eligible recipes at once
    /// - Parameter context: ModelContext for SwiftData operations
    func deleteAllEligible(context: ModelContext) async throws {
        try await deleteRecipes(eligibleRecipes, context: context)
    }

    /// Get statistics about eligible recipes
    func getCleanupStatistics(context: ModelContext) async throws -> CleanupStatistics {
        let eligible = try await fetchRecipesForCleanup(context: context)

        let collectionCounts = Dictionary(grouping: eligible) { recipe in
            recipe.sourceThemeId ?? "unknown"
        }.mapValues { $0.count }

        let oldestDate = eligible.map { $0.dateAdded }.min()
        let newestDate = eligible.map { $0.dateAdded }.max()

        return CleanupStatistics(
            totalEligible: eligible.count,
            collectionBreakdown: collectionCounts,
            oldestRecipeDate: oldestDate,
            newestRecipeDate: newestDate
        )
    }
}

// MARK: - Supporting Types

struct CleanupStatistics {
    let totalEligible: Int
    let collectionBreakdown: [String: Int]
    let oldestRecipeDate: Date?
    let newestRecipeDate: Date?

    var hasEligibleRecipes: Bool {
        totalEligible > 0
    }

    var formattedSummary: String {
        guard hasEligibleRecipes else {
            return "No heritage recipes eligible for cleanup"
        }

        return "\(totalEligible) heritage recipe\(totalEligible == 1 ? "" : "s") eligible for cleanup"
    }
}

// MARK: - Error Types

enum CleanupError: LocalizedError {
    case fetchFailed(Error)
    case deleteFailed(Error)
    case noEligibleRecipes

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to fetch eligible recipes: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete recipes: \(error.localizedDescription)"
        case .noEligibleRecipes:
            return "No recipes are eligible for cleanup at this time"
        }
    }
}
