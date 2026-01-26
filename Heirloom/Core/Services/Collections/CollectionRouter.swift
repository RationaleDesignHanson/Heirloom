//
//  CollectionRouter.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation
import SwiftData

/// Routes recipes to appropriate collections based on their source
@MainActor
class CollectionRouter {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Routing Methods

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
        let collection = findOrCreateCollection(
            name: "From Web",
            type: .webImports,
            iconName: "link"
        )

        // Set source metadata
        recipe.sourceURL = sourceURL.absoluteString

        // Add to collection
        addRecipeToCollection(recipe, collection: collection)

        Log.info("Routed URL import to From Web", category: .collections, metadata: [
            "recipe": recipe.title,
            "source": sourceURL.host ?? "unknown"
        ])
    }

    /// Route a recipe imported from video transcription
    func routeVideoImport(_ recipe: Recipe) {
        let collection = findOrCreateCollection(
            name: "From Videos",
            type: .videoImports,
            iconName: "video.fill"
        )

        // Add to collection
        addRecipeToCollection(recipe, collection: collection)

        Log.info("Routed video import to From Videos", category: .collections, metadata: [
            "recipe": recipe.title
        ])
    }

    /// Route recipes imported from a cookbook
    func routeCookbookImport(_ recipes: [Recipe], cookbookName: String) {
        // Clean up cookbook name
        let cleanName = cleanCookbookName(cookbookName)

        let collection = findOrCreateCollection(
            name: cleanName,
            type: .cookbook,
            iconName: "book.closed.fill"
        )

        collection.sourceCookbook = cookbookName

        for recipe in recipes {
            recipe.sourceCookbook = cookbookName
            addRecipeToCollection(recipe, collection: collection)
        }

        Log.info("Routed \(recipes.count) recipes to cookbook collection", category: .collections, metadata: [
            "cookbook": cleanName,
            "count": String(recipes.count)
        ])
    }

    /// Route a curated theme recipe
    func routeThemeRecipe(_ recipe: Recipe, to theme: RecipeTheme) {
        guard let collection = theme.collection else {
            Log.warning("Theme has no collection, creating one", category: .collections)
            let newCollection = RecipeCollection(name: theme.name, iconName: theme.iconName, collectionType: .theme)
            newCollection.sourceTheme = theme
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
            return existing
        }

        // Create new collection
        let collection = RecipeCollection(name: name, iconName: iconName, collectionType: type)
        collection.createdDate = Date()
        modelContext.insert(collection)

        Log.info("Created new collection", category: .collections, metadata: [
            "name": name,
            "type": type.rawValue
        ])

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
