import Testing
import Foundation
import SwiftData
import SwiftUI

@testable import Heirloom

@Suite("Sticker Tests")
struct StickerTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Recipe.self,
            StickerAsset.self,
            RecipeSticker.self,
            Ingredient.self,
            Tag.self,
            RecipeCollection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - StickerAsset Tests

    @Test("StickerAsset initializes with required fields")
    func testStickerAsset_Init_SetsFields() {
        // Act
        let asset = StickerAsset(
            id: "vintage_spoon_01",
            name: "Vintage Spoon",
            category: .vintage,
            assetName: "spoon_vintage",
            defaultSize: CGSize(width: 0.2, height: 0.2)
        )

        // Assert
        #expect(asset.id == "vintage_spoon_01")
        #expect(asset.name == "Vintage Spoon")
        #expect(asset.category == .vintage)
        #expect(asset.assetName == "spoon_vintage")
        #expect(asset.defaultSize.width == 0.2)
        #expect(asset.defaultSize.height == 0.2)
    }

    @Test("StickerAsset initializes with default values")
    func testStickerAsset_Init_SetsDefaults() {
        // Act
        let asset = StickerAsset(
            id: "test_01",
            name: "Test",
            category: .icons,
            assetName: "test",
            defaultSize: CGSize(width: 0.1, height: 0.1)
        )

        // Assert
        #expect(asset.supportsTinting == false)
        #expect(asset.tags.isEmpty)
        #expect(asset.isPremium == false)
        #expect(asset.sortOrder == 0)
        #expect(asset.isEnabled == true)
        #expect(asset.isFavorited == false)
        #expect(asset.useCount == 0)
    }

    @Test("StickerAsset category property reads and writes")
    func testStickerAsset_Category_ReadWrite() {
        // Arrange
        let asset = StickerAsset(
            id: "test",
            name: "Test",
            category: .vintage,
            assetName: "test",
            defaultSize: CGSize(width: 0.1, height: 0.1)
        )

        // Act
        asset.category = .botanical

        // Assert
        #expect(asset.category == .botanical)
        #expect(asset.categoryRawValue == "botanical")
    }

    @Test("StickerAsset defaultSize property reads and writes")
    func testStickerAsset_DefaultSize_ReadWrite() {
        // Arrange
        let asset = StickerAsset(
            id: "test",
            name: "Test",
            category: .icons,
            assetName: "test",
            defaultSize: CGSize(width: 0.1, height: 0.1)
        )

        // Act
        asset.defaultSize = CGSize(width: 0.3, height: 0.3)

        // Assert
        #expect(asset.defaultSizeWidth == 0.3)
        #expect(asset.defaultSizeHeight == 0.3)
    }

    @Test("StickerAsset stores SVG data")
    func testStickerAsset_SVGData_Stores() {
        // Arrange
        let asset = StickerAsset(
            id: "test",
            name: "Test",
            category: .icons,
            assetName: "test",
            defaultSize: CGSize(width: 0.1, height: 0.1)
        )
        let svgData = Data("<?xml version=\"1.0\"?>".utf8)

        // Act
        asset.svgData = svgData

        // Assert
        #expect(asset.svgData == svgData)
    }

    @Test("StickerAsset stores preview image data")
    func testStickerAsset_PreviewImageData_Stores() {
        // Arrange
        let asset = StickerAsset(
            id: "test",
            name: "Test",
            category: .icons,
            assetName: "test",
            defaultSize: CGSize(width: 0.1, height: 0.1)
        )
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header

        // Act
        asset.previewImageData = imageData

        // Assert
        #expect(asset.previewImageData == imageData)
    }

    @Test("StickerAsset matches search by name")
    func testStickerAsset_Matches_ByName() {
        // Arrange
        let asset = StickerAsset(
            id: "test",
            name: "Vintage Spoon",
            category: .vintage,
            assetName: "spoon",
            defaultSize: CGSize(width: 0.1, height: 0.1)
        )

        // Act & Assert
        #expect(asset.matches(searchQuery: "spoon") == true)
        #expect(asset.matches(searchQuery: "SPOON") == true)
        #expect(asset.matches(searchQuery: "fork") == false)
    }

    @Test("StickerAsset matches search by tags")
    func testStickerAsset_Matches_ByTags() {
        // Arrange
        let asset = StickerAsset(
            id: "test",
            name: "Heart",
            category: .icons,
            assetName: "heart",
            defaultSize: CGSize(width: 0.1, height: 0.1),
            tags: ["love", "favorite", "red"]
        )

        // Act & Assert
        #expect(asset.matches(searchQuery: "love") == true)
        #expect(asset.matches(searchQuery: "FAVORITE") == true)
        #expect(asset.matches(searchQuery: "blue") == false)
    }

    @Test("StickerAsset matches search by category")
    func testStickerAsset_Matches_ByCategory() {
        // Arrange
        let asset = StickerAsset(
            id: "test",
            name: "Leaf",
            category: .botanical,
            assetName: "leaf",
            defaultSize: CGSize(width: 0.1, height: 0.1)
        )

        // Act & Assert
        #expect(asset.matches(searchQuery: "botanical") == true)
        #expect(asset.matches(searchQuery: "BOTANICAL") == true)
    }

    @Test("StickerAsset incrementUseCount increases count")
    func testStickerAsset_IncrementUseCount() {
        // Arrange
        let asset = StickerAsset(
            id: "test",
            name: "Test",
            category: .icons,
            assetName: "test",
            defaultSize: CGSize(width: 0.1, height: 0.1)
        )

        // Act
        asset.incrementUseCount()
        asset.incrementUseCount()

        // Assert
        #expect(asset.useCount == 2)
    }

    @Test("StickerAsset toggleFavorite changes state")
    func testStickerAsset_ToggleFavorite() {
        // Arrange
        let asset = StickerAsset(
            id: "test",
            name: "Test",
            category: .icons,
            assetName: "test",
            defaultSize: CGSize(width: 0.1, height: 0.1)
        )

        // Act & Assert
        #expect(asset.isFavorited == false)
        asset.toggleFavorite()
        #expect(asset.isFavorited == true)
        asset.toggleFavorite()
        #expect(asset.isFavorited == false)
    }

    // MARK: - StickerCategory Tests

    @Test("StickerCategory enum has all cases")
    func testStickerCategory_AllCases() {
        // Assert
        #expect(StickerCategory.vintage.rawValue == "vintage")
        #expect(StickerCategory.decorative.rawValue == "decorative")
        #expect(StickerCategory.seasonal.rawValue == "seasonal")
        #expect(StickerCategory.icons.rawValue == "icons")
        #expect(StickerCategory.botanical.rawValue == "botanical")
        #expect(StickerCategory.utensils.rawValue == "utensils")
        #expect(StickerCategory.typography.rawValue == "typography")
        #expect(StickerCategory.frames.rawValue == "frames")
    }

    @Test("StickerCategory provides display names")
    func testStickerCategory_DisplayNames() {
        // Assert
        #expect(StickerCategory.vintage.displayName == "Vintage")
        #expect(StickerCategory.decorative.displayName == "Decorative")
        #expect(StickerCategory.seasonal.displayName == "Seasonal")
        #expect(StickerCategory.icons.displayName == "Icons")
        #expect(StickerCategory.botanical.displayName == "Botanical")
        #expect(StickerCategory.utensils.displayName == "Utensils")
        #expect(StickerCategory.typography.displayName == "Typography")
        #expect(StickerCategory.frames.displayName == "Frames")
    }

    @Test("StickerCategory provides icon names")
    func testStickerCategory_Icons() {
        // Assert
        #expect(StickerCategory.vintage.icon == "clock")
        #expect(StickerCategory.decorative.icon == "sparkles")
        #expect(StickerCategory.seasonal.icon == "snowflake")
        #expect(StickerCategory.icons.icon == "heart.fill")
        #expect(StickerCategory.botanical.icon == "leaf")
        #expect(StickerCategory.utensils.icon == "fork.knife")
        #expect(StickerCategory.typography.icon == "textformat")
        #expect(StickerCategory.frames.icon == "photo")
    }

    // MARK: - RecipeSticker Tests

    @Test("RecipeSticker initializes with required fields")
    func testRecipeSticker_Init_SetsFields() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill"
        )

        // Assert
        #expect(sticker.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(sticker.stickerType == .food)
        #expect(sticker.stickerName == "carrot.fill")
    }

    @Test("RecipeSticker initializes with default values")
    func testRecipeSticker_Init_SetsDefaults() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .badge,
            stickerName: "star.fill"
        )

        // Assert
        #expect(sticker.positionX == 0.5)
        #expect(sticker.positionY == 0.5)
        #expect(sticker.scale == 1.0)
        #expect(sticker.rotation == 0.0)
        #expect(sticker.colorHex == nil)
        #expect(sticker.opacity == 1.0)
        #expect(sticker.recipe == nil)
    }

    @Test("RecipeSticker initializes with custom position")
    func testRecipeSticker_Init_CustomPosition() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "leaf.fill",
            positionX: 0.8,
            positionY: 0.2
        )

        // Assert
        #expect(sticker.positionX == 0.8)
        #expect(sticker.positionY == 0.2)
    }

    @Test("RecipeSticker initializes with custom transforms")
    func testRecipeSticker_Init_CustomTransforms() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill",
            scale: 1.5,
            rotation: 45.0
        )

        // Assert
        #expect(sticker.scale == 1.5)
        #expect(sticker.rotation == 45.0)
    }

    @Test("RecipeSticker initializes with color and opacity")
    func testRecipeSticker_Init_ColorAndOpacity() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .badge,
            stickerName: "heart.fill",
            colorHex: "#FF0000",
            opacity: 0.8
        )

        // Assert
        #expect(sticker.colorHex == "#FF0000")
        #expect(sticker.opacity == 0.8)
    }

    @Test("RecipeSticker creates timestamp on initialization")
    func testRecipeSticker_CreatedDate() {
        // Arrange
        let before = Date()

        // Act
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill"
        )

        // Assert
        #expect(sticker.createdDate >= before)
    }

    @Test("RecipeSticker position can be updated")
    func testRecipeSticker_Position_CanUpdate() {
        // Arrange
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill"
        )

        // Act
        sticker.positionX = 0.75
        sticker.positionY = 0.25

        // Assert
        #expect(sticker.positionX == 0.75)
        #expect(sticker.positionY == 0.25)
    }

    @Test("RecipeSticker scale can be updated")
    func testRecipeSticker_Scale_CanUpdate() {
        // Arrange
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill"
        )

        // Act
        sticker.scale = 1.8

        // Assert
        #expect(sticker.scale == 1.8)
    }

    @Test("RecipeSticker rotation can be updated")
    func testRecipeSticker_Rotation_CanUpdate() {
        // Arrange
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill"
        )

        // Act
        sticker.rotation = 90.0

        // Assert
        #expect(sticker.rotation == 90.0)
    }

    @Test("RecipeSticker opacity can be updated")
    func testRecipeSticker_Opacity_CanUpdate() {
        // Arrange
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill"
        )

        // Act
        sticker.opacity = 0.5

        // Assert
        #expect(sticker.opacity == 0.5)
    }

    @Test("RecipeSticker can be associated with recipe")
    func testRecipeSticker_Recipe_CanAssociate() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")
        context.insert(recipe)

        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill"
        )
        context.insert(sticker)

        // Act
        sticker.recipe = recipe

        // Assert
        #expect(sticker.recipe?.id == recipe.id)
    }

    // MARK: - StickerType Tests

    @Test("StickerType enum has all cases")
    func testStickerType_AllCases() {
        // Assert
        #expect(RecipeSticker.StickerType.food.rawValue == "food")
        #expect(RecipeSticker.StickerType.badge.rawValue == "badge")
        #expect(RecipeSticker.StickerType.emotional.rawValue == "emotional")
        #expect(RecipeSticker.StickerType.seasonal.rawValue == "seasonal")
    }

    // MARK: - Sticker Library Tests

    @Test("RecipeSticker foodStickers contains expected items")
    func testRecipeSticker_FoodStickers() {
        // Assert
        #expect(RecipeSticker.foodStickers.contains("carrot.fill"))
        #expect(RecipeSticker.foodStickers.contains("leaf.fill"))
        #expect(RecipeSticker.foodStickers.contains("fork.knife"))
        #expect(RecipeSticker.foodStickers.count == 7)
    }

    @Test("RecipeSticker badgeStickers contains expected items")
    func testRecipeSticker_BadgeStickers() {
        // Assert
        #expect(RecipeSticker.badgeStickers.contains("star.fill"))
        #expect(RecipeSticker.badgeStickers.contains("heart.fill"))
        #expect(RecipeSticker.badgeStickers.contains("trophy.fill"))
        #expect(RecipeSticker.badgeStickers.count == 6)
    }

    @Test("RecipeSticker emotionalStickers contains expected items")
    func testRecipeSticker_EmotionalStickers() {
        // Assert
        #expect(RecipeSticker.emotionalStickers.contains("face.smiling"))
        #expect(RecipeSticker.emotionalStickers.contains("sparkles"))
        #expect(RecipeSticker.emotionalStickers.contains("gift.fill"))
        #expect(RecipeSticker.emotionalStickers.count == 6)
    }

    @Test("RecipeSticker seasonalStickers contains expected items")
    func testRecipeSticker_SeasonalStickers() {
        // Assert
        #expect(RecipeSticker.seasonalStickers.contains("snowflake"))
        #expect(RecipeSticker.seasonalStickers.contains("sun.max.fill"))
        #expect(RecipeSticker.seasonalStickers.contains("moon.stars.fill"))
        #expect(RecipeSticker.seasonalStickers.count == 5)
    }

    @Test("RecipeSticker stickers(for:) returns correct stickers for food")
    func testRecipeSticker_StickersFor_Food() {
        // Act
        let stickers = RecipeSticker.stickers(for: .food)

        // Assert
        #expect(stickers == RecipeSticker.foodStickers)
    }

    @Test("RecipeSticker stickers(for:) returns correct stickers for badge")
    func testRecipeSticker_StickersFor_Badge() {
        // Act
        let stickers = RecipeSticker.stickers(for: .badge)

        // Assert
        #expect(stickers == RecipeSticker.badgeStickers)
    }

    @Test("RecipeSticker stickers(for:) returns correct stickers for emotional")
    func testRecipeSticker_StickersFor_Emotional() {
        // Act
        let stickers = RecipeSticker.stickers(for: .emotional)

        // Assert
        #expect(stickers == RecipeSticker.emotionalStickers)
    }

    @Test("RecipeSticker stickers(for:) returns correct stickers for seasonal")
    func testRecipeSticker_StickersFor_Seasonal() {
        // Act
        let stickers = RecipeSticker.stickers(for: .seasonal)

        // Assert
        #expect(stickers == RecipeSticker.seasonalStickers)
    }

    @Test("RecipeSticker allCategories contains all types")
    func testRecipeSticker_AllCategories() {
        // Assert
        #expect(RecipeSticker.allCategories.count == 4)
        #expect(RecipeSticker.allCategories.contains(.food))
        #expect(RecipeSticker.allCategories.contains(.badge))
        #expect(RecipeSticker.allCategories.contains(.emotional))
        #expect(RecipeSticker.allCategories.contains(.seasonal))
    }

    // MARK: - Edge Case Tests

    @Test("RecipeSticker handles minimum scale")
    func testRecipeSticker_MinimumScale() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill",
            scale: 0.5
        )

        // Assert
        #expect(sticker.scale == 0.5)
    }

    @Test("RecipeSticker handles maximum scale")
    func testRecipeSticker_MaximumScale() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill",
            scale: 2.0
        )

        // Assert
        #expect(sticker.scale == 2.0)
    }

    @Test("RecipeSticker handles full rotation")
    func testRecipeSticker_FullRotation() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill",
            rotation: 360.0
        )

        // Assert
        #expect(sticker.rotation == 360.0)
    }

    @Test("RecipeSticker handles zero opacity")
    func testRecipeSticker_ZeroOpacity() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill",
            opacity: 0.0
        )

        // Assert
        #expect(sticker.opacity == 0.0)
    }

    @Test("RecipeSticker handles position at origin")
    func testRecipeSticker_PositionAtOrigin() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill",
            positionX: 0.0,
            positionY: 0.0
        )

        // Assert
        #expect(sticker.positionX == 0.0)
        #expect(sticker.positionY == 0.0)
    }

    @Test("RecipeSticker handles position at maximum")
    func testRecipeSticker_PositionAtMaximum() {
        // Act
        let sticker = RecipeSticker(
            stickerType: .food,
            stickerName: "carrot.fill",
            positionX: 1.0,
            positionY: 1.0
        )

        // Assert
        #expect(sticker.positionX == 1.0)
        #expect(sticker.positionY == 1.0)
    }
}
