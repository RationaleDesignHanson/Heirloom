//
//  AIRecipeGenerator.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import Foundation
import SwiftData
import UIKit

/// Protocol for AI recipe generation service
@MainActor
protocol AIRecipeGeneratorProtocol {
    /// Generate a complete recipe from minimal input
    func generateRecipe(
        dishName: String,
        ingredients: [String]?,
        context: ModelContext
    ) async throws -> Recipe
}

/// Service that generates complete recipes using AI from minimal input
@MainActor
class AIRecipeGenerator: AIRecipeGeneratorProtocol {
    // MARK: - Dependencies

    private let aiService: AIServiceProtocol
    private let configuration: AIConfigurationProtocol

    // MARK: - Initialization

    init(aiService: AIServiceProtocol, configuration: AIConfigurationProtocol) {
        self.aiService = aiService
        self.configuration = configuration
    }

    // MARK: - Generation

    func generateRecipe(
        dishName: String,
        ingredients: [String]?,
        context: ModelContext
    ) async throws -> Recipe {
        Log.info("Generating recipe from AI", category: .ai, metadata: [
            "dishName": dishName,
            "hasIngredients": ingredients != nil
        ])

        // Build prompt
        let prompt = buildPrompt(dishName: dishName, ingredients: ingredients)

        // Call AI service with structured response
        let options = AICompletionOptions(
            model: configuration.model(for: .parsing),
            maxTokens: 2048,
            temperature: 0.8, // Higher creativity for recipe generation
            systemMessage: systemPrompt
        )

        let response: GeneratedRecipeResponse
        do {
            response = try await aiService.completeStructured(
                prompt: prompt,
                schema: GeneratedRecipeResponse.self,
                options: options
            )
        } catch {
            Log.error("Failed to generate recipe", category: .ai, metadata: [
                "error": error.localizedDescription
            ])
            throw error
        }

        // Create Recipe model from response
        let recipe = createRecipe(from: response, context: context)

        Log.info("Recipe generated successfully", category: .ai, metadata: [
            "title": recipe.title,
            "ingredientCount": recipe.ingredients?.count ?? 0,
            "instructionCount": recipe.instructions.count
        ])

        return recipe
    }

    // MARK: - Private Methods

    private var systemPrompt: String {
        """
        You are a professional recipe developer. Generate complete, well-structured recipes
        that are practical and easy to follow. Always return valid JSON matching the schema.
        """
    }

    private func buildPrompt(dishName: String, ingredients: [String]?) -> String {
        var prompt = "Generate a complete recipe for: \(dishName)\n"

        if let ingredients = ingredients, !ingredients.isEmpty {
            prompt += "Using these key ingredients: \(ingredients.joined(separator: ", "))\n"
        }

        prompt += """

        Return JSON with:
        - title (string)
        - summary (string, 1-2 sentences)
        - prepTime (string, e.g., "15 min" or "1 hr 30 min")
        - cookTime (string, e.g., "30 min")
        - servings (string, e.g., "4 servings" or "Makes 12 cookies")
        - ingredients (array of {originalText, quantity, unit, name, preparation?, category?})
        - instructions (array of strings, one per step)
        - tags (array of strings like ["Italian", "Comfort Food", "Easy"])
        - cuisine (string, e.g., "Italian", "Mexican", "American")

        Guidelines:
        - Be specific and realistic
        - Include proper measurements
        - Keep instructions clear and sequential
        - Suggest appropriate tags for discoverability
        - For category, use one of: Produce, Dairy & Eggs, Meat & Seafood, Bakery, Pantry, Frozen, Spices & Seasonings, Condiments & Sauces, Beverages, Other
        """

        return prompt
    }

    private func createRecipe(from response: GeneratedRecipeResponse, context: ModelContext) -> Recipe {
        // Create base recipe
        let recipe = Recipe(
            title: response.title,
            sourceType: .manual,  // AI-generated uses manual source type
            instructions: response.instructions,
            servings: response.servings,
            prepTime: response.prepTime,
            cookTime: response.cookTime
        )

        // Mark as AI-generated
        recipe.aiGenerated = true

        // Set summary as notes
        recipe.notes = response.summary

        // Create ingredients with relationships
        var ingredientModels: [Ingredient] = []
        for (index, genIng) in response.ingredients.enumerated() {
            let ingredient = Ingredient(
                originalText: genIng.originalText,
                name: genIng.name,
                quantity: genIng.quantity,
                unit: genIng.unit,
                category: parseCategory(genIng.category),
                orderIndex: index
            )
            ingredient.preparation = genIng.preparation
            ingredient.recipe = recipe
            ingredientModels.append(ingredient)
            context.insert(ingredient)
        }
        recipe.ingredients = ingredientModels

        // Create/link tags
        if let tagNames = response.tags, !tagNames.isEmpty {
            recipe.tags = tagNames.compactMap { tagName in
                findOrCreateTag(name: tagName, in: context)
            }
        }

        // Insert recipe into context
        context.insert(recipe)

        return recipe
    }

    private func parseCategory(_ categoryString: String?) -> GroceryCategory {
        guard let categoryString = categoryString else { return .other }

        // Map AI response to GroceryCategory enum
        switch categoryString.lowercased() {
        case "produce":
            return .produce
        case "dairy & eggs", "dairy", "eggs":
            return .dairy
        case "meat & seafood", "meat", "seafood":
            return .meat
        case "bakery":
            return .bakery
        case "pantry":
            return .pantry
        case "frozen":
            return .frozen
        case "spices & seasonings", "spices", "seasonings":
            return .spices
        case "condiments & sauces", "condiments", "sauces":
            return .condiments
        case "beverages":
            return .beverages
        default:
            return .other
        }
    }

    private func findOrCreateTag(name: String, in context: ModelContext) -> Tag {
        // Try to find existing tag (case-insensitive)
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { tag in
                tag.name.localizedStandardContains(name)
            }
        )

        if let existingTags = try? context.fetch(descriptor),
           let tag = existingTags.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return tag
        }

        // Create new tag with random color
        let randomColor = Tag.predefinedColors.randomElement() ?? "#FF6B6B"
        let newTag = Tag(name: name, color: randomColor)
        context.insert(newTag)
        return newTag
    }
}
