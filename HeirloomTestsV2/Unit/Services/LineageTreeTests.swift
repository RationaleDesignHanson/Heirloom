//
//  LineageTreeTests.swift
//  HeirloomTestsV2
//
//  Unit tests for LineageTree model: node lookup, tree traversal,
//  statistics, generation badges, contributor info, and
//  RecipeLineageService.createRecipeFromFirebaseData.
//
//  Note: RecipeLineageService.fetchLineageTree requires Firebase and is
//  tested at the integration level. These tests cover the model layer
//  and static helpers that can be tested without Firebase.
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class LineageTreeTests: XCTestCase {

    var env: TestEnvironment!

    override func setUp() async throws {
        env = try await TestEnvironment.create()
    }

    override func tearDown() async throws {
        env?.tearDown()
        env = nil
    }

    // MARK: - Helpers

    /// Create a simple lineage tree for testing:
    /// Gen 0: root
    /// Gen 1: child1, child2
    /// Gen 2: grandchild (child of child1)
    private func createTestTree() -> LineageTree {
        let root = env.createTestRecipe(title: "Original Bolognese")
        let child1 = env.createTestRecipe(title: "Spicy Bolognese")
        let child2 = env.createTestRecipe(title: "Quick Bolognese")
        let grandchild = env.createTestRecipe(title: "Smoky Bolognese")

        let nodes = [
            LineageNode(recipe: root, generation: 0, position: .zero,
                       stats: NodeStats(cookCount: 10, shareCount: 3, viewCount: 50, rating: nil),
                       isCurrentUser: true, contributor: nil),
            LineageNode(recipe: child1, generation: 1, position: .zero,
                       stats: NodeStats(cookCount: 5, shareCount: 2, viewCount: 20, rating: nil),
                       isCurrentUser: false,
                       contributor: ContributorInfo(userId: "maria", displayName: "Maria Santos", avatarURL: nil, isConnected: true)),
            LineageNode(recipe: child2, generation: 1, position: .zero,
                       stats: NodeStats(cookCount: 8, shareCount: 1, viewCount: 30, rating: nil),
                       isCurrentUser: false,
                       contributor: ContributorInfo(userId: "phil", displayName: "Phillip Fry", avatarURL: nil, isConnected: false)),
            LineageNode(recipe: grandchild, generation: 2, position: .zero,
                       stats: NodeStats(cookCount: 3, shareCount: 0, viewCount: 10, rating: nil),
                       isCurrentUser: false, contributor: nil)
        ]

        let edges = [
            LineageEdge(fromID: root.id, toID: child1.id, label: nil, createdAt: Date()),
            LineageEdge(fromID: root.id, toID: child2.id, label: nil, createdAt: Date()),
            LineageEdge(fromID: child1.id, toID: grandchild.id, label: nil, createdAt: Date())
        ]

        return LineageTree(root: root, nodes: nodes, edges: edges)
    }

    // MARK: - Tree Structure

    func test_tree_maxGeneration() {
        let tree = createTestTree()
        XCTAssertEqual(tree.maxGeneration, 2)
    }

    func test_tree_nodeCount() {
        let tree = createTestTree()
        XCTAssertEqual(tree.nodes.count, 4)
    }

    func test_tree_edgeCount() {
        let tree = createTestTree()
        XCTAssertEqual(tree.edges.count, 3)
    }

    // MARK: - Node Lookup

    func test_node_findByRecipeID() {
        let tree = createTestTree()
        let rootNode = tree.node(for: tree.root.id)
        XCTAssertNotNil(rootNode)
        XCTAssertEqual(rootNode?.recipe.title, "Original Bolognese")
    }

    func test_node_findByRecipeID_notFound() {
        let tree = createTestTree()
        let node = tree.node(for: UUID())
        XCTAssertNil(node)
    }

    // MARK: - Tree Traversal

    func test_children_ofRoot_returnsBoth() {
        let tree = createTestTree()
        let children = tree.children(of: tree.root.id)
        XCTAssertEqual(children.count, 2)
    }

    func test_children_ofLeaf_returnsEmpty() {
        let tree = createTestTree()
        // Find "Quick Bolognese" (leaf node)
        let leaf = tree.nodes.first(where: { $0.recipe.title == "Quick Bolognese" })!
        let children = tree.children(of: leaf.recipe.id)
        XCTAssertEqual(children.count, 0)
    }

    func test_parent_ofChild_returnsRoot() {
        let tree = createTestTree()
        let child = tree.nodes.first(where: { $0.recipe.title == "Spicy Bolognese" })!
        let parent = tree.parent(of: child.recipe.id)
        XCTAssertNotNil(parent)
        XCTAssertEqual(parent?.recipe.title, "Original Bolognese")
    }

    func test_parent_ofRoot_returnsNil() {
        let tree = createTestTree()
        let parent = tree.parent(of: tree.root.id)
        XCTAssertNil(parent)
    }

    func test_siblings_ofChild_returnsOtherChild() {
        let tree = createTestTree()
        let child1 = tree.nodes.first(where: { $0.recipe.title == "Spicy Bolognese" })!
        let siblings = tree.siblings(of: child1.recipe.id)
        XCTAssertEqual(siblings.count, 1)
        XCTAssertEqual(siblings.first?.recipe.title, "Quick Bolognese")
    }

    func test_siblings_ofOnlyChild_returnsEmpty() {
        let tree = createTestTree()
        let grandchild = tree.nodes.first(where: { $0.recipe.title == "Smoky Bolognese" })!
        let siblings = tree.siblings(of: grandchild.recipe.id)
        XCTAssertEqual(siblings.count, 0)
    }

    // MARK: - Tree Stats

    func test_stats_totalNodes() {
        let tree = createTestTree()
        XCTAssertEqual(tree.stats.totalNodes, 4)
    }

    func test_stats_totalCooks() {
        let tree = createTestTree()
        // 10 + 5 + 8 + 3 = 26
        XCTAssertEqual(tree.stats.totalCooks, 26)
    }

    func test_stats_totalShares() {
        let tree = createTestTree()
        // 3 + 2 + 1 + 0 = 6
        XCTAssertEqual(tree.stats.totalShares, 6)
    }

    func test_stats_totalGenerations() {
        let tree = createTestTree()
        XCTAssertEqual(tree.stats.totalGenerations, 2)
    }

    func test_stats_displaySummary() {
        let tree = createTestTree()
        let summary = tree.stats.displaySummary
        XCTAssertTrue(summary.contains("4 versions"))
        XCTAssertTrue(summary.contains("2 generations"))
        XCTAssertTrue(summary.contains("26 total cooks"))
    }

    // MARK: - NodeStats

    func test_nodeStats_popularityScore() {
        // Formula: cookCount * 20 + shareCount * 10 + viewCount
        let stats = NodeStats(cookCount: 10, shareCount: 3, viewCount: 50, rating: nil)
        // 10*20 + 3*10 + 50 = 200 + 30 + 50 = 280
        XCTAssertEqual(stats.popularityScore, 280)
    }

    func test_nodeStats_displayStats_withActivity() {
        let stats = NodeStats(cookCount: 5, shareCount: 2, viewCount: 0, rating: nil)
        XCTAssertEqual(stats.displayStats, "5 cooks \u{2022} 2 shares")
    }

    func test_nodeStats_displayStats_noActivity() {
        let stats = NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil)
        XCTAssertEqual(stats.displayStats, "No activity yet")
    }

    // MARK: - LineageNode

    func test_lineageNode_generationBadge_original() {
        let recipe = env.createTestRecipe(title: "Test")
        let node = LineageNode(recipe: recipe, generation: 0, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: true, contributor: nil)
        XCTAssertEqual(node.generationBadge, "Original")
    }

    func test_lineageNode_generationBadge_first() {
        let recipe = env.createTestRecipe(title: "Test")
        let node = LineageNode(recipe: recipe, generation: 1, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: false, contributor: nil)
        XCTAssertEqual(node.generationBadge, "1st Gen")
    }

    func test_lineageNode_generationBadge_second() {
        let recipe = env.createTestRecipe(title: "Test")
        let node = LineageNode(recipe: recipe, generation: 2, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: false, contributor: nil)
        XCTAssertEqual(node.generationBadge, "2nd Gen")
    }

    func test_lineageNode_generationBadge_third() {
        let recipe = env.createTestRecipe(title: "Test")
        let node = LineageNode(recipe: recipe, generation: 3, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: false, contributor: nil)
        XCTAssertEqual(node.generationBadge, "3rd Gen")
    }

    func test_lineageNode_generationBadge_higher() {
        let recipe = env.createTestRecipe(title: "Test")
        let node = LineageNode(recipe: recipe, generation: 5, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: false, contributor: nil)
        XCTAssertEqual(node.generationBadge, "5th Gen")
    }

    func test_lineageNode_displayLabel() {
        let recipe = env.createTestRecipe(title: "Grandma's Pasta")
        let node = LineageNode(recipe: recipe, generation: 0, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: true, contributor: nil)
        XCTAssertEqual(node.displayLabel, "Grandma's Pasta")
    }

    // MARK: - ContributorInfo

    func test_contributorInfo_initials_twoNames() {
        let info = ContributorInfo(userId: "id", displayName: "Maria Santos", avatarURL: nil, isConnected: true)
        XCTAssertEqual(info.initials, "MS")
    }

    func test_contributorInfo_initials_singleName() {
        let info = ContributorInfo(userId: "id", displayName: "Grandmazing", avatarURL: nil, isConnected: false)
        XCTAssertEqual(info.initials, "G")
    }

    func test_contributorInfo_initials_threeName() {
        let info = ContributorInfo(userId: "id", displayName: "Mary Jane Watson", avatarURL: nil, isConnected: true)
        XCTAssertEqual(info.initials, "MW")
    }

    func test_contributorInfo_legacy_hasNoAccount() {
        let info = ContributorInfo(displayName: "Grandma")
        XCTAssertFalse(info.hasAccount)
        XCTAssertEqual(info.userId, "")
        XCTAssertFalse(info.isConnected)
    }

    func test_contributorInfo_regular_hasAccount() {
        let info = ContributorInfo(userId: "user123", displayName: "Chef Bob", avatarURL: nil, isConnected: true)
        XCTAssertTrue(info.hasAccount)
        XCTAssertTrue(info.isConnected)
    }

    // MARK: - LineageEdge

    func test_edgeType_default_isForked() {
        let edge = LineageEdge(fromID: UUID(), toID: UUID(), label: nil, createdAt: Date())
        XCTAssertEqual(edge.edgeType, .forked)
    }

    func test_edgeType_adapted() {
        let edge = LineageEdge(fromID: UUID(), toID: UUID(), label: "Adapted for slow cooker", createdAt: Date())
        XCTAssertEqual(edge.edgeType, .adapted)
    }

    func test_edgeType_remixed() {
        let edge = LineageEdge(fromID: UUID(), toID: UUID(), label: "Remixed with Asian flavors", createdAt: Date())
        XCTAssertEqual(edge.edgeType, .remixed)
    }

    func test_edgeType_simplified() {
        let edge = LineageEdge(fromID: UUID(), toID: UUID(), label: "Simplified for weeknight cooking", createdAt: Date())
        XCTAssertEqual(edge.edgeType, .simplified)
    }

    // MARK: - createRecipeFromFirebaseData

    func test_createRecipeFromFirebaseData_setsTitle() {
        let data: [String: Any] = [
            "title": "Grandma's Bolognese",
            "instructions": ["Step 1", "Step 2"],
            "sourceType": "manual"
        ]
        let recipeId = UUID()

        let recipe = RecipeLineageService.createRecipeFromFirebaseData(data, recipeId: recipeId)

        XCTAssertEqual(recipe.title, "Grandma's Bolognese")
        XCTAssertEqual(recipe.id, recipeId)
    }

    func test_createRecipeFromFirebaseData_setsInstructions() {
        let data: [String: Any] = [
            "title": "Test",
            "instructions": ["Boil water", "Add pasta", "Drain"],
            "sourceType": "manual"
        ]

        let recipe = RecipeLineageService.createRecipeFromFirebaseData(data, recipeId: UUID())

        XCTAssertEqual(recipe.instructions, ["Boil water", "Add pasta", "Drain"])
    }

    func test_createRecipeFromFirebaseData_setsOptionalFields() {
        let data: [String: Any] = [
            "title": "Test",
            "instructions": [],
            "servings": "4 servings",
            "prepTime": "15 min",
            "cookTime": "30 min",
            "notes": "Best served warm",
            "sourceType": "url",
            "sourceURL": "https://example.com/recipe",
            "timesCooked": 5
        ]

        let recipe = RecipeLineageService.createRecipeFromFirebaseData(data, recipeId: UUID())

        XCTAssertEqual(recipe.servings, "4 servings")
        XCTAssertEqual(recipe.prepTime, "15 min")
        XCTAssertEqual(recipe.cookTime, "30 min")
        XCTAssertEqual(recipe.notes, "Best served warm")
        XCTAssertEqual(recipe.timesCooked, 5)
    }

    func test_createRecipeFromFirebaseData_defaultsUnknownTitle() {
        let data: [String: Any] = [
            "instructions": []
        ]

        let recipe = RecipeLineageService.createRecipeFromFirebaseData(data, recipeId: UUID())

        XCTAssertEqual(recipe.title, "Unknown")
    }

    func test_createRecipeFromFirebaseData_setsImageFields() {
        let data: [String: Any] = [
            "title": "Test",
            "instructions": [],
            "imageFileName": "recipe_123.jpg",
            "firebaseImageURL": "https://storage.example.com/recipe_123.jpg"
        ]

        let recipe = RecipeLineageService.createRecipeFromFirebaseData(data, recipeId: UUID())

        XCTAssertEqual(recipe.imageFileName, "recipe_123.jpg")
        XCTAssertEqual(recipe.firebaseImageURL, "https://storage.example.com/recipe_123.jpg")
    }

    // MARK: - Single Node Tree

    func test_singleNodeTree_maxGeneration_isZero() {
        let recipe = env.createTestRecipe(title: "Standalone")
        let node = LineageNode(recipe: recipe, generation: 0, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: true, contributor: nil)
        let tree = LineageTree(root: recipe, nodes: [node], edges: [])

        XCTAssertEqual(tree.maxGeneration, 0)
        XCTAssertEqual(tree.stats.totalNodes, 1)
        XCTAssertEqual(tree.children(of: recipe.id).count, 0)
        XCTAssertNil(tree.parent(of: recipe.id))
    }
}
