import Foundation
import SwiftData

/// AI-powered shopping list summary and optimization service
/// Generates intelligent summaries, store routing, and budget estimates
@MainActor
class ShoppingListSummaryService: ShoppingListSummaryServiceProtocol {
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

    struct ShoppingListSummary: Codable {
        let overview: String                  // High-level description
        let storeRouting: StoreRoutingPlan    // Optimal path through store
        let budgetEstimate: BudgetEstimate    // Cost estimation
        let tips: [String]                    // Shopping tips
        let substitutions: [Substitution]     // Suggested alternatives
    }

    struct StoreRoutingPlan: Codable {
        let sections: [StoreSection]          // Organized by store section
        let estimatedTime: String             // Total shopping time
    }

    struct StoreSection: Codable {
        let name: String                      // e.g., "Produce", "Dairy"
        let items: [String]                   // Items in this section
        let tip: String?                      // Section-specific tip
    }

    struct BudgetEstimate: Codable {
        let estimatedTotal: String            // e.g., "$45-60"
        let breakdown: [CategoryCost]         // Cost by category
        let savingsTips: [String]             // Ways to save money
    }

    struct CategoryCost: Codable {
        let category: String
        let estimatedCost: String
    }

    struct Substitution: Codable {
        let original: String
        let alternative: String
        let reason: String                    // Why substitute
    }

    // MARK: - Public API

    /// Generate comprehensive AI summary for shopping list
    nonisolated func generateSummary(for ingredients: [Ingredient], recipes: [Recipe]) async throws -> Any {
        // Convert to internal format for now
        return try await generateShoppingListSummary(ingredients: ingredients, recipes: recipes)
    }

    private func generateShoppingListSummary(ingredients: [Ingredient], recipes: [Recipe]) async throws -> ShoppingListSummary {
        guard configuration.enableAIEnhancement,
              configuration.isConfigured(provider: .anthropic) else {
            // Return basic summary without AI
            return generateBasicSummary(ingredients: ingredients, recipes: recipes)
        }

        let context = buildShoppingContext(ingredients: ingredients, recipes: recipes)

        let prompt = """
        Analyze this shopping list and provide a comprehensive shopping plan.

        Shopping List:
        \(context)

        Generate:
        1. Overview: Brief description of what type of shopping trip this is
        2. Store Routing: Group items by typical grocery store sections in optimal order
        3. Budget Estimate: Rough cost estimate with breakdown by category
        4. Tips: 3-5 practical shopping tips for this specific list
        5. Substitutions: Suggest 2-3 possible substitutions if items aren't available

        Return ONLY valid JSON:
        {
          "overview": "A mid-size grocery trip focused on fresh produce and proteins for home cooking",
          "storeRouting": {
            "sections": [
              {
                "name": "Produce",
                "items": ["Tomatoes", "Lettuce", "Onions"],
                "tip": "Check for seasonal sales on vegetables"
              },
              {
                "name": "Meat & Seafood",
                "items": ["Chicken breasts", "Salmon"],
                "tip": null
              }
            ],
            "estimatedTime": "25-30 minutes"
          },
          "budgetEstimate": {
            "estimatedTotal": "$45-60",
            "breakdown": [
              {"category": "Produce", "estimatedCost": "$12-15"},
              {"category": "Meat & Seafood", "estimatedCost": "$20-30"}
            ],
            "savingsTips": [
              "Buy store-brand pasta for 30% savings",
              "Check for manager's specials on proteins"
            ]
          },
          "tips": [
            "Shop produce first for best selection",
            "Pick up frozen items last to keep them cold"
          ],
          "substitutions": [
            {
              "original": "Fresh basil",
              "alternative": "Dried basil (use 1/3 the amount)",
              "reason": "Fresh herbs may not be available"
            }
          ]
        }

        Typical grocery store section order: Produce → Bakery → Deli → Meat/Seafood → Dairy → Frozen → Pantry/Dry Goods → Beverages

        Be practical and specific. Consider typical US grocery store layouts and prices.
        """

        let model = configuration.model(for: .enhancement)

        let summary = try await aiService.completeStructured(
            prompt: prompt,
            schema: ShoppingListSummary.self,
            options: AICompletionOptions(
                model: model,
                temperature: 0.5,
                maxTokens: 2000,
                systemMessage: "You are a grocery shopping expert who helps people shop efficiently and economically."
            )
        )

        // Track success
        analytics.track(event: .aiEnhancementSuccess, properties: [
            "source": "shopping_list_summary",
            "item_count": ingredients.count
        ])

        return summary
    }

    // MARK: - Private Helpers

    private func buildShoppingContext(ingredients: [Ingredient], recipes: [Recipe]) -> String {
        var context = "Total Items: \(ingredients.count)\n\n"
        context += "Recipes: \(recipes.map { $0.title }.joined(separator: ", "))\n\n"

        context += "Ingredients:\n"
        for ingredient in ingredients {
            context += "  - \(ingredient.originalText)\n"
        }

        return context
    }

    private func generateBasicSummary(ingredients: [Ingredient], recipes: [Recipe]) -> ShoppingListSummary {
        let itemCount = ingredients.count

        // Simple placeholder section
        let sections = [
            StoreSection(
                name: "Shopping List",
                items: ingredients.map { $0.name },
                tip: nil
            )
        ]

        let overview = "A shopping list with \(itemCount) item\(itemCount == 1 ? "" : "s") for \(recipes.count) recipe\(recipes.count == 1 ? "" : "s")"

        let estimatedTime = itemCount < 10 ? "15-20 minutes" : itemCount < 25 ? "25-35 minutes" : "40-50 minutes"

        let estimatedTotal = itemCount < 10 ? "$20-35" : itemCount < 25 ? "$50-80" : "$90-130"

        return ShoppingListSummary(
            overview: overview,
            storeRouting: StoreRoutingPlan(
                sections: sections,
                estimatedTime: estimatedTime
            ),
            budgetEstimate: BudgetEstimate(
                estimatedTotal: estimatedTotal,
                breakdown: [],
                savingsTips: [
                    "Compare unit prices to find the best value",
                    "Check for store-brand alternatives"
                ]
            ),
            tips: [
                "Bring reusable bags",
                "Check for coupons before shopping",
                "Stick to your list to avoid impulse purchases"
            ],
            substitutions: []
        )
    }
}
