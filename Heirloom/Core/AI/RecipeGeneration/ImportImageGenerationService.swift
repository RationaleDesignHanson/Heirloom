//
//  ImportImageGenerationService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-24.
//

import Foundation

/// Generates AI images for imported recipes without charging credits.
/// Used by video import and web import flows to replace scraped/extracted images
/// with original AI-generated images, avoiding copyright issues.
@MainActor
class ImportImageGenerationService {
    private let imageGenerator: RecipeImageGenerator
    private let styleConfig: VisualStyleConfiguration

    init(imageGenerator: RecipeImageGenerator, styleConfig: VisualStyleConfiguration) {
        self.imageGenerator = imageGenerator
        self.styleConfig = styleConfig
    }

    /// Generate and save an AI image for an imported recipe.
    /// Does NOT deduct credits - this is an import-included feature.
    /// - Parameter recipe: The recipe to generate an image for
    /// - Throws: ImageGenerationError if generation fails
    func generateImageForImport(recipe: Recipe) async throws {
        Log.info("Generating AI image for imported recipe", category: .ai, metadata: [
            "title": recipe.title,
            "style": styleConfig.selectedStyle.rawValue
        ])

        // Use existing RecipeImageGenerator which already handles:
        // - Building prompts from recipe title + ingredients
        // - Calling Replicate API via Firebase
        // - Downloading and saving image to recipe
        try await imageGenerator.generateAndSaveImage(for: recipe)

        Log.info("AI image generated for imported recipe", category: .ai, metadata: [
            "title": recipe.title,
            "imageFileName": recipe.imageFileName ?? "none"
        ])
    }
}
