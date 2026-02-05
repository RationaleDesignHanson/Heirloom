//
//  DiscoveryService.swift
//  Heirloom
//
//  Service for discovering and fetching public recipes
//  Phase 4: Discovery feed with search, pagination, and caching
//

import Foundation
import FirebaseFirestore
// import FirebaseFunctions  // TODO: Re-enable when Firebase Functions package is added
import SwiftData
import UIKit

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
    case alreadySaved

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
        case .alreadySaved:
            return "You've already saved this recipe to your collection."
        }
    }
}

// MARK: - Implementation

/// Firebase implementation of discovery service
@MainActor
class FirebaseDiscoveryService: DiscoveryServiceProtocol {

    // MARK: - Dependencies

    private let db: Firestore
    private let session: URLSession
    // private let functions: Functions  // TODO: Re-enable when Firebase Functions package is added

    /// Current user ID for filtering out own recipes
    private var currentUserId: String? {
        FirebaseAuthService.shared.currentUserId
    }

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

    // MARK: - Filtering

    /// Filter out current user's own recipes and hidden/moderated recipes from discovery results
    /// Users should not discover their own recipes or content that has been hidden by moderation
    private func filterOutOwnRecipes(_ recipes: [PublicRecipe]) -> [PublicRecipe] {
        var filtered = recipes

        // Filter out hidden/moderated recipes
        filtered = filtered.filter { !$0.isHidden }

        // Filter out current user's own recipes
        if let userId = currentUserId {
            filtered = filtered.filter { $0.ownerId != userId }
        }

        return filtered
    }

    // MARK: - Initialization

    init(
        firestore: Firestore = Firestore.firestore()
        // functions: Functions = Functions.functions()  // TODO: Re-enable when Firebase Functions package is added
    ) {
        self.db = firestore
        // self.functions = functions  // TODO: Re-enable when Firebase Functions package is added

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Fetch Methods

    /// Fetch trending recipes (high trending score)
    func fetchTrending(limit: Int = 20, lastDocument: DocumentSnapshot? = nil) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?) {
        // Check cache for first page only
        if lastDocument == nil, let cached = trendingCache, !cached.isExpired {
            Log.debug("Trending cache hit", category: .social)
            return (filterOutOwnRecipes(cached.recipes), nil)
        }

        var query = db.collection("publicRecipes")
            .order(by: "trendingScore", descending: true)
            .limit(to: limit)

        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }

        do {
            let snapshot = try await query.getDocuments()
            let allRecipes = try snapshot.documents.compactMap { doc -> PublicRecipe? in
                try PublicRecipe(from: doc)
            }

            // Cache first page (unfiltered for user-independent cache)
            if lastDocument == nil {
                trendingCache = CachedResult(recipes: allRecipes, timestamp: Date())
            }

            // Filter out current user's own recipes
            let recipes = filterOutOwnRecipes(allRecipes)

            Log.info("Fetched trending recipes", category: .social, metadata: [
                "count": recipes.count,
                "filtered_out": allRecipes.count - recipes.count,
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
            return (filterOutOwnRecipes(cached.recipes), nil)
        }

        var query = db.collection("publicRecipes")
            .order(by: "publishedAt", descending: true)
            .limit(to: limit)

        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }

        do {
            let snapshot = try await query.getDocuments()
            let allRecipes = try snapshot.documents.compactMap { doc -> PublicRecipe? in
                try PublicRecipe(from: doc)
            }

            // Cache first page (unfiltered for user-independent cache)
            if lastDocument == nil {
                newCache = CachedResult(recipes: allRecipes, timestamp: Date())
            }

            // Filter out current user's own recipes
            let recipes = filterOutOwnRecipes(allRecipes)

            Log.info("Fetched new recipes", category: .social, metadata: [
                "count": recipes.count,
                "filtered_out": allRecipes.count - recipes.count
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
            return (filterOutOwnRecipes(cached.recipes), nil)
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
            let allRecipes = try snapshot.documents.compactMap { doc -> PublicRecipe? in
                try PublicRecipe(from: doc)
            }

            // Cache first page (unfiltered for user-independent cache)
            if lastDocument == nil {
                popularCache = CachedResult(recipes: allRecipes, timestamp: Date())
            }

            // Filter out current user's own recipes
            let recipes = filterOutOwnRecipes(allRecipes)

            Log.info("Fetched popular recipes", category: .social, metadata: [
                "count": recipes.count,
                "filtered_out": allRecipes.count - recipes.count
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

    /// Search recipes by keywords using Algolia (typo-tolerant fuzzy search)
    /// Falls back to Firestore array-contains if Algolia fails
    func search(query: String, limit: Int = 20, lastDocument: DocumentSnapshot? = nil) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespaces)

        guard normalizedQuery.count >= 2 else {
            throw DiscoveryError.invalidQuery
        }

        // Check cache for first page only
        let cacheKey = normalizedQuery.lowercased()
        if lastDocument == nil, let cached = searchCache[cacheKey], !cached.isExpired {
            Log.debug("Search cache hit", category: .social, metadata: ["query": normalizedQuery])
            return (filterOutOwnRecipes(cached.recipes), nil)
        }

        // Use Algolia for search (typo-tolerant, fuzzy matching)
        do {
            let algoliaService = ServiceContainer.shared.resolve(AlgoliaSearchService.self)
            let searchResults = try await algoliaService.searchPublicRecipes(query: normalizedQuery, limit: limit)

            // Fetch full PublicRecipe documents from Firestore based on Algolia IDs
            var recipes: [PublicRecipe] = []
            for result in searchResults {
                if let recipe = try await fetchPublicRecipe(id: result.id) {
                    recipes.append(recipe)
                }
            }

            // Filter out current user's own recipes
            let filteredCount = recipes.count
            recipes = filterOutOwnRecipes(recipes)

            // Cache first page
            if lastDocument == nil {
                searchCache[cacheKey] = CachedResult(recipes: recipes, timestamp: Date())
            }

            Log.info("Algolia search completed", category: .social, metadata: [
                "query": normalizedQuery,
                "algoliaResults": searchResults.count,
                "finalResults": recipes.count,
                "filtered_out": filteredCount - recipes.count
            ])

            // Note: Algolia doesn't support cursor-based pagination like Firestore
            // For now, return nil for lastDoc (no pagination support with Algolia)
            return (recipes, nil)

        } catch {
            // Fall back to Firestore search if Algolia fails
            Log.warning("Algolia search failed, falling back to Firestore", category: .social, metadata: [
                "query": normalizedQuery,
                "error": error.localizedDescription
            ])
            return try await searchWithFirestore(query: normalizedQuery, limit: limit, lastDocument: lastDocument)
        }
    }

    /// Fallback Firestore-based search using array-contains
    private func searchWithFirestore(query: String, limit: Int, lastDocument: DocumentSnapshot?) async throws -> (recipes: [PublicRecipe], lastDoc: DocumentSnapshot?) {
        let normalizedQuery = query.lowercased()

        // Split query into words for multi-term search
        let searchTerms = normalizedQuery.components(separatedBy: .whitespaces).filter { $0.count >= 3 }
        guard let firstTerm = searchTerms.first else {
            throw DiscoveryError.invalidQuery
        }

        // Firestore array-contains only works with single value
        var query = db.collection("publicRecipes")
            .whereField("searchKeywords", arrayContains: firstTerm)
            .order(by: "publishedAt", descending: true)
            .limit(to: limit * 2)

        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }

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

        recipes = filterOutOwnRecipes(recipes)
        recipes = Array(recipes.prefix(limit))

        return (recipes, snapshot.documents.last)
    }

    /// Fetch a single public recipe by ID
    /// Returns nil if recipe is hidden (unless viewer is the owner)
    func fetchPublicRecipe(id: String) async throws -> PublicRecipe? {
        do {
            let doc = try await db.collection("publicRecipes").document(id).getDocument()

            guard doc.exists else {
                Log.warning("Public recipe not found", category: .social, metadata: ["id": id])
                return nil
            }

            let recipe = try PublicRecipe(from: doc)

            // Check if recipe is hidden by moderation
            // Allow owners to view their own hidden recipes
            if recipe.isHidden && recipe.ownerId != currentUserId {
                Log.warning("Public recipe is hidden", category: .social, metadata: ["id": id])
                return nil
            }

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

    /// Track view on a public recipe (direct Firestore increment - TODO: migrate to Cloud Function)
    func trackView(publicRecipeId: String) async throws {
        do {
            // Direct Firestore increment (bypassing Cloud Function for now)
            // TODO: Re-enable Cloud Function when FirebaseFunctions package is added
            let docRef = db.collection("publicRecipes").document(publicRecipeId)
            try await docRef.updateData([
                "viewCount": FieldValue.increment(Int64(1)),
                "updatedAt": FieldValue.serverTimestamp()
            ])

            Log.debug("View tracked (direct Firestore)", category: .social, metadata: [
                "recipeId": publicRecipeId
            ])

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
        // Check for duplicates - prevent saving the same public recipe twice
        let publicRecipeIdToCheck: String? = publicRecipe.id  // Make explicitly optional for predicate comparison
        let duplicateDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.sourcePublicRecipeId == publicRecipeIdToCheck
            }
        )

        if let existingRecipe = try context.fetch(duplicateDescriptor).first {
            Log.warning("Recipe already saved", category: .social, metadata: [
                "publicRecipeId": publicRecipe.id,
                "existingRecipeId": existingRecipe.id.uuidString
            ])
            throw DiscoveryError.alreadySaved
        }

        // Create local recipe from public recipe
        let recipe = Recipe(
            title: publicRecipe.title,
            sourceType: .family,  // Saved from community
            instructions: publicRecipe.instructions,
            servings: publicRecipe.servings,
            prepTime: publicRecipe.prepTime,
            cookTime: publicRecipe.cookTime
        )

        // Copy totalTime if present
        recipe.totalTime = publicRecipe.totalTime

        // Set upstream attribution (fork model)
        recipe.sourcePublicRecipeId = publicRecipe.id
        recipe.sourcePublicRecipeCreatorId = publicRecipe.ownerId
        recipe.sourcePublicRecipeCreatorName = publicRecipe.creatorName
        recipe.sourcePublicRecipeLastSynced = Date()
        recipe.sourcePublicRecipeStillAvailable = true

        // Find or create "Community Recipes" collection
        let communityCollection = try findOrCreateCommunityCollection(context: context)

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

        // Add to Community Recipes collection (bidirectional relationship)
        if communityCollection.recipes == nil {
            communityCollection.recipes = []
        }
        communityCollection.recipes?.append(recipe)

        // Also add collection to recipe (ensure bidirectional relationship)
        if recipe.collections == nil {
            recipe.collections = []
        }
        recipe.collections?.append(communityCollection)

        // Download and save image from public recipe
        if let imageURL = publicRecipe.imageURL {
            do {
                Log.info("Downloading public recipe image", category: .social, metadata: [
                    "imageURL": imageURL,
                    "recipeId": recipe.id.uuidString
                ])

                // Download image
                guard let url = URL(string: imageURL) else {
                    Log.warning("Invalid image URL", category: .social, metadata: ["imageURL": imageURL])
                    throw DiscoveryError.firestoreError(NSError(domain: "Invalid URL", code: -1))
                }

                let (data, _) = try await session.data(from: url)

                guard let image = UIImage(data: data) else {
                    Log.warning("Failed to create image from data", category: .social)
                    throw DiscoveryError.firestoreError(NSError(domain: "Invalid image data", code: -1))
                }

                // Save to local storage
                let imageStorage = ServiceContainer.shared.resolve(ImageStorageService.self)
                let fileName = try await imageStorage.saveImage(image, recipeId: recipe.id)
                recipe.imageFileName = fileName

                Log.info("Saved public recipe image", category: .social, metadata: [
                    "fileName": fileName,
                    "recipeId": recipe.id.uuidString
                ])
            } catch {
                Log.warning("Failed to download public recipe image", category: .social, metadata: [
                    "error": error.localizedDescription,
                    "imageURL": imageURL
                ])
                // Don't fail the entire save if image download fails
            }
        }

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

    /// Find or create the "Community Recipes" collection for saved public recipes
    private func findOrCreateCommunityCollection(context: ModelContext) throws -> RecipeCollection {
        // Try to find existing Community Recipes collection
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { $0.name == "Community Recipes" }
        )

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        // Create new Community Recipes collection
        let collection = RecipeCollection(
            name: "Community Recipes",
            description: "Recipes saved from the community",
            iconName: "globe",
            color: "#2D5A27",  // HeirloomColors.familyGreen
            isSystemCollection: false,  // Show in My Collections section
            collectionType: .communityRecipes
        )

        context.insert(collection)

        Log.info("Created Community Recipes collection", category: .social)

        return collection
    }

    /// Track save on a public recipe (direct Firestore increment - TODO: migrate to Cloud Function)
    private func trackSave(publicRecipeId: String) async throws {
        do {
            // Direct Firestore increment (bypassing Cloud Function for now)
            // TODO: Re-enable Cloud Function when FirebaseFunctions package is added
            let docRef = db.collection("publicRecipes").document(publicRecipeId)
            try await docRef.updateData([
                "saveCount": FieldValue.increment(Int64(1)),
                "updatedAt": FieldValue.serverTimestamp()
            ])

            Log.debug("Save tracked (direct Firestore)", category: .social, metadata: [
                "recipeId": publicRecipeId
            ])

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
