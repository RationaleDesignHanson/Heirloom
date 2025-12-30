import Foundation
import CloudKit
import SwiftData
import UIKit
import os.log

/// Manual CloudKit sync service for hybrid architecture
/// Handles explicit sync between local SwiftData and CloudKit
@MainActor
class CloudKitSyncService: ObservableObject {

    // Device-visible logging
    private let logger = Logger(subsystem: "com.matthanson.heirloom", category: "CloudKitSync")

    // MARK: - Singleton

    static let shared = CloudKitSyncService()

    private init() {}

    // MARK: - Published State

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: Error?

    // MARK: - Dependencies

    private let container = CKContainer.default()
    private var database: CKDatabase {
        container.privateCloudDatabase
    }

    // Use custom zone (required for change tracking)
    private let customZone = CKRecordZone(zoneName: "HeirloomRecipes")

    // MARK: - Sync State

    private var modelContext: ModelContext?
    private var isAutoSyncEnabled = false
    private var isZoneCreated = false

    // MARK: - Configuration

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Create custom zone on first run
        Task {
            await createCustomZoneIfNeeded()
        }
    }

    /// Create custom CloudKit zone (required for change tracking)
    private func createCustomZoneIfNeeded() async {
        guard !isZoneCreated else {
            DeviceLogger.shared.log("ℹ️ [Heirloom] Zone already marked as created, skipping")
            return
        }

        DeviceLogger.shared.log("🔧 [Heirloom] Creating custom CloudKit zone...")

        do {
            let (savedZones, _) = try await database.modifyRecordZones(saving: [customZone], deleting: [])
            DeviceLogger.shared.log("📦 [Heirloom] Zone creation response: \(savedZones.count) zones saved")
            if !savedZones.isEmpty {
                for (zoneID, result) in savedZones {
                    switch result {
                    case .success(let zone):
                        DeviceLogger.shared.log("✅ [Heirloom] Zone saved: \(zone.zoneID.zoneName)")
                        isZoneCreated = true
                    case .failure(let error):
                        DeviceLogger.shared.log("❌ [Heirloom] Zone save failed for \(zoneID.zoneName): \(error.localizedDescription)", level: .error)
                    }
                }
            } else {
                DeviceLogger.shared.log("⚠️ [Heirloom] Zone creation returned empty array", level: .error)
            }
        } catch let error as CKError {
            DeviceLogger.shared.log("❌ [Heirloom] Zone creation CKError - code: \(error.errorCode), description: \(error.localizedDescription)", level: .error)

            // Check if zone already exists (partial error)
            if error.code == .partialFailure,
               let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
                DeviceLogger.shared.log("📋 [Heirloom] Partial errors: \(partialErrors.count)")
                for (key, partialError) in partialErrors {
                    if let ckError = partialError as? CKError, ckError.code == .serverRecordChanged {
                        DeviceLogger.shared.log("✅ [Heirloom] Zone already exists (from partial error)")
                        isZoneCreated = true
                        return
                    }
                    DeviceLogger.shared.log("❌ [Heirloom] Partial error for \(key): \(partialError.localizedDescription)", level: .error)
                }
            }
        } catch {
            DeviceLogger.shared.log("❌ [Heirloom] Failed to create zone (non-CK error): \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Record Conversion: SwiftData → CloudKit

    /// Convert a Recipe model to CloudKit record
    func convertToRecord(_ recipe: Recipe) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: recipe.id.uuidString,
            zoneID: customZone.zoneID  // Use custom zone
        )
        let record = CKRecord(recordType: "Recipe", recordID: recordID)

        // Basic fields
        record["title"] = recipe.title as CKRecordValue
        record["sourceType"] = recipe.sourceType?.rawValue as CKRecordValue?
        record["sourceURL"] = recipe.sourceURL as CKRecordValue?
        record["servings"] = recipe.servings as CKRecordValue?
        record["prepTime"] = recipe.prepTime as CKRecordValue?
        record["cookTime"] = recipe.cookTime as CKRecordValue?
        record["notes"] = recipe.notes as CKRecordValue?
        record["isFavorite"] = recipe.isFavorite as CKRecordValue

        // Timestamps - Use CloudKit's built-in modificationDate (automatically maintained & indexed)
        // Only store createdAt since modificationDate is automatic
        record["createdAt"] = recipe.createdAt as CKRecordValue

        // Instructions (as JSON array)
        if let instructionsData = try? JSONEncoder().encode(recipe.instructions),
           let instructionsString = String(data: instructionsData, encoding: .utf8) {
            record["instructions"] = instructionsString as CKRecordValue
        }

        // Ingredients (store IDs as JSON string, sync ingredients separately)
        let ingredientIDs = recipe.ingredients?.map { $0.id.uuidString } ?? []
        if let ingredientIDsData = try? JSONEncoder().encode(ingredientIDs),
           let ingredientIDsString = String(data: ingredientIDsData, encoding: .utf8) {
            record["ingredientIDs"] = ingredientIDsString as CKRecordValue
        }

        // Provenance metadata (as JSON)
        if let provenance = recipe.provenance,
           let provenanceData = try? JSONEncoder().encode(provenance),
           let provenanceString = String(data: provenanceData, encoding: .utf8) {
            record["provenanceJSON"] = provenanceString as CKRecordValue
        }

        // Legacy sharing fields (for backward compatibility)
        record["sharedBy"] = recipe.sharedBy as CKRecordValue?
        record["sharedDate"] = recipe.sharedDate as CKRecordValue?
        record["passedDownMessage"] = recipe.passedDownMessage as CKRecordValue?
        record["generationCount"] = recipe.generationCount as CKRecordValue

        // Store image filename (actual CKAsset will be attached during upload if image exists)
        if let imageFileName = recipe.imageFileName {
            record["imageFileName"] = imageFileName as CKRecordValue
        }

        // Sync metadata
        record["lastSyncedAt"] = Date() as CKRecordValue

        return record
    }

    /// Convert a CloudKit record to Recipe model
    func convertFromRecord(_ record: CKRecord, context: ModelContext) -> Recipe {
        // Basic info
        let title = record["title"] as? String ?? "Untitled"
        let sourceTypeString = record["sourceType"] as? String ?? "manual"
        let sourceType = RecipeSourceType(rawValue: sourceTypeString) ?? .manual

        // Instructions
        var instructions: [String] = []
        if let instructionsString = record["instructions"] as? String,
           let instructionsData = instructionsString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: instructionsData) {
            instructions = decoded
        }

        // Create recipe
        let recipe = Recipe(
            title: title,
            sourceType: sourceType,
            sourceURL: record["sourceURL"] as? String,
            instructions: instructions,
            servings: record["servings"] as? String,
            prepTime: record["prepTime"] as? String,
            cookTime: record["cookTime"] as? String
        )

        // Additional fields
        recipe.notes = record["notes"] as? String
        recipe.isFavorite = (record["isFavorite"] as? Int) == 1

        // Timestamps
        if let createdAt = record["createdAt"] as? Date {
            recipe.createdAt = createdAt
        }
        // Use CloudKit's built-in modificationDate for modifiedAt
        if let modificationDate = record.modificationDate {
            recipe.modifiedAt = modificationDate
        }

        // Provenance
        if let provenanceString = record["provenanceJSON"] as? String,
           let provenanceData = provenanceString.data(using: .utf8),
           let provenance = try? JSONDecoder().decode(ProvenanceMetadata.self, from: provenanceData) {
            recipe.provenance = provenance
        }

        // Legacy sharing fields
        recipe.sharedBy = record["sharedBy"] as? String
        recipe.sharedDate = record["sharedDate"] as? Date
        recipe.passedDownMessage = record["passedDownMessage"] as? String
        recipe.generationCount = record["generationCount"] as? Int ?? 0

        // Sync metadata
        recipe.cloudKitRecordID = record.recordID.recordName
        recipe.lastSyncedAt = Date()

        return recipe
    }

    // MARK: - Ingredient Conversion

    /// Convert Ingredient to CloudKit record
    func convertIngredientToRecord(_ ingredient: Ingredient, recipeID: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "Ingredient_\(ingredient.id.uuidString)", zoneID: customZone.zoneID)
        let record = CKRecord(recordType: "Ingredient", recordID: recordID)

        // Basic fields
        record["ingredientID"] = ingredient.id.uuidString as CKRecordValue

        // Create CKReference to parent recipe (for hierarchical sharing)
        let recipeRecordID = CKRecord.ID(recordName: recipeID, zoneID: customZone.zoneID)
        let recipeReference = CKRecord.Reference(recordID: recipeRecordID, action: .deleteSelf)
        record["recipe"] = recipeReference as CKRecordValue

        // Also store string ID for backward compatibility and queries
        record["recipeID"] = recipeID as CKRecordValue
        record["originalText"] = ingredient.originalText as CKRecordValue

        // Parsed components
        if let quantity = ingredient.quantity {
            record["quantity"] = quantity as CKRecordValue
        }
        if let quantityMax = ingredient.quantityMax {
            record["quantityMax"] = quantityMax as CKRecordValue
        }
        record["unit"] = ingredient.unit as CKRecordValue?
        record["normalizedUnit"] = ingredient.normalizedUnit as CKRecordValue?
        record["name"] = ingredient.name as CKRecordValue
        record["preparation"] = ingredient.preparation as CKRecordValue?
        record["size"] = ingredient.size as CKRecordValue?

        // Organization
        if let category = ingredient.category {
            record["category"] = category.rawValue as CKRecordValue
        }
        record["orderIndex"] = ingredient.orderIndex as CKRecordValue

        // State
        record["isSelected"] = (ingredient.isSelected ? 1 : 0) as CKRecordValue
        record["isCheckedOff"] = (ingredient.isCheckedOff ? 1 : 0) as CKRecordValue
        record["isOptional"] = (ingredient.isOptional ? 1 : 0) as CKRecordValue

        return record
    }

    /// Convert RecipeCardBack to CKRecord for CloudKit upload
    func convertCardBackToRecord(_ cardBack: RecipeCardBack, recipeID: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "CardBack_\(cardBack.id.uuidString)", zoneID: customZone.zoneID)
        let record = CKRecord(recordType: "RecipeCardBack", recordID: recordID)

        // Basic fields
        record["cardBackID"] = cardBack.id.uuidString as CKRecordValue

        // Create CKReference to parent recipe (for hierarchical sharing)
        let recipeRecordID = CKRecord.ID(recordName: recipeID, zoneID: customZone.zoneID)
        let recipeReference = CKRecord.Reference(recordID: recipeRecordID, action: .deleteSelf)
        record["recipe"] = recipeReference as CKRecordValue

        // Also store string ID for backward compatibility and queries
        record["recipeID"] = recipeID as CKRecordValue

        // User notes
        record["noteToFriends"] = cardBack.noteToFriends as CKRecordValue?
        if !cardBack.personalTips.isEmpty {
            record["personalTips"] = cardBack.personalTips as CKRecordValue
        }
        record["userRating"] = cardBack.userRating as CKRecordValue?

        // Attribution
        record["showAttribution"] = (cardBack.showAttribution ? 1 : 0) as CKRecordValue
        record["customAttributionText"] = cardBack.customAttributionText as CKRecordValue?
        record["attributionPosition"] = cardBack.attributionPosition.rawValue as CKRecordValue

        // Comment display
        if !cardBack.pinnedCommentIDs.isEmpty {
            record["pinnedCommentIDs"] = cardBack.pinnedCommentIDs.map { $0.uuidString } as CKRecordValue
        }
        record["maxCommentsToDisplay"] = cardBack.maxCommentsToDisplay as CKRecordValue

        // Visual
        record["backgroundStyle"] = cardBack.backgroundStyle.rawValue as CKRecordValue
        record["textColor"] = cardBack.textColor as CKRecordValue

        // Visibility
        if !cardBack.visibleSections.isEmpty {
            record["visibleSections"] = cardBack.visibleSections.map { $0.rawValue } as CKRecordValue
        }

        return record
    }

    /// Convert RecipeComment to CKRecord for CloudKit upload
    func convertCommentToRecord(_ comment: RecipeComment, recipeID: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "Comment_\(comment.id.uuidString)", zoneID: customZone.zoneID)
        let record = CKRecord(recordType: "RecipeComment", recordID: recordID)

        // Basic fields
        record["commentID"] = comment.id.uuidString as CKRecordValue

        // Create CKReference to parent recipe (for hierarchical sharing)
        let recipeRecordID = CKRecord.ID(recordName: recipeID, zoneID: customZone.zoneID)
        let recipeReference = CKRecord.Reference(recordID: recipeRecordID, action: .deleteSelf)
        record["recipe"] = recipeReference as CKRecordValue

        // Also store string ID for backward compatibility and queries
        record["recipeID"] = recipeID as CKRecordValue
        record["text"] = comment.text as CKRecordValue
        record["authorName"] = comment.authorName as CKRecordValue?
        record["createdAt"] = comment.createdAt as CKRecordValue

        // Metadata
        record["isPinned"] = (comment.isPinned ? 1 : 0) as CKRecordValue
        if let sentimentScore = comment.sentimentScore {
            record["sentimentScore"] = sentimentScore as CKRecordValue
        }

        return record
    }

    /// Convert CloudKit record to Ingredient
    func convertIngredientFromRecord(_ record: CKRecord) -> Ingredient {
        let ingredient = Ingredient(
            originalText: record["originalText"] as? String ?? "",
            name: record["name"] as? String ?? "",
            quantity: record["quantity"] as? Double,
            unit: record["unit"] as? String,
            category: GroceryCategory(rawValue: record["category"] as? String ?? "") ?? .other,
            orderIndex: record["orderIndex"] as? Int ?? 0
        )

        // Parsed components
        ingredient.quantityMax = record["quantityMax"] as? Double
        ingredient.normalizedUnit = record["normalizedUnit"] as? String
        ingredient.preparation = record["preparation"] as? String
        ingredient.size = record["size"] as? String

        // State
        ingredient.isSelected = (record["isSelected"] as? Int) == 1
        ingredient.isCheckedOff = (record["isCheckedOff"] as? Int) == 1
        ingredient.isOptional = (record["isOptional"] as? Int) == 1

        return ingredient
    }

    /// Convert CloudKit record to RecipeCardBack
    func convertCardBackFromRecord(_ record: CKRecord) -> RecipeCardBack {
        let cardBack = RecipeCardBack()

        // User notes
        cardBack.noteToFriends = record["noteToFriends"] as? String
        if let tips = record["personalTips"] as? [String] {
            cardBack.personalTips = tips
        }
        cardBack.userRating = record["userRating"] as? Int

        // Attribution
        cardBack.showAttribution = (record["showAttribution"] as? Int) == 1
        cardBack.customAttributionText = record["customAttributionText"] as? String
        if let position = record["attributionPosition"] as? String,
           let positionEnum = AttributionPosition(rawValue: position) {
            cardBack.attributionPosition = positionEnum
        }

        // Comment display
        if let commentIDs = record["pinnedCommentIDs"] as? [String] {
            cardBack.pinnedCommentIDs = commentIDs.compactMap { UUID(uuidString: $0) }
        }
        if let maxComments = record["maxCommentsToDisplay"] as? Int {
            cardBack.maxCommentsToDisplay = maxComments
        }

        // Visual
        if let bgStyle = record["backgroundStyle"] as? String,
           let styleEnum = CardBackgroundStyle(rawValue: bgStyle) {
            cardBack.backgroundStyle = styleEnum
        }
        if let textColor = record["textColor"] as? String {
            cardBack.textColor = textColor
        }

        // Visibility
        if let sections = record["visibleSections"] as? [String] {
            cardBack.visibleSections = sections.compactMap { CardBackSection(rawValue: $0) }
        }

        return cardBack
    }

    /// Convert CloudKit record to RecipeComment
    func convertCommentFromRecord(_ record: CKRecord) -> RecipeComment {
        let comment = RecipeComment(
            text: record["text"] as? String ?? "",
            authorName: record["authorName"] as? String
        )

        if let createdAt = record["createdAt"] as? Date {
            comment.createdAt = createdAt
        }

        comment.isPinned = (record["isPinned"] as? Int) == 1
        comment.sentimentScore = record["sentimentScore"] as? Double

        return comment
    }

    // MARK: - Upload Operations

    /// Upload a single recipe to CloudKit
    func uploadRecipe(_ recipe: Recipe) async throws -> CKRecord {
        guard let context = modelContext else {
            throw SyncError.notConfigured
        }

        DeviceLogger.shared.log("📤 [Heirloom] Uploading recipe: \(recipe.title)")
        logger.info("📤 [Heirloom] Uploading recipe: \(recipe.title)")
        print("📤 Uploading recipe: \(recipe.title)")

        let record = convertToRecord(recipe)

        do {
            // Step 1: Upload recipe record
            let savedRecord = try await database.save(record)
            let recipeID = savedRecord.recordID.recordName

            // Update local record with CloudKit metadata
            recipe.cloudKitRecordID = recipeID
            recipe.lastSyncedAt = Date()
            try context.save()

            DeviceLogger.shared.log("✅ [Heirloom] Uploaded recipe: \(recipe.title) (recordID: \(recipeID))")
            logger.info("✅ [Heirloom] Uploaded recipe: \(recipe.title)")
            print("✅ Uploaded recipe: \(recipe.title)")

            // Step 1b: Upload image as CKAsset if exists (for hierarchical sharing)
            if let imageFileName = recipe.imageFileName {
                print("📤 Uploading image for \(recipe.title)")
                if let image = await ImageStorageService.shared.loadImage(fileName: imageFileName),
                   let imageData = image.jpegData(compressionQuality: 0.8) {
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempFile = tempDir.appendingPathComponent("\(recipe.id.uuidString)_image.jpg")
                    try imageData.write(to: tempFile)

                    let imageAsset = CKAsset(fileURL: tempFile)
                    savedRecord["imageAsset"] = imageAsset as CKRecordValue

                    // Save record again with image asset
                    _ = try await database.save(savedRecord)
                    print("✅ Uploaded image for \(recipe.title)")

                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempFile)
                }
            }

            // Step 2: Upload ingredients
            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                DeviceLogger.shared.log("📤 [Heirloom] Uploading \(ingredients.count) ingredients for \(recipe.title)")
                print("📤 Uploading \(ingredients.count) ingredients")

                let ingredientRecords = ingredients.map { convertIngredientToRecord($0, recipeID: recipeID) }

                // Batch upload ingredients (max 400 records per batch in CloudKit)
                try await uploadIngredientsInBatches(ingredientRecords)

                DeviceLogger.shared.log("✅ [Heirloom] Uploaded \(ingredients.count) ingredients")
                print("✅ Uploaded \(ingredients.count) ingredients")
            }

            // Step 3: Upload card back if exists
            if let cardBack = recipe.cardBack {
                print("📤 Uploading card back for \(recipe.title)")
                let cardBackRecord = convertCardBackToRecord(cardBack, recipeID: recipeID)
                _ = try await database.save(cardBackRecord)
                print("✅ Uploaded card back")
            }

            // Step 4: Upload comments if exist
            if let comments = recipe.comments, !comments.isEmpty {
                print("📤 Uploading \(comments.count) comments for \(recipe.title)")
                let commentRecords = comments.map { convertCommentToRecord($0, recipeID: recipeID) }

                // Batch upload comments
                let operation = CKModifyRecordsOperation(recordsToSave: commentRecords, recordIDsToDelete: nil)
                operation.savePolicy = .allKeys
                operation.database = database

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    operation.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    database.add(operation)
                }

                print("✅ Uploaded \(comments.count) comments")
            }

            // Return the saved recipe record for immediate use (e.g., sharing)
            return savedRecord

        } catch let error as CKError {
            DeviceLogger.shared.log("❌ [Heirloom] Upload failed: \(recipe.title) - Error: \(error.localizedDescription) (code: \(error.errorCode))", level: .error)
            logger.error("❌ [Heirloom] Upload failed: \(error.localizedDescription)")
            print("❌ Upload failed: \(error.localizedDescription)")
            throw handleCloudKitError(error, for: recipe)
        }
    }

    /// Upload ingredient records in batches (CloudKit limit: 400 per batch)
    private func uploadIngredientsInBatches(_ records: [CKRecord]) async throws {
        let batchSize = 400
        for batch in stride(from: 0, to: records.count, by: batchSize) {
            let end = min(batch + batchSize, records.count)
            let batchRecords = Array(records[batch..<end])

            let operation = CKModifyRecordsOperation(recordsToSave: batchRecords, recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.qualityOfService = .userInitiated

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                database.add(operation)
            }
        }
    }

    /// Upload multiple recipes in batch
    func uploadRecipes(_ recipes: [Recipe]) async throws {
        guard !recipes.isEmpty else { return }

        DeviceLogger.shared.log("📤 [Heirloom] Batch uploading \(recipes.count) recipes...")
        print("📤 Batch uploading \(recipes.count) recipes")

        let records = recipes.map { convertToRecord($0) }

        do {
            let (savedRecords, _) = try await database.modifyRecords(saving: records, deleting: [])

            // Update local records
            // Match by recordName instead of index (dictionary order is undefined!)
            var successCount = 0
            for (recordID, result) in savedRecords {
                switch result {
                case .success(let savedRecord):
                    // Find the matching recipe by its ID (recordName matches recipe.id.uuidString)
                    if let recipe = recipes.first(where: { $0.id.uuidString == recordID.recordName }) {
                        recipe.cloudKitRecordID = savedRecord.recordID.recordName
                        recipe.lastSyncedAt = Date()
                        successCount += 1
                        DeviceLogger.shared.log("✅ [Heirloom] Uploaded: \(recipe.title)")
                    } else {
                        DeviceLogger.shared.log("⚠️ [Heirloom] Could not find local recipe for recordID: \(recordID.recordName)", level: .error)
                    }
                case .failure(let error):
                    // Find recipe to log error
                    if let recipe = recipes.first(where: { $0.id.uuidString == recordID.recordName }) {
                        DeviceLogger.shared.log("❌ [Heirloom] Failed to upload \(recipe.title): \(error.localizedDescription)", level: .error)
                    }
                }
            }

            try modelContext?.save()
            DeviceLogger.shared.log("✅ [Heirloom] Batch upload complete: \(successCount)/\(recipes.count) recipes uploaded")
            print("✅ Batch uploaded \(successCount) recipes")

        } catch let error as CKError {
            DeviceLogger.shared.log("❌ [Heirloom] Batch upload failed: \(error.localizedDescription) (code: \(error.errorCode))", level: .error)
            print("❌ Batch upload failed: \(error.localizedDescription)")
            throw SyncError.uploadFailed(error)
        }
    }

    // MARK: - Download Operations

    /// Download a single recipe from CloudKit
    func downloadRecipe(recordID: String) async throws -> Recipe {
        guard let context = modelContext else {
            throw SyncError.notConfigured
        }

        print("📥 Downloading recipe: \(recordID)")

        let ckRecordID = CKRecord.ID(recordName: recordID)
        let record = try await database.record(for: ckRecordID)

        let recipe = convertFromRecord(record, context: context)

        print("✅ Downloaded: \(recipe.title)")
        return recipe
    }

    /// Fetch all remote changes since last sync
    func fetchRemoteChanges(since date: Date = .distantPast) async throws -> [CKRecord] {
        DeviceLogger.shared.log("📥 [Heirloom] Fetching remote changes since: \(date)")
        print("📥 Fetching remote changes since: \(date)")

        // Use fetchAllRecordZoneChanges - the proper CloudKit sync API
        // This doesn't require any queryable indexes
        DeviceLogger.shared.log("🔍 [Heirloom] Fetching all Recipe records from CloudKit (no query)...")

        do {
            // Fetch ALL records of type Recipe using the zone-based API with custom zone
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = nil // Fetch all for now

            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [customZone.zoneID], configurationsByRecordZoneID: [customZone.zoneID: configuration])

            var allRecords: [CKRecord] = []

            operation.recordWasChangedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    if record.recordType == "Recipe" {
                        allRecords.append(record)
                    }
                case .failure(let error):
                    DeviceLogger.shared.log("⚠️ [Heirloom] Record fetch error: \(error.localizedDescription)", level: .error)
                }
            }

            operation.recordZoneFetchResultBlock = { zoneID, result in
                switch result {
                case .success:
                    DeviceLogger.shared.log("📦 [Heirloom] Zone fetch successful")
                case .failure(let error):
                    DeviceLogger.shared.log("❌ [Heirloom] Zone fetch failed: \(error.localizedDescription)", level: .error)
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    DeviceLogger.shared.log("📦 [Heirloom] Fetched \(allRecords.count) total records from CloudKit")
                case .failure(let error):
                    DeviceLogger.shared.log("❌ [Heirloom] Fetch failed: \(error.localizedDescription)", level: .error)
                }
            }

            // Execute operation
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                database.add(operation)
            }

            // Filter by modification date in Swift
            let filteredRecords = allRecords.filter { record in
                guard let modDate = record.modificationDate else { return false }
                return modDate > date
            }

            DeviceLogger.shared.log("✅ [Heirloom] \(filteredRecords.count) records modified since \(date)")
            print("✅ Fetched \(filteredRecords.count) remote changes")
            return filteredRecords

        } catch let error as CKError {
            DeviceLogger.shared.log("❌ [Heirloom] CloudKit fetch failed: \(error.localizedDescription) (code: \(error.code.rawValue))", level: .error)
            throw error
        } catch {
            DeviceLogger.shared.log("❌ [Heirloom] Unexpected fetch error: \(error.localizedDescription)", level: .error)
            throw error
        }
    }

    // MARK: - Full Sync

    /// Perform a full bidirectional sync
    func syncChanges() async throws {
        guard let context = modelContext else {
            throw SyncError.notConfigured
        }

        guard !isSyncing else {
            DeviceLogger.shared.log("⏸️ Sync already in progress, skipping")
            print("⏸️ Sync already in progress, skipping")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        // Ensure custom zone exists before syncing
        await createCustomZoneIfNeeded()

        DeviceLogger.shared.log("🔄 [Heirloom] Starting full sync...")
        logger.info("🔄 [Heirloom] Starting full sync...")
        print("🔄 Starting full sync...")

        do {
            // 1. Upload local changes
            let unsyncedRecipes = try fetchUnsyncedRecipes(context: context)
            if !unsyncedRecipes.isEmpty {
                DeviceLogger.shared.log("📤 [Heirloom] Uploading \(unsyncedRecipes.count) local changes")
                logger.info("📤 [Heirloom] Uploading \(unsyncedRecipes.count) local changes")
                print("📤 Uploading \(unsyncedRecipes.count) local changes")
                try await uploadRecipes(unsyncedRecipes)
            } else {
                DeviceLogger.shared.log("ℹ️ [Heirloom] No local changes to upload")
            }

            // 2. Download remote changes
            let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? .distantPast
            DeviceLogger.shared.log("📥 [Heirloom] Fetching remote changes since: \(lastSync)")
            let remoteRecords = try await fetchRemoteChanges(since: lastSync)

            if !remoteRecords.isEmpty {
                DeviceLogger.shared.log("📥 [Heirloom] Processing \(remoteRecords.count) remote changes")
                print("📥 Processing \(remoteRecords.count) remote changes")
                for record in remoteRecords {
                    try await mergeRemoteRecord(record, context: context)
                }
            } else {
                DeviceLogger.shared.log("ℹ️ [Heirloom] No remote changes to download")
            }

            // 3. Update sync timestamp
            let now = Date()
            UserDefaults.standard.set(now, forKey: "lastSyncDate")
            lastSyncDate = now
            syncError = nil

            DeviceLogger.shared.log("✅ [Heirloom] Sync complete")
            logger.info("✅ [Heirloom] Sync complete")
            print("✅ Sync complete")

        } catch {
            DeviceLogger.shared.log("❌ [Heirloom] Sync failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Heirloom] Sync failed: \(error.localizedDescription)")
            print("❌ Sync failed: \(error.localizedDescription)")
            syncError = error
            throw error
        }
    }

    // MARK: - Conflict Resolution

    /// Merge a remote record into local database
    private func mergeRemoteRecord(_ record: CKRecord, context: ModelContext) async throws {
        let recordID = record.recordID.recordName

        // Check if recipe exists locally
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.cloudKitRecordID == recordID
            }
        )

        let targetRecipe: Recipe
        if let existingRecipe = try context.fetch(descriptor).first {
            // Conflict: Recipe exists locally and remotely
            let resolved = try await resolveConflict(
                local: existingRecipe,
                remoteRecord: record,
                context: context
            )

            // Update existing recipe with resolved data
            updateRecipe(existingRecipe, from: resolved, record: record)
            targetRecipe = existingRecipe

        } else {
            // No conflict: New recipe from remote
            let newRecipe = convertFromRecord(record, context: context)
            context.insert(newRecipe)
            targetRecipe = newRecipe
        }

        // Fetch and restore ingredients for this recipe
        try await fetchAndRestoreIngredients(for: targetRecipe, recipeID: recordID, context: context)

        try context.save()
    }

    /// Fetch ingredients from CloudKit and restore them to the recipe
    private func fetchAndRestoreIngredients(for recipe: Recipe, recipeID: String, context: ModelContext) async throws {
        DeviceLogger.shared.log("📥 [Heirloom] Fetching ingredients for: \(recipe.title)")
        print("📥 Fetching ingredients for: \(recipe.title)")

        // Query for ingredients with matching recipeID
        let predicate = NSPredicate(format: "recipeID == %@", recipeID)
        let query = CKQuery(recordType: "Ingredient", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]

        do {
            let (results, _) = try await database.records(matching: query)
            let ingredientRecords = results.compactMap { try? $0.1.get() }

            if !ingredientRecords.isEmpty {
                DeviceLogger.shared.log("✅ [Heirloom] Found \(ingredientRecords.count) ingredients")
                print("✅ Found \(ingredientRecords.count) ingredients")

                // Clear existing ingredients to avoid duplicates
                recipe.ingredients?.removeAll()

                // Convert records to Ingredient objects and add to recipe
                for ingredientRecord in ingredientRecords {
                    let ingredient = convertIngredientFromRecord(ingredientRecord)
                    ingredient.recipe = recipe
                    context.insert(ingredient)

                    if recipe.ingredients == nil {
                        recipe.ingredients = []
                    }
                    recipe.ingredients?.append(ingredient)
                }
            } else {
                DeviceLogger.shared.log("ℹ️ [Heirloom] No ingredients found for: \(recipe.title)")
                print("ℹ️ No ingredients found for: \(recipe.title)")
            }
        } catch {
            DeviceLogger.shared.log("❌ [Heirloom] Failed to fetch ingredients: \(error.localizedDescription)", level: .error)
            print("❌ Failed to fetch ingredients: \(error.localizedDescription)")
            // Don't throw - allow recipe sync to succeed even if ingredients fail
        }
    }

    /// Resolve conflict between local and remote versions
    private func resolveConflict(
        local: Recipe,
        remoteRecord: CKRecord,
        context: ModelContext
    ) async throws -> Recipe {
        let remote = convertFromRecord(remoteRecord, context: context)

        print("⚠️ Conflict detected: '\(local.title)'")

        // Strategy: Last-write-wins based on modifiedAt
        if local.modifiedAt > remote.modifiedAt {
            print("   → Keeping local version (newer)")
            return local
        } else {
            print("   → Keeping remote version (newer)")
            return remote
        }

        // TODO: Could implement more sophisticated merge strategies:
        // - Merge specific fields
        // - Ask user to resolve
        // - Create duplicate with conflict marker
    }

    /// Update existing recipe with resolved data
    private func updateRecipe(_ existing: Recipe, from resolved: Recipe, record: CKRecord) {
        existing.title = resolved.title
        existing.instructions = resolved.instructions
        existing.servings = resolved.servings
        existing.prepTime = resolved.prepTime
        existing.cookTime = resolved.cookTime
        existing.notes = resolved.notes
        existing.isFavorite = resolved.isFavorite
        existing.modifiedAt = resolved.modifiedAt
        existing.provenance = resolved.provenance
        existing.lastSyncedAt = Date()
    }

    // MARK: - Helpers

    /// Fetch recipes that need to be synced to CloudKit
    private func fetchUnsyncedRecipes(context: ModelContext) throws -> [Recipe] {
        DeviceLogger.shared.log("🔍 [Heirloom] Fetching unsynced recipes...")

        // Fetch all recipes and filter in Swift (SwiftData predicates have issues with optional comparisons)
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        DeviceLogger.shared.log("🔍 [Heirloom] Found \(allRecipes.count) total recipes")

        // Filter for unsynced recipes
        let unsynced = allRecipes.filter { recipe in
            // Never synced OR modified after last sync
            let needsSync = recipe.lastSyncedAt == nil || recipe.modifiedAt > recipe.lastSyncedAt!
            if needsSync {
                DeviceLogger.shared.log("📝 [Heirloom] Recipe '\(recipe.title)' needs sync (lastSynced: \(recipe.lastSyncedAt?.description ?? "never"))")
            }
            return needsSync
        }

        DeviceLogger.shared.log("🔍 [Heirloom] \(unsynced.count) recipes need sync")
        return unsynced
    }

    /// Handle CloudKit-specific errors
    private func handleCloudKitError(_ error: CKError, for recipe: Recipe) -> Error {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            print("📡 Network unavailable - will retry later")
            return SyncError.networkUnavailable

        case .quotaExceeded:
            print("💾 CloudKit quota exceeded")
            return SyncError.quotaExceeded

        case .serverRecordChanged:
            print("⚠️ Server record changed - conflict detected")
            return SyncError.conflict

        case .notAuthenticated:
            print("🔐 User not authenticated with iCloud")
            return SyncError.notAuthenticated

        case .zoneNotFound:
            print("📦 CloudKit zone not found")
            return SyncError.zoneNotFound

        default:
            print("❌ CloudKit error: \(error.localizedDescription)")
            return SyncError.cloudKitError(error)
        }
    }

    // MARK: - Automatic Sync

    /// Start automatic background sync
    func startAutomaticSync() {
        guard !isAutoSyncEnabled else { return }
        isAutoSyncEnabled = true

        DeviceLogger.shared.log("🔄 [Heirloom] Starting automatic sync...")
        logger.info("🔄 [Heirloom] Starting automatic sync...")
        print("🔄 Starting automatic sync...")

        // Initial sync on start
        Task {
            do {
                DeviceLogger.shared.log("🔄 [Heirloom] Performing initial sync on startup...")
                try await syncChanges()
            } catch {
                DeviceLogger.shared.log("❌ [Heirloom] Initial sync failed: \(error.localizedDescription)", level: .error)
            }
        }

        // Sync periodically (every 5 minutes)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                do {
                    try await self?.syncChanges()
                } catch {
                    DeviceLogger.shared.log("❌ [Heirloom] Periodic sync failed: \(error.localizedDescription)", level: .error)
                }
            }
        }

        // Sync when app enters foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                do {
                    DeviceLogger.shared.log("🔄 [Heirloom] App entered foreground, syncing...")
                    try await self?.syncChanges()
                } catch {
                    DeviceLogger.shared.log("❌ [Heirloom] Foreground sync failed: \(error.localizedDescription)", level: .error)
                }
            }
        }

        DeviceLogger.shared.log("✅ [Heirloom] Automatic sync enabled")
        logger.info("✅ [Heirloom] Automatic sync enabled")
        print("✅ Automatic sync enabled")
    }
}

// MARK: - Errors

extension CloudKitSyncService {
    enum SyncError: LocalizedError {
        case notConfigured
        case networkUnavailable
        case quotaExceeded
        case conflict
        case notAuthenticated
        case zoneNotFound
        case uploadFailed(Error)
        case downloadFailed(Error)
        case cloudKitError(CKError)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Sync service not configured with model context"
            case .networkUnavailable:
                return "Network unavailable - changes will sync when connection is restored"
            case .quotaExceeded:
                return "iCloud storage quota exceeded"
            case .conflict:
                return "Sync conflict detected"
            case .notAuthenticated:
                return "Please sign in to iCloud in Settings"
            case .zoneNotFound:
                return "CloudKit zone not found"
            case .uploadFailed(let error):
                return "Upload failed: \(error.localizedDescription)"
            case .downloadFailed(let error):
                return "Download failed: \(error.localizedDescription)"
            case .cloudKitError(let error):
                return "CloudKit error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
