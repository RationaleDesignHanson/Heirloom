import UIKit
import PDFKit
import SwiftUI

@MainActor
class RecipeExportService {
    // MARK: - Dependencies

    private let toastManager: ToastManager

    // MARK: - Initialization

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

    // MARK: - Share Methods

    func shareRecipe(_ recipe: Recipe, as format: ShareFormat, from view: UIView) {
        Task {
            do {
                let items = try await prepareShareItems(for: recipe, format: format)
                presentShareSheet(items: items, from: view)
            } catch {
                toastManager.error(
                    title: "Failed to share",
                    message: error.localizedDescription
                )
            }
        }
    }

    // MARK: - Share Formats

    enum ShareFormat {
        case text
        case pdf
        case json
        case url // For future CloudKit sharing
    }

    // MARK: - Share Item Preparation

    private func prepareShareItems(for recipe: Recipe, format: ShareFormat) async throws -> [Any] {
        switch format {
        case .text:
            return [formatRecipeAsText(recipe)]

        case .pdf:
            let pdfData = try await generatePDF(for: recipe)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(recipe.title).pdf")
            try pdfData.write(to: tempURL)
            return [tempURL]

        case .json:
            let jsonData = try formatRecipeAsJSON(recipe)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(recipe.title).json")
            try jsonData.write(to: tempURL)
            return [tempURL]

        case .url:
            // TODO: Implement CloudKit sharing
            return [formatRecipeAsText(recipe)]
        }
    }

    // MARK: - Text Formatting

    private func formatRecipeAsText(_ recipe: Recipe) -> String {
        var text = ""

        // Title
        text += "\(recipe.title)\n"
        text += String(repeating: "=", count: recipe.title.count) + "\n\n"

        // Source
        if let sourceURL = recipe.sourceURL {
            text += "Source: \(sourceURL)\n\n"
        } else {
            text += "Source: \(recipe.sourceDisplayName)\n\n"
        }

        // Metadata
        var metadata: [String] = []
        if let servings = recipe.servings {
            metadata.append("Servings: \(servings)")
        }
        if let prepTime = recipe.prepTime {
            metadata.append("Prep: \(prepTime)")
        }
        if let cookTime = recipe.cookTime {
            metadata.append("Cook: \(cookTime)")
        }
        if !metadata.isEmpty {
            text += metadata.joined(separator: " | ") + "\n\n"
        }

        // Ingredients
        if let ingredients = recipe.ingredients, !ingredients.isEmpty {
            text += "INGREDIENTS\n"
            text += "-----------\n"
            for ingredient in ingredients.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                text += "• \(ingredient.displayText)\n"
            }
            text += "\n"
        }

        // Instructions
        if !recipe.instructions.isEmpty {
            text += "INSTRUCTIONS\n"
            text += "------------\n"
            for (index, instruction) in recipe.instructions.enumerated() {
                text += "\(index + 1). \(instruction)\n\n"
            }
        }

        // Notes
        if let notes = recipe.notes {
            text += "NOTES\n"
            text += "-----\n"
            text += notes + "\n\n"
        }

        // Footer
        text += "---\n"
        text += "Shared from Heirloom\n"

        return text
    }

    // MARK: - JSON Formatting

    private func formatRecipeAsJSON(_ recipe: Recipe) throws -> Data {
        // Create exportable dictionary
        var recipeDict: [String: Any] = [
            "id": recipe.id.uuidString,
            "title": recipe.title,
            "dateAdded": ISO8601DateFormatter().string(from: recipe.dateAdded),
            "lastModified": ISO8601DateFormatter().string(from: recipe.lastModified),
            "instructions": recipe.instructions
        ]

        // Add optional fields
        if let sourceType = recipe.sourceType {
            recipeDict["sourceType"] = sourceType.rawValue
        }
        if let sourceURL = recipe.sourceURL {
            recipeDict["sourceURL"] = sourceURL
        }
        if let sourceBookTitle = recipe.sourceBookTitle {
            recipeDict["sourceBookTitle"] = sourceBookTitle
        }
        if let sourceBookAuthor = recipe.sourceBookAuthor {
            recipeDict["sourceBookAuthor"] = sourceBookAuthor
        }
        if let sourceBookPage = recipe.sourceBookPage {
            recipeDict["sourceBookPage"] = sourceBookPage
        }
        if let sourcePerson = recipe.sourcePerson {
            recipeDict["sourcePerson"] = sourcePerson
        }
        if let sourceDate = recipe.sourceDate {
            recipeDict["sourceDate"] = sourceDate
        }
        if let sourceStory = recipe.sourceStory {
            recipeDict["sourceStory"] = sourceStory
        }
        if let servings = recipe.servings {
            recipeDict["servings"] = servings
        }
        if let prepTime = recipe.prepTime {
            recipeDict["prepTime"] = prepTime
        }
        if let cookTime = recipe.cookTime {
            recipeDict["cookTime"] = cookTime
        }
        if let totalTime = recipe.totalTime {
            recipeDict["totalTime"] = totalTime
        }
        if let notes = recipe.notes {
            recipeDict["notes"] = notes
        }
        if let imageFileName = recipe.imageFileName {
            recipeDict["imageFileName"] = imageFileName
        }

        // Add metadata
        recipeDict["timesCooked"] = recipe.timesCooked
        recipeDict["isFavorite"] = recipe.isFavorite
        if let lastCooked = recipe.lastCooked {
            recipeDict["lastCooked"] = ISO8601DateFormatter().string(from: lastCooked)
        }
        if let lastViewed = recipe.lastViewed {
            recipeDict["lastViewed"] = ISO8601DateFormatter().string(from: lastViewed)
        }

        // Add scaling metadata
        recipeDict["scalabilityRating"] = recipe.scalabilityRating
        recipeDict["minimumServings"] = recipe.minimumServings
        if let maximumServings = recipe.maximumServings {
            recipeDict["maximumServings"] = maximumServings
        }
        if let scalingNote = recipe.scalingNote {
            recipeDict["scalingNote"] = scalingNote
        }
        if let category = recipe.category {
            recipeDict["recipeCategory"] = category.rawValue
        }

        // Add ingredients
        if let ingredients = recipe.ingredients {
            let ingredientsArray = ingredients.sorted(by: { $0.orderIndex < $1.orderIndex }).map { ingredient -> [String: Any] in
                var ingredientDict: [String: Any] = [
                    "name": ingredient.name,
                    "originalText": ingredient.originalText,
                    "orderIndex": ingredient.orderIndex
                ]
                if let quantity = ingredient.quantity {
                    ingredientDict["quantity"] = quantity
                }
                if let quantityMax = ingredient.quantityMax {
                    ingredientDict["quantityMax"] = quantityMax
                }
                if let unit = ingredient.unit {
                    ingredientDict["unit"] = unit
                }
                if let preparation = ingredient.preparation {
                    ingredientDict["preparation"] = preparation
                }
                if let category = ingredient.category {
                    ingredientDict["category"] = category.rawValue
                }
                return ingredientDict
            }
            recipeDict["ingredients"] = ingredientsArray
        }

        // Add export metadata
        recipeDict["exportedFrom"] = "Heirloom"
        recipeDict["exportedAt"] = ISO8601DateFormatter().string(from: Date())
        recipeDict["formatVersion"] = "1.0"

        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: recipeDict, options: [.prettyPrinted, .sortedKeys])
        return jsonData
    }

    // MARK: - PDF Generation

    private func generatePDF(for recipe: Recipe) async throws -> Data {
        let pdfMetaData = [
            kCGPDFContextTitle: recipe.title,
            kCGPDFContextCreator: "Heirloom"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            let padding: CGFloat = 40
            var yPosition: CGFloat = padding

            // Title
            yPosition = drawText(
                recipe.title,
                at: CGPoint(x: padding, y: yPosition),
                width: pageRect.width - (padding * 2),
                font: .systemFont(ofSize: 28, weight: .bold),
                color: .black
            )
            yPosition += 10

            // Divider
            context.cgContext.setStrokeColor(UIColor.gray.cgColor)
            context.cgContext.setLineWidth(2)
            context.cgContext.move(to: CGPoint(x: padding, y: yPosition))
            context.cgContext.addLine(to: CGPoint(x: pageRect.width - padding, y: yPosition))
            context.cgContext.strokePath()
            yPosition += 20

            // Source
            let sourceText = recipe.sourceURL ?? recipe.sourceDisplayName
            yPosition = drawText(
                sourceText,
                at: CGPoint(x: padding, y: yPosition),
                width: pageRect.width - (padding * 2),
                font: .systemFont(ofSize: 12, weight: .regular),
                color: .gray
            )
            yPosition += 20

            // Metadata
            var metadata: [String] = []
            if let servings = recipe.servings {
                metadata.append("Servings: \(servings)")
            }
            if let prepTime = recipe.prepTime {
                metadata.append("Prep: \(prepTime)")
            }
            if let cookTime = recipe.cookTime {
                metadata.append("Cook: \(cookTime)")
            }
            if !metadata.isEmpty {
                yPosition = drawText(
                    metadata.joined(separator: " • "),
                    at: CGPoint(x: padding, y: yPosition),
                    width: pageRect.width - (padding * 2),
                    font: .systemFont(ofSize: 14, weight: .medium),
                    color: .darkGray
                )
                yPosition += 25
            }

            // Ingredients
            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                yPosition = drawText(
                    "INGREDIENTS",
                    at: CGPoint(x: padding, y: yPosition),
                    width: pageRect.width - (padding * 2),
                    font: .systemFont(ofSize: 18, weight: .bold),
                    color: .black
                )
                yPosition += 15

                for ingredient in ingredients.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    // Check if we need a new page
                    if yPosition > pageRect.height - 100 {
                        context.beginPage()
                        yPosition = padding
                    }

                    yPosition = drawText(
                        "• \(ingredient.displayText)",
                        at: CGPoint(x: padding, y: yPosition),
                        width: pageRect.width - (padding * 2),
                        font: .systemFont(ofSize: 12, weight: .regular),
                        color: .black
                    )
                    yPosition += 5
                }
                yPosition += 20
            }

            // Instructions
            if !recipe.instructions.isEmpty {
                // Check if we need a new page
                if yPosition > pageRect.height - 200 {
                    context.beginPage()
                    yPosition = padding
                }

                yPosition = drawText(
                    "INSTRUCTIONS",
                    at: CGPoint(x: padding, y: yPosition),
                    width: pageRect.width - (padding * 2),
                    font: .systemFont(ofSize: 18, weight: .bold),
                    color: .black
                )
                yPosition += 15

                for (index, instruction) in recipe.instructions.enumerated() {
                    // Check if we need a new page
                    if yPosition > pageRect.height - 150 {
                        context.beginPage()
                        yPosition = padding
                    }

                    yPosition = drawText(
                        "\(index + 1). \(instruction)",
                        at: CGPoint(x: padding, y: yPosition),
                        width: pageRect.width - (padding * 2),
                        font: .systemFont(ofSize: 12, weight: .regular),
                        color: .black
                    )
                    yPosition += 15
                }
                yPosition += 20
            }

            // Notes
            if let notes = recipe.notes {
                // Check if we need a new page
                if yPosition > pageRect.height - 150 {
                    context.beginPage()
                    yPosition = padding
                }

                yPosition = drawText(
                    "NOTES",
                    at: CGPoint(x: padding, y: yPosition),
                    width: pageRect.width - (padding * 2),
                    font: .systemFont(ofSize: 18, weight: .bold),
                    color: .black
                )
                yPosition += 15

                yPosition = drawText(
                    notes,
                    at: CGPoint(x: padding, y: yPosition),
                    width: pageRect.width - (padding * 2),
                    font: .systemFont(ofSize: 12, weight: .regular),
                    color: .darkGray
                )
            }

            // Footer
            let footerY = pageRect.height - padding - 20
            _ = drawText(
                "Shared from Heirloom",
                at: CGPoint(x: padding, y: footerY),
                width: pageRect.width - (padding * 2),
                font: .systemFont(ofSize: 10, weight: .regular),
                color: .gray
            )
        }

        return data
    }

    private func drawText(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont,
        color: UIColor
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)

        let rect = CGRect(x: point.x, y: point.y, width: width, height: CGFloat.greatestFiniteMagnitude)
        let path = CGPath(rect: rect, transform: nil)

        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)
        let context = UIGraphicsGetCurrentContext()!

        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: rect.origin.y)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0, y: -rect.origin.y)

        CTFrameDraw(frame, context)
        context.restoreGState()

        let lines = CTFrameGetLines(frame) as! [CTLine]
        let lineHeight = font.lineHeight
        let totalHeight = lineHeight * CGFloat(lines.count)

        return point.y + totalHeight
    }

    // MARK: - Share Sheet Presentation

    private func presentShareSheet(items: [Any], from view: UIView) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // Exclude some activity types
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .postToFacebook,
            .postToFlickr,
            .postToTencentWeibo,
            .postToTwitter,
            .postToVimeo,
            .postToWeibo
        ]

        // For iPad
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = view.bounds
        }

        rootViewController.present(activityVC, animated: true)
    }

    // MARK: - JSON Import

    func importRecipeFromJSON(url: URL) throws -> Recipe {
        // Read the file
        let data = try Data(contentsOf: url)

        // Parse JSON
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidFormat
        }

        // Verify format version
        if let version = json["formatVersion"] as? String, version != "1.0" {
            throw ImportError.unsupportedVersion(version)
        }

        // Extract required fields
        guard let title = json["title"] as? String else {
            throw ImportError.missingRequiredField("title")
        }

        guard let instructions = json["instructions"] as? [String] else {
            throw ImportError.missingRequiredField("instructions")
        }

        // Parse source type
        var sourceType: RecipeSourceType = .manual
        if let sourceTypeRaw = json["sourceType"] as? String,
           let parsedType = RecipeSourceType(rawValue: sourceTypeRaw) {
            sourceType = parsedType
        }

        // Create recipe
        let recipe = Recipe(
            title: title,
            sourceType: sourceType,
            sourceURL: json["sourceURL"] as? String,
            instructions: instructions,
            servings: json["servings"] as? String,
            prepTime: json["prepTime"] as? String,
            cookTime: json["cookTime"] as? String
        )

        // Set optional fields
        recipe.sourceBookTitle = json["sourceBookTitle"] as? String
        recipe.sourceBookAuthor = json["sourceBookAuthor"] as? String
        recipe.sourceBookPage = json["sourceBookPage"] as? Int
        recipe.sourcePerson = json["sourcePerson"] as? String
        recipe.sourceDate = json["sourceDate"] as? String
        recipe.sourceStory = json["sourceStory"] as? String
        recipe.totalTime = json["totalTime"] as? String
        recipe.notes = json["notes"] as? String

        // Set metadata (don't import timesCooked, lastCooked, isFavorite - these should be fresh)
        // Parse dates
        let dateFormatter = ISO8601DateFormatter()
        if let dateAddedString = json["dateAdded"] as? String,
           let dateAdded = dateFormatter.date(from: dateAddedString) {
            recipe.dateAdded = dateAdded
        }
        if let lastModifiedString = json["lastModified"] as? String,
           let lastModified = dateFormatter.date(from: lastModifiedString) {
            recipe.lastModified = lastModified
        }

        // Set scaling metadata
        if let scalabilityRating = json["scalabilityRating"] as? String {
            recipe.scalabilityRating = scalabilityRating
        }
        if let recipeCategory = json["recipeCategory"] as? String {
            recipe.recipeCategory = recipeCategory
        }
        if let minimumServings = json["minimumServings"] as? Int {
            recipe.minimumServings = minimumServings
        }
        if let maximumServings = json["maximumServings"] as? Int {
            recipe.maximumServings = maximumServings
        }
        if let scalingNote = json["scalingNote"] as? String {
            recipe.scalingNote = scalingNote
        }

        // Parse ingredients
        if let ingredientsArray = json["ingredients"] as? [[String: Any]] {
            var ingredients: [Ingredient] = []
            for (index, ingredientDict) in ingredientsArray.enumerated() {
                guard let name = ingredientDict["name"] as? String,
                      let originalText = ingredientDict["originalText"] as? String else {
                    continue
                }

                // Parse category
                var category: GroceryCategory = .other
                if let categoryRaw = ingredientDict["category"] as? String,
                   let parsedCategory = GroceryCategory(rawValue: categoryRaw) {
                    category = parsedCategory
                }

                let ingredient = Ingredient(
                    originalText: originalText,
                    name: name,
                    quantity: ingredientDict["quantity"] as? Double,
                    unit: ingredientDict["unit"] as? String,
                    category: category,
                    orderIndex: ingredientDict["orderIndex"] as? Int ?? index
                )
                // Set additional properties not in init
                ingredient.quantityMax = ingredientDict["quantityMax"] as? Double
                ingredient.preparation = ingredientDict["preparation"] as? String
                ingredients.append(ingredient)
            }
            recipe.ingredients = ingredients
        }

        return recipe
    }

    // MARK: - Import Errors

    enum ImportError: LocalizedError {
        case invalidFormat
        case unsupportedVersion(String)
        case missingRequiredField(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid JSON format"
            case .unsupportedVersion(let version):
                return "Unsupported format version: \(version)"
            case .missingRequiredField(let field):
                return "Missing required field: \(field)"
            }
        }
    }
}
