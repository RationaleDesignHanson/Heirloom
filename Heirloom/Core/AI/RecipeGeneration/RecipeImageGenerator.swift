//
//  RecipeImageGenerator.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import Foundation
import UIKit

/// Protocol for recipe image generation service
@MainActor
protocol RecipeImageGeneratorProtocol {
    /// Generate and save an AI image for a recipe
    func generateAndSaveImage(for recipe: Recipe) async throws
}

/// Generates recipe images using AI image generation (Replicate Flux or DALL-E) via Firebase Cloud Functions
/// Default: Replicate Flux for speed and cost efficiency
@MainActor
class RecipeImageGenerator: RecipeImageGeneratorProtocol {
    private let styleConfig: VisualStyleConfiguration
    private let firebaseService: FirebaseImageGenerationService
    private let session: URLSession

    init(styleConfig: VisualStyleConfiguration, firebaseService: FirebaseImageGenerationService) {
        self.styleConfig = styleConfig
        self.firebaseService = firebaseService

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    /// Generate and save image for recipe
    func generateAndSaveImage(for recipe: Recipe) async throws {
        // Build prompt from recipe
        let prompt = buildPrompt(for: recipe)
        Log.info("Generating recipe image", category: .general, metadata: ["prompt": prompt, "title": recipe.title])

        // Call image generation API via Firebase Function (Replicate Flux by default)
        let imageURL = try await firebaseService.generateImage(prompt: prompt)

        // Download image
        let (data, _) = try await session.data(from: imageURL)
        guard let uiImage = UIImage(data: data) else {
            throw ImageGenerationError.invalidImageData
        }

        // Save using recipe's saveImage method (uses ImageStorageService)
        try await recipe.saveImage(uiImage)

        Log.info("Saved AI-generated recipe image", category: .general, metadata: [
            "title": recipe.title,
            "fileName": recipe.imageFileName ?? "none"
        ])
    }

    // MARK: - Private Methods

    /// Build an optimized prompt for Flux/DALL-E image generation
    /// Structure: [dish description], [key ingredients], [style modifiers], [quality keywords]
    private func buildPrompt(for recipe: Recipe) -> String {
        let selectedStyle = styleConfig.selectedStyle

        // Build dish description - be specific about the food
        let dishDescription = recipe.title

        // Add key visual ingredients (limit to 3 most photogenic)
        var ingredientHints: [String] = []
        if let ingredients = recipe.ingredients?.prefix(5) {
            // Filter for visually interesting ingredients
            let visualIngredients = ingredients
                .map { $0.name.lowercased() }
                .filter { ingredient in
                    // Prioritize colorful/textural ingredients
                    let visualKeywords = ["tomato", "pepper", "herb", "cheese", "cream", "sauce",
                                         "berry", "lemon", "lime", "garlic", "onion", "mushroom",
                                         "bacon", "chicken", "beef", "salmon", "shrimp", "pasta",
                                         "rice", "bread", "chocolate", "butter", "egg", "avocado"]
                    return visualKeywords.contains { ingredient.contains($0) }
                }
                .prefix(3)
            ingredientHints = Array(visualIngredients)
        }

        // Build the prompt with clear structure for Flux
        var promptParts: [String] = []

        // Subject: the dish
        promptParts.append("beautiful \(dishDescription)")

        // Add ingredient visual hints if available
        if !ingredientHints.isEmpty {
            promptParts.append("with \(ingredientHints.joined(separator: ", "))")
        }

        // Add cuisine style from tags if available
        if let tags = recipe.tags, !tags.isEmpty {
            let cuisineTag = tags.first { tag in
                let cuisineKeywords = ["italian", "mexican", "asian", "indian", "french",
                                       "mediterranean", "american", "thai", "japanese", "chinese"]
                return cuisineKeywords.contains { tag.name.lowercased().contains($0) }
            }
            if let cuisine = cuisineTag {
                promptParts.append("\(cuisine.name) cuisine")
            }
        }

        // Combine with style modifier
        let subject = promptParts.joined(separator: ", ")
        let prompt = "\(subject), \(selectedStyle.promptModifier)"

        return prompt
    }
}

// Note: DALLEResponse, DALLEImage, and ImageGenerationError are defined in CollectionImageGenerator.swift
