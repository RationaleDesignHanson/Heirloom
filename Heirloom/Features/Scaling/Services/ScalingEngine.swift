//
//  ScalingEngine.swift
//  Heirloom
//
//  Created for Smallify feature
//

import Foundation

// MARK: - Scaling Engine

/// Core engine for scaling recipes
class ScalingEngine {

    init() {}

    // MARK: - Public API

    /// Scale a recipe to a target serving size
    func scaleRecipe(
        _ recipe: Recipe,
        toServings targetServings: Int
    ) -> ScaledRecipe? {
        // Validate that scaling is allowed
        guard recipe.isScalingAllowed else {
            return nil
        }

        // Validate target servings are within range
        if let allowedRange = recipe.allowedServingRange,
           !allowedRange.contains(targetServings) {
            return nil
        }

        // Calculate scale factor
        let originalServings = recipe.parsedServingCount
        let scaleFactor = Double(targetServings) / Double(originalServings)

        // Scale all ingredients
        let scaledIngredients = scaleIngredients(
            recipe.ingredients ?? [],
            scaleFactor: scaleFactor,
            recipeCategory: recipe.category
        )

        // Generate warnings
        let warnings = generateWarnings(
            recipe: recipe,
            targetServings: targetServings,
            scaleFactor: scaleFactor
        )

        // Equipment suggestions
        let equipmentSuggestions = generateEquipmentSuggestions(
            recipe: recipe,
            scaleFactor: scaleFactor
        )

        // Adjust cooking time if needed
        let adjustedCookTime = adjustCookingTime(
            originalTime: recipe.cookTime,
            scaleFactor: scaleFactor,
            category: recipe.category
        )

        return ScaledRecipe(
            originalRecipe: recipe,
            targetServings: targetServings,
            scaleFactor: scaleFactor,
            scaledIngredients: scaledIngredients,
            warnings: warnings,
            equipmentSuggestions: equipmentSuggestions,
            adjustedCookTime: adjustedCookTime
        )
    }

    // MARK: - Ingredient Scaling

    private func scaleIngredients(
        _ ingredients: [Ingredient],
        scaleFactor: Double,
        recipeCategory: RecipeCategory?
    ) -> [ScaledIngredient] {
        ingredients.map { ingredient in
            scaleIngredient(ingredient, scaleFactor: scaleFactor, recipeCategory: recipeCategory)
        }
    }

    private func scaleIngredient(
        _ ingredient: Ingredient,
        scaleFactor: Double,
        recipeCategory: RecipeCategory?
    ) -> ScaledIngredient {
        guard let originalQuantity = ingredient.quantity else {
            // No quantity to scale (e.g., "salt to taste")
            return ScaledIngredient(
                originalIngredient: ingredient,
                scaledQuantity: nil,
                notes: "Adjust to taste"
            )
        }

        // Detect ingredient type for non-linear scaling
        let adjustmentType = detectIngredientType(ingredient)
        let adjustedScaleFactor = calculateAdjustedScaleFactor(
            baseFactor: scaleFactor,
            adjustmentType: adjustmentType
        )

        // Apply scaling
        var scaledQty = originalQuantity * adjustedScaleFactor
        var scaledQtyMax: Double?

        if let originalMax = ingredient.quantityMax {
            scaledQtyMax = originalMax * adjustedScaleFactor
        }

        // Round to practical measurements
        scaledQty = roundToPracticalMeasurement(scaledQty, unit: ingredient.unit)
        if let max = scaledQtyMax {
            scaledQtyMax = roundToPracticalMeasurement(max, unit: ingredient.unit)
        }

        let wasAdjusted = abs(adjustedScaleFactor - scaleFactor) > 0.01
        let adjustmentReason = wasAdjusted ? adjustmentType.displayName : nil

        return ScaledIngredient(
            originalIngredient: ingredient,
            scaledQuantity: scaledQty,
            scaledQuantityMax: scaledQtyMax,
            wasAdjusted: wasAdjusted,
            adjustmentReason: adjustmentReason
        )
    }

    // MARK: - Ingredient Type Detection

    private func detectIngredientType(_ ingredient: Ingredient) -> ScalingAdjustmentType {
        let name = ingredient.name.lowercased()

        // Spices (scale less when scaling up)
        let spiceKeywords = ["cinnamon", "nutmeg", "ginger", "cloves", "cardamom",
                            "cumin", "coriander", "paprika", "cayenne", "turmeric",
                            "oregano", "basil", "thyme", "rosemary", "sage", "vanilla"]
        if spiceKeywords.contains(where: name.contains) {
            return .spices
        }

        // Leavening agents
        let leaveningKeywords = ["baking powder", "baking soda", "yeast"]
        if leaveningKeywords.contains(where: name.contains) {
            return .leavening
        }

        // Liquids (adjust for evaporation when scaling up)
        let liquidKeywords = ["water", "milk", "broth", "stock", "juice", "wine", "beer"]
        if liquidKeywords.contains(where: name.contains) {
            return .liquids
        }

        // Eggs (should round to whole numbers)
        if name.contains("egg") {
            return .eggs
        }

        // Seasonings (salt, pepper)
        if name.contains("salt") || name.contains("pepper") {
            return .seasoning
        }

        // Default: bulk ingredients (flour, sugar, etc.)
        return .bulkIngredient
    }

    private func calculateAdjustedScaleFactor(
        baseFactor: Double,
        adjustmentType: ScalingAdjustmentType
    ) -> Double {
        // Apply non-linear scaling for all scale factors
        // This provides more accurate scaling for ingredients like spices, eggs, etc.
        if baseFactor > 1.0 {
            // Scaling up
            return baseFactor * adjustmentType.multiplier.up
        } else if baseFactor < 1.0 {
            // Scaling down
            return baseFactor * adjustmentType.multiplier.down
        } else {
            // Exactly 1x, no adjustment needed
            return baseFactor
        }
    }

    // MARK: - Rounding & Formatting

    private func roundToPracticalMeasurement(_ value: Double, unit: String?) -> Double {
        guard let unit = unit?.lowercased() else { return value }

        // Round based on unit type
        // Use 2 decimal places for small measurements to avoid over-rounding scaled values
        if unit.contains("tsp") || unit.contains("teaspoon") {
            // Round to 2 decimal places
            return round(value * 100) / 100
        } else if unit.contains("tbsp") || unit.contains("tablespoon") {
            // Round to 2 decimal places
            return round(value * 100) / 100
        } else if unit.contains("cup") {
            // Round to nearest 1/8 cup
            return round(value * 8) / 8
        } else if unit.contains("oz") || unit.contains("ounce") {
            // Round to nearest 0.5 oz
            return round(value * 2) / 2
        } else if unit.contains("lb") || unit.contains("pound") {
            // Round to nearest 0.25 lb
            return round(value * 4) / 4
        } else if unit.contains("g") || unit.contains("gram") {
            // Round to nearest 5g
            return round(value / 5) * 5
        } else {
            // Default: round to 2 decimal places
            return round(value * 100) / 100
        }
    }

    // MARK: - Warnings

    private func generateWarnings(
        recipe: Recipe,
        targetServings: Int,
        scaleFactor: Double
    ) -> [ScalingWarning] {
        var warnings: [ScalingWarning] = []

        // Check if approaching recipe-specific or category minimum
        let effectiveMinimum = recipe.minimumServings
        if targetServings <= effectiveMinimum {
            // Use category warning if available, otherwise generic
            let warningMessage = recipe.category?.minimumWarning ??
                "Scaling to \(targetServings) servings may affect recipe quality"
            warnings.append(ScalingWarning(
                type: .categoryLimit,
                message: warningMessage,
                iconName: "exclamationmark.triangle.fill",
                severity: .caution
            ))
        }

        // Check if scaling factor is extreme
        if scaleFactor < 0.5 {
            warnings.append(ScalingWarning(
                type: .scalingFloor,
                message: "Scaling below 50% may affect ingredient precision",
                iconName: "arrow.down.circle.fill",
                severity: .caution
            ))
        } else if scaleFactor > 3.0 {
            warnings.append(ScalingWarning(
                type: .scalingCeiling,
                message: "Large batch scaling may require equipment adjustments",
                iconName: "arrow.up.circle.fill",
                severity: .info
            ))
        }

        return warnings
    }

    // MARK: - Equipment Suggestions

    private func generateEquipmentSuggestions(
        recipe: Recipe,
        scaleFactor: Double
    ) -> [String]? {
        var suggestions: [String] = []

        // Pan size recommendations (category-specific)
        if let category = recipe.category {
            if category == .layerCake || category == .pie {
                if scaleFactor < 0.75 {
                    suggestions.append("Use a smaller pan (6\" recommended)")
                } else if scaleFactor > 1.5 {
                    suggestions.append("Use a larger pan or divide into multiple pans")
                }
            }
        }

        // Mixing bowl recommendations (applies to all recipes)
        if scaleFactor > 2.0 {
            suggestions.append("Use a larger mixing bowl for better mixing")
        }

        return suggestions.isEmpty ? nil : suggestions
    }

    // MARK: - Time Adjustments

    private func adjustCookingTime(
        originalTime: String?,
        scaleFactor: Double,
        category: RecipeCategory?
    ) -> String? {
        // For MVP, only adjust baking times slightly
        // Most cooking times don't scale linearly

        guard let originalTime = originalTime,
              let category = category else {
            return nil
        }

        // Only adjust baking times
        if category == .cookies || category == .muffins || category == .quickBread {
            // Baking times change slightly with size
            if scaleFactor <= 0.75 {
                return "\(originalTime) (reduce by 2-3 minutes)"
            } else if scaleFactor >= 1.5 {
                return "\(originalTime) (add 3-5 minutes)"
            }
        }

        return nil // No adjustment needed
    }
}
