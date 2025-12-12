import Foundation
import SwiftData

@Model
final class DinnerParty {
    var id: UUID = UUID()
    var name: String = ""
    var desc: String?
    var guestCount: Int = 4
    var mealTime: Date = Date()
    var createdDate: Date = Date()
    var lastModified: Date = Date()
    var isActive: Bool = false

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \DinnerPartyRecipe.dinnerParty)
    var recipes: [DinnerPartyRecipe]?

    init(
        name: String,
        description: String? = nil,
        guestCount: Int = 4,
        mealTime: Date
    ) {
        self.id = UUID()
        self.name = name
        self.desc = description
        self.guestCount = guestCount
        self.mealTime = mealTime
        self.createdDate = Date()
        self.lastModified = Date()
        self.isActive = false
        self.recipes = []
    }

    // MARK: - Computed Properties

    var recipeCount: Int {
        recipes?.count ?? 0
    }

    var totalPrepTime: Int {
        guard let recipes = recipes else { return 0 }
        return recipes.compactMap { $0.recipe?.parsedPrepTime }.reduce(0, +)
    }

    var totalCookTime: Int {
        guard let recipes = recipes else { return 0 }
        return recipes.compactMap { $0.recipe?.parsedCookTime }.reduce(0, +)
    }

    var earliestStartTime: Date? {
        guard let recipes = recipes, !recipes.isEmpty else { return nil }
        let sortedRecipes = recipes.sorted { $0.startTimeOffset > $1.startTimeOffset }
        guard let first = sortedRecipes.first else { return nil }
        return mealTime.addingTimeInterval(-Double(first.startTimeOffset * 60))
    }

    var isUpcoming: Bool {
        guard let startTime = earliestStartTime else { return false }
        return startTime > Date()
    }

    var isInProgress: Bool {
        guard let startTime = earliestStartTime else { return false }
        return startTime <= Date() && mealTime > Date()
    }

    var isPast: Bool {
        mealTime < Date()
    }
}

extension DinnerParty {
    var displayTimeStatus: String {
        if isInProgress {
            return "In Progress"
        } else if isUpcoming {
            let timeUntil = earliestStartTime!.timeIntervalSinceNow
            let hours = Int(timeUntil / 3600)
            let minutes = Int((timeUntil.truncatingRemainder(dividingBy: 3600)) / 60)

            if hours > 0 {
                return "Starts in \(hours)h \(minutes)m"
            } else {
                return "Starts in \(minutes)m"
            }
        } else if isPast {
            return "Completed"
        } else {
            return "Not started"
        }
    }
}

// MARK: - DinnerPartyRecipe Junction Model

@Model
final class DinnerPartyRecipe {
    var id: UUID = UUID()
    var startTimeOffset: Int = 0 // Minutes before meal time to start this recipe
    var scalingFactor: Double = 1.0 // Multiplier for ingredient quantities
    var notes: String?
    var isCompleted: Bool = false
    var dinnerParty: DinnerParty?

    @Relationship(inverse: \Recipe.dinnerPartyRecipes)
    var recipe: Recipe?

    init(
        recipe: Recipe,
        startTimeOffset: Int,
        scalingFactor: Double = 1.0
    ) {
        self.id = UUID()
        self.recipe = recipe
        self.startTimeOffset = startTimeOffset
        self.scalingFactor = scalingFactor
        self.notes = nil
        self.isCompleted = false
    }

    var startTime: Date? {
        guard let dinnerParty = dinnerParty else { return nil }
        return dinnerParty.mealTime.addingTimeInterval(-Double(startTimeOffset * 60))
    }

    var shouldStartNow: Bool {
        guard let startTime = startTime else { return false }
        return startTime <= Date() && !isCompleted
    }

    var timeUntilStart: TimeInterval? {
        guard let startTime = startTime else { return nil }
        return startTime.timeIntervalSinceNow
    }
}
