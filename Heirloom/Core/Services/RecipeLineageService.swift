import Foundation
import SwiftData
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Service for fetching and managing recipe lineage trees
@MainActor
final class RecipeLineageService {

    // MARK: - Dependencies

    private let userProfileService: FirebaseUserProfileService

    init(userProfileService: FirebaseUserProfileService? = nil) {
        self.userProfileService = userProfileService ?? ServiceContainer.shared.resolve(FirebaseUserProfileService.self)
    }

    private lazy var db: Firestore = {
        Firestore.firestore()
    }()

    // MARK: - Fetch Lineage Tree

    /// Fetch the complete lineage tree for a recipe
    /// - Parameters:
    ///   - recipe: The recipe to build the tree around
    ///   - context: SwiftData model context
    ///   - maxDepth: Maximum number of generations to fetch (default: 10)
    /// - Returns: LineageTree with all connected recipes
    func fetchLineageTree(
        for recipe: Recipe,
        context: ModelContext,
        maxDepth: Int = 10
    ) async throws -> LineageTree {
        Log.debug("Fetching lineage tree", category: .general, metadata: ["title": recipe.title, "maxDepth": maxDepth])

        // 1. Get lineage for current recipe
        let recipeId = recipe.id
        let descriptor = FetchDescriptor<RecipeLineage>(
            predicate: #Predicate { $0.currentRecipeId == recipeId }
        )
        let localLineage = try? context.fetch(descriptor).first

        guard let lineage = localLineage else {
            // No lineage - this is a standalone recipe
            Log.debug("No lineage found for recipe", category: .general)
            let node = LineageNode(
                recipe: recipe,
                generation: 0,
                position: .zero,
                stats: NodeStats(
                    cookCount: recipe.timesCooked,
                    shareCount: recipe.totalShares,
                    viewCount: 0,
                    rating: nil
                ),
                isCurrentUser: true
            )
            return LineageTree(root: recipe, nodes: [node], edges: [])
        }

        // 2. Query Firebase for all recipes in this lineage tree
        let rootRecipeId = lineage.rootRecipeId
        Log.debug("Querying Firebase for lineage tree", category: .firebase, metadata: [
            "rootRecipeId": rootRecipeId.uuidString
        ])

        // Query global lineages collection
        let snapshot = try await db.collection("lineages")
            .whereField("rootRecipeId", isEqualTo: rootRecipeId.uuidString)
            .getDocuments()

        Log.debug("Found lineages in Firebase", category: .firebase, metadata: [
            "count": snapshot.documents.count
        ])

        // 3. Build nodes and edges from lineage data
        var nodes: [LineageNode] = []
        var edges: [LineageEdge] = []
        var recipesByGeneration: [Int: [(RecipeLineageVersion, String)]] = [:] // [(version, ownerId)]

        for doc in snapshot.documents {
            let data = doc.data()
            let recipeIdString = data["currentRecipeId"] as? String ?? ""
            let ownerId = data["ownerId"] as? String ?? ""
            let generation = data["generation"] as? Int ?? 0
            let parentRecipeIdString = data["parentRecipeId"] as? String

            guard let recipeIdUUID = UUID(uuidString: recipeIdString) else { continue }

            // Fetch recipe data from Firebase
            guard let recipeData = try? await fetchRecipeFromFirebase(
                ownerId: ownerId,
                recipeId: recipeIdUUID
            ) else {
                Log.warning("Failed to fetch recipe data", category: .firebase, metadata: [
                    "recipeId": recipeIdString,
                    "ownerId": ownerId
                ])
                continue
            }

            // Get display name for owner
            let ownerDisplayName = try? await userProfileService.fetchDisplayName(for: ownerId)

            // Create version
            let version = RecipeLineageVersion(
                recipeData: recipeData,
                generation: generation,
                modifiedBy: ownerId,
                modifiedByName: ownerDisplayName ?? "Someone",
                modifiedAt: (data["lastModified"] as? Timestamp)?.dateValue() ?? Date(),
                isCurrent: recipeIdUUID == recipeId
            )

            // Add to generation map
            if recipesByGeneration[generation] == nil {
                recipesByGeneration[generation] = []
            }
            recipesByGeneration[generation]?.append((version, ownerId))

            // Create node
            let isCurrentUser = ownerId == Auth.auth().currentUser?.uid
            let node = LineageNode(
                recipe: version.recipe ?? recipe,
                generation: generation,
                position: .zero, // Will be calculated by layout engine
                stats: NodeStats(
                    cookCount: 0,
                    shareCount: 0,
                    viewCount: 0,
                    rating: nil
                ),
                isCurrentUser: isCurrentUser
            )
            nodes.append(node)

            // Create edge from parent
            if generation > 0, let parentIdString = parentRecipeIdString,
               let parentId = UUID(uuidString: parentIdString) {
                let edge = LineageEdge(
                    fromID: parentId,
                    toID: recipeIdUUID,
                    label: nil,
                    createdAt: version.modifiedAt
                )
                edges.append(edge)
            }
        }

        // 4. Find root recipe (generation 0)
        guard let rootNode = nodes.first(where: { $0.generation == 0 }) else {
            throw LineageError.invalidProvenance
        }

        let tree = LineageTree(root: rootNode.recipe, nodes: nodes, edges: edges)

        Log.info("Built lineage tree", category: .general, metadata: [
            "nodeCount": nodes.count,
            "edgeCount": edges.count,
            "rootTitle": rootNode.recipe.title
        ])

        return tree
    }

    // MARK: - Firebase Helpers

    private func fetchRecipeFromFirebase(
        ownerId: String,
        recipeId: UUID
    ) async throws -> [String: Any] {
        // Use .server source to get fresh data
        let doc = try await db.collection("users/\(ownerId)/recipes")
            .document(recipeId.uuidString)
            .getDocument(source: .server)

        guard doc.exists, var data = doc.data() else {
            throw NSError(domain: "RecipeLineageService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Recipe not found"
            ])
        }

        // Fetch ingredients subcollection
        let ingredientsSnapshot = try await db.collection("users/\(ownerId)/recipes")
            .document(recipeId.uuidString)
            .collection("ingredients")
            .getDocuments(source: .server)

        let ingredients = ingredientsSnapshot.documents.map { $0.data() }
        if !ingredients.isEmpty {
            data["ingredients"] = ingredients
        }

        return data
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
