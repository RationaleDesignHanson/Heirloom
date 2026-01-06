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
    var heritageCollectionId: String? // ID for founding heritage collections (e.g., "presidential-pantry")

    // Relationships
    @Relationship(inverse: \Recipe.collections) var recipes: [Recipe]?

    init(
        name: String,
        description: String? = nil,
        iconName: String = "folder.fill",
        color: String = "#FF6B6B",
        isSystemCollection: Bool = false,
        heritageCollectionId: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.desc = description
        self.iconName = iconName
        self.color = color
        self.createdDate = Date()
        self.isSystemCollection = isSystemCollection
        self.heritageCollectionId = heritageCollectionId
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
        heritageCollectionId != nil
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

    // MARK: - Heritage Collections

    /// Heritage collection identifiers
    enum HeritageCollectionID: String, CaseIterable {
        case presidentialPantry = "presidential-pantry"
        case literaryKitchen = "literary-kitchen"
        case ancientTable = "ancient-table"
        case americanFoundation = "american-foundation"

        var displayName: String {
            switch self {
            case .presidentialPantry: return "Presidential Pantry"
            case .literaryKitchen: return "Literary Kitchen"
            case .ancientTable: return "Ancient Table"
            case .americanFoundation: return "American Foundation"
            }
        }

        var description: String {
            switch self {
            case .presidentialPantry:
                return "Recipes from First Families spanning 1800s-1900s"
            case .literaryKitchen:
                return "Dishes from literary works and authors' tables"
            case .ancientTable:
                return "Ancient recipes from classical civilizations"
            case .americanFoundation:
                return "Foundational American recipes from colonial era"
            }
        }

        var color: String {
            switch self {
            case .presidentialPantry: return "#8B0000"  // Deep red
            case .literaryKitchen: return "#2F4F4F"     // Dark slate gray
            case .ancientTable: return "#8B4513"        // Saddle brown/terracotta
            case .americanFoundation: return "#CD853F"  // Peru/amber
            }
        }

        var iconName: String {
            switch self {
            case .presidentialPantry: return "building.columns.fill"
            case .literaryKitchen: return "book.closed.fill"
            case .ancientTable: return "scroll.fill"
            case .americanFoundation: return "flag.fill"
            }
        }
    }

    /// Create the 4 founding heritage collections
    static func createHeritageCollections(context: ModelContext) {
        // Check if heritage collections already exist
        var descriptor = FetchDescriptor<RecipeCollection>()
        descriptor.predicate = #Predicate<RecipeCollection> { collection in
            collection.heritageCollectionId != nil
        }
        let heritageExists = (try? context.fetch(descriptor))?.isEmpty == false

        guard !heritageExists else { return }

        // Create all 4 founding collections
        for collectionID in HeritageCollectionID.allCases {
            let collection = RecipeCollection(
                name: collectionID.displayName,
                description: collectionID.description,
                iconName: collectionID.iconName,
                color: collectionID.color,
                isSystemCollection: true,
                heritageCollectionId: collectionID.rawValue
            )
            context.insert(collection)
        }

        try? context.save()
    }
}
