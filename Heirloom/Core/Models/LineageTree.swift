import Foundation
import SwiftUI

/// Represents a recipe lineage tree for visualization
struct LineageTree: Identifiable {
    let id = UUID()
    let root: Recipe
    let nodes: [LineageNode]
    let edges: [LineageEdge]

    /// Statistics about the entire tree
    var stats: TreeStats {
        TreeStats(
            totalNodes: nodes.count,
            totalGenerations: maxGeneration,
            totalForks: edges.count,
            totalCooks: nodes.reduce(0) { $0 + $1.stats.cookCount },
            totalShares: nodes.reduce(0) { $0 + $1.stats.shareCount }
        )
    }

    /// Maximum generation depth in the tree
    var maxGeneration: Int {
        nodes.map { $0.generation }.max() ?? 0
    }

    /// Get node by recipe ID
    func node(for recipeID: UUID) -> LineageNode? {
        nodes.first { $0.recipe.id == recipeID }
    }

    /// Get children of a node
    func children(of nodeID: UUID) -> [LineageNode] {
        let childIDs = edges.filter { $0.fromID == nodeID }.map { $0.toID }
        return nodes.filter { childIDs.contains($0.recipe.id) }
    }

    /// Get parent of a node
    func parent(of nodeID: UUID) -> LineageNode? {
        guard let edge = edges.first(where: { $0.toID == nodeID }) else { return nil }
        return nodes.first { $0.recipe.id == edge.fromID }
    }

    /// Get siblings of a node (same parent)
    func siblings(of nodeID: UUID) -> [LineageNode] {
        guard let parent = parent(of: nodeID) else { return [] }
        return children(of: parent.recipe.id).filter { $0.recipe.id != nodeID }
    }
}

/// A node in the lineage tree
struct LineageNode: Identifiable {
    let id = UUID()
    let recipe: Recipe
    let generation: Int
    var position: CGPoint // For graph layout
    let stats: NodeStats
    let isCurrentUser: Bool // Whether this is the user's version

    /// Display label for the node
    var displayLabel: String {
        recipe.title
    }

    /// Generation badge text
    var generationBadge: String {
        switch generation {
        case 0: return "Original"
        case 1: return "1st Gen"
        case 2: return "2nd Gen"
        case 3: return "3rd Gen"
        default: return "\(generation)th Gen"
        }
    }

    /// Color for the node based on generation
    var generationColor: Color {
        switch generation {
        case 0: return HeirloomColors.tomato
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        default: return HeirloomColors.warmGray
        }
    }
}

/// Statistics for a node
struct NodeStats {
    let cookCount: Int
    let shareCount: Int
    let viewCount: Int
    let rating: Double?

    var popularityScore: Double {
        Double(cookCount * 20 + shareCount * 10 + viewCount)
    }

    var displayStats: String {
        var parts: [String] = []
        if cookCount > 0 { parts.append("\(cookCount) cooks") }
        if shareCount > 0 { parts.append("\(shareCount) shares") }
        return parts.isEmpty ? "No activity yet" : parts.joined(separator: " • ")
    }
}

/// An edge connecting two nodes in the lineage tree
struct LineageEdge: Identifiable {
    let id = UUID()
    let fromID: UUID // Parent recipe ID
    let toID: UUID   // Child recipe ID
    let label: String?
    let createdAt: Date

    /// Edge type based on label
    var edgeType: EdgeType {
        guard let label = label?.lowercased() else { return .forked }
        if label.contains("adapt") { return .adapted }
        if label.contains("remix") { return .remixed }
        if label.contains("simplif") { return .simplified }
        return .forked
    }

    enum EdgeType {
        case forked
        case adapted
        case remixed
        case simplified

        var displayName: String {
            switch self {
            case .forked: return "Forked"
            case .adapted: return "Adapted"
            case .remixed: return "Remixed"
            case .simplified: return "Simplified"
            }
        }

        var color: Color {
            switch self {
            case .forked: return HeirloomColors.warmGray
            case .adapted: return .blue
            case .remixed: return .purple
            case .simplified: return .green
            }
        }
    }
}

/// Statistics for the entire tree
struct TreeStats {
    let totalNodes: Int
    let totalGenerations: Int
    let totalForks: Int
    let totalCooks: Int
    let totalShares: Int

    var displaySummary: String {
        "\(totalNodes) versions • \(totalGenerations) generations • \(totalCooks) total cooks"
    }
}

/// Layout algorithm for positioning nodes
enum LineageLayoutAlgorithm {
    case hierarchical // Top-down tree
    case timeline     // Chronological left-to-right
    case force        // Force-directed graph

    var displayName: String {
        switch self {
        case .hierarchical: return "Tree View"
        case .timeline: return "Timeline"
        case .force: return "Network"
        }
    }

    var icon: String {
        switch self {
        case .hierarchical: return "chart.tree"
        case .timeline: return "calendar"
        case .force: return "circle.hexagongrid"
        }
    }
}

/// Layout helper for calculating node positions
struct LineageLayoutEngine {

    /// Calculate hierarchical tree layout (top-down)
    static func hierarchicalLayout(tree: LineageTree, in size: CGSize) -> [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        let levelSpacing: CGFloat = 150
        let nodeSpacing: CGFloat = 120

        // Group nodes by generation
        var nodesByGeneration: [Int: [LineageNode]] = [:]
        for node in tree.nodes {
            nodesByGeneration[node.generation, default: []].append(node)
        }

        // Position each generation
        for (generation, nodes) in nodesByGeneration.sorted(by: { $0.key < $1.key }) {
            let y = CGFloat(generation) * levelSpacing + 50
            let totalWidth = CGFloat(nodes.count) * nodeSpacing
            let startX = (size.width - totalWidth) / 2

            for (index, node) in nodes.enumerated() {
                let x = startX + CGFloat(index) * nodeSpacing + nodeSpacing / 2
                positions[node.recipe.id] = CGPoint(x: x, y: y)
            }
        }

        return positions
    }

    /// Calculate timeline layout (chronological)
    static func timelineLayout(tree: LineageTree, in size: CGSize) -> [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        let nodes = tree.nodes.sorted { $0.recipe.dateAdded < $1.recipe.dateAdded }
        let spacing: CGFloat = 150

        for (index, node) in nodes.enumerated() {
            let x = 50 + CGFloat(index) * spacing
            let y = 100 + CGFloat(node.generation) * 100
            positions[node.recipe.id] = CGPoint(x: x, y: y)
        }

        return positions
    }
}
