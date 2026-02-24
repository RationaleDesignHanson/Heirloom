//
//  FirebaseSyncService+CRDT.swift
//  Heirloom
//
//  Created by Claude on 12/31/25.
//  CRDT-aware sync extension for FirebaseSyncService (v2.0+)
//

import Foundation
import SwiftData
import FirebaseFirestore

extension FirebaseSyncService {

    // MARK: - CRDT Upload Operations

    /// Upload recipe with CRDT operation log to Firestore
    /// Replaces traditional uploadRecipe for CRDT-enabled recipes
    func uploadRecipeWithCRDT(_ recipe: Recipe, deviceId: String) async throws {
        guard currentUserId != nil else {
            throw SyncError.notAuthenticated
        }

        Log.info("Uploading recipe with CRDT operation log", category: .crdt, metadata: ["title": recipe.title])

        // Check if there are pending operations (indicates this is an edit with changes)
        let hasPendingOperations = recipe.pendingOperationsData != nil

        // If no pending operations and recipe is already synced, check if we need to upload
        if !hasPendingOperations && recipe.lastSyncedAt != nil {
            Log.debug("No pending operations, checking if upload needed", category: .crdt)

            do {
                // Download remote to compare (with timeout protection)
                let recipeRef = try recipeDocument(id: recipe.id.firebaseString)
                let remoteDoc = try await recipeRef.getDocument()

                if remoteDoc.exists, let remoteData = remoteDoc.data() {
                    let remoteModifiedAt = remoteData["modifiedAt"] as? Date

                    // If remote is newer or same, skip upload to avoid overwriting
                    if let remoteModified = remoteModifiedAt, remoteModified >= recipe.modifiedAt {
                        Log.info("Remote is up-to-date, skipping upload", category: .crdt)
                        recipe.lastSyncedAt = Date()
                        try? modelContext?.save()
                        return
                    }
                }
            } catch {
                // If remote fetch fails, continue with upload to be safe
                Log.warning("Failed to fetch remote for comparison, continuing with upload", category: .crdt, metadata: ["error": error.localizedDescription])
            }
        }

        // Update modifiedAt to ensure other devices detect this change
        recipe.modifiedAt = Date()

        // Create or get CRDT wrapper
        let crdt = RecipeCRDT(recipe: recipe, deviceId: deviceId)

        // Restore existing vector clock from recipe if available
        if let vectorClockData = recipe.vectorClockData,
           let vectorClock = try? JSONDecoder().decode(VectorClock.self, from: vectorClockData) {
            crdt.operationLog.vectorClock = vectorClock
        }

        // Add pending operations from edit (if any)
        if let pendingData = recipe.pendingOperationsData,
           let pendingOps = try? JSONDecoder().decode([RecipeOperation].self, from: pendingData) {
            Log.info("Found pending operations from edit", category: .crdt, metadata: ["count": pendingOps.count])

            // Add operations to CRDT log and update their vector clocks
            // CRITICAL FIX: Create incremented clock snapshot BEFORE modifying log's clock
            // This ensures atomicity - if append() fails, the log's clock remains unchanged
            for op in pendingOps {
                // Step 1: Create snapshot of CURRENT clock state (before increment)
                let clockSnapshot = VectorClock(clocks: crdt.operationLog.vectorClock.clocks)
                clockSnapshot.lastUpdated = crdt.operationLog.vectorClock.lastUpdated

                // Step 2: Increment the SNAPSHOT (not the log's clock yet)
                clockSnapshot.increment(deviceId: op.deviceId)

                // Step 3: Assign incremented clock snapshot to operation
                op.vectorClock = clockSnapshot

                // Step 4: Append operation to log
                // append() validates the operation, then merges the clock (which increments the log's clock)
                // If append() fails validation, the log's clock is never touched - no race condition
                crdt.operationLog.append(op)

                Log.debug("Operation committed with vector clock", category: .crdt, metadata: [
                    "fieldPath": op.fieldPath,
                    "clockValue": crdt.operationLog.vectorClock.value(for: op.deviceId),
                    "operationId": op.id.firebaseString
                ])
            }

            // Clear pending operations now that they're in the log
            recipe.pendingOperationsData = nil
        }

        // Serialize CRDT to Firestore
        let recipeRef = try recipeDocument(id: recipe.id.firebaseString)

        var recipeData = convertToFirestoreData(recipe)
        recipeData["crdtData"] = crdt.toFirestoreData()
        recipeData["usesCRDT"] = true
        recipeData["lastModifiedByDevice"] = deviceId

        // Save vector clock
        if let vectorClockData = try? JSONEncoder().encode(crdt.operationLog.vectorClock) {
            recipe.vectorClockData = vectorClockData
        }

        // Wrap Firestore uploads with timeout protection (30 seconds standard)
        try await TaskTimeout.withTimeout(seconds: TaskTimeout.firebaseStandard) {
            try await recipeRef.setData(recipeData, merge: true)

            // Upload operation log to subcollection
            let operationsRef = recipeRef.collection("operations")

            // Upload all operations
            Log.info("Uploading operations to subcollection", category: .crdt, metadata: ["count": crdt.operationLog.operations.count])
            for operation in crdt.operationLog.operations {
                let opDoc = operationsRef.document(operation.id.firebaseString)
                let opData = operation.toFirestoreData()
                Log.debug("Uploading operation", category: .crdt, metadata: ["operationId": operation.id.firebaseString, "fieldPath": operation.fieldPath])
                try await opDoc.setData(opData)
            }
        }

        Log.info("Recipe uploaded with operations", category: .crdt, metadata: ["operationCount": crdt.operationLog.operations.count])

        // Upload other subcollections (ingredients, comments, etc.) using existing methods
        // Note: These are uploaded separately for backwards compatibility
        try await uploadSubcollections(for: recipe, recipeRef: recipeRef)

        // Update sync metadata
        recipe.lastSyncedAt = Date()
        recipe.lastModifiedByDevice = deviceId
        try? modelContext?.save()
    }

    // MARK: - CRDT Download Operations

    /// Download recipe with CRDT from Firestore and merge with local
    func downloadAndMergeRecipeWithCRDT(recipeId: String, context: ModelContext) async throws -> MergeOperationResult {
        Log.info("Downloading and merging recipe with CRDT", category: .crdt, metadata: ["recipeId": recipeId])

        let deviceId = getCurrentDeviceId()

        // Fetch remote recipe
        let recipeRef = try recipeDocument(id: recipeId)
        let doc = try await recipeRef.getDocument()

        guard doc.exists, let data = doc.data() else {
            throw SyncError.recipeNotFound
        }

        // Check if remote uses CRDT
        let usesCRDT = data["usesCRDT"] as? Bool ?? false

        // Download recipe data
        let remoteRecipe = convertFromFirestoreData(data, id: recipeId, context: context)

        if !usesCRDT {
            // Fallback to traditional sync for legacy recipes (no CRDT merge needed)
            Log.warning("Remote recipe doesn't use CRDT, falling back to traditional sync", category: .crdt)

            // Check if local recipe exists
            guard let recipeUUID = UUID(uuidString: recipeId) else {
                throw SyncError.recipeNotFound
            }
            let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == recipeUUID })
            let localRecipes = try context.fetch(descriptor)

            if localRecipes.isEmpty {
                // New recipe - insert it
                Log.info("New legacy recipe from remote, inserting", category: .crdt)
                context.insert(remoteRecipe)

                // Mark as synced to prevent re-upload on next sync
                remoteRecipe.lastSyncedAt = Date()

                // Download subcollections
                try await fetchAndRestoreIngredients(for: remoteRecipe, recipeId: recipeId, context: context)
                try await fetchAndRestoreComments(for: remoteRecipe, recipeId: recipeId, context: context)
                try await fetchAndRestoreCardBack(for: remoteRecipe, recipeId: recipeId, context: context)

                try context.save()

                // Download image
                if remoteRecipe.firebaseImageURL != nil {
                    do {
                        try await downloadImage(for: remoteRecipe)
                        Log.info("Image downloaded successfully", category: .storage, metadata: ["title": remoteRecipe.title])
                        try? context.save()
                    } catch {
                        Log.warning("Failed to download image", category: .storage, metadata: ["title": remoteRecipe.title, "error": error.localizedDescription])
                    }
                }

                // Update collection loading progress
                await updateCollectionLoadingProgress(for: remoteRecipe.id, context: context)
            }

            return .alreadyInSync
        }

        // Download operation log
        let operationsSnapshot = try await recipeRef.collection("operations").getDocuments()
        Log.info("Found operation documents in Firestore", category: .crdt, metadata: ["count": operationsSnapshot.documents.count])

        let operations = operationsSnapshot.documents.compactMap { RecipeOperation.from(firestoreData: $0.data()) }
        Log.info("Successfully parsed operations", category: .crdt, metadata: ["count": operations.count])

        let remoteOperationLog = OperationLog(recipeId: UUID(uuidString: recipeId)!, operations: operations)

        // Create remote CRDT
        let remoteCRDT = RecipeCRDT(recipe: remoteRecipe, deviceId: data["lastModifiedByDevice"] as? String ?? "unknown")
        remoteCRDT.operationLog = remoteOperationLog

        // Check if local recipe exists
        guard let recipeUUID = UUID(uuidString: recipeId) else {
            throw SyncError.recipeNotFound
        }
        let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == recipeUUID })
        let localRecipes = try context.fetch(descriptor)

        if let localRecipe = localRecipes.first {
            // Recipe exists locally - merge
            Log.info("Merging with existing local recipe", category: .crdt)

            // Create local CRDT
            let localCRDT = RecipeCRDT(recipe: localRecipe, deviceId: deviceId)

            // Restore local vector clock if available
            if let vectorClockData = localRecipe.vectorClockData,
               let vectorClock = try? JSONDecoder().decode(VectorClock.self, from: vectorClockData) {
                localCRDT.operationLog.vectorClock = vectorClock
            }

            // Perform CRDT merge
            let mergeResult = crdtMergeEngine.merge(local: localCRDT, remote: remoteCRDT)

            // Save merged vector clock back to recipe
            if case .autoMerged(let mergedCRDT, _) = mergeResult {
                if let vectorClockData = try? JSONEncoder().encode(mergedCRDT.operationLog.vectorClock) {
                    localRecipe.vectorClockData = vectorClockData
                    Log.info("Saved merged vector clock to recipe", category: .crdt)
                }
                // Mark as synced to prevent re-upload on next sync
                localRecipe.lastSyncedAt = Date()
                try? context.save()
            }

            return mergeResult
        } else {
            // New recipe - just insert
            Log.info("New recipe from remote, inserting", category: .crdt)
            context.insert(remoteRecipe)

            // Save remote vector clock to recipe
            if let vectorClockData = try? JSONEncoder().encode(remoteCRDT.operationLog.vectorClock) {
                remoteRecipe.vectorClockData = vectorClockData
                Log.info("Saved remote vector clock to new recipe", category: .crdt)
            }

            // Mark as synced to prevent re-upload on next sync
            remoteRecipe.lastSyncedAt = Date()

            // Download subcollections (ingredients, comments, card back)
            try await fetchAndRestoreIngredients(for: remoteRecipe, recipeId: recipeId, context: context)
            try await fetchAndRestoreComments(for: remoteRecipe, recipeId: recipeId, context: context)
            try await fetchAndRestoreCardBack(for: remoteRecipe, recipeId: recipeId, context: context)

            try context.save()

            // Download image from Firebase Storage AFTER saving the recipe
            // This ensures the recipe is available even if image download fails
            if remoteRecipe.firebaseImageURL != nil {
                do {
                    try await downloadImage(for: remoteRecipe)
                    Log.info("Image downloaded successfully", category: .storage, metadata: ["title": remoteRecipe.title])
                    try? context.save() // Save again to persist imageFileName
                } catch {
                    Log.warning("Failed to download image", category: .storage, metadata: ["title": remoteRecipe.title, "error": error.localizedDescription])
                    // Recipe is still saved, just without the image
                }
            }

            return .autoMerged(result: remoteCRDT)
        }
    }

    // MARK: - CRDT Conflict Resolution

    /// Replace old resolveConflict with CRDT merge
    func resolveConflictWithCRDT(local: Recipe, remote: Recipe, deviceId: String) async throws -> MergeOperationResult {
        Log.info("Resolving conflict using CRDT merge", category: .crdt)

        // Create CRDTs for both versions
        let localCRDT = RecipeCRDT(recipe: local, deviceId: deviceId)
        let remoteCRDT = RecipeCRDT(recipe: remote, deviceId: "remote")

        // Restore vector clocks
        if let localVectorClockData = local.vectorClockData,
           let vectorClock = try? JSONDecoder().decode(VectorClock.self, from: localVectorClockData) {
            localCRDT.operationLog.vectorClock = vectorClock
        }

        if let remoteVectorClockData = remote.vectorClockData,
           let vectorClock = try? JSONDecoder().decode(VectorClock.self, from: remoteVectorClockData) {
            remoteCRDT.operationLog.vectorClock = vectorClock
        }

        // Perform merge
        let mergeResult = crdtMergeEngine.merge(local: localCRDT, remote: remoteCRDT)

        return mergeResult
    }

    // MARK: - Helper Methods

    /// Get current device ID for CRDT tracking
    private func getCurrentDeviceId() -> String {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios"
        #elseif os(macOS)
        return "macos-\(Host.current().localizedName ?? "unknown")"
        #else
        return "unknown-device"
        #endif
    }

    /// Upload recipe subcollections (ingredients, comments, etc.)
    private func uploadSubcollections(for recipe: Recipe, recipeRef: DocumentReference) async throws {
        // Upload ingredients
        if let ingredients = recipe.ingredients, !ingredients.isEmpty {
            let ingredientsRef = recipeRef.collection("ingredients")

            // Clear existing
            let existingDocs = try await ingredientsRef.getDocuments()
            for doc in existingDocs.documents {
                try await doc.reference.delete()
            }

            // Upload new
            for ingredient in ingredients {
                let ingredientDoc = ingredientsRef.document(ingredient.id.firebaseString)
                let ingredientData = convertIngredientToFirestoreData(ingredient)
                try await ingredientDoc.setData(ingredientData)
            }
        }

        // Upload comments
        if let comments = recipe.comments, !comments.isEmpty {
            let commentsRef = recipeRef.collection("comments")

            for comment in comments {
                let commentDoc = commentsRef.document(comment.id.firebaseString)
                let commentData = convertCommentToFirestoreData(comment)
                try await commentDoc.setData(commentData)
            }
        }

        // Upload card back
        if let cardBack = recipe.cardBack {
            let cardBackRef = recipeRef.collection("cardBack").document("metadata")
            let cardBackData = convertCardBackToFirestoreData(cardBack)
            try await cardBackRef.setData(cardBackData)
        }

        // Upload image if exists
        if recipe.imageFileName != nil {
            if let imageURL = try await uploadImage(for: recipe) {
                recipe.firebaseImageURL = imageURL
                try await recipeRef.updateData(["firebaseImageURL": imageURL])
            }
        }
    }

    // MARK: - Transactional Sync

    /// Upload recipe with two-phase commit (transactional)
    /// Only marks as synced locally after Firebase confirms success
    func uploadRecipeTransactional(_ recipe: Recipe) async throws {
        let deviceId = getCurrentDeviceId()

        Log.info("Starting transactional upload", category: .sync, metadata: ["title": recipe.title])

        // Phase 1: Upload to Firebase
        if recipe.usesCRDT {
            try await uploadRecipeWithCRDT(recipe, deviceId: deviceId)
        } else {
            try await uploadRecipe(recipe)
        }

        // Phase 2: Only NOW mark as synced locally
        recipe.lastSyncedAt = Date()
        try? modelContext?.save()

        Log.info("Transaction complete", category: .sync, metadata: ["title": recipe.title])
    }

    // MARK: - Sync Flow with CRDT

    /// Enhanced sync flow that uses CRDT merge
    func syncChangesWithCRDT() async throws {
        guard !isSyncing else {
            Log.warning("Sync already in progress", category: .crdt)
            return
        }

        guard let context = modelContext else {
            throw SyncError.contextNotSet
        }

        isSyncing = true
        defer { isSyncing = false }

        Log.info("Starting CRDT-aware sync", category: .crdt)

        let isFirstSync = lastSyncDate == nil

        // Step 1: Sync collections FIRST (fast - just metadata, shows UI immediately)
        // On first sync (fresh device), download BEFORE uploading to avoid overwriting
        // Firebase recipeIds with empty arrays from freshly-created local collections.
        let localCollections = try context.fetch(FetchDescriptor<RecipeCollection>())
        let userCreatedCollections = localCollections.filter { !$0.isSystemCollection && !$0.isAllRecipes }

        if !isFirstSync && !userCreatedCollections.isEmpty {
            Log.info("Uploading collections", category: .sync, metadata: ["count": userCreatedCollections.count])
            for collection in userCreatedCollections {
                try await uploadCollection(collection)
            }
            Log.info("Collections uploaded", category: .sync)
        } else if isFirstSync {
            Log.info("First sync detected - skipping collection upload to preserve Firebase recipeIds", category: .sync)
        }

        // Download remote collections (FAST - shows collections in UI immediately)
        Log.info("Downloading collections", category: .sync)
        let remoteCollections = try await downloadAllCollections(context: context)
        Log.info("Downloaded collections", category: .sync, metadata: ["count": remoteCollections.count])

        // Step 2: Upload local recipe changes
        let unsyncedRecipes = try fetchUnsyncedRecipes(context: context)
        Log.info("Uploading local changes", category: .crdt, metadata: ["count": unsyncedRecipes.count])

        for recipe in unsyncedRecipes {
            try await uploadRecipeTransactional(recipe)
        }

        // Step 3: Download and merge remote recipes (SLOW - but UI already visible)
        let remoteChanges = try await fetchRemoteChanges(since: lastSyncDate)
        Log.info("Processing remote changes", category: .crdt, metadata: ["count": remoteChanges.count])

        var conflictsDetected: [(crdt: RecipeCRDT, conflicts: [DetailedConflict])] = []

        for doc in remoteChanges {
            let recipeId = doc.documentID
            let result = try await downloadAndMergeRecipeWithCRDT(recipeId: recipeId, context: context)

            if result.requiresUI {
                // Conflict needs user resolution
                if case .needsUserResolution(let conflicts, let partialCRDT, _) = result {
                    Log.warning("Conflict detected for recipe", category: .crdt, metadata: ["title": partialCRDT.recipe.title])

                    // Mark recipe as having conflicts
                    partialCRDT.recipe.hasPendingConflicts = true
                    partialCRDT.recipe.showConflictBadge = true
                    try? context.save()

                    conflictsDetected.append((crdt: partialCRDT, conflicts: conflicts))
                }
            }
        }

        // Step 4: Conflict resolution
        // (Collections already synced in Step 1)

        // If conflicts detected, user needs to resolve them
        if !conflictsDetected.isEmpty {
            Log.warning("Recipes have conflicts requiring resolution", category: .crdt, metadata: ["count": conflictsDetected.count])

            // Post notification to show conflict UI
            NotificationCenter.default.post(
                name: .recipeConflictsDetected,
                object: conflictsDetected
            )
        }

        // Step 5: Re-link recipes to collections (recipes downloaded after collections)
        // Collections were downloaded first for fast UI, but recipes didn't exist yet
        Log.info("Re-linking recipes to collections", category: .sync)
        try await relinkRecipesToCollections(context: context)

        // Step 5b: Repair orphaned recipes (no collection membership after relink)
        // This catches recipes whose collectionIds were wiped from Firebase by prior setData calls
        repairOrphanedRecipes(context: context)

        // Step 6: On first sync, upload collections NOW (after relinking so recipeIds are populated)
        if isFirstSync && !userCreatedCollections.isEmpty {
            // Re-fetch collections since relinking may have added recipes
            let updatedCollections = try context.fetch(FetchDescriptor<RecipeCollection>())
            let collectionsToUpload = updatedCollections.filter { !$0.isSystemCollection && !$0.isAllRecipes }
            Log.info("First sync: uploading collections after relink", category: .sync, metadata: ["count": collectionsToUpload.count])
            for collection in collectionsToUpload {
                try await uploadCollection(collection)
            }
            Log.info("First sync: collections uploaded with correct recipeIds", category: .sync)
        }

        lastSyncDate = Date()
        hasCompletedInitialSync = true
        Log.info("CRDT sync complete", category: .crdt)

        // Clean up old tombstones after successful sync
        cleanupOldTombstones(context: context)
    }

    /// Re-link recipes to collections after both have been downloaded
    /// Uses two passes: (1) collection-centric (recipeIds on collection docs) and
    /// (2) recipe-centric (collectionIds on recipe docs) as fallback when recipeIds are empty
    private func relinkRecipesToCollections(context: ModelContext) async throws {
        guard let userId = currentUserId else { return }

        // Batch fetch ALL local recipes and collections once, build lookup dictionaries
        let allLocalRecipes = try context.fetch(FetchDescriptor<Recipe>())
        let recipeLookup = Dictionary(allLocalRecipes.map {
            ($0.id.firebaseString.lowercased(), $0)
        }, uniquingKeysWith: { first, _ in first })

        let allLocalCollections = try context.fetch(FetchDescriptor<RecipeCollection>())
        let collectionLookup = Dictionary(allLocalCollections.map {
            ($0.id.firebaseString.lowercased(), $0)
        }, uniquingKeysWith: { first, _ in first })

        // Build name+type fallback lookup for collections whose Firebase UUID was remapped
        var collectionNameLookup: [String: RecipeCollection] = [:]
        for collection in allLocalCollections {
            let key = "\(collection.name)|\(collection.collectionType)"
            collectionNameLookup[key] = collection
        }

        var linkedCount = 0

        // Helper to find a local collection by Firebase UUID (3-tier lookup)
        func findLocalCollection(firebaseId: String, name: String? = nil, type: String? = nil) -> RecipeCollection? {
            if let byUUID = collectionLookup[firebaseId.lowercased()] {
                return byUUID
            } else if let remappedUUID = collectionUUIDRemapping[firebaseId.lowercased()],
                      let byRemapped = collectionLookup[remappedUUID.uuidString.lowercased()] {
                return byRemapped
            } else if let name = name, let type = type,
                      let byName = collectionNameLookup["\(name)|\(type)"] {
                return byName
            }
            return nil
        }

        // Helper to link a recipe to a collection if not already linked
        func linkIfNeeded(recipe: Recipe, collection: RecipeCollection) {
            let alreadyLinked = recipe.collections?.contains(where: { $0.id == collection.id }) ?? false
            if !alreadyLinked {
                if recipe.collections == nil {
                    recipe.collections = []
                }
                recipe.collections?.append(collection)
                linkedCount += 1
            }
        }

        // ---- Pass 1: Collection-centric (read recipeIds from collection docs) ----
        let collectionsRef = db.collection("users/\(userId)/collections")
        let collSnapshot = try await collectionsRef.getDocuments()

        for doc in collSnapshot.documents {
            let data = doc.data()
            guard let collectionIdString = data["id"] as? String,
                  let recipeIds = data["recipeIds"] as? [String],
                  !recipeIds.isEmpty else {
                continue
            }

            guard let localCollection = findLocalCollection(
                firebaseId: collectionIdString,
                name: data["name"] as? String,
                type: data["collectionType"] as? String
            ) else { continue }

            for recipeIdString in recipeIds {
                if let recipe = recipeLookup[recipeIdString.lowercased()] {
                    linkIfNeeded(recipe: recipe, collection: localCollection)
                }
            }
        }

        let pass1Count = linkedCount
        Log.info("Relink pass 1 (collection-centric)", category: .sync, metadata: ["linked": pass1Count])

        // ---- Pass 2: Recipe-centric (read collectionIds from recipe docs) ----
        // This is the critical fallback: if collection docs had their recipeIds wiped
        // (e.g., by a prior sync uploading empty local collections), the recipe docs
        // still carry their original collectionIds.
        let recipesRef = db.collection("users/\(userId)/recipes")
        let recipeSnapshot = try await recipesRef.getDocuments()

        var recipesWithCollectionIds = 0
        var recipesWithEmptyCollectionIds = 0

        for doc in recipeSnapshot.documents {
            let data = doc.data()
            let recipeIdString = doc.documentID

            let collectionIds = data["collectionIds"] as? [String] ?? []
            if collectionIds.isEmpty {
                recipesWithEmptyCollectionIds += 1
                continue
            }

            recipesWithCollectionIds += 1

            guard let recipe = recipeLookup[recipeIdString.lowercased()] else {
                continue
            }

            for collIdString in collectionIds {
                if let localCollection = findLocalCollection(firebaseId: collIdString) {
                    linkIfNeeded(recipe: recipe, collection: localCollection)
                }
            }
        }

        let pass2Count = linkedCount - pass1Count
        Log.info("Relink pass 2 (recipe-centric)", category: .sync, metadata: [
            "linked": pass2Count,
            "recipesWithCollectionIds": recipesWithCollectionIds,
            "recipesWithEmptyCollectionIds": recipesWithEmptyCollectionIds,
            "totalRecipeDocs": recipeSnapshot.documents.count
        ])

        // ---- Pass 3: Favorites-centric (link isFavorite recipes to Favorites collection) ----
        // Firebase stores isFavorite on recipes, but the app expects them in a Favorites collection.
        // Find or create Favorites collection and link all recipes with isFavorite: true.
        let favoritesDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate<RecipeCollection> { $0.name == "Favorites" && $0.isSystemCollection == true }
        )
        let favoritesCollection = try? context.fetch(favoritesDescriptor).first

        if let favorites = favoritesCollection {
            var favoritesLinked = 0
            for doc in recipeSnapshot.documents {
                let data = doc.data()
                let recipeIdString = doc.documentID
                let isFavorite = data["isFavorite"] as? Bool ?? false

                if isFavorite, let recipe = recipeLookup[recipeIdString.lowercased()] {
                    linkIfNeeded(recipe: recipe, collection: favorites)
                    favoritesLinked += 1
                }
            }
            if favoritesLinked > 0 {
                Log.info("Relink pass 3 (favorites)", category: .sync, metadata: ["favoritesLinked": favoritesLinked])
            }
        }

        let pass3Count = linkedCount - pass1Count - pass2Count

        if linkedCount > 0 {
            try? context.save()
            Log.info("Re-linked recipes to collections", category: .sync, metadata: ["linkedCount": linkedCount])
        } else {
            Log.warning("Relink completed with 0 links - collections may appear empty", category: .sync)
        }
    }

    /// Repair recipes that have no collection membership after sync/relink.
    /// This catches recipes whose collectionIds were wiped from Firebase
    /// (e.g. by prior setData calls that omitted the field).
    private func repairOrphanedRecipes(context: ModelContext) {
        do {
            let allRecipes = try context.fetch(FetchDescriptor<Recipe>())
            let orphaned = allRecipes.filter { recipe in
                // Skip heritage recipes (they don't need collections)
                guard recipe.sourceType != .heritage else { return false }
                // Orphan = no collections or empty collections
                return recipe.collections == nil || recipe.collections!.isEmpty
            }

            guard !orphaned.isEmpty else { return }

            Log.warning("Found orphaned recipes after relink", category: .sync, metadata: ["count": orphaned.count])

            let router = CollectionRouter(modelContext: context)

            for recipe in orphaned {
                let sourceType = recipe.sourceType ?? .manual
                switch sourceType {
                case .generated:
                    let collection = router.findOrCreateCollection(
                        name: "Generated Recipes", type: .userCreated, iconName: "wand.and.stars"
                    )
                    router.routeToSpecificCollection(recipe, collection: collection)
                case .url:
                    let collection = router.findOrCreateCollection(
                        name: "From Web", type: .webImports, iconName: "link"
                    )
                    router.routeToSpecificCollection(recipe, collection: collection)
                case .scan:
                    let collection = router.findOrCreateCollection(
                        name: "Scanned Recipes", type: .photoImports, iconName: "camera.fill"
                    )
                    router.routeToSpecificCollection(recipe, collection: collection)
                case .cookbook:
                    let collection = router.findOrCreateCollection(
                        name: "Cookbook Pages", type: .cookbook, iconName: "book.closed.fill"
                    )
                    router.routeToSpecificCollection(recipe, collection: collection)
                case .video:
                    let collection = router.findOrCreateCollection(
                        name: "From Videos", type: .videoImports, iconName: "video.fill"
                    )
                    router.routeToSpecificCollection(recipe, collection: collection)
                case .readRecipe:
                    let collection = router.findOrCreateCollection(
                        name: "Read Recipes", type: .readRecipes, iconName: "mic.fill"
                    )
                    router.routeToSpecificCollection(recipe, collection: collection)
                default:
                    // manual, family, heritage — leave in All Recipes
                    break
                }
            }

            try? context.save()
            Log.info("Repaired orphaned recipes", category: .sync, metadata: ["count": orphaned.count])
        } catch {
            Log.error("Failed to repair orphaned recipes", category: .sync, metadata: ["error": error.localizedDescription])
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let recipeConflictsDetected = Notification.Name("recipeConflictsDetected")
}
