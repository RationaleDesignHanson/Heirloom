import Foundation

/// Service for handling regional unit variations and conversions
/// Addresses differences like Japanese/Korean cups (200ml) vs US cups (237ml)
struct UnitConversionService {

    // MARK: - Regional Conversion Factors

    /// Regional cup volume variations (in milliliters)
    private static let cupVolumes: [String: Double] = [
        "en": 236.588,  // US legal cup (1 cup = 236.588 ml)
        "fr": 250.0,     // French cup (metric, 250ml)
        "es": 250.0,     // Spanish cup (metric, 250ml)
        "de": 250.0,     // German cup (metric, 250ml)
        "ja": 200.0,     // Japanese cup (1 カップ = 200ml)
        "zh": 250.0,     // Chinese cup (metric, 250ml)
        "ko": 200.0      // Korean cup (1 컵 = 200ml)
    ]

    /// Traditional Korean weight unit conversions to grams
    private static let koreanWeightUnits: [String: Double] = [
        "근": 600.0,    // 1 근 (geun) = 600 grams
        "돈": 3.75      // 1 돈 (don) = 3.75 grams
    ]

    // MARK: - Public API

    /// Adjust quantity based on source language and unit
    /// Converts regional measurements to US-standard equivalents
    /// - Parameters:
    ///   - quantity: Original quantity value
    ///   - unit: Normalized English unit name (e.g., "cup", "tablespoon")
    ///   - sourceLanguage: ISO 639-1 source language code
    ///   - originalUnit: Optional original unit string before normalization (for Korean traditional units)
    /// - Returns: Adjusted quantity in US-standard measurements
    static func adjustQuantity(
        _ quantity: Double,
        unit: String,
        sourceLanguage: String,
        originalUnit: String? = nil
    ) -> Double {
        // Skip adjustment for English (already US-standard)
        guard sourceLanguage != "en" else { return quantity }

        // Handle Korean traditional weight units
        if sourceLanguage == "ko", let original = originalUnit {
            if let gramsPerUnit = koreanWeightUnits[original] {
                // Convert Korean traditional unit to grams
                let totalGrams = quantity * gramsPerUnit
                // Return grams (unit is already normalized to "gram")
                return totalGrams
            }
        }

        // Handle cup volume variations
        if unit.lowercased() == "cup" {
            return adjustCupQuantity(quantity, sourceLanguage: sourceLanguage)
        }

        // Handle tablespoon variations (some regions use 15ml, others 20ml)
        if unit.lowercased() == "tablespoon" {
            return adjustTablespoonQuantity(quantity, sourceLanguage: sourceLanguage)
        }

        // No adjustment needed for other units
        return quantity
    }

    /// Convert a quantity from one language's cup measurement to US cups
    /// Example: 1 Japanese cup (200ml) = 0.845 US cups (237ml)
    /// - Parameters:
    ///   - quantity: Number of cups in source language
    ///   - sourceLanguage: ISO 639-1 language code
    /// - Returns: Equivalent quantity in US cups
    static func adjustCupQuantity(_ quantity: Double, sourceLanguage: String) -> Double {
        guard let sourceCupML = cupVolumes[sourceLanguage],
              let usCupML = cupVolumes["en"] else {
            return quantity
        }

        // If source and US are the same, no adjustment needed
        guard sourceCupML != usCupML else { return quantity }

        // Convert: (quantity × sourceML) / usML = adjustedQuantity
        let adjustedQuantity = (quantity * sourceCupML) / usCupML

        return adjustedQuantity
    }

    /// Adjust tablespoon quantity for regional variations
    /// Most regions: 1 tablespoon = 15ml
    /// Australia: 1 tablespoon = 20ml
    /// - Parameters:
    ///   - quantity: Number of tablespoons
    ///   - sourceLanguage: ISO 639-1 language code
    /// - Returns: Adjusted quantity (usually unchanged)
    static func adjustTablespoonQuantity(_ quantity: Double, sourceLanguage: String) -> Double {
        // Currently all supported languages use 15ml tablespoons
        // This function exists for future expansion if needed
        return quantity
    }

    // MARK: - Conversion Info

    /// Get conversion factor information for debugging/logging
    /// - Parameters:
    ///   - unit: Unit to check
    ///   - sourceLanguage: Source language
    /// - Returns: Human-readable conversion info, or nil if no conversion needed
    static func conversionInfo(for unit: String, sourceLanguage: String) -> String? {
        guard sourceLanguage != "en" else { return nil }

        if unit.lowercased() == "cup" {
            guard let sourceCupML = cupVolumes[sourceLanguage],
                  let usCupML = cupVolumes["en"],
                  sourceCupML != usCupML else {
                return nil
            }

            let factor = sourceCupML / usCupML
            return String(format: "1 %@ cup (%.0fml) = %.3f US cups (%.0fml)",
                          languageName(for: sourceLanguage) ?? sourceLanguage,
                          sourceCupML,
                          factor,
                          usCupML)
        }

        return nil
    }

    /// Get cup volume in milliliters for a language
    /// - Parameter language: ISO 639-1 language code
    /// - Returns: Cup volume in milliliters, or nil if unknown
    static func cupVolume(for language: String) -> Double? {
        return cupVolumes[language]
    }

    // MARK: - Helpers

    private static func languageName(for code: String) -> String? {
        let names: [String: String] = [
            "en": "US", "fr": "French", "es": "Spanish",
            "de": "German", "ja": "Japanese", "zh": "Chinese", "ko": "Korean"
        ]
        return names[code]
    }
}

// MARK: - Usage Examples

/*
 Example 1: Japanese Recipe (1 cup flour)
 ```
 let originalQty = 1.0
 let unit = "cup"
 let sourceLanguage = "ja"

 let adjustedQty = UnitConversionService.adjustQuantity(
     originalQty,
     unit: unit,
     sourceLanguage: sourceLanguage
 )
 // adjustedQty = 0.845 (US cups)
 // Japanese cup (200ml) is smaller than US cup (237ml)
 ```

 Example 2: Korean Recipe (1 근 beef)
 ```
 let originalQty = 1.0
 let unit = "gram"  // Already normalized from "근"
 let sourceLanguage = "ko"
 let originalUnit = "근"

 let adjustedQty = UnitConversionService.adjustQuantity(
     originalQty,
     unit: unit,
     sourceLanguage: sourceLanguage,
     originalUnit: originalUnit
 )
 // adjustedQty = 600.0 grams
 ```

 Example 3: French Recipe (2 tasses)
 ```
 let originalQty = 2.0
 let unit = "cup"
 let sourceLanguage = "fr"

 let adjustedQty = UnitConversionService.adjustQuantity(
     originalQty,
     unit: unit,
     sourceLanguage: sourceLanguage
 )
 // adjustedQty = 2.113 (US cups)
 // French metric cup (250ml) is larger than US cup (237ml)
 ```

 Example 4: English Recipe (no conversion)
 ```
 let originalQty = 1.5
 let unit = "cup"
 let sourceLanguage = "en"

 let adjustedQty = UnitConversionService.adjustQuantity(
     originalQty,
     unit: unit,
     sourceLanguage: sourceLanguage
 )
 // adjustedQty = 1.5 (unchanged)
 ```
 */
