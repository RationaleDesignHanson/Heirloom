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
class FirebaseLineageService: ObservableObject, FirebaseLineageServiceProtocol {

    // MARK: - Dependencies

    private let logger: LoggingService
    private let userProfileService: FirebaseUserProfileService

    // MARK: - Initialization

    init(logger: LoggingService, userProfileService: FirebaseUserProfileService) {
        self.logger = logger
        self.userProfileService = userProfileService
    }

    private var db: Firestore {
        // CRITICAL: Ensure Firebase is configured before accessing
        if FirebaseApp.app() == nil {
            logger.log("CRITICAL: Firebase not configured in LineageService - configuring now", category: .firebase, level: .error, metadata: nil)
            FirebaseApp.configure()
        }
        return Firestore.firestore()
    }

    private var auth: Auth {
        // CRITICAL: Ensure Firebase is configured before accessing
        if FirebaseApp.app() == nil {
            logger.log("CRITICAL: Firebase not configured in LineageService - configuring now", category: .firebase, level: .error, metadata: nil)
            FirebaseApp.configure()
        }
        return Auth.auth()
    }

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

        logger.log("Creating root lineage for recipe", category: .firebase, level: .info, metadata: nil)

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

        logger.log("Creating descendant lineage", category: .firebase, level: .info, metadata: nil)

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

        logger.log("Recording lineage modification", category: .firebase, level: .info, metadata: nil)

        // Find lineage record for this recipe
        let descriptor = FetchDescriptor<RecipeLineage>(
            predicate: #Predicate { $0.currentRecipeId == recipeId }
        )

        guard let lineage = try context.fetch(descriptor).first else {
            logger.log("No lineage found for recipe - cannot record modification", category: .firebase, level: .warning, metadata: [
                "recipeId": recipeId.uuidString
            ])
            // CRITICAL: Do NOT create lineage here - throw error instead
            // Lineage should only be created during share acceptance, not during edits
            throw LineageError.lineageNotFound
        }

        // Only track modifications for heirloom recipes
        guard lineage.isHeirloom else {
            Log.debug("Skipping modification tracking for non-heirloom recipe", category: .firebase)
            return
        }

        // Fetch user display name
        let displayName = try? await userProfileService.fetchDisplayName(for: userId)

        // Create modification record
        let modification = ModificationRecord(
            timestamp: Date(),
            modifiedBy: userId,
            modifiedByName: displayName,
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

        logger.log("Fetching descendant modifications", category: .firebase, level: .info, metadata: nil)

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

        logger.log("Descendant modifications fetched", category: .firebase, level: .info, metadata: nil)

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

    /// Fetch display name for the user who made the modification
    private func fetchModifierDisplayName(for userId: String) async -> String {
        do {
            if let displayName = try await userProfileService.fetchDisplayName(for: userId) {
                return displayName
            }
        } catch {
            Log.warning("Failed to fetch display name for notification", category: .firebase, metadata: [
                "userId": userId,
                "error": error.localizedDescription
            ])
        }
        return "Someone"
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

        // Fetch current user's display name ONCE for all notifications
        let modifierDisplayName = await fetchModifierDisplayName(for: lineage.ownerId)

        for doc in snapshot.documents {
            let ancestorData = doc.data()
            guard let ancestorOwnerId = ancestorData["ownerId"] as? String else { continue }
            let ancestorGeneration = ancestorData["generation"] as? Int ?? 0

            // Create notification data with CORRECT fields
            let notificationData: [String: Any] = [
                "type": "lineage_modification",
                "recipeId": lineage.currentRecipeId.uuidString,
                "rootRecipeId": lineage.rootRecipeId.uuidString,
                "generation": ancestorGeneration,  // FIX: Use ancestor's gen, not modifier's
                "modifierGeneration": lineage.generation,  // NEW: Track who made the change
                "modifiedBy": lineage.ownerId,
                "modifiedByName": modifierDisplayName,  // FIX: Fetched display name, never nil
                "ownerId": ancestorOwnerId,  // NEW: Track notification recipient
                "changeType": modification.changeType.rawValue,
                "changeDescription": modification.changeDescription,
                "timestamp": Timestamp(date: modification.timestamp),
                "read": false
            ]

            // Store notification in ancestor's collection
            try await db.collection("users/\(ancestorOwnerId)/notifications")
                .addDocument(data: notificationData)

            Log.info("Created lineage modification notification", category: .firebase, metadata: [
                "ancestorOwnerId": ancestorOwnerId,
                "ancestorGeneration": ancestorGeneration,
                "modifierGeneration": lineage.generation,
                "modifiedBy": lineage.ownerId
            ])
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
