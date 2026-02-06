//
//  CollectionRouter.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation
import SwiftData
import UIKit

/// Routes recipes to appropriate collections based on their source
@MainActor
class CollectionRouter {

    private let modelContext: ModelContext

    /// Track created collection per job to prevent duplicates within same import session
    private var jobCollectionCache: [UUID: UUID] = [:]  // jobID -> collectionID

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Routing Methods

    /// Route a recipe to a specific collection (used when user explicitly chooses collection)
    func routeToSpecificCollection(_ recipe: Recipe, collection: RecipeCollection) {
        addRecipeToCollection(recipe, collection: collection)
        Log.info("Routed recipe to specific collection", category: .collections, metadata: [
            "recipe": recipe.title,
            "collection": collection.name
        ])
    }

    /// Route multiple recipes to a specific collection
    func routeToSpecificCollection(_ recipes: [Recipe], collection: RecipeCollection) {
        for recipe in recipes {
            addRecipeToCollection(recipe, collection: collection)
        }
        Log.info("Routed recipes to specific collection", category: .collections, metadata: [
            "count": recipes.count,
            "collection": collection.name
        ])
    }

    /// Route a recipe shared by a friend
    func routeSharedRecipe(_ recipe: Recipe, from senderName: String?) {
        let collection = findOrCreateCollection(
            name: "From Friends",
            type: .fromFriends,
            iconName: "person.2.fill"
        )

        // Set sharing metadata
        recipe.sharedBy = senderName
        recipe.sharedDate = Date()

        // Add to collection
        addRecipeToCollection(recipe, collection: collection)

        Log.info("Routed shared recipe to From Friends", category: .collections, metadata: [
            "recipe": recipe.title,
            "from": senderName ?? "unknown"
        ])
    }

    /// Route a recipe imported from a URL
    func routeURLImport(_ recipe: Recipe, sourceURL: URL) {
        routeURLImport([recipe], sourceURL: sourceURL)
    }

    /// Route multiple recipes imported from a URL
    func routeURLImport(_ recipes: [Recipe], sourceURL: URL, jobID: UUID? = nil) {
        let collection = findOrCreateCollectionWithJobTracking(
            name: "From Web",
            type: .webImports,
            iconName: "link",
            jobID: jobID
        )

        for recipe in recipes {
            // Set source metadata
            recipe.sourceURL = sourceURL.absoluteString
            // Add to collection
            addRecipeToCollection(recipe, collection: collection)
        }

        Log.info("Routed URL import(s) to From Web", category: .collections, metadata: [
            "recipe_count": recipes.count,
            "source": sourceURL.host ?? "unknown"
        ])
    }

    /// Route a recipe imported from video transcription
    func routeVideoImport(_ recipe: Recipe) {
        routeVideoImport([recipe])
    }

    /// Route multiple recipes imported from video transcription
    func routeVideoImport(_ recipes: [Recipe], jobID: UUID? = nil) {
        let collection = findOrCreateCollectionWithJobTracking(
            name: "From Videos",
            type: .videoImports,
            iconName: "video.fill",
            jobID: jobID
        )

        for recipe in recipes {
            addRecipeToCollection(recipe, collection: collection)
        }

        Log.info("Routed video import(s) to From Videos", category: .collections, metadata: [
            "recipe_count": recipes.count
        ])
    }

    /// Route a recipe imported from photo OCR (single image: recipe cards, screenshots, handwritten recipes)
    func routePhotoImport(_ recipe: Recipe) {
        routePhotoImport([recipe])
    }

    /// Route multiple recipes imported from photo OCR
    func routePhotoImport(_ recipes: [Recipe], jobID: UUID? = nil) {
        let collection = findOrCreateCollectionWithJobTracking(
            name: "From Photos",
            type: .photoImports,
            iconName: "photo.fill",
            jobID: jobID
        )

        for recipe in recipes {
            addRecipeToCollection(recipe, collection: collection)
        }

        Log.info("Routed photo import(s) to From Photos", category: .collections, metadata: [
            "recipe_count": recipes.count
        ])
    }

    /// Route recipes imported from a cookbook with enhanced consolidation logic
    func routeCookbookImport(
        _ recipes: [Recipe],
        cookbookName: String,
        authorName: String? = nil,
        jobID: UUID? = nil,
        coverImagePath: String? = nil
    ) {
        // Clean up cookbook name
        let cleanName = cleanCookbookName(cookbookName)

        // Enhanced collection finding:
        // 1. For "Cookbook Pages", consolidate ALL imports into ONE collection globally
        // 2. For custom-named cookbooks, find by exact name + type
        // 3. Use job tracking to prevent duplicate collections within same import session
        let collection = findOrCreateCookbookCollection(
            name: cleanName,
            jobID: jobID,
            coverImagePath: coverImagePath
        )

        collection.sourceCookbook = cookbookName

        // Set author if provided (from PDF metadata)
        if let author = authorName, !author.isEmpty {
            collection.sourceAuthor = author
        }

        for recipe in recipes {
            recipe.sourceCookbook = cookbookName
            addRecipeToCollection(recipe, collection: collection)
        }

        Log.info("Routed \(recipes.count) recipes to cookbook collection", category: .collections, metadata: [
            "cookbook": cleanName,
            "author": authorName ?? "nil",
            "count": String(recipes.count),
            "collection_id": collection.id.uuidString
        ])
    }

    /// Route a curated theme recipe
    func routeThemeRecipe(_ recipe: Recipe, to theme: RecipeTheme) {
        guard let collection = theme.collection else {
            Log.warning("Theme has no collection, creating one", category: .collections)
            let newCollection = RecipeCollection(name: theme.name, iconName: theme.iconName, collectionType: .theme)
            newCollection.sourceTheme = theme

            // Set theme cover image as collection background
            if let coverImageURL = theme.coverImageURL {
                newCollection.generatedBackgroundImagePath = coverImageURL
                newCollection.useCustomBackground = true
                Log.info("Set theme cover image for collection", category: .collections, metadata: [
                    "themeName": theme.name,
                    "imageURL": coverImageURL
                ])
            }

            theme.collection = newCollection
            modelContext.insert(newCollection)

            addRecipeToCollection(recipe, collection: newCollection)
            return
        }

        addRecipeToCollection(recipe, collection: collection)
    }

    // MARK: - Helper Methods

    /// Find existing collection or create new one
    func findOrCreateCollection(
        name: String,
        type: CollectionType,
        iconName: String
    ) -> RecipeCollection {
        // Try to find existing
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { collection in
                collection.name == name && collection.collectionType == type.rawValue
            }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            // Ensure preset background is set for system collections that support it
            applyPresetBackgroundIfNeeded(to: existing, type: type)
            return existing
        }

        // Create new collection
        let collection = RecipeCollection(name: name, iconName: iconName, collectionType: type)
        collection.createdDate = Date()

        // Apply preset background for system collections
        applyPresetBackgroundIfNeeded(to: collection, type: type)

        modelContext.insert(collection)

        Log.info("Created new collection", category: .collections, metadata: [
            "name": name,
            "type": type.rawValue
        ])

        return collection
    }

    /// Apply preset background image for specific collection types
    private func applyPresetBackgroundIfNeeded(to collection: RecipeCollection, type: CollectionType) {
        // Skip if collection already has a custom background
        guard collection.customBackgroundImagePath == nil else { return }

        // Map collection types to preset asset names
        let presetAssetName: String? = switch type {
        case .fromFriends:
            "from-friends-bg"
        case .videoImports:
            "from-videos-bg"
        case .webImports:
            "from-web-bg"
        case .photoImports:
            "from-photos-bg"
        default:
            nil
        }

        // Check if bundled preset exists and apply
        if let assetName = presetAssetName, UIImage(named: assetName) != nil {
            collection.customBackgroundImagePath = "preset-\(assetName)"
            collection.useCustomBackground = true
            Log.info("Applied preset background to collection", category: .collections, metadata: [
                "collection": collection.name,
                "preset": assetName
            ])
        }
    }

    /// Find or create collection with job-level tracking to prevent duplicates within same import session
    private func findOrCreateCollectionWithJobTracking(
        name: String,
        type: CollectionType,
        iconName: String,
        jobID: UUID?
    ) -> RecipeCollection {
        // Check if this job already created a collection
        if let jobID = jobID, let cachedCollectionID = jobCollectionCache[jobID] {
            let descriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate { collection in
                    collection.id == cachedCollectionID
                }
            )
            if let cached = try? modelContext.fetch(descriptor).first {
                Log.info("Reusing collection from job cache", category: .collections, metadata: [
                    "job_id": jobID.uuidString,
                    "collection_id": cachedCollectionID.uuidString
                ])
                return cached
            }
        }

        // Find or create collection
        let collection = findOrCreateCollection(name: name, type: type, iconName: iconName)

        // Cache for this job
        if let jobID = jobID {
            jobCollectionCache[jobID] = collection.id
        }

        return collection
    }

    /// Find or create cookbook collection with sophisticated consolidation logic
    private func findOrCreateCookbookCollection(
        name: String,
        jobID: UUID?,
        coverImagePath: String?
    ) -> RecipeCollection {
        // Strategy:
        // 1. Check job cache first
        // 2. For "Cookbook Pages", consolidate globally (all imports use same collection)
        // 3. For custom-named cookbooks, find by name + type

        // Check job cache
        if let jobID = jobID, let cachedCollectionID = jobCollectionCache[jobID] {
            let descriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate { collection in
                    collection.id == cachedCollectionID
                }
            )
            if let cached = try? modelContext.fetch(descriptor).first {
                Log.info("Reusing cookbook collection from job cache", category: .collections, metadata: [
                    "job_id": jobID.uuidString,
                    "collection_id": cachedCollectionID.uuidString,
                    "name": name
                ])
                return cached
            }
        }

        // For "Cookbook Pages", consolidate globally
        let existingCollection: RecipeCollection?
        if name == "Cookbook Pages" {
            let descriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate { collection in
                    collection.name == name && collection.collectionType == "cookbook"
                }
            )
            existingCollection = try? modelContext.fetch(descriptor).first

            if existingCollection != nil {
                Log.info("Reusing existing 'Cookbook Pages' collection from previous import", category: .collections, metadata: [
                    "name": name
                ])
            } else {
                Log.info("Creating first 'Cookbook Pages' collection", category: .collections, metadata: [
                    "name": name
                ])
            }
        } else {
            // For custom-named cookbooks, find by name + type
            let descriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate { collection in
                    collection.name == name && collection.collectionType == "cookbook"
                }
            )
            existingCollection = try? modelContext.fetch(descriptor).first
        }

        let collection: RecipeCollection
        if let existing = existingCollection {
            collection = existing
            // Ensure preset background is applied if missing (for upgrades)
            applyPDFImportsPresetIfNeeded(to: collection, name: name)
        } else {
            // Create new collection
            collection = RecipeCollection(
                name: name,
                description: "Imported from \(name)",
                iconName: "book.fill",
                color: "#FF6B6B",
                isSystemCollection: false,
                collectionType: .cookbook
            )

            // Set cookbook cover image if available
            if let coverPath = coverImagePath {
                collection.cookbookCoverImagePath = coverPath
                Log.info("Applied cookbook cover to collection", category: .collections, metadata: [
                    "coverPath": coverPath
                ])
            }

            // Apply preset background for "PDF Imports" collection
            applyPDFImportsPresetIfNeeded(to: collection, name: name)

            collection.createdDate = Date()
            modelContext.insert(collection)

            Log.info("Created new cookbook collection", category: .collections, metadata: [
                "name": name,
                "collection_id": collection.id.uuidString
            ])
        }

        // Cache for this job
        if let jobID = jobID {
            jobCollectionCache[jobID] = collection.id
        }

        return collection
    }

    /// Add recipe to collection if not already present
    private func addRecipeToCollection(_ recipe: Recipe, collection: RecipeCollection) {
        // Initialize collections array if needed
        if recipe.collections == nil {
            recipe.collections = []
        }

        // Check if already in collection
        let alreadyInCollection = recipe.collections?.contains(where: { $0.id == collection.id }) ?? false

        if !alreadyInCollection {
            recipe.collections?.append(collection)
        }

        try? modelContext.save()
    }

    /// Apply preset background for "PDF Imports" collection
    private func applyPDFImportsPresetIfNeeded(to collection: RecipeCollection, name: String) {
        // Only apply to "PDF Imports" collection
        guard name == "PDF Imports" else { return }

        // Skip if collection already has a custom or generated background
        guard collection.customBackgroundImagePath == nil,
              collection.generatedBackgroundImagePath == nil,
              collection.cookbookCoverImagePath == nil else { return }

        // Check if bundled preset exists and apply
        if UIImage(named: "pdf-imports-bg") != nil {
            collection.customBackgroundImagePath = "preset-pdf-imports-bg"
            collection.useCustomBackground = true
            Log.info("Applied preset background to PDF Imports collection", category: .collections)
        }
    }

    /// Clean up cookbook name for display
    private func cleanCookbookName(_ name: String) -> String {
        var clean = name

        // Remove file extensions
        let extensions = [".pdf", ".epub", ".mobi"]
        for ext in extensions {
            if clean.lowercased().hasSuffix(ext) {
                clean = String(clean.dropLast(ext.count))
            }
        }

        // Remove common prefixes
        let prefixes = ["the ", "a "]
        for prefix in prefixes {
            if clean.lowercased().hasPrefix(prefix) {
                clean = String(clean.dropFirst(prefix.count))
            }
        }

        // Capitalize first letter
        if let first = clean.first {
            clean = first.uppercased() + clean.dropFirst()
        }

        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
