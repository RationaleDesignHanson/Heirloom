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

/// Generates recipe images using OpenAI DALL-E 3 via Firebase Cloud Functions
@MainActor
class RecipeImageGenerator: RecipeImageGeneratorProtocol {
    private let styleConfig: VisualStyleConfiguration
    private let firebaseService: FirebaseImageGenerationService

    init(styleConfig: VisualStyleConfiguration, firebaseService: FirebaseImageGenerationService) {
        self.styleConfig = styleConfig
        self.firebaseService = firebaseService
    }

    /// Generate and save image for recipe
    func generateAndSaveImage(for recipe: Recipe) async throws {
        // Build prompt from recipe
        let prompt = buildPrompt(for: recipe)
        Log.info("Generating recipe image", category: .general, metadata: ["prompt": prompt, "title": recipe.title])

        // Call DALL-E via Firebase Function
        let imageURL = try await firebaseService.generateImage(prompt: prompt)

        // Download image
        let (data, _) = try await URLSession.shared.data(from: imageURL)
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

    private func buildPrompt(for recipe: Recipe) -> String {
        let selectedStyle = styleConfig.selectedStyle

        // Build subject from recipe details
        var subject = "A delicious \(recipe.title)"

        // Add cuisine if available
        if let tags = recipe.tags, !tags.isEmpty {
            let tagNames = tags.map { $0.name }.joined(separator: ", ")
            subject += " with \(tagNames) style"
        }

        // Add ingredient hints if available (limit to 3 key ingredients)
        if let ingredients = recipe.ingredients?.prefix(3), !ingredients.isEmpty {
            let ingredientNames = ingredients.map { $0.name }.joined(separator: ", ")
            subject += " featuring \(ingredientNames)"
        }

        // Combine subject with user's selected visual style
        let prompt = "\(subject). \(selectedStyle.promptModifier)"

        return prompt
    }
}

// Note: DALLEResponse, DALLEImage, and ImageGenerationError are defined in CollectionImageGenerator.swift
