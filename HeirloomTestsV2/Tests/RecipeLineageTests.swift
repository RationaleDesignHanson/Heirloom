import Testing
import Foundation
import SwiftData
import SwiftUI

@testable import Heirloom

@Suite("Recipe Lineage Tests")
struct RecipeLineageTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Heirloom.Recipe.self,
            RecipeLineage.self,
            Heirloom.Ingredient.self,
            Heirloom.Tag.self,
            RecipeCollection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - RecipeLineage Initialization Tests

    @Test("RecipeLineage initializes with required fields")
    func testRecipeLineage_Init_WithRequiredFields() {
        // Arrange
        let rootId = UUID()
        let currentId = UUID()

        // Act
        let lineage = RecipeLineage(
            rootRecipeId: rootId,
            currentRecipeId: currentId,
            ownerId: "user123",
            rootOwnerId: "user123",
            generation: 0
        )

        // Assert
        #expect(lineage.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(lineage.rootRecipeId == rootId)
        #expect(lineage.currentRecipeId == currentId)
        #expect(lineage.ownerId == "user123")
        #expect(lineage.rootOwnerId == "user123")
        #expect(lineage.generation == 0)
        #expect(lineage.isHeirloom == true)
        #expect(lineage.hasLocalModifications == false)
    }

    @Test("RecipeLineage createRoot factory creates root lineage")
    func testRecipeLineage_CreateRoot_CreatesRootLineage() {
        // Arrange
        let recipeId = UUID()

        // Act
        let lineage = RecipeLineage.createRoot(recipeId: recipeId, ownerId: "user123")

        // Assert
        #expect(lineage.generation == 0)
        #expect(lineage.rootRecipeId == recipeId)
        #expect(lineage.currentRecipeId == recipeId)
        #expect(lineage.parentRecipeId == nil)
        #expect(lineage.isRoot == true)
    }

    @Test("RecipeLineage createDescendant factory creates descendant lineage")
    func testRecipeLineage_CreateDescendant_CreatesDescendantLineage() {
        // Arrange
        let rootId = UUID()
        let parentId = UUID()
        let currentId = UUID()

        // Act
        let lineage = RecipeLineage.createDescendant(
            rootRecipeId: rootId,
            parentRecipeId: parentId,
            currentRecipeId: currentId,
            ownerId: "user456",
            rootOwnerId: "user123",
            generation: 1,
            sharedByName: "John Doe"
        )

        // Assert
        #expect(lineage.generation == 1)
        #expect(lineage.rootRecipeId == rootId)
        #expect(lineage.parentRecipeId == parentId)
        #expect(lineage.currentRecipeId == currentId)
        #expect(lineage.sharedByName == "John Doe")
        #expect(lineage.isRoot == false)
    }

    // MARK: - Modification Record Tests

    @Test("ModificationRecord initializes with required fields")
    func testModificationRecord_Init_WithRequiredFields() {
        // Act
        let modification = ModificationRecord(
            modifiedBy: "user123",
            changeType: .ingredientAdded,
            changeDescription: "Added salt"
        )

        // Assert
        #expect(modification.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(modification.modifiedBy == "user123")
        #expect(modification.changeType == .ingredientAdded)
        #expect(modification.changeDescription == "Added salt")
    }

    @Test("ModificationRecord ChangeType has correct raw values")
    func testModificationRecord_ChangeType_RawValues() {
        // Assert
        #expect(ModificationRecord.ChangeType.created.rawValue == "created")
        #expect(ModificationRecord.ChangeType.modified.rawValue == "modified")
        #expect(ModificationRecord.ChangeType.ingredientAdded.rawValue == "ingredient_added")
        #expect(ModificationRecord.ChangeType.titleChanged.rawValue == "title_changed")
    }

    // MARK: - RecipeLineage Computed Properties

    @Test("RecipeLineage generationLabel returns correct labels")
    func testRecipeLineage_GenerationLabel_ReturnsCorrectLabels() {
        // Assert
        let gen0 = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 0)
        #expect(gen0.generationLabel == "Original")

        let gen1 = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 1)
        #expect(gen1.generationLabel == "1st Generation")

        let gen2 = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 2)
        #expect(gen2.generationLabel == "2nd Generation")

        let gen3 = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 3)
        #expect(gen3.generationLabel == "3rd Generation")

        let gen5 = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 5)
        #expect(gen5.generationLabel == "5th Generation")
    }

    @Test("RecipeLineage isRoot returns true for generation 0")
    func testRecipeLineage_IsRoot_TrueForGeneration0() {
        // Arrange
        let lineage = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 0)

        // Assert
        #expect(lineage.isRoot == true)
    }

    @Test("RecipeLineage isRoot returns false for generation > 0")
    func testRecipeLineage_IsRoot_FalseForHigherGenerations() {
        // Arrange
        let lineage = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 1)

        // Assert
        #expect(lineage.isRoot == false)
    }

    @Test("RecipeLineage modificationCount returns zero when no modifications")
    func testRecipeLineage_ModificationCount_ZeroWhenEmpty() {
        // Arrange
        let lineage = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 0)

        // Assert
        #expect(lineage.modificationCount == 0)
    }

    @Test("RecipeLineage modificationCount returns correct count")
    func testRecipeLineage_ModificationCount_ReturnsCount() {
        // Arrange
        let lineage = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 0)
        lineage.modifications = [
            ModificationRecord(modifiedBy: "u", changeType: .created, changeDescription: "Created"),
            ModificationRecord(modifiedBy: "u", changeType: .modified, changeDescription: "Modified")
        ]

        // Assert
        #expect(lineage.modificationCount == 2)
    }

    @Test("RecipeLineage addModification adds modification")
    func testRecipeLineage_AddModification_AddsModification() {
        // Arrange
        let lineage = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 0)
        let modification = ModificationRecord(modifiedBy: "u", changeType: .ingredientAdded, changeDescription: "Added ingredient")

        // Act
        lineage.addModification(modification)

        // Assert
        #expect(lineage.modificationCount == 1)
        #expect(lineage.hasLocalModifications == true)
    }

    @Test("RecipeLineage sortedModifications returns sorted by timestamp")
    func testRecipeLineage_SortedModifications_ReturnsSorted() {
        // Arrange
        let lineage = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 0)
        let old = ModificationRecord(timestamp: Date(timeIntervalSinceNow: -3600), modifiedBy: "u", changeType: .created, changeDescription: "Old")
        let recent = ModificationRecord(timestamp: Date(), modifiedBy: "u", changeType: .modified, changeDescription: "Recent")
        lineage.modifications = [old, recent]

        // Act
        let sorted = lineage.sortedModifications()

        // Assert - Most recent first
        #expect(sorted[0].changeDescription == "Recent")
        #expect(sorted[1].changeDescription == "Old")
    }

    // MARK: - LineageTree Tests

    @Test("LineageTree initializes with nodes and edges")
    func testLineageTree_Init_WithNodesAndEdges() {
        // Arrange
        let root = Heirloom.Recipe(title: "Root Recipe")
        let node = LineageNode(recipe: root, generation: 0, position: .zero, stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil), isCurrentUser: true)

        // Act
        let tree = LineageTree(root: root, nodes: [node], edges: [])

        // Assert
        #expect(tree.nodes.count == 1)
        #expect(tree.edges.count == 0)
        #expect(tree.root.title == "Root Recipe")
    }

    @Test("LineageTree maxGeneration returns highest generation")
    func testLineageTree_MaxGeneration_ReturnsHighest() {
        // Arrange
        let root = Heirloom.Recipe(title: "Root")
        let node0 = LineageNode(recipe: root, generation: 0, position: .zero, stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil), isCurrentUser: true)
        let node1 = LineageNode(recipe: Heirloom.Recipe(title: "Gen1"), generation: 1, position: .zero, stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil), isCurrentUser: false)
        let node2 = LineageNode(recipe: Heirloom.Recipe(title: "Gen2"), generation: 2, position: .zero, stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil), isCurrentUser: false)

        let tree = LineageTree(root: root, nodes: [node0, node1, node2], edges: [])

        // Assert
        #expect(tree.maxGeneration == 2)
    }

    @Test("LineageTree stats calculates totals correctly")
    func testLineageTree_Stats_CalculatesTotals() {
        // Arrange
        let root = Heirloom.Recipe(title: "Root")
        let node1 = LineageNode(recipe: root, generation: 0, position: .zero, stats: NodeStats(cookCount: 5, shareCount: 2, viewCount: 10, rating: nil), isCurrentUser: true)
        let node2 = LineageNode(recipe: Heirloom.Recipe(title: "Gen1"), generation: 1, position: .zero, stats: NodeStats(cookCount: 3, shareCount: 1, viewCount: 5, rating: nil), isCurrentUser: false)

        let tree = LineageTree(root: root, nodes: [node1, node2], edges: [])

        // Act
        let stats = tree.stats

        // Assert
        #expect(stats.totalNodes == 2)
        #expect(stats.totalCooks == 8) // 5 + 3
        #expect(stats.totalShares == 3) // 2 + 1
    }

    // MARK: - LineageNode Tests

    @Test("LineageNode generationBadge returns correct labels")
    func testLineageNode_GenerationBadge_ReturnsCorrectLabels() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test")
        let stats = NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil)

        // Act & Assert
        let node0 = LineageNode(recipe: recipe, generation: 0, position: .zero, stats: stats, isCurrentUser: true)
        #expect(node0.generationBadge == "Original")

        let node1 = LineageNode(recipe: recipe, generation: 1, position: .zero, stats: stats, isCurrentUser: false)
        #expect(node1.generationBadge == "1st Gen")

        let node2 = LineageNode(recipe: recipe, generation: 2, position: .zero, stats: stats, isCurrentUser: false)
        #expect(node2.generationBadge == "2nd Gen")
    }

    @Test("LineageNode displayLabel returns recipe title")
    func testLineageNode_DisplayLabel_ReturnsTitle() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Chocolate Cake")
        let node = LineageNode(recipe: recipe, generation: 0, position: .zero, stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil), isCurrentUser: true)

        // Assert
        #expect(node.displayLabel == "Chocolate Cake")
    }

    // MARK: - NodeStats Tests

    @Test("NodeStats popularityScore calculates correctly")
    func testNodeStats_PopularityScore_Calculates() {
        // Act
        let stats = NodeStats(cookCount: 10, shareCount: 5, viewCount: 20, rating: nil)

        // Assert - cookCount*20 + shareCount*10 + viewCount = 10*20 + 5*10 + 20 = 200 + 50 + 20 = 270
        #expect(stats.popularityScore == 270)
    }

    @Test("NodeStats displayStats formats correctly")
    func testNodeStats_DisplayStats_Formats() {
        // Arrange
        let stats = NodeStats(cookCount: 10, shareCount: 5, viewCount: 20, rating: nil)

        // Act
        let display = stats.displayStats

        // Assert
        #expect(display.contains("10 cooks"))
        #expect(display.contains("5 shares"))
    }

    // MARK: - LineageEdge Tests

    @Test("LineageEdge edgeType determines type from label")
    func testLineageEdge_EdgeType_DeterminesFromLabel() {
        // Arrange
        let edge1 = LineageEdge(fromID: UUID(), toID: UUID(), label: "Adapted for kids", createdAt: Date())
        let edge2 = LineageEdge(fromID: UUID(), toID: UUID(), label: "Remixed with herbs", createdAt: Date())
        let edge3 = LineageEdge(fromID: UUID(), toID: UUID(), label: "Simplified version", createdAt: Date())
        let edge4 = LineageEdge(fromID: UUID(), toID: UUID(), label: nil, createdAt: Date())

        // Assert
        #expect(edge1.edgeType == .adapted)
        #expect(edge2.edgeType == .remixed)
        #expect(edge3.edgeType == .simplified)
        #expect(edge4.edgeType == .forked)
    }

    @Test("LineageEdge EdgeType displayName returns correct names")
    func testLineageEdge_EdgeType_DisplayName() {
        // Assert
        #expect(LineageEdge.EdgeType.forked.displayName == "Forked")
        #expect(LineageEdge.EdgeType.adapted.displayName == "Adapted")
        #expect(LineageEdge.EdgeType.remixed.displayName == "Remixed")
        #expect(LineageEdge.EdgeType.simplified.displayName == "Simplified")
    }

    // MARK: - TreeStats Tests

    @Test("TreeStats displaySummary formats correctly")
    func testTreeStats_DisplaySummary_Formats() {
        // Arrange
        let stats = TreeStats(totalNodes: 5, totalGenerations: 3, totalForks: 4, totalCooks: 50, totalShares: 10)

        // Act
        let summary = stats.displaySummary

        // Assert
        #expect(summary.contains("5 versions"))
        #expect(summary.contains("3 generations"))
        #expect(summary.contains("50 total cooks"))
    }

    // MARK: - LineageLayoutAlgorithm Tests

    @Test("LineageLayoutAlgorithm displayName returns correct names")
    func testLineageLayoutAlgorithm_DisplayName() {
        // Assert
        #expect(LineageLayoutAlgorithm.hierarchical.displayName == "Tree View")
        #expect(LineageLayoutAlgorithm.timeline.displayName == "Timeline")
        #expect(LineageLayoutAlgorithm.force.displayName == "Network")
    }

    @Test("LineageLayoutAlgorithm icon returns correct SF Symbols")
    func testLineageLayoutAlgorithm_Icon() {
        // Assert
        #expect(LineageLayoutAlgorithm.hierarchical.icon == "chart.tree")
        #expect(LineageLayoutAlgorithm.timeline.icon == "calendar")
        #expect(LineageLayoutAlgorithm.force.icon == "circle.hexagongrid")
    }

    // MARK: - Edge Case Tests

    @Test("RecipeLineage handles very high generation numbers")
    func testRecipeLineage_HandlesHighGenerations() {
        // Act
        let lineage = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 99)

        // Assert
        #expect(lineage.generation == 99)
        #expect(lineage.generationLabel == "99th Generation")
    }

    @Test("RecipeLineage modifications can be filtered by user")
    func testRecipeLineage_ModificationsByUser_Filters() {
        // Arrange
        let lineage = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "u", rootOwnerId: "u", generation: 0)
        lineage.modifications = [
            ModificationRecord(modifiedBy: "user1", changeType: .created, changeDescription: "Created"),
            ModificationRecord(modifiedBy: "user2", changeType: .modified, changeDescription: "Modified"),
            ModificationRecord(modifiedBy: "user1", changeType: .ingredientAdded, changeDescription: "Added")
        ]

        // Act
        let user1Mods = lineage.modifications(by: "user1")

        // Assert
        #expect(user1Mods.count == 2)
    }
}
