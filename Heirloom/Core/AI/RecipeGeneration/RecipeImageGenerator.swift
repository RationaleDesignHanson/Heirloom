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
    /// Structure: [finished dish emphasis], [dish description], [presentation], [style modifiers]
    private func buildPrompt(for recipe: Recipe) -> String {
        let selectedStyle = styleConfig.selectedStyle

        // Build dish description - be specific about the food
        let dishDescription = recipe.title

        // Extract key visual ingredients (limit to 3 most visually distinctive)
        var ingredientHints: [String] = []
        if let ingredients = recipe.ingredients, !ingredients.isEmpty {
            // Take first 6 ingredients and extract the key visual parts
            let ingredientNames = ingredients.prefix(6).compactMap { ingredient -> String? in
                let name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                // Skip generic items that don't add visual info
                let skipWords = ["salt", "pepper", "water", "oil", "for serving", "to taste", "pinch",
                                "flour", "sugar", "butter", "egg", "eggs", "cream cheese", "mayonnaise"]
                if skipWords.contains(where: { name.contains($0) }) || name.isEmpty || name.count < 3 {
                    return nil
                }
                return name
            }
            ingredientHints = Array(ingredientNames.prefix(3))
        }

        // Build the prompt with emphasis on THE FINISHED DISH, plated and ready to serve
        var promptParts: [String] = []

        // CRITICAL: Emphasize this is a finished, plated dish - not raw ingredients
        promptParts.append("a beautifully plated finished dish of \(dishDescription)")
        promptParts.append("ready to serve")

        // Add ingredient hints only if they help describe the visual appearance
        if !ingredientHints.isEmpty {
            promptParts.append("made with \(ingredientHints.joined(separator: " and "))")
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
        let prompt = "\(subject), \(selectedStyle.promptModifier), no people no hands no humans no fingers"

        return prompt
    }
}

// Note: DALLEResponse, DALLEImage, and ImageGenerationError are defined in CollectionImageGenerator.swift
