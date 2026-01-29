//
//  RecipeExporter.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//  Updated for post-trial export feature on 2026-01-13.
//

import Foundation
import SwiftUI
import SwiftData
import UIKit

/// Service for exporting recipes to JSON and PDF formats
@MainActor
final class RecipeExporter {

    // MARK: - JSON Export

    /// Export all accessible recipes to JSON format
    /// - Parameter context: SwiftData model context
    /// - Returns: URL to the temporary JSON file
    func exportAsJSON(context: ModelContext) async throws -> URL {
        Log.info("Starting JSON export", category: .storage)

        // Fetch all recipes
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        let recipes = try context.fetch(descriptor)

        guard !recipes.isEmpty else {
            throw RecipeExportError.noRecipesToExport
        }

        Log.info("Fetched recipes for export", category: .storage, metadata: ["count": recipes.count])

        // Convert to exportable format
        let exportData = recipes.map { recipe in
            RecipeExportData(
                id: recipe.id.uuidString,
                title: recipe.title,
                ingredients: recipe.ingredients?.map { $0.originalText } ?? [],
                instructions: recipe.instructions,
                servings: recipe.servings,
                prepTime: recipe.prepTime,
                cookTime: recipe.cookTime,
                notes: recipe.notes,
                sourceType: recipe.sourceType?.rawValue,
                sourceURL: recipe.sourceURL,
                sourcePerson: recipe.sourcePerson,
                sourceBookTitle: recipe.sourceBookTitle,
                sourceDate: recipe.sourceDate,
                dateAdded: recipe.dateAdded.iso8601,
                lastModified: recipe.lastModified.iso8601,
                isFavorite: recipe.isFavorite,
                timesCooked: recipe.timesCooked,
                lastCooked: recipe.lastCooked?.iso8601,
                isThemeRecipe: recipe.isThemeRecipe,
                sourceThemeId: recipe.sourceThemeId,
                historicalText: recipe.historicalText,
                historicalContext: recipe.historicalContext
            )
        }

        // Create export wrapper
        let wrapper = RecipeExportWrapper(
            exportDate: Date().iso8601,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            recipeCount: recipes.count,
            recipes: exportData
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(wrapper)

        // Save to temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "heirloom-recipes-\(Date().iso8601FilenameSafe).json"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try jsonData.write(to: fileURL)

        Log.info("JSON export completed", category: .storage, metadata: [
            "fileName": fileName,
            "recipeCount": recipes.count,
            "fileSize": jsonData.count
        ])

        return fileURL
    }

    // MARK: - PDF Export

    /// Export all accessible recipes to PDF format
    /// - Parameter context: SwiftData model context
    /// - Returns: URL to the temporary PDF file
    func exportAsPDF(context: ModelContext) async throws -> URL {
        Log.info("Starting PDF export", category: .storage)

        // Fetch all recipes
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        let recipes = try context.fetch(descriptor)

        guard !recipes.isEmpty else {
            throw RecipeExportError.noRecipesToExport
        }

        Log.info("Fetched recipes for PDF export", category: .storage, metadata: ["count": recipes.count])

        // Create PDF document
        let pdfMetadata = [
            kCGPDFContextTitle: "Heirloom Recipes",
            kCGPDFContextAuthor: "Heirloom App",
            kCGPDFContextCreator: "Heirloom Recipe Manager"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]

        // US Letter size: 8.5" x 11" = 612 x 792 points
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "heirloom-recipes-\(Date().iso8601FilenameSafe).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        try renderer.writePDF(to: fileURL) { context in
            for (index, recipe) in recipes.enumerated() {
                // Start new page for each recipe
                context.beginPage()

                // Render recipe content
                renderRecipeToPDF(recipe: recipe, in: pageRect, context: context.cgContext)

                Log.debug("Rendered recipe to PDF", category: .storage, metadata: [
                    "index": index + 1,
                    "title": recipe.title
                ])
            }
        }

        Log.info("PDF export completed", category: .storage, metadata: [
            "fileName": fileName,
            "recipeCount": recipes.count
        ])

        return fileURL
    }

    // MARK: - PDF Rendering

    private func renderRecipeToPDF(recipe: Recipe, in pageRect: CGRect, context: CGContext) {
        let margin: CGFloat = 50
        var yPosition: CGFloat = margin
        let contentWidth = pageRect.width - (margin * 2)

        // Title
        let titleFont = UIFont.boldSystemFont(ofSize: 24)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        let titleString = recipe.title as NSString
        let titleRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 40)
        titleString.draw(in: titleRect, withAttributes: titleAttributes)
        yPosition += 50

        // Source
        if let sourceType = recipe.sourceType {
            let sourceFont = UIFont.systemFont(ofSize: 12)
            let sourceAttributes: [NSAttributedString.Key: Any] = [
                .font: sourceFont,
                .foregroundColor: UIColor.gray
            ]
            let sourceText = "Source: \(sourceType.displayName)" as NSString
            let sourceRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 20)
            sourceText.draw(in: sourceRect, withAttributes: sourceAttributes)
            yPosition += 30
        }

        // Metadata (servings, prep time, cook time)
        let metadataFont = UIFont.systemFont(ofSize: 12)
        let metadataAttributes: [NSAttributedString.Key: Any] = [
            .font: metadataFont,
            .foregroundColor: UIColor.darkGray
        ]

        var metadataParts: [String] = []
        if let servings = recipe.servings {
            metadataParts.append("Servings: \(servings)")
        }
        if let prepTime = recipe.prepTime {
            metadataParts.append("Prep: \(prepTime)")
        }
        if let cookTime = recipe.cookTime {
            metadataParts.append("Cook: \(cookTime)")
        }

        if !metadataParts.isEmpty {
            let metadataText = metadataParts.joined(separator: " • ") as NSString
            let metadataRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 20)
            metadataText.draw(in: metadataRect, withAttributes: metadataAttributes)
            yPosition += 30
        }

        // Separator line
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: yPosition))
        context.addLine(to: CGPoint(x: pageRect.width - margin, y: yPosition))
        context.strokePath()
        yPosition += 20

        // Ingredients
        let sectionFont = UIFont.boldSystemFont(ofSize: 16)
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: sectionFont,
            .foregroundColor: UIColor.black
        ]
        let ingredientsTitle = "Ingredients" as NSString
        let ingredientsTitleRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 25)
        ingredientsTitle.draw(in: ingredientsTitleRect, withAttributes: sectionAttributes)
        yPosition += 30

        let bodyFont = UIFont.systemFont(ofSize: 12)
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor.black
        ]

        if let ingredients = recipe.ingredients {
            for ingredient in ingredients {
                let ingredientText = "• \(ingredient.originalText)" as NSString
                let ingredientRect = CGRect(x: margin + 10, y: yPosition, width: contentWidth - 10, height: 20)
                ingredientText.draw(in: ingredientRect, withAttributes: bodyAttributes)
                yPosition += 20
            }
        }
        yPosition += 20

        // Instructions
        let instructionsTitle = "Instructions" as NSString
        let instructionsTitleRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 25)
        instructionsTitle.draw(in: instructionsTitleRect, withAttributes: sectionAttributes)
        yPosition += 30

        for (index, instruction) in recipe.instructions.enumerated() {
            let instructionText = "\(index + 1). \(instruction)" as NSString
            let instructionHeight = instructionText.boundingRect(
                with: CGSize(width: contentWidth - 10, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: bodyAttributes,
                context: nil
            ).height

            let instructionRect = CGRect(x: margin + 10, y: yPosition, width: contentWidth - 10, height: instructionHeight + 10)
            instructionText.draw(in: instructionRect, withAttributes: bodyAttributes)
            yPosition += instructionHeight + 15
        }

        // Notes (if present)
        if let notes = recipe.notes, !notes.isEmpty {
            yPosition += 10
            let notesTitle = "Notes" as NSString
            let notesTitleRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 25)
            notesTitle.draw(in: notesTitleRect, withAttributes: sectionAttributes)
            yPosition += 30

            let notesText = notes as NSString
            let notesHeight = notesText.boundingRect(
                with: CGSize(width: contentWidth - 10, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: bodyAttributes,
                context: nil
            ).height

            let notesRect = CGRect(x: margin + 10, y: yPosition, width: contentWidth - 10, height: notesHeight + 10)
            notesText.draw(in: notesRect, withAttributes: bodyAttributes)
        }
    }

    // MARK: - Legacy Support (for existing callers)

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
        let imageFileName: String? // NEW: Image filename for sidecar restoration
    }

    /// Export format
    struct RecipeExport: Codable {
        let metadata: ExportMetadata
        let recipes: [ExportableRecipe]
    }

    /// Export recipes to JSON (legacy method)
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

    /// Generate filename for export (legacy method)
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return "heirloom-recipes-\(dateString).json"
    }

    private func convertToExportable(recipe: Recipe, formatter: ISO8601DateFormatter) -> ExportableRecipe {
        return ExportableRecipe(
            id: recipe.id.uuidString,
            title: recipe.title,
            ingredients: recipe.ingredients?.map { $0.originalText } ?? [],
            instructions: recipe.instructions,
            collectionName: recipe.collections?.first?.name,
            isHeritage: recipe.isThemeRecipe,
            createdDate: formatter.string(from: recipe.dateAdded),
            modifiedDate: formatter.string(from: recipe.lastModified),
            source: recipe.sourceURL,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            servings: recipe.servings,
            notes: recipe.notes,
            imageFileName: recipe.imageFileName // NEW: Include for sidecar restoration
        )
    }
}

// MARK: - Export Data Models

struct RecipeExportWrapper: Codable {
    let exportDate: String
    let version: String
    let recipeCount: Int
    let recipes: [RecipeExportData]
}

struct RecipeExportData: Codable {
    let id: String
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let notes: String?
    let sourceType: String?
    let sourceURL: String?
    let sourcePerson: String?
    let sourceBookTitle: String?
    let sourceDate: String?
    let dateAdded: String
    let lastModified: String
    let isFavorite: Bool
    let timesCooked: Int
    let lastCooked: String?
    let isThemeRecipe: Bool
    let sourceThemeId: String?
    let historicalText: String?
    let historicalContext: String?
}

// MARK: - Date Extensions

extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }

    var iso8601FilenameSafe: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: self)
    }
}

// MARK: - Errors

enum RecipeExportError: LocalizedError {
    case noRecipesToExport
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noRecipesToExport:
            return "No recipes available to export"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}
