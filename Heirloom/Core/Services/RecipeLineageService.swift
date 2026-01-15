import Foundation
import SwiftData
import SwiftUI
import FirebaseFirestore

/// Service for fetching and managing recipe lineage trees
@MainActor
final class RecipeLineageService {

    // MARK: - Dependencies

    private let firebaseLineageService: FirebaseLineageService?

    init(firebaseLineageService: FirebaseLineageService? = nil) {
        self.firebaseLineageService = firebaseLineageService
    }

    // MARK: - Fetch Lineage Tree

    /// Fetch the complete lineage tree for a recipe
    /// - Parameters:
    ///   - recipe: The recipe to build the tree around
    ///   - context: SwiftData model context
    ///   - maxDepth: Maximum number of generations to fetch up/down (default: 3)
    /// - Returns: LineageTree with all connected recipes
    func fetchLineageTree(
        for recipe: Recipe,
        context: ModelContext,
        maxDepth: Int = 3
    ) async throws -> LineageTree {
        Log.debug("Fetching lineage tree", category: .general, metadata: ["title": recipe.title, "maxDepth": maxDepth])

        var allRecipes: [Recipe] = [recipe]
        var edges: [LineageEdge] = []

        // Fetch ancestors (parents, grandparents, etc.)
        let ancestors = try await fetchAncestors(of: recipe, context: context, maxDepth: maxDepth)
        allRecipes.append(contentsOf: ancestors.recipes)
        edges.append(contentsOf: ancestors.edges)

        // Fetch descendants (children, grandchildren, etc.)
        let descendants = try await fetchDescendants(of: recipe, context: context, maxDepth: maxDepth)
        allRecipes.append(contentsOf: descendants.recipes)
        edges.append(contentsOf: descendants.edges)

        // Remove duplicates
        let uniqueRecipes = Array(Set(allRecipes.map { $0.id }))
            .compactMap { id in allRecipes.first { $0.id == id } }

        // Create nodes with stats
        let nodes = uniqueRecipes.map { recipe in
            createNode(for: recipe)
        }

        // Find root (generation 0)
        let root = uniqueRecipes
            .sorted { ($0.provenance?.generation ?? 0) < ($1.provenance?.generation ?? 0) }
            .first ?? recipe

        let tree = LineageTree(root: root, nodes: nodes, edges: edges)

        Log.info("Built lineage tree", category: .general, metadata: ["nodeCount": nodes.count, "edgeCount": edges.count, "rootTitle": root.title])
        return tree
    }

    /// Fetch lineage tree from Firebase for shared recipes
    /// Queries global lineages collection for all recipes in the same family tree
    func fetchRemoteLineageTree(
        provenanceHash: String,
        maxDepth: Int = 3
    ) async throws -> LineageTree {
        guard firebaseLineageService != nil else {
            Log.warning("No Firebase lineage service available for remote fetch", category: .firebase)
            throw LineageError.notImplemented
        }

        Log.info("Fetching remote lineage tree from Firebase", category: .firebase, metadata: [
            "provenanceHash": provenanceHash,
            "maxDepth": maxDepth
        ])

        // Query global lineages collection for matching rootProvenanceHash
        let db = Firestore.firestore()
        let query = db.collection("lineages")
            .whereField("rootProvenanceHash", isEqualTo: provenanceHash)
            .limit(to: 100) // Safety limit

        let snapshot = try await query.getDocuments()

        Log.info("Fetched remote lineages", category: .firebase, metadata: ["count": snapshot.documents.count])

        // Convert Firestore documents to lightweight recipe representations
        var recipes: [Recipe] = []
        var edges: [LineageEdge] = []

        for doc in snapshot.documents {
            let data = doc.data()

            // Extract basic recipe info from lineage document
            guard let recipeIdString = data["currentRecipeId"] as? String,
                  let recipeId = UUID(uuidString: recipeIdString),
                  let recipeTitle = data["recipeTitle"] as? String,
                  let generation = data["generation"] as? Int else {
                Log.warning("Invalid lineage data in remote document", category: .firebase, metadata: ["docId": doc.documentID])
                continue
            }

            // Create lightweight Recipe object for visualization
            // Note: This is a partial recipe with just enough info for lineage display
            let recipe = Recipe()
            recipe.id = recipeId
            recipe.title = recipeTitle

            // Create provenance metadata
            let parentShareId = data["parentShareId"] as? String
            let sharedByName = data["sharedByName"] as? String

            let provenance = ProvenanceMetadata(
                sourceType: generation == 0 ? .userCreated : .shared,
                rootProvenanceHash: provenanceHash,
                generation: generation,
                parentShareID: parentShareId,
                sharedByName: sharedByName
            )
            recipe.provenance = provenance

            recipes.append(recipe)

            // Edge creation will be done after we have all recipes parsed

            Log.debug("Parsed remote recipe", category: .firebase, metadata: [
                "title": recipeTitle,
                "generation": generation
            ])
        }

        // Find the root recipe (generation 0)
        guard let root = recipes.first(where: { $0.provenance?.generation == 0 }) else {
            Log.error("No root recipe found in remote lineage", category: .firebase)
            throw LineageError.invalidProvenance
        }

        // Build edges by connecting generations
        // Each recipe at generation N+1 connects to a recipe at generation N
        for recipe in recipes where (recipe.provenance?.generation ?? 0) > 0 {
            let currentGen = recipe.provenance?.generation ?? 0
            let parentGen = currentGen - 1

            // Find any recipe from the previous generation (simplified - assumes single parent)
            if let parent = recipes.first(where: { ($0.provenance?.generation ?? 0) == parentGen }) {
                let edge = LineageEdge(
                    fromID: parent.id,
                    toID: recipe.id,
                    label: recipe.provenance?.sharedByName.map { "Shared by \($0)" },
                    createdAt: recipe.provenance?.createdAt ?? Date()
                )
                edges.append(edge)
            }
        }

        // Create nodes with positions and stats (placeholder values for remote recipes)
        let nodes = recipes.map { recipe in
            LineageNode(
                recipe: recipe,
                generation: recipe.provenance?.generation ?? 0,
                position: .zero, // Will be calculated by layout engine
                stats: NodeStats(cookCount: 0, shareCount: 0, viewCount: 0, rating: nil),
                isCurrentUser: false // Remote recipes are never the current user's
            )
        }

        let tree = LineageTree(root: root, nodes: nodes, edges: edges)

        Log.info("Built remote lineage tree", category: .firebase, metadata: [
            "nodeCount": nodes.count,
            "edgeCount": edges.count,
            "rootTitle": root.title
        ])

        return tree
    }

    // MARK: - Fetch Ancestors

    private func fetchAncestors(
        of recipe: Recipe,
        context: ModelContext,
        maxDepth: Int,
        currentDepth: Int = 0
    ) async throws -> (recipes: [Recipe], edges: [LineageEdge]) {
        guard currentDepth < maxDepth else { return ([], []) }

        var recipes: [Recipe] = []
        var edges: [LineageEdge] = []

        // Get parent from provenance
        guard let provenance = recipe.provenance,
              let parentHash = provenance.parentShareID else {
            return ([], [])
        }

        // Query for all recipes with provenance, then filter in memory
        // (SwiftData predicates don't handle optional String comparisons well)
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.provenance != nil
            }
        )

        let allRecipes = try context.fetch(descriptor)
        let parents = allRecipes.filter { $0.provenance?.rootProvenanceHash == parentHash }

        for parent in parents {
            recipes.append(parent)

            // Create edge
            let edge = LineageEdge(
                fromID: parent.id,
                toID: recipe.id,
                label: "Forked",
                createdAt: recipe.dateAdded
            )
            edges.append(edge)

            // Recursively fetch parent's ancestors
            let ancestorResult = try await fetchAncestors(
                of: parent,
                context: context,
                maxDepth: maxDepth,
                currentDepth: currentDepth + 1
            )
            recipes.append(contentsOf: ancestorResult.recipes)
            edges.append(contentsOf: ancestorResult.edges)
        }

        return (recipes, edges)
    }

    // MARK: - Fetch Descendants

    private func fetchDescendants(
        of recipe: Recipe,
        context: ModelContext,
        maxDepth: Int,
        currentDepth: Int = 0
    ) async throws -> (recipes: [Recipe], edges: [LineageEdge]) {
        guard currentDepth < maxDepth else { return ([], []) }

        var recipes: [Recipe] = []
        var edges: [LineageEdge] = []

        guard let provenance = recipe.provenance else { return ([], []) }

        // Query for children (recipes that have this recipe as parent)
        let rootHash = provenance.rootProvenanceHash

        // Fetch all recipes with provenance, then filter in memory
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { childRecipe in
                childRecipe.provenance != nil
            }
        )

        let allRecipes = try context.fetch(descriptor)
        let children = allRecipes.filter { $0.provenance?.parentShareID == rootHash }

        for child in children {
            recipes.append(child)

            // Create edge
            let edge = LineageEdge(
                fromID: recipe.id,
                toID: child.id,
                label: "Forked",
                createdAt: child.dateAdded
            )
            edges.append(edge)

            // Recursively fetch child's descendants
            let descendantResult = try await fetchDescendants(
                of: child,
                context: context,
                maxDepth: maxDepth,
                currentDepth: currentDepth + 1
            )
            recipes.append(contentsOf: descendantResult.recipes)
            edges.append(contentsOf: descendantResult.edges)
        }

        return (recipes, edges)
    }

    // MARK: - Node Creation

    private func createNode(for recipe: Recipe) -> LineageNode {
        let generation = recipe.provenance?.generation ?? 0
        let stats = NodeStats(
            cookCount: recipe.timesCooked,
            shareCount: recipe.totalShares,
            viewCount: 0, // TODO: Track views in analytics
            rating: nil // TODO: Add rating system
        )

        return LineageNode(
            recipe: recipe,
            generation: generation,
            position: .zero, // Will be calculated by layout algorithm
            stats: stats,
            isCurrentUser: true // TODO: Detect if recipe belongs to current user
        )
    }

    // MARK: - Lineage Statistics

    /// Calculate statistics for a recipe's lineage
    func calculateLineageStats(for recipe: Recipe, context: ModelContext) async throws -> LineageStats {
        let tree = try await fetchLineageTree(for: recipe, context: context)

        let totalForks = tree.nodes.count - 1 // Exclude self
        let totalCooks = tree.stats.totalCooks
        let totalShares = tree.stats.totalShares
        let avgPopularity = tree.nodes.isEmpty ? 0 : Double(totalCooks) / Double(tree.nodes.count)

        // Find most popular descendant
        let mostPopular = tree.nodes
            .filter { $0.recipe.id != recipe.id }
            .max { $0.stats.popularityScore < $1.stats.popularityScore }

        return LineageStats(
            totalForks: totalForks,
            totalGenerations: tree.maxGeneration,
            totalCooks: totalCooks,
            totalShares: totalShares,
            averagePopularity: avgPopularity,
            mostPopularFork: mostPopular?.recipe
        )
    }

    /// Find recipes in the same lineage
    func findSiblings(of recipe: Recipe, context: ModelContext) async throws -> [Recipe] {
        guard let provenance = recipe.provenance,
              let parentHash = provenance.parentShareID else {
            return []
        }

        // Query for siblings (same parent)
        let recipeId = recipe.id

        // Fetch all recipes with provenance, then filter in memory
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { sibling in
                sibling.provenance != nil
            }
        )

        let allRecipes = try context.fetch(descriptor)
        return allRecipes.filter {
            $0.provenance?.parentShareID == parentHash && $0.id != recipeId
        }
    }

    /// Get direct children of a recipe
    func getDirectChildren(of recipe: Recipe, context: ModelContext) async throws -> [Recipe] {
        guard let provenance = recipe.provenance else { return [] }

        let rootHash = provenance.rootProvenanceHash

        // Fetch all recipes with provenance, then filter in memory
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { child in
                child.provenance != nil
            }
        )

        let allRecipes = try context.fetch(descriptor)
        return allRecipes.filter { $0.provenance?.parentShareID == rootHash }
    }
}

// MARK: - Supporting Types

/// Statistics for a recipe's lineage
struct LineageStats {
    let totalForks: Int
    let totalGenerations: Int
    let totalCooks: Int
    let totalShares: Int
    let averagePopularity: Double
    let mostPopularFork: Recipe?

    var displaySummary: String {
        var parts: [String] = []
        if totalForks > 0 { parts.append("\(totalForks) forks") }
        if totalGenerations > 0 { parts.append("\(totalGenerations) generations") }
        if totalCooks > 0 { parts.append("\(totalCooks) total cooks") }
        return parts.isEmpty ? "Original recipe" : parts.joined(separator: " • ")
    }

    var hasForks: Bool {
        totalForks > 0
    }
}

/// Errors specific to lineage operations
enum LineageError: LocalizedError {
    case notFound
    case invalidProvenance
    case notImplemented
    case fetchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Recipe lineage not found"
        case .invalidProvenance:
            return "Recipe has invalid provenance data"
        case .notImplemented:
            return "Feature not yet implemented"
        case .fetchFailed(let error):
            return "Failed to fetch lineage: \(error.localizedDescription)"
        }
    }
}
