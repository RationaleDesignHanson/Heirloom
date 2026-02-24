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
    private let connectionService: ConnectionServiceProtocol

    init(
        userProfileService: FirebaseUserProfileService? = nil,
        connectionService: ConnectionServiceProtocol? = nil
    ) {
        self.userProfileService = userProfileService ?? ServiceContainer.shared.resolve(FirebaseUserProfileService.self)
        self.connectionService = connectionService ?? ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
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

        // 1. Get lineage for current recipe - first try local, then Firebase
        let recipeId = recipe.id
        let descriptor = FetchDescriptor<RecipeLineage>(
            predicate: #Predicate { $0.currentRecipeId == recipeId }
        )
        let localLineage = try? context.fetch(descriptor).first

        // 2. Determine rootRecipeId - from local lineage or Firebase lookup
        let rootRecipeId: UUID

        if let lineage = localLineage {
            rootRecipeId = lineage.rootRecipeId
            Log.debug("Found local lineage", category: .general, metadata: [
                "rootRecipeId": rootRecipeId.uuidString
            ])
        } else {
            // No local lineage - try Firebase directly
            // This can happen if the lineage wasn't properly created during share acceptance
            Log.debug("No local lineage, checking Firebase", category: .firebase)

            let firebaseLineage = try await db.collection("lineages")
                .whereField("currentRecipeId", isEqualTo: recipeId.firebaseString)
                .limit(to: 1)
                .getDocuments()

            if let doc = firebaseLineage.documents.first,
               let rootRecipeIdString = doc.data()["rootRecipeId"] as? String,
               let fetchedRootId = UUID(uuidString: rootRecipeIdString) {
                rootRecipeId = fetchedRootId
                Log.info("Found lineage in Firebase (missing locally)", category: .firebase, metadata: [
                    "rootRecipeId": rootRecipeIdString
                ])
            } else {
                // No lineage anywhere - this is a standalone recipe
                Log.debug("No lineage found for recipe", category: .general)

                // Fetch contributor if recipe has sharedBy
                var contributorInfo: ContributorInfo?
                if let sharedBy = recipe.sharedBy, !sharedBy.isEmpty {
                    // Legacy: sharedBy is just a name, not a userId
                    contributorInfo = ContributorInfo(displayName: sharedBy)
                }

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
                    isCurrentUser: true,
                    contributor: contributorInfo
                )
                return LineageTree(root: recipe, nodes: [node], edges: [])
            }
        }

        // 3. Query Firebase for all recipes in this lineage tree (by rootRecipeId)
        Log.debug("Querying Firebase for lineage tree", category: .firebase, metadata: [
            "rootRecipeId": rootRecipeId.uuidString
        ])

        // Query global lineages collection
        // IMPORTANT: Use firebaseString (lowercase) to match document field values
        let snapshot = try await db.collection("lineages")
            .whereField("rootRecipeId", isEqualTo: rootRecipeId.firebaseString)
            .getDocuments()

        Log.info("Found lineages in Firebase for family tree", category: .firebase, metadata: [
            "count": snapshot.documents.count,
            "rootRecipeId": rootRecipeId.uuidString
        ])

        // Heritage chain filtering for demo user sanitization ONLY
        // The heritageChain is frozen at share acceptance time and only contains ancestors.
        // For real-user chains, we query Firebase by rootRecipeId to show ALL nodes (ancestors + descendants).
        // We only apply the heritageChain filter if it contains demo users that need to be hidden.
        let originalHeritageChain = recipe.heritageChain ?? []
        let containsDemoUsers = originalHeritageChain.contains { $0.hasPrefix("demo_") }
        let hasHeritageChainFilter = containsDemoUsers && !originalHeritageChain.isEmpty
        var allowedOwnerIds: Set<String>? = nil
        if hasHeritageChainFilter {
            allowedOwnerIds = Set(originalHeritageChain)
            if let currentUserId = Auth.auth().currentUser?.uid {
                allowedOwnerIds?.insert(currentUserId)
            }
            Log.info("Heritage chain filter active for lineage tree (demo sanitization)", category: .firebase, metadata: [
                "allowedOwners": allowedOwnerIds?.count ?? 0,
                "heritageChain": originalHeritageChain.joined(separator: ", ")
            ])
        }

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

            // Filter by heritage chain ONLY for demo user sanitization
            // When a recipe is shared to real users, demo users are removed from heritageChain
            // For real-user chains, allowedOwnerIds is nil and we show all nodes from Firebase
            if let allowedOwnerIds = allowedOwnerIds, !allowedOwnerIds.contains(ownerId) {
                Log.debug("Filtering out lineage node not in heritage chain (demo sanitization)", category: .firebase, metadata: [
                    "ownerId": ownerId,
                    "generation": generation,
                    "reason": "owner not in sanitized heritage chain"
                ])
                continue
            }

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

            // Fetch contributor info (Phase 8)
            Log.debug("Fetching contributor info for lineage node", category: .social, metadata: [
                "ownerId": ownerId,
                "generation": generation
            ])
            let contributorInfo = await fetchContributorInfo(userId: ownerId)

            // Create version (stores raw recipeData for diff view)
            let modifiedAt = (data["lastModified"] as? Timestamp)?.dateValue() ?? Date()
            let displayName = ownerDisplayName ?? contributorInfo?.displayName ?? "Someone"
            let version = RecipeLineageVersion(
                recipeData: recipeData,
                generation: generation,
                modifiedBy: ownerId,
                modifiedByName: displayName,
                modifiedAt: modifiedAt,
                isCurrent: recipeIdUUID == recipeId
            )

            // Add to generation map
            if recipesByGeneration[generation] == nil {
                recipesByGeneration[generation] = []
            }
            recipesByGeneration[generation]?.append((version, ownerId))

            // Build the display Recipe for this node
            // For the current user's local recipe, use the actual SwiftData object
            // For remote nodes, create a Recipe from the Firebase data
            let isCurrentUser = ownerId == Auth.auth().currentUser?.uid
            let displayRecipe: Recipe
            if isCurrentUser && recipeIdUUID == recipeId {
                displayRecipe = recipe
            } else {
                displayRecipe = Self.createRecipeFromFirebaseData(recipeData, recipeId: recipeIdUUID)
            }

            // Extract real stats from Firebase data
            let cookCount = recipeData["timesCooked"] as? Int ?? 0
            let shareCount = recipeData["publicSaveCount"] as? Int ?? 0
            let viewCount = recipeData["publicViewCount"] as? Int ?? 0

            let node = LineageNode(
                recipe: displayRecipe,
                generation: generation,
                position: .zero,
                stats: NodeStats(
                    cookCount: cookCount,
                    shareCount: shareCount,
                    viewCount: viewCount,
                    rating: nil
                ),
                isCurrentUser: isCurrentUser,
                contributor: contributorInfo,
                version: version
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
            .document(recipeId.firebaseString)
            .getDocument(source: .server)

        guard doc.exists, var data = doc.data() else {
            throw NSError(domain: "RecipeLineageService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Recipe not found"
            ])
        }

        // Fetch ingredients subcollection
        let ingredientsSnapshot = try await db.collection("users/\(ownerId)/recipes")
            .document(recipeId.firebaseString)
            .collection("ingredients")
            .getDocuments(source: .server)

        let ingredients = ingredientsSnapshot.documents.map { $0.data() }
        if !ingredients.isEmpty {
            data["ingredients"] = ingredients
        }

        return data
    }

    // MARK: - Recipe Construction from Firebase Data

    /// Create a lightweight Recipe object from Firebase dictionary data for lineage display.
    /// This Recipe is NOT inserted into any ModelContext — it's display-only for the lineage tree.
    static func createRecipeFromFirebaseData(_ data: [String: Any], recipeId: UUID) -> Recipe {
        let title = data["title"] as? String ?? "Unknown"
        let sourceTypeRaw = data["sourceType"] as? String
        let sourceType = sourceTypeRaw.flatMap { RecipeSourceType(rawValue: $0) } ?? .manual

        let recipe = Recipe(
            title: title,
            sourceType: sourceType,
            sourceURL: data["sourceURL"] as? String,
            instructions: data["instructions"] as? [String] ?? [],
            servings: data["servings"] as? String,
            prepTime: data["prepTime"] as? String,
            cookTime: data["cookTime"] as? String
        )
        recipe.id = recipeId
        recipe.imageFileName = data["imageFileName"] as? String
        recipe.firebaseImageURL = data["firebaseImageURL"] as? String
        recipe.notes = data["notes"] as? String
        recipe.timesCooked = data["timesCooked"] as? Int ?? 0

        if let dateTimestamp = data["dateAdded"] as? Timestamp {
            recipe.dateAdded = dateTimestamp.dateValue()
        } else if let dateString = data["dateAdded"] as? String,
                  let date = ISO8601DateFormatter().date(from: dateString) {
            recipe.dateAdded = date
        }

        return recipe
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

    // MARK: - Contributor Info (Phase 8)

    /// Fetch contributor information including profile and connection status
    private func fetchContributorInfo(userId: String) async -> ContributorInfo? {
        guard !userId.isEmpty else { return nil }

        // Handle demo users - use hardcoded info
        if userId.hasPrefix("demo_") {
            if let demoInfo = DemoSocialBehaviorService.demoUserInfo[userId] {
                Log.debug("Using hardcoded demo user info for contributor", category: .firebase, metadata: [
                    "userId": userId,
                    "displayName": demoInfo.displayName
                ])
                return ContributorInfo(
                    userId: userId,
                    displayName: demoInfo.displayName,
                    avatarURL: demoInfo.photoURL,
                    isConnected: true // Demo users are always "connected"
                )
            } else {
                Log.warning("Demo user not found in hardcoded data", category: .firebase, metadata: ["userId": userId])
                return nil
            }
        }

        do {
            // Fetch display name from user profile service
            guard let displayName = try await userProfileService.fetchDisplayName(for: userId) else {
                Log.warning("No display name found for user", category: .firebase, metadata: ["userId": userId])
                return nil
            }

            // Check if user is connected by fetching all connections
            // This is not ideal performance-wise but works with current APIs
            var isConnected = false
            if Auth.auth().currentUser?.uid != nil {
                do {
                    let connections = try await connectionService.fetchConnections(status: .connected, forceRefresh: false)
                    isConnected = connections.contains { $0.connectedUserId == userId }
                } catch {
                    Log.debug("Could not check connection status", category: .firebase, metadata: ["error": error.localizedDescription])
                    // Continue with isConnected = false
                }
            }

            let contributorInfo = ContributorInfo(
                userId: userId,
                displayName: displayName,
                avatarURL: nil, // Not available from FirebaseUserProfileService
                isConnected: isConnected
            )

            Log.info("✅ Phase 8: Contributor loaded", category: .social, metadata: [
                "userId": userId,
                "displayName": displayName,
                "isConnected": isConnected
            ])

            return contributorInfo
        } catch {
            Log.warning("Failed to fetch contributor info", category: .firebase, metadata: [
                "userId": userId,
                "error": error.localizedDescription
            ])
            return nil
        }
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
