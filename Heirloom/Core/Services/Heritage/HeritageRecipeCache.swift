//
//  HeritageRecipeCache.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-15.
//

import Foundation
import SwiftData

/// Durable cache for Heritage recipe metadata (survives force-quit)
/// Stores minimal recipe data in UserDefaults for instant recovery
///
/// Architecture:
/// - Phase 1: Download recipe → Cache to UserDefaults (instant, survives force-quit)
/// - Phase 2: Insert into SwiftData (async, best-effort)
/// - Phase 3: On next launch, promote cached entries → full SwiftData objects if needed
@MainActor
class HeritageRecipeCache {
    private let defaults = UserDefaults.standard
    private let cacheKey = "heritageRecipesCache_v1"

    /// Cached recipe metadata - minimal data needed for recovery
    struct CachedRecipe: Codable {
        let heritageRecipeId: String        // Unique heritage recipe ID (e.g., "presidential-001")
        let title: String                   // Recipe title
        let collectionId: String            // Heritage collection ID
        let imageFileName: String?          // Local image file name (already persists)
        let ingredientsCount: Int           // Number of ingredients
        let instructionsCount: Int          // Number of instructions
        let downloadedAt: Date              // When cached
        let recipeUUID: String              // SwiftData UUID for lookup
        let servings: String?               // Serving size
        let prepTime: String?               // Prep time
        let cookTime: String?               // Cook time
    }

    // MARK: - Public API

    /// Save recipe to durable cache (synchronous UserDefaults write)
    /// Call this immediately after downloading from Firebase, before SwiftData insertion
    func cache(_ recipe: Recipe) {
        var cached = loadCachedRecipes()

        guard let heritageId = recipe.heritageRecipeId,
              let collectionId = recipe.heritageCollectionId else {
            Log.warning("Cannot cache recipe without heritageRecipeId or collectionId", category: .heritage)
            return
        }

        let entry = CachedRecipe(
            heritageRecipeId: heritageId,
            title: recipe.title,
            collectionId: collectionId,
            imageFileName: recipe.imageFileName,
            ingredientsCount: recipe.ingredients?.count ?? 0,
            instructionsCount: recipe.instructions.count,
            downloadedAt: Date(),
            recipeUUID: recipe.id.uuidString,
            servings: recipe.servings,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime
        )

        cached[heritageId] = entry
        saveCachedRecipes(cached)

        Log.debug("Cached heritage recipe to UserDefaults", category: .heritage, metadata: [
            "heritageRecipeId": heritageId,
            "title": recipe.title
        ])
    }

    /// Get all cached recipes (instant UserDefaults read)
    func getCachedRecipes() -> [String: CachedRecipe] {
        return loadCachedRecipes()
    }

    /// Check if recipe exists in cache
    func isCached(_ heritageRecipeId: String) -> Bool {
        return loadCachedRecipes()[heritageRecipeId] != nil
    }

    /// Remove recipe from cache (after successful SwiftData promotion)
    func removeCached(_ heritageRecipeId: String) {
        var cached = loadCachedRecipes()
        cached.removeValue(forKey: heritageRecipeId)
        saveCachedRecipes(cached)

        Log.debug("Removed recipe from cache", category: .heritage, metadata: [
            "heritageRecipeId": heritageRecipeId
        ])
    }

    /// Clear entire cache (for testing/debugging)
    func clearCache() {
        defaults.removeObject(forKey: cacheKey)
        defaults.synchronize()

        Log.info("Cleared heritage recipe cache", category: .heritage)
    }

    /// Get cache statistics
    func getCacheStats() -> (count: Int, totalSize: Int) {
        let cached = loadCachedRecipes()
        let data = try? JSONEncoder().encode(cached)
        return (count: cached.count, totalSize: data?.count ?? 0)
    }

    // MARK: - Private Helpers

    private func loadCachedRecipes() -> [String: CachedRecipe] {
        guard let data = defaults.data(forKey: cacheKey) else {
            return [:]
        }

        do {
            let cached = try JSONDecoder().decode([String: CachedRecipe].self, from: data)
            return cached
        } catch {
            Log.error("Failed to decode heritage recipe cache", category: .heritage, error: error)
            return [:]
        }
    }

    private func saveCachedRecipes(_ cached: [String: CachedRecipe]) {
        do {
            let data = try JSONEncoder().encode(cached)
            defaults.set(data, forKey: cacheKey)
            defaults.synchronize()  // Force immediate write to disk (survives force-quit)

            Log.debug("Saved heritage recipe cache", category: .heritage, metadata: [
                "recipeCount": cached.count,
                "sizeBytes": data.count
            ])
        } catch {
            Log.error("Failed to encode heritage recipe cache", category: .heritage, error: error)
        }
    }
}
