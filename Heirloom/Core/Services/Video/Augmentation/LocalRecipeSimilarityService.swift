//
//  LocalRecipeSimilarityService.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/9/26.
//
//  Service for finding similar recipes in local SwiftData database
//  Uses multi-factor similarity scoring: ingredient overlap, title similarity, timing, and tags

import Foundation
import SwiftData

@MainActor
class LocalRecipeSimilarityService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Find similar recipes using multi-factor similarity scoring
    /// - Parameters:
    ///   - extractedRecipe: Recipe extracted from video
    ///   - limit: Maximum number of results to return (default: 10)
    /// - Returns: Array of similar recipes sorted by similarity score
    func findSimilarRecipes(
        to extractedRecipe: StructuredRecipe,
        limit: Int = 10
    ) async throws -> [SimilarRecipeMatch] {
        // 1. Fetch all recipes from SwiftData
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try modelContext.fetch(descriptor)

        // 2. Calculate similarity scores for each recipe
        var matches: [(recipe: Recipe, score: Double, reasons: [SimilarRecipeMatch.MatchReason])] = []

        for recipe in allRecipes {
            let (score, reasons) = calculateSimilarity(
                extractedRecipe: extractedRecipe,
                candidateRecipe: recipe
            )

            // Only include recipes above minimum threshold
            if score >= 0.3 {
                matches.append((recipe, score, reasons))
            }
        }

        // 3. Sort by score (highest first) and limit results
        let topMatches = matches
            .sorted { $0.score > $1.score }
            .prefix(limit)

        // 4. Convert to SimilarRecipeMatch objects
        return topMatches.map { match in
            SimilarRecipeMatch(
                recipe: match.recipe,
                similarityScore: match.score,
                matchReasons: match.reasons
            )
        }
    }

    // MARK: - Similarity Calculation

    /// Calculate overall similarity score using weighted factors
    /// - Returns: Tuple of (score, reasons) where score is 0.0-1.0
    private func calculateSimilarity(
        extractedRecipe: StructuredRecipe,
        candidateRecipe: Recipe
    ) -> (score: Double, reasons: [SimilarRecipeMatch.MatchReason]) {
        var totalScore: Double = 0.0
        var reasons: [SimilarRecipeMatch.MatchReason] = []

        // 1. Title similarity (30% weight)
        let titleScore = calculateTitleSimilarity(
            extracted: extractedRecipe.title,
            candidate: candidateRecipe.title
        )
        if titleScore > 0.3 {
            totalScore += titleScore * 0.3
            reasons.append(.titleSimilarity)
        }

        // 2. Ingredient overlap (50% weight) - Most important
        if let candidateIngredients = candidateRecipe.ingredients {
            let ingredientScore = calculateIngredientOverlap(
                extractedIngredients: extractedRecipe.ingredients,
                candidateIngredients: Array(candidateIngredients)
            )
            if ingredientScore > 0.2 {
                totalScore += ingredientScore * 0.5
                reasons.append(.ingredientOverlap)
            }
        }

        // 3. Tag matching (10% weight)
        if let tags = candidateRecipe.tags, !tags.isEmpty {
            let tagScore = calculateTagSimilarity(
                extractedRecipe: extractedRecipe,
                candidateTags: Array(tags)
            )
            if tagScore > 0.0 {
                totalScore += tagScore * 0.1
                reasons.append(.tagMatch)
            }
        }

        // 4. Timing similarity (10% weight)
        let timingScore = calculateTimingSimilarity(
            extractedRecipe: extractedRecipe,
            candidateRecipe: candidateRecipe
        )
        if timingScore > 0.3 {
            totalScore += timingScore * 0.1
            reasons.append(.timingSimilarity)
        }

        return (totalScore, reasons)
    }

    // MARK: - Title Similarity

    /// Calculate title similarity using token overlap and Levenshtein distance
    private func calculateTitleSimilarity(extracted: String, candidate: String) -> Double {
        // Normalize titles
        let extractedNormalized = normalizeTitle(extracted)
        let candidateNormalized = normalizeTitle(candidate)

        // Calculate token overlap (Jaccard similarity)
        let extractedTokens = Set(extractedNormalized.components(separatedBy: " "))
        let candidateTokens = Set(candidateNormalized.components(separatedBy: " "))

        let intersection = extractedTokens.intersection(candidateTokens)
        let union = extractedTokens.union(candidateTokens)

        guard !union.isEmpty else { return 0.0 }

        let jaccardSimilarity = Double(intersection.count) / Double(union.count)

        // Calculate Levenshtein distance (normalized)
        let maxLength = max(extractedNormalized.count, candidateNormalized.count)
        guard maxLength > 0 else { return 0.0 }

        let distance = levenshteinDistance(extractedNormalized, candidateNormalized)
        let levenshteinSimilarity = 1.0 - (Double(distance) / Double(maxLength))

        // Return weighted average (favor Jaccard for recipe titles)
        return (jaccardSimilarity * 0.7) + (levenshteinSimilarity * 0.3)
    }

    /// Normalize title for comparison
    private func normalizeTitle(_ title: String) -> String {
        let lowercase = title.lowercased()

        // Remove common recipe words
        let stopWords = ["recipe", "grandma's", "classic", "best", "easy", "homemade", "simple", "the", "a", "an"]

        var normalized = lowercase
        for stopWord in stopWords {
            normalized = normalized.replacingOccurrences(of: " \(stopWord) ", with: " ")
            normalized = normalized.replacingOccurrences(of: "^\(stopWord) ", with: "", options: .regularExpression)
            normalized = normalized.replacingOccurrences(of: " \(stopWord)$", with: "", options: .regularExpression)
        }

        // Remove extra whitespace
        normalized = normalized.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return normalized.trimmingCharacters(in: .whitespaces)
    }

    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m {
            matrix[i][0] = i
        }

        for j in 0...n {
            matrix[0][j] = j
        }

        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,     // deletion
                        matrix[i][j - 1] + 1,     // insertion
                        matrix[i - 1][j - 1] + 1  // substitution
                    )
                }
            }
        }

        return matrix[m][n]
    }

    // MARK: - Ingredient Overlap

    /// Calculate ingredient overlap using Jaccard similarity
    private func calculateIngredientOverlap(
        extractedIngredients: [ExtractedIngredient],
        candidateIngredients: [Ingredient]
    ) -> Double {
        // Extract and normalize ingredient names
        let extractedNames = Set(extractedIngredients.map { normalizeIngredientName($0.item) })
        let candidateNames = Set(candidateIngredients.map { normalizeIngredientName($0.name) })

        guard !extractedNames.isEmpty && !candidateNames.isEmpty else { return 0.0 }

        // Calculate Jaccard similarity: |A ∩ B| / |A ∪ B|
        let intersection = extractedNames.intersection(candidateNames)
        let union = extractedNames.union(candidateNames)

        let baseScore = Double(intersection.count) / Double(union.count)

        // Bonus for matching core ingredients (common in baking)
        let coreIngredients = Set(["flour", "sugar", "butter", "eggs", "milk", "salt", "vanilla"])
        let matchedCoreIngredients = intersection.intersection(coreIngredients)

        let coreBonus = Double(matchedCoreIngredients.count) * 0.05

        return min(1.0, baseScore + coreBonus)
    }

    /// Normalize ingredient name for comparison
    private func normalizeIngredientName(_ name: String) -> String {
        let lowercase = name.lowercased()

        // Remove common modifiers
        let modifiers = ["fresh", "dried", "chopped", "diced", "minced", "sliced", "grated",
                         "room temperature", "softened", "melted", "organic", "unsalted"]

        var normalized = lowercase
        for modifier in modifiers {
            normalized = normalized.replacingOccurrences(of: modifier, with: "")
        }

        // Simplify common ingredient variations
        let simplifications = [
            "all-purpose flour": "flour",
            "all purpose flour": "flour",
            "ap flour": "flour",
            "granulated sugar": "sugar",
            "white sugar": "sugar",
            "cane sugar": "sugar",
            "unsalted butter": "butter",
            "salted butter": "butter",
            "large eggs": "eggs",
            "whole milk": "milk",
            "2% milk": "milk",
            "dark chocolate": "chocolate",
            "milk chocolate": "chocolate",
            "semisweet chocolate": "chocolate"
        ]

        for (variant, simplified) in simplifications {
            if normalized.contains(variant) {
                return simplified
            }
        }

        // Remove extra whitespace and trim
        normalized = normalized.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Tag Matching

    /// Calculate tag similarity by inferring tags from extracted recipe
    private func calculateTagSimilarity(
        extractedRecipe: StructuredRecipe,
        candidateTags: [Tag]
    ) -> Double {
        // Infer tags from extracted recipe title and ingredients
        let inferredTagNames = inferTags(from: extractedRecipe)

        guard !inferredTagNames.isEmpty && !candidateTags.isEmpty else { return 0.0 }

        // Extract candidate tag names
        let candidateTagNames = Set(candidateTags.map { $0.name.lowercased() })

        // Calculate overlap
        let matches = inferredTagNames.intersection(candidateTagNames)

        return Double(matches.count) / Double(candidateTagNames.count)
    }

    /// Infer potential tags from recipe title and ingredients
    private func inferTags(from recipe: StructuredRecipe) -> Set<String> {
        var tags = Set<String>()

        let titleLower = recipe.title.lowercased()
        let ingredientNames = recipe.ingredients.map { $0.item.lowercased() }.joined(separator: " ")

        // Common recipe type keywords
        let recipeTypes = [
            "cookie", "cookies", "cake", "bread", "pasta", "soup", "salad",
            "chicken", "beef", "pork", "fish", "vegetable", "dessert",
            "breakfast", "lunch", "dinner", "snack", "appetizer"
        ]

        for type in recipeTypes {
            if titleLower.contains(type) || ingredientNames.contains(type) {
                tags.insert(type)
            }
        }

        // Dietary keywords
        let dietaryTags = [
            "vegetarian", "vegan", "gluten-free", "dairy-free", "keto", "paleo"
        ]

        for dietary in dietaryTags {
            if titleLower.contains(dietary) || ingredientNames.contains(dietary) {
                tags.insert(dietary)
            }
        }

        // Cuisine keywords
        let cuisines = [
            "italian", "chinese", "mexican", "french", "japanese", "indian",
            "thai", "greek", "mediterranean", "american"
        ]

        for cuisine in cuisines {
            if titleLower.contains(cuisine) {
                tags.insert(cuisine)
            }
        }

        return tags
    }

    // MARK: - Timing Similarity

    /// Calculate timing similarity based on cook time and prep time
    private func calculateTimingSimilarity(
        extractedRecipe: StructuredRecipe,
        candidateRecipe: Recipe
    ) -> Double {
        // Parse cook times from both recipes
        guard let extractedMinutes = parseDurationToMinutes(extractedRecipe.cookTime),
              let candidateMinutes = parseDurationToMinutes(candidateRecipe.cookTime) else {
            return 0.0
        }

        // Calculate similarity based on time difference
        let maxTime = max(extractedMinutes, candidateMinutes, 1)
        let timeDiff = abs(extractedMinutes - candidateMinutes)

        // Similarity decreases with time difference
        // Similar times (±20%) get high score
        let similarity = 1.0 - (Double(timeDiff) / Double(maxTime))

        return max(0.0, similarity)
    }

    /// Parse duration string to minutes
    private func parseDurationToMinutes(_ duration: String?) -> Int? {
        guard let duration = duration else { return nil }

        let lowercase = duration.lowercased()

        // Try to extract minutes
        if let range = lowercase.range(of: #"(\d+)\s*(?:min|minute)"#, options: .regularExpression) {
            let match = lowercase[range]
            let digits = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Int(digits)
        }

        // Try to extract hours and convert to minutes
        if let range = lowercase.range(of: #"(\d+)\s*(?:hr|hour)"#, options: .regularExpression) {
            let match = lowercase[range]
            let digits = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let hours = Int(digits) {
                return hours * 60
            }
        }

        return nil
    }
}
