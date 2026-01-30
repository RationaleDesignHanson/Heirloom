import Foundation
import SwiftData

/// AI-powered meal plan summary and planning service
/// Generates intelligent summaries, timeline recommendations, and coordination tips
@MainActor
class DinnerPartySummaryService: DinnerPartySummaryServiceProtocol {
    // MARK: - Dependencies

    private let aiService: AIServiceProtocol
    private let configuration: AIConfigurationProtocol
    private let analytics: AnalyticsService

    // MARK: - Initialization

    init(aiService: AIServiceProtocol, configuration: AIConfigurationProtocol, analytics: AnalyticsService) {
        self.aiService = aiService
        self.configuration = configuration
        self.analytics = analytics
    }

    // MARK: - Summary Models

    struct DinnerPartySummary: Codable {
        let overview: String              // High-level description of the meal
        let timeline: TimelineRecommendation
        let preparationTips: [String]     // Key prep advice
        let coordination: CoordinationAdvice
        let servingOrder: [String]        // Suggested order to serve dishes
    }

    struct TimelineRecommendation: Codable {
        let startTime: String             // When to start cooking (e.g., "2 hours before")
        let criticalMoments: [String]     // Key timing points
        let parallelTasks: [ParallelTask] // Tasks that can be done simultaneously
    }

    struct ParallelTask: Codable {
        let timeSlot: String              // e.g., "30-45 minutes before serving"
        let tasks: [String]               // List of concurrent tasks
    }

    struct CoordinationAdvice: Codable {
        let bottlenecks: [String]         // Potential timing issues
        let makeAhead: [String]           // What can be prepared in advance
        let lastMinute: [String]          // What must be done last
    }

    // MARK: - Public API

    /// Generate comprehensive AI summary for a meal plan
    nonisolated func generateSummary(for party: DinnerParty, recipes: [Recipe]) async throws -> Any {
        return try await generateDinnerPartySummary(for: party, recipes: recipes)
    }

    private func generateDinnerPartySummary(for dinnerParty: DinnerParty, recipes: [Recipe]) async throws -> DinnerPartySummary {
        guard configuration.enableAIEnhancement,
              configuration.isConfigured(provider: .anthropic) else {
            // Return basic summary without AI
            return generateBasicSummary(for: dinnerParty)
        }

        // Build context about the meal plan
        let context = buildDinnerPartyContext(dinnerParty)

        let prompt = """
        Analyze this meal plan and provide a comprehensive planning summary.

        Meal Plan Details:
        \(context)

        Generate a JSON summary with:
        1. Overview: 2-3 sentence description of the meal and its character
        2. Timeline: When to start, critical moments, parallel tasks
        3. Preparation Tips: 3-5 key pieces of advice for successful execution
        4. Coordination: Bottlenecks, make-ahead items, last-minute tasks
        5. Serving Order: Recommended order to serve the dishes

        Return ONLY valid JSON in this format:
        {
          "overview": "A delightful Italian-inspired meal featuring...",
          "timeline": {
            "startTime": "2 hours before serving",
            "criticalMoments": [
              "Start roasting chicken at 5:00 PM",
              "Begin pasta water at 6:30 PM"
            ],
            "parallelTasks": [
              {
                "timeSlot": "5:00-5:30 PM",
                "tasks": ["Prep vegetables", "Make sauce", "Set table"]
              }
            ]
          },
          "preparationTips": [
            "Marinate chicken night before for best flavor",
            "Have all ingredients prepped before starting"
          ],
          "coordination": {
            "bottlenecks": ["Oven space - only one dish can roast at a time"],
            "makeAhead": ["Dessert", "Salad dressing", "Sauce base"],
            "lastMinute": ["Toss salad", "Boil pasta", "Slice bread"]
          },
          "servingOrder": ["Appetizer", "Salad", "Main Course", "Dessert"]
        }

        Be specific, practical, and considerate of timing constraints.
        """

        let model = configuration.model(for: .enhancement)

        let summary = try await aiService.completeStructured(
            prompt: prompt,
            schema: DinnerPartySummary.self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.5, // Balanced creativity and consistency
                maxTokens: 2000,
                systemMessage: "You are an expert chef and event planner. Provide practical, actionable advice."
            )
        )

        // Track success
        analytics.track(event: .aiEnhancementSuccess, properties: [
            "source": "dinner_party_summary",
            "recipe_count": dinnerParty.recipeCount,
            "guest_count": dinnerParty.guestCount
        ])

        return summary
    }

    // MARK: - Private Helpers

    private func buildDinnerPartyContext(_ dinnerParty: DinnerParty) -> String {
        var context = """
        Name: \(dinnerParty.name)
        Guest Count: \(dinnerParty.guestCount)
        Meal Time: \(formatDate(dinnerParty.mealTime))
        """

        if let description = dinnerParty.desc, !description.isEmpty {
            context += "\nDescription: \(description)"
        }

        guard let recipes = dinnerParty.recipes, !recipes.isEmpty else {
            return context
        }

        context += "\n\nRecipes:"
        for (index, dpRecipe) in recipes.enumerated() {
            guard let recipe = dpRecipe.recipe else { continue }

            context += "\n\n\(index + 1). \(recipe.title)"
            if let servings = recipe.servings {
                context += " (serves \(servings)"
                if dpRecipe.scalingFactor != 1.0 {
                    context += ", scaled \(formatScaling(dpRecipe.scalingFactor))x"
                }
                context += ")"
            }

            if let prepTime = recipe.prepTime, !prepTime.isEmpty {
                context += "\n   Prep: \(prepTime)"
            }
            if let cookTime = recipe.cookTime, !cookTime.isEmpty {
                context += "\n   Cook: \(cookTime)"
            }

            context += "\n   Start: \(formatStartTime(dpRecipe.startTimeOffset)) minutes before serving"

            // Include key ingredients
            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                let keyIngredients = ingredients.prefix(5).map { $0.name }
                context += "\n   Key ingredients: \(keyIngredients.joined(separator: ", "))"
            }
        }

        return context
    }

    private func generateBasicSummary(for dinnerParty: DinnerParty) -> DinnerPartySummary {
        let recipeCount = dinnerParty.recipeCount
        let guestCount = dinnerParty.guestCount

        let overview = "A meal for \(guestCount) guests featuring \(recipeCount) dish\(recipeCount == 1 ? "" : "es")."

        let totalTime = dinnerParty.totalPrepTime + dinnerParty.totalCookTime
        let startTime = totalTime > 0 ? "Start cooking \(totalTime) minutes before serving" : "Start cooking 1 hour before serving"

        return DinnerPartySummary(
            overview: overview,
            timeline: TimelineRecommendation(
                startTime: startTime,
                criticalMoments: ["Begin cooking at the planned time"],
                parallelTasks: []
            ),
            preparationTips: [
                "Read all recipes before starting",
                "Prep ingredients in advance",
                "Set the table early to reduce last-minute stress"
            ],
            coordination: CoordinationAdvice(
                bottlenecks: [],
                makeAhead: ["Dessert", "Table setting"],
                lastMinute: ["Final plating", "Heating dishes"]
            ),
            servingOrder: dinnerParty.recipes?.compactMap { $0.recipe?.title } ?? []
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatStartTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        } else {
            return "\(minutes)"
        }
    }

    private func formatScaling(_ factor: Double) -> String {
        if factor == floor(factor) {
            return String(format: "%.0f", factor)
        } else {
            return String(format: "%.1f", factor)
        }
    }
}
