import Foundation
import SwiftData

/// AI-powered recipe timeline calculator for dinner party coordination
/// Calculates optimal start times and identifies timing conflicts
@MainActor
class RecipeTimelineCalculator {
    static let shared = RecipeTimelineCalculator()
    private init() {}

    // MARK: - Timeline Models

    struct TimelineAnalysis: Codable {
        let recommendations: [RecipeStartTime]
        let conflicts: [TimingConflict]
        let resourceConflicts: [ResourceConflict]
        let totalDuration: Int  // Minutes from first start to serving time
    }

    struct RecipeStartTime: Codable {
        let recipeTitle: String
        let startOffset: Int      // Minutes before serving time
        let reasoning: String     // Why this timing
        let dependencies: [String] // What must happen first
    }

    struct TimingConflict: Codable {
        let description: String
        let affectedRecipes: [String]
        let severity: String      // "high", "medium", "low"
        let suggestion: String
    }

    struct ResourceConflict: Codable {
        let resource: String      // e.g., "oven", "stovetop"
        let conflictingRecipes: [String]
        let timeWindow: String
        let resolution: String
    }

    // MARK: - Public API

    /// Calculate optimal timeline for dinner party recipes using AI
    func calculateTimeline(
        recipes: [DinnerPartyRecipe],
        servingTime: Date
    ) async throws -> TimelineAnalysis {
        guard AIConfiguration.shared.enableAIEnhancement,
              AIConfiguration.shared.isConfigured(provider: .anthropic) else {
            // Return basic timeline without AI
            return calculateBasicTimeline(recipes: recipes)
        }

        let context = buildRecipesContext(recipes)

        let prompt = """
        Analyze these recipes and calculate optimal start times for a coordinated dinner party.

        Recipes:
        \(context)

        Calculate:
        1. Optimal start time for each recipe (minutes before serving)
        2. Identify timing conflicts (e.g., oven space, stovetop burners)
        3. Identify resource conflicts (equipment overlaps)
        4. Provide practical suggestions to resolve conflicts

        Consider:
        - Dishes should be ready simultaneously or in proper serving order
        - Account for prep time, cook time, and rest time
        - Identify parallel tasks vs. sequential requirements
        - Flag resource bottlenecks (oven, stovetop, mixing bowls)

        Return ONLY valid JSON:
        {
          "recommendations": [
            {
              "recipeTitle": "Roasted Chicken",
              "startOffset": 90,
              "reasoning": "Requires 75 min roasting + 15 min prep",
              "dependencies": ["Preheat oven"]
            }
          ],
          "conflicts": [
            {
              "description": "Both dishes need oven at 400°F",
              "affectedRecipes": ["Chicken", "Vegetables"],
              "severity": "high",
              "suggestion": "Roast vegetables first, then chicken, or use two racks"
            }
          ],
          "resourceConflicts": [
            {
              "resource": "oven",
              "conflictingRecipes": ["Chicken", "Bread"],
              "timeWindow": "30-45 minutes before serving",
              "resolution": "Bake bread first, keep warm while chicken roasts"
            }
          ],
          "totalDuration": 120
        }

        Be specific and practical. Focus on real-world kitchen constraints.
        """

        let service = AnthropicAIService.shared
        let model = AIConfiguration.shared.model(for: .enhancement)

        let analysis = try await service.completeStructured(
            prompt: prompt,
            schema: TimelineAnalysis.self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.4, // More deterministic for timeline calculations
                maxTokens: 2000,
                systemMessage: "You are an expert chef specializing in dinner party coordination and timing."
            )
        )

        // Track success
        AnalyticsService.shared.track(event: .aiEnhancementSuccess, properties: [
            "source": "recipe_timeline",
            "recipe_count": recipes.count
        ])

        return analysis
    }

    // MARK: - Private Helpers

    private func buildRecipesContext(_ recipes: [DinnerPartyRecipe]) -> String {
        var context = ""

        for (index, dpRecipe) in recipes.enumerated() {
            guard let recipe = dpRecipe.recipe else { continue }

            context += "\n\n\(index + 1). \(recipe.title)"

            if let servings = recipe.servings {
                context += " (serves \(servings))"
            }

            // Timing info
            if let prepTime = recipe.prepTime, !prepTime.isEmpty {
                context += "\n   Prep Time: \(prepTime)"
            }
            if let cookTime = recipe.cookTime, !cookTime.isEmpty {
                context += "\n   Cook Time: \(cookTime)"
            }

            // Instructions (abbreviated for context)
            if let instructions = recipe.instructions, !instructions.isEmpty {
                context += "\n   Method: "
                let firstInstruction = instructions.prefix(2).joined(separator: " ")
                let abbreviated = String(firstInstruction.prefix(150))
                context += abbreviated + (firstInstruction.count > 150 ? "..." : "")
            }

            // Equipment hints from instructions
            if let instructions = recipe.instructions {
                let fullText = instructions.joined(separator: " ").lowercased()
                var equipment: [String] = []

                if fullText.contains("oven") || fullText.contains("bake") || fullText.contains("roast") {
                    equipment.append("oven")
                }
                if fullText.contains("stovetop") || fullText.contains("boil") || fullText.contains("sauté") {
                    equipment.append("stovetop")
                }
                if fullText.contains("grill") {
                    equipment.append("grill")
                }
                if fullText.contains("microwave") {
                    equipment.append("microwave")
                }

                if !equipment.isEmpty {
                    context += "\n   Equipment: \(equipment.joined(separator: ", "))"
                }
            }

            // Current start time if set
            if dpRecipe.startTimeOffset > 0 {
                context += "\n   Current scheduled start: \(dpRecipe.startTimeOffset) minutes before serving"
            }
        }

        return context
    }

    private func calculateBasicTimeline(recipes: [DinnerPartyRecipe]) -> TimelineAnalysis {
        var recommendations: [RecipeStartTime] = []

        for dpRecipe in recipes {
            guard let recipe = dpRecipe.recipe else { continue }

            let prepTime = recipe.parsedPrepTime ?? 0
            let cookTime = recipe.parsedCookTime ?? 0
            let totalTime = prepTime + cookTime

            let startOffset = max(totalTime, 30) // At least 30 minutes

            recommendations.append(RecipeStartTime(
                recipeTitle: recipe.title,
                startOffset: startOffset,
                reasoning: "Based on prep time (\(prepTime) min) and cook time (\(cookTime) min)",
                dependencies: []
            ))
        }

        let maxDuration = recommendations.map { $0.startOffset }.max() ?? 60

        return TimelineAnalysis(
            recommendations: recommendations,
            conflicts: [],
            resourceConflicts: [],
            totalDuration: maxDuration
        )
    }
}
