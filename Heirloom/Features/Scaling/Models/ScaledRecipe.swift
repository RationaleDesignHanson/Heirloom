//
//  ScaledRecipe.swift
//  Heirloom
//
//  Created for Smallify feature
//

import Foundation

// MARK: - Scaled Recipe Result

/// Result of scaling a recipe to a new serving size
struct ScaledRecipe {
    let originalRecipe: Recipe
    let targetServings: Int
    let scaleFactor: Double
    let scaledIngredients: [ScaledIngredient]
    let warnings: [ScalingWarning]
    let equipmentSuggestions: [String]?

    /// Adjusted cooking time (if applicable)
    let adjustedCookTime: String?

    /// Whether this scale is within recommended bounds
    var isWithinRecommendedRange: Bool {
        warnings.filter { $0.severity == .warning }.isEmpty
    }
}

// MARK: - Scaled Ingredient

/// An ingredient with scaled quantities
struct ScaledIngredient: Identifiable {
    let id: UUID
    let originalIngredient: Ingredient
    let scaledQuantity: Double?
    let scaledQuantityMax: Double?
    let displayQuantity: String // Formatted with fractions
    let notes: String? // e.g., "rounded up for practicality"

    /// Whether this ingredient was adjusted non-linearly
    let wasAdjusted: Bool
    let adjustmentReason: String?

    init(
        originalIngredient: Ingredient,
        scaledQuantity: Double?,
        scaledQuantityMax: Double? = nil,
        wasAdjusted: Bool = false,
        adjustmentReason: String? = nil,
        notes: String? = nil
    ) {
        self.id = originalIngredient.id
        self.originalIngredient = originalIngredient
        self.scaledQuantity = scaledQuantity
        self.scaledQuantityMax = scaledQuantityMax
        self.wasAdjusted = wasAdjusted
        self.adjustmentReason = adjustmentReason
        self.notes = notes

        // Format the display quantity using IngredientFormatter
        if let qty = scaledQuantity {
            let formatter = ServiceContainer.sharedUnsafe.resolveUnsafe(IngredientFormatter.self)
            let qtyStr = formatter.formatQuantity(qty, unit: originalIngredient.unit)
            if let maxQty = scaledQuantityMax {
                let maxStr = formatter.formatQuantity(maxQty, unit: originalIngredient.unit)
                self.displayQuantity = "\(qtyStr)-\(maxStr)"
            } else {
                self.displayQuantity = qtyStr
            }
        } else {
            self.displayQuantity = ""
        }
    }


    /// Full display string: "2 ½ cups flour"
    var fullDisplayString: String {
        var parts: [String] = []

        if !displayQuantity.isEmpty {
            parts.append(displayQuantity)
        }

        if let unit = originalIngredient.unit, !unit.isEmpty {
            parts.append(unit)
        }

        parts.append(originalIngredient.name)

        if let prep = originalIngredient.preparation, !prep.isEmpty {
            parts.append("(\(prep))")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Scaling Adjustment Type

/// Types of non-linear scaling adjustments
enum ScalingAdjustmentType {
    case spices        // 0.66x multiplier when scaling up
    case leavening     // 0.75x multiplier when scaling up
    case liquids       // Reduce by 10% when scaling up (evaporation)
    case eggs          // Round to nearest whole egg
    case bulkIngredient // Main ingredients like flour, sugar
    case seasoning     // Salt, pepper

    var multiplier: (up: Double, down: Double) {
        switch self {
        case .spices:
            return (up: 0.66, down: 1.0) // Scale spices less when going up
        case .leavening:
            return (up: 0.75, down: 1.0) // Scale leavening less when going up
        case .liquids:
            return (up: 0.9, down: 1.0) // Reduce liquids slightly when scaling up
        case .eggs, .bulkIngredient, .seasoning:
            return (up: 1.0, down: 1.0) // Linear scaling
        }
    }

    var displayName: String {
        switch self {
        case .spices: return "Spices"
        case .leavening: return "Leavening"
        case .liquids: return "Liquids"
        case .eggs: return "Eggs"
        case .bulkIngredient: return "Bulk Ingredients"
        case .seasoning: return "Seasoning"
        }
    }
}
