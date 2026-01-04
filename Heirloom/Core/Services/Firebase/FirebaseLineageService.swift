//
//  FirebaseLineageService.swift
//  Heirloom
//
//  Created during Firebase Migration - Heirloom Sharing System
//  Handles lineage tracking and modification syncing for heirloom recipes
//

import Foundation
import SwiftData
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// Service for managing recipe lineage in Firebase
/// Tracks family trees and syncs modifications across the heirloom network
@MainActor
class FirebaseLineageService: ObservableObject {

    // MARK: - Singleton

    static let shared = FirebaseLineageService()

    private init() {}

    // MARK: - Dependencies

    private lazy var db: Firestore = {
        // Use shared Firestore instance (configured by FirebaseSyncService)
        Firestore.firestore()
    }()
    private var auth: Auth { Auth.auth() }

    // MARK: - Lineage Creation

    /// Create a root lineage record (generation 0)
    /// Called when a user creates a new recipe or imports one as root
    func createRootLineage(
        recipeId: UUID,
        context: ModelContext
    ) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw LineageError.notAuthenticated
        }

        Log.info("Creating root lineage for recipe", category: .firebase, metadata: ["recipeId": recipeId.uuidString])

        // Create local lineage record
        let lineage = RecipeLineage.createRoot(
            recipeId: recipeId,
            ownerId: userId
        )

        context.insert(lineage)
        try context.save()

        // Sync to Firebase
        try await syncLineageToFirebase(lineage)

        Log.info("Root lineage created successfully", category: .firebase)
    }

    /// Create a descendant lineage record when accepting a heirloom share
    /// Links the new recipe to its parent and root in the family tree
    func createDescendantLineage(
        rootRecipeId: UUID,
        parentRecipeId: UUID,
        currentRecipeId: UUID,
        rootOwnerId: String,
        generation: Int,
        sharedByName: String?,
        context: ModelContext
    ) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw LineageError.notAuthenticated
        }

        Log.info("Creating descendant lineage", category: .firebase, metadata: ["generation": generation])

        // Create local lineage record
        let lineage = RecipeLineage.createDescendant(
            rootRecipeId: rootRecipeId,
            parentRecipeId: parentRecipeId,
            currentRecipeId: currentRecipeId,
            ownerId: userId,
            rootOwnerId: rootOwnerId,
            generation: generation,
            sharedByName: sharedByName
        )

        context.insert(lineage)
        try context.save()

        // Sync to Firebase
        try await syncLineageToFirebase(lineage)

        Log.info("Descendant lineage created successfully", category: .firebase)
    }

    // MARK: - Modification Tracking

    /// Record a modification to a recipe
    /// If it's a heirloom recipe, this will be synced to ancestors in the family tree
    func recordModification(
        recipeId: UUID,
        changeType: ModificationRecord.ChangeType,
        changeDescription: String,
        fieldChanged: String? = nil,
        context: ModelContext
    ) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw LineageError.notAuthenticated
        }

        Log.info("Recording lineage modification", category: .firebase, metadata: ["changeType": changeType.rawValue])

        // Find lineage record for this recipe
        let descriptor = FetchDescriptor<RecipeLineage>(
            predicate: #Predicate { $0.currentRecipeId == recipeId }
        )

        guard let lineage = try context.fetch(descriptor).first else {
            Log.warning("No lineage found for recipe", category: .firebase, metadata: ["recipeId": recipeId.uuidString])
            return
        }

        // Only track modifications for heirloom recipes
        guard lineage.isHeirloom else {
            Log.debug("Skipping modification tracking for non-heirloom recipe", category: .firebase)
            return
        }

        // Create modification record
        let modification = ModificationRecord(
            timestamp: Date(),
            modifiedBy: userId,
            modifiedByName: nil, // TODO: Fetch from user profile
            changeType: changeType,
            changeDescription: changeDescription,
            fieldChanged: fieldChanged
        )

        // Add to lineage
        lineage.addModification(modification)
        try context.save()

        // Sync to Firebase
        try await syncModificationToFirebase(lineage, modification)

        // Notify ancestors in the family tree
        try await notifyAncestors(lineage: lineage, modification: modification)

        Log.info("Lineage modification recorded and synced", category: .firebase)
    }

    // MARK: - Fetching Lineage

    /// Fetch lineage for a recipe
    func fetchLineage(
        for recipeId: UUID,
        context: ModelContext
    ) throws -> RecipeLineage? {
        let descriptor = FetchDescriptor<RecipeLineage>(
            predicate: #Predicate { $0.currentRecipeId == recipeId }
        )

        return try context.fetch(descriptor).first
    }

    /// Fetch all descendant modifications for recipes the user owns
    /// This allows the root creator to see all modifications made by descendants
    func fetchDescendantModifications(
        for rootRecipeId: UUID
    ) async throws -> [DescendantModification] {
        guard let userId = auth.currentUser?.uid else {
            throw LineageError.notAuthenticated
        }

        Log.info("Fetching descendant modifications", category: .firebase, metadata: ["rootRecipeId": rootRecipeId.uuidString])

        // Query Firebase for all lineage records with this root
        let snapshot = try await db.collection("lineages")
            .whereField("rootRecipeId", isEqualTo: rootRecipeId.uuidString)
            .whereField("rootOwnerId", isEqualTo: userId)
            .getDocuments()

        var allModifications: [DescendantModification] = []

        for doc in snapshot.documents {
            let data = doc.data()

            // Extract modification records
            if let modificationsData = data["modifications"] as? [[String: Any]] {
                for modData in modificationsData {
                    if let modification = parseModificationRecord(modData) {
                        let descendant = DescendantModification(
                            lineageId: doc.documentID,
                            generation: data["generation"] as? Int ?? 0,
                            ownerId: data["ownerId"] as? String ?? "",
                            ownerName: data["sharedByName"] as? String,
                            modification: modification
                        )
                        allModifications.append(descendant)
                    }
                }
            }
        }

        // Sort by timestamp (most recent first)
        allModifications.sort { $0.modification.timestamp > $1.modification.timestamp }

        Log.info("Descendant modifications fetched", category: .firebase, metadata: ["count": allModifications.count])

        return allModifications
    }

    // MARK: - Firebase Sync

    /// Sync lineage record to Firebase
    private func syncLineageToFirebase(_ lineage: RecipeLineage) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw LineageError.notAuthenticated
        }

        let lineageData: [String: Any] = [
            "id": lineage.id.uuidString,
            "rootRecipeId": lineage.rootRecipeId.uuidString,
            "parentRecipeId": lineage.parentRecipeId?.uuidString as Any,
            "currentRecipeId": lineage.currentRecipeId.uuidString,
            "ownerId": lineage.ownerId,
            "rootOwnerId": lineage.rootOwnerId,
            "generation": lineage.generation,
            "createdAt": Timestamp(date: lineage.createdAt),
            "lastModified": Timestamp(date: lineage.lastModified),
            "isHeirloom": lineage.isHeirloom,
            "hasLocalModifications": lineage.hasLocalModifications,
            "sharedByName": lineage.sharedByName as Any,
            "modifications": lineage.modifications?.map { modificationToDict($0) } ?? []
        ]

        // Store in user's lineages collection
        let docRef = db.collection("users/\(userId)/lineages").document(lineage.id.uuidString)
        try await docRef.setData(lineageData, merge: true)

        // Also store in global lineages index for cross-user queries
        let globalRef = db.collection("lineages").document(lineage.id.uuidString)
        try await globalRef.setData(lineageData, merge: true)

        // Update local sync timestamp
        lineage.lastSynced = Date()
    }

    /// Sync a modification to Firebase
    private func syncModificationToFirebase(
        _ lineage: RecipeLineage,
        _ modification: ModificationRecord
    ) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw LineageError.notAuthenticated
        }

        // Update lineage document with new modification
        let modificationData = modificationToDict(modification)

        let docRef = db.collection("users/\(userId)/lineages").document(lineage.id.uuidString)
        try await docRef.updateData([
            "modifications": FieldValue.arrayUnion([modificationData]),
            "lastModified": Timestamp(date: modification.timestamp),
            "hasLocalModifications": true
        ])

        // Also update global index
        let globalRef = db.collection("lineages").document(lineage.id.uuidString)
        try await globalRef.updateData([
            "modifications": FieldValue.arrayUnion([modificationData]),
            "lastModified": Timestamp(date: modification.timestamp),
            "hasLocalModifications": true
        ])
    }

    /// Notify ancestors when a descendant makes modifications
    private func notifyAncestors(
        lineage: RecipeLineage,
        modification: ModificationRecord
    ) async throws {
        // Only notify if this is a descendant (not root)
        guard lineage.generation > 0 else { return }

        Log.info("Notifying ancestors of lineage modification", category: .firebase)

        // Query for all ancestors (lineage records with same root but lower generation)
        let snapshot = try await db.collection("lineages")
            .whereField("rootRecipeId", isEqualTo: lineage.rootRecipeId.uuidString)
            .whereField("generation", isLessThan: lineage.generation)
            .getDocuments()

        for doc in snapshot.documents {
            let ancestorOwnerId = doc.data()["ownerId"] as? String ?? ""

            // Create notification document
            let notificationData: [String: Any] = [
                "type": "lineage_modification",
                "recipeId": lineage.currentRecipeId.uuidString,
                "rootRecipeId": lineage.rootRecipeId.uuidString,
                "generation": lineage.generation,
                "modifiedBy": lineage.ownerId,
                "modifiedByName": lineage.sharedByName as Any,
                "changeType": modification.changeType.rawValue,
                "changeDescription": modification.changeDescription,
                "timestamp": Timestamp(date: modification.timestamp),
                "read": false
            ]

            // Store notification for ancestor
            try await db.collection("users/\(ancestorOwnerId)/notifications")
                .addDocument(data: notificationData)

            Log.debug("Notification sent to ancestor", category: .firebase, metadata: ["ancestorOwnerId": ancestorOwnerId])
        }
    }

    // MARK: - Helper Methods

    private func modificationToDict(_ modification: ModificationRecord) -> [String: Any] {
        return [
            "id": modification.id.uuidString,
            "timestamp": Timestamp(date: modification.timestamp),
            "modifiedBy": modification.modifiedBy,
            "modifiedByName": modification.modifiedByName as Any,
            "changeType": modification.changeType.rawValue,
            "changeDescription": modification.changeDescription,
            "fieldChanged": modification.fieldChanged as Any
        ]
    }

    private func parseModificationRecord(_ data: [String: Any]) -> ModificationRecord? {
        guard
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString),
            let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
            let modifiedBy = data["modifiedBy"] as? String,
            let changeTypeString = data["changeType"] as? String,
            let changeType = ModificationRecord.ChangeType(rawValue: changeTypeString),
            let changeDescription = data["changeDescription"] as? String
        else {
            return nil
        }

        return ModificationRecord(
            id: id,
            timestamp: timestamp,
            modifiedBy: modifiedBy,
            modifiedByName: data["modifiedByName"] as? String,
            changeType: changeType,
            changeDescription: changeDescription,
            fieldChanged: data["fieldChanged"] as? String
        )
    }
}

// MARK: - Supporting Types

/// Represents a modification made by a descendant in the family tree
struct DescendantModification {
    let lineageId: String
    let generation: Int
    let ownerId: String
    let ownerName: String?
    let modification: ModificationRecord
}

// MARK: - Errors

extension FirebaseLineageService {
    enum LineageError: LocalizedError {
        case notAuthenticated
        case lineageNotFound
        case invalidData

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to track lineage"
            case .lineageNotFound:
                return "Lineage record not found for this recipe"
            case .invalidData:
                return "Invalid lineage data"
            }
        }
    }
}
