import UIKit
import PDFKit
import SwiftUI

@MainActor
class RecipeShareService {
    static let shared = RecipeShareService()
    private init() {}

    // MARK: - Share Methods

    func shareRecipe(_ recipe: Recipe, as format: ShareFormat, from view: UIView) {
        Task {
            do {
                let items = try await prepareShareItems(for: recipe, format: format)
                presentShareSheet(items: items, from: view)
            } catch {
                ToastManager.shared.error(
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
}
