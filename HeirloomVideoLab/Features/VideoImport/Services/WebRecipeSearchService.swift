//
//  WebRecipeSearchService.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/9/26.
//
//  Service for searching web for similar recipes using DuckDuckGo HTML API
//  Leverages existing RecipeImportService for parsing recipe pages

import Foundation
import SwiftSoup

@MainActor
class WebRecipeSearchService {
    private let recipeImportService: RecipeImportService
    private let session: URLSession
    private static let maxWebSearches = 3 // Limit to control processing time

    init(recipeImportService: RecipeImportService) {
        self.recipeImportService = recipeImportService

        // Configure URLSession with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Convenience initializer with default RecipeImportService
    convenience init() {
        self.init(recipeImportService: RecipeImportService())
    }

    // MARK: - Public API

    /// Search web for similar recipes
    /// - Parameter extractedRecipe: Recipe extracted from video
    /// - Returns: Array of web recipe results
    func searchSimilarRecipes(
        for extractedRecipe: StructuredRecipe
    ) async throws -> [WebRecipeResult] {
        print("🔍 Searching web for similar recipes to: \(extractedRecipe.title)")

        // 1. Construct search query from extracted recipe
        let query = buildSearchQuery(from: extractedRecipe)
        print("🔍 Search query: \(query)")

        // 2. Use DuckDuckGo HTML API (free, no API key)
        let searchResults = try await performDuckDuckGoSearch(query: query)
        print("🔍 Found \(searchResults.count) search results")

        // 3. Filter for recipe sites
        let recipeURLs = filterRecipeURLs(searchResults)
            .prefix(Self.maxWebSearches)
        print("🔍 Filtered to \(recipeURLs.count) recipe URLs")

        // 4. Fetch and parse recipes in parallel
        return await withTaskGroup(of: WebRecipeResult?.self) { group in
            for url in recipeURLs {
                group.addTask {
                    do {
                        return try await self.fetchRecipe(from: url, originalQuery: extractedRecipe.title)
                    } catch {
                        print("⚠️ Failed to fetch recipe from \(url): \(error.localizedDescription)")
                        return nil
                    }
                }
            }

            var results: [WebRecipeResult] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }
    }

    // MARK: - Search Implementation

    /// Perform DuckDuckGo HTML search
    private func performDuckDuckGoSearch(query: String) async throws -> [SearchResult] {
        // DuckDuckGo HTML search (no API key required)
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") else {
            throw WebSearchError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WebSearchError.networkError
        }

        // Parse HTML response
        return try parseDuckDuckGoHTML(data)
    }

    /// Parse DuckDuckGo HTML response
    private func parseDuckDuckGoHTML(_ data: Data) throws -> [SearchResult] {
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw WebSearchError.parseError
        }

        let doc = try SwiftSoup.parse(htmlString)
        let results = try doc.select("div.result")

        var searchResults: [SearchResult] = []

        for result in results {
            // Extract title
            guard let titleElement = try? result.select("a.result__a").first(),
                  let title = try? titleElement.text(),
                  !title.isEmpty else {
                continue
            }

            // Extract URL
            guard let urlString = try? titleElement.attr("href"),
                  !urlString.isEmpty else {
                continue
            }

            // Extract snippet
            let snippet = (try? result.select("a.result__snippet").first()?.text()) ?? ""

            searchResults.append(SearchResult(
                title: title,
                url: urlString,
                snippet: snippet
            ))
        }

        return searchResults
    }

    /// Build search query from extracted recipe
    private func buildSearchQuery(from recipe: StructuredRecipe) -> String {
        // Extract key ingredients (first 3-4 most important)
        let keyIngredients = recipe.ingredients
            .prefix(4)
            .map { $0.item }
            .joined(separator: " ")

        // Include recipe title
        let title = recipe.title

        // Construct query optimized for recipe sites
        // Target popular recipe sites for better quality results
        return "\(title) \(keyIngredients) recipe site:allrecipes.com OR site:foodnetwork.com OR site:seriouseats.com OR site:bonappetit.com"
    }

    /// Filter search results to keep only recipe URLs
    private func filterRecipeURLs(_ searchResults: [SearchResult]) -> [String] {
        // Trusted recipe domains
        let trustedDomains = [
            "allrecipes.com",
            "foodnetwork.com",
            "seriouseats.com",
            "bonappetit.com",
            "epicurious.com",
            "nytimes.com",
            "tasteofhome.com",
            "delish.com",
            "simplyrecipes.com",
            "thekitchn.com"
        ]

        return searchResults
            .compactMap { result in
                guard let url = URL(string: result.url),
                      let host = url.host() else {
                    return nil
                }

                // Check if domain is trusted
                let isTrusted = trustedDomains.contains { host.contains($0) }

                return isTrusted ? result.url : nil
            }
    }

    // MARK: - Recipe Fetching

    /// Fetch and parse a recipe from URL
    private func fetchRecipe(from urlString: String, originalQuery: String) async throws -> WebRecipeResult {
        print("📥 Fetching recipe from: \(urlString)")

        // Use existing RecipeImportService to parse the recipe
        let importedRecipe = try await recipeImportService.importRecipe(from: urlString)

        print("✅ Successfully parsed recipe: \(importedRecipe.title)")

        // Convert ingredients to WebRecipeResult format
        let ingredients = importedRecipe.ingredients.map { ingredientText in
            WebRecipeResult.ImportedIngredient(
                text: ingredientText,
                parsedQuantity: nil,  // Could enhance with parsing
                parsedUnit: nil,
                parsedName: extractIngredientName(from: ingredientText)
            )
        }

        // Calculate similarity score to original query
        let similarityScore = calculateSimilarity(
            importedTitle: importedRecipe.title,
            importedIngredients: ingredients,
            originalQuery: originalQuery
        )

        return WebRecipeResult(
            title: importedRecipe.title,
            sourceURL: urlString,
            ingredients: ingredients,
            instructions: importedRecipe.instructions,
            servings: importedRecipe.servings,
            similarityScore: similarityScore
        )
    }

    /// Extract ingredient name from text (simple heuristic)
    private func extractIngredientName(from text: String) -> String? {
        // Remove measurements and quantities
        let cleaned = text
            .replacingOccurrences(of: #"\d+[\s\-/]*\d*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(cup|tablespoon|teaspoon|tbsp|tsp|oz|lb|gram|kg)s?"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Take first few words as ingredient name
        let words = cleaned.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .prefix(3)

        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    /// Calculate similarity between imported recipe and original query
    private func calculateSimilarity(
        importedTitle: String,
        importedIngredients: [WebRecipeResult.ImportedIngredient],
        originalQuery: String
    ) -> Double {
        // Simple title-based similarity for now
        let queryWords = Set(originalQuery.lowercased().components(separatedBy: .whitespaces))
        let titleWords = Set(importedTitle.lowercased().components(separatedBy: .whitespaces))

        let intersection = queryWords.intersection(titleWords)
        let union = queryWords.union(titleWords)

        guard !union.isEmpty else { return 0.0 }

        return Double(intersection.count) / Double(union.count)
    }
}

// MARK: - Supporting Types

/// Search result from DuckDuckGo
private struct SearchResult {
    let title: String
    let url: String
    let snippet: String
}

/// Errors for web search
enum WebSearchError: LocalizedError {
    case invalidQuery
    case networkError
    case parseError
    case noResultsFound

    var errorDescription: String? {
        switch self {
        case .invalidQuery: return "Invalid search query"
        case .networkError: return "Network error during search"
        case .parseError: return "Failed to parse search results"
        case .noResultsFound: return "No recipe results found"
        }
    }
}

// MARK: - Note
// ImportedRecipe type is defined in RecipeImportService.swift
// We use that existing type instead of defining a duplicate
