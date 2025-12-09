import Foundation
import SwiftData
import UIKit

@Model
final class Recipe {
    // MARK: - Identity
    var id: UUID = UUID()
    var title: String = ""
    var dateAdded: Date = Date()
    var lastModified: Date = Date()

    // MARK: - Source Information
    var sourceType: RecipeSourceType?
    var sourceURL: String?
    var sourceBookTitle: String?
    var sourceBookAuthor: String?
    var sourceBookPage: Int?
    var sourcePerson: String?
    var sourceDate: String?
    var sourceStory: String?

    // MARK: - Content
    /// Image stored in file system, not database (per Systems Architect recommendation)
    /// Path relative to ImageStorageService.imagesDirectory
    var imageFileName: String?

    /// Original image URL for potential re-download
    var sourceImageURL: String?

    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    var ingredients: [Ingredient]?

    var instructions: [String] = []
    var servings: String?
    var prepTime: String?
    var cookTime: String?
    var totalTime: String?
    var notes: String?

    // MARK: - Personalization (Phase 2)
    @Relationship(deleteRule: .cascade, inverse: \CardStyle.recipe)
    var cardStyle: CardStyle?

    // MARK: - Metadata
    var timesCooked: Int = 0
    var lastCooked: Date?
    var isFavorite: Bool = false
    var isInShoppingList: Bool = false

    // MARK: - Organization
    var tags: [Tag]?
    var collections: [RecipeCollection]?

    // MARK: - Social (Phase 2)
    var sharedBy: String?
    var sharedDate: Date?
    var passedDownBy: String?
    var passedDownDate: Date?
    var passedDownMessage: String?
    var generationCount: Int = 1

    // MARK: - Initialization
    init(
        title: String = "",
        sourceType: RecipeSourceType = .manual,
        sourceURL: String? = nil,
        instructions: [String] = [],
        servings: String? = nil,
        prepTime: String? = nil,
        cookTime: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.dateAdded = Date()
        self.lastModified = Date()
        self.ingredients = []
        self.instructions = instructions
        self.servings = servings
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.timesCooked = 0
        self.isFavorite = false
        self.isInShoppingList = false
        self.generationCount = 1
    }
}

// MARK: - Computed Properties
extension Recipe {
    var sourceDisplayName: String {
        switch sourceType ?? .manual {
        case .url:
            if let urlString = sourceURL,
               let url = URL(string: urlString),
               let host = url.host() {
                return host.replacingOccurrences(of: "www.", with: "")
            }
            return "Website"
        case .cookbook:
            if let title = sourceBookTitle {
                if let page = sourceBookPage {
                    return "\(title), p. \(page)"
                }
                return title
            }
            return "Cookbook"
        case .family:
            if let person = sourcePerson {
                if let date = sourceDate {
                    return "\(person), \(date)"
                }
                return person
            }
            return "Family Recipe"
        case .manual:
            return "My Recipe"
        }
    }

    var shouldShowLoveMarks: Bool {
        timesCooked >= 5
    }

    var loveMarkIntensity: Double {
        min(Double(timesCooked) / 20.0, 1.0)
    }

    /// Lightweight DTO for list views (per iOS Engineer recommendation)
    var listItem: RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            imageFileName: imageFileName,
            sourceType: sourceType ?? .manual,
            sourceDisplayName: sourceDisplayName,
            isFavorite: isFavorite,
            timesCooked: timesCooked,
            dateAdded: dateAdded
        )
    }
}

// MARK: - Image Helpers
extension Recipe {
    /// Load the recipe image from file system
    func loadImage() async -> UIImage? {
        guard let fileName = imageFileName else { return nil }
        return await ImageStorageService.shared.loadImage(fileName: fileName)
    }

    /// Save an image to file system and update the recipe
    @MainActor
    func saveImage(_ image: UIImage) async throws {
        let fileName = try await ImageStorageService.shared.saveImage(
            image,
            recipeId: id
        )
        self.imageFileName = fileName
        self.lastModified = Date()
    }

    /// Delete the recipe's image from file system
    @MainActor
    func deleteImage() async {
        guard let fileName = imageFileName else { return }
        await ImageStorageService.shared.deleteImage(fileName: fileName)
        self.imageFileName = nil
        self.lastModified = Date()
    }
}

// MARK: - RecipeSourceType
enum RecipeSourceType: String, Codable, CaseIterable {
    case url = "url"
    case cookbook = "cookbook"
    case family = "family"
    case manual = "manual"

    var iconName: String {
        switch self {
        case .url: return "globe"
        case .cookbook: return "book.closed.fill"
        case .family: return "heart.fill"
        case .manual: return "square.and.pencil"
        }
    }

    var displayName: String {
        switch self {
        case .url: return "Website"
        case .cookbook: return "Cookbook"
        case .family: return "Family"
        case .manual: return "My Recipe"
        }
    }
}

// MARK: - Lightweight DTO
/// Lightweight data transfer object for recipe list views
/// Prevents loading all ingredients/instructions when scrolling
struct RecipeListItem: Identifiable {
    let id: UUID
    let title: String
    let imageFileName: String?
    let sourceType: RecipeSourceType
    let sourceDisplayName: String
    let isFavorite: Bool
    let timesCooked: Int
    let dateAdded: Date
}

// MARK: - Sample Data
extension Recipe {
    static var example: Recipe {
        let recipe = Recipe(
            title: "Grandma's Chocolate Chip Cookies",
            sourceType: .family,
            instructions: [
                "Preheat oven to 375°F",
                "Cream together butter and sugars",
                "Beat in eggs and vanilla",
                "Gradually blend in dry ingredients",
                "Stir in chocolate chips",
                "Drop by rounded tablespoon onto ungreased cookie sheets",
                "Bake for 9 to 11 minutes or until golden brown"
            ],
            servings: "48 cookies",
            prepTime: "15 min",
            cookTime: "11 min"
        )
        recipe.sourcePerson = "Grandma Rose"
        recipe.sourceDate = "1987"
        recipe.timesCooked = 12
        recipe.isFavorite = true

        return recipe
    }
}
