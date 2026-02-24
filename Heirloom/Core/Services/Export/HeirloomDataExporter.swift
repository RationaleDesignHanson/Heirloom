//
//  HeirloomDataExporter.swift
//  Heirloom
//
//  Social Layer Phase 3: Data Export/Import Service
//  Extends RecipeExporter to support v2 exports with social data
//

import Foundation
import SwiftData
import FirebaseFirestore
import UIKit

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
    var generateMissingImages: Bool = false // Generate AI images for recipes without photos
    var skipImageRestoration: Bool = false // If true, returns image info but doesn't restore (caller can do it with progress)

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
        recipeExporter: RecipeExporter
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

        // Fetch user recipes only (exclude theme recipes - they come from JSON files)
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { $0.isThemeRecipe == false },
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        let recipes = try context.fetch(descriptor)

        // Theme recipes aren't user data, so only fail if there are no user recipes
        // and the user has some recipes (all are theme recipes)
        if recipes.isEmpty {
            // Check if there are any recipes at all
            let allDescriptor = FetchDescriptor<Recipe>()
            let allRecipes = try context.fetch(allDescriptor)
            if allRecipes.isEmpty {
                throw RecipeExportError.noRecipesToExport
            }
            // User only has theme recipes - that's OK, we'll export an empty recipe list
            // but still include profile, connections, theme progress, etc.
            Log.info("No user recipes to export (only theme recipes exist)", category: .storage)
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
            if let connections = try? await connectionService.fetchConnections(status: .connected, forceRefresh: false) {
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
        if options.includePrivacySettings, userProfileData != nil {
            privacySettingsData = convertToPrivacySettingsExportData(
                try await profileService.fetchCurrentUserProfile()
            )
        }

        // Theme progress (always include if user has selected themes)
        let themeProgressData = exportThemeProgress()

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
            privacySettings: privacySettingsData,
            themeProgress: themeProgressData
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
        let kitchenTablesImported = 0 // TODO: Implement Kitchen Table import in Phase 4

        // Track imported recipes with image URLs for restoration
        var recipesNeedingImageRestore: [(recipe: Recipe, firebaseURL: String)] = []

        // Import recipes
        for recipeData in exportWrapper.recipes {
            do {
                if let recipe = try importRecipe(recipeData, context: context, mergeMode: options.mergeRecipes) {
                    recipesImported += 1

                    // Track recipes with image URLs for restoration
                    if let firebaseURL = recipeData.firebaseImageURL {
                        recipesNeedingImageRestore.append((recipe: recipe, firebaseURL: firebaseURL))
                    }
                }
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

        // Import theme progress (if present)
        if let themeProgressData = exportWrapper.themeProgress {
            importThemeProgress(themeProgressData)
            Log.info("Imported theme progress", category: .storage, metadata: [
                "selectedThemes": themeProgressData.selectedThemeIds.count,
                "originalDay": themeProgressData.currentTrialDay
            ])
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

        // Save context - wrapped to handle potential SwiftData keypath issues
        do {
            try context.save()
        } catch {
            // SwiftData can crash on complex keypaths during save
            // Log the error but continue if recipes were imported
            Log.error("Context save failed during import", category: .storage, error: error)
            errors.append(HeirloomImportError(
                type: .parseError,
                itemId: nil,
                message: "Some data may not have saved: \(error.localizedDescription)"
            ))
        }

        // Build list of images needing restoration
        var imagesToRestore: [ImageRestoreInfo] = []

        // Handle image restoration based on options
        if !recipesNeedingImageRestore.isEmpty {
            if options.skipImageRestoration {
                // Return image info for caller to restore with progress tracking
                imagesToRestore = recipesNeedingImageRestore.map { ImageRestoreInfo(recipe: $0.recipe, firebaseURL: $0.firebaseURL) }
                Log.info("Skipping async image restoration - returning image list for caller", category: .storage, metadata: [
                    "count": imagesToRestore.count
                ])
            } else {
                // Restore images asynchronously (legacy behavior)
                Log.info("Starting image restoration for imported recipes", category: .storage, metadata: [
                    "count": recipesNeedingImageRestore.count
                ])
                Task {
                    await restoreImages(for: recipesNeedingImageRestore, context: context)
                }
            }
        }

        // Queue missing images for AI generation if opted in
        if options.generateMissingImages {
            Task {
                await queueMissingImagesForGeneration(context: context)
            }
        }

        var result = HeirloomImportResult(
            version: exportWrapper.version,
            recipesImported: recipesImported,
            connectionsImported: connectionsImported > 0 ? connectionsImported : nil,
            kitchenTablesImported: kitchenTablesImported > 0 ? kitchenTablesImported : nil,
            errors: errors
        )
        result.imagesToRestore = imagesToRestore

        Log.info("Heirloom import completed", category: .storage, metadata: [
            "version": exportWrapper.version,
            "recipesImported": recipesImported,
            "connectionsImported": connectionsImported,
            "errorCount": errors.count
        ])

        return result
    }

    // MARK: - Private Import Helpers

    /// Import a single recipe from export data
    /// - Returns: The imported Recipe, or nil if skipped (duplicate in merge mode)
    @discardableResult
    private func importRecipe(
        _ data: RecipeExportDataV2,
        context: ModelContext,
        mergeMode: Bool
    ) throws -> Recipe? {
        // Skip theme recipes - they come from JSON files, not user data
        // This handles old exports that may have included theme recipes
        if data.isThemeRecipe {
            Log.debug("Skipping theme recipe import", category: .storage, metadata: ["id": data.id, "title": data.title])
            return nil
        }

        // Check if recipe already exists
        if mergeMode {
            // Convert string ID to UUID for comparison
            // NOTE: Cannot use computed properties (like uuidString) in SwiftData predicates
            guard let recipeUUID = UUID(uuidString: data.id) else {
                Log.warning("Invalid recipe ID in import data", category: .storage, metadata: ["id": data.id])
                return nil
            }
            let descriptor = FetchDescriptor<Recipe>(
                predicate: #Predicate { $0.id == recipeUUID }
            )
            let existing = try context.fetch(descriptor)
            if !existing.isEmpty {
                Log.debug("Skipping duplicate recipe", category: .storage, metadata: ["id": data.id])
                return nil
            }
        }

        // Create new recipe from export data
        let recipe = Recipe(
            title: data.title,
            sourceType: data.sourceType != nil ? RecipeSourceType(rawValue: data.sourceType!) ?? .manual : .manual,
            sourceURL: data.sourceURL,
            instructions: data.instructions,
            servings: data.servings,
            prepTime: data.prepTime,
            cookTime: data.cookTime
        )

        // Restore original ID if valid
        if let originalUUID = UUID(uuidString: data.id) {
            recipe.id = originalUUID
        }

        recipe.notes = data.notes
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
        recipe.sharedByUserId = data.sharedByUserId
        recipe.sharedFromRecipeId = data.sharedFromRecipeId
        recipe.heritageChain = data.heritageChain
        recipe.heritageChainNames = data.heritageChainNames
        recipe.isDemoRecipe = data.isDemoRecipe ?? false
        if let generation = data.generation {
            recipe.generationCount = generation
        }
        if let sharedDateString = data.sharedDate, let sharedDate = ISO8601DateFormatter().date(from: sharedDateString) {
            recipe.sharedDate = sharedDate
        }

        // Parse ingredients from joined string
        if !data.ingredients.isEmpty {
            recipe.ingredients = data.ingredients.map { ingredientText in
                let ingredient = Ingredient()
                ingredient.originalText = ingredientText
                ingredient.name = ingredientText
                return ingredient
            }
        }

        context.insert(recipe)

        // Link to collections by name (user-created collections only)
        if let collectionNames = data.collections, !collectionNames.isEmpty {
            for collectionName in collectionNames {
                // Find existing collection
                let collectionDescriptor = FetchDescriptor<RecipeCollection>(
                    predicate: #Predicate { $0.name == collectionName }
                )
                if let existingCollection = try? context.fetch(collectionDescriptor).first {
                    // Skip theme/system collections - user recipes shouldn't be in theme collections
                    // This handles old exports that may have exported theme collection names
                    if existingCollection.type == .theme || existingCollection.type == .system {
                        Log.debug("Skipping theme/system collection link", category: .storage, metadata: [
                            "collection": collectionName,
                            "recipe": recipe.title
                        ])
                        continue
                    }
                    // Add recipe to existing user collection
                    if existingCollection.recipes == nil {
                        existingCollection.recipes = []
                    }
                    existingCollection.recipes?.append(recipe)
                } else {
                    // Create new user-created collection
                    let newCollection = RecipeCollection(name: collectionName)
                    newCollection.recipes = [recipe]
                    context.insert(newCollection)
                }
            }
        }

        return recipe
    }

    private func importPrivacySettings(_ data: PrivacySettingsExportData) async throws {
        let currentProfile = try await profileService.fetchCurrentUserProfile()

        var updatedProfile = currentProfile

        // Update individual privacy settings from export data
        updatedProfile.privacySettings.profileVisibility = ProfileVisibility(rawValue: data.profileVisibility) ?? .connections
        updatedProfile.privacySettings.recipeVisibility = RecipeVisibility(rawValue: data.recipeVisibility) ?? .connections
        updatedProfile.privacySettings.kitchenTableVisibility = KitchenTableVisibility(rawValue: data.kitchenTableVisibility) ?? .private
        updatedProfile.privacySettings.whoCanConnect = WhoCanConnect(rawValue: data.whoCanConnect) ?? .everyone
        updatedProfile.privacySettings.allowRecipeResharing = data.allowRecipeResharing
        updatedProfile.privacySettings.allowMentions = data.allowMentions
        updatedProfile.privacySettings.allowSearchIndexing = data.hasPublicProfile

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

    // MARK: - Image Restoration

    /// Restore images from preserved Firebase URLs
    /// Downloads from old URL, saves locally, then re-uploads to current user's Storage
    private func restoreImages(
        for recipes: [(recipe: Recipe, firebaseURL: String)],
        context: ModelContext
    ) async {
        var restored = 0
        var failed = 0

        for (recipe, firebaseURL) in recipes {
            do {
                try await restoreImage(firebaseURL: firebaseURL, for: recipe)
                restored += 1
            } catch {
                failed += 1
                Log.warning("Image restore failed", category: .storage, metadata: [
                    "recipeId": recipe.id.uuidString,
                    "error": error.localizedDescription
                ])
            }
        }

        // Save after all restorations
        try? context.save()

        Log.info("Image restoration complete", category: .storage, metadata: [
            "restored": restored,
            "failed": failed
        ])
    }

    /// Restore a single image from preserved Firebase URL (public for progress tracking)
    func restoreImage(firebaseURL: String, for recipe: Recipe) async throws {
        guard let url = URL(string: firebaseURL) else {
            throw HeirloomImportError(type: .imageMissing, itemId: recipe.id.uuidString, message: "Invalid image URL")
        }

        // Download from preserved URL (may fail if original account deleted)
        let (data, response) = try await URLSession.shared.data(from: url)

        // Verify we got a valid response
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw HeirloomImportError(
                type: .imageMissing,
                itemId: recipe.id.uuidString,
                message: "Image URL returned status \(httpResponse.statusCode)"
            )
        }

        guard let image = UIImage(data: data) else {
            throw HeirloomImportError(type: .imageMissing, itemId: recipe.id.uuidString, message: "Invalid image data")
        }

        // Save to local storage
        try await recipe.saveImage(image)

        // Re-upload to current user's Firebase Storage path
        let imageService = ServiceContainer.shared.resolve((any FirebaseImageServiceProtocol).self)
        if let newURL = try await imageService.uploadImage(for: recipe) {
            recipe.firebaseImageURL = newURL
        }

        Log.info("Image restored successfully", category: .storage, metadata: [
            "recipeId": recipe.id.uuidString,
            "title": recipe.title
        ])
    }

    /// Queue recipes without images for AI generation
    private func queueMissingImagesForGeneration(context: ModelContext) async {
        // Fetch all recipes without images that aren't already queued
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> {
                $0.imageFileName == nil && $0.needsAIImage == false
            }
        )

        guard let recipesNeedingImages = try? context.fetch(descriptor) else {
            Log.warning("Failed to fetch recipes needing images", category: .storage)
            return
        }

        guard !recipesNeedingImages.isEmpty else {
            Log.info("No recipes need AI image generation", category: .storage)
            return
        }

        let imageQueue: ImageGenerationQueue = ServiceContainer.shared.resolve(ImageGenerationQueue.self)
        imageQueue.context = context

        for recipe in recipesNeedingImages {
            imageQueue.enqueue(recipe) // Sets needsAIImage = true
        }

        Log.info("Queued recipes for AI image generation", category: .storage, metadata: [
            "count": recipesNeedingImages.count
        ])
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
                    sharedByUserId: nil,
                    sharedFromRecipeId: nil,
                    sharedDate: nil,
                    generation: nil,
                    rootRecipeId: nil,
                    rootProvenanceHash: nil,
                    heritageChain: nil,
                    heritageChainNames: nil,
                    isDemoRecipe: nil,
                    tags: nil,
                    collections: nil,
                    cardBackText: nil,
                    comments: nil,
                    annotations: nil,
                    firebaseImageURL: nil
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
        // Convert comments to export format
        let commentsData: [CommentExportData]? = recipe.comments?.map { comment in
            CommentExportData(
                id: comment.id.uuidString,
                text: comment.text,
                authorUserId: "", // Not tracked locally
                authorDisplayName: comment.authorName ?? "Unknown",
                createdAt: comment.createdAt.iso8601
            )
        }

        // Extract card back text (personal tips combined)
        let cardBackText: String? = recipe.cardBack.flatMap { cardBack in
            var parts: [String] = []
            if let note = cardBack.noteToFriends, !note.isEmpty {
                parts.append(note)
            }
            if !cardBack.personalTips.isEmpty {
                parts.append(contentsOf: cardBack.personalTips)
            }
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        }

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
            // V2 social/sharing fields
            sharedBy: recipe.sharedBy,
            sharedByUserId: recipe.sharedByUserId,
            sharedFromRecipeId: recipe.sharedFromRecipeId,
            sharedDate: recipe.sharedDate?.iso8601,
            generation: recipe.generationCount > 0 ? recipe.generationCount : nil,
            rootRecipeId: recipe.sharedFromRecipeId, // Immediate parent recipe ID (full lineage requires Firebase lookup)
            rootProvenanceHash: recipe.provenance.rootProvenanceHash, // Cryptographic lineage identifier
            heritageChain: recipe.heritageChain, // Cached heritage chain IDs for offline display
            heritageChainNames: recipe.heritageChainNames, // Display names for offline heritage view
            isDemoRecipe: recipe.isDemoRecipe ? true : nil, // Only export if true (demo recipes cannot be shared)
            tags: recipe.tags?.map { $0.name },
            // Only export user-created collections (exclude theme/system collections that are recreated on restore)
            collections: recipe.collections?.compactMap { $0.type == .userCreated ? $0.name : nil },
            cardBackText: cardBackText,
            comments: commentsData,
            annotations: nil, // Annotations not yet tracked on Recipe model
            firebaseImageURL: recipe.firebaseImageURL
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

    // MARK: - Theme Progress Export/Import

    /// Export theme unlock progress from UserDefaults
    private func exportThemeProgress() -> ThemeProgressExportData? {
        let userDefaults = UserDefaults.standard

        // Check if user has selected themes
        guard let selectedThemeIds = userDefaults.stringArray(forKey: "selected_theme_ids"),
              !selectedThemeIds.isEmpty else {
            return nil
        }

        // Get trial start date
        guard let trialStartDate = userDefaults.object(forKey: "theme_trial_start_date") as? Date else {
            return nil
        }

        let lastUnlockDay = userDefaults.integer(forKey: "last_unlock_day")

        // Calculate current trial day
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: trialStartDate, to: Date()).day ?? 0
        let currentTrialDay = min(max(days + 1, 1), 15)

        Log.info("Exporting theme progress", category: .storage, metadata: [
            "selectedThemes": selectedThemeIds.count,
            "currentDay": currentTrialDay,
            "lastUnlockDay": lastUnlockDay
        ])

        return ThemeProgressExportData(
            selectedThemeIds: selectedThemeIds,
            trialStartDate: trialStartDate.iso8601,
            lastUnlockDay: lastUnlockDay,
            currentTrialDay: currentTrialDay
        )
    }

    /// Import theme unlock progress to UserDefaults
    private func importThemeProgress(_ data: ThemeProgressExportData) {
        let userDefaults = UserDefaults.standard

        // Parse trial start date
        let formatter = ISO8601DateFormatter()
        guard let trialStartDate = formatter.date(from: data.trialStartDate) else {
            Log.warning("Failed to parse trial start date from import", category: .storage)
            return
        }

        // Restore theme progress
        userDefaults.set(data.selectedThemeIds, forKey: "selected_theme_ids")
        userDefaults.set(trialStartDate, forKey: "theme_trial_start_date")
        userDefaults.set(data.lastUnlockDay, forKey: "last_unlock_day")

        Log.info("Restored theme progress", category: .storage, metadata: [
            "selectedThemes": data.selectedThemeIds.count,
            "trialStartDate": data.trialStartDate,
            "lastUnlockDay": data.lastUnlockDay,
            "originalDay": data.currentTrialDay
        ])

        // Notify ThemeUnlockTracker to reload state
        NotificationCenter.default.post(
            name: NSNotification.Name("ThemeProgressRestored"),
            object: nil,
            userInfo: ["selectedThemeIds": data.selectedThemeIds]
        )
    }
}
