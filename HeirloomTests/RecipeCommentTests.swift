import XCTest
import SwiftData
@testable import Heirloom

/// Unit tests for RecipeComment model and threading behavior
@MainActor
final class RecipeCommentTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        modelContainer = try TestFixtures.createTestContainer()
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Comment Creation Tests

    func testCreateTopLevelComment() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let comment = RecipeComment(
            text: "This is a great recipe!",
            authorName: "Test User",
            recipe: recipe
        )
        modelContext.insert(comment)

        try modelContext.save()

        XCTAssertNotNil(comment.id)
        XCTAssertEqual(comment.text, "This is a great recipe!")
        XCTAssertEqual(comment.authorName, "Test User")
        XCTAssertNil(comment.parentComment, "Top-level comment should have no parent")
        XCTAssertEqual(comment.replies?.count ?? 0, 0, "New comment should have no replies")
    }

    func testCreateReplyComment() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let parentComment = RecipeComment(
            text: "Parent comment",
            authorName: "User 1",
            recipe: recipe
        )
        modelContext.insert(parentComment)

        let replyComment = RecipeComment(
            text: "Reply to parent",
            authorName: "User 2",
            recipe: recipe,
            parentComment: parentComment
        )
        modelContext.insert(replyComment)

        try modelContext.save()

        // Verify parent-child relationship
        XCTAssertNotNil(replyComment.parentComment)
        XCTAssertEqual(replyComment.parentComment?.id, parentComment.id)
        XCTAssertEqual(parentComment.replies?.count, 1)
        XCTAssertEqual(parentComment.replies?.first?.id, replyComment.id)
    }

    func testMultipleReplies() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let parentComment = RecipeComment(
            text: "Parent comment",
            authorName: "User 1",
            recipe: recipe
        )
        modelContext.insert(parentComment)

        // Create 3 replies
        for i in 1...3 {
            let reply = RecipeComment(
                text: "Reply \(i)",
                authorName: "User \(i+1)",
                recipe: recipe,
                parentComment: parentComment
            )
            modelContext.insert(reply)
        }

        try modelContext.save()

        XCTAssertEqual(parentComment.replies?.count, 3)
    }

    func testNestedReplies() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        // Level 1: Top-level comment
        let level1 = RecipeComment(text: "Level 1", authorName: "User 1", recipe: recipe)
        modelContext.insert(level1)

        // Level 2: Reply to level 1
        let level2 = RecipeComment(text: "Level 2", authorName: "User 2", recipe: recipe, parentComment: level1)
        modelContext.insert(level2)

        // Level 3: Reply to level 2
        let level3 = RecipeComment(text: "Level 3", authorName: "User 3", recipe: recipe, parentComment: level2)
        modelContext.insert(level3)

        try modelContext.save()

        // Verify nesting
        XCTAssertNil(level1.parentComment)
        XCTAssertEqual(level1.replies?.count, 1)
        XCTAssertEqual(level2.parentComment?.id, level1.id)
        XCTAssertEqual(level2.replies?.count, 1)
        XCTAssertEqual(level3.parentComment?.id, level2.id)
        XCTAssertEqual(level3.replies?.count ?? 0, 0)
    }

    // MARK: - Cascade Delete Tests

    func testCascadeDeleteTopLevelComment() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let comment = RecipeComment(text: "Test comment", authorName: "User", recipe: recipe)
        modelContext.insert(comment)

        let commentID = comment.id
        try modelContext.save()

        // Delete comment
        modelContext.delete(comment)
        try modelContext.save()

        // Verify deletion
        let fetchDescriptor = FetchDescriptor<RecipeComment>(
            predicate: #Predicate { $0.id == commentID }
        )
        let results = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(results.count, 0)
    }

    func testCascadeDeleteWithReplies() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let parentComment = RecipeComment(text: "Parent", authorName: "User 1", recipe: recipe)
        modelContext.insert(parentComment)

        let reply1 = RecipeComment(text: "Reply 1", authorName: "User 2", recipe: recipe, parentComment: parentComment)
        modelContext.insert(reply1)

        let reply2 = RecipeComment(text: "Reply 2", authorName: "User 3", recipe: recipe, parentComment: parentComment)
        modelContext.insert(reply2)

        let parentID = parentComment.id
        let reply1ID = reply1.id
        let reply2ID = reply2.id

        try modelContext.save()

        // Delete parent - should cascade to replies
        modelContext.delete(parentComment)
        try modelContext.save()

        // Verify parent deleted
        let parentFetch = FetchDescriptor<RecipeComment>(
            predicate: #Predicate { $0.id == parentID }
        )
        XCTAssertEqual(try modelContext.fetch(parentFetch).count, 0)

        // Verify replies deleted (cascade)
        let reply1Fetch = FetchDescriptor<RecipeComment>(
            predicate: #Predicate { $0.id == reply1ID }
        )
        XCTAssertEqual(try modelContext.fetch(reply1Fetch).count, 0)

        let reply2Fetch = FetchDescriptor<RecipeComment>(
            predicate: #Predicate { $0.id == reply2ID }
        )
        XCTAssertEqual(try modelContext.fetch(reply2Fetch).count, 0)
    }

    func testCascadeDeleteNestedReplies() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let level1 = RecipeComment(text: "Level 1", authorName: "User 1", recipe: recipe)
        modelContext.insert(level1)

        let level2 = RecipeComment(text: "Level 2", authorName: "User 2", recipe: recipe, parentComment: level1)
        modelContext.insert(level2)

        let level3 = RecipeComment(text: "Level 3", authorName: "User 3", recipe: recipe, parentComment: level2)
        modelContext.insert(level3)

        let level1ID = level1.id
        let level2ID = level2.id
        let level3ID = level3.id

        try modelContext.save()

        // Delete top-level comment - should cascade to all descendants
        modelContext.delete(level1)
        try modelContext.save()

        // Verify all deleted
        let fetchAll = FetchDescriptor<RecipeComment>(
            predicate: #Predicate { comment in
                comment.id == level1ID || comment.id == level2ID || comment.id == level3ID
            }
        )
        XCTAssertEqual(try modelContext.fetch(fetchAll).count, 0)
    }

    // MARK: - Comment Source Tests

    func testCommentSourceDefault() throws {
        let comment = RecipeComment(text: "Test", authorName: "User")
        XCTAssertEqual(comment.source, .user)
    }

    func testCommentSourceScraped() throws {
        let comment = RecipeComment(text: "Scraped comment", authorName: "Web User")
        comment.source = .scraped
        comment.sourceURL = "https://example.com/recipe"
        comment.originalDate = Date(timeIntervalSince1970: 1609459200) // Jan 1, 2021

        XCTAssertEqual(comment.source, .scraped)
        XCTAssertEqual(comment.sourceURL, "https://example.com/recipe")
        XCTAssertNotNil(comment.originalDate)
    }

    // MARK: - Timestamp Tests

    func testCommentTimestamps() throws {
        let comment = RecipeComment(text: "Test", authorName: "User")

        XCTAssertNotNil(comment.createdAt)
        XCTAssertNil(comment.modifiedAt)

        // Simulate modification
        let modDate = Date()
        comment.modifiedAt = modDate

        XCTAssertEqual(comment.modifiedAt, modDate)
    }

    // MARK: - Comment Thread Queries

    func testFetchTopLevelComments() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        // Create top-level comments
        for i in 1...3 {
            let comment = RecipeComment(text: "Comment \(i)", authorName: "User \(i)", recipe: recipe)
            modelContext.insert(comment)
        }

        // Create reply (not top-level)
        let parent = RecipeComment(text: "Parent", authorName: "Parent User", recipe: recipe)
        modelContext.insert(parent)

        let reply = RecipeComment(text: "Reply", authorName: "Reply User", recipe: recipe, parentComment: parent)
        modelContext.insert(reply)

        try modelContext.save()

        // Fetch only top-level comments (parentComment == nil)
        let topLevelFetch = FetchDescriptor<RecipeComment>(
            predicate: #Predicate { $0.parentComment == nil }
        )
        let topLevelComments = try modelContext.fetch(topLevelFetch)

        XCTAssertEqual(topLevelComments.count, 4) // 3 + parent (not the reply)
    }

    func testFetchRepliesForComment() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let parentComment = RecipeComment(text: "Parent", authorName: "User 1", recipe: recipe)
        modelContext.insert(parentComment)

        let parentID = parentComment.id

        // Create multiple replies
        for i in 1...5 {
            let reply = RecipeComment(text: "Reply \(i)", authorName: "User \(i+1)", recipe: recipe, parentComment: parentComment)
            modelContext.insert(reply)
        }

        try modelContext.save()

        // Fetch replies for specific parent
        let repliesFetch = FetchDescriptor<RecipeComment>(
            predicate: #Predicate { $0.parentComment?.id == parentID }
        )
        let replies = try modelContext.fetch(repliesFetch)

        XCTAssertEqual(replies.count, 5)
    }

    // MARK: - Bidirectional Relationship Tests

    func testBidirectionalRelationshipIntegrity() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let parent = RecipeComment(text: "Parent", authorName: "User 1", recipe: recipe)
        modelContext.insert(parent)

        let child = RecipeComment(text: "Child", authorName: "User 2", recipe: recipe, parentComment: parent)
        modelContext.insert(child)

        try modelContext.save()

        // Verify bidirectional relationship
        XCTAssertNotNil(child.parentComment)
        XCTAssertEqual(child.parentComment?.id, parent.id)

        XCTAssertNotNil(parent.replies)
        XCTAssertEqual(parent.replies?.count, 1)
        XCTAssertEqual(parent.replies?.first?.id, child.id)

        // Verify parent from child matches
        XCTAssertEqual(child.parentComment?.text, "Parent")

        // Verify child from parent matches
        XCTAssertEqual(parent.replies?.first?.text, "Child")
    }

    func testRemoveReplyUpdatesParent() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let parent = RecipeComment(text: "Parent", authorName: "User 1", recipe: recipe)
        modelContext.insert(parent)

        let child = RecipeComment(text: "Child", authorName: "User 2", recipe: recipe, parentComment: parent)
        modelContext.insert(child)

        try modelContext.save()

        XCTAssertEqual(parent.replies?.count, 1)

        // Delete child
        modelContext.delete(child)
        try modelContext.save()

        // Parent should have no replies
        XCTAssertEqual(parent.replies?.count ?? 0, 0)
    }
}
