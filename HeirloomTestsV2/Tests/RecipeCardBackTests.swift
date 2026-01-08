import Testing
import Foundation
import SwiftData

@testable import Heirloom

@Suite("Recipe Card Back Tests")
struct RecipeCardBackTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Recipe.self,
            RecipeCardBack.self,
            Ingredient.self,
            Tag.self,
            RecipeCollection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Initialization Tests

    @Test("RecipeCardBack initializes with default values")
    func testInit_WithNoRecipe_SetsDefaults() {
        // Act
        let cardBack = RecipeCardBack()

        // Assert
        #expect(cardBack.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(cardBack.recipe == nil)
        #expect(cardBack.noteToFriends == nil)
        #expect(cardBack.personalTips.isEmpty)
        #expect(cardBack.userRating == nil)
        #expect(cardBack.userTags.isEmpty)
        #expect(cardBack.showAttribution == true)
        #expect(cardBack.customAttributionText == nil)
        #expect(cardBack.attributionPosition == .bottomLeft)
        #expect(cardBack.pinnedCommentIDs.isEmpty)
        #expect(cardBack.maxCommentsToDisplay == 3)
        #expect(cardBack.showSentimentIndicators == true)
        #expect(cardBack.backgroundStyle == .cream)
        #expect(cardBack.textColor == "#2D2D2D")
        #expect(cardBack.showBorder == true)
        #expect(cardBack.borderColor == "#E8D7C3")
        #expect(cardBack.fontSizeMultiplier == 1.0)
        #expect(cardBack.backSideStickers.isEmpty)
        #expect(cardBack.visibleSections.count == 4)
        #expect(cardBack.layoutStyle == .standard)
        #expect(cardBack.shareMessage == nil)
        #expect(cardBack.includeBackWhenSharing == true)
        #expect(cardBack.privacyLevel == .friendsOnly)
        #expect(cardBack.timesShared == 0)
        #expect(cardBack.lastEditedAt == nil)
        #expect(cardBack.isComplete == false)
    }

    @Test("RecipeCardBack initializes with recipe relationship")
    func testInit_WithRecipe_SetsRecipe() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act
        let cardBack = RecipeCardBack(recipe: recipe)

        // Assert
        #expect(cardBack.recipe?.id == recipe.id)
    }

    @Test("RecipeCardBack sets correct default visible sections")
    func testInit_SetsDefaultVisibleSections() {
        // Act
        let cardBack = RecipeCardBack()

        // Assert
        #expect(cardBack.visibleSections.contains(.attribution))
        #expect(cardBack.visibleSections.contains(.noteToFriends))
        #expect(cardBack.visibleSections.contains(.pinnedComments))
        #expect(cardBack.visibleSections.contains(.userTips))
    }

    // MARK: - User Content Tests

    @Test("RecipeCardBack stores note to friends")
    func testNoteToFriends_StoresValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.noteToFriends = "This recipe is a family favorite!"

        // Assert
        #expect(cardBack.noteToFriends == "This recipe is a family favorite!")
    }

    @Test("RecipeCardBack stores personal tips array")
    func testPersonalTips_StoresMultipleTips() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.personalTips = [
            "Let butter come to room temperature",
            "Don't overmix the batter",
            "Bake at 350°F for best results"
        ]

        // Assert
        #expect(cardBack.personalTips.count == 3)
        #expect(cardBack.personalTips[0] == "Let butter come to room temperature")
        #expect(cardBack.personalTips[2] == "Bake at 350°F for best results")
    }

    @Test("RecipeCardBack stores user rating")
    func testUserRating_StoresValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.userRating = 5

        // Assert
        #expect(cardBack.userRating == 5)
    }

    @Test("RecipeCardBack stores user tags")
    func testUserTags_StoresMultipleTags() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.userTags = ["family favorite", "easy", "kid-friendly"]

        // Assert
        #expect(cardBack.userTags.count == 3)
        #expect(cardBack.userTags.contains("family favorite"))
        #expect(cardBack.userTags.contains("easy"))
    }

    // MARK: - Attribution Display Tests

    @Test("RecipeCardBack toggles show attribution")
    func testShowAttribution_TogglesValue() {
        // Arrange
        let cardBack = RecipeCardBack()
        #expect(cardBack.showAttribution == true)

        // Act
        cardBack.showAttribution = false

        // Assert
        #expect(cardBack.showAttribution == false)
    }

    @Test("RecipeCardBack stores custom attribution text")
    func testCustomAttributionText_StoresValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.customAttributionText = "From Grandma's recipe box"

        // Assert
        #expect(cardBack.customAttributionText == "From Grandma's recipe box")
    }

    @Test("RecipeCardBack stores attribution position")
    func testAttributionPosition_StoresValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.attributionPosition = .topRight

        // Assert
        #expect(cardBack.attributionPosition == .topRight)
    }

    // MARK: - Comment Display Tests

    @Test("RecipeCardBack stores pinned comment IDs")
    func testPinnedCommentIDs_StoresMultipleIDs() {
        // Arrange
        let cardBack = RecipeCardBack()
        let id1 = UUID()
        let id2 = UUID()

        // Act
        cardBack.pinnedCommentIDs = [id1, id2]

        // Assert
        #expect(cardBack.pinnedCommentIDs.count == 2)
        #expect(cardBack.pinnedCommentIDs.contains(id1))
        #expect(cardBack.pinnedCommentIDs.contains(id2))
    }

    @Test("RecipeCardBack stores max comments to display")
    func testMaxCommentsToDisplay_StoresValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.maxCommentsToDisplay = 5

        // Assert
        #expect(cardBack.maxCommentsToDisplay == 5)
    }

    @Test("RecipeCardBack toggles show sentiment indicators")
    func testShowSentimentIndicators_TogglesValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.showSentimentIndicators = false

        // Assert
        #expect(cardBack.showSentimentIndicators == false)
    }

    // MARK: - Visual Customization Tests

    @Test("RecipeCardBack stores background style")
    func testBackgroundStyle_StoresValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.backgroundStyle = .vintage

        // Assert
        #expect(cardBack.backgroundStyle == .vintage)
    }

    @Test("RecipeCardBack stores text color as hex")
    func testTextColor_StoresHexValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.textColor = "#FF5733"

        // Assert
        #expect(cardBack.textColor == "#FF5733")
    }

    @Test("RecipeCardBack toggles show border")
    func testShowBorder_TogglesValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.showBorder = false

        // Assert
        #expect(cardBack.showBorder == false)
    }

    @Test("RecipeCardBack stores border color as hex")
    func testBorderColor_StoresHexValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.borderColor = "#000000"

        // Assert
        #expect(cardBack.borderColor == "#000000")
    }

    @Test("RecipeCardBack stores font size multiplier")
    func testFontSizeMultiplier_StoresValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.fontSizeMultiplier = 1.2

        // Assert
        #expect(cardBack.fontSizeMultiplier == 1.2)
    }

    // MARK: - Sticker Position Tests

    @Test("RecipeCardBack stores back side stickers")
    func testBackSideStickers_StoresMultipleStickers() {
        // Arrange
        let cardBack = RecipeCardBack()
        let sticker1 = RecipeStickerPosition(
            stickerID: UUID(),
            x: 0.5,
            y: 0.5,
            rotation: 15.0,
            scale: 1.0
        )
        let sticker2 = RecipeStickerPosition(
            stickerID: UUID(),
            x: 0.8,
            y: 0.2,
            rotation: -10.0,
            scale: 0.8
        )

        // Act
        cardBack.backSideStickers = [sticker1, sticker2]

        // Assert
        #expect(cardBack.backSideStickers.count == 2)
        #expect(cardBack.backSideStickers[0].x == 0.5)
        #expect(cardBack.backSideStickers[1].rotation == -10.0)
    }

    // MARK: - Layout Configuration Tests

    @Test("RecipeCardBack stores visible sections")
    func testVisibleSections_StoresCustomSections() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.visibleSections = [.attribution, .userRating]

        // Assert
        #expect(cardBack.visibleSections.count == 2)
        #expect(cardBack.visibleSections.contains(.attribution))
        #expect(cardBack.visibleSections.contains(.userRating))
    }

    @Test("RecipeCardBack stores layout style")
    func testLayoutStyle_StoresValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.layoutStyle = .detailed

        // Assert
        #expect(cardBack.layoutStyle == .detailed)
    }

    // MARK: - Sharing Context Tests

    @Test("RecipeCardBack stores share message")
    func testShareMessage_StoresValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.shareMessage = "Try this amazing recipe!"

        // Assert
        #expect(cardBack.shareMessage == "Try this amazing recipe!")
    }

    @Test("RecipeCardBack toggles include back when sharing")
    func testIncludeBackWhenSharing_TogglesValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.includeBackWhenSharing = false

        // Assert
        #expect(cardBack.includeBackWhenSharing == false)
    }

    @Test("RecipeCardBack stores privacy level")
    func testPrivacyLevel_StoresValue() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.privacyLevel = .public

        // Assert
        #expect(cardBack.privacyLevel == .public)
    }

    // MARK: - Metadata Tests

    @Test("RecipeCardBack increments times shared")
    func testTimesShared_Increments() {
        // Arrange
        let cardBack = RecipeCardBack()
        #expect(cardBack.timesShared == 0)

        // Act
        cardBack.timesShared += 1

        // Assert
        #expect(cardBack.timesShared == 1)
    }

    @Test("RecipeCardBack stores last edited at timestamp")
    func testLastEditedAt_StoresTimestamp() {
        // Arrange
        let cardBack = RecipeCardBack()
        let timestamp = Date()

        // Act
        cardBack.lastEditedAt = timestamp

        // Assert
        #expect(cardBack.lastEditedAt == timestamp)
    }

    @Test("RecipeCardBack toggles is complete")
    func testIsComplete_TogglesValue() {
        // Arrange
        let cardBack = RecipeCardBack()
        #expect(cardBack.isComplete == false)

        // Act
        cardBack.isComplete = true

        // Assert
        #expect(cardBack.isComplete == true)
    }

    // MARK: - Computed Property Tests

    @Test("hasContent returns false when card back is empty")
    func testHasContent_EmptyCardBack_ReturnsFalse() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act & Assert
        #expect(cardBack.hasContent == false)
    }

    @Test("hasContent returns true when has note to friends")
    func testHasContent_WithNoteToFriends_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.noteToFriends = "Great recipe!"

        // Act & Assert
        #expect(cardBack.hasContent == true)
    }

    @Test("hasContent returns true when has personal tips")
    func testHasContent_WithPersonalTips_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.personalTips = ["Tip 1"]

        // Act & Assert
        #expect(cardBack.hasContent == true)
    }

    @Test("hasContent returns true when has user rating")
    func testHasContent_WithUserRating_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.userRating = 5

        // Act & Assert
        #expect(cardBack.hasContent == true)
    }

    @Test("hasContent returns true when has pinned comments")
    func testHasContent_WithPinnedComments_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.pinnedCommentIDs = [UUID()]

        // Act & Assert
        #expect(cardBack.hasContent == true)
    }

    @Test("hasContent returns true when has stickers")
    func testHasContent_WithStickers_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.backSideStickers = [
            RecipeStickerPosition(stickerID: UUID(), x: 0.5, y: 0.5, rotation: 0, scale: 1.0)
        ]

        // Act & Assert
        #expect(cardBack.hasContent == true)
    }

    @Test("isReadyToDisplay returns false when not complete")
    func testIsReadyToDisplay_NotComplete_ReturnsFalse() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.noteToFriends = "Content"
        cardBack.isComplete = false

        // Act & Assert
        #expect(cardBack.isReadyToDisplay == false)
    }

    @Test("isReadyToDisplay returns false when no content")
    func testIsReadyToDisplay_NoContent_ReturnsFalse() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.isComplete = true

        // Act & Assert
        #expect(cardBack.isReadyToDisplay == false)
    }

    @Test("isReadyToDisplay returns true when has content and is complete")
    func testIsReadyToDisplay_HasContentAndComplete_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.noteToFriends = "Content"
        cardBack.isComplete = true

        // Act & Assert
        #expect(cardBack.isReadyToDisplay == true)
    }

    @Test("displayShareMessage returns custom message when set")
    func testDisplayShareMessage_WithCustomMessage_ReturnsCustom() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.shareMessage = "Try this!"

        // Act & Assert
        #expect(cardBack.displayShareMessage == "Try this!")
    }

    @Test("displayShareMessage returns default message when nil")
    func testDisplayShareMessage_NoCustomMessage_ReturnsDefault() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act & Assert
        #expect(cardBack.displayShareMessage == "Check out this recipe I love!")
    }

    @Test("pinnedCommentCount returns correct count")
    func testPinnedCommentCount_ReturnsCount() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.pinnedCommentIDs = [UUID(), UUID(), UUID()]

        // Act & Assert
        #expect(cardBack.pinnedCommentCount == 3)
    }

    @Test("showsSocialElements returns false when no social sections visible")
    func testShowsSocialElements_NoSocialSections_ReturnsFalse() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.visibleSections = [.attribution, .userRating]

        // Act & Assert
        #expect(cardBack.showsSocialElements == false)
    }

    @Test("showsSocialElements returns true when has pinned comments section")
    func testShowsSocialElements_HasPinnedComments_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.visibleSections = [.pinnedComments]

        // Act & Assert
        #expect(cardBack.showsSocialElements == true)
    }

    @Test("showsSocialElements returns true when has note to friends section")
    func testShowsSocialElements_HasNoteToFriends_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.visibleSections = [.noteToFriends]

        // Act & Assert
        #expect(cardBack.showsSocialElements == true)
    }

    @Test("showsHeritageContent returns false when no heritage sections")
    func testShowsHeritageContent_NoHeritageSections_ReturnsFalse() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act & Assert
        #expect(cardBack.showsHeritageContent == false)
    }

    @Test("showsHeritageContent returns true when has heritage collection badge")
    func testShowsHeritageContent_HasCollectionBadge_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.visibleSections.append(.heritageCollectionBadge)

        // Act & Assert
        #expect(cardBack.showsHeritageContent == true)
    }

    @Test("showsHeritageContent returns true when has heritage provenance")
    func testShowsHeritageContent_HasProvenance_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.visibleSections.append(.heritageProvenance)

        // Act & Assert
        #expect(cardBack.showsHeritageContent == true)
    }

    @Test("showsHeritageContent returns true when has historical text")
    func testShowsHeritageContent_HasHistoricalText_ReturnsTrue() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.visibleSections.append(.historicalText)

        // Act & Assert
        #expect(cardBack.showsHeritageContent == true)
    }

    // MARK: - Heritage Configuration Tests

    @Test("configureForHeritageRecipe adds heritage sections")
    func testConfigureForHeritageRecipe_AddsHeritageSections() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.visibleSections = [.attribution]

        // Act
        cardBack.configureForHeritageRecipe()

        // Assert
        #expect(cardBack.visibleSections.contains(.heritageCollectionBadge))
        #expect(cardBack.visibleSections.contains(.heritageProvenance))
        #expect(cardBack.visibleSections.contains(.historicalText))
    }

    @Test("configureForHeritageRecipe does not duplicate heritage sections")
    func testConfigureForHeritageRecipe_DoesNotDuplicate() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.visibleSections = [.heritageCollectionBadge]

        // Act
        cardBack.configureForHeritageRecipe()

        // Assert
        let badgeCount = cardBack.visibleSections.filter { $0 == .heritageCollectionBadge }.count
        #expect(badgeCount == 1)
    }

    @Test("configureForHeritageRecipe sets vintage styling")
    func testConfigureForHeritageRecipe_SetsVintageStyling() {
        // Arrange
        let cardBack = RecipeCardBack()

        // Act
        cardBack.configureForHeritageRecipe()

        // Assert
        #expect(cardBack.backgroundStyle == .vintage)
        #expect(cardBack.layoutStyle == .vintage)
        #expect(cardBack.showBorder == true)
    }

    @Test("configureForHeritageRecipe updates last modified timestamp")
    func testConfigureForHeritageRecipe_UpdatesTimestamp() {
        // Arrange
        let cardBack = RecipeCardBack()
        let before = Date()

        // Act
        cardBack.configureForHeritageRecipe()

        // Assert
        #expect(cardBack.lastModified >= before)
    }

    @Test("removeHeritageSections removes all heritage sections")
    func testRemoveHeritageSections_RemovesAllHeritageSections() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.visibleSections = [
            .attribution,
            .heritageCollectionBadge,
            .heritageProvenance,
            .historicalText,
            .noteToFriends
        ]

        // Act
        cardBack.removeHeritageSections()

        // Assert
        #expect(!cardBack.visibleSections.contains(.heritageCollectionBadge))
        #expect(!cardBack.visibleSections.contains(.heritageProvenance))
        #expect(!cardBack.visibleSections.contains(.historicalText))
        #expect(cardBack.visibleSections.contains(.attribution))
        #expect(cardBack.visibleSections.contains(.noteToFriends))
    }

    @Test("removeHeritageSections updates last modified timestamp")
    func testRemoveHeritageSections_UpdatesTimestamp() {
        // Arrange
        let cardBack = RecipeCardBack()
        cardBack.visibleSections.append(.heritageCollectionBadge)
        let before = Date()

        // Act
        cardBack.removeHeritageSections()

        // Assert
        #expect(cardBack.lastModified >= before)
    }

    // MARK: - Supporting Type Tests

    @Test("AttributionPosition enum has all cases")
    func testAttributionPosition_AllCases() {
        // Assert
        #expect(AttributionPosition.topLeft.rawValue == "topLeft")
        #expect(AttributionPosition.topRight.rawValue == "topRight")
        #expect(AttributionPosition.bottomLeft.rawValue == "bottomLeft")
        #expect(AttributionPosition.bottomRight.rawValue == "bottomRight")
        #expect(AttributionPosition.center.rawValue == "center")
    }

    @Test("CardBackgroundStyle enum has all cases")
    func testCardBackgroundStyle_AllCases() {
        // Assert
        #expect(CardBackgroundStyle.cream.rawValue == "cream")
        #expect(CardBackgroundStyle.vintage.rawValue == "vintage")
        #expect(CardBackgroundStyle.lined.rawValue == "lined")
        #expect(CardBackgroundStyle.grid.rawValue == "grid")
        #expect(CardBackgroundStyle.photo.rawValue == "photo")
        #expect(CardBackgroundStyle.solid.rawValue == "solid")
    }

    @Test("CardBackSection enum has all cases")
    func testCardBackSection_AllCases() {
        // Assert
        #expect(CardBackSection.attribution.rawValue == "attribution")
        #expect(CardBackSection.noteToFriends.rawValue == "noteToFriends")
        #expect(CardBackSection.pinnedComments.rawValue == "pinnedComments")
        #expect(CardBackSection.userTips.rawValue == "userTips")
        #expect(CardBackSection.userRating.rawValue == "userRating")
        #expect(CardBackSection.userTags.rawValue == "userTags")
        #expect(CardBackSection.cookingHistory.rawValue == "cookingHistory")
        #expect(CardBackSection.heritageCollectionBadge.rawValue == "heritageCollectionBadge")
        #expect(CardBackSection.heritageProvenance.rawValue == "heritageProvenance")
        #expect(CardBackSection.historicalText.rawValue == "historicalText")
    }

    @Test("CardBackLayout enum has all cases")
    func testCardBackLayout_AllCases() {
        // Assert
        #expect(CardBackLayout.standard.rawValue == "standard")
        #expect(CardBackLayout.minimal.rawValue == "minimal")
        #expect(CardBackLayout.detailed.rawValue == "detailed")
        #expect(CardBackLayout.vintage.rawValue == "vintage")
    }

    @Test("CardBackPrivacy enum has all cases")
    func testCardBackPrivacy_AllCases() {
        // Assert
        #expect(CardBackPrivacy.private.rawValue == "private")
        #expect(CardBackPrivacy.friendsOnly.rawValue == "friendsOnly")
        #expect(CardBackPrivacy.public.rawValue == "public")
    }

    @Test("RecipeStickerPosition stores all properties")
    func testRecipeStickerPosition_StoresAllProperties() {
        // Arrange
        let stickerID = UUID()

        // Act
        let position = RecipeStickerPosition(
            stickerID: stickerID,
            x: 0.75,
            y: 0.25,
            rotation: 45.0,
            scale: 1.5
        )

        // Assert
        #expect(position.stickerID == stickerID)
        #expect(position.x == 0.75)
        #expect(position.y == 0.25)
        #expect(position.rotation == 45.0)
        #expect(position.scale == 1.5)
    }

    // MARK: - Sample Data Tests

    @Test("sample() creates card back with sample data")
    func testSample_CreatesCardBackWithData() {
        // Act
        let cardBack = RecipeCardBack.sample()

        // Assert
        #expect(cardBack.noteToFriends != nil)
        #expect(cardBack.personalTips.count == 3)
        #expect(cardBack.userRating == 5)
        #expect(cardBack.userTags.count == 3)
        #expect(cardBack.showAttribution == true)
        #expect(cardBack.backgroundStyle == .vintage)
        #expect(cardBack.layoutStyle == .detailed)
        #expect(cardBack.isComplete == true)
    }

    @Test("sample() creates card back with recipe relationship")
    func testSample_WithRecipe_SetsRecipe() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")
        context.insert(recipe)

        // Act
        let cardBack = RecipeCardBack.sample(with: recipe)

        // Assert
        #expect(cardBack.recipe?.id == recipe.id)
    }
}
