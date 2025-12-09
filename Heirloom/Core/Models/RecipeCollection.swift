import Foundation
import SwiftData
import SwiftUI

@Model
final class RecipeCollection {
    var id: UUID
    var name: String
    var desc: String? // "description" is a reserved keyword
    var iconName: String
    var color: String // Hex color code
    var createdDate: Date
    var isSystemCollection: Bool // For built-in collections like "Favorites"

    // Relationships
    @Relationship(inverse: \Recipe.collections) var recipes: [Recipe]?

    init(
        name: String,
        description: String? = nil,
        iconName: String = "folder.fill",
        color: String = "#FF6B6B",
        isSystemCollection: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.desc = description
        self.iconName = iconName
        self.color = color
        self.createdDate = Date()
        self.isSystemCollection = isSystemCollection
    }

    // MARK: - Computed Properties

    var swiftUIColor: Color {
        Color(hex: color) ?? HeirloomColors.tomato
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
        let favoritesExists = (try? context.fetch(FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { $0.name == "Favorites" && $0.isSystemCollection }
        )))?.isEmpty == false

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
