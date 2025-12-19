import XCTest
@testable import Heirloom
import SwiftUI

final class LineageLayoutEngineTests: XCTestCase {

    // MARK: - Setup Helpers

    private func createSampleRecipe(title: String, generation: Int, dateAdded: Date = Date()) -> Recipe {
        let recipe = Recipe(title: title, sourceType: .manual)
        recipe.provenance = ProvenanceMetadata(
            sourceType: generation == 0 ? .userCreated : .shared,
            generation: generation
        )
        recipe.dateAdded = dateAdded
        return recipe
    }

    private func createSimpleTree() -> LineageTree {
        let root = createSampleRecipe(title: "Root", generation: 0)
        let child1 = createSampleRecipe(title: "Child 1", generation: 1)
        let child2 = createSampleRecipe(title: "Child 2", generation: 1)

        let nodes = [
            LineageNode(recipe: root, generation: 0, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false),
            LineageNode(recipe: child1, generation: 1, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false),
            LineageNode(recipe: child2, generation: 1, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false)
        ]

        let edges = [
            LineageEdge(fromID: root.id, toID: child1.id, label: "Forked", createdAt: Date()),
            LineageEdge(fromID: root.id, toID: child2.id, label: "Forked", createdAt: Date())
        ]

        return LineageTree(root: root, nodes: nodes, edges: edges)
    }

    // MARK: - Hierarchical Layout Tests

    func test_hierarchicalLayout_positionsNodes() {
        let tree = createSimpleTree()
        let size = CGSize(width: 800, height: 600)

        let positions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size)

        XCTAssertEqual(positions.count, 3)
        XCTAssertNotNil(positions[tree.root.id])
    }

    func test_hierarchicalLayout_rootAtTopLevel() {
        let tree = createSimpleTree()
        let size = CGSize(width: 800, height: 600)

        let positions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size)

        guard let rootPos = positions[tree.root.id] else {
            XCTFail("Root position not found")
            return
        }

        // Root should be near the top (y = 50)
        XCTAssertEqual(rootPos.y, 50, accuracy: 1)
    }

    func test_hierarchicalLayout_childrenBelowRoot() {
        let tree = createSimpleTree()
        let size = CGSize(width: 800, height: 600)

        let positions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size)

        guard let rootPos = positions[tree.root.id] else {
            XCTFail("Root position not found")
            return
        }

        let child1 = tree.nodes.first { $0.recipe.title == "Child 1" }!
        guard let child1Pos = positions[child1.recipe.id] else {
            XCTFail("Child 1 position not found")
            return
        }

        // Child should be below root (levelSpacing = 150)
        XCTAssertGreaterThan(child1Pos.y, rootPos.y)
        XCTAssertEqual(child1Pos.y, rootPos.y + 150, accuracy: 1)
    }

    func test_hierarchicalLayout_childrenSpacedHorizontally() {
        let tree = createSimpleTree()
        let size = CGSize(width: 800, height: 600)

        let positions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size)

        let child1 = tree.nodes.first { $0.recipe.title == "Child 1" }!
        let child2 = tree.nodes.first { $0.recipe.title == "Child 2" }!

        guard let child1Pos = positions[child1.recipe.id],
              let child2Pos = positions[child2.recipe.id] else {
            XCTFail("Child positions not found")
            return
        }

        // Children should be spaced horizontally (nodeSpacing = 120)
        XCTAssertNotEqual(child1Pos.x, child2Pos.x)
        let spacing = abs(child2Pos.x - child1Pos.x)
        XCTAssertEqual(spacing, 120, accuracy: 1)
    }

    func test_hierarchicalLayout_centersNodes() {
        let tree = createSimpleTree()
        let size = CGSize(width: 800, height: 600)

        let positions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size)

        let child1 = tree.nodes.first { $0.recipe.title == "Child 1" }!
        let child2 = tree.nodes.first { $0.recipe.title == "Child 2" }!

        guard let child1Pos = positions[child1.recipe.id],
              let child2Pos = positions[child2.recipe.id] else {
            XCTFail("Child positions not found")
            return
        }

        // Average x position should be near center
        let avgX = (child1Pos.x + child2Pos.x) / 2
        XCTAssertEqual(avgX, size.width / 2, accuracy: 60)
    }

    // MARK: - Timeline Layout Tests

    func test_timelineLayout_positionsNodes() {
        let tree = createSimpleTree()
        let size = CGSize(width: 1000, height: 600)

        let positions = LineageLayoutEngine.timelineLayout(tree: tree, in: size)

        XCTAssertEqual(positions.count, 3)
        XCTAssertNotNil(positions[tree.root.id])
    }

    func test_timelineLayout_ordersByDate() {
        // Create tree with specific dates
        let oldDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let newDate = Date()

        let root = createSampleRecipe(title: "Root", generation: 0, dateAdded: oldDate)
        let child = createSampleRecipe(title: "Child", generation: 1, dateAdded: newDate)

        let nodes = [
            LineageNode(recipe: root, generation: 0, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false),
            LineageNode(recipe: child, generation: 1, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false)
        ]

        let edges = [
            LineageEdge(fromID: root.id, toID: child.id, label: "Forked", createdAt: Date())
        ]

        let tree = LineageTree(root: root, nodes: nodes, edges: edges)
        let size = CGSize(width: 1000, height: 600)

        let positions = LineageLayoutEngine.timelineLayout(tree: tree, in: size)

        guard let rootPos = positions[root.id],
              let childPos = positions[child.id] else {
            XCTFail("Positions not found")
            return
        }

        // Newer recipe (child) should be to the right of older recipe (root)
        XCTAssertGreaterThan(childPos.x, rootPos.x)
    }

    func test_timelineLayout_spacesNodesHorizontally() {
        let tree = createSimpleTree()
        let size = CGSize(width: 1000, height: 600)

        let positions = LineageLayoutEngine.timelineLayout(tree: tree, in: size)

        let allX = positions.values.map { $0.x }

        // All x positions should be different (spaced by 150)
        let uniqueX = Set(allX)
        XCTAssertEqual(allX.count, uniqueX.count)
    }

    func test_timelineLayout_positionsGenerationsByY() {
        let tree = createSimpleTree()
        let size = CGSize(width: 1000, height: 600)

        let positions = LineageLayoutEngine.timelineLayout(tree: tree, in: size)

        let rootY = positions[tree.root.id]!.y
        let child1 = tree.nodes.first { $0.recipe.title == "Child 1" }!
        let child1Y = positions[child1.recipe.id]!.y

        // Child (generation 1) should be below root (generation 0)
        XCTAssertGreaterThan(child1Y, rootY)
    }

    // MARK: - Edge Cases

    func test_hierarchicalLayout_singleNode() {
        let recipe = createSampleRecipe(title: "Only Node", generation: 0)
        let nodes = [
            LineageNode(recipe: recipe, generation: 0, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false)
        ]
        let tree = LineageTree(root: recipe, nodes: nodes, edges: [])
        let size = CGSize(width: 800, height: 600)

        let positions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size)

        XCTAssertEqual(positions.count, 1)

        let pos = positions[recipe.id]!
        // Single node should be near center
        XCTAssertEqual(pos.x, size.width / 2, accuracy: 60)
        XCTAssertEqual(pos.y, 50, accuracy: 1)
    }

    func test_timelineLayout_singleNode() {
        let recipe = createSampleRecipe(title: "Only Node", generation: 0)
        let nodes = [
            LineageNode(recipe: recipe, generation: 0, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false)
        ]
        let tree = LineageTree(root: recipe, nodes: nodes, edges: [])
        let size = CGSize(width: 800, height: 600)

        let positions = LineageLayoutEngine.timelineLayout(tree: tree, in: size)

        XCTAssertEqual(positions.count, 1)

        let pos = positions[recipe.id]!
        // Timeline starts at x=50
        XCTAssertEqual(pos.x, 50, accuracy: 1)
    }

    func test_hierarchicalLayout_manyGenerations() {
        // Create a tree with 4 generations
        let gen0 = createSampleRecipe(title: "Gen 0", generation: 0)
        let gen1 = createSampleRecipe(title: "Gen 1", generation: 1)
        let gen2 = createSampleRecipe(title: "Gen 2", generation: 2)
        let gen3 = createSampleRecipe(title: "Gen 3", generation: 3)

        let nodes = [
            LineageNode(recipe: gen0, generation: 0, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false),
            LineageNode(recipe: gen1, generation: 1, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false),
            LineageNode(recipe: gen2, generation: 2, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false),
            LineageNode(recipe: gen3, generation: 3, position: .zero,
                       stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                       isCurrentUser: false)
        ]

        let edges = [
            LineageEdge(fromID: gen0.id, toID: gen1.id, label: "Forked", createdAt: Date()),
            LineageEdge(fromID: gen1.id, toID: gen2.id, label: "Forked", createdAt: Date()),
            LineageEdge(fromID: gen2.id, toID: gen3.id, label: "Forked", createdAt: Date())
        ]

        let tree = LineageTree(root: gen0, nodes: nodes, edges: edges)
        let size = CGSize(width: 800, height: 800)

        let positions = LineageLayoutEngine.hierarchicalLayout(tree: tree, in: size)

        let y0 = positions[gen0.id]!.y
        let y1 = positions[gen1.id]!.y
        let y2 = positions[gen2.id]!.y
        let y3 = positions[gen3.id]!.y

        // Each generation should be 150 pixels below the previous
        XCTAssertEqual(y1 - y0, 150, accuracy: 1)
        XCTAssertEqual(y2 - y1, 150, accuracy: 1)
        XCTAssertEqual(y3 - y2, 150, accuracy: 1)
    }
}
