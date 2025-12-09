import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    var id: UUID
    var name: String
    var color: String // Hex color code
    var createdDate: Date

    // Relationships
    @Relationship(inverse: \Recipe.tags) var recipes: [Recipe]?

    init(
        name: String,
        color: String = "#FF6B6B"
    ) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.createdDate = Date()
    }

    // MARK: - Computed Properties

    var swiftUIColor: Color {
        Color(hex: color) ?? HeirloomColors.tomato
    }

    var recipeCount: Int {
        recipes?.count ?? 0
    }

    // MARK: - Predefined Tag Colors

    static let predefinedColors = [
        "#FF6B6B", // Tomato
        "#4ECDC4", // Turquoise
        "#FFD93D", // Golden
        "#95E1D3", // Mint
        "#F38181", // Coral
        "#AA96DA", // Lavender
        "#FCBAD3", // Pink
        "#FF8C42", // Orange
        "#6BCF7F", // Green
        "#4A90E2"  // Blue
    ]
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0

        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}
