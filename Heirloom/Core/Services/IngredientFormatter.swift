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
            var processed = convertWordNumbers(ingredient.originalText)
            processed = expandUnitAbbreviationsInText(processed)
            if scaleFactor != 1.0 {
                return scaleEmbeddedQuantities(in: processed, scaleFactor: scaleFactor)
            }
            return processed
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

        // Add name (expand abbreviations first, then scale embedded quantities)
        let expandedName = expandUnitAbbreviationsInText(ingredient.name)
        if scaleFactor != 1.0 {
            parts.append(scaleEmbeddedQuantities(in: expandedName, scaleFactor: scaleFactor))
        } else {
            parts.append(expandedName)
        }

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
                let finalUnit = singularizeUnit(converted.unit, quantity: converted.quantity)
                return (formattedQty, finalUnit)
            }
        }

        // No conversion needed or possible - use original values
        let formattedQty = formatQuantity(quantity, unit: unit)
        let finalUnit = unit.map { singularizeUnit($0, quantity: quantity) }
        return (formattedQty, finalUnit)
    }

    /// Format a quantity value based on the unit type
    /// - Parameters:
    ///   - value: The numeric value to format
    ///   - unit: The unit string (determines fraction vs decimal formatting)
    /// - Returns: Formatted quantity string
    nonisolated func formatQuantity(_ value: Double, unit: String? = nil) -> String {
        // Handle zero or very small values
        if value < 0.05 {
            return ""
        }

        // Determine if this is a metric unit (use decimals) or imperial (use fractions)
        let isMetric = MeasurementConversionService.isMetricUnit(unit)

        if isMetric {
            // Metric: round to tenths place (e.g., 250.5 g, 100.2 ml)
            let rounded = round(value * 10) / 10
            if rounded == Double(Int(rounded)) {
                // Whole number - no decimal point
                return "\(Int(rounded))"
            }
            return String(format: "%.1f", rounded)
        } else {
            // Imperial: use practical fractions only
            return formatImperialFraction(value)
        }
    }

    /// Format a value using imperial fractions
    private nonisolated func formatImperialFraction(_ value: Double) -> String {
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

    /// Singularize a unit if the quantity is 1 or less
    /// - Parameters:
    ///   - unit: The unit string (e.g., "cups", "teaspoons")
    ///   - quantity: The quantity value
    /// - Returns: Singular or plural unit as appropriate
    private nonisolated func singularizeUnit(_ unit: String, quantity: Double) -> String {
        // First, expand common abbreviations to full unit names
        let expandedUnit = expandAbbreviation(unit)

        // Only singularize if quantity <= 1
        guard quantity <= 1.0 else {
            return expandedUnit
        }

        let lowerUnit = expandedUnit.lowercased()

        // Common plural → singular mappings
        let pluralMappings: [String: String] = [
            "cups": "cup",
            "teaspoons": "teaspoon",
            "tablespoons": "tablespoon",
            "ounces": "ounce",
            "pounds": "pound",
            "grams": "gram",
            "kilograms": "kilogram",
            "milliliters": "milliliter",
            "liters": "liter",
            "pints": "pint",
            "quarts": "quart",
            "gallons": "gallon",
            "cloves": "clove",
            "slices": "slice",
            "pieces": "piece",
            "sticks": "stick",
            "bunches": "bunch",
            "sprigs": "sprig",
            "leaves": "leaf",
            "stalks": "stalk",
            "heads": "head",
            "cans": "can",
            "packages": "package",
            "containers": "container",
            "jars": "jar",
            "bottles": "bottle",
            "pinches": "pinch",
            "dashes": "dash"
        ]

        // Check for exact match
        if let singular = pluralMappings[lowerUnit] {
            // Preserve original capitalization
            if unit.first?.isUppercase == true {
                return singular.prefix(1).uppercased() + singular.dropFirst()
            }
            return singular
        }

        // If not in our mapping, return as-is
        return expandedUnit
    }

    private nonisolated func expandAbbreviation(_ unit: String) -> String {
        unit.expandedUnitAbbreviation
    }

    // MARK: - Word Number Conversion

    /// Scale the leading number in text (e.g., "2 large eggs" × 2 → "4 large eggs")
    nonisolated func scaleLeadingNumber(in text: String, scaleFactor: Double) -> String {
        guard let regex = try? NSRegularExpression(pattern: "^(\\d+\\.?\\d*)(\\s+.+)?$", options: []) else {
            return text
        }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              let number = Double(nsText.substring(with: match.range(at: 1))) else {
            return text
        }
        let scaled = number * scaleFactor
        let formatted = formatQuantity(scaled)
        let rest = match.range(at: 2).location != NSNotFound ? nsText.substring(with: match.range(at: 2)) : ""
        return formatted + rest
    }

    /// Convert leading word numbers to digits (e.g., "Two large eggs" → "2 large eggs")
    nonisolated func convertWordNumbers(_ text: String) -> String {
        let wordToNumber: [String: String] = [
            "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
            "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10",
            "eleven": "11", "twelve": "12",
        ]
        let words = text.split(separator: " ", maxSplits: 1)
        guard let first = words.first,
              let digit = wordToNumber[first.lowercased()] else {
            return text
        }
        let rest = words.count > 1 ? " " + words[1] : ""
        return digit + rest
    }

    // MARK: - Unit Abbreviation Expansion in Text

    /// Expand unit abbreviations embedded in text (e.g., "2T" → "2 tablespoon", "3C" → "3 cup").
    /// Case-sensitive for T/C/t to distinguish tablespoon/cup/teaspoon.
    /// After expansion, scaleEmbeddedQuantities can match the full unit names for scaling.
    private nonisolated func expandUnitAbbreviationsInText(_ text: String) -> String {
        // Phase 1: Expand "digit+abbreviation" patterns (e.g., "2T" → "2 tablespoon")
        let abbreviations = ["tbsp", "tbs", "tsp", "oz", "lb", "T", "C", "t"]
        let pattern = "(\\d+\\.?\\d*)\\s*(" + abbreviations.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")\\b"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }

        var result = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: result.length))

        for match in matches.reversed() {
            let number = result.substring(with: match.range(at: 1))
            let abbrev = result.substring(with: match.range(at: 2))
            let expanded = abbrev.expandedUnitAbbreviation
            if expanded != abbrev {
                result = result.replacingCharacters(in: match.range, with: "\(number) \(expanded)") as NSString
            }
        }

        // Phase 2: Expand a leading standalone abbreviation (e.g., name="C plus..." → "cup plus...")
        // Handles cases where the parser put the unit in the name field instead of the unit field
        let resultStr = result as String
        let words = resultStr.split(separator: " ", maxSplits: 1)
        if let firstWord = words.first {
            let word = String(firstWord)
            let expanded = word.expandedUnitAbbreviation
            if expanded != word {
                let rest = words.count > 1 ? " " + words[1] : ""
                return expanded + rest
            }
        }

        return resultStr
    }

    // MARK: - Embedded Quantity Scaling

    /// Scale any embedded quantities found in text (e.g., "plus 1 tablespoon" in ingredient names)
    /// Handles compound ingredients like "1/4 cup + 1 tablespoon butter, divided"
    /// where the parser only extracted the first quantity and the rest is in the name.
    private nonisolated func scaleEmbeddedQuantities(in text: String, scaleFactor: Double) -> String {
        let units = [
            "cups?", "tablespoons?", "tbsp", "teaspoons?", "tsp",
            "ounces?", "oz", "pounds?", "lbs?", "grams?",
            "ml", "liters?", "pinch(?:es)?", "dash(?:es)?",
            "cloves?", "sticks?", "pieces?", "slices?"
        ]
        let unitPattern = "(?:" + units.joined(separator: "|") + ")"

        // Quantity: mixed number "1 1/2", slash fraction "1/4", decimal "1.5",
        // whole + unicode "2½", standalone unicode "½", or plain integer "2"
        let qtyPattern = "(\\d+\\s+\\d+/\\d+|\\d+/\\d+|\\d+\\.\\d+|\\d+\\s*[\u{00BD}\u{00BC}\u{00BE}\u{2153}\u{2154}\u{215B}\u{215C}\u{215D}\u{215E}]|[\u{00BD}\u{00BC}\u{00BE}\u{2153}\u{2154}\u{215B}\u{215C}\u{215D}\u{215E}]|\\d+)"
        let fullPattern = qtyPattern + "(\\s+)" + "(" + unitPattern + ")"

        guard let regex = try? NSRegularExpression(pattern: fullPattern, options: .caseInsensitive) else {
            return text
        }

        var result = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: result.length))

        // Process in reverse to preserve string positions
        for match in matches.reversed() {
            let qtyString = result.substring(with: match.range(at: 1))
            let unitString = result.substring(with: match.range(at: 3))

            if let qty = parseEmbeddedQuantity(qtyString) {
                let scaled = qty * scaleFactor
                let formatted = formatQuantity(scaled, unit: unitString)
                result = result.replacingCharacters(in: match.range(at: 1), with: formatted) as NSString
            }
        }

        return result as String
    }

    /// Parse a quantity string that may contain fractions or unicode fractions
    private nonisolated func parseEmbeddedQuantity(_ str: String) -> Double? {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        let unicodeFractions: [Character: Double] = [
            "\u{00BD}": 0.5, "\u{00BC}": 0.25, "\u{00BE}": 0.75,
            "\u{2153}": 1.0/3.0, "\u{2154}": 2.0/3.0,
            "\u{215B}": 0.125, "\u{215C}": 0.375, "\u{215D}": 0.625, "\u{215E}": 0.875
        ]

        // Single unicode fraction
        if trimmed.count == 1, let ch = trimmed.first, let val = unicodeFractions[ch] {
            return val
        }

        // Whole number + unicode fraction (e.g., "2½" or "2 ½")
        for (char, val) in unicodeFractions {
            if trimmed.contains(char) {
                let parts = trimmed.split(separator: char)
                if let wholePart = parts.first,
                   let whole = Double(wholePart.trimmingCharacters(in: .whitespaces)) {
                    return whole + val
                }
            }
        }

        // Mixed number with slash fraction (e.g., "1 1/4")
        let components = trimmed.split(separator: " ")
        if components.count == 2, let whole = Double(components[0]) {
            let fracStr = String(components[1])
            if fracStr.contains("/") {
                let fracParts = fracStr.split(separator: "/")
                if fracParts.count == 2,
                   let num = Double(fracParts[0]),
                   let den = Double(fracParts[1]), den != 0 {
                    return whole + (num / den)
                }
            }
        }

        // Slash fraction (e.g., "1/4")
        if trimmed.contains("/") {
            let parts = trimmed.split(separator: "/")
            if parts.count == 2,
               let num = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let den = Double(parts[1].trimmingCharacters(in: .whitespaces)), den != 0 {
                return num / den
            }
        }

        // Plain number
        return Double(trimmed)
    }
}

// MARK: - Unit Abbreviation Expansion

extension String {
    /// Expand common unit abbreviations to full names.
    /// Handles case-sensitive abbreviations (e.g., "t" = teaspoon, "T" = tablespoon, "C" = cup).
    var expandedUnitAbbreviation: String {
        // Case-sensitive abbreviations first
        let caseSensitiveMappings: [String: String] = [
            "t": "teaspoon",
            "T": "tablespoon",
            "C": "cup",
            "oz": "ounce",
            "lb": "pound",
            "pt": "pint",
            "qt": "quart",
            "gal": "gallon",
            "g": "gram",
            "kg": "kilogram",
            "ml": "ml",
            "l": "liter",
        ]

        if let expanded = caseSensitiveMappings[self] {
            return expanded
        }

        // Case-insensitive abbreviations
        let caseInsensitiveMappings: [String: String] = [
            "tsp": "teaspoon",
            "tbsp": "tablespoon",
            "tbs": "tablespoon",
            "ozs": "ounces",
            "lbs": "pounds",
            "pts": "pints",
            "qts": "quarts",
        ]

        if let expanded = caseInsensitiveMappings[self.lowercased()] {
            return expanded
        }

        return self
    }

}
