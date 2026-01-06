//
//  CategoryDetectionService.swift
//  Heirloom
//
//  Created for Smallify feature
//  Automatically detects recipe category for scaling intelligence
//

import Foundation

// MARK: - Category Detection Service

/// Detects recipe category from title, ingredients, and instructions
class CategoryDetectionService {

    init() {}

    // MARK: - Public API

    /// Detect the category for a recipe
    func detectCategory(for recipe: Recipe) -> RecipeCategory {
        // Try detection in order of specificity
        if let category = detectFromTitle(recipe.title) {
            return category
        }

        if let category = detectFromIngredients(recipe.ingredients ?? []) {
            return category
        }

        if let category = detectFromInstructions(recipe.instructions) {
            return category
        }

        // Default to other
        return .other
    }

    /// Apply detected category and update scaling metadata
    func detectAndApply(to recipe: Recipe) {
        let detectedCategory = detectCategory(for: recipe)

        // Update recipe with detected category and defaults
        recipe.category = detectedCategory
        recipe.scalability = detectedCategory.defaultScalability
        recipe.minimumServings = detectedCategory.minimumServings

        // Set maximum servings based on category
        if detectedCategory.defaultScalability == .locked {
            recipe.maximumServings = recipe.parsedServingCount // Fixed
        } else {
            recipe.maximumServings = recipe.parsedServingCount * 4 // 4x max
        }

        // Add scaling note for locked categories
        if detectedCategory.defaultScalability == .locked {
            recipe.scalingNote = detectedCategory.minimumWarning
        }
    }

    // MARK: - Title Detection

    private func detectFromTitle(_ title: String) -> RecipeCategory? {
        let lowercased = title.lowercased()

        // Locked categories (most specific)
        if containsAny(lowercased, keywords: ["croissant", "puff pastry", "danish", "kouign-amann"]) {
            return .laminated
        }

        if containsAny(lowercased, keywords: ["mayonnaise", "hollandaise", "aioli", "béarnaise"]) {
            return .emulsion
        }

        if containsAny(lowercased, keywords: ["sourdough", "starter"]) {
            return .sourdough
        }

        if containsAny(lowercased, keywords: ["caramel", "toffee", "fudge", "brittle", "candy"]) {
            return .candy
        }

        // Hard scaling
        if containsAny(lowercased, keywords: ["bread", "baguette", "focaccia", "challah", "brioche"]) {
            // But exclude quick breads
            if !containsAny(lowercased, keywords: ["banana bread", "zucchini bread", "pumpkin bread"]) {
                return .yeastBread
            }
        }

        // Moderate scaling
        if containsAny(lowercased, keywords: ["layer cake", "cake"]) {
            // Exclude cupcakes and sheet cakes (those are easier)
            if !containsAny(lowercased, keywords: ["cupcake", "sheet cake"]) {
                return .layerCake
            }
        }

        if containsAny(lowercased, keywords: ["pie", "tart", "quiche"]) {
            return .pie
        }

        // Easy scaling - specific categories
        if containsAny(lowercased, keywords: ["soup", "stew", "chili", "bisque", "chowder"]) {
            return .soupStew
        }

        if containsAny(lowercased, keywords: ["pasta", "spaghetti", "linguine", "fettuccine", "penne", "rigatoni"]) {
            return .pasta
        }

        if containsAny(lowercased, keywords: ["stir fry", "stir-fry", "fried rice"]) {
            return .stirFry
        }

        if containsAny(lowercased, keywords: ["casserole", "bake", "lasagna", "mac and cheese"]) {
            return .casserole
        }

        if containsAny(lowercased, keywords: ["cookie", "biscotti", "shortbread"]) {
            return .cookies
        }

        if containsAny(lowercased, keywords: ["muffin", "cupcake"]) {
            return .muffins
        }

        if containsAny(lowercased, keywords: ["banana bread", "zucchini bread", "pumpkin bread", "cornbread", "biscuit", "scone"]) {
            return .quickBread
        }

        return nil
    }

    // MARK: - Ingredient Detection

    private func detectFromIngredients(_ ingredients: [Ingredient]) -> RecipeCategory? {
        let ingredientNames = ingredients.map { $0.name.lowercased() }.joined(separator: " ")

        // Laminated dough detection
        if ingredientNames.contains("butter") &&
           (ingredientNames.contains("fold") || ingredientNames.contains("layer")) {
            return .laminated
        }

        // Emulsion detection - requires egg yolks + oil
        if ingredientNames.contains("egg yolk") &&
           (ingredientNames.contains("oil") || ingredientNames.contains("butter")) {
            // Check if it's a baking recipe or an emulsion
            if !ingredientNames.contains("flour") {
                return .emulsion
            }
        }

        // Sourdough detection
        if ingredientNames.contains("sourdough") || ingredientNames.contains("starter") {
            return .sourdough
        }

        // Yeast bread
        if ingredientNames.contains("yeast") && ingredientNames.contains("flour") {
            return .yeastBread
        }

        // Cookies - has flour, sugar, butter/oil but no eggs or few eggs
        let hasFlour = ingredientNames.contains("flour")
        let hasSugar = ingredientNames.contains("sugar")
        let hasButter = ingredientNames.contains("butter") || ingredientNames.contains("oil")
        let hasEggs = ingredients.contains { $0.name.lowercased().contains("egg") }

        if hasFlour && hasSugar && hasButter {
            if !hasEggs || ingredients.filter({ $0.name.lowercased().contains("egg") }).count <= 2 {
                return .cookies
            }
        }

        return nil
    }

    // MARK: - Instruction Detection

    private func detectFromInstructions(_ instructions: [String]) -> RecipeCategory? {
        let instructionText = instructions.joined(separator: " ").lowercased()

        // Laminated dough
        if instructionText.contains("fold") && instructionText.contains("turn") &&
           instructionText.contains("butter") {
            return .laminated
        }

        // Yeast bread
        if instructionText.contains("knead") || instructionText.contains("proof") ||
           instructionText.contains("rise") {
            return .yeastBread
        }

        // Emulsion
        if instructionText.contains("emulsif") || instructionText.contains("whisk slowly") {
            return .emulsion
        }

        // Soup/Stew
        if instructionText.contains("simmer") && instructionText.contains("broth") {
            return .soupStew
        }

        // Stir fry
        if instructionText.contains("stir fry") || instructionText.contains("wok") {
            return .stirFry
        }

        return nil
    }

    // MARK: - Helpers

    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}

// MARK: - Recipe Extension

extension Recipe {
    /// Auto-detect and apply category with scaling defaults
    func detectAndApplyCategory() {
        let service = MainActor.assumeIsolated {
            ServiceContainer.shared.resolve(CategoryDetectionService.self)
        }
        service.detectAndApply(to: self)
    }

    /// Get the detected category without applying it
    func detectedCategory() -> RecipeCategory {
        let service = MainActor.assumeIsolated {
            ServiceContainer.shared.resolve(CategoryDetectionService.self)
        }
        return service.detectCategory(for: self)
    }
}
