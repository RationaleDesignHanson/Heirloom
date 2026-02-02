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
        #if DEBUG
        print("🔍 Searching web for similar recipes to: \(extractedRecipe.title)")
        #endif

        // 1. Try exact title search first
        let exactQuery = buildSearchQuery(from: extractedRecipe)
        #if DEBUG
        print("🔍 Exact search query: \(exactQuery)")
        #endif

        var searchResults = try await performDuckDuckGoSearch(query: exactQuery)
        #if DEBUG
        print("🔍 Found \(searchResults.count) exact match results")
        #endif

        // 2. If no results, try broader search with key ingredients
        if searchResults.isEmpty {
            #if DEBUG
            print("🔍 No exact matches - trying broader search with key ingredients")
            #endif
            let broaderQuery = buildBroaderQuery(from: extractedRecipe)
            #if DEBUG
            print("🔍 Broader search query: \(broaderQuery)")
            #endif
            searchResults = try await performDuckDuckGoSearch(query: broaderQuery)
            #if DEBUG
            print("🔍 Found \(searchResults.count) broader results")
            #endif
        }

        // 3. Filter for recipe sites
        let recipeURLs = filterRecipeURLs(searchResults)
            .prefix(Self.maxWebSearches)
        #if DEBUG
        print("🔍 Filtered to \(recipeURLs.count) recipe URLs")
        #endif

        // 4. Fetch and parse recipes in parallel
        return await withTaskGroup(of: WebRecipeResult?.self) { group in
            for url in recipeURLs {
                group.addTask {
                    do {
                        return try await self.fetchRecipe(from: url, originalQuery: extractedRecipe.title)
                    } catch {
                        #if DEBUG
                        print("⚠️ Failed to fetch recipe from \(url): \(error.localizedDescription)")
                        #endif
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

    /// Perform web search using multiple fallback strategies
    private func performDuckDuckGoSearch(query: String) async throws -> [SearchResult] {
        // Try Brave Search API first (free tier: 2000/month)
        // https://brave.com/search/api/
        // If no API key, fallback to direct recipe site search

        if let braveResults = try? await performBraveSearch(query) {
            #if DEBUG
            print("🔍 Using Brave Search API (\(braveResults.count) results)")
            #endif
            return braveResults
        }

        // Fallback: Direct recipe site search (no search engine needed)
        #if DEBUG
        print("🔍 Fallback: Searching recipe sites directly")
        #endif
        return try await searchRecipeSitesDirectly(query)
    }

    /// Brave Search API (free tier, no blocking)
    private func performBraveSearch(_ query: String) async throws -> [SearchResult] {
        // Get API key from environment or config
        guard let apiKey = ProcessInfo.processInfo.environment["BRAVE_SEARCH_API_KEY"] ?? getHardcodedBraveKey() else {
            throw WebSearchError.networkError
        }

        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.search.brave.com/res/v1/web/search?q=\(encodedQuery)&count=10") else {
            throw WebSearchError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebSearchError.networkError
        }

        if httpResponse.statusCode == 401 {
            #if DEBUG
            print("⚠️ Brave Search API: Invalid or missing API key")
            #endif
            throw WebSearchError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            #if DEBUG
            print("⚠️ Brave Search API returned status \(httpResponse.statusCode)")
            #endif
            throw WebSearchError.networkError
        }

        return try parseBraveSearchJSON(data)
    }

    /// Parse Brave Search JSON response
    private func parseBraveSearchJSON(_ data: Data) throws -> [SearchResult] {
        struct BraveResponse: Codable {
            let web: WebResults?

            struct WebResults: Codable {
                let results: [Result]

                struct Result: Codable {
                    let title: String
                    let url: String
                    let description: String?
                }
            }
        }

        let decoder = JSONDecoder()
        let braveResponse = try decoder.decode(BraveResponse.self, from: data)

        guard let results = braveResponse.web?.results else {
            return []
        }

        return results.map { result in
            SearchResult(
                title: result.title,
                url: result.url,
                snippet: result.description ?? ""
            )
        }
    }

    /// Hardcoded Brave API key for VideoLab (free tier)
    private func getHardcodedBraveKey() -> String? {
        // Brave Search API key
        // Free tier: 2,000 queries/month
        // Get yours at: https://brave.com/search/api/
        return "BSAlCWqf1tp_j98WflvJLH8xCgn2ZUu"
    }

    /// Fallback: Search recipe sites directly without search engine
    private func searchRecipeSitesDirectly(_ query: String) async throws -> [SearchResult] {
        // Extract recipe name and cuisine
        let recipeName = query
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: " recipe", with: "")
            .replacingOccurrences(of: " site:", with: "")
            .replacingOccurrences(of: "allrecipes.com OR foodnetwork.com OR seriouseats.com OR bonappetit.com", with: "")
            .trimmingCharacters(in: .whitespaces)

        #if DEBUG
        print("🔍 Scraping recipe sites directly for: \(recipeName)")
        #endif

        // Try AllRecipes first (most reliable structure)
        if let allRecipesResults = try? await scrapeAllRecipes(recipeName) {
            #if DEBUG
            print("✅ Found \(allRecipesResults.count) recipes from AllRecipes")
            #endif
            if !allRecipesResults.isEmpty {
                return allRecipesResults
            }
        }

        // Try FoodNetwork as fallback
        if let foodNetworkResults = try? await scrapeFoodNetwork(recipeName) {
            #if DEBUG
            print("✅ Found \(foodNetworkResults.count) recipes from FoodNetwork")
            #endif
            if !foodNetworkResults.isEmpty {
                return foodNetworkResults
            }
        }

        // Last resort: return empty (augmentation will use Claude knowledge only)
        #if DEBUG
        print("⚠️ No recipes found from direct site scraping")
        #endif
        return []
    }

    /// Scrape AllRecipes search results
    private func scrapeAllRecipes(_ recipeName: String) async throws -> [SearchResult] {
        let searchTerms = recipeName
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? recipeName

        guard let url = URL(string: "https://www.allrecipes.com/search?q=\(searchTerms)") else {
            throw WebSearchError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let htmlString = String(data: data, encoding: .utf8) else {
            throw WebSearchError.networkError
        }

        // Parse HTML for recipe links
        let doc = try SwiftSoup.parse(htmlString)

        // AllRecipes structure: <a class="mntl-card-list-items" href="/recipe/...">
        let recipeLinks = try doc.select("a[href*='/recipe/']")

        var results: [SearchResult] = []
        for link in recipeLinks.prefix(5) {
            guard let href = try? link.attr("href"),
                  href.contains("/recipe/"),
                  !href.contains("/recipes/") else { // Skip listing pages
                continue
            }

            let fullURL = href.hasPrefix("http") ? href : "https://www.allrecipes.com\(href)"
            let title = (try? link.text()) ?? recipeName

            results.append(SearchResult(
                title: title,
                url: fullURL,
                snippet: "From AllRecipes"
            ))
        }

        return results
    }

    /// Scrape FoodNetwork search results
    private func scrapeFoodNetwork(_ recipeName: String) async throws -> [SearchResult] {
        let searchTerms = recipeName
            .replacingOccurrences(of: " ", with: "+")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? recipeName

        guard let url = URL(string: "https://www.foodnetwork.com/search/\(searchTerms)-") else {
            throw WebSearchError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let htmlString = String(data: data, encoding: .utf8) else {
            throw WebSearchError.networkError
        }

        // Parse HTML for recipe links
        let doc = try SwiftSoup.parse(htmlString)

        // FoodNetwork structure: Look for recipe URLs
        let recipeLinks = try doc.select("a[href*='/recipes/']")

        var results: [SearchResult] = []
        var seenURLs = Set<String>()

        for link in recipeLinks {
            guard let href = try? link.attr("href"),
                  href.contains("/recipes/"),
                  !seenURLs.contains(href) else {
                continue
            }

            let fullURL = href.hasPrefix("http") ? href : "https://www.foodnetwork.com\(href)"
            let title = (try? link.text()) ?? recipeName

            seenURLs.insert(href)
            results.append(SearchResult(
                title: title,
                url: fullURL,
                snippet: "From FoodNetwork"
            ))

            if results.count >= 5 { break }
        }

        return results
    }

    /// Parse DuckDuckGo HTML response
    private func parseDuckDuckGoHTML(_ data: Data) throws -> [SearchResult] {
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw WebSearchError.parseError
        }

        let doc = try SwiftSoup.parse(htmlString)
        let results = try doc.select("div.result")

        var searchResults: [SearchResult] = []

        for (_, result) in results.enumerated() {
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
        // For specific dish names (2-4 words), just use the title - it's already descriptive
        // Examples: "Butter Chicken", "Chocolate Chip Cookies", "Beef Wellington"
        let title = recipe.title
        let titleWords = title.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // Detect cuisine type from ingredients and title
        let cuisine = detectCuisine(title: title, ingredients: recipe.ingredients)

        // If title is specific enough (2-4 words), use ONLY the title + cuisine
        // Don't try to add ingredients - they'll just dilute the search
        if titleWords.count >= 2 && titleWords.count <= 4 {
            if let cuisineType = cuisine {
                return "\"\(title)\" \(cuisineType) recipe site:allrecipes.com OR site:foodnetwork.com OR site:seriouseats.com OR site:bonappetit.com"
            } else {
                return "\"\(title)\" recipe site:allrecipes.com OR site:foodnetwork.com OR site:seriouseats.com OR site:bonappetit.com"
            }
        }

        // Only if title is vague (1 word or 5+ words), add distinctive ingredients
        // Examples of vague titles: "Dinner", "Mom's Special Recipe", "Quick Easy Weeknight Meal"
        let distinctiveIngredients = recipe.ingredients
            .map { $0.item.lowercased() }
            .filter { ingredient in
                // Only use truly distinctive ingredients (not butter, chicken, oil, etc.)
                let isDistinctive = !ingredient.isEmpty &&
                    ingredient != "butter" &&
                    ingredient != "chicken" &&
                    ingredient != "beef" &&
                    ingredient != "pork" &&
                    ingredient != "fish" &&
                    ingredient != "oil" &&
                    ingredient != "salt" &&
                    ingredient != "pepper" &&
                    ingredient != "water" &&
                    ingredient != "flour" &&
                    ingredient != "sugar" &&
                    ingredient != "egg"
                return isDistinctive
            }
            .prefix(2)
            .joined(separator: " ")

        // Add ingredients only if title is vague
        if !distinctiveIngredients.isEmpty {
            return "\"\(title)\" \(distinctiveIngredients) recipe site:allrecipes.com OR site:foodnetwork.com OR site:seriouseats.com OR site:bonappetit.com"
        } else {
            return "\"\(title)\" recipe site:allrecipes.com OR site:foodnetwork.com OR site:seriouseats.com OR site:bonappetit.com"
        }
    }

    /// Build broader search query when exact title yields no results
    /// Extracts key ingredients and main protein/dish type
    private func buildBroaderQuery(from recipe: StructuredRecipe) -> String {
        let title = recipe.title.lowercased()

        // Extract main protein or dish type from title
        let mainDishWords = ["chicken", "beef", "pork", "fish", "salmon", "shrimp", "pasta", "rice", "noodles"]
        let mainDish = mainDishWords.first { title.contains($0) } ?? ""

        // Get most distinctive ingredients (2-3)
        let distinctiveIngredients = recipe.ingredients
            .map { $0.item.lowercased() }
            .filter { ingredient in
                // These are flavor-defining ingredients
                ["honey", "garlic", "ginger", "soy", "teriyaki", "sesame", "lemon", "lime",
                 "chili", "curry", "basil", "cilantro", "parmesan", "mozzarella"].contains(where: {
                    ingredient.contains($0)
                })
            }
            .prefix(3)
            .joined(separator: " ")

        // Detect cuisine
        let cuisine = detectCuisine(title: recipe.title, ingredients: recipe.ingredients)

        // Build query: key flavor + main dish + cuisine
        // Example: "honey garlic chicken chinese recipe"
        var queryParts: [String] = []
        if !distinctiveIngredients.isEmpty {
            queryParts.append(distinctiveIngredients)
        }
        if !mainDish.isEmpty {
            queryParts.append(mainDish)
        }
        if let cuisineType = cuisine {
            queryParts.append(cuisineType)
        }
        queryParts.append("recipe")

        let query = queryParts.joined(separator: " ")
        return "\(query) site:allrecipes.com OR site:foodnetwork.com OR site:seriouseats.com OR site:bonappetit.com"
    }

    /// Detect cuisine type from title and ingredients
    private func detectCuisine(title: String, ingredients: [ExtractedIngredient]) -> String? {
        let titleLower = title.lowercased()
        let ingredientNames = ingredients.map { $0.item.lowercased() }.joined(separator: " ")

        // Indian cuisine indicators
        if titleLower.contains("curry") ||
           titleLower.contains("tikka") ||
           titleLower.contains("masala") ||
           titleLower.contains("biryani") ||
           titleLower.contains("tandoori") ||
           ingredientNames.contains("garam masala") ||
           ingredientNames.contains("turmeric") ||
           ingredientNames.contains("curry leaves") ||
           ingredientNames.contains("cardamom") {
            return "indian"
        }

        // Italian cuisine indicators
        if titleLower.contains("pasta") ||
           titleLower.contains("pizza") ||
           titleLower.contains("risotto") ||
           titleLower.contains("carbonara") ||
           titleLower.contains("bolognese") ||
           ingredientNames.contains("parmesan") ||
           ingredientNames.contains("mozzarella") ||
           ingredientNames.contains("basil") {
            return "italian"
        }

        // Mexican cuisine indicators
        if titleLower.contains("taco") ||
           titleLower.contains("burrito") ||
           titleLower.contains("enchilada") ||
           titleLower.contains("quesadilla") ||
           ingredientNames.contains("cilantro") ||
           ingredientNames.contains("jalapeño") ||
           ingredientNames.contains("cumin") ||
           ingredientNames.contains("lime") {
            return "mexican"
        }

        // Chinese/Asian cuisine indicators
        if titleLower.contains("stir fry") ||
           titleLower.contains("fried rice") ||
           titleLower.contains("lo mein") ||
           titleLower.contains("kung pao") ||
           ingredientNames.contains("soy sauce") ||
           ingredientNames.contains("sesame oil") ||
           ingredientNames.contains("ginger") ||
           ingredientNames.contains("rice vinegar") {
            return "chinese"
        }

        // Thai cuisine indicators
        if titleLower.contains("pad thai") ||
           titleLower.contains("curry") && ingredientNames.contains("coconut milk") ||
           ingredientNames.contains("fish sauce") ||
           ingredientNames.contains("lemongrass") ||
           ingredientNames.contains("thai basil") {
            return "thai"
        }

        // Japanese cuisine indicators
        if titleLower.contains("sushi") ||
           titleLower.contains("teriyaki") ||
           titleLower.contains("ramen") ||
           ingredientNames.contains("miso") ||
           ingredientNames.contains("sake") ||
           ingredientNames.contains("nori") {
            return "japanese"
        }

        // Mediterranean cuisine indicators
        if titleLower.contains("greek") ||
           titleLower.contains("mediterranean") ||
           ingredientNames.contains("feta") ||
           ingredientNames.contains("olive oil") && ingredientNames.contains("lemon") ||
           ingredientNames.contains("oregano") {
            return "mediterranean"
        }

        // French cuisine indicators
        if titleLower.contains("french") ||
           titleLower.contains("bourguignon") ||
           titleLower.contains("coq au vin") ||
           ingredientNames.contains("gruyere") ||
           ingredientNames.contains("cognac") {
            return "french"
        }

        return nil
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
        #if DEBUG
        print("📥 Fetching recipe from: \(urlString)")
        #endif

        // Use existing RecipeImportService to parse the recipe
        let importedRecipe = try await recipeImportService.importRecipe(from: urlString)

        #if DEBUG
        print("✅ Successfully parsed recipe: \(importedRecipe.title)")
        #endif

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
        // Remove common/filler words that don't define the recipe
        let fillerWords = Set(["recipe", "easy", "best", "simple", "homemade", "authentic", "classic", "perfect", "the", "a", "an", "with"])

        let queryWords = Set(originalQuery.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !fillerWords.contains($0) && !$0.isEmpty })

        let titleWords = Set(importedTitle.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !fillerWords.contains($0) && !$0.isEmpty })

        guard !queryWords.isEmpty && !titleWords.isEmpty else { return 0.0 }

        // Calculate Jaccard similarity
        let intersection = queryWords.intersection(titleWords)
        let union = queryWords.union(titleWords)

        let jaccardScore = Double(intersection.count) / Double(union.count)

        // Penalize if key distinctive words from query are missing
        // For "Butter Chicken", both "butter" and "chicken" should be in the title
        let missingKeyWords = queryWords.subtracting(titleWords)
        let hasMissingKeyWords = !missingKeyWords.isEmpty && missingKeyWords.count > queryWords.count / 2

        // If more than half the key words are missing, heavily penalize
        if hasMissingKeyWords {
            return jaccardScore * 0.3  // Reduce score by 70%
        }

        return jaccardScore
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
