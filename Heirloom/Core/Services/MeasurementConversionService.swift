//
//  MeasurementConversionService.swift
//  Heirloom
//
//  Stateless service for converting measurements between imperial and metric systems
//

import Foundation
import SwiftUI

/// Converted measurement result
struct ConvertedMeasurement {
    let quantity: Double
    let unit: String
    let originalQuantity: Double
    let originalUnit: String
}

/// Type of measurement unit
enum UnitType {
    case volume
    case weight
    case count
    case unknown
}

/// Stateless service for measurement unit conversion
@MainActor
final class MeasurementConversionService {

    // MARK: - Conversion Factors

    /// Volume conversions to milliliters (US measurements)
    private static let volumeToML: [String: Double] = [
        "cup": 236.588,
        "cups": 236.588,
        "c": 236.588,
        "tablespoon": 14.787,
        "tablespoons": 14.787,
        "tbsp": 14.787,
        "tbs": 14.787,
        "tb": 14.787,
        "T": 14.787,
        "teaspoon": 4.929,
        "teaspoons": 4.929,
        "tsp": 4.929,
        "ts": 4.929,
        "t": 4.929,
        "fluid ounce": 29.574,
        "fluid ounces": 29.574,
        "fl oz": 29.574,
        "fl. oz.": 29.574,
        "oz": 29.574, // Context-dependent - assuming fluid oz for volume
        "pint": 473.176,
        "pints": 473.176,
        "pt": 473.176,
        "quart": 946.353,
        "quarts": 946.353,
        "qt": 946.353,
        "gallon": 3785.41,
        "gallons": 3785.41,
        "gal": 3785.41,
        "milliliter": 1.0,
        "milliliters": 1.0,
        "millilitre": 1.0,
        "millilitres": 1.0,
        "ml": 1.0,
        "liter": 1000.0,
        "liters": 1000.0,
        "litre": 1000.0,
        "litres": 1000.0,
        "l": 1000.0
    ]

    /// Weight conversions to grams
    private static let weightToGrams: [String: Double] = [
        "ounce": 28.3495,
        "ounces": 28.3495,
        "oz": 28.3495,
        "pound": 453.592,
        "pounds": 453.592,
        "lb": 453.592,
        "lbs": 453.592,
        "gram": 1.0,
        "grams": 1.0,
        "g": 1.0,
        "kilogram": 1000.0,
        "kilograms": 1000.0,
        "kg": 1000.0
    ]

    /// Count units that should not be converted
    private static let countUnits: Set<String> = [
        "whole", "large", "medium", "small", "clove", "cloves",
        "piece", "pieces", "slice", "slices", "can", "cans",
        "jar", "jars", "package", "packages", "pkg", "bunch",
        "head", "heads", "stalk", "stalks", "sprig", "sprigs",
        "leaf", "leaves", "strip", "strips", "sheet", "sheets"
    ]

    /// Unknown/descriptive units that should not be converted
    private static let unknownUnits: Set<String> = [
        "pinch", "dash", "handful", "to taste", "some", "a little",
        "as needed", "optional"
    ]

    // MARK: - Main Conversion Method

    /// Convert a measurement to the target unit system
    static func convert(
        quantity: Double,
        unit: String,
        to targetSystem: UnitSystem
    ) -> ConvertedMeasurement? {
        let normalizedUnit = unit.lowercased().trimmingCharacters(in: .whitespaces)
        let unitType = self.unitType(for: normalizedUnit)

        // Don't convert count or unknown units
        guard unitType == .volume || unitType == .weight else {
            return nil
        }

        // Check if already in target system
        let isCurrentlyMetric = isMetricUnit(normalizedUnit)
        let isCurrentlyImperial = isImperialUnit(normalizedUnit)

        // If already in target system, return nil (no conversion needed)
        if (targetSystem == .metric && isCurrentlyMetric) ||
           (targetSystem == .imperial && isCurrentlyImperial) {
            return nil
        }

        // Perform conversion based on unit type
        switch unitType {
        case .volume:
            return convertVolume(quantity: quantity, unit: normalizedUnit, to: targetSystem)
        case .weight:
            return convertWeight(quantity: quantity, unit: normalizedUnit, to: targetSystem)
        default:
            return nil
        }
    }

    // MARK: - Volume Conversion

    private static func convertVolume(
        quantity: Double,
        unit: String,
        to targetSystem: UnitSystem
    ) -> ConvertedMeasurement? {
        // Convert to milliliters first
        guard let mlFactor = volumeToML[unit] else {
            return nil
        }

        let totalML = quantity * mlFactor

        // Convert to target system
        switch targetSystem {
        case .imperial:
            return convertMLToImperial(ml: totalML, originalQuantity: quantity, originalUnit: unit)
        case .metric:
            return convertMLToMetric(ml: totalML, originalQuantity: quantity, originalUnit: unit)
        }
    }

    private static func convertMLToImperial(ml: Double, originalQuantity: Double, originalUnit: String) -> ConvertedMeasurement {
        // Select best imperial unit based on quantity
        let cups = ml / 236.588

        if cups >= 4.0 {
            // Use gallons for large quantities
            let gallons = ml / 3785.41
            return ConvertedMeasurement(
                quantity: gallons,
                unit: gallons == 1.0 ? "gallon" : "gallons",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        } else if cups >= 2.0 {
            // Use quarts
            let quarts = ml / 946.353
            return ConvertedMeasurement(
                quantity: quarts,
                unit: quarts == 1.0 ? "quart" : "quarts",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        } else if cups >= 1.0 {
            // Use cups
            return ConvertedMeasurement(
                quantity: cups,
                unit: cups == 1.0 ? "cup" : "cups",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        } else if cups >= 0.0625 { // 1 tbsp = 1/16 cup
            // Use tablespoons
            let tbsp = ml / 14.787
            return ConvertedMeasurement(
                quantity: tbsp,
                unit: tbsp == 1.0 ? "tablespoon" : "tablespoons",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        } else {
            // Use teaspoons for small quantities
            let tsp = ml / 4.929
            return ConvertedMeasurement(
                quantity: tsp,
                unit: tsp == 1.0 ? "teaspoon" : "teaspoons",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        }
    }

    private static func convertMLToMetric(ml: Double, originalQuantity: Double, originalUnit: String) -> ConvertedMeasurement {
        // Select best metric unit
        if ml >= 1000.0 {
            // Use liters for large quantities (round to 1 decimal for liters)
            let liters = round(ml / 1000.0 * 10) / 10
            return ConvertedMeasurement(
                quantity: liters,
                unit: liters == 1.0 ? "L" : "L",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        } else {
            // Use milliliters (round to whole number)
            let roundedML = round(ml)
            return ConvertedMeasurement(
                quantity: roundedML,
                unit: "ml",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        }
    }

    // MARK: - Weight Conversion

    private static func convertWeight(
        quantity: Double,
        unit: String,
        to targetSystem: UnitSystem
    ) -> ConvertedMeasurement? {
        // Convert to grams first
        guard let gramsFactor = weightToGrams[unit] else {
            return nil
        }

        let totalGrams = quantity * gramsFactor

        // Convert to target system
        switch targetSystem {
        case .imperial:
            return convertGramsToImperial(grams: totalGrams, originalQuantity: quantity, originalUnit: unit)
        case .metric:
            return convertGramsToMetric(grams: totalGrams, originalQuantity: quantity, originalUnit: unit)
        }
    }

    private static func convertGramsToImperial(grams: Double, originalQuantity: Double, originalUnit: String) -> ConvertedMeasurement {
        // Select best imperial unit
        let ounces = grams / 28.3495

        if ounces >= 16.0 {
            // Use pounds for large quantities
            let pounds = grams / 453.592
            return ConvertedMeasurement(
                quantity: pounds,
                unit: pounds == 1.0 ? "lb" : "lbs",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        } else {
            // Use ounces
            return ConvertedMeasurement(
                quantity: ounces,
                unit: "oz",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        }
    }

    private static func convertGramsToMetric(grams: Double, originalQuantity: Double, originalUnit: String) -> ConvertedMeasurement {
        // Select best metric unit
        if grams >= 1000.0 {
            // Use kilograms for large quantities (round to 1 decimal for kg)
            let kg = round(grams / 1000.0 * 10) / 10
            return ConvertedMeasurement(
                quantity: kg,
                unit: "kg",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        } else {
            // Use grams (round to whole number)
            let roundedGrams = round(grams)
            return ConvertedMeasurement(
                quantity: roundedGrams,
                unit: "g",
                originalQuantity: originalQuantity,
                originalUnit: originalUnit
            )
        }
    }

    // MARK: - Unit Type Detection

    /// Determine the type of unit (volume, weight, count, unknown)
    static func unitType(for unit: String?) -> UnitType {
        guard let unit = unit?.lowercased().trimmingCharacters(in: .whitespaces), !unit.isEmpty else {
            return .unknown
        }

        if volumeToML[unit] != nil {
            return .volume
        } else if weightToGrams[unit] != nil {
            return .weight
        } else if countUnits.contains(unit) {
            return .count
        } else {
            return .unknown
        }
    }

    /// Check if a unit is metric
    nonisolated static func isMetricUnit(_ unit: String?) -> Bool {
        guard let unit = unit?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return false
        }

        let metricVolume: Set<String> = ["ml", "milliliter", "milliliters", "millilitre", "millilitres", "l", "liter", "liters", "litre", "litres"]
        let metricWeight: Set<String> = ["g", "gram", "grams", "kg", "kilogram", "kilograms"]

        return metricVolume.contains(unit) || metricWeight.contains(unit)
    }

    /// Check if a unit is imperial
    static func isImperialUnit(_ unit: String?) -> Bool {
        guard let unit = unit?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return false
        }

        let imperialVolume: Set<String> = ["cup", "cups", "c", "tablespoon", "tablespoons", "tbsp", "tbs", "tb", "T",
                                           "teaspoon", "teaspoons", "tsp", "ts", "t", "fluid ounce", "fluid ounces",
                                           "fl oz", "fl. oz.", "pint", "pints", "pt", "quart", "quarts", "qt",
                                           "gallon", "gallons", "gal"]
        let imperialWeight: Set<String> = ["ounce", "ounces", "oz", "pound", "pounds", "lb", "lbs"]

        return imperialVolume.contains(unit) || imperialWeight.contains(unit)
    }
}
