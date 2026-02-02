//
//  RecipeImageGenerator.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import Foundation
import UIKit

/// Protocol for recipe image generation service
protocol RecipeImageGeneratorProtocol {
    /// Generate and save an AI image for a recipe
    func generateAndSaveImage(for recipe: Recipe) async throws
}

/// Generates recipe images using OpenAI DALL-E 3
@MainActor
class RecipeImageGenerator: RecipeImageGeneratorProtocol {
    private let aiConfig: AIConfiguration
    private let styleConfig: VisualStyleConfiguration

    init(aiConfig: AIConfiguration, styleConfig: VisualStyleConfiguration) {
        self.aiConfig = aiConfig
        self.styleConfig = styleConfig
    }

    /// Generate and save image for recipe
    func generateAndSaveImage(for recipe: Recipe) async throws {
        // Check for API key (with fallback to default key)
        guard let apiKey = await aiConfig.apiKeyWithFallback(for: .openai) else {
            throw ImageGenerationError.noAPIKey
        }

        // Build prompt from recipe
        let prompt = buildPrompt(for: recipe)
        Log.info("Generating recipe image", category: .ai, metadata: ["prompt": prompt, "title": recipe.title])

        // Call DALL-E API
        let imageURL = try await generateWithDALLE(prompt: prompt, apiKey: apiKey)

        // Download image
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        guard let uiImage = UIImage(data: data) else {
            throw ImageGenerationError.invalidImageData
        }

        // Save using recipe's saveImage method (uses ImageStorageService)
        try await recipe.saveImage(uiImage)

        Log.info("Saved AI-generated recipe image", category: .ai, metadata: [
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

    private func generateWithDALLE(prompt: String, apiKey: String) async throws -> URL {
        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // DALL-E can take a while

        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1792x1024", // Landscape for recipe cards
            "quality": "standard"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                Log.error("DALL-E API error", category: .ai, metadata: ["error": message])
                throw ImageGenerationError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
            throw ImageGenerationError.apiError(statusCode: httpResponse.statusCode, message: nil)
        }

        let dalleResponse = try JSONDecoder().decode(DALLEResponse.self, from: data)

        guard let urlString = dalleResponse.data.first?.url,
              let imageURL = URL(string: urlString) else {
            throw ImageGenerationError.noImageReturned
        }

        return imageURL
    }
}

// Note: DALLEResponse, DALLEImage, and ImageGenerationError are defined in CollectionImageGenerator.swift
