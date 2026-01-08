import Foundation
import SwiftData

/// Represents a comment on a recipe - can be from website scraping or user-generated
/// Supports threading for conversations and sentiment analysis for insights
@Model
final class RecipeComment {
    // MARK: - Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modifiedAt: Date?

    // MARK: - Relationships
    var recipe: Recipe?

    /// Parent comment for threading (nil if top-level comment)
    var parentComment: RecipeComment?

    /// Child comments (replies)
    /// Note: For self-referential relationships, only the "many" side (array) has inverse
    @Relationship(deleteRule: .cascade, inverse: \RecipeComment.parentComment)
    var replies: [RecipeComment]?

    // MARK: - Content
    var text: String = ""
    var authorName: String?
    var authorAvatar: String? // URL or asset name

    // MARK: - Source
    /// Where this comment came from
    var source: CommentSource = CommentSource.user

    /// Original URL if scraped from website
    var sourceURL: String?

    /// Date from original comment (may differ from createdAt if scraped)
    var originalDate: Date?

    // MARK: - Classification & Analysis
    /// Type of insight this comment provides
    var commentType: CommentType = CommentType.general

    /// Sentiment score (-1.0 to 1.0, where -1 is negative, 0 neutral, 1 positive)
    var sentimentScore: Double?

    /// Extracted topics/themes (e.g., "texture", "timing", "ingredient substitution")
    var topics: [String] = []

    /// Confidence score for AI-generated analysis (0.0 to 1.0)
    var analysisConfidence: Double?

    // MARK: - User Interaction
    /// Useful votes (upvotes)
    var upvotes: Int = 0

    /// Not useful votes (downvotes)
    var downvotes: Int = 0

    /// Whether user has pinned this comment to card back
    var isPinned: Bool = false

    /// Whether user has marked as favorite
    var isFavorite: Bool = false

    /// Whether comment is shown on recipe card back
    var showOnCardBack: Bool = false

    // MARK: - Shared Comments (Phase 2C)
    /// Visibility scope for this comment
    var shareScope: CommentScope = CommentScope.private

    /// Provenance hash of the recipe version this comment was made on
    /// Used to aggregate comments across shared copies
    var originProvenanceHash: String?

    /// Number of endorsements from users across lineage
    var endorsementCount: Int = 0

    // MARK: - Rich Content
    /// Structured data extracted from comment (e.g., ingredient modifications)
    var structuredData: CommentStructuredData?

    // MARK: - Moderation
    /// Whether comment has been flagged for review
    var isFlagged: Bool = false

    /// Whether comment is hidden from view
    var isHidden: Bool = false

    /// Reason for hiding/flagging
    var moderationNote: String?

    // MARK: - Initialization
    init(
        text: String,
        authorName: String? = nil,
        source: CommentSource = .user,
        commentType: CommentType = .general,
        recipe: Recipe? = nil,
        parentComment: RecipeComment? = nil
    ) {
        self.id = UUID()
        // SECURITY FIX: Sanitize text to prevent XSS attacks (SEC-1)
        // Strip all HTML tags from comments to prevent script injection
        self.text = HTMLSanitizer.shared.stripAllHTML(text)
        self.authorName = authorName
        self.source = source
        self.commentType = commentType
        self.recipe = recipe
        self.parentComment = parentComment
        self.createdAt = Date()
        self.replies = []
        self.topics = []
    }
}

// MARK: - Supporting Types

enum CommentSource: String, Codable, CaseIterable {
    case user = "user"              // Created by app user
    case scraped = "scraped"        // Scraped from recipe website
    case ai = "ai"                  // AI-generated insight
    case imported = "imported"      // Imported from another service
}

enum CommentType: String, Codable, CaseIterable {
    case general = "general"                        // General comment
    case tip = "tip"                                // Cooking tip or trick
    case modification = "modification"              // Recipe modification or substitution
    case timing = "timing"                          // Timing adjustment suggestion
    case technique = "technique"                    // Technique clarification
    case substitution = "substitution"              // Ingredient substitution
    case scaling = "scaling"                        // Scaling advice
    case storage = "storage"                        // Storage tips
    case pairing = "pairing"                        // Pairing suggestions
    case warning = "warning"                        // Warning or caution
    case question = "question"                      // Question about recipe
    case review = "review"                          // Overall review/rating
}

enum CommentScope: String, Codable, CaseIterable {
    case `private` = "private"      // Only visible to you
    case lineage = "lineage"        // Visible to anyone in the recipe's lineage (shares)
    case `public` = "public"        // Visible to everyone (future: public recipe comments)

    var displayName: String {
        switch self {
        case .private: return "Private"
        case .lineage: return "Share with Family"
        case .public: return "Public"
        }
    }

    var description: String {
        switch self {
        case .private: return "Only you can see this"
        case .lineage: return "Visible to everyone who has this recipe"
        case .public: return "Visible to anyone"
        }
    }

    var iconName: String {
        switch self {
        case .private: return "lock.fill"
        case .lineage: return "person.2.fill"
        case .public: return "globe"
        }
    }
}

struct CommentStructuredData: Codable {
    /// Original ingredient mentioned
    var originalIngredient: String?

    /// Suggested replacement
    var replacementIngredient: String?

    /// Original timing
    var originalTiming: String?

    /// Suggested timing adjustment
    var adjustedTiming: String?

    /// Temperature adjustment
    var temperatureAdjustment: String?

    /// Serving size context
    var servingContext: String?

    /// Success rating (1-5)
    var successRating: Int?

    /// Additional structured notes
    var notes: [String: String] = [:]
}

// MARK: - Extensions

extension RecipeComment {
    /// Whether this is a top-level comment (no parent)
    var isTopLevel: Bool {
        parentComment == nil
    }

    /// Total number of votes (upvotes - downvotes)
    var voteScore: Int {
        upvotes - downvotes
    }

    /// Whether comment has high engagement
    var isHighEngagement: Bool {
        upvotes >= 5 || voteScore >= 3
    }

    /// Whether comment is positive (based on sentiment)
    var isPositive: Bool {
        guard let score = sentimentScore else { return false }
        return score > 0.2
    }

    /// Whether comment is negative (based on sentiment)
    var isNegative: Bool {
        guard let score = sentimentScore else { return false }
        return score < -0.2
    }

    /// Formatted author display name
    var displayAuthor: String {
        authorName ?? "Anonymous"
    }

    /// Formatted date string
    var displayDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: originalDate ?? createdAt, relativeTo: Date())
    }

    // MARK: - Shared Comment Helpers

    /// Whether this comment is shared beyond private scope
    var isShared: Bool {
        shareScope != .private
    }

    /// Whether this comment can be seen by recipe lineage
    var isVisibleToLineage: Bool {
        shareScope == .lineage || shareScope == .public
    }

    /// Whether this comment is from another user's recipe copy
    var isFromLineage: Bool {
        originProvenanceHash != nil && originProvenanceHash != recipe?.provenance?.rootProvenanceHash
    }

    /// Total engagement score (upvotes + endorsements - downvotes)
    var totalEngagementScore: Int {
        upvotes + endorsementCount - downvotes
    }

    /// Whether this comment has significant engagement
    var hasSignificantEngagement: Bool {
        totalEngagementScore >= 5 || endorsementCount >= 3
    }

    // MARK: - Security Helper Methods (Phase 7)

    /// Safely set text with HTML sanitization (SEC-1)
    func setText(_ newText: String) {
        self.text = HTMLSanitizer.shared.stripAllHTML(newText)
        self.modifiedAt = Date()
    }
}

// MARK: - Sample Data

extension RecipeComment {
    static func sample(
        text: String = "This recipe turned out amazing! I doubled the garlic and it was perfect.",
        source: CommentSource = .scraped,
        commentType: CommentType = .modification
    ) -> RecipeComment {
        let comment = RecipeComment(
            text: text,
            authorName: "Sarah M.",
            source: source,
            commentType: commentType
        )
        comment.upvotes = 12
        comment.sentimentScore = 0.85
        comment.topics = ["garlic", "modification", "flavor"]
        comment.analysisConfidence = 0.92

        return comment
    }
}
