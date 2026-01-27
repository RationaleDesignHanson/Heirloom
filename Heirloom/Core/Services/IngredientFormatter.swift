//
//  IngredientFormatter.swift
//  Heirloom
//
//  Centralized service for formatting ingredients with unit conversion support
//

import Foundation
import SwiftUI

/// Service for formatting ingredients with scaling and unit conversion
@MainActor
final class IngredientFormatter {

    // MARK: - Dependencies

    private let unitsConfig: UnitsConfiguration

    // MARK: - Initialization

    init(unitsConfig: UnitsConfiguration) {
        self.unitsConfig = unitsConfig
    }

    // MARK: - Main Formatting Method

    /// Format an ingredient with optional scaling and unit conversion
    /// - Parameters:
    ///   - ingredient: The ingredient to format
    ///   - scaleFactor: Multiplication factor for quantities (default: 1.0)
    ///   - convertUnits: Whether to apply unit conversion based on user preference (default: true)
    /// - Returns: Formatted ingredient string
    func format(
        _ ingredient: Ingredient,
        scaleFactor: Double = 1.0,
        convertUnits: Bool = true
    ) -> String {
        // Fallback to originalText if name is empty
        if ingredient.name.isEmpty && !ingredient.originalText.isEmpty {
            return ingredient.originalText
        }

        var parts: [String] = []

        // Format quantity with optional conversion
        if let qty = ingredient.quantity {
            let scaledQty = qty * scaleFactor
            let (formattedQty, formattedUnit) = formatQuantityWithUnit(
                quantity: scaledQty,
                unit: ingredient.unit,
                convertUnits: convertUnits
            )

            parts.append(formattedQty)

            // Handle range (quantityMax)
            if let qtyMax = ingredient.quantityMax {
                let scaledMax = qtyMax * scaleFactor
                let (formattedMax, _) = formatQuantityWithUnit(
                    quantity: scaledMax,
                    unit: ingredient.unit,
                    convertUnits: convertUnits
                )
                parts.append("-\(formattedMax)")
            }

            // Add unit
            if let unit = formattedUnit {
                parts.append(unit)
            }
        }

        // Add name
        parts.append(ingredient.name)

        // Add preparation
        if let prep = ingredient.preparation {
            parts.append("(\(prep))")
        }

        // Add optional flag
        if ingredient.isOptional {
            parts.append("(optional)")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Quantity Formatting with Conversion

    /// Format a quantity with its unit, applying conversion if needed
    /// - Parameters:
    ///   - quantity: The numeric quantity
    ///   - unit: The unit string (may be nil)
    ///   - convertUnits: Whether to apply unit conversion
    /// - Returns: Tuple of (formatted quantity, formatted unit)
    private func formatQuantityWithUnit(
        quantity: Double,
        unit: String?,
        convertUnits: Bool
    ) -> (String, String?) {
        // Try to convert if enabled and unit exists
        if convertUnits, let unit = unit {
            if let converted = MeasurementConversionService.convert(
                quantity: quantity,
                unit: unit,
                to: unitsConfig.preferredSystem
            ) {
                // Conversion successful - use converted values
                let formattedQty = formatQuantity(converted.quantity, unit: converted.unit)
                return (formattedQty, converted.unit)
            }
        }

        // No conversion needed or possible - use original values
        let formattedQty = formatQuantity(quantity, unit: unit)
        return (formattedQty, unit)
    }

    /// Format a quantity value based on the unit type
    /// - Parameters:
    ///   - value: The numeric value to format
    ///   - unit: The unit string (determines fraction vs decimal formatting)
    /// - Returns: Formatted quantity string
    func formatQuantity(_ value: Double, unit: String? = nil) -> String {
        // Handle zero or very small values
        if value < 0.05 {
            return ""
        }

        // Determine if this is a metric unit (use decimals) or imperial (use fractions)
        let isMetric = MeasurementConversionService.isMetricUnit(unit)

        if isMetric {
            // Metric: round to whole numbers (no decimals for ml, g, etc.)
            let rounded = round(value)
            return "\(Int(rounded))"
        } else {
            // Imperial: use practical fractions only
            return formatImperialFraction(value)
        }
    }

    /// Format a value using imperial fractions
    private func formatImperialFraction(_ value: Double) -> String {
        let practicalFractions: [(Double, String)] = [
            (0.125, "⅛"),  // 1/8
            (0.25, "¼"),   // 1/4
            (0.333, "⅓"),  // 1/3
            (0.5, "½"),    // 1/2
            (0.667, "⅔"),  // 2/3
            (0.75, "¾")    // 3/4
        ]

        let whole = Int(value)
        let fraction = value - Double(whole)

        // If it's essentially a whole number
        if fraction < 0.05 {
            return "\(whole)"
        }

        // Try to match practical fractions (within 0.05 tolerance)
        for (threshold, symbol) in practicalFractions {
            if abs(fraction - threshold) < 0.05 {
                return whole > 0 ? "\(whole) \(symbol)" : symbol
            }
        }

        // Fallback: use decimal notation if no practical fraction matches
        let rounded = round(value * 10) / 10
        if rounded == Double(Int(rounded)) {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
}
