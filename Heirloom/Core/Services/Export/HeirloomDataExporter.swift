//
//  HeirloomDataExporter.swift
//  Heirloom
//
//  Social Layer Phase 3: Data Export/Import Service
//  Extends RecipeExporter to support v2 exports with social data
//

import Foundation
import SwiftData

// MARK: - Export Options

struct HeirloomExportOptions {
    var includeProfiles: Bool = true
    var includeConnections: Bool = true
    var includeKitchenTables: Bool = true
    var includePrivacySettings: Bool = true
    var includeRecipeImages: Bool = false // Not yet supported

    static var fullExport: HeirloomExportOptions {
        return HeirloomExportOptions()
    }

    static var recipesOnly: HeirloomExportOptions {
        return HeirloomExportOptions(
            includeProfiles: false,
            includeConnections: false,
            includeKitchenTables: false,
            includePrivacySettings: false
        )
    }
}

// MARK: - Import Options

struct HeirloomImportOptions {
    var mergeRecipes: Bool = true // If false, replace all recipes
    var restoreConnections: Bool = true
    var restoreKitchenTables: Bool = true
    var restorePrivacySettings: Bool = true

    static var mergeAll: HeirloomImportOptions {
        return HeirloomImportOptions()
    }

    static var recipesOnly: HeirloomImportOptions {
        return HeirloomImportOptions(
            restoreConnections: false,
            restoreKitchenTables: false,
            restorePrivacySettings: false
        )
    }
}

// MARK: - Data Exporter

/// Service for exporting and importing Heirloom data with social features
@MainActor
final class HeirloomDataExporter {

    // MARK: - Dependencies

    private let profileService: ProfileServiceProtocol
    private let connectionService: ConnectionServiceProtocol
    private let recipeExporter: RecipeExporter

    // MARK: - Initialization

    init(
        profileService: ProfileServiceProtocol,
        connectionService: ConnectionServiceProtocol,
        recipeExporter: RecipeExporter = RecipeExporter()
    ) {
        self.profileService = profileService
        self.connectionService = connectionService
        self.recipeExporter = recipeExporter
    }

    // MARK: - Export

    /// Export all Heirloom data to v2 format with social data
    /// - Parameters:
    ///   - context: SwiftData model context
    ///   - options: Export options
    /// - Returns: URL to the temporary JSON file
    func exportAllData(
        context: ModelContext,
        options: HeirloomExportOptions = .fullExport
    ) async throws -> URL {
        Log.info("Starting Heirloom v2 export", category: .storage, metadata: [
            "includeProfiles": options.includeProfiles,
            "includeConnections": options.includeConnections
        ])

        // Fetch all recipes
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        let recipes = try context.fetch(descriptor)

        guard !recipes.isEmpty else {
            throw RecipeExportError.noRecipesToExport
        }

        // Convert recipes to v2 format
        let recipeData = recipes.map { convertToRecipeExportDataV2($0) }

        // Fetch user profile (if enabled)
        var userProfileData: UserProfileExportData?
        if options.includeProfiles {
            if let profile = try? await profileService.fetchCurrentUserProfile() {
                userProfileData = convertToUserProfileExportData(profile)
            }
        }

        // Fetch connections (if enabled)
        var connectionsData: [ConnectionExportData]?
        if options.includeConnections {
            if let connections = try? await connectionService.fetchConnections(status: .connected) {
                connectionsData = connections.map { convertToConnectionExportData($0) }
            }
        }

        // Kitchen Tables (placeholder - to be implemented in Phase 4)
        var kitchenTablesData: [KitchenTableExportData]?
        if options.includeKitchenTables {
            // TODO: Fetch from KitchenTableService when available
            kitchenTablesData = []
        }

        // Privacy settings (if enabled)
        var privacySettingsData: PrivacySettingsExportData?
        if options.includePrivacySettings, let profile = userProfileData {
            privacySettingsData = convertToPrivacySettingsExportData(
                try await profileService.fetchCurrentUserProfile()
            )
        }

        // Get current user ID
        let userId = try? await profileService.fetchCurrentUserProfile().userId

        // Create v2 export wrapper
        let exportWrapper = HeirloomExportV2(
            version: 2,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            userId: userId,
            recipes: recipeData,
            userProfile: userProfileData,
            connections: connectionsData,
            kitchenTables: kitchenTablesData,
            privacySettings: privacySettingsData
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(exportWrapper)

        // Save to temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "heirloom-export-v2-\(Date().iso8601FilenameSafe).json"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try jsonData.write(to: fileURL)

        Log.info("Heirloom v2 export completed", category: .storage, metadata: [
            "fileName": fileName,
            "recipeCount": recipes.count,
            "connectionCount": connectionsData?.count ?? 0,
            "fileSize": jsonData.count
        ])

        return fileURL
    }

    // MARK: - Import

    /// Import Heirloom data from v1 or v2 export file
    /// - Parameters:
    ///   - url: URL to the JSON export file
    ///   - context: SwiftData model context
    ///   - options: Import options
    /// - Returns: Import result with statistics and errors
    func importData(
        from url: URL,
        context: ModelContext,
        options: HeirloomImportOptions = .mergeAll
    ) async throws -> HeirloomImportResult {
        Log.info("Starting Heirloom import", category: .storage, metadata: [
            "fileName": url.lastPathComponent
        ])

        // Read JSON file
        let jsonData = try Data(contentsOf: url)

        // Decode as v2 format (backward compatible with v1)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportWrapper: HeirloomExportV2
        do {
            exportWrapper = try decoder.decode(HeirloomExportV2.self, from: jsonData)
        } catch {
            // Try decoding as v1 format (RecipeExportWrapper)
            Log.info("Attempting v1 import fallback", category: .storage)
            return try await importV1Format(from: url, context: context)
        }

        Log.info("Detected export version", category: .storage, metadata: [
            "version": exportWrapper.version,
            "recipeCount": exportWrapper.recipeCount,
            "hasSocialData": exportWrapper.hasSocialData
        ])

        var errors: [HeirloomImportError] = []
        var recipesImported = 0
        var connectionsImported = 0
        var kitchenTablesImported = 0

        // Import recipes
        for recipeData in exportWrapper.recipes {
            do {
                try importRecipe(recipeData, context: context, mergeMode: options.mergeRecipes)
                recipesImported += 1
            } catch {
                errors.append(HeirloomImportError(
                    type: .parseError,
                    itemId: recipeData.id,
                    message: "Failed to import recipe: \(error.localizedDescription)"
                ))
            }
        }

        // Import user profile (if present and enabled)
        if options.restorePrivacySettings,
           let privacyData = exportWrapper.privacySettings {
            do {
                try await importPrivacySettings(privacyData)
                Log.info("Imported privacy settings", category: .storage)
            } catch {
                errors.append(HeirloomImportError(
                    type: .parseError,
                    itemId: nil,
                    message: "Failed to import privacy settings: \(error.localizedDescription)"
                ))
            }
        }

        // Import connections (if present and enabled)
        if options.restoreConnections,
           let connectionsData = exportWrapper.connections {
            for connectionData in connectionsData {
                do {
                    // Check if user still exists (basic validation)
                    // Full reconnection logic would require user search/matching
                    try await importConnection(connectionData)
                    connectionsImported += 1
                } catch {
                    errors.append(HeirloomImportError(
                        type: .connectionNotFound,
                        itemId: connectionData.connectedUserId,
                        message: "Could not restore connection: \(connectionData.connectedUserDisplayName)"
                    ))
                }
            }
        }

        // Save context
        try context.save()

        let result = HeirloomImportResult(
            version: exportWrapper.version,
            recipesImported: recipesImported,
            connectionsImported: connectionsImported > 0 ? connectionsImported : nil,
            kitchenTablesImported: kitchenTablesImported > 0 ? kitchenTablesImported : nil,
            errors: errors
        )

        Log.info("Heirloom import completed", category: .storage, metadata: [
            "version": exportWrapper.version,
            "recipesImported": recipesImported,
            "connectionsImported": connectionsImported,
            "errorCount": errors.count
        ])

        return result
    }

    // MARK: - Private Import Helpers

    private func importRecipe(
        _ data: RecipeExportDataV2,
        context: ModelContext,
        mergeMode: Bool
    ) throws {
        // Check if recipe already exists
        if mergeMode {
            let descriptor = FetchDescriptor<Recipe>(
                predicate: #Predicate { $0.id.uuidString == data.id }
            )
            let existing = try context.fetch(descriptor)
            if !existing.isEmpty {
                Log.debug("Skipping duplicate recipe", category: .storage, metadata: ["id": data.id])
                return
            }
        }

        // Create new recipe from export data
        let recipe = Recipe(
            title: data.title,
            ingredientsText: data.ingredients.joined(separator: "\n"),
            instructions: data.instructions,
            sourceType: data.sourceType != nil ? SourceType(rawValue: data.sourceType!) : nil
        )

        recipe.servings = data.servings
        recipe.prepTime = data.prepTime
        recipe.cookTime = data.cookTime
        recipe.notes = data.notes
        recipe.sourceURL = data.sourceURL
        recipe.sourcePerson = data.sourcePerson
        recipe.sourceBookTitle = data.sourceBookTitle
        recipe.sourceDate = data.sourceDate
        recipe.isFavorite = data.isFavorite
        recipe.timesCooked = data.timesCooked
        recipe.isThemeRecipe = data.isThemeRecipe
        recipe.sourceThemeId = data.sourceThemeId
        recipe.historicalText = data.historicalText
        recipe.historicalContext = data.historicalContext

        // V2 social fields
        recipe.sharedBy = data.sharedBy
        recipe.generation = data.generation ?? 0
        recipe.rootRecipeId = data.rootRecipeId

        context.insert(recipe)
    }

    private func importPrivacySettings(_ data: PrivacySettingsExportData) async throws {
        let currentProfile = try await profileService.fetchCurrentUserProfile()

        var updatedProfile = currentProfile
        updatedProfile.privacySettings = PrivacySettings(
            profileVisibility: ProfileVisibility(rawValue: data.profileVisibility) ?? .connections,
            recipeVisibility: RecipeVisibility(rawValue: data.recipeVisibility) ?? .connections,
            kitchenTableVisibility: KitchenTableVisibility(rawValue: data.kitchenTableVisibility) ?? .members,
            whoCanConnect: WhoCanConnect(rawValue: data.whoCanConnect) ?? .anyone,
            allowRecipeResharing: data.allowRecipeResharing,
            allowMentions: data.allowMentions,
            notifyConnectionRequests: true,
            notifyRecipeShares: true,
            allowSearchIndexing: data.hasPublicProfile
        )

        try await profileService.updateProfile(updatedProfile)
    }

    private func importConnection(_ data: ConnectionExportData) async throws {
        // This is a placeholder - full implementation would require:
        // 1. Search for user by handle or email
        // 2. Verify user still exists
        // 3. Send connection request if user found
        // 4. Create "reconnection list" for manual review if user not found

        Log.warning("Connection import not yet fully implemented", category: .storage, metadata: [
            "connectedUserDisplayName": data.connectedUserDisplayName
        ])

        throw HeirloomImportError(
            type: .connectionNotFound,
            itemId: data.connectedUserId,
            message: "Connection restoration requires manual review"
        )
    }

    // MARK: - V1 Import Fallback

    private func importV1Format(
        from url: URL,
        context: ModelContext
    ) async throws -> HeirloomImportResult {
        Log.info("Importing v1 format", category: .storage)

        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        let wrapper = try decoder.decode(RecipeExportWrapper.self, from: jsonData)

        var errors: [HeirloomImportError] = []
        var recipesImported = 0

        for recipeData in wrapper.recipes {
            do {
                // Convert v1 to v2 format
                let v2Data = RecipeExportDataV2(
                    id: recipeData.id,
                    title: recipeData.title,
                    ingredients: recipeData.ingredients,
                    instructions: recipeData.instructions,
                    servings: recipeData.servings,
                    prepTime: recipeData.prepTime,
                    cookTime: recipeData.cookTime,
                    notes: recipeData.notes,
                    sourceType: recipeData.sourceType,
                    sourceURL: recipeData.sourceURL,
                    sourcePerson: recipeData.sourcePerson,
                    sourceBookTitle: recipeData.sourceBookTitle,
                    sourceDate: recipeData.sourceDate,
                    dateAdded: recipeData.dateAdded,
                    lastModified: recipeData.lastModified,
                    isFavorite: recipeData.isFavorite,
                    timesCooked: recipeData.timesCooked,
                    lastCooked: recipeData.lastCooked,
                    isThemeRecipe: recipeData.isThemeRecipe,
                    sourceThemeId: recipeData.sourceThemeId,
                    historicalText: recipeData.historicalText,
                    historicalContext: recipeData.historicalContext,
                    // V2 fields (not present in v1)
                    sharedBy: nil,
                    sharedDate: nil,
                    generation: nil,
                    rootRecipeId: nil,
                    heritageChain: nil,
                    tags: nil,
                    collections: nil,
                    cardBackText: nil,
                    comments: nil,
                    annotations: nil
                )

                try importRecipe(v2Data, context: context, mergeMode: true)
                recipesImported += 1
            } catch {
                errors.append(HeirloomImportError(
                    type: .parseError,
                    itemId: recipeData.id,
                    message: "Failed to import v1 recipe: \(error.localizedDescription)"
                ))
            }
        }

        try context.save()

        return HeirloomImportResult(
            version: 1,
            recipesImported: recipesImported,
            connectionsImported: nil,
            kitchenTablesImported: nil,
            errors: errors
        )
    }

    // MARK: - Conversion Helpers

    private func convertToRecipeExportDataV2(_ recipe: Recipe) -> RecipeExportDataV2 {
        return RecipeExportDataV2(
            id: recipe.id.uuidString,
            title: recipe.title,
            ingredients: recipe.ingredients?.map { $0.originalText } ?? [],
            instructions: recipe.instructions,
            servings: recipe.servings,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            notes: recipe.notes,
            sourceType: recipe.sourceType?.rawValue,
            sourceURL: recipe.sourceURL,
            sourcePerson: recipe.sourcePerson,
            sourceBookTitle: recipe.sourceBookTitle,
            sourceDate: recipe.sourceDate,
            dateAdded: recipe.dateAdded.iso8601,
            lastModified: recipe.lastModified.iso8601,
            isFavorite: recipe.isFavorite,
            timesCooked: recipe.timesCooked,
            lastCooked: recipe.lastCooked?.iso8601,
            isThemeRecipe: recipe.isThemeRecipe,
            sourceThemeId: recipe.sourceThemeId,
            historicalText: recipe.historicalText,
            historicalContext: recipe.historicalContext,
            // V2 additions
            sharedBy: recipe.sharedBy,
            sharedDate: recipe.sharedDate?.iso8601,
            generation: recipe.generation > 0 ? recipe.generation : nil,
            rootRecipeId: recipe.rootRecipeId,
            heritageChain: nil, // Not yet tracked
            tags: nil, // Not yet implemented
            collections: recipe.collections?.map { $0.name },
            cardBackText: recipe.cardBackText,
            comments: nil, // Not yet implemented
            annotations: nil // Not yet implemented
        )
    }

    private func convertToUserProfileExportData(_ profile: UserProfile) -> UserProfileExportData {
        return UserProfileExportData(
            userId: profile.userId,
            displayName: profile.displayName,
            handle: profile.handle,
            bio: profile.bio,
            location: profile.location,
            specialties: profile.specialties,
            websiteURL: profile.websiteURL,
            joinedAt: profile.joinedAt.iso8601,
            connectionCount: profile.connectionCount,
            sharedRecipeCount: profile.sharedRecipeCount,
            heritageGenerationCount: profile.heritageGenerationCount
        )
    }

    private func convertToConnectionExportData(_ connection: Connection) -> ConnectionExportData {
        return ConnectionExportData(
            connectedUserId: connection.connectedUserId,
            connectedUserDisplayName: connection.connectedUserDisplayName,
            connectedUserHandle: nil, // Would need to fetch from profile
            status: connection.status.rawValue,
            acceptedAt: connection.acceptedAt?.iso8601,
            recipesSharedCount: connection.recipesSharedCount,
            recipesReceivedCount: connection.recipesReceivedCount,
            isFavorite: connection.isFavorite,
            sourceKitchenTableId: connection.sourceKitchenTableId
        )
    }

    private func convertToPrivacySettingsExportData(_ profile: UserProfile) -> PrivacySettingsExportData {
        let settings = profile.privacySettings
        return PrivacySettingsExportData(
            profileVisibility: settings.profileVisibility.rawValue,
            recipeVisibility: settings.recipeVisibility.rawValue,
            kitchenTableVisibility: settings.kitchenTableVisibility.rawValue,
            whoCanConnect: settings.whoCanConnect.rawValue,
            allowRecipeResharing: settings.allowRecipeResharing,
            allowMentions: settings.allowMentions,
            hasPublicProfile: profile.hasPublicProfile
        )
    }
}
