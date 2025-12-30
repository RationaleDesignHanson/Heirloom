import Foundation
import CloudKit
import SwiftData
import UIKit

/// Service for creating and managing CKShare-based recipe sharing
/// Handles share creation, URL generation, permissions, and revocation
///
/// This is the primary sharing service - uses native CloudKit CKShare for:
/// - Private database sharing (more secure than public)
/// - Email-based participant invitations
/// - Proper permission management
/// - Pass down with generational tracking
@MainActor
final class RecipeShareService {
    // MARK: - Singleton

    static let shared = RecipeShareService()

    private init() {}

    // MARK: - Dependencies

    private let container: CKContainer = CKContainer.default()
    private let coordinator = CloudKitSyncCoordinator.shared
    private let monitor = CloudKitMonitoringService.shared

    // Use same custom zone as CloudKitSyncService
    private let customZone = CKRecordZone(zoneName: "HeirloomRecipes")

    // MARK: - Share Creation

    /// Create a CKShare for a recipe with specified options
    /// - Parameters:
    ///   - recipe: The recipe to share
    ///   - options: Configuration for what to include
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: The created CKShare with URL
    func createShare(
        for recipe: Recipe,
        options: ShareOptions,
        context: ModelContext
    ) async throws -> CKShare {
        print("📤 Creating share for recipe: \(recipe.title)")
        DeviceLogger.shared.log("📤 Creating share for recipe: \(recipe.title)")

        // 1. Ensure recipe has CloudKit record and get the CKRecord
        let rootRecord = try await ensureCloudKitRecord(for: recipe, context: context)

        print("✅ Recipe has CloudKit record: \(rootRecord.recordID.recordName)")
        DeviceLogger.shared.log("✅ Recipe has CloudKit record: \(rootRecord.recordID.recordName)")

        // Check if share already exists
        if let existingShare = try await getExistingShare(for: recipe) {
            print("ℹ️ Share already exists for this recipe")
            DeviceLogger.shared.log("ℹ️ Share already exists for recipe")
            return existingShare
        }

        // 2. Create CKShare from the root record
        let share = CKShare(rootRecord: rootRecord)

        // 3. Configure share metadata
        share[CKShare.SystemFieldKey.title] = recipe.title as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "recipe" as CKRecordValue

        // Set thumbnail if available
        if recipe.imageFileName != nil {
            // TODO: Convert image to CKAsset
            // share[CKShare.SystemFieldKey.thumbnailImageData] = imageAsset
        }

        // 4. Configure permissions
        // Use readOnly for link-based sharing (anyone with link can view)
        // For private sharing with specific people, use .none and add participants
        share.publicPermission = .readOnly // Allow link-based sharing
        // Store permission as custom field
        share["permission"] = options.permission.rawValue as CKRecordValue

        // 5. Set expiration (no built-in expiration, store as custom field for UI)
        if let expirationDate = options.expirationDuration?.expirationDate {
            share["expiresAt"] = expirationDate as CKRecordValue
        }

        // 6. Add custom metadata (store as custom fields for preview)
        share["title"] = recipe.title as CKRecordValue
        share["servings"] = recipe.servings as? CKRecordValue
        share["prepTime"] = recipe.prepTime as? CKRecordValue
        share["cookTime"] = recipe.cookTime as? CKRecordValue
        share["ingredientCount"] = (recipe.ingredients?.count ?? 0) as CKRecordValue
        share["instructionCount"] = recipe.instructions.count as CKRecordValue
        share["personalMessage"] = options.personalMessage as? CKRecordValue
        share["sharerName"] = options.sharerName as? CKRecordValue
        share["includeCardBack"] = (options.includeCardBack ? 1 : 0) as CKRecordValue
        share["includeRating"] = (options.includeRating ? 1 : 0) as CKRecordValue
        share["includePinnedComments"] = (options.includePinnedComments ? 1 : 0) as CKRecordValue
        share["allowReSharing"] = (options.allowReSharing ? 1 : 0) as CKRecordValue
        share["generation"] = (recipe.provenance?.generation ?? 0) as CKRecordValue

        // 7. Save share AND root record together to CloudKit
        // CloudKit REQUIRES both to be saved in the same operation
        DeviceLogger.shared.log("💾 Saving new share to CloudKit...")
        let savedShare = try await saveShare(share, withRootRecord: rootRecord)

        print("✅ Share created successfully: \(savedShare.url?.absoluteString ?? "no URL")")
        DeviceLogger.shared.log("✅ New share created successfully")

        // NOTE: CloudKit automatically shares child records that have CKReferences to the root record
        // Ingredients and other related data will be accessible through the share if properly linked

        // 10. Update recipe provenance
        updateProvenanceForSharing(recipe: recipe, share: savedShare)

        // 11. Track analytics
        trackShareCreated(recipe: recipe, options: options)

        return savedShare
    }

    /// Generate a shareable URL from a CKShare
    /// - Parameter share: The CKShare to generate URL for
    /// - Returns: Shareable URL in heirloom:// format for deep linking
    func generateShareURL(from share: CKShare) -> URL? {
        guard let cloudKitURL = share.url else {
            return nil
        }

        // Convert CloudKit URL to heirloom:// deep link format
        // This ensures the link opens the app and triggers share acceptance
        let urlString = cloudKitURL.absoluteString
        guard let encodedURL = urlString.data(using: .utf8)?.base64EncodedString() else {
            return nil
        }

        let heirloomURL = "heirloom://share/\(encodedURL)"
        return URL(string: heirloomURL)
    }

    /// Generate a short link for easier sharing
    /// - Parameter share: The CKShare
    /// - Returns: Shortened URL (e.g., heirloom.app/r/abc123)
    func generateShortLink(from share: CKShare) async throws -> URL {
        guard let longURL = share.url else {
            throw ShareError.noShareURL
        }

        return try await ShortURLService.shared.generateShortURL(from: longURL)
    }

    /// Generate a short link with QR code for sharing
    /// - Parameters:
    ///   - share: The CKShare
    ///   - qrSize: Size of QR code image (default: 512)
    /// - Returns: Tuple with shortened URL and QR code image
    func generateSharePackage(from share: CKShare, qrSize: CGFloat = 512) async throws -> (shortURL: URL, qrCode: UIImage?) {
        guard let longURL = share.url else {
            throw ShareError.noShareURL
        }

        let shortURL = try await ShortURLService.shared.generateShortURL(from: longURL)
        let qrCode = ShortURLService.shared.generateQRCode(for: shortURL, size: qrSize)
        return (shortURL: shortURL, qrCode: qrCode)
    }

    /// Generate QR code for a share
    /// - Parameters:
    ///   - share: The CKShare
    ///   - size: Size of QR code image (default: 512)
    /// - Returns: QR code image
    func generateQRCode(from share: CKShare, size: CGFloat = 512) -> UIImage? {
        guard let url = share.url else {
            return nil
        }

        return ShortURLService.shared.generateQRCode(for: url, size: size)
    }

    // MARK: - Share Management

    /// Get existing share for a recipe if one exists
    /// - Parameter recipe: The recipe to check for existing shares
    /// - Returns: The existing CKShare if found, nil otherwise
    func getExistingShare(for recipe: Recipe) async throws -> CKShare? {
        // Recipe must have CloudKit record ID to query for shares
        guard let recordIDString = recipe.cloudKitRecordID else {
            return nil
        }

        let recordID = CKRecord.ID(recordName: recordIDString, zoneID: customZone.zoneID)
        let database = container.privateCloudDatabase

        do {
            // Fetch the recipe record first
            let record = try await database.record(for: recordID)

            // Check if this record has an associated share
            if let shareReference = record.share {
                print("ℹ️ Recipe has existing share reference")

                // Fetch the share
                let share = try await database.record(for: shareReference.recordID)
                if let ckShare = share as? CKShare {
                    print("ℹ️ Found existing share for recipe: \(recipe.title)")
                    return ckShare
                }
            }

            print("ℹ️ No existing share found for recipe: \(recipe.title)")
            return nil
        } catch {
            print("⚠️ Error checking for existing share: \(error.localizedDescription)")
            // Return nil on error - caller will create new share
            return nil
        }
    }

    /// Revoke an existing share
    /// - Parameter share: The CKShare to revoke
    func revokeShare(_ share: CKShare) async throws {
        print("🗑️ Revoking share: \(share.recordID.recordName)")

        let database = container.privateCloudDatabase
        try await database.deleteRecord(withID: share.recordID)

        print("✅ Share revoked successfully")
    }

    /// Check the status of a share
    /// - Parameter shareID: The CKShare record ID
    /// - Returns: ShareStatus with participant info
    func checkShareStatus(_ shareID: String) async throws -> ShareStatus {
        let recordID = CKRecord.ID(recordName: shareID, zoneID: customZone.zoneID)
        let database = container.privateCloudDatabase

        do {
            let share = try await database.record(for: recordID) as? CKShare
            guard let share = share else {
                throw ShareError.shareNotFound
            }

            return ShareStatus(
                isActive: true,
                participantCount: share.participants.count,
                acceptedCount: share.participants.filter { $0.acceptanceStatus == .accepted }.count,
                owner: share.owner.userIdentity.nameComponents?.formatted() ?? "Unknown",
                createdAt: share.creationDate,
                expiresAt: share["expiresAt"] as? Date
            )
        } catch {
            print("❌ Error checking share status: \(error)")
            throw ShareError.checkFailed(error)
        }
    }

    /// List all active shares for the current user
    func listActiveShares() async throws -> [CKShare] {
        print("📋 Fetching active shares...")

        let database = container.privateCloudDatabase
        let query = CKQuery(
            recordType: "cloudkit.share",
            predicate: NSPredicate(value: true)
        )

        let results = try await database.records(matching: query)
        let shares = results.matchResults.compactMap { try? $0.1.get() as? CKShare }

        print("✅ Found \(shares.count) active shares")
        return shares
    }

    // MARK: - Helper Methods

    /// Ensure recipe has a CloudKit record
    /// Uses CloudKitSyncService for hybrid architecture
    private func ensureCloudKitRecord(
        for recipe: Recipe,
        context: ModelContext
    ) async throws -> CKRecord {
        // Wrap in retry logic for transient errors
        return try await CloudKitRetryHelper.withRetry(maxAttempts: 3) {
            // Check if recipe already has CloudKit metadata from manual sync
            if let existingRecordID = recipe.cloudKitRecordID {
                // Recipe already synced - try to fetch the existing record
                let recordID = CKRecord.ID(recordName: existingRecordID, zoneID: self.customZone.zoneID)

                do {
                    let record = try await self.fetchRecord(recordID)
                    print("✅ Found existing CloudKit record for recipe")
                    return record
                } catch {
                    // Record not found (stale ID) - clear it and re-upload
                    let ckError = error as? CKError
                    if ckError?.code == .unknownItem {
                        print("⚠️ Stale CloudKit record ID, re-uploading recipe...")
                        recipe.cloudKitRecordID = nil

                        // Fall through to upload below
                    } else {
                        // Other error - rethrow
                        throw error
                    }
                }
            }

            // Recipe not synced yet (or had stale ID) - trigger immediate upload
            print("📤 Recipe not synced yet, uploading to CloudKit...")
            let savedRecord = try await CloudKitSyncService.shared.uploadRecipe(recipe)

            print("✅ Recipe uploaded and returned: \(savedRecord.recordID.recordName)")
            return savedRecord
        }
    }

    /// Fetch a CloudKit record by ID with automatic retry
    private func fetchRecord(_ recordID: CKRecord.ID) async throws -> CKRecord {
        return try await CloudKitRetryHelper.withRetry(maxAttempts: 3) {
            let database = self.container.privateCloudDatabase
            return try await database.record(for: recordID)
        }
    }

    /// Save a share AND its root record together to CloudKit
    /// CloudKit requires the share and root record to be saved in the same operation
    private func saveShare(_ share: CKShare, withRootRecord rootRecord: CKRecord? = nil) async throws -> CKShare {
        let database = container.privateCloudDatabase

        DeviceLogger.shared.log("🔍 saveShare called with rootRecord: \(rootRecord != nil ? "YES" : "NO")")

        // If we have a root record, save both together (required for new shares)
        if let rootRecord = rootRecord {
            DeviceLogger.shared.log("✅ Root record exists, proceeding with child record fetch")
            // Fetch all child records (ingredients, card back, comments) to include in share
            var allRecordsToSave: [CKRecord] = [rootRecord, share]

            DeviceLogger.shared.log("📦 Fetching child records to include in share...")
            DeviceLogger.shared.log("   Recipe ID: \(rootRecord.recordID.recordName)")

            // Fetch ingredients
            do {
                let ingredientPredicate = NSPredicate(format: "recipeID == %@", rootRecord.recordID.recordName)
                let ingredientQuery = CKQuery(recordType: "Ingredient", predicate: ingredientPredicate)
                let (ingredientResults, _) = try await database.records(matching: ingredientQuery, inZoneWith: customZone.zoneID)

                var successCount = 0
                for (_, result) in ingredientResults {
                    if case .success(let record) = result {
                        allRecordsToSave.append(record)
                        successCount += 1
                    }
                }
                DeviceLogger.shared.log("📦 Including \(successCount) ingredients in share")
            } catch {
                DeviceLogger.shared.log("⚠️ Failed to fetch ingredients for share: \(error.localizedDescription)")
            }

            // Fetch card back
            do {
                let cardBackPredicate = NSPredicate(format: "recipeID == %@", rootRecord.recordID.recordName)
                let cardBackQuery = CKQuery(recordType: "RecipeCardBack", predicate: cardBackPredicate)
                let (cardBackResults, _) = try await database.records(matching: cardBackQuery, inZoneWith: customZone.zoneID)

                if let (_, result) = cardBackResults.first, case .success(let record) = result {
                    allRecordsToSave.append(record)
                    DeviceLogger.shared.log("📦 Including card back in share")
                }
            } catch {
                DeviceLogger.shared.log("⚠️ Failed to fetch card back for share: \(error.localizedDescription)")
            }

            // Fetch comments
            do {
                let commentPredicate = NSPredicate(format: "recipeID == %@ AND isPinned == 1", rootRecord.recordID.recordName)
                let commentQuery = CKQuery(recordType: "RecipeComment", predicate: commentPredicate)
                let (commentResults, _) = try await database.records(matching: commentQuery, inZoneWith: customZone.zoneID)

                var successCount = 0
                for (_, result) in commentResults {
                    if case .success(let record) = result {
                        allRecordsToSave.append(record)
                        successCount += 1
                    }
                }
                if successCount > 0 {
                    DeviceLogger.shared.log("📦 Including \(successCount) comments in share")
                }
            } catch {
                DeviceLogger.shared.log("⚠️ Failed to fetch comments for share: \(error.localizedDescription)")
            }

            DeviceLogger.shared.log("📦 Total records to save: \(allRecordsToSave.count) (recipe + share + child records)")

            return try await withCheckedThrowingContinuation { continuation in
                let operation = CKModifyRecordsOperation(
                    recordsToSave: allRecordsToSave,
                    recordIDsToDelete: nil
                )
                
                operation.savePolicy = .changedKeys

                // Track the saved share with URL
                var savedShareWithURL: CKShare?

                operation.perRecordSaveBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        DeviceLogger.shared.log("✅ Saved record: \(recordID.recordName) (type: \(String(describing: type(of: record))))")
                        // Capture the saved CKShare which has the URL from CloudKit
                        if let savedShare = record as? CKShare {
                            savedShareWithURL = savedShare
                            DeviceLogger.shared.log("📎 Share URL received: \(savedShare.url?.absoluteString ?? "nil")")
                        }
                    case .failure(let error):
                        DeviceLogger.shared.log("❌ Failed to save record \(recordID.recordName): \(error.localizedDescription)")
                    }
                }

                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        DeviceLogger.shared.log("✅ Modify records operation succeeded")

                        // Wait for CloudKit to fully process - the URL populates asynchronously
                        Task {
                            // Give CloudKit a moment to populate the URL on the saved share object
                            for attempt in 1...5 {
                                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                                if let shareWithURL = savedShareWithURL, shareWithURL.url != nil {
                                    print("✅ Share URL populated after \(attempt)s: \(shareWithURL.url!.absoluteString)")
                                    continuation.resume(returning: shareWithURL)
                                    return
                                }

                                print("⏳ Waiting for URL (attempt \(attempt)/5)...")
                            }

                            // After 5 seconds, return what we have
                            print("⚠️ Timeout waiting for URL, returning share anyway")
                            continuation.resume(returning: savedShareWithURL ?? share)
                        }

                    case .failure(let error):
                        print("❌ CKModifyRecordsOperation failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
                
                database.add(operation)
            }
        } else {
            // No root record - just save the share (for updates)
            let savedRecord = try await database.save(share)
            guard let savedShare = savedRecord as? CKShare else {
                throw ShareError.saveFailed
            }
            return savedShare
        }
    }

    /// Upload ingredients to shared zone so recipients can access them
    private func uploadIngredientsToSharedZone(
        ingredients: [Ingredient],
        recipeID: String,
        share: CKShare
    ) async throws {
        // Get the shared zone ID from the share
        let sharedZoneID = share.recordID.zoneID
        DeviceLogger.shared.log("  🔧 Using shared zone: \(sharedZoneID.zoneName)")

        // Convert ingredients to CloudKit records in the shared zone
        let ingredientRecords = ingredients.map { ingredient in
            let recordID = CKRecord.ID(
                recordName: "Ingredient_\(ingredient.id.uuidString)",
                zoneID: sharedZoneID  // Use shared zone, not private zone!
            )
            let record = CKRecord(recordType: "Ingredient", recordID: recordID)

            // Copy all ingredient fields
            record["ingredientID"] = ingredient.id.uuidString as CKRecordValue
            record["recipeID"] = recipeID as CKRecordValue
            record["originalText"] = ingredient.originalText as CKRecordValue
            record["quantity"] = ingredient.quantity as CKRecordValue?
            record["quantityMax"] = ingredient.quantityMax as CKRecordValue?
            record["unit"] = ingredient.unit as CKRecordValue?
            record["normalizedUnit"] = ingredient.normalizedUnit as CKRecordValue?
            record["name"] = ingredient.name as CKRecordValue
            record["preparation"] = ingredient.preparation as CKRecordValue?
            record["size"] = ingredient.size as CKRecordValue?
            record["category"] = ingredient.category?.rawValue as CKRecordValue?
            record["orderIndex"] = ingredient.orderIndex as CKRecordValue
            record["isSelected"] = (ingredient.isSelected ? 1 : 0) as CKRecordValue
            record["isCheckedOff"] = (ingredient.isCheckedOff ? 1 : 0) as CKRecordValue
            record["isOptional"] = (ingredient.isOptional ? 1 : 0) as CKRecordValue

            return record
        }

        // Upload to shared database (not private!)
        let database = container.sharedCloudDatabase

        // Batch upload (CloudKit limit: 400 per batch)
        let batchSize = 400
        for batch in stride(from: 0, to: ingredientRecords.count, by: batchSize) {
            let end = min(batch + batchSize, ingredientRecords.count)
            let batchRecords = Array(ingredientRecords[batch..<end])

            let operation = CKModifyRecordsOperation(recordsToSave: batchRecords, recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.database = database

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        DeviceLogger.shared.log("  ✅ Uploaded ingredients batch (\(batchRecords.count) records)")
                        continuation.resume()
                    case .failure(let error):
                        print("❌ Failed to upload ingredients batch: \(error.localizedDescription)")
                        DeviceLogger.shared.log("  ❌ Failed to upload ingredients batch: \(error.localizedDescription)", level: .error)
                        continuation.resume(throwing: error)
                    }
                }
                database.add(operation)
            }
        }
    }

    /// Upload image to shared zone as a separate RecipeImage record
    private func uploadImageToSharedZone(
        imageFileName: String,
        recipeID: UUID,
        rootRecordName: String,
        share: CKShare
    ) async throws {
        // Get the shared zone ID from the share
        let sharedZoneID = share.recordID.zoneID
        DeviceLogger.shared.log("  🔧 Using shared zone: \(sharedZoneID.zoneName)")

        // Load image from local storage
        guard let image = await ImageStorageService.shared.loadImage(fileName: imageFileName) else {
            print("⚠️ Could not load image: \(imageFileName)")
            DeviceLogger.shared.log("  ⚠️ Could not load image from disk: \(imageFileName)", level: .warning)
            return
        }
        DeviceLogger.shared.log("  ✅ Loaded image from disk")

        // Convert to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("⚠️ Could not convert image to JPEG")
            DeviceLogger.shared.log("  ⚠️ Could not convert image to JPEG", level: .warning)
            return
        }
        DeviceLogger.shared.log("  ✅ Converted image to JPEG (\(imageData.count) bytes)")

        // Create temporary file for CKAsset
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(recipeID.uuidString)_image.jpg")

        try imageData.write(to: tempFile)
        DeviceLogger.shared.log("  ✅ Wrote image to temp file")

        // Create a RecipeImage record in the shared zone (similar to ingredients)
        let imageRecordID = CKRecord.ID(
            recordName: "RecipeImage_\(recipeID.uuidString)",
            zoneID: sharedZoneID
        )
        let imageRecord = CKRecord(recordType: "RecipeImage", recordID: imageRecordID)

        // Link to recipe
        imageRecord["recipeID"] = rootRecordName as CKRecordValue
        imageRecord["imageFileName"] = imageFileName as CKRecordValue

        // Attach image asset
        let imageAsset = CKAsset(fileURL: tempFile)
        imageRecord["imageAsset"] = imageAsset

        // Upload to shared database
        let database = container.sharedCloudDatabase
        _ = try await database.save(imageRecord)

        print("✅ Image uploaded to shared zone")
        DeviceLogger.shared.log("  ✅ RecipeImage record saved to shared database")

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempFile)
    }

    /// Update recipe provenance after sharing
    private func updateProvenanceForSharing(recipe: Recipe, share: CKShare) {
        guard var provenance = recipe.provenance else { return }

        // Increment share count
        provenance.cachedMetrics.totalShares += 1
        provenance.cachedMetrics.lastUpdated = Date()

        recipe.provenance = provenance

        // CloudKit metadata already tracked at recipe level via CloudKitSyncService
    }

    /// Track share creation analytics
    private func trackShareCreated(recipe: Recipe, options: ShareOptions) {
        // TODO: Send to analytics service
        print("📊 Analytics: Recipe shared - \(recipe.title)")
        print("   Permission: \(options.permission.rawValue)")
        print("   Expiration: \(options.expirationDuration?.displayName ?? "Never")")
        print("   Includes personalization: \(options.includesPersonalization)")
    }
}

// MARK: - Supporting Types

extension RecipeShareService {
    struct ShareStatus {
        let isActive: Bool
        let participantCount: Int
        let acceptedCount: Int
        let owner: String
        let createdAt: Date?
        let expiresAt: Date?

        var isExpired: Bool {
            guard let expiresAt = expiresAt else { return false }
            return expiresAt < Date()
        }

        var pendingCount: Int {
            participantCount - acceptedCount
        }

        var statusText: String {
            if isExpired {
                return "Expired"
            } else if acceptedCount == 0 {
                return "Pending"
            } else if acceptedCount == participantCount {
                return "Active (\(acceptedCount) accepted)"
            } else {
                return "Partially accepted (\(acceptedCount)/\(participantCount))"
            }
        }
    }

    enum ShareError: LocalizedError {
        case noRecordID
        case noShareURL
        case shareNotFound
        case saveFailed
        case checkFailed(Error)
        case participantNotFound
        case notAuthenticated
        case notAShare

        var errorDescription: String? {
            switch self {
            case .noRecordID:
                return "Recipe does not have a CloudKit record ID"
            case .noShareURL:
                return "Share was created but no URL was generated"
            case .shareNotFound:
                return "Share not found in CloudKit"
            case .saveFailed:
                return "Failed to save share to CloudKit"
            case .checkFailed(let error):
                return "Failed to check share status: \(error.localizedDescription)"
            case .participantNotFound:
                return "Could not find iCloud user with that email. They can still use the share link."
            case .notAuthenticated:
                return "Please sign in to iCloud to share recipes"
            case .notAShare:
                return "Fetched record is not a valid share"
            }
        }
    }
}

// MARK: - Pass Down (Family Sharing)

extension RecipeShareService {
    /// Pass down options for family recipe sharing
    struct PassDownOptions {
        /// Recipient's name (for provenance tracking)
        var recipientName: String
        
        /// Recipient's email (for CloudKit invitation)
        var recipientEmail: String?
        
        /// Personal message/story about the recipe
        var message: String?
        
        /// Sharer's name (auto-filled from iCloud if nil)
        var sharerName: String?
    }
    
    /// Pass down a recipe to a family member with generational tracking
    /// - Parameters:
    ///   - recipe: The recipe to pass down
    ///   - options: Pass down configuration including recipient info
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: The created CKShare with URL for sharing
    func passDownRecipe(
        _ recipe: Recipe,
        options: PassDownOptions,
        context: ModelContext
    ) async throws -> CKShare {
        print("🎁 Passing down recipe: \(recipe.title) to \(options.recipientName)")
        
        // 1. Get sharer name first (separate async call)
        var sharerName = options.sharerName
        if sharerName == nil {
            sharerName = try? await getCurrentUserName()
        }
        
        // 2. Create base share options for pass down
        var shareOptions = ShareOptions.full // Include everything for family sharing
        shareOptions.personalMessage = options.message
        shareOptions.sharerName = sharerName
        shareOptions.expirationDuration = .never // Family shares don't expire
        shareOptions.allowReSharing = true // Allow further passing down
        
        // 2. Ensure recipe has CloudKit record and get the CKRecord
        let record = try await ensureCloudKitRecord(for: recipe, context: context)

        print("✅ Recipe has CloudKit record for pass down: \(record.recordID.recordName)")

        // 3. Create share from the root record
        let share = CKShare(rootRecord: record)
        
        // 4. Configure share metadata
        share[CKShare.SystemFieldKey.title] = recipe.title as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "passdown" as CKRecordValue
        
        // 5. Set pass-down specific metadata
        share["isPassDown"] = 1 as CKRecordValue
        share["recipientName"] = options.recipientName as CKRecordValue
        share["passDownMessage"] = options.message as? CKRecordValue
        share["sharerName"] = shareOptions.sharerName as? CKRecordValue
        share["generation"] = (recipe.generationCount) as CKRecordValue
        share["nextGeneration"] = (recipe.generationCount + 1) as CKRecordValue
        
        // 6. Add recipient as participant if email provided
        if let email = options.recipientEmail, !email.isEmpty {
            let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: email)
            share.publicPermission = .none // Private share
            
            // Fetch user identity and add as participant
            do {
                let participant = try await lookupParticipant(lookupInfo: lookupInfo)
                participant.permission = .readWrite
                share.addParticipant(participant)
                print("✅ Added participant: \(email)")
            } catch {
                // If lookup fails, still create shareable link
                print("⚠️ Could not add participant directly, will use link sharing: \(error.localizedDescription)")
                share.publicPermission = .readOnly
            }
        } else {
            // No email - create link-based share
            share.publicPermission = .readOnly
        }
        
        // 7. Save share AND root record together to CloudKit
        // CloudKit REQUIRES both to be saved in the same operation
        let savedShare = try await saveShare(share, withRootRecord: record)
        
        print("✅ Pass down share created: \(savedShare.url?.absoluteString ?? "no URL")")
        
        // 8. Update recipe provenance for pass down
        updateProvenanceForPassDown(recipe: recipe, share: savedShare, recipientName: options.recipientName)
        try context.save()
        
        // 9. Track analytics
        trackPassDownCreated(recipe: recipe, options: options)
        
        // 10. Log to monitor
        monitor.logSyncEvent(
            type: .passDown,
            details: "Passed down '\(recipe.title)' to \(options.recipientName)",
            success: true
        )
        
        return savedShare
    }
    
    /// Lookup a CloudKit participant by email
    private func lookupParticipant(lookupInfo: CKUserIdentity.LookupInfo) async throws -> CKShare.Participant {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareParticipantsOperation(userIdentityLookupInfos: [lookupInfo])
            
            var foundParticipant: CKShare.Participant?
            
            operation.perShareParticipantResultBlock = { _, result in
                switch result {
                case .success(let participant):
                    foundParticipant = participant
                case .failure(let error):
                    print("⚠️ Participant lookup failed: \(error.localizedDescription)")
                }
            }
            
            operation.fetchShareParticipantsResultBlock = { result in
                switch result {
                case .success:
                    if let participant = foundParticipant {
                        continuation.resume(returning: participant)
                    } else {
                        continuation.resume(throwing: ShareError.participantNotFound)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            container.add(operation)
        }
    }
    
    /// Update provenance specifically for pass down
    private func updateProvenanceForPassDown(recipe: Recipe, share: CKShare, recipientName: String) {
        // Update existing provenance or create new
        if var provenance = recipe.provenance {
            // Pass downs count as shares for metrics
            provenance.cachedMetrics.totalShares += 1
            provenance.cachedMetrics.lastUpdated = Date()
            recipe.provenance = provenance
        }

        // CloudKit metadata already tracked at recipe level via CloudKitSyncService

        // Also update legacy fields for compatibility
        recipe.passedDownDate = Date()
        recipe.sharedDate = Date()
    }
    
    /// Track pass down analytics
    private func trackPassDownCreated(recipe: Recipe, options: PassDownOptions) {
        print("📊 Analytics: Recipe passed down - \(recipe.title)")
        print("   To: \(options.recipientName)")
        print("   Generation: \(recipe.generationCount) → \(recipe.generationCount + 1)")
        print("   Has email: \(options.recipientEmail != nil)")
        print("   Has message: \(options.message != nil)")
        
        AnalyticsService.shared.track(event: .recipeShared, properties: [
            "method": "passdown",
            "has_recipient_email": options.recipientEmail != nil,
            "generation": recipe.generationCount
        ])
    }
    
    /// Get current user's name from iCloud
    /// Uses CKFetchShareParticipantsOperation for iOS 17+ compatibility
    func getCurrentUserName() async throws -> String {
        // Try to get user record ID and use it as a fallback identifier
        do {
            let userRecordID = try await container.userRecordID()
            
            // For now, use a friendly fallback since the deprecated API
            // was the main way to get user names. In production, you would
            // typically get the user's name from their profile or ask them.
            // The record name is a UUID, so we return a friendly default.
            print("📱 User record ID: \(userRecordID.recordName)")
            
            // Return a friendly default - the actual name will come from
            // the user's input or their iCloud profile when they accept shares
            return "A Family Member"
        } catch {
            print("⚠️ Could not get user record ID: \(error.localizedDescription)")
            return "A Family Member"
        }
    }
}

// MARK: - Share with Email Invitation

extension RecipeShareService {
    /// Share a recipe directly to an email address
    /// - Parameters:
    ///   - recipe: The recipe to share
    ///   - email: Recipient's email address
    ///   - options: Share configuration
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: The created CKShare
    func shareToEmail(
        recipe: Recipe,
        email: String,
        options: ShareOptions,
        context: ModelContext
    ) async throws -> CKShare {
        print("📧 Sharing recipe to email: \(email)")
        
        // 1. Create the base share
        let share = try await createShare(for: recipe, options: options, context: context)
        
        // 2. Try to add participant by email
        let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: email)
        
        do {
            let participant = try await lookupParticipant(lookupInfo: lookupInfo)
            participant.permission = options.permission == .readWrite ? .readWrite : .readOnly
            share.addParticipant(participant)
            
            // Re-save with participant
            let updatedShare = try await saveShare(share)
            print("✅ Added email participant and saved share")
            
            return updatedShare
        } catch {
            // Participant lookup failed - they may not have an iCloud account
            // The share link will still work
            print("⚠️ Could not add participant directly (they may not have iCloud): \(error.localizedDescription)")
            return share
        }
    }

    // MARK: - Retry Logic

    /// Fetch share with retry logic and exponential backoff
    /// CloudKit may take time to generate the share URL after save
    private func fetchShareWithRetry(
        shareRecordID: CKRecord.ID,
        database: CKDatabase,
        maxAttempts: Int,
        delays: [TimeInterval]
    ) async throws -> CKShare? {
        var attempt = 0

        while attempt < maxAttempts {
            let delay = attempt < delays.count ? delays[attempt] : delays.last ?? 5.0

            // Wait before fetching (except first attempt)
            if delay > 0 {
                print("⏳ Waiting \(delay)s before fetch attempt \(attempt + 1)/\(maxAttempts)...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            print("🔄 Fetching share (attempt \(attempt + 1)/\(maxAttempts))...")

            do {
                let fetchedRecord = try await database.record(for: shareRecordID)

                if let fetchedShare = fetchedRecord as? CKShare {
                    if let url = fetchedShare.url {
                        print("✅ Share URL obtained on attempt \(attempt + 1): \(url.absoluteString)")
                        DeviceLogger.shared.log("✅ Share URL obtained on attempt \(attempt + 1)")
                        return fetchedShare
                    } else {
                        print("⚠️ Share fetched but URL still nil (attempt \(attempt + 1))")
                        // URL not ready yet, will retry
                    }
                } else {
                    print("❌ Fetched record is not a CKShare")
                    throw ShareError.notAShare
                }
            } catch {
                print("❌ Fetch failed on attempt \(attempt + 1): \(error.localizedDescription)")
                if attempt == maxAttempts - 1 {
                    // Last attempt failed, throw error
                    throw error
                }
            }

            attempt += 1
        }

        print("❌ Failed to get share URL after \(maxAttempts) attempts")
        DeviceLogger.shared.log("❌ Failed to get share URL after \(maxAttempts) attempts", level: .error)
        return nil
    }
}

// MARK: - Convenience Methods

extension RecipeShareService {
    /// Quick share with default options
    func quickShare(recipe: Recipe, context: ModelContext) async throws -> CKShare {
        return try await createShare(for: recipe, options: .default, context: context)
    }

    /// Share with personal message
    func shareWithMessage(
        recipe: Recipe,
        message: String,
        context: ModelContext
    ) async throws -> CKShare {
        var options = ShareOptions.default
        options.personalMessage = message
        return try await createShare(for: recipe, options: options, context: context)
    }
    
    /// Quick pass down with just name and message
    func quickPassDown(
        recipe: Recipe,
        recipientName: String,
        message: String?,
        context: ModelContext
    ) async throws -> CKShare {
        let options = PassDownOptions(
            recipientName: recipientName,
            recipientEmail: nil,
            message: message,
            sharerName: nil
        )
        return try await passDownRecipe(recipe, options: options, context: context)
    }
}
