//
//  DuplicateDetectionService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import Foundation
import SwiftData
import CryptoKit

/// Service for detecting duplicate recipes using content hashing and fuzzy matching
@MainActor
class DuplicateDetectionService {

    // MARK: - Duplicate Detection Result

    struct DuplicateMatch {
        let recipe: Recipe
        let similarityScore: Double // 0.0 to 1.0
        let matchType: MatchType

        enum MatchType {
            case exactHash      // Identical content hash
            case titleMatch     // Similar title
            case contentMatch   // Similar ingredients/instructions
        }
    }

    // MARK: - Content Hash Generation

    /// Generate content hash for a recipe
    /// Uses SHA256 of normalized title + sorted ingredients
    static func generateContentHash(title: String, ingredients: [String]) -> String {
        // Normalize title: lowercase, remove extra whitespace, remove punctuation
        let normalizedTitle = Self.normalizeText(title)

        // Normalize and sort ingredients
        let normalizedIngredients = ingredients
            .map { Self.normalizeText($0) }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: "|")

        // Combine title and ingredients
        let content = "\(normalizedTitle)|\(normalizedIngredients)"

        // Generate SHA256 hash
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Update recipe's content hash
    static func updateContentHash(for recipe: Recipe) {
        let ingredients = recipe.ingredients?.map { $0.originalText } ?? []
        recipe.contentHash = generateContentHash(title: recipe.title, ingredients: ingredients)
    }

    // MARK: - Duplicate Detection

    /// Find potential duplicates for a recipe in the database
    func findDuplicates(
        for recipe: Recipe,
        in context: ModelContext,
        threshold: Double = 0.7
    ) throws -> [DuplicateMatch] {
        var matches: [DuplicateMatch] = []

        // 1. Exact hash match (highest priority)
        if let contentHash = recipe.contentHash, !contentHash.isEmpty {
            let exactMatches = try findByExactHash(contentHash, excluding: recipe.id, in: context)
            matches.append(contentsOf: exactMatches.map {
                DuplicateMatch(recipe: $0, similarityScore: 1.0, matchType: .exactHash)
            })
        }

        // 2. Title-based fuzzy matching (for recipes without hash or additional matches)
        let titleMatches = try findByFuzzyTitle(recipe.title, excluding: recipe.id, in: context)
        for candidate in titleMatches {
            // Skip if already matched by hash
            if matches.contains(where: { $0.recipe.id == candidate.id }) {
                continue
            }

            let similarity = calculateTitleSimilarity(recipe.title, candidate.title)
            if similarity >= threshold {
                matches.append(DuplicateMatch(
                    recipe: candidate,
                    similarityScore: similarity,
                    matchType: .titleMatch
                ))
            }
        }

        // 3. Content-based matching (ingredient overlap)
        if matches.isEmpty || matches.count < 5 {
            let contentMatches = try findByContentSimilarity(recipe, excluding: recipe.id, in: context)
            for (candidate, similarity) in contentMatches {
                // Skip if already matched
                if matches.contains(where: { $0.recipe.id == candidate.id }) {
                    continue
                }

                if similarity >= threshold {
                    matches.append(DuplicateMatch(
                        recipe: candidate,
                        similarityScore: similarity,
                        matchType: .contentMatch
                    ))
                }
            }
        }

        // Sort by similarity score (highest first)
        return matches.sorted { $0.similarityScore > $1.similarityScore }
    }

    // MARK: - Database Queries

    private func findByExactHash(
        _ hash: String,
        excluding recipeId: UUID,
        in context: ModelContext
    ) throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.contentHash == hash && recipe.id != recipeId
            }
        )
        return try context.fetch(descriptor)
    }

    private func findByFuzzyTitle(
        _ title: String,
        excluding recipeId: UUID,
        in context: ModelContext
    ) throws -> [Recipe] {
        // Get first 3 words of title for efficient database filtering
        let titleWords = Self.normalizeText(title).split(separator: " ").prefix(3)
        guard let firstWord = titleWords.first else { return [] }

        let searchTerm = String(firstWord)
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.id != recipeId &&
                recipe.title.localizedStandardContains(searchTerm)
            }
        )
        return try context.fetch(descriptor)
    }

    private func findByContentSimilarity(
        _ recipe: Recipe,
        excluding recipeId: UUID,
        in context: ModelContext
    ) throws -> [(Recipe, Double)] {
        // Get recipes with similar ingredient counts (±50%)
        let ingredientCount = recipe.ingredients?.count ?? 0
        let minCount = max(1, ingredientCount - ingredientCount / 2)
        let maxCount = ingredientCount + ingredientCount / 2

        var descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.id != recipeId
            }
        )
        descriptor.fetchLimit = 100 // Limit for performance

        let candidates = try context.fetch(descriptor)

        // Calculate ingredient overlap
        let recipeIngredients = Set(
            recipe.ingredients?.map { Self.normalizeText($0.originalText) } ?? []
        )

        return candidates.compactMap { candidate in
            let candidateIngredients = Set(
                candidate.ingredients?.map { Self.normalizeText($0.originalText) } ?? []
            )

            guard candidateIngredients.count >= minCount &&
                  candidateIngredients.count <= maxCount else {
                return nil
            }

            let overlap = recipeIngredients.intersection(candidateIngredients).count
            let union = recipeIngredients.union(candidateIngredients).count

            guard union > 0 else { return nil }

            let similarity = Double(overlap) / Double(union) // Jaccard similarity
            return (candidate, similarity)
        }
    }

    // MARK: - Similarity Calculations

    private func calculateTitleSimilarity(_ title1: String, _ title2: String) -> Double {
        let norm1 = Self.normalizeText(title1)
        let norm2 = Self.normalizeText(title2)

        // Exact match
        if norm1 == norm2 {
            return 1.0
        }

        // Levenshtein distance-based similarity
        let distance = levenshteinDistance(norm1, norm2)
        let maxLength = max(norm1.count, norm2.count)

        guard maxLength > 0 else { return 0.0 }

        return 1.0 - (Double(distance) / Double(maxLength))
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1),
                           count: s1Array.count + 1)

        for i in 0...s1Array.count {
            matrix[i][0] = i
        }

        for j in 0...s2Array.count {
            matrix[0][j] = j
        }

        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[s1Array.count][s2Array.count]
    }

    // MARK: - Text Normalization

    private static func normalizeText(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
    }

    // MARK: - Bulk Operations

    /// Update content hashes for all recipes that don't have one
    func updateMissingHashes(in context: ModelContext) async throws -> Int {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.contentHash == nil || recipe.contentHash == ""
            }
        )

        let recipes = try context.fetch(descriptor)

        for recipe in recipes {
            Self.updateContentHash(for: recipe)
        }

        try context.save()

        Log.info("Updated content hashes for recipes", category: .general, metadata: [
            "count": recipes.count
        ])

        return recipes.count
    }

    /// Find all duplicate groups in the database
    func findAllDuplicates(in context: ModelContext) throws -> [[Recipe]] {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.contentHash != nil && recipe.contentHash != ""
            }
        )

        let recipes = try context.fetch(descriptor)

        // Group by content hash
        var hashGroups: [String: [Recipe]] = [:]
        for recipe in recipes {
            guard let hash = recipe.contentHash else { continue }
            hashGroups[hash, default: []].append(recipe)
        }

        // Return only groups with 2+ recipes (duplicates)
        return hashGroups.values.filter { $0.count > 1 }
    }
}
