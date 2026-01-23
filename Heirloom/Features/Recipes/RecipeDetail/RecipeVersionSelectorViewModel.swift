import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth

@MainActor
class RecipeVersionSelectorViewModel: ObservableObject {
    @Published var versions: [RecipeLineageVersion] = []
    @Published var selectedVersion: RecipeLineageVersion?
    @Published var isLoading = false
    @Published var error: String?

    private lazy var db: Firestore = {
        // Use shared Firestore instance (configured by FirebaseSyncService)
        Firestore.firestore()
    }()

    private let userProfileService: FirebaseUserProfileService

    init(userProfileService: FirebaseUserProfileService? = nil) {
        self.userProfileService = userProfileService ?? ServiceContainer.shared.resolve(FirebaseUserProfileService.self)
    }

    /// Load all versions of a recipe (original + all descendant modifications)
    func loadVersions(for recipe: Recipe, context: ModelContext) async {
        Log.debug("Loading recipe versions", category: .firebase, metadata: ["title": recipe.title])
        isLoading = true
        error = nil

        do {
            // 1. First check local SwiftData for lineage
            let recipeId = recipe.id
            let descriptor = FetchDescriptor<RecipeLineage>(
                predicate: #Predicate { $0.currentRecipeId == recipeId }
            )
            let localLineage = try? context.fetch(descriptor).first

            if localLineage != nil {
                Log.debug("Found lineage in local SwiftData", category: .firebase)
            }

            // 2. If no local lineage, try Firebase
            var lineage = localLineage
            if lineage == nil {
                lineage = try? await fetchLineage(for: recipe.id)
            }

            guard let lineage = lineage else {
                // No lineage tracking - this is a standalone recipe
                Log.debug("No lineage found (checked local SwiftData and Firebase)", category: .firebase)
                let currentVersion = RecipeLineageVersion(
                    recipe: recipe,
                    generation: 0,
                    modifiedBy: nil,
                    modifiedByName: nil,
                    modifiedAt: recipe.lastModified,
                    isCurrent: true
                )
                versions = [currentVersion]
                selectedVersion = currentVersion
                isLoading = false
                return
            }

            // 2. This recipe has lineage - fetch all versions in the family tree
            var allVersions: [RecipeLineageVersion] = []

            // Add current local version
            // Fetch correct display name for current owner (not sharedByName which is the previous sharer)
            let ownerDisplayName: String?
            do {
                ownerDisplayName = try await userProfileService.fetchDisplayName(for: lineage.ownerId)
                if ownerDisplayName == nil {
                    Log.warning("No display name found for current recipe owner", category: .firebase, metadata: [
                        "ownerId": lineage.ownerId,
                        "generation": lineage.generation
                    ])
                }
            } catch {
                Log.error("Failed to fetch current owner display name", category: .firebase, metadata: [
                    "ownerId": lineage.ownerId,
                    "error": error.localizedDescription
                ])
                ownerDisplayName = nil
            }

            let currentVersion = RecipeLineageVersion(
                recipe: recipe,
                generation: lineage.generation,
                modifiedBy: lineage.ownerId,
                modifiedByName: ownerDisplayName ?? "Someone",
                modifiedAt: recipe.lastModified,
                isCurrent: true
            )
            allVersions.append(currentVersion)

            // 3. Fetch all other versions from the lineage tree
            let otherVersions = try await fetchOtherVersions(
                rootRecipeId: lineage.rootRecipeId,
                currentRecipeId: recipe.id
            )
            allVersions.append(contentsOf: otherVersions)

            // 4. Sort by generation (root first, then descendants)
            allVersions.sort { $0.generation < $1.generation }

            versions = allVersions

            // 5. Set selected version based on last viewed, or default to current
            if let lastViewedId = recipe.lastViewedVersionId,
               let lastViewed = allVersions.first(where: { $0.recipe?.id == lastViewedId }) {
                selectedVersion = lastViewed
                Log.debug("Restored last viewed version", category: .firebase, metadata: ["version": lastViewed.displayName])
            } else {
                selectedVersion = currentVersion
                Log.debug("Defaulting to current version", category: .firebase)
            }

        } catch {
            self.error = "Failed to load versions: \(error.localizedDescription)"
            Log.error("Error loading recipe versions", category: .firebase, metadata: ["error": error.localizedDescription])
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    /// Batch fetch display names for multiple owner IDs
    /// Uses concurrent fetching for performance
    private func fetchDisplayNames(for ownerIds: Set<String>) async -> [String: String] {
        await withTaskGroup(of: (String, String?).self) { group in
            var displayNames: [String: String] = [:]

            // Launch concurrent fetch tasks
            for ownerId in ownerIds {
                group.addTask { [weak self] in
                    guard let self = self else { return (ownerId, nil) }
                    let name = try? await self.userProfileService.fetchDisplayName(for: ownerId)
                    return (ownerId, name)
                }
            }

            // Collect results
            for await (ownerId, name) in group {
                if let name = name {
                    displayNames[ownerId] = name
                } else {
                    Log.warning("No display name found for owner", category: .firebase, metadata: ["ownerId": ownerId])
                }
            }

            return displayNames
        }
    }

    private func fetchLineage(for recipeId: UUID) async throws -> RecipeLineage? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }

        Log.debug("Fetching lineage for recipe", category: .firebase, metadata: ["recipeId": recipeId.uuidString])

        // First try: User's own lineages collection
        let userSnapshot = try await db.collection("users/\(userId)/lineages")
            .whereField("currentRecipeId", isEqualTo: recipeId.uuidString)
            .limit(to: 1)
            .getDocuments()

        var doc = userSnapshot.documents.first

        if doc != nil {
            Log.debug("Found lineage in user's collection", category: .firebase)
        } else {
            // Second try: Global lineages index
            Log.debug("Checking global lineages collection", category: .firebase)
            let globalSnapshot = try await db.collection("lineages")
                .whereField("currentRecipeId", isEqualTo: recipeId.uuidString)
                .limit(to: 1)
                .getDocuments()
            doc = globalSnapshot.documents.first

            if doc != nil {
                Log.debug("Found lineage in global collection", category: .firebase)
            }
        }

        guard let lineageDoc = doc else {
            Log.debug("No lineage document found in Firebase (checked both user and global collections)", category: .firebase)
            return nil
        }

        let data = lineageDoc.data()
        Log.debug("Found lineage for recipe", category: .firebase, metadata: ["generation": data["generation"] as? Int ?? 0])

        // Create RecipeLineage from Firebase data
        let lineage = RecipeLineage(
            rootRecipeId: UUID(uuidString: data["rootRecipeId"] as? String ?? "") ?? recipeId,
            currentRecipeId: recipeId,
            ownerId: data["ownerId"] as? String ?? "",
            rootOwnerId: data["rootOwnerId"] as? String ?? "",
            generation: data["generation"] as? Int ?? 0
        )
        lineage.firebaseId = lineageDoc.documentID
        lineage.sharedByName = data["sharedByName"] as? String

        return lineage
    }

    private func fetchOtherVersions(
        rootRecipeId: UUID,
        currentRecipeId: UUID
    ) async throws -> [RecipeLineageVersion] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }

        Log.debug("Fetching versions for root recipe", category: .firebase, metadata: [
            "rootRecipeId": rootRecipeId.uuidString,
            "currentRecipeId": currentRecipeId.uuidString,
            "userId": userId
        ])

        // Try both global lineages and user-specific lineages
        // First query: Global lineages collection
        let globalSnapshot = try await db.collection("lineages")
            .whereField("rootRecipeId", isEqualTo: rootRecipeId.uuidString)
            .getDocuments()

        Log.debug("Global lineages query result", category: .firebase, metadata: [
            "documentCount": globalSnapshot.documents.count
        ])

        // Second query: Check if root owner has their lineage in users collection
        // We need to get the rootOwnerId first from our own lineage
        let ownLineageSnapshot = try await db.collection("users/\(userId)/lineages")
            .whereField("currentRecipeId", isEqualTo: currentRecipeId.uuidString)
            .limit(to: 1)
            .getDocuments()

        var rootOwnerId: String? = nil
        if let ownDoc = ownLineageSnapshot.documents.first {
            rootOwnerId = ownDoc.data()["rootOwnerId"] as? String
            Log.debug("Found own lineage", category: .firebase, metadata: [
                "rootOwnerId": rootOwnerId ?? "nil",
                "generation": ownDoc.data()["generation"] as? Int ?? 0
            ])
        }

        // Query root owner's lineages from GLOBAL collection (readable by all authenticated users)
        // This avoids permission denied errors when viewing shared recipes
        var rootOwnerSnapshot: QuerySnapshot? = nil
        if let rootOwnerId = rootOwnerId {
            rootOwnerSnapshot = try? await db.collection("lineages")
                .whereField("ownerId", isEqualTo: rootOwnerId)
                .whereField("currentRecipeId", isEqualTo: rootRecipeId.uuidString)
                .limit(to: 1)
                .getDocuments()

            Log.debug("Root owner lineages query result (from global collection)", category: .firebase, metadata: [
                "documentCount": rootOwnerSnapshot?.documents.count ?? 0,
                "rootOwnerId": rootOwnerId
            ])
        }

        var versions: [RecipeLineageVersion] = []
        // Track unique versions to prevent duplicates (by ownerId + recipeId + generation)
        var seenVersions: Set<String> = []

        // Process global lineages
        for doc in globalSnapshot.documents {
            let data = doc.data()
            let recipeIdString = data["currentRecipeId"] as? String ?? ""
            let ownerId = data["ownerId"] as? String ?? ""
            let generation = data["generation"] as? Int ?? 0

            // FIXED: Use ownerId filtering instead of recipeId to handle immutable IDs
            // When immutable IDs are used, multiple devices can have recipes with the same ID
            // but different owners. We want to include all other owners' versions.
            guard let recipeId = UUID(uuidString: recipeIdString) else { continue }

            // Skip our own lineage (but include all other owners, even with same recipe ID)
            guard ownerId != userId else {
                Log.debug("Skipping own lineage", category: .firebase, metadata: [
                    "ownerId": ownerId,
                    "generation": generation
                ])
                continue
            }

            // Create unique key to prevent duplicates (ownerId + recipeId + generation)
            let versionKey = "\(ownerId)_\(recipeId.uuidString)_\(generation)"
            guard !seenVersions.contains(versionKey) else {
                Log.debug("Skipping duplicate version", category: .firebase, metadata: [
                    "ownerId": ownerId,
                    "recipeId": recipeId.uuidString,
                    "generation": generation,
                    "reason": "already added from different query path"
                ])
                continue
            }

            Log.debug("Processing global lineage", category: .firebase, metadata: [
                "ownerId": ownerId,
                "recipeId": recipeId.uuidString,
                "generation": generation
            ])

            // Fetch the actual recipe data from Firebase
            if let recipeData = try? await fetchRecipeFromFirebase(
                ownerId: ownerId,
                recipeId: recipeId
            ) {
                // Extract ingredients for logging
                let ingredientsData = recipeData["ingredients"] as? [[String: Any]] ?? []
                let ingredientTexts = ingredientsData.compactMap { $0["originalText"] as? String }

                // Fetch correct display name for owner (not sharedByName which is the previous sharer)
                let ownerDisplayName: String?
                do {
                    ownerDisplayName = try await userProfileService.fetchDisplayName(for: ownerId)
                    if ownerDisplayName == nil {
                        Log.warning("No display name found for owner", category: .firebase, metadata: [
                            "ownerId": ownerId,
                            "generation": generation
                        ])
                    }
                } catch {
                    Log.error("Failed to fetch display name", category: .firebase, metadata: [
                        "ownerId": ownerId,
                        "error": error.localizedDescription
                    ])
                    ownerDisplayName = nil
                }

                let version = RecipeLineageVersion(
                    recipeData: recipeData,
                    generation: generation,
                    modifiedBy: ownerId,
                    modifiedByName: ownerDisplayName ?? "Someone",
                    modifiedAt: (data["lastModified"] as? Timestamp)?.dateValue() ?? Date(),
                    isCurrent: false
                )
                versions.append(version)
                seenVersions.insert(versionKey)  // Mark as seen
                Log.debug("Added version from global lineage", category: .firebase, metadata: [
                    "generation": generation,
                    "ownerId": ownerId,
                    "ingredientCount": ingredientTexts.count,
                    "ingredients": ingredientTexts.joined(separator: " | ")
                ])
            } else {
                Log.warning("Failed to fetch recipe data for version", category: .firebase, metadata: [
                    "ownerId": ownerId,
                    "recipeId": recipeId.uuidString
                ])
            }
        }

        // Process root owner's lineage if found
        if let rootOwnerSnapshot = rootOwnerSnapshot {
            for doc in rootOwnerSnapshot.documents {
                let data = doc.data()
                let recipeIdString = data["currentRecipeId"] as? String ?? ""
                let ownerId = data["ownerId"] as? String ?? ""
                let generation = data["generation"] as? Int ?? 0

                // FIXED: Use ownerId filtering to handle immutable IDs
                guard let recipeId = UUID(uuidString: recipeIdString) else { continue }

                // Skip if this is our own lineage (shouldn't happen here since we're querying root owner)
                guard ownerId != userId else {
                    Log.debug("Skipping own lineage in root owner query", category: .firebase, metadata: [
                        "ownerId": ownerId,
                        "generation": generation
                    ])
                    continue
                }

                // Only include if this is the root recipe (generation 0)
                guard recipeId == rootRecipeId else {
                    Log.debug("Skipping non-root recipe", category: .firebase, metadata: [
                        "recipeId": recipeId.uuidString,
                        "rootRecipeId": rootRecipeId.uuidString
                    ])
                    continue
                }

                // Create unique key to prevent duplicates (ownerId + recipeId + generation)
                let versionKey = "\(ownerId)_\(recipeId.uuidString)_\(generation)"
                guard !seenVersions.contains(versionKey) else {
                    Log.debug("Skipping duplicate root owner version", category: .firebase, metadata: [
                        "ownerId": ownerId,
                        "recipeId": recipeId.uuidString,
                        "generation": generation,
                        "reason": "already added from global lineages query"
                    ])
                    continue
                }

                Log.debug("Processing root owner lineage", category: .firebase, metadata: [
                    "ownerId": ownerId,
                    "recipeId": recipeId.uuidString,
                    "generation": generation
                ])

                // Fetch the actual recipe data from Firebase
                if let recipeData = try? await fetchRecipeFromFirebase(
                    ownerId: ownerId,
                    recipeId: recipeId
                ) {
                    // Fetch correct display name for owner (not sharedByName which is the previous sharer)
                    let ownerDisplayName: String?
                    do {
                        ownerDisplayName = try await userProfileService.fetchDisplayName(for: ownerId)
                        if ownerDisplayName == nil {
                            Log.warning("No display name found for root owner", category: .firebase, metadata: [
                                "ownerId": ownerId,
                                "generation": generation
                            ])
                        }
                    } catch {
                        Log.error("Failed to fetch root owner display name", category: .firebase, metadata: [
                            "ownerId": ownerId,
                            "error": error.localizedDescription
                        ])
                        ownerDisplayName = nil
                    }

                    let version = RecipeLineageVersion(
                        recipeData: recipeData,
                        generation: generation,
                        modifiedBy: ownerId,
                        modifiedByName: ownerDisplayName ?? "Someone",
                        modifiedAt: (data["lastModified"] as? Timestamp)?.dateValue() ?? Date(),
                        isCurrent: false
                    )
                    versions.append(version)
                    seenVersions.insert(versionKey)  // Mark as seen
                    Log.debug("Added root owner version", category: .firebase, metadata: [
                        "generation": generation,
                        "ownerId": ownerId
                    ])
                } else {
                    Log.warning("Failed to fetch root recipe data", category: .firebase, metadata: [
                        "ownerId": ownerId,
                        "recipeId": recipeId.uuidString
                    ])
                }
            }
        }

        Log.debug("Found other recipe versions", category: .firebase, metadata: ["count": versions.count])
        return versions
    }

    private func fetchRecipeFromFirebase(
        ownerId: String,
        recipeId: UUID
    ) async throws -> [String: Any] {
        // CRITICAL: Use .server source to get fresh data, not stale cache
        // This ensures we see the latest edits from other devices
        let doc = try await db.collection("users/\(ownerId)/recipes")
            .document(recipeId.uuidString)
            .getDocument(source: .server)

        guard doc.exists, var data = doc.data() else {
            throw NSError(domain: "RecipeVersions", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Recipe not found"
            ])
        }

        // Fetch ingredients subcollection (also from server, not cache)
        let ingredientsSnapshot = try await db.collection("users/\(ownerId)/recipes")
            .document(recipeId.uuidString)
            .collection("ingredients")
            .getDocuments(source: .server)

        let ingredients = ingredientsSnapshot.documents.map { $0.data() }
        if !ingredients.isEmpty {
            data["ingredients"] = ingredients
            Log.debug("Fetched ingredients for recipe version", category: .firebase, metadata: ["count": ingredients.count])
        }

        return data
    }
}

// MARK: - RecipeLineageVersion Model

struct RecipeLineageVersion: Identifiable, Hashable {
    let id = UUID()
    let recipe: Recipe?
    let recipeData: [String: Any]?
    let generation: Int
    let modifiedBy: String?
    let modifiedByName: String?
    let modifiedAt: Date
    let isCurrent: Bool

    var title: String {
        recipe?.title ?? recipeData?["title"] as? String ?? "Unknown"
    }

    var displayName: String {
        if generation == 0 {
            return "Original"
        } else if isCurrent {
            return "Your Version (Gen \(generation))"
        } else {
            let name = modifiedByName ?? "Someone"
            return "\(name)'s Version (Gen \(generation))"
        }
    }

    /// Compact timestamp for UI (e.g., "2d ago", "3mo ago")
    var compactTimestamp: String {
        let now = Date()
        let interval = now.timeIntervalSince(modifiedAt)

        let seconds = Int(interval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7
        let months = days / 30
        let years = days / 365

        if years > 0 {
            return "\(years)y ago"
        } else if months > 0 {
            return "\(months)mo ago"
        } else if weeks > 0 {
            return "\(weeks)w ago"
        } else if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }

    init(recipe: Recipe, generation: Int, modifiedBy: String?, modifiedByName: String?, modifiedAt: Date, isCurrent: Bool) {
        self.recipe = recipe
        self.recipeData = nil
        self.generation = generation
        self.modifiedBy = modifiedBy
        self.modifiedByName = modifiedByName
        self.modifiedAt = modifiedAt
        self.isCurrent = isCurrent
    }

    init(recipeData: [String: Any], generation: Int, modifiedBy: String?, modifiedByName: String?, modifiedAt: Date, isCurrent: Bool) {
        self.recipe = nil
        self.recipeData = recipeData
        self.generation = generation
        self.modifiedBy = modifiedBy
        self.modifiedByName = modifiedByName
        self.modifiedAt = modifiedAt
        self.isCurrent = isCurrent
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RecipeLineageVersion, rhs: RecipeLineageVersion) -> Bool {
        lhs.id == rhs.id
    }
}
