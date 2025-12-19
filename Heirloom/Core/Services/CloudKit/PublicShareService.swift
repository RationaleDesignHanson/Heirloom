//
//  PublicShareService.swift
//  Heirloom
//
//  Handles recipe sharing via CloudKit public database.
//  This approach is independent from SwiftData's private database sync,
//  allowing reliable sharing between different iCloud users.
//

import Foundation
import CloudKit
import SwiftData
import UIKit

/// Service for sharing recipes via CloudKit public database
/// Creates immutable share records that can be imported by recipients
@MainActor
final class PublicShareService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PublicShareService()
    
    // MARK: - Published State
    
    @Published var isSharing = false
    @Published var isFetching = false
    @Published var lastError: Error?
    
    // MARK: - Constants
    
    private let container = CKContainer(identifier: "iCloud.com.matthanson.heirloom")
    private let recordType = "ShareableRecipe"
    
    // URL scheme for share links
    // In production, this would be a universal link domain
    private let shareURLScheme = "heirloom"
    private let shareURLHost = "share"
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Share Recipe
    
    /// Share a recipe to the public database and get a shareable URL
    /// - Parameters:
    ///   - recipe: The recipe to share
    ///   - options: Sharing options (message, expiration, etc.)
    /// - Returns: URL that can be shared with others
    func shareRecipe(_ recipe: Recipe, options: ShareOptions) async throws -> URL {
        print("📤 Starting public share for: \(recipe.title)")
        
        isSharing = true
        lastError = nil
        
        defer { isSharing = false }
        
        // 1. Create unique share ID
        let shareID = UUID().uuidString
        
        // 2. Generate share URL (do this first so we always have a URL)
        let shareURL = generateShareURL(shareID: shareID)
        print("🔗 Generated share URL: \(shareURL.absoluteString)")
        
        do {
            // 3. Check iCloud account status
            let status = try await container.accountStatus()
            print("☁️ iCloud account status: \(status.rawValue)")
            
            guard status == .available else {
                print("⚠️ iCloud not available, returning local URL only")
                // Still return URL - it just won't work until CloudKit is available
                throw ShareError.saveFailed(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "iCloud account not available. Please sign into iCloud in Settings."]))
            }
            
            // 4. Serialize recipe to CKRecord
            let record = try await serializeRecipe(recipe, shareID: shareID, options: options)
            print("📝 Serialized recipe to CKRecord")
            
            // 5. Save to public database
            let savedRecord = try await saveToPublicDatabase(record)
            print("✅ Saved to public database: \(savedRecord.recordID.recordName)")
            
            // 6. Track analytics
            AnalyticsService.shared.track(event: .recipeShared, properties: [
                "method": "public_database",
                "share_id": shareID,
                "has_message": options.personalMessage != nil,
                "generation": recipe.generationCount
            ])
            
            // 7. Log to CloudKit monitor
            CloudKitMonitoringService.shared.logSyncEvent(
                type: .share,
                details: "Shared '\(recipe.title)' to public database",
                success: true
            )
            
            return shareURL
            
        } catch {
            lastError = error
            print("❌ Share failed: \(error.localizedDescription)")
            CloudKitMonitoringService.shared.logError(
                operation: "Share Recipe",
                error: error,
                details: "Failed to share '\(recipe.title)'"
            )
            throw error
        }
    }
    
    /// Share a recipe for "pass down" with generational tracking
    /// - Parameters:
    ///   - recipe: The recipe to pass down
    ///   - recipientName: Name of the recipient (for provenance)
    ///   - message: Personal message
    /// - Returns: URL that can be shared
    func passDownRecipe(_ recipe: Recipe, to recipientName: String, message: String?) async throws -> URL {
        print("🎁 Starting pass down for: \(recipe.title) to \(recipientName)")
        
        var options = ShareOptions.default
        options.personalMessage = message
        options.sharerName = await fetchCurrentUserName()
        
        // Pass down specific: include all personalization
        options.includeCardBack = true
        options.includeStickers = true
        options.includeNotes = true
        
        return try await shareRecipe(recipe, options: options)
    }
    
    // MARK: - Fetch Shared Recipe
    
    /// Fetch a shared recipe from public database
    /// - Parameter shareID: The share ID from the URL
    /// - Returns: SharedRecipeData ready for import
    func fetchSharedRecipe(shareID: String) async throws -> SharedRecipeData {
        print("📥 Fetching shared recipe: \(shareID)")
        print("📥 Looking for record ID: share-\(shareID)")
        print("📥 Using container: \(container.containerIdentifier ?? "default")")
        
        // Log account status to verify we're connected
        do {
            let status = try await container.accountStatus()
            print("📥 Account status for fetch: \(status.rawValue) (1=available)")
        } catch {
            print("📥 Could not check account status: \(error)")
        }
        
        isFetching = true
        lastError = nil
        
        defer { isFetching = false }
        
        do {
            let publicDB = container.publicCloudDatabase
            
            // Query for the record
            let recordID = CKRecord.ID(recordName: "share-\(shareID)")
            print("📥 Querying public database...")
            let record = try await publicDB.record(for: recordID)
            
            // Check expiration
            if let expiresAt = record["expiresAt"] as? Date, expiresAt < Date() {
                throw ShareError.expired
            }
            
            // Deserialize to SharedRecipeData
            let sharedData = try deserializeRecord(record)
            
            print("✅ Fetched shared recipe: \(sharedData.title)")
            return sharedData
            
        } catch let error as CKError where error.code == .unknownItem {
            print("❌ Record not found in CloudKit (unknownItem)")
            lastError = ShareError.notFound
            throw ShareError.notFound
        } catch let error as CKError {
            print("❌ CloudKit fetch error: \(error.code.rawValue) - \(error.localizedDescription)")
            lastError = error
            throw error
        } catch {
            print("❌ Fetch error: \(error.localizedDescription)")
            lastError = error
            throw error
        }
    }
    
    /// Preview a shared recipe without importing
    /// - Parameter url: The share URL
    /// - Returns: SharedRecipeData for preview
    func previewShare(from url: URL) async throws -> SharedRecipeData {
        guard let shareID = extractShareID(from: url) else {
            throw ShareError.invalidURL
        }
        
        return try await fetchSharedRecipe(shareID: shareID)
    }
    
    // MARK: - Import Shared Recipe
    
    /// Import a shared recipe into the user's collection
    /// - Parameters:
    ///   - sharedData: The fetched shared recipe data
    ///   - context: SwiftData model context
    ///   - saveAs: The source type to categorize the recipe as (default: .family)
    /// - Returns: The imported Recipe
    func importSharedRecipe(_ sharedData: SharedRecipeData, into context: ModelContext, saveAs sourceType: RecipeSourceType = .family) throws -> Recipe {
        print("📥 Importing shared recipe: \(sharedData.title) as \(sourceType.displayName)")
        
        // Create new recipe from shared data
        let recipe = Recipe(
            title: sharedData.title,
            sourceType: sourceType,
            sourceURL: sharedData.sourceURL,
            instructions: sharedData.instructions,
            servings: sharedData.servings,
            prepTime: sharedData.prepTime,
            cookTime: sharedData.cookTime
        )
        
        // Set metadata
        recipe.notes = sharedData.notes
        
        // Set source person to sharer's name so it displays properly
        // For family recipes: "From [sharer's name]"
        // For other types: still tracks who shared it
        recipe.sourcePerson = sharedData.sharerName
        recipe.sourceDate = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
        
        // Create ingredients
        var ingredients: [Ingredient] = []
        for (index, ingredientText) in sharedData.ingredients.enumerated() {
            let ingredient = Ingredient(
                originalText: ingredientText,
                name: ingredientText,
                orderIndex: index
            )
            ingredients.append(ingredient)
        }
        recipe.ingredients = ingredients
        
        // Set provenance for received share
        let newGeneration = sharedData.generation + 1
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceURL: sharedData.sourceURL,
            sourceAttribution: sharedData.originalAttribution,
            rootProvenanceHash: sharedData.rootProvenanceHash,
            generation: newGeneration,
            parentShareID: sharedData.shareID,
            sharedByName: sharedData.sharerName,
            createdAt: Date()
        )
        
        // Legacy fields for backward compatibility
        recipe.sharedBy = sharedData.sharerName
        recipe.sharedDate = Date()
        recipe.passedDownMessage = sharedData.personalMessage
        recipe.generationCount = newGeneration + 1 // Legacy uses 1-based
        
        // Insert into context
        context.insert(recipe)
        
        // Track analytics
        AnalyticsService.shared.track(event: .recipeShared, properties: [
            "method": "import_from_share",
            "share_id": sharedData.shareID,
            "generation": newGeneration
        ])
        
        print("✅ Imported recipe: \(recipe.title) (Generation \(newGeneration))")
        return recipe
    }
    
    // MARK: - Private: Serialization
    
    /// Serialize a Recipe to CKRecord for public database
    private func serializeRecipe(_ recipe: Recipe, shareID: String, options: ShareOptions) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: "share-\(shareID)")
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        // Core identifiers
        record["shareID"] = shareID as CKRecordValue
        record["recipeID"] = recipe.id.uuidString as CKRecordValue
        
        // Recipe content
        record["title"] = recipe.title as CKRecordValue
        record["instructions"] = recipe.instructions as CKRecordValue
        record["servings"] = recipe.servings as CKRecordValue?
        record["prepTime"] = recipe.prepTime as CKRecordValue?
        record["cookTime"] = recipe.cookTime as CKRecordValue?
        record["sourceURL"] = recipe.sourceURL as CKRecordValue?
        
        // Include notes if option is set
        if options.includeNotes {
            record["notes"] = recipe.notes as CKRecordValue?
        }
        
        // Ingredients as JSON array
        if let ingredients = recipe.ingredients {
            let ingredientTexts = ingredients
                .sorted { $0.orderIndex < $1.orderIndex }
                .map { $0.originalText }
            
            if let data = try? JSONEncoder().encode(ingredientTexts),
               let jsonString = String(data: data, encoding: .utf8) {
                record["ingredientsJSON"] = jsonString as CKRecordValue
            }
        }
        
        // Provenance / Lineage
        record["generation"] = recipe.generationCount as CKRecordValue
        record["rootProvenanceHash"] = (recipe.provenance?.rootProvenanceHash ?? shareID) as CKRecordValue
        record["originalAttribution"] = recipe.sourceAttribution as CKRecordValue?

        // Sharer info
        var sharerName = options.sharerName
        if sharerName == nil {
            sharerName = await fetchCurrentUserName()
        }
        record["sharerName"] = (sharerName ?? "A Family Member") as CKRecordValue
        record["personalMessage"] = options.personalMessage as CKRecordValue?
        
        // Timestamps
        record["createdAt"] = Date() as CKRecordValue
        
        // Expiration
        if let duration = options.expirationDuration, duration != .never {
            record["expiresAt"] = duration.expirationDate as CKRecordValue?
        }
        
        // Include image if available
        if let imageFileName = recipe.imageFileName {
            // Load and attach image as CKAsset
            if let image = await ImageStorageService.shared.loadImage(fileName: imageFileName),
               let assetURL = saveImageToTempFile(image) {
                record["imageAsset"] = CKAsset(fileURL: assetURL)
            }
        }
        
        return record
    }
    
    /// Deserialize CKRecord to SharedRecipeData
    private func deserializeRecord(_ record: CKRecord) throws -> SharedRecipeData {
        guard let shareID = record["shareID"] as? String,
              let title = record["title"] as? String else {
            throw ShareError.invalidData
        }
        
        // Parse ingredients from JSON
        var ingredients: [String] = []
        if let jsonString = record["ingredientsJSON"] as? String,
           let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            ingredients = decoded
        }
        
        // Parse instructions
        let instructions = (record["instructions"] as? [String]) ?? []
        
        return SharedRecipeData(
            shareID: shareID,
            recipeID: record["recipeID"] as? String,
            title: title,
            instructions: instructions,
            ingredients: ingredients,
            servings: record["servings"] as? String,
            prepTime: record["prepTime"] as? String,
            cookTime: record["cookTime"] as? String,
            sourceURL: record["sourceURL"] as? String,
            notes: record["notes"] as? String,
            generation: record["generation"] as? Int ?? 0,
            rootProvenanceHash: record["rootProvenanceHash"] as? String ?? shareID,
            originalAttribution: record["originalAttribution"] as? String,
            sharerName: record["sharerName"] as? String ?? "Someone",
            personalMessage: record["personalMessage"] as? String,
            createdAt: record["createdAt"] as? Date ?? Date(),
            expiresAt: record["expiresAt"] as? Date,
            imageAsset: record["imageAsset"] as? CKAsset
        )
    }
    
    // MARK: - Private: CloudKit Operations
    
    /// Save record to public database
    private func saveToPublicDatabase(_ record: CKRecord) async throws -> CKRecord {
        let publicDB = container.publicCloudDatabase
        
        do {
            let saved = try await publicDB.save(record)
            print("✅ CloudKit save SUCCESS: \(saved.recordID.recordName)")
            return saved
        } catch let error as CKError {
            print("❌ CloudKit save FAILED: code=\(error.code.rawValue) - \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ CloudKit save FAILED: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private: URL Generation
    
    /// Generate share URL from share ID
    private func generateShareURL(shareID: String) -> URL {
        // Using custom URL scheme: heirloom://share/{shareID}
        var components = URLComponents()
        components.scheme = shareURLScheme
        components.host = shareURLHost
        components.path = "/\(shareID)"
        
        return components.url!
    }
    
    /// Extract share ID from URL
    func extractShareID(from url: URL) -> String? {
        // heirloom://share/{shareID}
        if url.scheme == shareURLScheme && url.host() == shareURLHost {
            let path = url.path
            return path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        
        // https://heirloom.app/share/{shareID}
        if url.host() == "heirloom.app" && url.pathComponents.contains("share") {
            return url.pathComponents.last
        }
        
        return nil
    }
    
    // MARK: - Private: Helpers
    
    /// Fetch current user's display name
    private func fetchCurrentUserName() async -> String {
        do {
            // Verify user is signed in by fetching record ID
            _ = try await container.userRecordID()
            // For privacy reasons, we can't easily get the user's name
            // Use a generic fallback
            return "A Family Member"
        } catch {
            return "A Family Member"
        }
    }
    
    /// Save image to temp file for CKAsset
    private func saveImageToTempFile(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("⚠️ Failed to save temp image: \(error)")
            return nil
        }
    }
}

// MARK: - Supporting Types

/// Data transfer object for shared recipe
struct SharedRecipeData {
    let shareID: String
    let recipeID: String?
    let title: String
    let instructions: [String]
    let ingredients: [String]
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let sourceURL: String?
    let notes: String?
    let generation: Int
    let rootProvenanceHash: String
    let originalAttribution: String?
    let sharerName: String
    let personalMessage: String?
    let createdAt: Date
    let expiresAt: Date?
    let imageAsset: CKAsset?
    
    /// Whether the share has expired
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt < Date()
    }
    
    /// Display string for generation
    var generationDisplay: String {
        if generation == 0 {
            return "Original Recipe"
        } else if generation == 1 {
            return "1st Generation"
        } else if generation == 2 {
            return "2nd Generation"
        } else if generation == 3 {
            return "3rd Generation"
        } else {
            return "\(generation)th Generation"
        }
    }
    
    /// Display string for who shared
    var sharedByDisplay: String {
        "Shared by \(sharerName)"
    }
}

/// Errors specific to sharing
enum ShareError: LocalizedError {
    case invalidURL
    case invalidData
    case notFound
    case expired
    case saveFailed(Error)
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The share link is not valid"
        case .invalidData:
            return "The shared recipe data is corrupted"
        case .notFound:
            return "This shared recipe no longer exists"
        case .expired:
            return "This share link has expired"
        case .saveFailed(let error):
            return "Failed to save share: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch share: \(error.localizedDescription)"
        }
    }
}
