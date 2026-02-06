import Foundation
import SwiftData
import SwiftUI

@Model
final class RecipeCollection {
    var id: UUID = UUID()
    var name: String = ""
    var desc: String? // "description" is a reserved keyword
    var iconName: String = "folder.fill"
    var color: String = "#FF6B6B" // Hex color code
    var createdDate: Date = Date()
    var lastViewedDate: Date? // Last time user opened this collection (for "NEW" badge detection)
    var isSystemCollection: Bool = false // For built-in collections like "Favorites"
    var isAllRecipes: Bool = false // Special "All Recipes" collection that shows all recipes

    // MARK: - Theme System (Collections 2.1)
    var collectionType: String = "userCreated" // CollectionType rawValue

    @Relationship(deleteRule: .nullify)
    var sourceTheme: RecipeTheme?

    var sourceThemeId: String? // Firebase ID of the theme (avoids accessing relationship)

    var sourceCookbook: String?
    var sourceAuthor: String?
    var sourceURL: String?

    // Custom Backgrounds
    var customBackgroundImagePath: String? // User-selected background image filename (local storage)
    var generatedBackgroundImagePath: String? // AI-generated background image filename
    var cookbookCoverImagePath: String? // Cookbook cover image (from PDF first page)
    var useCustomBackground: Bool = false // Whether to show custom/generated background instead of recipe collage
    var lastImageGenerationDate: Date? // Date when background was last generated
    var lastRecipeCountAtGeneration: Int = 0 // Recipe count at time of last generation (for staleness detection)

    // Relationships
    @Relationship(inverse: \Recipe.collections) var recipes: [Recipe]?

    init(
        name: String,
        description: String? = nil,
        iconName: String = "folder.fill",
        color: String = "#FF6B6B",
        isSystemCollection: Bool = false,
        isAllRecipes: Bool = false,
        collectionType: CollectionType = .userCreated
    ) {
        self.id = UUID()
        self.name = name
        self.desc = description
        self.iconName = iconName
        self.color = color
        self.createdDate = Date()
        self.isSystemCollection = isSystemCollection
        self.isAllRecipes = isAllRecipes
        self.collectionType = collectionType.rawValue
    }

    // MARK: - Computed Properties

    var swiftUIColor: Color {
        Color(hex: color)
    }

    var recipeCount: Int {
        recipes?.count ?? 0
    }

    /// Whether this collection has recipes that were added since the last time user viewed it
    /// Used to show "NEW" badge on collection cards
    /// Badge clears when user taps into the collection (calls markAsViewed)
    var hasNewRecipes: Bool {
        guard let allRecipes = recipes, !allRecipes.isEmpty else {
            return false
        }

        // If collection has been viewed, only show badge for recipes added AFTER that view
        if let lastViewed = lastViewedDate {
            return allRecipes.contains { recipe in
                return recipe.createdAt > lastViewed
            }
        }

        // Collection never viewed - show badge if recipes were added in the last 48 hours
        let fortyEightHoursAgo = Date().addingTimeInterval(-48 * 60 * 60)
        return allRecipes.contains { recipe in
            return recipe.createdAt > fortyEightHoursAgo
        }
    }

    /// Count of new recipes added since last viewed
    var newRecipeCount: Int {
        guard let lastViewed = lastViewedDate else {
            return recipeCount
        }

        guard let allRecipes = recipes else {
            return 0
        }

        return allRecipes.filter { recipe in
            return recipe.createdAt > lastViewed
        }.count
    }

    var displayDescription: String {
        if let desc = desc {
            return desc
        } else if recipeCount == 0 {
            return "No recipes yet"
        } else if recipeCount == 1 {
            return "1 recipe"
        } else {
            return "\(recipeCount) recipes"
        }
    }

    var isHeritageCollection: Bool {
        type == .theme
    }

    /// Computed property for collection type enum
    var type: CollectionType {
        get { CollectionType(rawValue: collectionType) ?? .userCreated }
        set { collectionType = newValue.rawValue }
    }

    var isVisibleInMainList: Bool {
        // "All Recipes" only visible once it has recipes (appears after first user-added recipe)
        if isAllRecipes {
            return recipeCount > 0
        }

        // Other system collections are hidden (Favorites, Quick Meals, Meal Prep)
        if isSystemCollection {
            return false
        }

        // Empty auto-generated collections are hidden, but user-created and theme collections should show
        // Exception: "Generated Recipes" collection should always show (it's user-created type)
        if type != .theme && type != CollectionType.userCreated && recipeCount == 0 {
            return false
        }

        return true
    }

    var subtitleText: String {
        switch type {
        case .theme:
            if let theme = sourceTheme {
                let unlockedCount = recipes?.count ?? 0
                let totalCount = theme.totalRecipes
                if unlockedCount < totalCount {
                    return "\(unlockedCount) of \(totalCount) recipes unlocked"
                } else {
                    return "All \(totalCount) recipes unlocked"
                }
            }
            return "\(recipeCount) recipes"
        case .fromFriends:
            return "\(recipeCount) shared recipe\(recipeCount == 1 ? "" : "s")"
        case .videoImports:
            return "\(recipeCount) video recipe\(recipeCount == 1 ? "" : "s")"
        case .webImports:
            return "\(recipeCount) web recipe\(recipeCount == 1 ? "" : "s")"
        case .photoImports:
            return "\(recipeCount) photo recipe\(recipeCount == 1 ? "" : "s")"
        case .cookbook:
            // Prefer author name, fallback to cookbook name
            if let author = sourceAuthor, !author.isEmpty {
                return "From \(author)"
            } else if let cookbook = sourceCookbook {
                return "From \(cookbook)"
            }
            return "\(recipeCount) recipes"
        default:
            return "\(recipeCount) recipe\(recipeCount == 1 ? "" : "s")"
        }
    }

    /// Display name for collection (uses type name for auto-generated collections)
    var displayName: String {
        // For auto-generated type-based collections WITHOUT custom names, use the type display name
        // But cookbook collections with custom names should use the custom name
        switch type {
        case .webImports:
            return "Web Imports"
        case .videoImports:
            return "Video Imports"
        case .cookbook:
            // Cookbook collections always use their custom name
            return name
        case .photoImports:
            return "Photo Imports"
        case .fromFriends:
            return "From Friends"
        case .communityRecipes:
            return "Community Recipes"
        case .userCreated, .theme, .system:
            // User-created, theme, and system collections use their custom name
            return name
        }
    }

    /// Whether this collection's name can be edited by the user
    var isNameEditable: Bool {
        switch type {
        case .userCreated, .theme:
            return true
        default:
            return false // System and auto-generated collections can't be renamed
        }
    }

    // MARK: - Task #6: Collection Categories and Rules

    /// Collection category for organizational grouping (delegates to CollectionType)
    var category: CollectionCategory {
        type.category
    }

    /// Whether this collection can be shared with other users (delegates to CollectionType)
    var canShare: Bool {
        type.canShare
    }

    /// Whether this collection is system-managed and cannot be deleted (delegates to CollectionType)
    var isSystemManaged: Bool {
        type.isSystemManaged
    }

    /// Explanation text when user tries to share a restricted collection
    var shareRestrictionReason: String? {
        type.shareRestrictionReason
    }

    /// Display order for sorting within category sections
    var displayOrder: Int {
        type.sortPriority
    }

    /// Category-specific icon (defaults to collection's icon or category icon)
    var categoryIcon: String {
        if !iconName.isEmpty && iconName != "folder.fill" {
            return iconName
        }
        return category.sectionIcon
    }

    // MARK: - Predefined Icons

    static let predefinedIcons = [
        "folder.fill",
        "heart.fill",
        "star.fill",
        "book.fill",
        "flame.fill",
        "leaf.fill",
        "birthday.cake.fill",
        "fork.knife",
        "cup.and.saucer.fill",
        "carrot.fill",
        "fish.fill"
    ]

    // MARK: - Actions

    /// Mark this collection as viewed (clears "NEW" badge)
    func markAsViewed() {
        lastViewedDate = Date()
    }

    // MARK: - System Collections

    static func createSystemCollections(context: ModelContext) {
        // Check if All Recipes already exists (by flag OR by name for legacy collections)
        var allRecipesDescriptor = FetchDescriptor<RecipeCollection>()
        allRecipesDescriptor.predicate = #Predicate<RecipeCollection> { collection in
            collection.isAllRecipes == true
        }
        let existingByFlag = try? context.fetch(allRecipesDescriptor)

        // Also check by name for legacy collections that might not have the flag
        var allRecipesByNameDescriptor = FetchDescriptor<RecipeCollection>()
        allRecipesByNameDescriptor.predicate = #Predicate<RecipeCollection> { collection in
            collection.name == "All Recipes"
        }
        let existingByName = try? context.fetch(allRecipesByNameDescriptor)

        if let allRecipesCollection = existingByFlag?.first {
            // Ensure existing "All Recipes" has the correct type for visibility
            if allRecipesCollection.collectionType != CollectionType.userCreated.rawValue {
                allRecipesCollection.collectionType = CollectionType.userCreated.rawValue
            }
            // Ensure preset background is set
            if allRecipesCollection.customBackgroundImagePath == nil && UIImage(named: "all-recipes-bg") != nil {
                allRecipesCollection.customBackgroundImagePath = "preset-all-recipes-bg"
                allRecipesCollection.useCustomBackground = true
            }
        } else if let legacyAllRecipes = existingByName?.first {
            // Found by name but not by flag - migrate it
            legacyAllRecipes.isAllRecipes = true
            legacyAllRecipes.isSystemCollection = true
            if legacyAllRecipes.collectionType != CollectionType.userCreated.rawValue {
                legacyAllRecipes.collectionType = CollectionType.userCreated.rawValue
            }
            // Set preset background
            if UIImage(named: "all-recipes-bg") != nil {
                legacyAllRecipes.customBackgroundImagePath = "preset-all-recipes-bg"
                legacyAllRecipes.useCustomBackground = true
            }
            Log.info("Migrated legacy All Recipes collection", category: .general)
        } else {
            // Create new All Recipes collection
            let allRecipes = RecipeCollection(
                name: "All Recipes",
                description: "All recipes in your library",
                iconName: "book.closed.fill",
                color: "#FF6B6B",
                isSystemCollection: true,
                isAllRecipes: true
            )
            // Set preset background image
            if UIImage(named: "all-recipes-bg") != nil {
                allRecipes.customBackgroundImagePath = "preset-all-recipes-bg"
                allRecipes.useCustomBackground = true
            }
            context.insert(allRecipes)
            Log.info("Created new All Recipes collection", category: .general)
        }

        // Check if "Generated Recipes" collection exists (visible on first launch)
        // Also handle duplicates - merge them if multiple exist
        var generatedDescriptor = FetchDescriptor<RecipeCollection>()
        generatedDescriptor.predicate = #Predicate<RecipeCollection> { collection in
            collection.name == "Generated Recipes"
        }
        let existingGeneratedCollections = (try? context.fetch(generatedDescriptor)) ?? []

        if existingGeneratedCollections.isEmpty {
            // Create new Generated Recipes collection
            let generatedRecipes = RecipeCollection(
                name: "Generated Recipes",
                description: "AI-created recipes",
                iconName: "wand.and.stars",
                color: "#9B59B6", // Purple for AI/magic theme
                isSystemCollection: false,
                isAllRecipes: false,
                collectionType: .userCreated
            )
            // Check if bundled preset image exists before enabling custom background
            // "preset-" prefix tells AsyncRecipeImage to load from bundle assets
            if UIImage(named: "generated-recipes-bg") != nil {
                generatedRecipes.customBackgroundImagePath = "preset-generated-recipes-bg"
                generatedRecipes.useCustomBackground = true
            }
            // Otherwise uses icon placeholder (wand.and.stars)
            context.insert(generatedRecipes)
            Log.info("Created Generated Recipes collection", category: .general)
        } else if existingGeneratedCollections.count > 1 {
            // DEDUPLICATION: Multiple "Generated Recipes" collections found
            // Keep the one with most recipes, merge others into it, then delete duplicates
            Log.warning("Found duplicate Generated Recipes collections", category: .collections, metadata: [
                "count": existingGeneratedCollections.count
            ])

            // Sort by recipe count (descending) to keep the one with most recipes
            let sortedCollections = existingGeneratedCollections.sorted {
                ($0.recipes?.count ?? 0) > ($1.recipes?.count ?? 0)
            }

            let primaryCollection = sortedCollections[0]
            let duplicates = Array(sortedCollections.dropFirst())

            // Move recipes from duplicates to primary collection
            for duplicate in duplicates {
                // Make a copy of recipes array to avoid mutation during iteration
                let recipesToMove = Array(duplicate.recipes ?? [])
                for recipe in recipesToMove {
                    // Remove from duplicate's collection
                    recipe.collections?.removeAll { $0.id == duplicate.id }
                    // Add to primary collection
                    if recipe.collections == nil {
                        recipe.collections = []
                    }
                    if !recipe.collections!.contains(where: { $0.id == primaryCollection.id }) {
                        recipe.collections!.append(primaryCollection)
                    }
                }
                if !recipesToMove.isEmpty {
                    Log.info("Moved recipes from duplicate collection", category: .collections, metadata: [
                        "movedCount": recipesToMove.count,
                        "fromId": duplicate.id.uuidString
                    ])
                }
                // Delete the duplicate collection
                context.delete(duplicate)
            }

            // Ensure primary has the correct properties
            if primaryCollection.customBackgroundImagePath == nil && UIImage(named: "generated-recipes-bg") != nil {
                primaryCollection.customBackgroundImagePath = "preset-generated-recipes-bg"
                primaryCollection.useCustomBackground = true
            }

            Log.info("Deduplicated Generated Recipes collections", category: .collections, metadata: [
                "kept": primaryCollection.id.uuidString,
                "deleted": duplicates.count
            ])

            do {
                try context.save()
                Log.info("Successfully saved after deduplication", category: .collections)
            } catch {
                Log.error("Failed to save after deduplication", category: .collections, metadata: [
                    "error": error.localizedDescription
                ])
            }
        } else if existingGeneratedCollections.count == 1 {
            // Single existing collection - ensure preset background is set
            // This handles upgrades from before preset was added
            let existingCollection = existingGeneratedCollections[0]
            if existingCollection.customBackgroundImagePath == nil && UIImage(named: "generated-recipes-bg") != nil {
                existingCollection.customBackgroundImagePath = "preset-generated-recipes-bg"
                existingCollection.useCustomBackground = true
                Log.info("Updated Generated Recipes collection with preset background", category: .collections)
            }
        }

        // Check if Favorites already exists (hidden system collections)
        var descriptor = FetchDescriptor<RecipeCollection>()
        descriptor.predicate = #Predicate<RecipeCollection> { collection in
            collection.name == "Favorites" && collection.isSystemCollection == true
        }
        let favoritesExists = (try? context.fetch(descriptor))?.isEmpty == false

        if !favoritesExists {
            let favorites = RecipeCollection(
                name: "Favorites",
                description: "Your favorite recipes",
                iconName: "heart.fill",
                color: "#FF6B6B",
                isSystemCollection: true
            )
            context.insert(favorites)

            let quickMeals = RecipeCollection(
                name: "Quick Meals",
                description: "Recipes under 30 minutes",
                iconName: "clock.fill",
                color: "#4ECDC4",
                isSystemCollection: true
            )
            context.insert(quickMeals)

            let mealPrep = RecipeCollection(
                name: "Meal Prep",
                description: "Great for batch cooking",
                iconName: "tray.2.fill",
                color: "#95E1D3",
                isSystemCollection: true
            )
            context.insert(mealPrep)

            try? context.save()
        }
    }

}

// MARK: - Deletion Tombstone

/// Tombstone record for tracking deleted collections
/// Prevents Firebase sync from recreating locally-deleted collections
@Model
final class DeletedCollectionRecord {
    var collectionId: UUID
    var deletedAt: Date
    var syncedToFirebase: Bool

    init(collectionId: UUID) {
        self.collectionId = collectionId
        self.deletedAt = Date()
        self.syncedToFirebase = false
    }
}
