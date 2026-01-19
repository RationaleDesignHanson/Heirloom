//
//  FirebaseNukeService.swift
//  Heirloom
//
//  ⚠️ EXTREMELY DANGEROUS DEBUG FEATURE
//  TODO: REMOVE BEFORE PRODUCTION
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// ⚠️ DANGER: Deletes all user data from Firebase
/// This service should only be used for testing/development
@MainActor
class FirebaseNukeService {

    private let db = Firestore.firestore()

    /// Collections that will be PRESERVED (not deleted)
    private let preservedCollections = [
        "heritage_recipes",
        "heritage_schedules"
    ]

    /// Collections that will be DELETED
    private let collectionsToNuke = [
        "users",
        "shared_recipes",
        "recipe_lineage",
        "heritage_unlocks"
    ]

    /// Password required to execute nuke (set this to something secure)
    private let nukePassword = "NUKE2026"

    // MARK: - Validation

    /// Check if password is correct
    func validatePassword(_ password: String) -> Bool {
        return password == nukePassword
    }

    // MARK: - Nuke Operation

    /// ⚠️ DANGER: Delete all user data from Firebase
    /// Preserves: heritage_recipes, heritage_schedules
    /// Deletes: users, shared_recipes, recipe_lineage, heritage_unlocks
    func nukeUserData() async throws {
        Log.warning("🔥🔥🔥 STARTING FIREBASE NUKE OPERATION 🔥🔥🔥", category: .store)

        var deletedDocuments = 0
        var errors: [String] = []

        // Delete each collection
        for collectionName in collectionsToNuke {
            do {
                let count = try await deleteCollection(collectionName)
                deletedDocuments += count
                Log.info("Deleted \(count) documents from \(collectionName)", category: .store)
            } catch {
                errors.append("Failed to delete \(collectionName): \(error.localizedDescription)")
                Log.error("Failed to delete \(collectionName)", category: .store, error: error)
            }
        }

        // Sign out current user
        try Auth.auth().signOut()
        Log.info("Signed out current user", category: .store)

        // Clear local UserDefaults (subscription state, auth state, etc.)
        clearLocalUserData()

        Log.warning("""
        🔥🔥🔥 FIREBASE NUKE COMPLETE 🔥🔥🔥
        Deleted: \(deletedDocuments) documents
        Errors: \(errors.count)
        Preserved: \(preservedCollections.joined(separator: ", "))
        """, category: .store)

        if !errors.isEmpty {
            throw NSError(
                domain: "FirebaseNukeService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: errors.joined(separator: "\n")]
            )
        }
    }

    // MARK: - Collection Deletion

    /// Delete all documents in a collection
    private func deleteCollection(_ collectionName: String) async throws -> Int {
        let collection = db.collection(collectionName)
        let snapshot = try await collection.getDocuments()

        var deletedCount = 0

        // Delete in batches of 500 (Firestore limit)
        let batchSize = 500
        let documents = snapshot.documents

        for i in stride(from: 0, to: documents.count, by: batchSize) {
            let batch = db.batch()
            let endIndex = min(i + batchSize, documents.count)

            for doc in documents[i..<endIndex] {
                batch.deleteDocument(doc.reference)
                deletedCount += 1

                // Also delete subcollections (e.g., users/{userId}/heritageState)
                await deleteSubcollections(of: doc.reference)
            }

            try await batch.commit()

            Log.debug("Deleted batch: \(deletedCount)/\(documents.count) from \(collectionName)", category: .store)
        }

        return deletedCount
    }

    /// Delete known subcollections (e.g., users/{userId}/heritageState)
    private func deleteSubcollections(of docRef: DocumentReference) async {
        // Known subcollections under user documents
        let knownSubcollections = ["heritageState"]

        for subcollectionName in knownSubcollections {
            do {
                let subcollection = docRef.collection(subcollectionName)
                let snapshot = try await subcollection.getDocuments()

                for doc in snapshot.documents {
                    try await doc.reference.delete()
                }

                if !snapshot.documents.isEmpty {
                    Log.debug("Deleted \(snapshot.documents.count) documents from subcollection: \(subcollectionName)", category: .store)
                }
            } catch {
                Log.error("Failed to delete subcollection \(subcollectionName)", category: .store, error: error)
            }
        }
    }

    // MARK: - Local Data Cleanup

    /// Clear local UserDefaults related to user/subscription state
    private func clearLocalUserData() {
        let keysToRemove = [
            "subscription_status",
            "first_launch_date",
            "trial_expiry_date",
            "subscription_expiry_date",
            "last_subscription_status_refresh",
            "cached_product_id",
            "heritageUnlockedRecipeIds",
            "heritageLastUnlockDate",
            "heritageTrialStartDate",
            "paywall_soft_wall_dismiss_count",
            "paywall_recipe_count",
            "paywall_has_triggered_first_recipe",
            "paywall_has_triggered_five_recipes",
            "paywall_has_triggered_day13",
            "asmr_credits_used_this_month",
            "asmr_credit_reset_date"
        ]

        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }

        UserDefaults.standard.synchronize()

        Log.info("Cleared local user data (\(keysToRemove.count) keys)", category: .store)
    }
}
