//
//  RecipeExporter.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import Foundation
import SwiftUI

/// Service for exporting recipes to JSON format
final class RecipeExporter {

    /// Export metadata included in JSON
    struct ExportMetadata: Codable {
        let exportDate: String
        let appVersion: String
        let recipeCount: Int
    }

    /// Exportable recipe format (simplified for JSON)
    struct ExportableRecipe: Codable {
        let id: String
        let title: String
        let ingredients: [String]
        let instructions: [String]
        let collectionName: String?
        let isHeritage: Bool
        let createdDate: String
        let modifiedDate: String
        let source: String?
        let prepTime: String?
        let cookTime: String?
        let servings: String?
        let notes: String?
    }

    /// Export format
    struct RecipeExport: Codable {
        let metadata: ExportMetadata
        let recipes: [ExportableRecipe]
    }

    // MARK: - Export

    /// Export recipes to JSON
    /// - Parameter recipes: Recipes to export
    /// - Returns: JSON data
    func exportToJSON(recipes: [Recipe]) throws -> Data {
        let formatter = ISO8601DateFormatter()
        let exportableRecipes = recipes.map { recipe -> ExportableRecipe in
            convertToExportable(recipe: recipe, formatter: formatter)
        }

        let metadata = ExportMetadata(
            exportDate: ISO8601DateFormatter().string(from: Date()),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            recipeCount: recipes.count
        )

        let export = RecipeExport(
            metadata: metadata,
            recipes: exportableRecipes
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(export)
    }

    /// Generate filename for export
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return "heirloom-recipes-\(dateString).json"
    }

    // MARK: - Private Helpers

    private func convertToExportable(recipe: Recipe, formatter: ISO8601DateFormatter) -> ExportableRecipe {
        return ExportableRecipe(
            id: recipe.id.uuidString,
            title: recipe.title,
            ingredients: recipe.ingredients?.map { $0.originalText } ?? [],
            instructions: recipe.instructions,
            collectionName: recipe.collections?.first?.name,
            isHeritage: recipe.isHeritageRecipe,
            createdDate: formatter.string(from: recipe.dateAdded),
            modifiedDate: formatter.string(from: recipe.lastModified),
            source: recipe.sourceURL,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            servings: recipe.servings,
            notes: recipe.notes
        )
    }
}
