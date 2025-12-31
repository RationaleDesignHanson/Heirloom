//
//  DataMigrationService.swift
//  Heirloom
//
//  Created during Firebase Migration - Phase 7
//  Handles one-time migration from CloudKit to Firebase
//

import Foundation
import SwiftData
import CloudKit
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// One-time migration service to move data from CloudKit to Firebase
/// Run this once during the dual-write period to migrate existing users
@MainActor
class DataMigrationService: ObservableObject {

    // MARK: - Singleton

    static let shared = DataMigrationService()

    private init() {}

    // MARK: - Published State

    @Published private(set) var isMigrating = false
    @Published private(set) var progress: MigrationProgress = MigrationProgress()
    @Published private(set) var migrationError: Error?

    // MARK: - Dependencies

    private let cloudKitContainer = CKContainer.default()
    private var cloudKitDatabase: CKDatabase {
        cloudKitContainer.privateCloudDatabase
    }
    private let cloudKitZone = CKRecordZone(zoneName: "HeirloomRecipes")

    private let firebaseSync = FirebaseSyncService.shared
    private var auth: Auth { Auth.auth() }

    // MARK: - Migration Progress

    struct MigrationProgress {
        var totalRecipes: Int = 0
        var migratedRecipes: Int = 0
        var failedRecipes: Int = 0
        var totalImages: Int = 0
        var migratedImages: Int = 0
        var failedImages: Int = 0
        var currentRecipe: String = ""
        var isComplete: Bool = false
        var startTime: Date?
        var endTime: Date?

        var percentComplete: Double {
            guard totalRecipes > 0 else { return 0 }
            return Double(migratedRecipes + failedRecipes) / Double(totalRecipes)
        }

        var elapsedTime: TimeInterval {
            guard let start = startTime else { return 0 }
            let end = endTime ?? Date()
            return end.timeIntervalSince(start)
        }

        mutating func reset() {
            self = MigrationProgress()
        }
    }

    // MARK: - Main Migration

    /// Migrate all data from CloudKit to Firebase
    /// - Parameters:
    ///   - context: ModelContext for SwiftData operations
    ///   - dryRun: If true, only counts records without migrating
    func migrateAllData(context: ModelContext, dryRun: Bool = false) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw MigrationError.notAuthenticated
        }

        guard !isMigrating else {
            throw MigrationError.migrationInProgress
        }

        isMigrating = true
        progress.reset()
        progress.startTime = Date()
        migrationError = nil

        print("🚀 [Migration] Starting migration from CloudKit to Firebase")
        print("   User ID: \(userId)")
        print("   Dry Run: \(dryRun)")
        DeviceLogger.shared.log("🚀 [Migration] Starting \(dryRun ? "dry run" : "migration")")

        do {
            // Step 1: Fetch all recipes from CloudKit
            let recipes = try await fetchAllRecipesFromCloudKit(context: context)
            progress.totalRecipes = recipes.count

            print("📊 [Migration] Found \(recipes.count) recipes in CloudKit")
            DeviceLogger.shared.log("📊 [Migration] Found \(recipes.count) recipes")

            if dryRun {
                print("✅ [Migration] Dry run complete - \(recipes.count) recipes would be migrated")
                progress.isComplete = true
                progress.endTime = Date()
                isMigrating = false
                return
            }

            // Step 2: Migrate each recipe
            for recipe in recipes {
                progress.currentRecipe = recipe.title

                do {
                    // Upload recipe to Firebase
                    try await firebaseSync.uploadRecipe(recipe)

                    // Upload image if exists
                    if recipe.imageFileName != nil {
                        progress.totalImages += 1
                        do {
                            if let imageURL = try await firebaseSync.uploadImage(for: recipe) {
                                recipe.firebaseImageURL = imageURL
                                progress.migratedImages += 1
                                print("   ✅ Image: \(recipe.title)")
                            }
                        } catch {
                            progress.failedImages += 1
                            print("   ⚠️ Image failed: \(recipe.title) - \(error.localizedDescription)")
                        }
                    }

                    progress.migratedRecipes += 1
                    print("✅ [\(progress.migratedRecipes)/\(progress.totalRecipes)] \(recipe.title)")

                } catch {
                    progress.failedRecipes += 1
                    print("❌ [\(progress.migratedRecipes + progress.failedRecipes)/\(progress.totalRecipes)] Failed: \(recipe.title)")
                    print("   Error: \(error.localizedDescription)")
                    DeviceLogger.shared.log("❌ [Migration] Failed to migrate: \(recipe.title)", level: .error)
                }
            }

            // Step 3: Complete
            progress.isComplete = true
            progress.endTime = Date()

            let summary = """
            ✅ [Migration] Complete!
               Total: \(progress.totalRecipes) recipes
               Migrated: \(progress.migratedRecipes)
               Failed: \(progress.failedRecipes)
               Images: \(progress.migratedImages)/\(progress.totalImages)
               Time: \(String(format: "%.1f", progress.elapsedTime))s
            """
            print(summary)
            DeviceLogger.shared.log(summary)

            isMigrating = false

        } catch {
            progress.endTime = Date()
            isMigrating = false
            migrationError = error
            print("❌ [Migration] Failed: \(error.localizedDescription)")
            DeviceLogger.shared.log("❌ [Migration] Failed: \(error.localizedDescription)", level: .error)
            throw error
        }
    }

    // MARK: - CloudKit Fetching

    /// Fetch all recipes from CloudKit
    private func fetchAllRecipesFromCloudKit(context: ModelContext) async throws -> [Recipe] {
        print("📥 [Migration] Fetching recipes from CloudKit...")

        // Query all Recipe records in the custom zone
        let query = CKQuery(recordType: "Recipe", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let (records, nextCursor) = try await performQuery(query: query, cursor: cursor)
            allRecords.append(contentsOf: records)
            cursor = nextCursor
        } while cursor != nil

        print("   Found \(allRecords.count) CloudKit records")

        // Convert CKRecords to Recipe models
        var recipes: [Recipe] = []

        for record in allRecords {
            do {
                let recipe = try convertCloudKitRecordToRecipe(record, context: context)

                // Fetch ingredients for this recipe
                let ingredients = try await fetchIngredientsForRecipe(recipeId: recipe.id, context: context)
                recipe.ingredients = ingredients.isEmpty ? nil : ingredients

                // Fetch comments for this recipe
                let comments = try await fetchCommentsForRecipe(recipeId: recipe.id, context: context)
                recipe.comments = comments.isEmpty ? nil : comments

                // Insert into context (temporary, will be uploaded to Firebase)
                if !context.container.mainContext.registeredObjects.contains(where: { ($0 as? Recipe)?.id == recipe.id }) {
                    context.insert(recipe)
                }

                recipes.append(recipe)

            } catch {
                print("⚠️ [Migration] Skipping recipe due to conversion error: \(error.localizedDescription)")
            }
        }

        print("   Converted \(recipes.count) recipes")

        return recipes
    }

    /// Perform CloudKit query with pagination
    private func performQuery(query: CKQuery, cursor: CKQueryOperation.Cursor?) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        if let cursor = cursor {
            // Continue from cursor
            return try await cloudKitDatabase.records(continuingMatchFrom: cursor, desiredKeys: nil)
        } else {
            // New query
            return try await cloudKitDatabase.records(matching: query, inZoneWith: cloudKitZone.zoneID, desiredKeys: nil)
        }
    }

    /// Fetch ingredients for a recipe from CloudKit
    private func fetchIngredientsForRecipe(recipeId: UUID, context: ModelContext) async throws -> [Ingredient] {
        // Query ingredients that reference this recipe
        let recipeRecordID = CKRecord.ID(recordName: recipeId.uuidString, zoneID: cloudKitZone.zoneID)
        let recipeReference = CKRecord.Reference(recordID: recipeRecordID, action: .none)
        let predicate = NSPredicate(format: "recipe == %@", recipeReference)
        let query = CKQuery(recordType: "Ingredient", predicate: predicate)

        let (records, _) = try await cloudKitDatabase.records(matching: query, inZoneWith: cloudKitZone.zoneID, desiredKeys: nil)

        var ingredients: [Ingredient] = []

        for (_, result) in records {
            switch result {
            case .success(let record):
                do {
                    let ingredient = try convertCloudKitRecordToIngredient(record)
                    ingredients.append(ingredient)
                } catch {
                    print("⚠️ [Migration] Failed to convert ingredient: \(error.localizedDescription)")
                }
            case .failure(let error):
                print("⚠️ [Migration] Failed to fetch ingredient: \(error.localizedDescription)")
            }
        }

        return ingredients.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Fetch comments for a recipe from CloudKit
    private func fetchCommentsForRecipe(recipeId: UUID, context: ModelContext) async throws -> [RecipeComment] {
        let recipeRecordID = CKRecord.ID(recordName: recipeId.uuidString, zoneID: cloudKitZone.zoneID)
        let recipeReference = CKRecord.Reference(recordID: recipeRecordID, action: .none)
        let predicate = NSPredicate(format: "recipe == %@", recipeReference)
        let query = CKQuery(recordType: "RecipeComment", predicate: predicate)

        let (records, _) = try await cloudKitDatabase.records(matching: query, inZoneWith: cloudKitZone.zoneID, desiredKeys: nil)

        var comments: [RecipeComment] = []

        for (_, result) in records {
            switch result {
            case .success(let record):
                do {
                    let comment = try convertCloudKitRecordToComment(record)
                    comments.append(comment)
                } catch {
                    print("⚠️ [Migration] Failed to convert comment: \(error.localizedDescription)")
                }
            case .failure(let error):
                print("⚠️ [Migration] Failed to fetch comment: \(error.localizedDescription)")
            }
        }

        return comments.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - CloudKit Record Conversion

    private func convertCloudKitRecordToRecipe(_ record: CKRecord, context: ModelContext) throws -> Recipe {
        let title = record["title"] as? String ?? "Untitled"
        let sourceTypeString = record["sourceType"] as? String ?? "manual"
        let sourceType = RecipeSourceType(rawValue: sourceTypeString) ?? .manual

        let recipe = Recipe(
            title: title,
            sourceType: sourceType,
            sourceURL: record["sourceURL"] as? String,
            instructions: record["instructions"] as? [String] ?? [],
            servings: record["servings"] as? String,
            prepTime: record["prepTime"] as? String,
            cookTime: record["cookTime"] as? String
        )

        // Set ID from CloudKit record name
        if let recordName = UUID(uuidString: record.recordID.recordName) {
            recipe.id = recordName
        }

        // Additional fields
        recipe.notes = record["notes"] as? String
        recipe.isFavorite = (record["isFavorite"] as? Int64 == 1)
        recipe.timesCooked = Int(record["timesCooked"] as? Int64 ?? 0)

        // Timestamps
        if let createdAt = record["createdAt"] as? Date {
            recipe.createdAt = createdAt
        }
        if let modifiedAt = record["modifiedAt"] as? Date {
            recipe.modifiedAt = modifiedAt
        }
        recipe.dateAdded = recipe.createdAt
        recipe.lastModified = recipe.modifiedAt

        // Image (will need to download from CloudKit asset)
        if let imageAsset = record["imageAsset"] as? CKAsset {
            // Store asset URL for later download
            recipe.sourceImageURL = imageAsset.fileURL?.absoluteString
        }

        return recipe
    }

    private func convertCloudKitRecordToIngredient(_ record: CKRecord) throws -> Ingredient {
        let ingredient = Ingredient(
            originalText: record["originalText"] as? String ?? "",
            name: record["name"] as? String ?? "",
            quantity: record["quantity"] as? Double,
            unit: record["unit"] as? String,
            category: GroceryCategory(rawValue: record["category"] as? String ?? "") ?? .other,
            orderIndex: Int(record["orderIndex"] as? Int64 ?? 0)
        )

        if let recordName = UUID(uuidString: record.recordID.recordName) {
            ingredient.id = recordName
        }

        ingredient.quantityMax = record["quantityMax"] as? Double
        ingredient.preparation = record["preparation"] as? String
        ingredient.isOptional = (record["isOptional"] as? Int64 == 1)

        return ingredient
    }

    private func convertCloudKitRecordToComment(_ record: CKRecord) throws -> RecipeComment {
        let comment = RecipeComment(
            text: record["text"] as? String ?? "",
            authorName: record["authorName"] as? String
        )

        if let recordName = UUID(uuidString: record.recordID.recordName) {
            comment.id = recordName
        }

        if let createdAt = record["createdAt"] as? Date {
            comment.createdAt = createdAt
        }

        comment.isPinned = (record["isPinned"] as? Int64 == 1)
        comment.sentimentScore = record["sentimentScore"] as? Double

        return comment
    }

    // MARK: - Migration Status

    /// Check if migration is needed (CloudKit has data, Firebase is empty)
    func checkMigrationStatus(context: ModelContext) async throws -> MigrationStatus {
        guard auth.currentUser != nil else {
            throw MigrationError.notAuthenticated
        }

        // Count CloudKit recipes
        let cloudKitCount = try await countCloudKitRecipes()

        // Count Firebase recipes
        let firebaseCount = try await countFirebaseRecipes()

        return MigrationStatus(
            cloudKitRecipes: cloudKitCount,
            firebaseRecipes: firebaseCount,
            needsMigration: cloudKitCount > 0 && firebaseCount == 0
        )
    }

    private func countCloudKitRecipes() async throws -> Int {
        let query = CKQuery(recordType: "Recipe", predicate: NSPredicate(value: true))
        let (records, _) = try await cloudKitDatabase.records(matching: query, inZoneWith: cloudKitZone.zoneID, desiredKeys: ["title"])
        return records.count
    }

    private func countFirebaseRecipes() async throws -> Int {
        guard let userId = auth.currentUser?.uid else { return 0 }
        let db = Firestore.firestore()
        let snapshot = try await db.collection("users/\(userId)/recipes").getDocuments()
        return snapshot.documents.count
    }
}

// MARK: - Supporting Types

extension DataMigrationService {
    struct MigrationStatus {
        let cloudKitRecipes: Int
        let firebaseRecipes: Int
        let needsMigration: Bool

        var summary: String {
            """
            CloudKit: \(cloudKitRecipes) recipes
            Firebase: \(firebaseRecipes) recipes
            Migration needed: \(needsMigration ? "Yes" : "No")
            """
        }
    }

    enum MigrationError: LocalizedError {
        case notAuthenticated
        case migrationInProgress
        case cloudKitAccessDenied
        case firebaseAccessDenied

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to Firebase to migrate data"
            case .migrationInProgress:
                return "Migration is already in progress"
            case .cloudKitAccessDenied:
                return "Cannot access CloudKit data. Please check iCloud settings."
            case .firebaseAccessDenied:
                return "Cannot access Firebase. Please check authentication."
            }
        }
    }
}
