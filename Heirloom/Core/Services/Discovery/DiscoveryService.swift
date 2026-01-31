//
//  DiscoveryService.swift
//  Heirloom
//
//  Service for discovering and fetching public recipes
//  Phase 4: Discovery feed with search, pagination, and caching
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions
import SwiftData

// MARK: - Protocol

/// Service for discovering public recipes
@MainActor
protocol DiscoveryServiceProtocol {
    /// Fetch trending recipes (high engagement + recent)
    func fetchTrending(limit: Int, lastDocument: DocumentSnapshot?) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?)

    /// Fetch recently published recipes
    func fetchNew(limit: Int, lastDocument: DocumentSnapshot?) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?)

    /// Fetch popular recipes (most saves + views)
    func fetchPopular(limit: Int, lastDocument: DocumentSnapshot?) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?)

    /// Search recipes by keywords
    func search(query: String, limit: Int, lastDocument: DocumentSnapshot?) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?)

    /// Fetch a single public recipe by ID
    func fetchPublicRecipe(id: String) async throws -> PublicRecipe?

    /// Track view on a public recipe (calls Cloud Function)
    func trackView(publicRecipeId: String) async throws

    /// Save a public recipe to user's collection
    func saveToMyRecipes(publicRecipe: PublicRecipe, context: ModelContext) async throws -> Recipe

    /// Clear cache (for testing or manual refresh)
    func clearCache()
}

// MARK: - Errors

enum DiscoveryError: LocalizedError {
    case notFound
    case invalidQuery
    case cloudFunctionError(Error)
    case firestoreError(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Recipe not found."
        case .invalidQuery:
            return "Invalid search query. Please try different keywords."
        case .cloudFunctionError(let error):
            return "Failed to track view: \(error.localizedDescription)"
        case .firestoreError(let error):
            return "Failed to fetch recipes: \(error.localizedDescription)"
        }
    }
}

// MARK: - Implementation

/// Firebase implementation of discovery service
@MainActor
class FirebaseDiscoveryService: DiscoveryServiceProtocol {

    // MARK: - Dependencies

    private let db: Firestore
    private let functions: Functions

    // MARK: - Cache

    private var trendingCache: CachedResult?
    private var newCache: CachedResult?
    private var popularCache: CachedResult?
    private var searchCache: [String: CachedResult] = [:]

    private let cacheExpirationSeconds: TimeInterval = 5 * 60  // 5 minutes

    private struct CachedResult {
        let recipes: [PublicRecipe]
        let timestamp: Date

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 5 * 60
        }
    }

    // MARK: - Initialization

    init(
        firestore: Firestore = Firestore.firestore(),
        functions: Functions = Functions.functions()
    ) {
        self.db = firestore
        self.functions = functions
    }

    // MARK: - Fetch Methods

    /// Fetch trending recipes (high trending score)
    func fetchTrending(limit: Int = 20, lastDocument: DocumentSnapshot? = nil) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?) {
        // Check cache for first page only
        if lastDocument == nil, let cached = trendingCache, !cached.isExpired {
            Log.debug("Trending cache hit", category: .social)
            return (cached.recipes, nil)
        }

        var query = db.collection("publicRecipes")
            .order(by: "trendingScore", descending: true)
            .limit(to: limit)

        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }

        do {
            let snapshot = try await query.getDocuments()
            let recipes = try snapshot.documents.compactMap { doc -> PublicRecipe? in
                try PublicRecipe(from: doc)
            }

            // Cache first page
            if lastDocument == nil {
                trendingCache = CachedResult(recipes: recipes, timestamp: Date())
            }

            Log.info("Fetched trending recipes", category: .social, metadata: [
                "count": recipes.count,
                "hasMore": !snapshot.documents.isEmpty
            ])

            let lastDoc = snapshot.documents.last
            return (recipes, lastDoc)

        } catch {
            Log.error("Failed to fetch trending recipes", category: .social, metadata: [
                "error": error.localizedDescription
            ])
            throw DiscoveryError.firestoreError(error)
        }
    }

    /// Fetch recently published recipes
    func fetchNew(limit: Int = 20, lastDocument: DocumentSnapshot? = nil) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?) {
        // Check cache for first page only
        if lastDocument == nil, let cached = newCache, !cached.isExpired {
            Log.debug("New recipes cache hit", category: .social)
            return (cached.recipes, nil)
        }

        var query = db.collection("publicRecipes")
            .order(by: "publishedAt", descending: true)
            .limit(to: limit)

        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }

        do {
            let snapshot = try await query.getDocuments()
            let recipes = try snapshot.documents.compactMap { doc -> PublicRecipe? in
                try PublicRecipe(from: doc)
            }

            // Cache first page
            if lastDocument == nil {
                newCache = CachedResult(recipes: recipes, timestamp: Date())
            }

            Log.info("Fetched new recipes", category: .social, metadata: [
                "count": recipes.count
            ])

            let lastDoc = snapshot.documents.last
            return (recipes, lastDoc)

        } catch {
            Log.error("Failed to fetch new recipes", category: .social, metadata: [
                "error": error.localizedDescription
            ])
            throw DiscoveryError.firestoreError(error)
        }
    }

    /// Fetch popular recipes (most saves + views)
    func fetchPopular(limit: Int = 20, lastDocument: DocumentSnapshot? = nil) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?) {
        // Check cache for first page only
        if lastDocument == nil, let cached = popularCache, !cached.isExpired {
            Log.debug("Popular recipes cache hit", category: .social)
            return (cached.recipes, nil)
        }

        var query = db.collection("publicRecipes")
            .order(by: "saveCount", descending: true)
            .order(by: "viewCount", descending: true)
            .limit(to: limit)

        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }

        do {
            let snapshot = try await query.getDocuments()
            let recipes = try snapshot.documents.compactMap { doc -> PublicRecipe? in
                try PublicRecipe(from: doc)
            }

            // Cache first page
            if lastDocument == nil {
                popularCache = CachedResult(recipes: recipes, timestamp: Date())
            }

            Log.info("Fetched popular recipes", category: .social, metadata: [
                "count": recipes.count
            ])

            let lastDoc = snapshot.documents.last
            return (recipes, lastDoc)

        } catch {
            Log.error("Failed to fetch popular recipes", category: .social, metadata: [
                "error": error.localizedDescription
            ])
            throw DiscoveryError.firestoreError(error)
        }
    }

    /// Search recipes by keywords (Firestore array-contains)
    func search(query: String, limit: Int = 20, lastDocument: DocumentSnapshot? = nil) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?) {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)

        guard normalizedQuery.count >= 3 else {
            throw DiscoveryError.invalidQuery
        }

        // Check cache for first page only
        let cacheKey = normalizedQuery
        if lastDocument == nil, let cached = searchCache[cacheKey], !cached.isExpired {
            Log.debug("Search cache hit", category: .social, metadata: ["query": normalizedQuery])
            return (cached.recipes, nil)
        }

        // Split query into words for multi-term search
        let searchTerms = normalizedQuery.components(separatedBy: .whitespaces).filter { $0.count >= 3 }
        guard let firstTerm = searchTerms.first else {
            throw DiscoveryError.invalidQuery
        }

        // Firestore array-contains only works with single value
        // For MVP, search first term and filter others client-side
        var query = db.collection("publicRecipes")
            .whereField("searchKeywords", arrayContains: firstTerm)
            .order(by: "publishedAt", descending: true)
            .limit(to: limit * 2)  // Fetch extra for client-side filtering

        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }

        do {
            let snapshot = try await query.getDocuments()
            var recipes = try snapshot.documents.compactMap { doc -> PublicRecipe? in
                try PublicRecipe(from: doc)
            }

            // Client-side filter for multi-term queries
            if searchTerms.count > 1 {
                recipes = recipes.filter { recipe in
                    let allKeywords = recipe.searchKeywords.joined(separator: " ")
                    return searchTerms.allSatisfy { term in
                        allKeywords.contains(term)
                    }
                }
            }

            // Trim to limit
            recipes = Array(recipes.prefix(limit))

            // Cache first page
            if lastDocument == nil {
                searchCache[cacheKey] = CachedResult(recipes: recipes, timestamp: Date())
            }

            Log.info("Search completed", category: .social, metadata: [
                "query": normalizedQuery,
                "terms": searchTerms.count,
                "results": recipes.count
            ])

            let lastDoc = snapshot.documents.last
            return (recipes, lastDoc)

        } catch {
            Log.error("Search failed", category: .social, metadata: [
                "query": normalizedQuery,
                "error": error.localizedDescription
            ])
            throw DiscoveryError.firestoreError(error)
        }
    }

    /// Fetch a single public recipe by ID
    func fetchPublicRecipe(id: String) async throws -> PublicRecipe? {
        do {
            let doc = try await db.collection("publicRecipes").document(id).getDocument()

            guard doc.exists else {
                Log.warning("Public recipe not found", category: .social, metadata: ["id": id])
                return nil
            }

            let recipe = try PublicRecipe(from: doc)
            Log.debug("Fetched public recipe", category: .social, metadata: ["id": id, "title": recipe.title])
            return recipe

        } catch {
            Log.error("Failed to fetch public recipe", category: .social, metadata: [
                "id": id,
                "error": error.localizedDescription
            ])
            throw DiscoveryError.firestoreError(error)
        }
    }

    // MARK: - Engagement Tracking

    /// Track view on a public recipe (calls Cloud Function with rate limiting)
    func trackView(publicRecipeId: String) async throws {
        do {
            let callable = functions.httpsCallable("incrementPublicRecipeView")
            let result = try await callable.call(["recipeId": publicRecipeId])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                let rateLimited = data["rateLimited"] as? Bool ?? false
                let viewCount = data["viewCount"] as? Int ?? 0

                Log.debug("View tracked", category: .social, metadata: [
                    "recipeId": publicRecipeId,
                    "viewCount": viewCount,
                    "rateLimited": rateLimited
                ])
            }

        } catch {
            Log.warning("Failed to track view", category: .social, metadata: [
                "recipeId": publicRecipeId,
                "error": error.localizedDescription
            ])
            // Don't throw - view tracking is non-critical
        }
    }

    // MARK: - Save to Collection

    /// Save a public recipe to user's local collection with upstream attribution
    func saveToMyRecipes(publicRecipe: PublicRecipe, context: ModelContext) async throws -> Recipe {
        // Create local recipe from public recipe
        let recipe = Recipe(
            title: publicRecipe.title,
            sourceType: .family,  // Saved from community
            instructions: [],  // Public recipes don't include full instructions
            servings: publicRecipe.servings,
            prepTime: publicRecipe.prepTime,
            cookTime: publicRecipe.cookTime
        )

        // Set upstream attribution (fork model)
        recipe.sourcePublicRecipeId = publicRecipe.id
        recipe.sourcePublicRecipeCreatorId = publicRecipe.ownerId
        recipe.sourcePublicRecipeCreatorName = publicRecipe.creatorName
        recipe.sourcePublicRecipeLastSynced = Date()
        recipe.sourcePublicRecipeStillAvailable = true

        // Copy description to notes
        if let description = publicRecipe.description {
            recipe.notes = description
        }

        // Create ingredients from names
        for (index, ingredientName) in publicRecipe.ingredients.enumerated() {
            let ingredient = Ingredient(
                originalText: ingredientName,
                name: ingredientName,
                quantity: nil,
                unit: nil,
                category: .other,
                orderIndex: index
            )
            ingredient.recipe = recipe
            context.insert(ingredient)
        }

        // Insert recipe
        context.insert(recipe)

        // Save context
        do {
            try context.save()

            Log.info("Saved public recipe to collection", category: .social, metadata: [
                "publicRecipeId": publicRecipe.id,
                "recipeId": recipe.id.uuidString,
                "title": recipe.title
            ])

            // Track save (calls Cloud Function)
            try await trackSave(publicRecipeId: publicRecipe.id)

            // Track analytics
            DiscoveryAnalytics.trackPublicRecipeSaved(
                publicRecipeId: publicRecipe.id,
                recipeId: recipe.id.uuidString,
                creatorId: publicRecipe.ownerId
            )

            return recipe

        } catch {
            Log.error("Failed to save recipe", category: .social, metadata: [
                "publicRecipeId": publicRecipe.id,
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    /// Track save on a public recipe (calls Cloud Function)
    private func trackSave(publicRecipeId: String) async throws {
        do {
            let callable = functions.httpsCallable("incrementPublicRecipeSave")
            let result = try await callable.call(["recipeId": publicRecipeId])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                let saveCount = data["saveCount"] as? Int ?? 0

                Log.debug("Save tracked", category: .social, metadata: [
                    "recipeId": publicRecipeId,
                    "saveCount": saveCount
                ])
            }

        } catch {
            Log.warning("Failed to track save", category: .social, metadata: [
                "recipeId": publicRecipeId,
                "error": error.localizedDescription
            ])
            // Don't throw - save tracking is non-critical
        }
    }

    // MARK: - Cache Management

    func clearCache() {
        trendingCache = nil
        newCache = nil
        popularCache = nil
        searchCache.removeAll()
        Log.info("Discovery cache cleared", category: .social)
    }
}

// MARK: - Analytics Extensions

extension DiscoveryAnalytics {
    static func trackPublicRecipeSaved(
        publicRecipeId: String,
        recipeId: String,
        creatorId: String
    ) {
        // TODO: Implement analytics tracking
        // Analytics.track("public_recipe_saved", properties: [...])
    }
}
