import Foundation
import SwiftData

/// Service for managing recipe comments - CRUD operations, threading, and persistence
@MainActor
final class CommentService {
    // MARK: - Dependencies

    private let firebaseSync: FirebaseSyncService
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

    // MARK: - Initialization

    init(firebaseSync: FirebaseSyncService) {
        self.firebaseSync = firebaseSync
    }

    // MARK: - Create

    /// Add a comment to a recipe
    func addComment(
        to recipe: Recipe,
        text: String,
        authorName: String? = nil,
        source: CommentSource = .user,
        commentType: CommentType = .general,
        parentComment: RecipeComment? = nil,
        context: ModelContext
    ) throws -> RecipeComment {
        let comment = RecipeComment(
            text: text,
            authorName: authorName,
            source: source,
            commentType: commentType,
            recipe: recipe,
            parentComment: parentComment
        )

        context.insert(comment)

        // Add to recipe's comments array
        if recipe.comments == nil {
            recipe.comments = []
        }
        recipe.comments?.append(comment)

        // If this is a reply, add to parent's replies
        if let parent = parentComment {
            if parent.replies == nil {
                parent.replies = []
            }
            parent.replies?.append(comment)
        }

        try context.save()

        // Sync to Firebase if active
        if backendConfig.isFirebaseActive {
            Task {
                do {
                    try await firebaseSync.uploadComment(comment, recipeId: recipe.id)
                    Log.info("Comment synced to Firebase", category: .firebase)
                } catch {
                    Log.warning("Failed to sync comment to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                }
            }
        }

        return comment
    }

    /// Batch import comments (for scraped comments from websites)
    func importComments(
        _ commentTexts: [String],
        to recipe: Recipe,
        source: CommentSource = .scraped,
        context: ModelContext
    ) throws -> [RecipeComment] {
        var importedComments: [RecipeComment] = []

        for text in commentTexts {
            let comment = RecipeComment(
                text: text,
                source: source,
                commentType: .general,
                recipe: recipe
            )

            context.insert(comment)
            importedComments.append(comment)

            if recipe.comments == nil {
                recipe.comments = []
            }
            recipe.comments?.append(comment)
        }

        try context.save()

        // Sync imported comments to Firebase if active
        if backendConfig.isFirebaseActive {
            Task {
                for comment in importedComments {
                    do {
                        try await firebaseSync.uploadComment(comment, recipeId: recipe.id)
                    } catch {
                        Log.warning("Failed to sync imported comment to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                    }
                }
                Log.info("Imported comments synced to Firebase", category: .firebase, metadata: ["count": importedComments.count])
            }
        }

        return importedComments
    }

    // MARK: - Read

    /// Get all top-level comments for a recipe (no parent)
    func getTopLevelComments(for recipe: Recipe) -> [RecipeComment] {
        recipe.comments?.filter { $0.isTopLevel } ?? []
    }

    /// Get comments sorted by vote score
    func getTopComments(
        for recipe: Recipe,
        limit: Int = 5
    ) -> [RecipeComment] {
        let comments = recipe.comments ?? []
        return comments
            .filter { !$0.isHidden }
            .sorted { $0.voteScore > $1.voteScore }
            .prefix(limit)
            .map { $0 }
    }

    /// Get pinned comments
    func getPinnedComments(for recipe: Recipe) -> [RecipeComment] {
        recipe.comments?.filter { $0.isPinned } ?? []
    }

    /// Get comments by type
    func getComments(
        for recipe: Recipe,
        ofType type: CommentType
    ) -> [RecipeComment] {
        recipe.comments?.filter { $0.commentType == type } ?? []
    }

    /// Get high engagement comments (lots of upvotes)
    func getHighEngagementComments(for recipe: Recipe) -> [RecipeComment] {
        recipe.comments?.filter { $0.isHighEngagement } ?? []
    }

    /// Get positive comments (based on sentiment)
    func getPositiveComments(for recipe: Recipe) -> [RecipeComment] {
        recipe.comments?.filter { $0.isPositive } ?? []
    }

    /// Search comments by text
    func searchComments(
        for recipe: Recipe,
        query: String
    ) -> [RecipeComment] {
        let lowercasedQuery = query.lowercased()
        return recipe.comments?.filter {
            $0.text.lowercased().contains(lowercasedQuery) ||
            $0.topics.contains { $0.lowercased().contains(lowercasedQuery) }
        } ?? []
    }

    // MARK: - Update

    /// Update comment text
    func updateComment(
        _ comment: RecipeComment,
        text: String,
        context: ModelContext
    ) throws {
        comment.text = text
        comment.modifiedAt = Date()
        try context.save()

        // Sync updated comment to Firebase if active
        if backendConfig.isFirebaseActive, let recipeId = comment.recipe?.id {
            Task {
                do {
                    try await firebaseSync.uploadComment(comment, recipeId: recipeId)
                    Log.info("Updated comment synced to Firebase", category: .firebase)
                } catch {
                    Log.warning("Failed to sync updated comment to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                }
            }
        }
    }

    /// Vote on a comment
    func upvoteComment(_ comment: RecipeComment, context: ModelContext) throws {
        comment.upvotes += 1
        try context.save()

        // Sync updated vote count to Firebase if active
        if backendConfig.isFirebaseActive, let recipeId = comment.recipe?.id {
            Task {
                do {
                    try await firebaseSync.uploadComment(comment, recipeId: recipeId)
                    Log.info("Comment upvote synced to Firebase", category: .firebase)
                } catch {
                    Log.warning("Failed to sync upvote to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                }
            }
        }
    }

    func downvoteComment(_ comment: RecipeComment, context: ModelContext) throws {
        comment.downvotes += 1
        try context.save()

        // Sync updated vote count to Firebase if active
        if backendConfig.isFirebaseActive, let recipeId = comment.recipe?.id {
            Task {
                do {
                    try await firebaseSync.uploadComment(comment, recipeId: recipeId)
                    Log.info("Comment downvote synced to Firebase", category: .firebase)
                } catch {
                    Log.warning("Failed to sync downvote to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                }
            }
        }
    }

    /// Toggle pin status
    func togglePin(_ comment: RecipeComment, context: ModelContext) throws {
        comment.isPinned.toggle()
        try context.save()
    }

    /// Toggle favorite status
    func toggleFavorite(_ comment: RecipeComment, context: ModelContext) throws {
        comment.isFavorite.toggle()
        try context.save()
    }

    /// Toggle card back visibility
    func toggleCardBackVisibility(
        _ comment: RecipeComment,
        context: ModelContext
    ) throws {
        comment.showOnCardBack.toggle()

        // If showing on card back, also pin it
        if comment.showOnCardBack {
            comment.isPinned = true
        }

        try context.save()
    }

    /// Update sentiment score (typically done by CommentAnalysisService)
    func updateSentiment(
        for comment: RecipeComment,
        score: Double,
        confidence: Double,
        topics: [String],
        context: ModelContext
    ) throws {
        comment.sentimentScore = score
        comment.analysisConfidence = confidence
        comment.topics = topics
        try context.save()
    }

    /// Update comment type classification
    func updateCommentType(
        _ comment: RecipeComment,
        type: CommentType,
        context: ModelContext
    ) throws {
        comment.commentType = type
        try context.save()
    }

    // MARK: - Delete

    /// Delete a comment (and all replies if top-level)
    func deleteComment(_ comment: RecipeComment, context: ModelContext) throws {
        let commentId = comment.id
        let recipeId = comment.recipe?.id

        context.delete(comment)
        try context.save()

        // Delete from Firebase if active
        if backendConfig.isFirebaseActive, let recipeId = recipeId {
            Task {
                do {
                    try await firebaseSync.deleteComment(commentId, from: recipeId)
                    Log.info("Comment deleted from Firebase", category: .firebase)
                } catch {
                    Log.warning("Failed to delete comment from Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                }
            }
        }
    }

    /// Delete all comments for a recipe
    func deleteAllComments(for recipe: Recipe, context: ModelContext) throws {
        guard let comments = recipe.comments else { return }

        let commentIds = comments.map { $0.id }
        let recipeId = recipe.id

        for comment in comments {
            context.delete(comment)
        }

        recipe.comments = []
        try context.save()

        // Delete all comments from Firebase if active
        if backendConfig.isFirebaseActive {
            Task {
                for commentId in commentIds {
                    do {
                        try await firebaseSync.deleteComment(commentId, from: recipeId)
                    } catch {
                        Log.warning("Failed to delete comment from Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                    }
                }
                Log.info("All comments deleted from Firebase", category: .firebase, metadata: ["count": commentIds.count])
            }
        }
    }

    /// Hide comment (soft delete)
    func hideComment(
        _ comment: RecipeComment,
        reason: String?,
        context: ModelContext
    ) throws {
        comment.isHidden = true
        comment.moderationNote = reason
        try context.save()
    }

    /// Flag comment for review
    func flagComment(
        _ comment: RecipeComment,
        reason: String?,
        context: ModelContext
    ) throws {
        comment.isFlagged = true
        comment.moderationNote = reason
        try context.save()
    }

    // MARK: - Shared Comments (Phase 2C)

    /// Get comments by scope
    func getComments(
        for recipe: Recipe,
        scope: CommentScope
    ) -> [RecipeComment] {
        recipe.comments?.filter { $0.shareScope == scope } ?? []
    }

    /// Get comments visible to lineage (non-private)
    func getLineageVisibleComments(for recipe: Recipe) -> [RecipeComment] {
        recipe.comments?.filter { $0.isVisibleToLineage } ?? []
    }

    /// Get comments from other recipe copies in lineage
    func getLineageComments(for recipe: Recipe) -> [RecipeComment] {
        recipe.comments?.filter { $0.isFromLineage } ?? []
    }

    /// Endorse a comment (for lineage comments)
    func endorseComment(_ comment: RecipeComment, context: ModelContext) async throws {
        // Update local endorsement count
        comment.endorsementCount += 1
        try context.save()

        // TODO: Sync to CloudKit if comment is shared
        // if comment.isVisibleToLineage {
        //     try await SharedCommentService.shared.updateEndorsement(
        //         for: comment.id,
        //         increment: true
        //     )
        // }
    }

    /// Remove endorsement from comment
    func unendorseComment(_ comment: RecipeComment, context: ModelContext) async throws {
        // Update local endorsement count
        comment.endorsementCount = max(0, comment.endorsementCount - 1)
        try context.save()

        // TODO: Sync to CloudKit if comment is shared
        // if comment.isVisibleToLineage {
        //     try await SharedCommentService.shared.updateEndorsement(
        //         for: comment.id,
        //         increment: false
        //     )
        // }
    }

    /// Update comment scope
    func updateCommentScope(
        _ comment: RecipeComment,
        scope: CommentScope,
        recipe: Recipe,
        context: ModelContext
    ) async throws {
        _ = comment.shareScope // Store old scope for potential future use
        comment.shareScope = scope

        // Set origin provenance hash if not already set
        if comment.originProvenanceHash == nil {
            comment.originProvenanceHash = recipe.provenance?.rootProvenanceHash
        }

        try context.save()

        // TODO: Share to CloudKit if changing from private to shared
        // if oldScope == CommentScope.private && scope != CommentScope.private {
        //     try await SharedCommentService.shared.shareComment(comment, from: recipe)
        // }
    }

    // MARK: - Statistics

    /// Get comment statistics for a recipe
    func getStatistics(for recipe: Recipe) -> CommentStatistics {
        let comments = recipe.comments ?? []

        let total = comments.count
        let topLevel = comments.filter { $0.isTopLevel }.count
        let replies = comments.filter { !$0.isTopLevel }.count
        let pinned = comments.filter { $0.isPinned }.count
        let scraped = comments.filter { $0.source == .scraped }.count
        let user = comments.filter { $0.source == .user }.count

        let avgSentiment = comments.compactMap { $0.sentimentScore }.average()
        let totalUpvotes = comments.map { $0.upvotes }.reduce(0, +)
        let totalDownvotes = comments.map { $0.downvotes }.reduce(0, +)

        // Count by type
        var typeBreakdown: [CommentType: Int] = [:]
        for comment in comments {
            typeBreakdown[comment.commentType, default: 0] += 1
        }

        return CommentStatistics(
            totalComments: total,
            topLevelComments: topLevel,
            replies: replies,
            pinnedComments: pinned,
            scrapedComments: scraped,
            userComments: user,
            averageSentiment: avgSentiment,
            totalUpvotes: totalUpvotes,
            totalDownvotes: totalDownvotes,
            commentsByType: typeBreakdown
        )
    }
}

// MARK: - Supporting Types

struct CommentStatistics {
    let totalComments: Int
    let topLevelComments: Int
    let replies: Int
    let pinnedComments: Int
    let scrapedComments: Int
    let userComments: Int
    let averageSentiment: Double?
    let totalUpvotes: Int
    let totalDownvotes: Int
    let commentsByType: [CommentType: Int]

    var hasComments: Bool {
        totalComments > 0
    }

    var engagementRate: Double {
        guard totalComments > 0 else { return 0 }
        return Double(totalUpvotes + totalDownvotes) / Double(totalComments)
    }

    var positivityRate: Double? {
        guard let sentiment = averageSentiment else { return nil }
        return (sentiment + 1.0) / 2.0 // Convert -1...1 to 0...1
    }
}

// MARK: - Array Extension

private extension Array where Element == Double {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
