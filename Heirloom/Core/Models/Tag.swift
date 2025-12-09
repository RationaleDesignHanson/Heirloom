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

