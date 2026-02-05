//
//  AlgoliaSearchService.swift
//  Heirloom
//
//  Phase 7 Enhanced: Algolia fuzzy search integration
//  Provides typo-tolerant search with instant results
//

import Foundation
import Search

protocol SearchServiceProtocol {
    func searchUsers(query: String, filters: SearchFilters?) async throws -> [UserSearchResult]
    func searchPublicRecipes(query: String, limit: Int) async throws -> [PublicRecipeSearchResult]
}

// Decodable wrapper for Algolia user search hits
private struct AlgoliaUserHit: Codable {
    let objectID: String
    let displayName: String
    let email: String?
    let photoURL: String?
    let bio: String?
}

// Legacy alias
private typealias AlgoliaHit = AlgoliaUserHit

// Decodable wrapper for Algolia public recipe search hits
private struct AlgoliaPublicRecipeHit: Codable {
    let objectID: String
    let title: String
    let description: String?
    let creatorName: String
    let creatorId: String?
    let creatorPhotoURL: String?
    let imageURL: String?
    let tags: [String]?
    let category: String?
    let viewCount: Int?
    let saveCount: Int?
    let servings: String?
    let prepTime: String?
    let cookTime: String?
}

/// Search result for public recipes from Algolia
struct PublicRecipeSearchResult: Identifiable {
    let id: String
    let title: String
    let description: String?
    let creatorName: String
    let creatorId: String?
    let creatorPhotoURL: String?
    let imageURL: String?
    let tags: [String]
    let category: String?
    let viewCount: Int
    let saveCount: Int
    let servings: String?
    let prepTime: String?
    let cookTime: String?
}

@MainActor
class AlgoliaSearchService: SearchServiceProtocol {
    private let searchClient: SearchClient
    private let usersIndexName = "users"
    private let publicRecipesIndexName = "public_recipes"

    // Legacy alias
    private var indexName: String { usersIndexName }

    init() {
        // Initialize with app credentials
        let appID = "A1DITUD2QN"
        let apiKey = "4e4be19553e7b15c90aeba9bbebb6fe0" // Search-only key (safe for client)
        self.searchClient = try! SearchClient(appID: appID, apiKey: apiKey)
    }

    func searchUsers(query: String, filters: SearchFilters? = nil) async throws -> [UserSearchResult] {
        guard query.count >= 2 else { return [] }

        // Build filter string
        var filterString: String?
        if let filters = filters, filters.isActive {
            var filterStrings: [String] = []

            if let location = filters.location {
                filterStrings.append("location:\"\(location)\"")
            }

            if let specialties = filters.specialties, !specialties.isEmpty {
                let specialtyFilter = specialties.map { "specialties:\"\($0)\"" }.joined(separator: " OR ")
                filterStrings.append("(\(specialtyFilter))")
            }

            if !filterStrings.isEmpty {
                filterString = filterStrings.joined(separator: " AND ")
            }
        }

        // Create search request with proper parameter order
        var searchParams = SearchForHits(
            query: query,
            hitsPerPage: 20,
            indexName: indexName
        )

        // Add filters if present
        if let filterString = filterString {
            searchParams.filters = filterString
        }

        // Perform search with AlgoliaHit as the generic type
        let response: SearchResponses<AlgoliaHit> = try await searchClient.search(
            searchMethodParams: SearchMethodParams(requests: [SearchQuery.searchForHits(searchParams)])
        )

        // Parse results from first response
        guard let firstResult = response.results.first else {
            return []
        }

        // Parse hits based on result type
        var results: [UserSearchResult] = []

        if case .searchResponse(let searchResponse) = firstResult {
            results = searchResponse.hits.map { hit in
                UserSearchResult(
                    id: hit.objectID,
                    displayName: hit.displayName,
                    email: hit.email,
                    photoURL: hit.photoURL,
                    bio: hit.bio
                )
            }
        }

        return results
    }

    /// Search public recipes via Algolia
    /// Supports typo-tolerant search on title, creator name, ingredients, tags
    func searchPublicRecipes(query: String, limit: Int = 20) async throws -> [PublicRecipeSearchResult] {
        guard query.count >= 2 else { return [] }

        // Create search request
        let searchParams = SearchForHits(
            query: query,
            hitsPerPage: limit,
            indexName: publicRecipesIndexName
        )

        // Perform search
        let response: SearchResponses<AlgoliaPublicRecipeHit> = try await searchClient.search(
            searchMethodParams: SearchMethodParams(requests: [SearchQuery.searchForHits(searchParams)])
        )

        // Parse results from first response
        guard let firstResult = response.results.first else {
            return []
        }

        var results: [PublicRecipeSearchResult] = []

        if case .searchResponse(let searchResponse) = firstResult {
            results = searchResponse.hits.map { hit in
                PublicRecipeSearchResult(
                    id: hit.objectID,
                    title: hit.title,
                    description: hit.description,
                    creatorName: hit.creatorName,
                    creatorId: hit.creatorId,
                    creatorPhotoURL: hit.creatorPhotoURL,
                    imageURL: hit.imageURL,
                    tags: hit.tags ?? [],
                    category: hit.category,
                    viewCount: hit.viewCount ?? 0,
                    saveCount: hit.saveCount ?? 0,
                    servings: hit.servings,
                    prepTime: hit.prepTime,
                    cookTime: hit.cookTime
                )
            }
        }

        Log.info("Algolia public recipe search", category: .social, metadata: [
            "query": query,
            "results": results.count
        ])

        return results
    }
}
