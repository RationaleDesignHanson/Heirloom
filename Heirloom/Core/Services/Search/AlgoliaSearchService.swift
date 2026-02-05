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
}

// Decodable wrapper for Algolia search hits
private struct AlgoliaHit: Codable {
    let objectID: String
    let displayName: String
    let email: String?
    let photoURL: String?
    let bio: String?
}

@MainActor
class AlgoliaSearchService: SearchServiceProtocol {
    private let searchClient: SearchClient?
    private let indexName = "users"

    init() {
        // Initialize with app credentials
        let appID = "A1DITUD2QN"
        let apiKey = "4e4be19553e7b15c90aeba9bbebb6fe0" // Search-only key (safe for client)
        do {
            self.searchClient = try SearchClient(appID: appID, apiKey: apiKey)
        } catch {
            Log.error("Failed to initialize Algolia SearchClient", category: .general, metadata: ["error": error.localizedDescription])
            self.searchClient = nil
        }
    }

    func searchUsers(query: String, filters: SearchFilters? = nil) async throws -> [UserSearchResult] {
        guard query.count >= 2 else { return [] }

        guard let searchClient = searchClient else {
            Log.warning("Search unavailable - Algolia client not initialized", category: .general)
            return []
        }

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
}
