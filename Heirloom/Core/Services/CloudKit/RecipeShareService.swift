import Foundation
import CloudKit
import SwiftData

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

        // 1. Ensure recipe has CloudKit record ID
        guard let recordID = try await ensureCloudKitRecord(for: recipe, context: context) else {
            throw ShareError.noRecordID
        }

        print("✅ Recipe has CloudKit record: \(recordID.recordName)")

        // 2. Fetch the root record and create CKShare
        let rootRecord = try await fetchRecord(recordID)
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
        share.publicPermission = .none // Private share only
        // Store permission as custom field
        share["permission"] = options.permission.rawValue as CKRecordValue

        // 5. Set expiration (no built-in expiration, store as custom field for UI)
        if let expirationDate = options.expirationDuration?.expirationDate {
            share["expiresAt"] = expirationDate as CKRecordValue
        }

        // 6. Add custom metadata
        share["personalMessage"] = options.personalMessage as? CKRecordValue
        share["sharerName"] = options.sharerName as? CKRecordValue
        share["includeCardBack"] = (options.includeCardBack ? 1 : 0) as CKRecordValue
        share["includeRating"] = (options.includeRating ? 1 : 0) as CKRecordValue
        share["allowReSharing"] = (options.allowReSharing ? 1 : 0) as CKRecordValue
        share["generation"] = (recipe.provenance?.generation ?? 0) as CKRecordValue

        // 7. Save share AND root record together to CloudKit
        // CloudKit REQUIRES both to be saved in the same operation
        let savedShare = try await saveShare(share, withRootRecord: rootRecord)

        print("✅ Share created successfully: \(savedShare.url?.absoluteString ?? "no URL")")

        // 8. Update recipe provenance
        updateProvenanceForSharing(recipe: recipe, share: savedShare)

        // 9. Track analytics
        trackShareCreated(recipe: recipe, options: options)

        return savedShare
    }

    /// Generate a shareable URL from a CKShare
    /// - Parameter share: The CKShare to generate URL for
    /// - Returns: Shareable URL
    func generateShareURL(from share: CKShare) -> URL? {
        return share.url
    }

    /// Generate a short link for easier sharing
    /// - Parameter share: The CKShare
    /// - Returns: Shortened URL (e.g., heirloom.app/r/abc123)
    func generateShortLink(from share: CKShare) async throws -> URL {
        guard let longURL = share.url else {
            throw ShareError.noShareURL
        }

        // TODO: Implement short link generation via Cloud Function
        // For now, return the long URL
        return longURL
    }

    // MARK: - Share Management

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
        let recordID = CKRecord.ID(recordName: shareID)
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
    private func ensureCloudKitRecord(
        for recipe: Recipe,
        context: ModelContext
    ) async throws -> CKRecord.ID? {
        // Check if recipe already has CloudKit metadata
        if let existingRecordID = recipe.provenance?.cloudKitRecordID {
            return CKRecord.ID(recordName: existingRecordID)
        }

        // Create new CloudKit record for recipe
        let recordID = CKRecord.ID(recordName: "recipe-\(recipe.id.uuidString)")
        let record = CKRecord(recordType: "Recipe", recordID: recordID)

        // Populate record with recipe data
        record["title"] = recipe.title as CKRecordValue
        record["instructions"] = (recipe.instructions.joined(separator: "\n")) as CKRecordValue
        record["servings"] = recipe.servings as? CKRecordValue
        record["prepTime"] = recipe.prepTime as? CKRecordValue
        record["cookTime"] = recipe.cookTime as? CKRecordValue
        record["sourceURL"] = recipe.sourceURL as? CKRecordValue

        // Save to CloudKit
        let database = container.privateCloudDatabase
        let savedRecord = try await database.save(record)

        // Update recipe with CloudKit ID
        recipe.provenance?.cloudKitRecordID = savedRecord.recordID.recordName
        recipe.provenance?.lastSyncedAt = Date()

        try context.save()

        return savedRecord.recordID
    }

    /// Fetch a CloudKit record by ID
    private func fetchRecord(_ recordID: CKRecord.ID) async throws -> CKRecord {
        let database = container.privateCloudDatabase
        return try await database.record(for: recordID)
    }

    /// Save a share AND its root record together to CloudKit
    /// CloudKit requires the share and root record to be saved in the same operation
    private func saveShare(_ share: CKShare, withRootRecord rootRecord: CKRecord? = nil) async throws -> CKShare {
        let database = container.privateCloudDatabase
        
        // If we have a root record, save both together (required for new shares)
        if let rootRecord = rootRecord {
            return try await withCheckedThrowingContinuation { continuation in
                let operation = CKModifyRecordsOperation(
                    recordsToSave: [rootRecord, share],
                    recordIDsToDelete: nil
                )
                
                operation.savePolicy = .changedKeys
                operation.perRecordSaveBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        print("✅ Saved record: \(recordID.recordName) (\(type(of: record)))")
                    case .failure(let error):
                        print("❌ Failed to save record \(recordID.recordName): \(error.localizedDescription)")
                    }
                }
                
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume(returning: share)
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

    /// Update recipe provenance after sharing
    private func updateProvenanceForSharing(recipe: Recipe, share: CKShare) {
        guard var provenance = recipe.provenance else { return }

        // Increment share count
        provenance.cachedMetrics.totalShares += 1
        provenance.cachedMetrics.lastUpdated = Date()

        // Update CloudKit metadata
        provenance.cloudKitRecordID = share.recordID.recordName
        provenance.lastSyncedAt = Date()

        recipe.provenance = provenance
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
        
        // 2. Ensure recipe has CloudKit record
        guard let recordID = try await ensureCloudKitRecord(for: recipe, context: context) else {
            throw ShareError.noRecordID
        }
        
        // 3. Fetch the record and create share
        let record = try await fetchRecord(recordID)
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
            provenance.cloudKitRecordID = share.recordID.recordName
            provenance.lastSyncedAt = Date()
            recipe.provenance = provenance
        }
        
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
