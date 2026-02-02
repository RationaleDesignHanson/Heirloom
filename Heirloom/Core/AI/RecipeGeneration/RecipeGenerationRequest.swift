//
//  RecipeGenerationRequest.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import Foundation

/// Input model for AI recipe generation
struct RecipeGenerationRequest {
    let dishName: String
    let ingredients: [String]?

    init(dishName: String, ingredients: [String]? = nil) {
        self.dishName = dishName
        self.ingredients = ingredients
    }
}
