import Foundation
import SwiftData

/// Represents the back side of a recipe card with social features
/// Displays attribution, user notes, pinned comments, and stickers
@Model
final class RecipeCardBack {
    // MARK: - Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var lastModified: Date = Date()

    // MARK: - Relationship
    var recipe: Recipe?

    // MARK: - User Notes
    /// Personal note from recipe owner to friends/family
    var noteToFriends: String?

    /// Cooking tips or modifications the user wants to highlight
    var personalTips: [String] = []

    /// User's rating (1-5 stars)
    var userRating: Int?

    /// Tags the user has added (dietary, occasion, etc.)
    var userTags: [String] = []

    // MARK: - Attribution Display
    /// Whether to show attribution on card back
    var showAttribution: Bool = true

    /// Custom attribution text (overrides auto-generated)
    var customAttributionText: String?

    /// Attribution position on card
    var attributionPosition: AttributionPosition = AttributionPosition.bottomLeft

    // MARK: - Comment Display
    /// IDs of pinned comments to show on card back
    var pinnedCommentIDs: [UUID] = []

    /// Maximum number of comments to display
    var maxCommentsToDisplay: Int = 3

    /// Whether to show sentiment indicators
    var showSentimentIndicators: Bool = true

    // MARK: - Visual Customization
    /// Background style for card back
    var backgroundStyle: CardBackgroundStyle = CardBackgroundStyle.cream

    /// Text color for card back
    var textColor: String = "#2D2D2D" // Hex color

    /// Whether to show decorative border
    var showBorder: Bool = true

    /// Border color
    var borderColor: String = "#E8D7C3"

    /// Font size multiplier (0.8 - 1.2)
    var fontSizeMultiplier: Double = 1.0

    // MARK: - Sticker Positions (Back Side)
    /// Stickers that appear on the back of the card
    var backSideStickers: [RecipeStickerPosition] = []

    // MARK: - Layout Configuration
    /// Which sections to show on card back
    var visibleSections: [CardBackSection] = [
        CardBackSection.attribution,
        CardBackSection.noteToFriends,
        CardBackSection.pinnedComments,
        CardBackSection.userTips
    ]

    /// Layout style for card back
    var layoutStyle: CardBackLayout = CardBackLayout.standard

    // MARK: - Sharing Context
    /// Message when sharing this recipe
    var shareMessage: String?

    /// Whether to include card back when sharing
    var includeBackWhenSharing: Bool = true

    /// Privacy level for card back
    var privacyLevel: CardBackPrivacy = CardBackPrivacy.friendsOnly

    // MARK: - Metadata
    /// Times this recipe has been shared
    var timesShared: Int = 0

    /// Last time card back was edited
    var lastEditedAt: Date?

    /// Whether card back is complete and ready to show
    var isComplete: Bool = false

    // MARK: - Initialization
    init(recipe: Recipe? = nil) {
        self.id = UUID()
        self.recipe = recipe
        self.createdAt = Date()
        self.lastModified = Date()
        self.pinnedCommentIDs = []
        self.personalTips = []
        self.userTags = []
        self.backSideStickers = []
        self.visibleSections = [.attribution, .noteToFriends, .pinnedComments, .userTips]
    }
}

// MARK: - Supporting Types

enum AttributionPosition: String, Codable {
    case topLeft = "topLeft"
    case topRight = "topRight"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
    case center = "center"
}

enum CardBackgroundStyle: String, Codable, CaseIterable {
    case cream = "cream"                    // Warm cream color
    case vintage = "vintage"                // Aged paper texture
    case lined = "lined"                    // Lined paper
    case grid = "grid"                      // Recipe card grid
    case photo = "photo"                    // Photo background (blurred)
    case solid = "solid"                    // Solid color
}

enum CardBackSection: String, Codable, CaseIterable {
    case attribution = "attribution"
    case noteToFriends = "noteToFriends"
    case pinnedComments = "pinnedComments"
    case userTips = "userTips"
    case userRating = "userRating"
    case userTags = "userTags"
    case cookingHistory = "cookingHistory"
}

enum CardBackLayout: String, Codable, CaseIterable {
    case standard = "standard"              // Balanced layout
    case minimal = "minimal"                // Clean and sparse
    case detailed = "detailed"              // Maximum information
    case vintage = "vintage"                // Classic recipe card style
}

enum CardBackPrivacy: String, Codable {
    case `private` = "private"              // Only visible to owner
    case friendsOnly = "friendsOnly"        // Visible to shared recipients
    case `public` = "public"                // Visible to anyone
}

struct RecipeStickerPosition: Codable {
    var stickerID: UUID
    var x: Double                           // 0.0 to 1.0 (percentage of card width)
    var y: Double                           // 0.0 to 1.0 (percentage of card height)
    var rotation: Double                    // Degrees
    var scale: Double                       // 0.5 to 2.0
}

// MARK: - Extensions

extension RecipeCardBack {
    /// Whether card back has any user content
    var hasContent: Bool {
        noteToFriends != nil ||
        !personalTips.isEmpty ||
        userRating != nil ||
        !pinnedCommentIDs.isEmpty ||
        !backSideStickers.isEmpty
    }

    /// Whether card back is ready to display
    var isReadyToDisplay: Bool {
        hasContent && isComplete
    }

    /// Formatted share message
    var displayShareMessage: String {
        shareMessage ?? "Check out this recipe I love!"
    }

    /// Number of pinned comments
    var pinnedCommentCount: Int {
        pinnedCommentIDs.count
    }

    /// Whether card back shows social elements
    var showsSocialElements: Bool {
        visibleSections.contains(.pinnedComments) ||
        visibleSections.contains(.noteToFriends)
    }
}

// MARK: - Sample Data

extension RecipeCardBack {
    static func sample(with recipe: Recipe? = nil) -> RecipeCardBack {
        let cardBack = RecipeCardBack(recipe: recipe)
        cardBack.noteToFriends = "This is my grandmother's recipe - she always said the secret is to not overmix the batter!"
        cardBack.personalTips = [
            "Let butter come to room temperature first",
            "Double the vanilla for extra flavor",
            "Works great with gluten-free flour too"
        ]
        cardBack.userRating = 5
        cardBack.userTags = ["family favorite", "easy", "kid-friendly"]
        cardBack.showAttribution = true
        cardBack.backgroundStyle = .vintage
        cardBack.layoutStyle = .detailed
        cardBack.isComplete = true

        return cardBack
    }
}
