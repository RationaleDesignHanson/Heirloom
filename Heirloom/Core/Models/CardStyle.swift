import Foundation
import SwiftData
import SwiftUI

@Model
final class RecipeCardStyle {
    var id: UUID
    var createdDate: Date
    var lastModified: Date

    // Background customization
    var backgroundType: BackgroundType
    var backgroundColorHex: String? // For solid colors
    var backgroundImageName: String? // For patterns/textures

    // Love marks (worn, coffee-stained appearance)
    var coffeeStainEnabled: Bool
    var coffeeStainPosition: CoffeeStainPosition?
    var wornEdgesIntensity: Double // 0.0 to 1.0
    var autoLoveMarks: Bool // Automatically add marks based on times cooked

    // Relationship
    var recipe: Recipe?

    init(
        backgroundType: BackgroundType = .default,
        coffeeStainEnabled: Bool = false,
        wornEdgesIntensity: Double = 0.0,
        autoLoveMarks: Bool = false
    ) {
        self.id = UUID()
        self.createdDate = Date()
        self.lastModified = Date()
        self.backgroundType = backgroundType
        self.coffeeStainEnabled = coffeeStainEnabled
        self.wornEdgesIntensity = wornEdgesIntensity
        self.autoLoveMarks = autoLoveMarks
    }

    enum BackgroundType: String, Codable {
        case `default` = "default"
        case solid = "solid"
        case gradient = "gradient"
        case pattern = "pattern"
        case texture = "texture"
    }

    enum CoffeeStainPosition: String, Codable {
        case topLeft = "topLeft"
        case topRight = "topRight"
        case bottomLeft = "bottomLeft"
        case bottomRight = "bottomRight"
        case center = "center"
    }
}

// MARK: - Predefined Styles

extension RecipeCardStyle {
    static let predefinedBackgroundColors = [
        "#FEFDFB", // Cream (default)
        "#FFF9E6", // Warm White
        "#FFF4E0", // Vanilla
        "#F8F3E8", // Linen
        "#FFE5D9", // Peach
        "#E8F2F7", // Light Blue
        "#F0F7E8", // Mint
        "#FCF0E3"  // Tan
    ]

    static let predefinedPatterns = [
        "pattern-dots",
        "pattern-lines",
        "pattern-grid",
        "pattern-vintage"
    ]

    static let predefinedTextures = [
        "texture-paper",
        "texture-fabric",
        "texture-kraft",
        "texture-parchment"
    ]
}
