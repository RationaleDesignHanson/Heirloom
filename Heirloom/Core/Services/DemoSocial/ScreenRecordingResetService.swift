//
//  ScreenRecordingResetService.swift
//  Heirloom
//
//  Service for resetting app to first-time user state for screen recordings.
//  Clears local data, Firebase user data, and social connections while preserving theme data.
//

import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

/// Service for managing screen recording resets and mock data visibility
@MainActor
final class ScreenRecordingResetService: ObservableObject {

    // MARK: - Singleton

    static let shared = ScreenRecordingResetService()

    // MARK: - Published State

    @Published var isResetting = false
    @Published var resetProgress: String = ""
    @Published var lastResetVerification: ResetVerification?

    /// Flag to prevent Firebase sync during reset
    /// FirebaseSyncService checks this before syncing
    @Published var isResetInProgress = false

    /// Flag to suppress the auth state listener's clearAllUserData call.
    /// Set before sign-out, cleared after a delay so the async auth listener
    /// Task has time to check it. Separate from isResetInProgress which is
    /// cleared in the defer block before the auth listener Task runs.
    var suppressDataClear = false

    /// Toggle to hide theme/heritage collections for screen recordings
    /// When true, CollectionsListView will not show theme collections
    @Published var hideThemeCollections: Bool {
        didSet {
            UserDefaults.standard.set(hideThemeCollections, forKey: UserDefaultsKeys.hideThemeCollections)
        }
    }

    /// Toggle to hide user-created demo seed collections for screen recordings
    /// When true, CollectionsListView will not show collections marked as isDemoSeed
    @Published var hideDemoSeedCollections: Bool {
        didSet {
            UserDefaults.standard.set(hideDemoSeedCollections, forKey: UserDefaultsKeys.hideDemoSeedCollections)
        }
    }

    // MARK: - Dependencies

    private let db: Firestore?
    private let auth: Auth?
    private let storage: Storage?

    // MARK: - Initialization

    private init() {
        self.db = Firestore.firestore()
        self.auth = Auth.auth()
        self.storage = Storage.storage()
        self.hideThemeCollections = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hideThemeCollections)
        self.hideDemoSeedCollections = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hideDemoSeedCollections)
    }

    // MARK: - Reset Verification

    struct ResetVerification {
        let timestamp: Date
        let localRecipesRemaining: Int
        let localCollectionsRemaining: Int
        let firebaseRecipesRemaining: Int
        let firebaseConnectionsRemaining: Int
        let themeRecipesPreserved: Int
        let success: Bool
        let errors: [String]

        var summary: String {
            if success {
                return "Reset complete. Theme recipes: \(themeRecipesPreserved)"
            } else {
                return "Reset had issues: \(errors.joined(separator: ", "))"
            }
        }
    }

    // MARK: - First Time User Reset

    /// Reset app to first-time user state
    /// - Clears local SwiftData (user recipes, collections)
    /// - Clears Firebase user data (recipes, collections, connections, notifications)
    /// - Removes user from demo users' connection lists
    /// - Preserves theme recipes locally and in Firebase
    func resetToFirstTimeUser(context: ModelContext) async throws -> ResetVerification {
        guard let userId = auth?.currentUser?.uid else {
            throw ResetError.notAuthenticated
        }

        isResetting = true
        isResetInProgress = true
        var errors: [String] = []

        defer {
            isResetting = false
            isResetInProgress = false
            resetProgress = ""
        }

        // Stop any ongoing sync to prevent race conditions
        let syncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
        await syncService.cancelSync()
        // CRITICAL: Set lastSyncDate to NOW so any post-reset sync only fetches
        // recipes created after this point (not the ones we just deleted)
        syncService.lastSyncDate = Date()
        Log.info("Reset: Stopped any ongoing sync operations and set lastSyncDate to now", category: .general)

        // Stop demo social behaviors to prevent them from interfering during reset
        DemoSocialBehaviorService.shared.stop()
        Log.info("Reset: Stopped demo social behavior service", category: .general)

        // Step 1: Get demo seed IDs to preserve (before clearing anything)
        // IMPORTANT: All IDs are lowercased for case-insensitive comparison.
        // Firestore document IDs may be lowercase while SwiftData UUID strings are uppercase.

        // 1a. Find demo seed collections from local SwiftData
        let demoSeedCollectionDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { $0.isDemoSeed }
        )
        let demoSeedCollections = try context.fetch(demoSeedCollectionDescriptor)
        var demoSeedCollectionIds = Set(demoSeedCollections.map { $0.id.uuidString.lowercased() })

        // 1b. Get recipe IDs in demo seed collections from SwiftData relationships
        var demoSeedRecipeIds = Set<String>()
        for collection in demoSeedCollections {
            if let recipes = collection.recipes {
                for recipe in recipes {
                    demoSeedRecipeIds.insert(recipe.id.uuidString.lowercased())
                }
            }
        }

        // 1c. ALSO get IDs from Firestore for reliability
        if let db = db {
            // Query Firebase for isDemoSeed collections (may exist on Firebase but not locally)
            do {
                let seedCollSnapshot = try await db.collection("users").document(userId)
                    .collection("collections")
                    .whereField("isDemoSeed", isEqualTo: true)
                    .getDocuments()
                for doc in seedCollSnapshot.documents {
                    demoSeedCollectionIds.insert(doc.documentID.lowercased())
                    // Also get recipeIds from these Firebase collection docs
                    if let recipeIds = doc.data()["recipeIds"] as? [String] {
                        for recipeId in recipeIds {
                            demoSeedRecipeIds.insert(recipeId.lowercased())
                        }
                    }
                }
                Log.info("Found seed collections via isDemoSeed query", category: .general, metadata: [
                    "count": seedCollSnapshot.documents.count
                ])
            } catch {
                Log.warning("Could not query isDemoSeed collections", category: .general, metadata: [
                    "error": error.localizedDescription
                ])
            }

            // Query Firebase for isDemoSeed recipes (most reliable for recipe IDs)
            do {
                let seedRecipesSnapshot = try await db.collection("users").document(userId)
                    .collection("recipes")
                    .whereField("isDemoSeed", isEqualTo: true)
                    .getDocuments()
                for doc in seedRecipesSnapshot.documents {
                    demoSeedRecipeIds.insert(doc.documentID.lowercased())
                }
                Log.info("Found seed recipes via isDemoSeed query", category: .general, metadata: [
                    "count": seedRecipesSnapshot.documents.count
                ])
            } catch {
                Log.warning("Could not query isDemoSeed recipes", category: .general, metadata: [
                    "error": error.localizedDescription
                ])
            }
        }

        // 1d. Also preserve any local collection that CONTAINS demo seed recipes,
        // even if the collection itself isn't marked isDemoSeed. This handles cases
        // where seed collections lost their isDemoSeed flag during sync.
        let allCollDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { !$0.isSystemCollection && !$0.isAllRecipes }
        )
        let allLocalCollections = try context.fetch(allCollDescriptor)
        for collection in allLocalCollections {
            if let recipes = collection.recipes {
                let hasPreservedRecipe = recipes.contains { recipe in
                    demoSeedRecipeIds.contains(recipe.id.uuidString.lowercased())
                }
                if hasPreservedRecipe {
                    demoSeedCollectionIds.insert(collection.id.uuidString.lowercased())
                }
            }
        }

        Log.info("Demo seed data to preserve", category: .general, metadata: [
            "collections": demoSeedCollectionIds.count,
            "recipes": demoSeedRecipeIds.count
        ])

        // Step 2: Clear local SwiftData
        resetProgress = "Clearing local data..."
        let (localRecipesDeleted, localCollectionsDeleted, themeCount, demoSeedCount) = try await clearLocalData(context: context, preserveRecipeIds: demoSeedRecipeIds, preserveCollectionIds: demoSeedCollectionIds)
        Log.info("Local data cleared", category: .general, metadata: [
            "recipes_deleted": localRecipesDeleted,
            "collections_deleted": localCollectionsDeleted,
            "theme_preserved": themeCount,
            "demo_seed_preserved": demoSeedCount
        ])

        // Step 3: Clear Firebase user data (preserving demo seed)
        resetProgress = "Clearing cloud data..."
        do {
            try await clearFirebaseUserData(
                userId: userId,
                preserveRecipeIds: demoSeedRecipeIds,
                preserveCollectionIds: demoSeedCollectionIds
            )
        } catch {
            errors.append("Firebase clear failed: \(error.localizedDescription)")
            Log.error("Failed to clear Firebase data", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Step 4: Remove user from demo users' connections
        resetProgress = "Cleaning up social connections..."
        do {
            try await removeUserFromDemoConnections(userId: userId)
        } catch {
            errors.append("Demo connections cleanup failed: \(error.localizedDescription)")
            Log.error("Failed to clean demo connections", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Step 5: Reset onboarding state and clear all caches
        resetProgress = "Resetting app state..."
        resetOnboardingState()

        // Step 5.5: Clear all processing job queues (video, import, generation)
        resetProgress = "Clearing job queues..."
        try clearAllJobQueues(context: context)

        // Step 5.6: Reset user credits to trial state
        resetProgress = "Resetting credits..."
        try resetUserCredits(context: context)

        // Step 6: Clear connection service cache AFTER Firebase operations complete
        // This ensures the cache doesn't hold stale connection data
        ServiceContainer.shared.resolveOptional(ConnectionServiceProtocol.self)?.clearCache()
        Log.info("Reset: Cleared connection service cache", category: .general)

        // Step 6b: Reset profile social counters, clear avatar, and clear cache
        let profileService = ServiceContainer.shared.resolve((any ProfileServiceProtocol).self)
        do {
            var profile = try await profileService.fetchCurrentUserProfile()
            profile.sharedRecipeCount = 0
            profile.connectionCount = 0
            profile.followerCount = 0
            profile.followingCount = 0
            profile.heritageGenerationCount = 0
            profile.recipeAcceptanceCount = 0
            profile.photoURL = nil  // Clear profile picture
            try await profileService.updateProfile(profile)
            Log.info("Reset: Reset profile social counters and cleared avatar", category: .general)
        } catch {
            errors.append("Profile reset failed: \(error.localizedDescription)")
            Log.error("Failed to reset profile counters", category: .general, metadata: ["error": error.localizedDescription])
        }
        profileService.clearCache()
        Log.info("Reset: Cleared profile service cache", category: .general)

        // Step 6c: Delete avatar image from Firebase Storage
        if let storage = storage {
            let avatarRef = storage.reference().child("users/\(userId)/profile/avatar.jpg")
            do {
                try await avatarRef.delete()
                Log.info("Reset: Deleted avatar image from storage", category: .general)
            } catch {
                // Avatar may not exist - that's OK
                Log.debug("Avatar deletion note (may not exist)", category: .general, metadata: ["note": error.localizedDescription])
            }
        }

        // Small delay to let Firebase propagate deletions
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Step 7: Recreate system collections (All Recipes, Generated Recipes, etc.)
        resetProgress = "Recreating default collections..."
        RecipeCollection.createSystemCollections(context: context)
        try context.save()
        Log.info("System collections recreated", category: .general)

        // Step 7b: Clear all collection tombstones — a full reset is a clean slate.
        // Tombstones created in clearLocalData() would block Firebase collection re-download
        // on the next sync, causing recipes to lose their collection relationships.
        let tombstoneDescriptor = FetchDescriptor<DeletedCollectionRecord>()
        let tombstones = try context.fetch(tombstoneDescriptor)
        if !tombstones.isEmpty {
            for tombstone in tombstones {
                context.delete(tombstone)
            }
            try context.save()
            Log.info("Cleared collection tombstones after reset", category: .general, metadata: [
                "count": tombstones.count
            ])
        }

        // Step 7c: Re-route preserved demo seed recipes to source-type collections.
        // The reset deleted From Web, From Videos, Cookbook Pages, From Friends, etc.
        // Recreate them based on each recipe's sourceType so the collections page isn't empty.
        resetProgress = "Restoring collection assignments..."
        let router = CollectionRouter(modelContext: context)
        let preservedRecipeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { !$0.isThemeRecipe }
        )
        let preservedRecipes = try context.fetch(preservedRecipeDescriptor)
        var relinkedCount = 0

        for recipe in preservedRecipes {
            guard let sourceType = recipe.sourceType else { continue }

            let targetCollection: RecipeCollection?
            switch sourceType {
            case .url:
                targetCollection = router.findOrCreateCollection(name: "From Web", type: .webImports, iconName: "link")
            case .video:
                targetCollection = router.findOrCreateCollection(name: "From Videos", type: .videoImports, iconName: "video.fill")
            case .cookbook:
                let cookbookName = recipe.sourceCookbook ?? "Cookbook Pages"
                targetCollection = router.findOrCreateCollection(name: cookbookName, type: .cookbook, iconName: "book.closed.fill")
            case .scan:
                targetCollection = router.findOrCreateCollection(name: "From Photos", type: .photoImports, iconName: "photo.fill")
            case .readRecipe:
                targetCollection = router.findOrCreateCollection(name: "Read Recipes", type: .readRecipes, iconName: "text.book.closed")
            case .family:
                targetCollection = router.findOrCreateCollection(name: "From Friends", type: .fromFriends, iconName: "person.2.fill")
            default:
                targetCollection = nil
            }

            if let collection = targetCollection {
                if recipe.collections == nil {
                    recipe.collections = []
                }
                if !(recipe.collections?.contains(where: { $0.id == collection.id }) ?? false) {
                    recipe.collections?.append(collection)
                    relinkedCount += 1
                }
            }
        }

        if relinkedCount > 0 {
            try context.save()
        }
        Log.info("Re-routed preserved recipes to source-type collections", category: .general, metadata: [
            "relinked": relinkedCount,
            "totalPreserved": preservedRecipes.count
        ])

        // Step 7d: Stop automatic sync so it restarts cleanly on next app launch.
        // Without this, the sync timer could fire immediately after reset completes
        // (isResetInProgress becomes false in defer) and upload empty collections to Firebase.
        syncService.stopAutomaticSync()
        Log.info("Reset: Stopped automatic sync for clean restart", category: .general)

        // Step 8: Verify reset
        resetProgress = "Verifying reset..."
        let verification = try await verifyReset(
            context: context,
            userId: userId,
            themeCount: themeCount,
            demoSeedRecipeCount: demoSeedRecipeIds.count,
            demoSeedCollectionCount: demoSeedCollectionIds.count,
            errors: errors
        )

        lastResetVerification = verification

        // Step 9: Sign out to force re-authentication on next launch.
        // This prevents auto-sync from re-downloading deleted recipes
        // (Firestore eventual consistency means batch deletes may not
        // be visible yet when sync runs on the next app launch).
        //
        // suppressDataClear prevents the auth state listener's async
        // clearAllUserData() from nuking the data we carefully preserved.
        // The listener fires in a Task { @MainActor in } which runs after
        // the defer block clears isResetInProgress.
        resetProgress = "Signing out..."
        suppressDataClear = true
        do {
            let authService = ServiceContainer.shared.resolve(FirebaseAuthService.self)
            try authService.signOut()
            Log.info("Reset: Signed out successfully", category: .general)
        } catch {
            // Non-fatal — the lastSyncDate=NOW safety net still prevents recipe re-download
            Log.error("Reset: Failed to sign out", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Give the auth state listener's async Task time to run and see
        // suppressDataClear=true before we clear it.
        try? await Task.sleep(nanoseconds: 500_000_000)
        suppressDataClear = false

        return verification
    }

    // MARK: - Clear Local Data

    private func clearLocalData(context: ModelContext, preserveRecipeIds: Set<String>, preserveCollectionIds: Set<String>) async throws -> (recipesDeleted: Int, collectionsDeleted: Int, themePreserved: Int, demoSeedPreserved: Int) {

        // Fetch all non-theme recipes
        let recipeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { !$0.isThemeRecipe }
        )
        let userRecipes = try context.fetch(recipeDescriptor)

        // Delete user recipes, but preserve those in demo seed collections
        // Uses the Firestore-augmented preserveRecipeIds set (not just SwiftData relationships)
        var recipesDeleted = 0
        for recipe in userRecipes {
            // Force-resolve relationships to prevent faulting errors
            _ = recipe.ingredients
            _ = recipe.collections
            _ = recipe.tags

            // Check if recipe is a preserved seed recipe (using the reliable ID set from Firestore)
            // Note: preserveRecipeIds are lowercased, so we must lowercase the comparison
            if preserveRecipeIds.contains(recipe.id.uuidString.lowercased()) {
                Log.debug("Preserving recipe in demo seed collection", category: .general, metadata: ["title": recipe.title])
                continue
            }

            context.delete(recipe)
            recipesDeleted += 1
        }

        // Fetch all collections (non-system, non-theme)
        let collectionDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { !$0.isSystemCollection && !$0.isAllRecipes }
        )
        let collections = try context.fetch(collectionDescriptor)

        // Delete non-theme, non-preserved collections
        // preserveCollectionIds includes isDemoSeed collections AND collections containing demo seed recipes
        var collectionsDeleted = 0
        var demoSeedPreservedCount = 0
        for collection in collections {
            // Skip theme collections
            guard collection.sourceTheme == nil else { continue }

            // Skip collections in the preserve set (isDemoSeed or contains demo seed recipes)
            if preserveCollectionIds.contains(collection.id.uuidString.lowercased()) {
                demoSeedPreservedCount += 1
                Log.debug("Preserving collection during reset", category: .general, metadata: [
                    "name": collection.name,
                    "isDemoSeed": collection.isDemoSeed
                ])
                continue
            }

            // Create tombstone for sync
            let tombstone = DeletedCollectionRecord(collectionId: collection.id)
            context.insert(tombstone)
            context.delete(collection)
            collectionsDeleted += 1
        }

        Log.info("Collections preserved during reset", category: .general, metadata: [
            "preserved": demoSeedPreservedCount,
            "deleted": collectionsDeleted
        ])

        // Count preserved theme recipes
        let themeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe }
        )
        let themeCount = try context.fetchCount(themeDescriptor)

        try context.save()

        return (recipesDeleted, collectionsDeleted, themeCount, demoSeedPreservedCount)
    }

    // MARK: - Clear Firebase User Data

    private func clearFirebaseUserData(userId: String, preserveRecipeIds: Set<String>, preserveCollectionIds: Set<String>) async throws {
        guard let db = db else { return }

        // Firestore batch operations are limited to 500 operations per batch
        // Process deletions in chunks to stay under the limit
        let batchChunkSize = 400

        // Clear recipes subcollection (with subcollections), preserving demo seed recipes
        let recipesRef = db.collection("users").document(userId).collection("recipes")
        let recipesSnapshot = try await recipesRef.getDocuments()

        // Filter out recipes to preserve (lowercase for case-insensitive comparison)
        let recipesToDelete = recipesSnapshot.documents.filter { doc in
            !preserveRecipeIds.contains(doc.documentID.lowercased())
        }

        // Delete subcollections first (they're separate from the batch)
        for doc in recipesToDelete {
            try await deleteSubcollections(parentRef: doc.reference)
        }

        // Delete recipe documents in batches
        try await deleteDocumentsInBatches(
            Array(recipesToDelete.map { $0.reference }),
            db: db,
            chunkSize: batchChunkSize
        )

        // Clear collections subcollection, preserving demo seed collections
        let collectionsRef = db.collection("users").document(userId).collection("collections")
        let collectionsSnapshot = try await collectionsRef.getDocuments()

        // Filter out collections to preserve (lowercase for case-insensitive comparison)
        let collectionsToDelete = collectionsSnapshot.documents.filter { doc in
            !preserveCollectionIds.contains(doc.documentID.lowercased())
        }

        try await deleteDocumentsInBatches(
            Array(collectionsToDelete.map { $0.reference }),
            db: db,
            chunkSize: batchChunkSize
        )

        // Clear connections subcollection (always delete - these are social data)
        let connectionsRef = db.collection("users").document(userId).collection("connections")
        let connectionsSnapshot = try await connectionsRef.getDocuments()
        try await deleteDocumentsInBatches(
            Array(connectionsSnapshot.documents.map { $0.reference }),
            db: db,
            chunkSize: batchChunkSize
        )

        // Clear notifications subcollection (always delete - these are social data)
        let notificationsRef = db.collection("users").document(userId).collection("notifications")
        let notificationsSnapshot = try await notificationsRef.getDocuments()
        try await deleteDocumentsInBatches(
            Array(notificationsSnapshot.documents.map { $0.reference }),
            db: db,
            chunkSize: batchChunkSize
        )

        // Clear recipe shares (always delete - these are social data)
        // Note: This may fail if recipeShares collection has no Firestore rules
        var recipeSharesCount = 0
        do {
            let sharesRef = db.collection("users").document(userId).collection("recipeShares")
            let sharesSnapshot = try await sharesRef.getDocuments()
            recipeSharesCount = sharesSnapshot.documents.count
            try await deleteDocumentsInBatches(
                Array(sharesSnapshot.documents.map { $0.reference }),
                db: db,
                chunkSize: batchChunkSize
            )
        } catch {
            Log.warning("Could not clear recipeShares (may require updated Firebase rules)", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Clear top-level shares collection where user is owner (direct shares to friends)
        // This is what shows as "X shared" in the profile header
        // Note: This may fail if Firebase rules don't allow querying this collection
        var topLevelSharesCount = 0
        do {
            let topLevelSharesRef = db.collection("shares")
            let topLevelSharesSnapshot = try await topLevelSharesRef
                .whereField("ownerId", isEqualTo: userId)
                .getDocuments()
            topLevelSharesCount = topLevelSharesSnapshot.documents.count
            try await deleteDocumentsInBatches(
                Array(topLevelSharesSnapshot.documents.map { $0.reference }),
                db: db,
                chunkSize: batchChunkSize
            )
        } catch {
            Log.warning("Could not clear top-level shares (may require updated Firebase rules)", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Clear shares where user is a recipient (e.g., demo welcome shares sent TO the user)
        // Without this, stale shares from demo users reappear after reset
        var incomingSharesCount = 0
        do {
            let incomingSharesRef = db.collection("shares")
            let incomingSharesSnapshot = try await incomingSharesRef
                .whereField("recipientUserIds", arrayContains: userId)
                .getDocuments()
            incomingSharesCount = incomingSharesSnapshot.documents.count
            try await deleteDocumentsInBatches(
                Array(incomingSharesSnapshot.documents.map { $0.reference }),
                db: db,
                chunkSize: batchChunkSize
            )
        } catch {
            Log.warning("Could not clear incoming shares", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Clear publicRecipes collection where user is owner
        // This is what shows as public recipes in the profile header
        // Note: This may fail if Firebase rules don't allow querying this collection
        var publicRecipesCount = 0
        do {
            let publicRecipesRef = db.collection("publicRecipes")
            let publicRecipesSnapshot = try await publicRecipesRef
                .whereField("ownerId", isEqualTo: userId)
                .getDocuments()
            publicRecipesCount = publicRecipesSnapshot.documents.count
            try await deleteDocumentsInBatches(
                Array(publicRecipesSnapshot.documents.map { $0.reference }),
                db: db,
                chunkSize: batchChunkSize
            )
        } catch {
            Log.warning("Could not clear publicRecipes (may require updated Firebase rules)", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Clear user's lineage records (prevents duplicate versions after re-sharing)
        var userLineagesCount = 0
        do {
            let lineagesRef = db.collection("users").document(userId).collection("lineages")
            let lineagesSnapshot = try await lineagesRef.getDocuments()
            userLineagesCount = lineagesSnapshot.documents.count
            try await deleteDocumentsInBatches(
                Array(lineagesSnapshot.documents.map { $0.reference }),
                db: db,
                chunkSize: batchChunkSize
            )
        } catch {
            Log.warning("Could not clear user lineages", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Clear global lineage records owned by this user
        var globalLineagesCount = 0
        do {
            let globalLineagesRef = db.collection("lineages")
            let globalLineagesSnapshot = try await globalLineagesRef
                .whereField("ownerId", isEqualTo: userId)
                .getDocuments()
            globalLineagesCount = globalLineagesSnapshot.documents.count
            try await deleteDocumentsInBatches(
                Array(globalLineagesSnapshot.documents.map { $0.reference }),
                db: db,
                chunkSize: batchChunkSize
            )
        } catch {
            Log.warning("Could not clear global lineages", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Delete user's images from storage (skip demo seed recipe images)
        try await deleteUserStorage(userId: userId, preserveRecipeIds: preserveRecipeIds)

        Log.info("Firebase user data cleared", category: .general, metadata: [
            "recipes_deleted": recipesToDelete.count,
            "recipes_preserved": preserveRecipeIds.count,
            "collections_deleted": collectionsToDelete.count,
            "collections_preserved": preserveCollectionIds.count,
            "connections": connectionsSnapshot.documents.count,
            "notifications": notificationsSnapshot.documents.count,
            "recipeShares": recipeSharesCount,
            "directShares": topLevelSharesCount,
            "incomingShares": incomingSharesCount,
            "publicRecipes": publicRecipesCount,
            "userLineages": userLineagesCount,
            "globalLineages": globalLineagesCount
        ])
    }

    /// Delete documents in batches to stay under Firestore's 500 operation limit
    private func deleteDocumentsInBatches(_ refs: [DocumentReference], db: Firestore, chunkSize: Int) async throws {
        guard !refs.isEmpty else { return }

        // Process in chunks
        for chunkStart in stride(from: 0, to: refs.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, refs.count)
            let chunk = Array(refs[chunkStart..<chunkEnd])

            let batch = db.batch()
            for ref in chunk {
                batch.deleteDocument(ref)
            }
            try await batch.commit()

            Log.debug("Deleted batch of documents", category: .firebase, metadata: [
                "count": chunk.count,
                "progress": "\(chunkEnd)/\(refs.count)"
            ])
        }
    }

    private func deleteSubcollections(parentRef: DocumentReference) async throws {
        guard db != nil else { return }

        let subcollectionNames = ["ingredients", "comments", "cardBack"]

        for name in subcollectionNames {
            let subcollectionRef = parentRef.collection(name)
            let snapshot = try await subcollectionRef.getDocuments()
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        }
    }

    private func deleteUserStorage(userId: String, preserveRecipeIds: Set<String>) async throws {
        guard let storage = storage else { return }

        let userStorageRef = storage.reference().child("users/\(userId)")

        do {
            let result = try await userStorageRef.listAll()
            for item in result.items {
                try await item.delete()
            }
            // Recursively delete folders, but preserve demo seed recipe images
            for prefix in result.prefixes {
                // Check if this is a recipes folder
                if prefix.name == "recipes" {
                    try await deleteRecipesStorageFolder(prefix, preserveRecipeIds: preserveRecipeIds)
                } else {
                    try await deleteStorageFolder(prefix)
                }
            }
        } catch {
            // Storage might be empty - that's OK
            Log.debug("Storage deletion note", category: .general, metadata: ["note": error.localizedDescription])
        }
    }

    private func deleteRecipesStorageFolder(_ ref: StorageReference, preserveRecipeIds: Set<String>) async throws {
        let result = try await ref.listAll()

        // Delete items in this folder
        for item in result.items {
            try await item.delete()
        }

        // Delete recipe subfolders, but skip preserved recipe IDs
        for prefix in result.prefixes {
            if preserveRecipeIds.contains(prefix.name.lowercased()) {
                Log.debug("Preserving storage for demo seed recipe", category: .general, metadata: ["recipeId": prefix.name])
                continue
            }
            try await deleteStorageFolder(prefix)
        }
    }

    private func deleteStorageFolder(_ ref: StorageReference) async throws {
        let result = try await ref.listAll()
        for item in result.items {
            try await item.delete()
        }
        for prefix in result.prefixes {
            try await deleteStorageFolder(prefix)
        }
    }

    // MARK: - Remove User from Demo Connections

    private func removeUserFromDemoConnections(userId: String) async throws {
        guard let db = db else { return }

        let batch = db.batch()
        var deletedCount = 0

        for demoUserId in DemoSocialBehaviorService.demoUserIds {
            // Check if this demo user has a connection record with the current user
            let connectionsRef = db.collection("users").document(demoUserId).collection("connections")
            let snapshot = try await connectionsRef
                .whereField("connectedUserId", isEqualTo: userId)
                .getDocuments()

            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
                deletedCount += 1
            }

            // Also check by document ID (connection IDs are shared between both users)
            let userConnectionsRef = db.collection("users").document(userId).collection("connections")
            let userSnapshot = try await userConnectionsRef.getDocuments()

            for userDoc in userSnapshot.documents {
                // Try to delete matching doc from demo user's connections
                let demoDocRef = connectionsRef.document(userDoc.documentID)
                batch.deleteDocument(demoDocRef)
            }
        }

        try await batch.commit()

        Log.info("Removed user from demo connections", category: .general, metadata: [
            "deleted_count": deletedCount
        ])
    }

    // MARK: - Clear Job Queues

    private func clearAllJobQueues(context: ModelContext) throws {
        // Clear video processing jobs
        let videoJobDescriptor = FetchDescriptor<VideoProcessingJob>()
        let videoJobs = try context.fetch(videoJobDescriptor)
        for job in videoJobs {
            context.delete(job)
        }

        // Clear import jobs
        let importJobDescriptor = FetchDescriptor<ImportJob>()
        let importJobs = try context.fetch(importJobDescriptor)
        for job in importJobs {
            context.delete(job)
        }

        // Clear recipe generation jobs
        let genJobDescriptor = FetchDescriptor<RecipeGenerationJob>()
        let genJobs = try context.fetch(genJobDescriptor)
        for job in genJobs {
            context.delete(job)
        }

        try context.save()
        Log.info("Job queues cleared", category: .general, metadata: [
            "video_jobs": videoJobs.count,
            "import_jobs": importJobs.count,
            "generation_jobs": genJobs.count
        ])
    }

    // MARK: - Reset User Credits

    private func resetUserCredits(context: ModelContext) throws {
        let descriptor = FetchDescriptor<UserCredits>()
        let allCredits = try context.fetch(descriptor)

        for credits in allCredits {
            // Reset to trial state (wipes purchased credits too)
            credits.resetToTrial()
        }

        try context.save()
        Log.info("User credits reset to trial state", category: .general)
    }

    // MARK: - Reset Onboarding State

    private func resetOnboardingState() {
        // Clear onboarding completion flag to show first-time user experience
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasSeenAddRecipeBanner")
        UserDefaults.standard.removeObject(forKey: "addRecipeBannerDismissCount")

        // Set sync date to NOW (not nil) so post-reset sync won't re-download deleted recipes.
        // Setting to nil causes sync to fetch everything since 2020-01-01, racing with
        // Firestore eventual consistency on the batch deletes.
        // CRITICAL: Set BOTH sync keys - FirebaseSyncService uses "firebase_lastSyncDate"
        // The old key "lastFirebaseSyncDate" is kept for backwards compatibility
        let resetTime = Date()
        UserDefaults.standard.set(resetTime, forKey: "firebase_lastSyncDate")
        UserDefaults.standard.set(resetTime, forKey: "lastFirebaseSyncDate")

        // Clear demo social state flags
        UserDefaults.standard.removeObject(forKey: "demo_social_welcome_shares_sent")
        UserDefaults.standard.removeObject(forKey: "demo_social_proactive_request_sent")

        // Clear subscription cache so stale "Premium" status doesn't persist.
        // Without this, the cached tier causes UserCredits to be set to .premium/.expired
        // instead of .trial, giving 0 credits after the trial check finds no real subscription.
        UserDefaults.standard.removeObject(forKey: "subscription_status")
        UserDefaults.standard.removeObject(forKey: "first_launch_date")
        UserDefaults.standard.removeObject(forKey: "trial_expiry_date")
        UserDefaults.standard.removeObject(forKey: "subscription_expiry_date")
        UserDefaults.standard.removeObject(forKey: "last_subscription_status_refresh")
        UserDefaults.standard.removeObject(forKey: "cached_product_id")

        // Reset SubscriptionManager in-memory state so it re-initializes trial on next launch
        let subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
        subscriptionManager.clearCache()

        // Hide demo seed collections so they don't appear during fresh onboarding
        hideDemoSeedCollections = true

        Log.info("Onboarding state reset", category: .general)
    }

    // MARK: - Verify Reset

    private func verifyReset(context: ModelContext, userId: String, themeCount: Int, demoSeedRecipeCount: Int, demoSeedCollectionCount: Int, errors: [String]) async throws -> ResetVerification {
        // Check local state (non-theme recipes remaining)
        let localRecipeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { !$0.isThemeRecipe }
        )
        let localRecipesRemaining = try context.fetchCount(localRecipeDescriptor)

        let localCollectionDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { !$0.isSystemCollection && !$0.isAllRecipes }
        )
        let localCollections = try context.fetch(localCollectionDescriptor)
        let localCollectionsRemaining = localCollections.filter { $0.sourceTheme == nil }.count

        // Check Firebase state
        var firebaseRecipesRemaining = 0
        var firebaseConnectionsRemaining = 0

        if let db = db {
            let recipesSnapshot = try await db.collection("users").document(userId).collection("recipes").getDocuments()
            firebaseRecipesRemaining = recipesSnapshot.documents.count

            let connectionsSnapshot = try await db.collection("users").document(userId).collection("connections").getDocuments()
            firebaseConnectionsRemaining = connectionsSnapshot.documents.count
        }

        // Subtract preserved demo seed recipes — these are expected to remain
        let unexpectedLocalRecipes = max(0, localRecipesRemaining - demoSeedRecipeCount)
        let unexpectedFirebaseRecipes = max(0, firebaseRecipesRemaining - demoSeedRecipeCount)

        var allErrors = errors
        if unexpectedLocalRecipes > 0 {
            allErrors.append("\(unexpectedLocalRecipes) local recipes not deleted")
        }
        if unexpectedFirebaseRecipes > 0 {
            allErrors.append("\(unexpectedFirebaseRecipes) Firebase recipes not deleted")
        }

        let success = unexpectedLocalRecipes == 0 && unexpectedFirebaseRecipes == 0 && firebaseConnectionsRemaining == 0

        return ResetVerification(
            timestamp: Date(),
            localRecipesRemaining: localRecipesRemaining,
            localCollectionsRemaining: localCollectionsRemaining,
            firebaseRecipesRemaining: firebaseRecipesRemaining,
            firebaseConnectionsRemaining: firebaseConnectionsRemaining,
            themeRecipesPreserved: themeCount,
            success: success,
            errors: allErrors
        )
    }

    // MARK: - Errors

    enum ResetError: LocalizedError {
        case notAuthenticated

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Not signed in. Please sign in first."
            }
        }
    }
}
