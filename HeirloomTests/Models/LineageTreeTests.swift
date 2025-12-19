import XCTest
@testable import Heirloom
import SwiftUI

final class LineageTreeTests: XCTestCase {

    // MARK: - Setup Helpers

    private func createSampleRecipe(title: String, generation: Int) -> Recipe {
        let recipe = Recipe(title: title, sourceType: .manual)
        recipe.provenance = ProvenanceMetadata(
            sourceType: generation == 0 ? .userCreated : .shared,
            generation: generation
        )
        return recipe
    }

    private func createSampleTree() -> LineageTree {
        let root = createSampleRecipe(title: "Original Recipe", generation: 0)
        let child1 = createSampleRecipe(title: "First Fork", generation: 1)
        let child2 = createSampleRecipe(title: "Second Fork", generation: 1)
        let grandchild = createSampleRecipe(title: "Second Generation", generation: 2)

        let nodes = [
            LineageNode(
                recipe: root,
                generation: 0,
                position: .zero,
                stats: NodeStats(cookCount: 10, shareCount: 5, viewCount: 100, rating: 4.5),
                isCurrentUser: false
            ),
            LineageNode(
                recipe: child1,
                generation: 1,
                position: .zero,
                stats: NodeStats(cookCount: 8, shareCount: 3, viewCount: 50, rating: 4.3),
                isCurrentUser: true
            ),
            LineageNode(
                recipe: child2,
                generation: 1,
                position: .zero,
                stats: NodeStats(cookCount: 6, shareCount: 2, viewCount: 30, rating: 4.0),
                isCurrentUser: false
            ),
            LineageNode(
                recipe: grandchild,
                generation: 2,
                position: .zero,
                stats: NodeStats(cookCount: 4, shareCount: 1, viewCount: 20, rating: 3.8),
                isCurrentUser: false
            )
        ]

        let edges = [
            LineageEdge(fromID: root.id, toID: child1.id, label: "Forked", createdAt: Date()),
            LineageEdge(fromID: root.id, toID: child2.id, label: "Adapted", createdAt: Date()),
            LineageEdge(fromID: child1.id, toID: grandchild.id, label: "Remixed", createdAt: Date())
        ]

        return LineageTree(root: root, nodes: nodes, edges: edges)
    }

    // MARK: - Basic Tree Tests

    func test_lineageTree_initialization() {
        let tree = createSampleTree()

        XCTAssertEqual(tree.nodes.count, 4)
        XCTAssertEqual(tree.edges.count, 3)
        XCTAssertEqual(tree.root.title, "Original Recipe")
    }

    func test_lineageTree_maxGeneration() {
        let tree = createSampleTree()

        XCTAssertEqual(tree.maxGeneration, 2)
    }

    func test_lineageTree_stats() {
        let tree = createSampleTree()
        let stats = tree.stats

        XCTAssertEqual(stats.totalNodes, 4)
        XCTAssertEqual(stats.totalGenerations, 2)
        XCTAssertEqual(stats.totalForks, 3)
        XCTAssertEqual(stats.totalCooks, 28) // 10 + 8 + 6 + 4
        XCTAssertEqual(stats.totalShares, 11) // 5 + 3 + 2 + 1
    }

    // MARK: - Node Lookup Tests

    func test_lineageTree_nodeForRecipeID() {
        let tree = createSampleTree()
        let firstNode = tree.nodes.first!

        let foundNode = tree.node(for: firstNode.recipe.id)

        XCTAssertNotNil(foundNode)
        XCTAssertEqual(foundNode?.recipe.id, firstNode.recipe.id)
    }

    func test_lineageTree_nodeForInvalidID() {
        let tree = createSampleTree()

        let foundNode = tree.node(for: UUID())

        XCTAssertNil(foundNode)
    }

    // MARK: - Children Tests

    func test_lineageTree_childrenOfRoot() {
        let tree = createSampleTree()
        let rootID = tree.root.id

        let children = tree.children(of: rootID)

        XCTAssertEqual(children.count, 2)
        XCTAssertTrue(children.contains { $0.recipe.title == "First Fork" })
        XCTAssertTrue(children.contains { $0.recipe.title == "Second Fork" })
    }

    func test_lineageTree_childrenOfLeafNode() {
        let tree = createSampleTree()
        let leafNode = tree.nodes.last! // "Second Generation"

        let children = tree.children(of: leafNode.recipe.id)

        XCTAssertEqual(children.count, 0)
    }

    func test_lineageTree_childrenOfMiddleNode() {
        let tree = createSampleTree()
        let middleNode = tree.nodes.first { $0.recipe.title == "First Fork" }!

        let children = tree.children(of: middleNode.recipe.id)

        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children.first?.recipe.title, "Second Generation")
    }

    // MARK: - Parent Tests

    func test_lineageTree_parentOfChildNode() {
        let tree = createSampleTree()
        let childNode = tree.nodes.first { $0.recipe.title == "First Fork" }!

        let parent = tree.parent(of: childNode.recipe.id)

        XCTAssertNotNil(parent)
        XCTAssertEqual(parent?.recipe.title, "Original Recipe")
    }

    func test_lineageTree_parentOfRootNode() {
        let tree = createSampleTree()
        let rootID = tree.root.id

        let parent = tree.parent(of: rootID)

        XCTAssertNil(parent)
    }

    func test_lineageTree_parentOfGrandchild() {
        let tree = createSampleTree()
        let grandchild = tree.nodes.first { $0.recipe.title == "Second Generation" }!

        let parent = tree.parent(of: grandchild.recipe.id)

        XCTAssertNotNil(parent)
        XCTAssertEqual(parent?.recipe.title, "First Fork")
    }

    // MARK: - Siblings Tests

    func test_lineageTree_siblingsOfFirstChild() {
        let tree = createSampleTree()
        let firstChild = tree.nodes.first { $0.recipe.title == "First Fork" }!

        let siblings = tree.siblings(of: firstChild.recipe.id)

        XCTAssertEqual(siblings.count, 1)
        XCTAssertEqual(siblings.first?.recipe.title, "Second Fork")
    }

    func test_lineageTree_siblingsOfOnlyChild() {
        let tree = createSampleTree()
        let onlyChild = tree.nodes.first { $0.recipe.title == "Second Generation" }!

        let siblings = tree.siblings(of: onlyChild.recipe.id)

        XCTAssertEqual(siblings.count, 0)
    }

    func test_lineageTree_siblingsOfRootNode() {
        let tree = createSampleTree()
        let rootID = tree.root.id

        let siblings = tree.siblings(of: rootID)

        XCTAssertEqual(siblings.count, 0)
    }

    // MARK: - Node Generation Badge Tests

    func test_lineageNode_generationBadge_original() {
        let recipe = createSampleRecipe(title: "Test", generation: 0)
        let node = LineageNode(recipe: recipe, generation: 0, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: false)

        XCTAssertEqual(node.generationBadge, "Original")
    }

    func test_lineageNode_generationBadge_firstGen() {
        let recipe = createSampleRecipe(title: "Test", generation: 1)
        let node = LineageNode(recipe: recipe, generation: 1, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: false)

        XCTAssertEqual(node.generationBadge, "1st Gen")
    }

    func test_lineageNode_generationBadge_secondGen() {
        let recipe = createSampleRecipe(title: "Test", generation: 2)
        let node = LineageNode(recipe: recipe, generation: 2, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: false)

        XCTAssertEqual(node.generationBadge, "2nd Gen")
    }

    func test_lineageNode_generationBadge_thirdGen() {
        let recipe = createSampleRecipe(title: "Test", generation: 3)
        let node = LineageNode(recipe: recipe, generation: 3, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: false)

        XCTAssertEqual(node.generationBadge, "3rd Gen")
    }

    func test_lineageNode_generationBadge_higherGen() {
        let recipe = createSampleRecipe(title: "Test", generation: 5)
        let node = LineageNode(recipe: recipe, generation: 5, position: .zero,
                              stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                              isCurrentUser: false)

        XCTAssertEqual(node.generationBadge, "5th Gen")
    }

    // MARK: - Node Stats Tests

    func test_nodeStats_popularityScore() {
        let stats = NodeStats(cookCount: 10, shareCount: 5, viewCount: 100, rating: nil)

        // cookCount * 20 + shareCount * 10 + viewCount = 10*20 + 5*10 + 100 = 350
        XCTAssertEqual(stats.popularityScore, 350)
    }

    func test_nodeStats_displayStats_withActivity() {
        let stats = NodeStats(cookCount: 10, shareCount: 5, viewCount: 100, rating: nil)

        let display = stats.displayStats

        XCTAssertTrue(display.contains("10 cooks"))
        XCTAssertTrue(display.contains("5 shares"))
    }

    func test_nodeStats_displayStats_noActivity() {
        let stats = NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil)

        let display = stats.displayStats

        XCTAssertEqual(display, "No activity yet")
    }

    // MARK: - Edge Type Tests

    func test_lineageEdge_typeFromLabel_forked() {
        let edge = LineageEdge(fromID: UUID(), toID: UUID(), label: "Forked", createdAt: Date())

        XCTAssertEqual(edge.edgeType, .forked)
        XCTAssertEqual(edge.edgeType.displayName, "Forked")
    }

    func test_lineageEdge_typeFromLabel_adapted() {
        let edge = LineageEdge(fromID: UUID(), toID: UUID(), label: "Adapted", createdAt: Date())

        XCTAssertEqual(edge.edgeType, .adapted)
        XCTAssertEqual(edge.edgeType.displayName, "Adapted")
    }

    func test_lineageEdge_typeFromLabel_remixed() {
        let edge = LineageEdge(fromID: UUID(), toID: UUID(), label: "Remixed", createdAt: Date())

        XCTAssertEqual(edge.edgeType, .remixed)
        XCTAssertEqual(edge.edgeType.displayName, "Remixed")
    }

    func test_lineageEdge_typeFromLabel_simplified() {
        let edge = LineageEdge(fromID: UUID(), toID: UUID(), label: "Simplified", createdAt: Date())

        XCTAssertEqual(edge.edgeType, .simplified)
        XCTAssertEqual(edge.edgeType.displayName, "Simplified")
    }

    func test_lineageEdge_typeFromLabel_default() {
        let edge = LineageEdge(fromID: UUID(), toID: UUID(), label: "Unknown", createdAt: Date())

        XCTAssertEqual(edge.edgeType, .forked)
    }

    func test_lineageEdge_typeFromLabel_nilLabel() {
        let edge = LineageEdge(fromID: UUID(), toID: UUID(), label: nil, createdAt: Date())

        XCTAssertEqual(edge.edgeType, .forked)
    }

    // MARK: - TreeStats Display Tests

    func test_treeStats_displaySummary() {
        let stats = TreeStats(
            totalNodes: 5,
            totalGenerations: 3,
            totalForks: 4,
            totalCooks: 50,
            totalShares: 10
        )

        let summary = stats.displaySummary

        XCTAssertTrue(summary.contains("5 versions"))
        XCTAssertTrue(summary.contains("3 generations"))
        XCTAssertTrue(summary.contains("50 total cooks"))
    }

    // MARK: - Layout Algorithm Tests

    func test_layoutAlgorithm_displayNames() {
        XCTAssertEqual(LineageLayoutAlgorithm.hierarchical.displayName, "Tree View")
        XCTAssertEqual(LineageLayoutAlgorithm.timeline.displayName, "Timeline")
        XCTAssertEqual(LineageLayoutAlgorithm.force.displayName, "Network")
    }

    func test_layoutAlgorithm_icons() {
        XCTAssertEqual(LineageLayoutAlgorithm.hierarchical.icon, "chart.tree")
        XCTAssertEqual(LineageLayoutAlgorithm.timeline.icon, "calendar")
        XCTAssertEqual(LineageLayoutAlgorithm.force.icon, "circle.hexagongrid")
    }
}
