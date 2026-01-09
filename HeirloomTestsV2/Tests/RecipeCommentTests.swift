import Testing
import Foundation
import SwiftData

@testable import Heirloom

@Suite("Recipe Comment Tests")
struct RecipeCommentTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Heirloom.Recipe.self,
            RecipeComment.self,
            Heirloom.Ingredient.self,
            Heirloom.Tag.self,
            RecipeCollection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Initialization Tests

    @Test("RecipeComment initializes with required text")
    func testInit_WithText_SetsText() {
        // Act
        let comment = RecipeComment(text: "Great recipe!")

        // Assert
        #expect(comment.text == "Great recipe!")
    }

    @Test("RecipeComment initializes with default values")
    func testInit_SetsDefaultValues() {
        // Act
        let comment = RecipeComment(text: "Comment")

        // Assert
        #expect(comment.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(comment.source == .user)
        #expect(comment.commentType == .general)
        #expect(comment.recipe == nil)
        #expect(comment.parentComment == nil)
        #expect(comment.replies != nil)
        #expect(comment.topics.isEmpty)
        #expect(comment.upvotes == 0)
        #expect(comment.downvotes == 0)
        #expect(comment.isPinned == false)
        #expect(comment.isFavorite == false)
        #expect(comment.showOnCardBack == false)
        #expect(comment.shareScope == .private)
        #expect(comment.endorsementCount == 0)
        #expect(comment.isFlagged == false)
        #expect(comment.isHidden == false)
    }

    @Test("RecipeComment initializes with custom parameters")
    func testInit_WithCustomParameters_SetsValues() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test")

        // Act
        let comment = RecipeComment(
            text: "Comment",
            authorName: "John",
            source: .scraped,
            commentType: .tip,
            recipe: recipe
        )

        // Assert
        #expect(comment.authorName == "John")
        #expect(comment.source == .scraped)
        #expect(comment.commentType == .tip)
        #expect(comment.recipe?.id == recipe.id)
    }

    @Test("RecipeComment creates timestamp on initialization")
    func testInit_CreatesTimestamp() {
        // Arrange
        let before = Date()

        // Act
        let comment = RecipeComment(text: "Comment")

        // Assert
        #expect(comment.createdAt >= before)
        #expect(comment.modifiedAt == nil)
    }

    // MARK: - Threading Tests

    @Test("RecipeComment supports parent-child threading")
    func testThreading_ParentChild() {
        // Arrange
        let context = createTestContext()
        let parent = RecipeComment(text: "Parent comment")
        context.insert(parent)

        // Act
        let child = RecipeComment(text: "Child reply", parentComment: parent)
        context.insert(child)
        parent.replies?.append(child)

        // Assert
        #expect(child.parentComment?.id == parent.id)
        #expect(parent.replies?.count == 1)
        #expect(parent.replies?[0].id == child.id)
    }

    @Test("RecipeComment isTopLevel returns true for no parent")
    func testIsTopLevel_NoParent_ReturnsTrue() {
        // Act
        let comment = RecipeComment(text: "Comment")

        // Assert
        #expect(comment.isTopLevel == true)
    }

    @Test("RecipeComment isTopLevel returns false when has parent")
    func testIsTopLevel_HasParent_ReturnsFalse() {
        // Arrange
        let parent = RecipeComment(text: "Parent")
        let child = RecipeComment(text: "Child", parentComment: parent)

        // Assert
        #expect(child.isTopLevel == false)
    }

    // MARK: - Content Tests

    @Test("RecipeComment stores author information")
    func testAuthor_StoresInformation() {
        // Act
        let comment = RecipeComment(text: "Comment", authorName: "Sarah M.")
        comment.authorAvatar = "avatar-123.jpg"

        // Assert
        #expect(comment.authorName == "Sarah M.")
        #expect(comment.authorAvatar == "avatar-123.jpg")
    }

    @Test("RecipeComment displayAuthor returns name when set")
    func testDisplayAuthor_WithName_ReturnsName() {
        // Act
        let comment = RecipeComment(text: "Comment", authorName: "Sarah")

        // Assert
        #expect(comment.displayAuthor == "Sarah")
    }

    @Test("RecipeComment displayAuthor returns Anonymous when nil")
    func testDisplayAuthor_NoName_ReturnsAnonymous() {
        // Act
        let comment = RecipeComment(text: "Comment")

        // Assert
        #expect(comment.displayAuthor == "Anonymous")
    }

    // MARK: - Source Tests

    @Test("CommentSource enum has all cases")
    func testCommentSource_AllCases() {
        // Assert
        #expect(CommentSource.user.rawValue == "user")
        #expect(CommentSource.scraped.rawValue == "scraped")
        #expect(CommentSource.ai.rawValue == "ai")
        #expect(CommentSource.imported.rawValue == "imported")
    }

    @Test("RecipeComment stores source URL")
    func testSourceURL_Stores() {
        // Act
        let comment = RecipeComment(text: "Comment", source: .scraped)
        comment.sourceURL = "https://example.com/recipe/comments"

        // Assert
        #expect(comment.sourceURL == "https://example.com/recipe/comments")
    }

    @Test("RecipeComment stores original date")
    func testOriginalDate_Stores() {
        // Arrange
        let date = Date(timeIntervalSince1970: 1609459200) // Jan 1, 2021

        // Act
        let comment = RecipeComment(text: "Comment")
        comment.originalDate = date

        // Assert
        #expect(comment.originalDate == date)
    }

    // MARK: - Comment Type Tests

    @Test("CommentType enum has all cases")
    func testCommentType_AllCases() {
        // Assert
        #expect(CommentType.general.rawValue == "general")
        #expect(CommentType.tip.rawValue == "tip")
        #expect(CommentType.modification.rawValue == "modification")
        #expect(CommentType.timing.rawValue == "timing")
        #expect(CommentType.technique.rawValue == "technique")
        #expect(CommentType.substitution.rawValue == "substitution")
        #expect(CommentType.scaling.rawValue == "scaling")
        #expect(CommentType.storage.rawValue == "storage")
        #expect(CommentType.pairing.rawValue == "pairing")
        #expect(CommentType.warning.rawValue == "warning")
        #expect(CommentType.question.rawValue == "question")
        #expect(CommentType.review.rawValue == "review")
    }

    // MARK: - Sentiment Analysis Tests

    @Test("RecipeComment stores sentiment score")
    func testSentimentScore_Stores() {
        // Act
        let comment = RecipeComment(text: "Amazing recipe!")
        comment.sentimentScore = 0.85

        // Assert
        #expect(comment.sentimentScore == 0.85)
    }

    @Test("RecipeComment isPositive returns true for positive sentiment")
    func testIsPositive_PositiveSentiment_ReturnsTrue() {
        // Act
        let comment = RecipeComment(text: "Great!")
        comment.sentimentScore = 0.5

        // Assert
        #expect(comment.isPositive == true)
    }

    @Test("RecipeComment isPositive returns false for neutral sentiment")
    func testIsPositive_NeutralSentiment_ReturnsFalse() {
        // Act
        let comment = RecipeComment(text: "Okay")
        comment.sentimentScore = 0.1

        // Assert
        #expect(comment.isPositive == false)
    }

    @Test("RecipeComment isNegative returns true for negative sentiment")
    func testIsNegative_NegativeSentiment_ReturnsTrue() {
        // Act
        let comment = RecipeComment(text: "Terrible")
        comment.sentimentScore = -0.5

        // Assert
        #expect(comment.isNegative == true)
    }

    @Test("RecipeComment isNegative returns false for neutral sentiment")
    func testIsNegative_NeutralSentiment_ReturnsFalse() {
        // Act
        let comment = RecipeComment(text: "Okay")
        comment.sentimentScore = -0.1

        // Assert
        #expect(comment.isNegative == false)
    }

    @Test("RecipeComment stores topics")
    func testTopics_Stores() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.topics = ["garlic", "timing", "temperature"]

        // Assert
        #expect(comment.topics.count == 3)
        #expect(comment.topics.contains("garlic"))
        #expect(comment.topics.contains("timing"))
    }

    @Test("RecipeComment stores analysis confidence")
    func testAnalysisConfidence_Stores() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.analysisConfidence = 0.92

        // Assert
        #expect(comment.analysisConfidence == 0.92)
    }

    // MARK: - Voting Tests

    @Test("RecipeComment tracks upvotes")
    func testUpvotes_Tracks() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.upvotes = 15

        // Assert
        #expect(comment.upvotes == 15)
    }

    @Test("RecipeComment tracks downvotes")
    func testDownvotes_Tracks() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.downvotes = 3

        // Assert
        #expect(comment.downvotes == 3)
    }

    @Test("RecipeComment voteScore calculates correctly")
    func testVoteScore_Calculates() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.upvotes = 20
        comment.downvotes = 5

        // Assert
        #expect(comment.voteScore == 15)
    }

    @Test("RecipeComment isHighEngagement returns true for high upvotes")
    func testIsHighEngagement_HighUpvotes_ReturnsTrue() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.upvotes = 10

        // Assert
        #expect(comment.isHighEngagement == true)
    }

    @Test("RecipeComment isHighEngagement returns true for high vote score")
    func testIsHighEngagement_HighVoteScore_ReturnsTrue() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.upvotes = 5
        comment.downvotes = 1

        // Assert
        #expect(comment.isHighEngagement == true)
    }

    @Test("RecipeComment isHighEngagement returns false for low engagement")
    func testIsHighEngagement_LowEngagement_ReturnsFalse() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.upvotes = 2

        // Assert
        #expect(comment.isHighEngagement == false)
    }

    // MARK: - User Interaction Tests

    @Test("RecipeComment can be pinned")
    func testPinned_CanBeSet() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.isPinned = true

        // Assert
        #expect(comment.isPinned == true)
    }

    @Test("RecipeComment can be favorited")
    func testFavorite_CanBeSet() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.isFavorite = true

        // Assert
        #expect(comment.isFavorite == true)
    }

    @Test("RecipeComment can be shown on card back")
    func testShowOnCardBack_CanBeSet() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.showOnCardBack = true

        // Assert
        #expect(comment.showOnCardBack == true)
    }

    // MARK: - Share Scope Tests

    @Test("CommentScope enum has all cases")
    func testCommentScope_AllCases() {
        // Assert
        #expect(CommentScope.private.rawValue == "private")
        #expect(CommentScope.lineage.rawValue == "lineage")
        #expect(CommentScope.public.rawValue == "public")
    }

    @Test("CommentScope provides display names")
    func testCommentScope_DisplayNames() {
        // Assert
        #expect(CommentScope.private.displayName == "Private")
        #expect(CommentScope.lineage.displayName == "Share with Family")
        #expect(CommentScope.public.displayName == "Public")
    }

    @Test("CommentScope provides descriptions")
    func testCommentScope_Descriptions() {
        // Assert
        #expect(CommentScope.private.description == "Only you can see this")
        #expect(CommentScope.lineage.description == "Visible to everyone who has this recipe")
        #expect(CommentScope.public.description == "Visible to anyone")
    }

    @Test("CommentScope provides icon names")
    func testCommentScope_IconNames() {
        // Assert
        #expect(CommentScope.private.iconName == "lock.fill")
        #expect(CommentScope.lineage.iconName == "person.2.fill")
        #expect(CommentScope.public.iconName == "globe")
    }

    @Test("RecipeComment isShared returns false for private scope")
    func testIsShared_PrivateScope_ReturnsFalse() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.shareScope = .private

        // Assert
        #expect(comment.isShared == false)
    }

    @Test("RecipeComment isShared returns true for lineage scope")
    func testIsShared_LineageScope_ReturnsTrue() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.shareScope = .lineage

        // Assert
        #expect(comment.isShared == true)
    }

    @Test("RecipeComment isVisibleToLineage returns true for lineage scope")
    func testIsVisibleToLineage_LineageScope_ReturnsTrue() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.shareScope = .lineage

        // Assert
        #expect(comment.isVisibleToLineage == true)
    }

    @Test("RecipeComment isVisibleToLineage returns true for public scope")
    func testIsVisibleToLineage_PublicScope_ReturnsTrue() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.shareScope = .public

        // Assert
        #expect(comment.isVisibleToLineage == true)
    }

    // MARK: - Provenance and Endorsement Tests

    @Test("RecipeComment stores origin provenance hash")
    func testOriginProvenanceHash_Stores() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.originProvenanceHash = "abc123def456"

        // Assert
        #expect(comment.originProvenanceHash == "abc123def456")
    }

    @Test("RecipeComment tracks endorsement count")
    func testEndorsementCount_Tracks() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.endorsementCount = 7

        // Assert
        #expect(comment.endorsementCount == 7)
    }

    @Test("RecipeComment totalEngagementScore includes endorsements")
    func testTotalEngagementScore_IncludesEndorsements() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.upvotes = 10
        comment.downvotes = 2
        comment.endorsementCount = 5

        // Assert
        #expect(comment.totalEngagementScore == 13) // 10 + 5 - 2
    }

    @Test("RecipeComment hasSignificantEngagement with high total score")
    func testHasSignificantEngagement_HighTotalScore_ReturnsTrue() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.upvotes = 10

        // Assert
        #expect(comment.hasSignificantEngagement == true)
    }

    @Test("RecipeComment hasSignificantEngagement with high endorsements")
    func testHasSignificantEngagement_HighEndorsements_ReturnsTrue() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.endorsementCount = 5

        // Assert
        #expect(comment.hasSignificantEngagement == true)
    }

    // MARK: - Structured Data Tests

    @Test("CommentStructuredData stores ingredient substitution")
    func testStructuredData_IngredientSubstitution() {
        // Act
        var data = CommentStructuredData()
        data.originalIngredient = "butter"
        data.replacementIngredient = "coconut oil"

        let comment = RecipeComment(text: "Comment")
        comment.structuredData = data

        // Assert
        #expect(comment.structuredData?.originalIngredient == "butter")
        #expect(comment.structuredData?.replacementIngredient == "coconut oil")
    }

    @Test("CommentStructuredData stores timing adjustments")
    func testStructuredData_TimingAdjustments() {
        // Act
        var data = CommentStructuredData()
        data.originalTiming = "30 minutes"
        data.adjustedTiming = "45 minutes"

        let comment = RecipeComment(text: "Comment")
        comment.structuredData = data

        // Assert
        #expect(comment.structuredData?.originalTiming == "30 minutes")
        #expect(comment.structuredData?.adjustedTiming == "45 minutes")
    }

    @Test("CommentStructuredData stores success rating")
    func testStructuredData_SuccessRating() {
        // Act
        var data = CommentStructuredData()
        data.successRating = 5

        let comment = RecipeComment(text: "Comment")
        comment.structuredData = data

        // Assert
        #expect(comment.structuredData?.successRating == 5)
    }

    @Test("CommentStructuredData stores temperature adjustment")
    func testStructuredData_TemperatureAdjustment() {
        // Act
        var data = CommentStructuredData()
        data.temperatureAdjustment = "Reduce by 25°F"

        let comment = RecipeComment(text: "Comment")
        comment.structuredData = data

        // Assert
        #expect(comment.structuredData?.temperatureAdjustment == "Reduce by 25°F")
    }

    @Test("CommentStructuredData stores custom notes")
    func testStructuredData_CustomNotes() {
        // Act
        var data = CommentStructuredData()
        data.notes["altitude"] = "High altitude adjustment needed"
        data.notes["dietary"] = "Works great with gluten-free flour"

        let comment = RecipeComment(text: "Comment")
        comment.structuredData = data

        // Assert
        #expect(comment.structuredData?.notes["altitude"] == "High altitude adjustment needed")
        #expect(comment.structuredData?.notes["dietary"] == "Works great with gluten-free flour")
    }

    // MARK: - Moderation Tests

    @Test("RecipeComment can be flagged")
    func testFlagged_CanBeSet() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.isFlagged = true
        comment.moderationNote = "Inappropriate content"

        // Assert
        #expect(comment.isFlagged == true)
        #expect(comment.moderationNote == "Inappropriate content")
    }

    @Test("RecipeComment can be hidden")
    func testHidden_CanBeSet() {
        // Act
        let comment = RecipeComment(text: "Comment")
        comment.isHidden = true

        // Assert
        #expect(comment.isHidden == true)
    }

    // MARK: - Sample Data Tests

    @Test("RecipeComment sample creates comment with defaults")
    func testSample_CreatesWithDefaults() {
        // Act
        let comment = RecipeComment.sample()

        // Assert
        #expect(comment.text.contains("amazing"))
        #expect(comment.authorName == "Sarah M.")
        #expect(comment.source == .scraped)
        #expect(comment.commentType == .modification)
        #expect(comment.upvotes == 12)
        #expect(comment.sentimentScore == 0.85)
        #expect(comment.topics.contains("garlic"))
        #expect(comment.analysisConfidence == 0.92)
    }

    @Test("RecipeComment sample accepts custom parameters")
    func testSample_AcceptsCustomParameters() {
        // Act
        let comment = RecipeComment.sample(
            text: "Custom text",
            source: .user,
            commentType: .tip
        )

        // Assert
        #expect(comment.text == "Custom text")
        #expect(comment.source == .user)
        #expect(comment.commentType == .tip)
    }

    // MARK: - Recipe Relationship Tests

    @Test("RecipeComment can be associated with recipe")
    func testRecipe_CanBeAssociated() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        context.insert(recipe)

        let comment = RecipeComment(text: "Great!", recipe: recipe)
        context.insert(comment)

        // Assert
        #expect(comment.recipe?.id == recipe.id)
    }

    // MARK: - Date Display Tests

    @Test("RecipeComment displayDate formats relative time")
    func testDisplayDate_FormatsRelativeTime() {
        // Arrange
        let comment = RecipeComment(text: "Comment")
        let pastDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        comment.createdAt = pastDate

        // Act
        let display = comment.displayDate

        // Assert - Should contain some time indicator
        #expect(display.count > 0)
    }

    @Test("RecipeComment displayDate uses original date when available")
    func testDisplayDate_UsesOriginalDate() {
        // Arrange
        let comment = RecipeComment(text: "Comment")
        let originalDate = Date(timeIntervalSinceNow: -86400) // 1 day ago
        comment.originalDate = originalDate

        // Act
        let display = comment.displayDate

        // Assert
        #expect(display.count > 0)
    }
}
