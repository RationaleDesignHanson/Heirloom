//
//  SimilarRecipeModels.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/9/26.
//
//  Data models for similar recipe enhancement feature
//  Supports local recipe similarity search, web recipe search, and AI-powered quantity augmentation

import Foundation
import SwiftData

// MARK: - Similar Recipe Match (Local Search Result)

/// Result from local SwiftData similarity search
struct SimilarRecipeMatch: Identifiable {
    let id = UUID()
    let recipe: Recipe
    let similarityScore: Double // 0.0 - 1.0
    let matchReasons: [MatchReason]

    // For Codable conformance
    var recipeId: UUID { recipe.id }
    var recipeTitle: String { recipe.title }

    enum MatchReason: String, CaseIterable {
        case titleSimilarity = "Similar recipe name"
        case ingredientOverlap = "Shared ingredients"
        case tagMatch = "Matching tags"
        case timingSimilarity = "Similar cooking time"

        var icon: String {
            switch self {
            case .titleSimilarity: return "textformat"
            case .ingredientOverlap: return "carrot"
            case .tagMatch: return "tag"
            case .timingSimilarity: return "clock"
            }
        }
    }

    /// Format similarity score as percentage
    var similarityPercentage: Int {
        Int(similarityScore * 100)
    }

    /// Display string for UI
    var displayString: String {
        "\(recipe.title) (\(similarityPercentage)%)"
    }
}

// MARK: - Web Recipe Result

/// Result from web recipe search
struct WebRecipeResult: Identifiable, Codable {
    let id = UUID()
    let title: String
    let sourceURL: String
    let ingredients: [ImportedIngredient]
    let instructions: [String]?
    let servings: String?
    let similarityScore: Double

    struct ImportedIngredient: Codable {
        let text: String
        let parsedQuantity: String?
        let parsedUnit: String?
        let parsedName: String?
    }

    /// Convert to SimilarRecipeMatch for unified processing
    func toMatch() -> SimilarRecipeMatch {
        // Create a lightweight Recipe object for display purposes
        let recipe = Recipe(
            title: title,
            sourceType: RecipeSourceType.url,  // Web recipes are URL-sourced
            sourceURL: sourceURL,
            instructions: instructions ?? [],
            servings: servings
        )

        return SimilarRecipeMatch(
            recipe: recipe,
            similarityScore: similarityScore,
            matchReasons: [SimilarRecipeMatch.MatchReason.ingredientOverlap, SimilarRecipeMatch.MatchReason.titleSimilarity]
        )
    }

    /// Extract domain from URL for display
    var displayDomain: String {
        guard let url = URL(string: sourceURL),
              let host = url.host() else {
            return sourceURL
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    /// Format similarity score as percentage
    var similarityPercentage: Int {
        Int(similarityScore * 100)
    }
}

// MARK: - Augmented Recipe

/// Recipe with AI-inferred quantities from similar recipes
struct AugmentedRecipe: Codable {
    let original: StructuredRecipe
    let augmentedIngredients: [AugmentedIngredient]
    let metadata: AugmentationMetadata

    /// Whether any augmentation occurred
    var hasAugmentations: Bool {
        !augmentedIngredients.isEmpty
    }

    /// Count of high-confidence augmentations
    var highConfidenceCount: Int {
        augmentedIngredients.filter { $0.inferredConfidence == .high }.count
    }

    /// Count of medium-confidence augmentations
    var mediumConfidenceCount: Int {
        augmentedIngredients.filter { $0.inferredConfidence == .medium }.count
    }

    /// Count of low-confidence augmentations
    var lowConfidenceCount: Int {
        augmentedIngredients.filter { $0.inferredConfidence == .low }.count
    }

    /// Summary string for UI
    var confidenceSummary: String {
        let high = highConfidenceCount
        let medium = mediumConfidenceCount

        if high > 0 && medium > 0 {
            return "\(high) high confidence, \(medium) medium confidence"
        } else if high > 0 {
            return "\(high) high confidence"
        } else if medium > 0 {
            return "\(medium) medium confidence"
        } else {
            return "No high-confidence inferences"
        }
    }
}

// MARK: - Augmented Ingredient

/// Ingredient with AI-inferred quantity
struct AugmentedIngredient: Identifiable, Codable {
    let id = UUID()
    let originalIngredient: ExtractedIngredient
    let inferredQuantity: String?
    let inferredUnit: String?
    let inferredConfidence: InferenceConfidence
    let reasoning: String
    let sourceRecipes: [String] // Titles of supporting recipes

    /// Combined display quantity (prefers inferred if confidence is good)
    var displayQuantity: String? {
        switch inferredConfidence {
        case .high, .medium:
            return inferredQuantity ?? originalIngredient.quantity
        case .low, .unknown:
            return originalIngredient.quantity
        }
    }

    /// Combined display unit (prefers inferred if confidence is good)
    var displayUnit: String? {
        switch inferredConfidence {
        case .high, .medium:
            return inferredUnit ?? originalIngredient.unit
        case .low, .unknown:
            return originalIngredient.unit
        }
    }

    /// Whether this augmentation should be shown to user
    var shouldDisplay: Bool {
        inferredQuantity != nil && inferredConfidence != .unknown
    }
}

// MARK: - Inference Confidence

/// Confidence level for AI-inferred quantities
enum InferenceConfidence: String, Codable, CaseIterable {
    case high = "high"       // 3+ recipes agree (±20% variance)
    case medium = "medium"   // 2 recipes agree or strong contextual
    case low = "low"         // 1 recipe or high variance (>30%)
    case unknown = "unknown" // No good inference possible

    var displayText: String {
        switch self {
        case .high: return "Based on 3+ similar recipes"
        case .medium: return "Based on 2 similar recipes"
        case .low: return "Based on 1 similar recipe"
        case .unknown: return "Unable to infer"
        }
    }

    var shortDisplayText: String {
        switch self {
        case .high: return "High confidence"
        case .medium: return "Medium confidence"
        case .low: return "Low confidence"
        case .unknown: return "Unknown"
        }
    }

    var color: String {
        switch self {
        case .high: return "#4CAF50"      // Green
        case .medium: return "#FF9800"     // Orange
        case .low: return "#FFC107"        // Amber
        case .unknown: return "#9E9E9E"    // Gray
        }
    }

    var systemIconName: String {
        switch self {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "questionmark.circle.fill"
        case .unknown: return "xmark.circle.fill"
        }
    }
}

// MARK: - Augmentation Metadata

/// Metadata about the augmentation process
struct AugmentationMetadata: Codable {
    let localRecipesUsed: Int
    let webRecipesUsed: Int
    let totalInferences: Int
    let averageConfidence: InferenceConfidence
    let processingTime: TimeInterval
    let timestamp: Date

    init(
        localRecipesUsed: Int,
        webRecipesUsed: Int,
        totalInferences: Int,
        averageConfidence: InferenceConfidence,
        processingTime: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.localRecipesUsed = localRecipesUsed
        self.webRecipesUsed = webRecipesUsed
        self.totalInferences = totalInferences
        self.averageConfidence = averageConfidence
        self.processingTime = processingTime
        self.timestamp = timestamp
    }

    /// Total recipes consulted
    var totalRecipesUsed: Int {
        localRecipesUsed + webRecipesUsed
    }

    /// Summary string for UI
    var summaryText: String {
        if totalRecipesUsed == 0 {
            return "No similar recipes found"
        }

        var parts: [String] = []

        if localRecipesUsed > 0 {
            parts.append("\(localRecipesUsed) local")
        }

        if webRecipesUsed > 0 {
            parts.append("\(webRecipesUsed) web")
        }

        let recipeText = totalRecipesUsed == 1 ? "recipe" : "recipes"
        return "Used \(parts.joined(separator: " + ")) \(recipeText)"
    }
}

// MARK: - Enhanced Video Recipe Extraction

extension VideoRecipeExtraction {
    /// Enhanced extraction with augmentation data
    struct Enhanced: Codable {
        let original: VideoRecipeExtraction
        let augmentedRecipe: AugmentedRecipe?
        let similarRecipes: [SimilarRecipeMatch]
        let webRecipes: [WebRecipeResult]

        /// Whether augmentation was performed
        var wasAugmented: Bool {
            augmentedRecipe != nil
        }

        /// Total similar recipes found
        var totalSimilarRecipes: Int {
            similarRecipes.count + webRecipes.count
        }

        // Custom Codable implementation - only encode essential data
        enum CodingKeys: String, CodingKey {
            case original, augmentedRecipe
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(original, forKey: .original)
            try container.encodeIfPresent(augmentedRecipe, forKey: .augmentedRecipe)
            // Skip similarRecipes and webRecipes (not needed for persistence)
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            original = try container.decode(VideoRecipeExtraction.self, forKey: .original)
            augmentedRecipe = try container.decodeIfPresent(AugmentedRecipe.self, forKey: .augmentedRecipe)
            // Default empty arrays for similarRecipes/webRecipes when decoding
            similarRecipes = []
            webRecipes = []
        }

        // Regular initializer
        init(original: VideoRecipeExtraction, augmentedRecipe: AugmentedRecipe?, similarRecipes: [SimilarRecipeMatch], webRecipes: [WebRecipeResult]) {
            self.original = original
            self.augmentedRecipe = augmentedRecipe
            self.similarRecipes = similarRecipes
            self.webRecipes = webRecipes
        }

        /// Final recipe to display (augmented if available, otherwise original)
        var finalRecipe: StructuredRecipe {
            guard let augmented = augmentedRecipe else {
                return original.structuredRecipe
            }

            // Merge original with augmented data
            return mergeRecipes(original: original.structuredRecipe, augmented: augmented)
        }

        /// Merge original recipe with augmented data
        private func mergeRecipes(original: StructuredRecipe, augmented: AugmentedRecipe) -> StructuredRecipe {
            // Create new ingredients array with augmented values
            var mergedIngredients = original.ingredients

            for augmentedIngredient in augmented.augmentedIngredients {
                // Find matching ingredient by original text
                if let index = mergedIngredients.firstIndex(where: {
                    $0.originalText == augmentedIngredient.originalIngredient.originalText
                }) {
                    // Use augmented quantity if confidence is high or medium
                    if augmentedIngredient.inferredConfidence == .high ||
                       augmentedIngredient.inferredConfidence == .medium {

                        let updatedIngredient = ExtractedIngredient(
                            originalText: mergedIngredients[index].originalText,
                            item: mergedIngredients[index].item,
                            quantity: augmentedIngredient.inferredQuantity ?? mergedIngredients[index].quantity,
                            unit: augmentedIngredient.inferredUnit ?? mergedIngredients[index].unit,
                            preparation: mergedIngredients[index].preparation,
                            confidence: augmentedIngredient.inferredConfidence == .high ? .explicit : .inferred
                        )

                        mergedIngredients[index] = updatedIngredient
                    }
                }
            }

            // Return new StructuredRecipe with merged ingredients
            return StructuredRecipe(
                title: original.title,
                description: original.description,
                servings: original.servings,
                prepTime: original.prepTime,
                cookTime: original.cookTime,
                ingredients: mergedIngredients,
                steps: original.steps,
                overallConfidence: max(original.overallConfidence, 0.8), // Boost confidence if augmented
                warnings: original.warnings
            )
        }
    }
}

// MARK: - Confidence Boost

/// Tracks confidence improvements from augmentation
struct ConfidenceBoost {
    let ingredientIndex: Int
    let originalConfidence: ExtractionConfidence
    let boostedConfidence: ExtractionConfidence
    let reason: String

    var improvementText: String {
        "Improved from \(originalConfidence.displayName) to \(boostedConfidence.displayName): \(reason)"
    }
}
