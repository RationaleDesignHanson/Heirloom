import Foundation
import SwiftData

@Model
final class RecipeGenerationJob {
    // MARK: - Identity
    var id: UUID
    var dishName: String
    var createdAt: Date
    var completedAt: Date?

    // MARK: - Input Data
    var ingredients: String?
    var transcript: String?
    var isSillyRecipe: Bool = false  // Easter egg flag
    var targetCollectionId: UUID?  // Target collection for routing (nil = use default "Generated Recipes")

    // MARK: - Status
    var status: RecipeGenerationStatus
    var currentPhase: RecipeGenerationPhase
    var error: String?

    // MARK: - Initialization
    init(dishName: String, ingredients: String? = nil, transcript: String? = nil, targetCollectionId: UUID? = nil) {
        self.id = UUID()
        self.dishName = dishName
        self.ingredients = ingredients
        self.transcript = transcript
        self.targetCollectionId = targetCollectionId
        self.status = .processing
        self.currentPhase = .analyzing
        self.createdAt = Date()
    }
}

// MARK: - RecipeGenerationStatus
enum RecipeGenerationStatus: String, Codable {
    case processing
    case completed
    case failed
}

// MARK: - RecipeGenerationPhase
enum RecipeGenerationPhase: String, Codable {
    case analyzing
    case extracting
    case enriching
    case complete

    var displayText: String {
        switch self {
        case .analyzing:
            return "Understanding your recipe..."
        case .extracting:
            return "Extracting ingredients..."
        case .enriching:
            return "Generating recipe image..."
        case .complete:
            return "Recipe generated!"
        }
    }

    var iconName: String {
        switch self {
        case .analyzing:
            return "brain"
        case .extracting:
            return "list.bullet.clipboard"
        case .enriching:
            return "sparkles"
        case .complete:
            return "checkmark.circle.fill"
        }
    }
}
