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

        print("📤 [CRDT] Uploading recipe with operation log: \(recipe.title)")

        // Check if there are pending operations (indicates this is an edit with changes)
        let hasPendingOperations = recipe.pendingOperationsData != nil

        // If no pending operations and recipe is already synced, check if we need to upload
        if !hasPendingOperations && recipe.lastSyncedAt != nil {
            print("⚠️ [CRDT] No pending operations and already synced, checking if upload needed...")

            // Download remote to compare
            let recipeRef = try recipeDocument(id: recipe.id.uuidString)
            let remoteDoc = try await recipeRef.getDocument()

            if remoteDoc.exists, let remoteData = remoteDoc.data() {
                let remoteModifiedAt = remoteData["modifiedAt"] as? Date

                // If remote is newer or same, skip upload to avoid overwriting
                if let remoteModified = remoteModifiedAt, remoteModified >= recipe.modifiedAt {
                    print("⚠️ [CRDT] Remote is up-to-date or newer, skipping upload to avoid overwrite")
                    recipe.lastSyncedAt = Date()
                    try? modelContext?.save()
                    return
                }
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
            print("📝 [CRDT] Found \(pendingOps.count) pending operations from edit")

            // Add operations to CRDT log and update their vector clocks
            for op in pendingOps {
                // Increment the operation log's vector clock FIRST
                crdt.operationLog.vectorClock.increment(deviceId: op.deviceId)

                // Create a snapshot copy of the current vector clock for this operation
                let clockSnapshot = VectorClock(clocks: crdt.operationLog.vectorClock.clocks)
                clockSnapshot.lastUpdated = crdt.operationLog.vectorClock.lastUpdated
                op.vectorClock = clockSnapshot

                // Now add the operation with the correct vector clock
                crdt.operationLog.operations.append(op)

                print("📝 [CRDT] Operation '\(op.fieldPath)' vector clock: \(op.vectorClock)")
            }

            // Clear pending operations now that they're in the log
            recipe.pendingOperationsData = nil
        }

        // Serialize CRDT to Firestore
        let recipeRef = try recipeDocument(id: recipe.id.uuidString)

        var recipeData = convertToFirestoreData(recipe)
        recipeData["crdtData"] = crdt.toFirestoreData()
        recipeData["usesCRDT"] = true
        recipeData["lastModifiedByDevice"] = deviceId

        // Save vector clock
        if let vectorClockData = try? JSONEncoder().encode(crdt.operationLog.vectorClock) {
            recipe.vectorClockData = vectorClockData
        }

        try await recipeRef.setData(recipeData)

        // Upload operation log to subcollection
        let operationsRef = recipeRef.collection("operations")

        // Upload all operations
        print("📤 [CRDT] Uploading \(crdt.operationLog.operations.count) operations to subcollection")
        for operation in crdt.operationLog.operations {
            let opDoc = operationsRef.document(operation.id.uuidString)
            let opData = operation.toFirestoreData()
            print("📤 [CRDT] Uploading operation \(operation.id.uuidString): \(operation.fieldPath)")
            try await opDoc.setData(opData)
        }

        print("✅ [CRDT] Uploaded recipe with \(crdt.operationLog.operations.count) operations")

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
        print("📥 [CRDT] Downloading and merging recipe: \(recipeId)")

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
            print("⚠️ [CRDT] Remote recipe doesn't use CRDT, falling back to traditional sync")

            // Check if local recipe exists
            guard let recipeUUID = UUID(uuidString: recipeId) else {
                throw SyncError.recipeNotFound
            }
            let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == recipeUUID })
            let localRecipes = try context.fetch(descriptor)

            if localRecipes.isEmpty {
                // New recipe - insert it
                print("✅ [CRDT] New legacy recipe from remote, inserting")
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
                        print("✅ [CRDT] Image downloaded successfully for: \(remoteRecipe.title)")
                        try? context.save()
                    } catch {
                        print("⚠️ [CRDT] Failed to download image for \(remoteRecipe.title): \(error.localizedDescription)")
                    }
                }
            }

            return .alreadyInSync
        }

        // Download operation log
        let operationsSnapshot = try await recipeRef.collection("operations").getDocuments()
        print("📥 [CRDT] Found \(operationsSnapshot.documents.count) operation documents in Firestore")

        let operations = operationsSnapshot.documents.compactMap { RecipeOperation.from(firestoreData: $0.data()) }
        print("📥 [CRDT] Successfully parsed \(operations.count) operations")

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
            print("🔀 [CRDT] Merging with existing local recipe")

            // Create local CRDT
            let localCRDT = RecipeCRDT(recipe: localRecipe, deviceId: deviceId)

            // Restore local vector clock if available
            if let vectorClockData = localRecipe.vectorClockData,
               let vectorClock = try? JSONDecoder().decode(VectorClock.self, from: vectorClockData) {
                localCRDT.operationLog.vectorClock = vectorClock
            }

            // Perform CRDT merge
            let mergeResult = CRDTMergeEngine.shared.merge(local: localCRDT, remote: remoteCRDT)

            // Save merged vector clock back to recipe
            if case .autoMerged(let mergedCRDT, _) = mergeResult {
                if let vectorClockData = try? JSONEncoder().encode(mergedCRDT.operationLog.vectorClock) {
                    localRecipe.vectorClockData = vectorClockData
                    print("✅ [CRDT] Saved merged vector clock to recipe")
                }
                // Mark as synced to prevent re-upload on next sync
                localRecipe.lastSyncedAt = Date()
                try? context.save()
            }

            return mergeResult
        } else {
            // New recipe - just insert
            print("✅ [CRDT] New recipe from remote, inserting")
            context.insert(remoteRecipe)

            // Save remote vector clock to recipe
            if let vectorClockData = try? JSONEncoder().encode(remoteCRDT.operationLog.vectorClock) {
                remoteRecipe.vectorClockData = vectorClockData
                print("✅ [CRDT] Saved remote vector clock to new recipe")
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
                    print("✅ [CRDT] Image downloaded successfully for: \(remoteRecipe.title)")
                    try? context.save() // Save again to persist imageFileName
                } catch {
                    print("⚠️ [CRDT] Failed to download image for \(remoteRecipe.title): \(error.localizedDescription)")
                    // Recipe is still saved, just without the image
                }
            }

            return .autoMerged(result: remoteCRDT)
        }
    }

    // MARK: - CRDT Conflict Resolution

    /// Replace old resolveConflict with CRDT merge
    func resolveConflictWithCRDT(local: Recipe, remote: Recipe, deviceId: String) async throws -> MergeOperationResult {
        print("🔀 [CRDT] Resolving conflict using CRDT merge")

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
        let mergeResult = CRDTMergeEngine.shared.merge(local: localCRDT, remote: remoteCRDT)

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
                let ingredientDoc = ingredientsRef.document(ingredient.id.uuidString)
                let ingredientData = convertIngredientToFirestoreData(ingredient)
                try await ingredientDoc.setData(ingredientData)
            }
        }

        // Upload comments
        if let comments = recipe.comments, !comments.isEmpty {
            let commentsRef = recipeRef.collection("comments")

            for comment in comments {
                let commentDoc = commentsRef.document(comment.id.uuidString)
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

        print("🔒 [Transaction] Starting transactional upload: \(recipe.title)")

        // Phase 1: Upload to Firebase
        if recipe.usesCRDT {
            try await uploadRecipeWithCRDT(recipe, deviceId: deviceId)
        } else {
            try await uploadRecipe(recipe)
        }

        // Phase 2: Only NOW mark as synced locally
        recipe.lastSyncedAt = Date()
        try? modelContext?.save()

        print("✅ [Transaction] Transaction complete: \(recipe.title)")
    }

    // MARK: - Sync Flow with CRDT

    /// Enhanced sync flow that uses CRDT merge
    func syncChangesWithCRDT() async throws {
        guard !isSyncing else {
            print("⚠️ [CRDT] Sync already in progress")
            return
        }

        guard let context = modelContext else {
            throw SyncError.contextNotSet
        }

        isSyncing = true
        defer { isSyncing = false }

        print("🔄 [CRDT] Starting CRDT-aware sync...")

        // Step 1: Upload local changes
        let unsyncedRecipes = try fetchUnsyncedRecipes(context: context)
        print("📤 [CRDT] Uploading \(unsyncedRecipes.count) local changes")

        for recipe in unsyncedRecipes {
            try await uploadRecipeTransactional(recipe)
        }

        // Step 2: Download and merge remote changes
        let remoteChanges = try await fetchRemoteChanges(since: lastSyncDate)
        print("📥 [CRDT] Processing \(remoteChanges.count) remote changes")

        var conflictsDetected: [(crdt: RecipeCRDT, conflicts: [DetailedConflict])] = []

        for doc in remoteChanges {
            let recipeId = doc.documentID
            let result = try await downloadAndMergeRecipeWithCRDT(recipeId: recipeId, context: context)

            if result.requiresUI {
                // Conflict needs user resolution
                if case .needsUserResolution(let conflicts, let partialCRDT, _) = result {
                    print("⚠️ [CRDT] Conflict detected for: \(partialCRDT.recipe.title)")

                    // Mark recipe as having conflicts
                    partialCRDT.recipe.hasPendingConflicts = true
                    partialCRDT.recipe.showConflictBadge = true
                    try? context.save()

                    conflictsDetected.append((crdt: partialCRDT, conflicts: conflicts))
                }
            }
        }

        // Step 3: If conflicts detected, user needs to resolve them
        if !conflictsDetected.isEmpty {
            print("⚠️ [CRDT] \(conflictsDetected.count) recipes have conflicts requiring resolution")

            // Post notification to show conflict UI
            NotificationCenter.default.post(
                name: .recipeConflictsDetected,
                object: conflictsDetected
            )
        }

        lastSyncDate = Date()
        print("✅ [CRDT] Sync complete")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let recipeConflictsDetected = Notification.Name("recipeConflictsDetected")
}
