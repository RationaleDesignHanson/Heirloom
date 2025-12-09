import Foundation
import SwiftData
import SwiftUI

@Model
final class Sticker {
    var id: UUID
    var stickerType: StickerType
    var stickerName: String // SF Symbol name or asset name

    // Position and transforms
    var positionX: Double // Percentage of card width (0.0 to 1.0)
    var positionY: Double // Percentage of card height (0.0 to 1.0)
    var scale: Double // 0.5 to 2.0
    var rotation: Double // Degrees (0 to 360)

    // Visual properties
    var colorHex: String?
    var opacity: Double // 0.0 to 1.0

    var createdDate: Date

    // Relationship
    var recipe: Recipe?

    init(
        stickerType: StickerType,
        stickerName: String,
        positionX: Double = 0.5,
        positionY: Double = 0.5,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        colorHex: String? = nil,
        opacity: Double = 1.0
    ) {
        self.id = UUID()
        self.stickerType = stickerType
        self.stickerName = stickerName
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.rotation = rotation
        self.colorHex = colorHex
        self.opacity = opacity
        self.createdDate = Date()
    }

    enum StickerType: String, Codable {
        case food = "food"
        case badge = "badge"
        case emotional = "emotional"
        case seasonal = "seasonal"
    }
}

// MARK: - Sticker Library

extension Sticker {
    static let foodStickers = [
        "carrot.fill",
        "leaf.fill",
        "flame.fill",
        "birthday.cake.fill",
        "cup.and.saucer.fill",
        "fork.knife",
        "fish.fill"
    ]

    static let badgeStickers = [
        "star.fill",
        "heart.fill",
        "checkmark.seal.fill",
        "rosette",
        "medal.fill",
        "trophy.fill"
    ]

    static let emotionalStickers = [
        "face.smiling",
        "heart.circle.fill",
        "hands.clap.fill",
        "gift.fill",
        "sparkles",
        "bolt.fill"
    ]

    static let seasonalStickers = [
        "snowflake",
        "sun.max.fill",
        "leaf",
        "cloud.sun.fill",
        "moon.stars.fill"
    ]

    static func stickers(for type: StickerType) -> [String] {
        switch type {
        case .food:
            return foodStickers
        case .badge:
            return badgeStickers
        case .emotional:
            return emotionalStickers
        case .seasonal:
            return seasonalStickers
        }
    }

    static let allCategories: [StickerType] = [.food, .badge, .emotional, .seasonal]
}
