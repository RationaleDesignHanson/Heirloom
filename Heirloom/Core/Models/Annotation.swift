import Foundation
import SwiftData
import SwiftUI

@Model
final class RecipeAnnotation {
    var id: UUID = UUID()
    var text: String = ""
    var style: AnnotationStyle = AnnotationStyle.stickyNote

    // Position
    var positionX: Double = 0.5 // Percentage of card width (0.0 to 1.0)
    var positionY: Double = 0.5 // Percentage of card height (0.0 to 1.0)

    // Visual properties
    var fontSize: Double = 14.0 // 12.0 to 24.0
    var rotation: Double = 0.0 // Degrees (0 to 360)
    var colorHex: String = "#FFD93D"

    var createdDate: Date = Date()
    var lastModified: Date = Date()

    // Relationship
    var recipe: Recipe?

    init(
        text: String,
        style: AnnotationStyle = .stickyNote,
        positionX: Double = 0.5,
        positionY: Double = 0.5,
        fontSize: Double = 14.0,
        rotation: Double = 0.0,
        colorHex: String = "#FFD93D"
    ) {
        self.id = UUID()
        self.text = text
        self.style = style
        self.positionX = positionX
        self.positionY = positionY
        self.fontSize = fontSize
        self.rotation = rotation
        self.colorHex = colorHex
        self.createdDate = Date()
        self.lastModified = Date()
    }

    enum AnnotationStyle: String, Codable {
        case handwritten = "handwritten"
        case stickyNote = "stickyNote"
        case marker = "marker"

        var displayName: String {
            switch self {
            case .handwritten:
                return "Handwritten"
            case .stickyNote:
                return "Sticky Note"
            case .marker:
                return "Marker"
            }
        }

        var font: Font {
            switch self {
            case .handwritten:
                return .custom("Bradley Hand", size: 16)
            case .stickyNote:
                return .system(size: 14, weight: .regular, design: .rounded)
            case .marker:
                return .system(size: 16, weight: .bold, design: .default)
            }
        }
    }
}

// MARK: - Security Helper Methods (Phase 7)

extension RecipeAnnotation {
    /// Safely set text with HTML sanitization (SEC-8)
    func setText(_ newText: String) {
        self.text = HTMLSanitizer.shared.stripAllHTML(newText)
        self.lastModified = Date()
    }
}

// MARK: - Predefined Colors

extension RecipeAnnotation {
    static let predefinedColors = [
        "#FFD93D", // Yellow (sticky note)
        "#FF6B6B", // Red
        "#4ECDC4", // Turquoise
        "#95E1D3", // Mint
        "#F38181", // Coral
        "#AA96DA", // Lavender
        "#FCBAD3"  // Pink
    ]
}
