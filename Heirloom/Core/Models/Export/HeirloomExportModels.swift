//
//  HeirloomExportModels.swift
//  Heirloom
//
//  Social Layer Phase 2: Export Data Models with Social Data
//  Backward compatible with v1 exports, adds social data in v2
//
//  Note: RecipeExportData, RecipeExportWrapper, Date extensions, and ImportError
//  already exist in RecipeExporter.swift. This file adds v2 extensions and social models.
//

import Foundation
import SwiftData

// MARK: - Export Wrapper (v2)

/// Top-level wrapper for Heirloom data exports
/// Version 2 adds social data while maintaining backward compatibility
struct HeirloomExportV2: Codable {
    /// Export format version
    /// - v1: Recipes only (backward compatible)
    /// - v2: Recipes + social data
    let version: Int

    /// When this export was created
    let exportDate: String // ISO8601 format

    /// App version that created the export
    let appVersion: String

    /// User ID of the exporter (for re-import attribution)
    let userId: String?

    /// Number of recipes in export
    let recipeCount: Int

    /// Number of connections in export (v2 only)
    let connectionCount: Int?

    /// Number of Kitchen Tables in export (v2 only)
    let kitchenTableCount: Int?

    /// Recipe data (v1 + v2)
    let recipes: [RecipeExportDataV2]

    /// User profile data (v2 only, optional)
    let userProfile: UserProfileExportData?

    /// Connection data (v2 only, optional)
    let connections: [ConnectionExportData]?

    /// Kitchen Table data (v2 only, optional)
    let kitchenTables: [KitchenTableExportData]?

    /// Privacy settings (v2 only, optional)
    let privacySettings: PrivacySettingsExportData?

    /// Theme unlock progress (v2 only, optional)
    let themeProgress: ThemeProgressExportData?

    // MARK: - Initialization

    init(
        version: Int = 2,
        exportDate: Date = Date(),
        appVersion: String,
        userId: String?,
        recipes: [RecipeExportDataV2],
        userProfile: UserProfileExportData? = nil,
        connections: [ConnectionExportData]? = nil,
        kitchenTables: [KitchenTableExportData]? = nil,
        privacySettings: PrivacySettingsExportData? = nil,
        themeProgress: ThemeProgressExportData? = nil
    ) {
        self.version = version
        self.exportDate = ISO8601DateFormatter().string(from: exportDate)
        self.appVersion = appVersion
        self.userId = userId
        self.recipeCount = recipes.count
        self.connectionCount = connections?.count
        self.kitchenTableCount = kitchenTables?.count
        self.recipes = recipes
        self.userProfile = userProfile
        self.connections = connections
        self.kitchenTables = kitchenTables
        self.privacySettings = privacySettings
        self.themeProgress = themeProgress
    }
}

// MARK: - Recipe Export Data (v2 extension)

/// Recipe data for export (v2 with social data)
/// Extends v1 RecipeExportData with social/provenance fields
struct RecipeExportDataV2: Codable {
    // V1 fields (maintained for backward compatibility)
    let id: String
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let notes: String?
    let sourceType: String?
    let sourceURL: String?
    let sourcePerson: String?
    let sourceBookTitle: String?
    let sourceDate: String?
    let dateAdded: String // ISO8601
    let lastModified: String // ISO8601
    let isFavorite: Bool
    let timesCooked: Int
    let lastCooked: String? // ISO8601
    let isThemeRecipe: Bool
    let sourceThemeId: String?
    let historicalText: String?
    let historicalContext: String?

    // V2 additions (social layer)
    let sharedBy: String? // Sharer's display name
    let sharedByUserId: String? // Sharer's Firebase user ID
    let sharedFromRecipeId: String? // UUID of the recipe in sharer's collection (lowercase)
    let sharedDate: String? // ISO8601
    let generation: Int?
    let rootRecipeId: String?
    let rootProvenanceHash: String? // SHA256 hash identifying the lineage root (cryptographic lineage)
    let heritageChain: [String]? // Array of user IDs in lineage
    let heritageChainNames: [String]? // Display names for offline viewing (parallel to heritageChain)
    let isDemoRecipe: Bool? // Whether recipe was received from demo user (cannot be shared)
    let tags: [String]? // Tag names
    let collections: [String]? // Collection names

    // V2 personalization
    let cardBackText: String?
    let comments: [CommentExportData]?
    let annotations: [AnnotationExportData]?

    // V2 image preservation
    let firebaseImageURL: String? // Firebase Storage download URL for image restoration

    // V2.1 bundled images (ZIP export - legacy, kept for backward compatibility)
    let localImagePath: String? // Relative path in ZIP: "images/{uuid}.jpg"

    // V2.2 embedded images (JSON export with base64)
    let imageBase64: String? // Base64-encoded JPEG image data

    enum CodingKeys: String, CodingKey {
        case id, title, ingredients, instructions, servings
        case prepTime, cookTime, notes
        case sourceType, sourceURL, sourcePerson, sourceBookTitle, sourceDate
        case dateAdded, lastModified
        case isFavorite, timesCooked, lastCooked
        case isThemeRecipe, sourceThemeId, historicalText, historicalContext
        // V2 fields
        case sharedBy, sharedByUserId, sharedFromRecipeId, sharedDate, generation, rootRecipeId, rootProvenanceHash, heritageChain, heritageChainNames, isDemoRecipe
        case tags, collections
        case cardBackText, comments, annotations
        case firebaseImageURL
        case localImagePath
        case imageBase64
    }
}

// MARK: - User Profile Export Data (v2)

/// User profile data for export
struct UserProfileExportData: Codable {
    let userId: String
    let displayName: String
    let handle: String?
    let bio: String?
    let location: String?
    let specialties: [String]?
    let websiteURL: String?
    let joinedAt: String // ISO8601
    let connectionCount: Int
    let sharedRecipeCount: Int
    let heritageGenerationCount: Int
}

// MARK: - Connection Export Data (v2)

/// Connection data for export
struct ConnectionExportData: Codable {
    let connectedUserId: String
    let connectedUserDisplayName: String
    let connectedUserHandle: String?
    let status: String // ConnectionStatus.rawValue
    let acceptedAt: String? // ISO8601
    let recipesSharedCount: Int
    let recipesReceivedCount: Int
    let isFavorite: Bool
    let sourceKitchenTableId: String?
}

// MARK: - Kitchen Table Export Data (v2)

/// Kitchen Table data for export
struct KitchenTableExportData: Codable {
    let id: String
    let name: String
    let description: String?
    let createdBy: String
    let createdAt: String // ISO8601
    let memberCount: Int
    let recipeCount: Int
    let isActive: Bool
}

// MARK: - Privacy Settings Export Data (v2)

/// Privacy settings for export/backup
struct PrivacySettingsExportData: Codable {
    let profileVisibility: String
    let recipeVisibility: String
    let kitchenTableVisibility: String
    let whoCanConnect: String
    let allowRecipeResharing: Bool
    let allowMentions: Bool
    let hasPublicProfile: Bool
}

// MARK: - Theme Progress Export Data (v2)

/// Theme unlock progress for export/backup
/// Allows users to resume their theme unlock schedule after restore
struct ThemeProgressExportData: Codable {
    /// IDs of themes the user selected during onboarding
    let selectedThemeIds: [String]

    /// When the trial started (ISO8601) - legacy compatibility
    let trialStartDate: String

    /// The last unlock day that was processed (1-14)
    let lastUnlockDay: Int

    /// Current trial day at time of export (for reference)
    let currentTrialDay: Int

    /// Per-theme added dates (themeId → ISO8601 date string)
    /// Used by Discovery tab for per-theme progress tracking
    let themeAddedDates: [String: String]?
}

// MARK: - Comment Export Data (v2)

/// Recipe comment for export
struct CommentExportData: Codable {
    let id: String
    let text: String
    let authorUserId: String
    let authorDisplayName: String
    let createdAt: String // ISO8601
}

// MARK: - Annotation Export Data (v2)

/// Recipe annotation for export
struct AnnotationExportData: Codable {
    let id: String
    let text: String
    let location: String // JSON encoded location data
    let createdAt: String // ISO8601
}

// MARK: - Import Models

/// Info about an image that needs to be restored
struct ImageRestoreInfo {
    let recipe: Recipe
    let firebaseURL: String
}

/// Result of importing an Heirloom export file
struct HeirloomImportResult {
    let version: Int
    let recipesImported: Int
    let connectionsImported: Int?
    let kitchenTablesImported: Int?
    let errors: [HeirloomImportError]
    /// Images that need restoration (if skipImageRestoration was true)
    var imagesToRestore: [ImageRestoreInfo] = []

    var isSuccessful: Bool {
        return recipesImported > 0 && errors.isEmpty
    }

    var hasWarnings: Bool {
        return !errors.isEmpty
    }
}

/// Import error tracking (v2)
struct HeirloomImportError: Codable, Error {
    let type: HeirloomImportErrorType
    let itemId: String?
    let message: String
    let timestamp: Date

    init(type: HeirloomImportErrorType, itemId: String? = nil, message: String) {
        self.type = type
        self.itemId = itemId
        self.message = message
        self.timestamp = Date()
    }
}

enum HeirloomImportErrorType: String, Codable {
    case invalidFormat          // File format not recognized
    case versionMismatch        // Export version too new for this app
    case missingData            // Required fields missing
    case duplicateId            // Recipe/connection already exists
    case invalidUserId          // User ID doesn't match or is invalid
    case connectionNotFound     // Referenced connection doesn't exist
    case kitchenTableNotFound   // Referenced Kitchen Table doesn't exist
    case imageMissing           // Recipe image file not found
    case parseError             // JSON parsing failed
}

// MARK: - Backward Compatibility

extension HeirloomExportV2 {
    /// Check if this export is compatible with current app version
    func isCompatible(with appVersion: Int) -> Bool {
        return version <= appVersion
    }

    /// Whether this export contains social data
    var hasSocialData: Bool {
        return version >= 2 && (connections != nil || kitchenTables != nil)
    }

    /// Whether this export contains only recipes (v1 style)
    var isRecipeOnlyExport: Bool {
        return version == 1 || (!hasSocialData && userProfile == nil)
    }
}

// Note: RecipeExportWrapper, Date extensions (iso8601, iso8601FilenameSafe)
// already exist in RecipeExporter.swift and are not redeclared here.
