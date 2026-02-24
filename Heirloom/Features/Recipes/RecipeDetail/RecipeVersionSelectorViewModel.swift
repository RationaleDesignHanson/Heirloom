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

            // Heritage chain filtering for demo user sanitization ONLY
            // The heritageChain is frozen at share acceptance time and only contains ancestors.
            // For real-user chains, we query Firebase by rootRecipeId to show ALL versions (ancestors + descendants).
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
                Log.debug("Heritage chain filter active (demo sanitization)", category: .firebase, metadata: [
                    "allowedOwners": allowedOwnerIds?.count ?? 0
                ])
            }

            // 2. If no local lineage, try Firebase
            var lineage = localLineage
            if lineage == nil {
                lineage = try? await fetchLineage(for: recipe.id)
            }

            if lineage == nil {
                // No lineage tracking for THIS recipe - but there might be descendants
                // (e.g., user created recipe, shared it, and someone modified it)
                Log.debug("No lineage found for current recipe, checking for descendants", category: .firebase)

                // Check if there are any descendants (lineage records where rootRecipeId = this recipe)
                let descendants = try await fetchDescendants(for: recipe.id)

                if descendants.isEmpty {
                    // Truly standalone recipe with no lineage
                    Log.debug("No descendants found either - standalone recipe", category: .firebase)
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

                // This is a Gen 0 recipe with descendants - show them all
                Log.debug("Found descendants for Gen 0 recipe", category: .firebase, metadata: ["count": descendants.count])

                // Get current user's display name for Gen 0
                guard let userId = Auth.auth().currentUser?.uid else {
                    isLoading = false
                    return
                }
                let ownerDisplayName = try? await userProfileService.fetchDisplayName(for: userId)

                let currentVersion = RecipeLineageVersion(
                    recipe: recipe,
                    generation: 0,
                    modifiedBy: userId,
                    modifiedByName: ownerDisplayName ?? "Original",
                    modifiedAt: recipe.lastModified,
                    isCurrent: true
                )

                var allVersions = [currentVersion]
                allVersions.append(contentsOf: descendants)
                allVersions.sort { $0.generation < $1.generation }

                versions = allVersions
                selectedVersion = currentVersion
                isLoading = false
                return
            }

            guard let lineage = lineage else {
                // This shouldn't happen after the check above, but satisfy the compiler
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
            // Pass allowed owners to filter out demo users (only when demo users are present)
            let otherVersions = try await fetchOtherVersions(
                rootRecipeId: lineage.rootRecipeId,
                currentRecipeId: recipe.id,
                allowedOwnerIds: allowedOwnerIds
            )

            // 3.5. Deduplicate - filter out versions that match current user
            // This prevents showing duplicate entries when the current user's version
            // also exists in Firebase lineage records (possibly with different generation
            // due to local vs Firebase data discrepancy)
            // A user can only have ONE version of a recipe, so filter by owner ID alone
            let currentUserId = Auth.auth().currentUser?.uid
            let filteredOtherVersions = otherVersions.filter { version in
                // If this version belongs to the current user, filter it out
                // (the current user's version is already shown as currentVersion)
                if let userId = currentUserId, version.modifiedBy == userId {
                    return false
                }
                // Also filter out exact duplicates (same owner + same generation)
                return !(version.modifiedBy == currentVersion.modifiedBy &&
                         version.generation == currentVersion.generation)
            }

            let removedCount = otherVersions.count - filteredOtherVersions.count
            if removedCount > 0 {
                Log.debug("Deduplicated versions matching current recipe", category: .firebase, metadata: [
                    "removedCount": removedCount,
                    "currentGeneration": currentVersion.generation,
                    "currentOwnerId": currentVersion.modifiedBy ?? "nil"
                ])
            }

            allVersions.append(contentsOf: filteredOtherVersions)

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

    /// Get display name for an owner, handling demo users specially
    private func getDisplayName(for ownerId: String) async -> String? {
        // Handle demo users - use hardcoded display names
        if ownerId.hasPrefix("demo_"),
           let demoInfo = DemoSocialBehaviorService.demoUserInfo[ownerId] {
            return demoInfo.displayName
        }
        // For real users, fetch from Firebase
        return try? await userProfileService.fetchDisplayName(for: ownerId)
    }

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
        // IMPORTANT: Use firebaseString (lowercase) to match document field values
        let userSnapshot = try await db.collection("users/\(userId)/lineages")
            .whereField("currentRecipeId", isEqualTo: recipeId.firebaseString)
            .limit(to: 1)
            .getDocuments()

        var doc = userSnapshot.documents.first

        if doc != nil {
            Log.debug("Found lineage in user's collection", category: .firebase)
        } else {
            // Second try: Global lineages index
            Log.debug("Checking global lineages collection", category: .firebase)
            let globalSnapshot = try await db.collection("lineages")
                .whereField("currentRecipeId", isEqualTo: recipeId.firebaseString)
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

    /// Fetch descendants of a recipe (lineage records where this recipe is the root)
    /// Used when viewing a Gen 0 recipe to find modifications made by recipients
    private func fetchDescendants(for recipeId: UUID) async throws -> [RecipeLineageVersion] {
        Log.debug("Fetching descendants for recipe", category: .firebase, metadata: ["recipeId": recipeId.uuidString])

        // Query global lineages where rootRecipeId matches this recipe
        // This finds all recipes that descend from this one
        let snapshot = try await db.collection("lineages")
            .whereField("rootRecipeId", isEqualTo: recipeId.firebaseString)
            .getDocuments()

        Log.debug("Descendants query result", category: .firebase, metadata: ["count": snapshot.documents.count])

        var versions: [RecipeLineageVersion] = []

        for doc in snapshot.documents {
            let data = doc.data()
            let descendantRecipeIdString = data["currentRecipeId"] as? String ?? ""
            let ownerId = data["ownerId"] as? String ?? ""
            let generation = data["generation"] as? Int ?? 0

            guard let descendantRecipeId = UUID(uuidString: descendantRecipeIdString) else { continue }

            // Skip if this is pointing to the same recipe (Gen 0 lineage shouldn't exist, but just in case)
            guard descendantRecipeId != recipeId || generation > 0 else { continue }

            Log.debug("Processing descendant", category: .firebase, metadata: [
                "ownerId": ownerId,
                "recipeId": descendantRecipeIdString,
                "generation": generation
            ])

            // Fetch the actual recipe data from Firebase
            if let recipeData = try? await fetchRecipeFromFirebase(ownerId: ownerId, recipeId: descendantRecipeId) {
                let ownerDisplayName = await getDisplayName(for: ownerId)

                let version = RecipeLineageVersion(
                    recipeData: recipeData,
                    generation: generation,
                    modifiedBy: ownerId,
                    modifiedByName: ownerDisplayName ?? "Someone",
                    modifiedAt: (data["lastModified"] as? Timestamp)?.dateValue() ?? Date(),
                    isCurrent: false
                )
                versions.append(version)
                Log.debug("Added descendant version", category: .firebase, metadata: [
                    "generation": generation,
                    "ownerId": ownerId
                ])
            } else {
                Log.warning("Failed to fetch descendant recipe data", category: .firebase, metadata: [
                    "ownerId": ownerId,
                    "recipeId": descendantRecipeIdString
                ])
            }
        }

        return versions
    }

    private func fetchOtherVersions(
        rootRecipeId: UUID,
        currentRecipeId: UUID,
        allowedOwnerIds: Set<String>? = nil
    ) async throws -> [RecipeLineageVersion] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }

        Log.debug("Fetching versions for root recipe", category: .firebase, metadata: [
            "rootRecipeId": rootRecipeId.uuidString,
            "currentRecipeId": currentRecipeId.uuidString,
            "userId": userId,
            "allowedOwnerIdsCount": allowedOwnerIds?.count ?? -1
        ])

        // Try both global lineages and user-specific lineages
        // First query: Global lineages collection
        // IMPORTANT: Use firebaseString (lowercase) to match document field values
        let globalSnapshot = try await db.collection("lineages")
            .whereField("rootRecipeId", isEqualTo: rootRecipeId.firebaseString)
            .getDocuments()

        Log.debug("Global lineages query result", category: .firebase, metadata: [
            "documentCount": globalSnapshot.documents.count
        ])

        // Second query: Check if root owner has their lineage in users collection
        // We need to get the rootOwnerId first from our own lineage
        let ownLineageSnapshot = try await db.collection("users/\(userId)/lineages")
            .whereField("currentRecipeId", isEqualTo: currentRecipeId.firebaseString)
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
                .whereField("currentRecipeId", isEqualTo: rootRecipeId.firebaseString)
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

            // FIXED: Show all generations regardless of ownership
            // Multi-generation chains can circle back to the same user (Gen 0 → Gen 1 → Gen 2 back to Gen 0's owner)
            // We want to show ALL generations in the version dropdown
            guard let recipeId = UUID(uuidString: recipeIdString) else { continue }

            // Filter by heritage chain if provided (sanitization filter)
            // When a recipe is shared to real users, demo users are removed from heritageChain
            // We only show versions from users that are in the recipient's heritage chain
            if let allowedOwnerIds = allowedOwnerIds, !allowedOwnerIds.contains(ownerId) {
                Log.debug("Filtering out version not in heritage chain", category: .firebase, metadata: [
                    "ownerId": ownerId,
                    "generation": generation,
                    "reason": "owner not in sanitized heritage chain"
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
                let ownerDisplayName = await getDisplayName(for: ownerId)
                if ownerDisplayName == nil {
                    Log.warning("No display name found for owner", category: .firebase, metadata: [
                        "ownerId": ownerId,
                        "generation": generation
                    ])
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

                // FIXED: Show all generations regardless of ownership
                guard let recipeId = UUID(uuidString: recipeIdString) else { continue }

                // Filter by heritage chain if provided (sanitization filter)
                if let allowedOwnerIds = allowedOwnerIds, !allowedOwnerIds.contains(ownerId) {
                    Log.debug("Filtering out root owner version not in heritage chain", category: .firebase, metadata: [
                        "ownerId": ownerId,
                        "generation": generation,
                        "reason": "owner not in sanitized heritage chain"
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
                    let ownerDisplayName = await getDisplayName(for: ownerId)
                    if ownerDisplayName == nil {
                        Log.warning("No display name found for root owner", category: .firebase, metadata: [
                            "ownerId": ownerId,
                            "generation": generation
                        ])
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
            .document(recipeId.firebaseString)
            .getDocument(source: .server)

        guard doc.exists, var data = doc.data() else {
            throw NSError(domain: "RecipeVersions", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Recipe not found"
            ])
        }

        // Fetch ingredients subcollection (also from server, not cache)
        let ingredientsSnapshot = try await db.collection("users/\(ownerId)/recipes")
            .document(recipeId.firebaseString)
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
            if isCurrent {
                return "Original"
            } else {
                let name = modifiedByName ?? "Someone"
                return "\(name)'s Version"
            }
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
