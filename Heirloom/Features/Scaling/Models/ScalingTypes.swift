//
//  ScalingTypes.swift
//  Heirloom
//
//  Created for Smallify feature
//

import Foundation

// MARK: - Scalability Rating

/// Indicates how well a recipe handles scaling
enum ScalabilityRating: String, Codable {
    case locked        // Cannot be scaled (laminated doughs, emulsions)
    case easy          // Full range scaling (0.25x - 4x)
    case moderate      // Limited range, some warnings
    case hard          // Very limited range, many warnings

    var displayName: String {
        switch self {
        case .locked: return "Fixed"
        case .easy: return "Easy to scale"
        case .moderate: return "Moderate"
        case .hard: return "Difficult to scale"
        }
    }

    var iconName: String {
        switch self {
        case .locked: return "lock.fill"
        case .easy: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .hard: return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Recipe Category

/// Recipe categories with scaling-specific defaults
enum RecipeCategory: String, Codable, CaseIterable {
    // Easy scaling categories
    case soupStew = "Soup & Stew"
    case pasta = "Pasta"
    case stirFry = "Stir Fry"
    case casserole = "Casserole"
    case cookies = "Cookies"
    case muffins = "Muffins"
    case quickBread = "Quick Bread"

    // Moderate scaling categories
    case layerCake = "Layer Cake"
    case pie = "Pie"

    // Hard scaling categories
    case yeastBread = "Yeast Bread"

    // Locked categories (cannot scale)
    case laminated = "Laminated Dough"
    case emulsion = "Emulsion"
    case sourdough = "Sourdough"
    case candy = "Candy"

    // Generic
    case other = "Other"

    /// Default scalability rating for this category
    var defaultScalability: ScalabilityRating {
        switch self {
        case .soupStew, .pasta, .stirFry, .casserole:
            return .easy
        case .cookies, .muffins, .quickBread:
            return .easy
        case .layerCake, .pie:
            return .moderate
        case .yeastBread:
            return .hard
        case .laminated, .emulsion, .sourdough, .candy:
            return .locked
        case .other:
            return .easy
        }
    }

    /// Minimum recommended servings for this category
    var minimumServings: Int {
        switch self {
        case .soupStew, .pasta, .stirFry, .casserole:
            return 1
        case .cookies:
            return 4  // Below 4 cookies impractical
        case .muffins, .quickBread:
            return 2
        case .layerCake:
            return 6  // Minimum 6" pan
        case .pie:
            return 4  // Below 6" difficult
        case .yeastBread:
            return 4  // Minimum for proper kneading
        case .laminated, .emulsion, .sourdough, .candy:
            return Int.max  // Locked, no scaling
        case .other:
            return 1
        }
    }

    /// Warning message when approaching minimum
    var minimumWarning: String? {
        switch self {
        case .layerCake:
            return "Minimum 6\" pan recommended for best results"
        case .yeastBread:
            return "Minimum 4 rolls needed for proper kneading"
        case .pie:
            return "Crust ratio affects results below 6\" size"
        case .cookies:
            return "Below 4 cookies, measurements become imprecise"
        case .laminated:
            return "Butter layers require minimum batch size—cannot scale"
        case .emulsion:
            return "Requires minimum 1 egg yolk for emulsification—cannot scale"
        case .sourdough:
            return "Starter ratios are critical—use dedicated small-batch recipe"
        case .candy:
            return "Temperature and ratios are critical—cannot scale"
        default:
            return nil
        }
    }

    /// Smart preset serving sizes for this category
    /// Returns typical batch sizes that make sense for the category
    var presetServingSizes: [Int] {
        switch self {
        case .cookies:
            return [12, 24, 48, 96]
        case .muffins:
            return [6, 12, 18, 24]
        case .soupStew:
            return [2, 4, 6, 8]
        case .pasta:
            return [2, 4, 6, 8]
        case .stirFry:
            return [2, 4, 6, 8]
        case .casserole:
            return [4, 6, 8, 12]
        case .layerCake:
            return [6, 8, 12, 16]
        case .pie:
            return [6, 8, 10, 12]
        case .yeastBread:
            return [4, 6, 8, 12, 16]
        case .quickBread:
            return [6, 8, 12, 16]
        case .laminated, .emulsion, .sourdough, .candy:
            return []  // Locked categories return empty array
        case .other:
            return [2, 4, 6, 8, 12]
        }
    }
}

// MARK: - Scaling Warning

/// Warnings to display when scaling reaches problematic levels
struct ScalingWarning {
    enum WarningType {
        case categoryLimit
        case scalingFloor
        case scalingCeiling
        case equipmentSuggestion
        case ingredientMinimum
    }

    let type: WarningType
    let message: String
    let iconName: String
    let severity: Severity

    enum Severity {
        case info      // Blue
        case caution   // Yellow/Orange
        case warning   // Red
    }
}
