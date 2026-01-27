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
    var isSystemCollection: Bool = false // For built-in collections like "Favorites"
    var isAllRecipes: Bool = false // Special "All Recipes" collection that shows all recipes

    // MARK: - Theme System (Collections 2.1)
    var collectionType: String = "userCreated" // CollectionType rawValue

    @Relationship(deleteRule: .nullify)
    var sourceTheme: RecipeTheme?

    var sourceThemeId: String? // Firebase ID of the theme (avoids accessing relationship)

    var sourceCookbook: String?
    var sourceURL: String?

    // Custom Backgrounds
    var customBackgroundImagePath: String? // User-selected background image filename (local storage)
    var generatedBackgroundImagePath: String? // AI-generated background image filename
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
        // System collections and "All Recipes" are hidden
        if isSystemCollection || isAllRecipes {
            return false
        }

        // Empty non-theme collections are hidden
        if type != .theme && recipeCount == 0 {
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
            if let cookbook = sourceCookbook {
                return "From \(cookbook)"
            }
            return "\(recipeCount) recipes"
        default:
            return "\(recipeCount) recipe\(recipeCount == 1 ? "" : "s")"
        }
    }

    /// Display name for collection (uses type name for auto-generated collections)
    var displayName: String {
        // For auto-generated type-based collections, use the type display name
        switch type {
        case .webImports:
            return "Web Imports"
        case .videoImports:
            return "Video Imports"
        case .cookbook:
            return "Cookbook Pages"
        case .photoImports:
            return "Photo Imports"
        case .fromFriends:
            return "From Friends"
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

    // MARK: - System Collections

    static func createSystemCollections(context: ModelContext) {
        // Check if All Recipes already exists
        var allRecipesDescriptor = FetchDescriptor<RecipeCollection>()
        allRecipesDescriptor.predicate = #Predicate<RecipeCollection> { collection in
            collection.isAllRecipes == true
        }
        let allRecipesExists = (try? context.fetch(allRecipesDescriptor))?.isEmpty == false

        if !allRecipesExists {
            let allRecipes = RecipeCollection(
                name: "All Recipes",
                description: "All recipes in your library",
                iconName: "book.closed.fill",
                color: "#FF6B6B",
                isSystemCollection: true,
                isAllRecipes: true
            )
            context.insert(allRecipes)
        }

        // Check if Favorites already exists
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
