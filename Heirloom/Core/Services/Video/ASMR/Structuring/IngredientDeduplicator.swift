//
//  IngredientDeduplicator.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-11.
//
//  Service for detecting and merging duplicate ingredients in ASMR video recipe extraction.
//  Uses hybrid approach: text normalization for exact matches + AI semantic similarity for unclear cases.

import Foundation

struct IngredientDeduplicator {
    private let aiService: any AIServiceProtocol

    init(aiService: any AIServiceProtocol) {
        self.aiService = aiService
    }

    // MARK: - Public API

    /// Deduplicate ingredients using hybrid text + AI approach
    func deduplicateIngredients(
        _ ingredients: [ExtractedIngredient]
    ) async throws -> [ExtractedIngredient] {

        guard !ingredients.isEmpty else { return [] }
        guard ingredients.count > 1 else { return ingredients }

        var remaining = ingredients
        var deduplicated: [ExtractedIngredient] = []

        while !remaining.isEmpty {
            let current = remaining.removeFirst()
            var merged = current
            var indicesToRemove: [Int] = []

            // Phase 1: Text normalization (fast exact matching)
            let currentNormalized = normalize(current.item)

            for (index, candidate) in remaining.enumerated() {
                let candidateNormalized = normalize(candidate.item)

                if currentNormalized == candidateNormalized {
                    // Exact match after normalization - merge immediately
                    merged = mergeIngredients(merged, candidate, moreSpecificName: nil)
                    indicesToRemove.append(index)
                    print("✅ Text match: '\(current.item)' ≈ '\(candidate.item)'")
                }
            }

            // Remove exact matches
            for index in indicesToRemove.reversed() {
                remaining.remove(at: index)
            }
            indicesToRemove.removeAll()

            // Phase 2: AI semantic similarity (for remaining unclear cases)
            for (index, candidate) in remaining.enumerated() {
                // Skip if normalized forms are very different (optimization)
                let currentNorm = normalize(merged.item)
                let candidateNorm = normalize(candidate.item)

                // If they share no common words, likely not duplicates
                let currentWords = Set(currentNorm.split(separator: " "))
                let candidateWords = Set(candidateNorm.split(separator: " "))
                let overlap = currentWords.intersection(candidateWords)

                if overlap.isEmpty {
                    continue  // Skip AI check - clearly different
                }

                // Ask AI for semantic comparison
                do {
                    let (similar, confidence, moreSpecific) = try await areIngredientsSimilar(
                        merged.item,
                        candidate.item
                    )

                    // Only merge if high confidence (>0.8)
                    if similar && confidence > 0.8 {
                        merged = mergeIngredients(merged, candidate, moreSpecificName: moreSpecific)
                        indicesToRemove.append(index)
                        print("✅ AI match (\(String(format: "%.2f", confidence))): '\(current.item)' ≈ '\(candidate.item)' → '\(moreSpecific ?? "merged")'")
                    } else if similar && confidence > 0.6 {
                        print("⚠️ Uncertain match (\(String(format: "%.2f", confidence))): '\(current.item)' vs '\(candidate.item)' - keeping both")
                    }
                } catch {
                    // If AI fails, skip and keep both ingredients
                    print("⚠️ AI check failed for '\(merged.item)' vs '\(candidate.item)': \(error)")
                    continue
                }
            }

            // Remove AI-matched ingredients
            for index in indicesToRemove.reversed() {
                remaining.remove(at: index)
            }

            deduplicated.append(merged)
        }

        return deduplicated
    }

    // MARK: - Text Normalization

    /// Normalize ingredient name for exact-match comparison
    private func normalize(_ name: String) -> String {
        var normalized = name.lowercased().trimmingCharacters(in: .whitespaces)

        // Remove common modifier words
        let modifiers = [
            "fresh", "organic", "raw", "cooked", "dried", "frozen",
            "canned", "jarred", "packaged", "whole", "sliced",
            "plain", "unsalted", "salted", "sweetened", "unsweetened"
        ]

        for modifier in modifiers {
            normalized = normalized.replacingOccurrences(
                of: "\\b\(modifier)\\b",
                with: "",
                options: .regularExpression
            )
        }

        // Collapse multiple spaces
        normalized = normalized.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)

        return normalized
    }

    // MARK: - AI Semantic Similarity

    /// Check if two ingredients are semantically the same using AI
    private func areIngredientsSimilar(
        _ ing1: String,
        _ ing2: String
    ) async throws -> (similar: Bool, confidence: Double, moreSpecific: String?) {

        let prompt = """
        Compare these two ingredients and determine if they refer to the same ingredient:

        Ingredient A: "\(ing1)"
        Ingredient B: "\(ing2)"

        Rules:
        - "beef" and "ground beef" are the SAME (one is more specific)
        - "chicken" and "chicken breast" are the SAME
        - "tomato" and "cherry tomato" are DIFFERENT (different varieties)
        - "onion" and "red onion" are DIFFERENT (different varieties)
        - "butter" and "peanut butter" are DIFFERENT (different ingredients)

        Return JSON:
        {
            "areSame": boolean,
            "confidence": number (0.0-1.0),
            "reasoning": "brief explanation",
            "moreSpecific": "Ingredient A" | "Ingredient B" | null
        }

        If areSame is true, moreSpecific should indicate which name is more detailed (return exact text).
        """

        let result = try await aiService.completeStructured(
            prompt: prompt,
            schema: SimilarityResult.self,
            options: AICompletionOptions(temperature: 0.0, maxTokens: 200)
        )

        // Map "Ingredient A/B" to actual ingredient name
        let specificName: String?
        if let specific = result.moreSpecific?.lowercased() {
            if specific.contains("ingredient a") || specific == ing1.lowercased() {
                specificName = ing1
            } else if specific.contains("ingredient b") || specific == ing2.lowercased() {
                specificName = ing2
            } else {
                specificName = nil
            }
        } else {
            specificName = nil
        }

        return (result.areSame, result.confidence, specificName)
    }

    private struct SimilarityResult: Codable {
        let areSame: Bool
        let confidence: Double
        let reasoning: String
        let moreSpecific: String?
    }

    // MARK: - Smart Merge

    /// Merge two duplicate ingredients intelligently
    private func mergeIngredients(
        _ ing1: ExtractedIngredient,
        _ ing2: ExtractedIngredient,
        moreSpecificName: String?
    ) -> ExtractedIngredient {

        // 1. Choose most specific name
        let finalName: String
        if let specific = moreSpecificName {
            finalName = specific
        } else {
            // Fallback: longer name is usually more specific
            finalName = ing1.item.count > ing2.item.count ? ing1.item : ing2.item
        }

        // 2. Choose best quantity (prefer non-nil, non-range, non-vague)
        let finalQuantity: String?
        let quantities = [ing1.quantity, ing2.quantity].compactMap { $0 }
        if quantities.isEmpty {
            finalQuantity = nil
        } else {
            finalQuantity = quantities.max(by: { quantityQuality($0) < quantityQuality($1) })
        }

        // 3. Choose best unit
        let finalUnit = ing1.unit ?? ing2.unit

        // 4. Combine preparation notes
        let preparations = [ing1.preparation, ing2.preparation].compactMap { $0 }
        let uniquePreparations = Array(Set(preparations))  // Remove duplicates
        let finalPreparation = uniquePreparations.isEmpty ? nil : uniquePreparations.joined(separator: ", ")

        // 5. Use highest confidence
        let finalConfidence = confidenceScore(ing1.confidence) > confidenceScore(ing2.confidence)
            ? ing1.confidence
            : ing2.confidence

        // 6. Use the primary ingredient's original text (no debug notation for users)
        let finalOriginalText = ing1.originalText

        return ExtractedIngredient(
            originalText: finalOriginalText,
            item: finalName,
            quantity: finalQuantity,
            unit: finalUnit,
            preparation: finalPreparation,
            confidence: finalConfidence
        )
    }

    // MARK: - Helpers

    /// Score quantity quality (higher is better)
    private func quantityQuality(_ quantity: String) -> Int {
        let q = quantity.lowercased()

        // Vague terms = lowest quality
        if ["some", "handful", "to taste", "pinch", "about"].contains(where: q.contains) {
            return 1
        }

        // Ranges = low quality
        if q.contains("-") || q.contains("to") {
            return 2
        }

        // Specific numeric = best quality
        if Double(q) != nil || q.contains(where: { "0123456789".contains($0) }) {
            return 3
        }

        return 0  // Unknown
    }

    /// Convert confidence enum to numeric score
    private func confidenceScore(_ conf: ExtractionConfidence) -> Double {
        switch conf {
        case .explicit: return 0.95
        case .visual: return 0.90
        case .inferred: return 0.75
        case .approximate: return 0.60
        case .unknown: return 0.40
        }
    }
}

// MARK: - Error Types

enum IngredientError: Error, LocalizedError {
    case aiParseFailed
    case networkError
    case invalidIngredient(String)

    var errorDescription: String? {
        switch self {
        case .aiParseFailed:
            return "Failed to parse AI similarity response"
        case .networkError:
            return "Network error during ingredient comparison"
        case .invalidIngredient(let name):
            return "Invalid ingredient: \(name)"
        }
    }
}
