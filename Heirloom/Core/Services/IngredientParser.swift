import Foundation

/// Simple ingredient parser to extract quantity, unit, and name from text
/// This is a basic implementation - will be enhanced in later phases
struct IngredientParser {

    static func parse(_ text: String) -> (quantity: Double?, quantityMax: Double?, unit: String?, name: String) {
        var remainingText = text.trimmingCharacters(in: .whitespaces)

        // Extract quantity (including fractions and ranges)
        let (qty, qtyMax, afterQty, hadSpaceAfterQuantity) = extractQuantity(from: remainingText)
        remainingText = afterQty

        // Extract unit only if there was a space after quantity
        // This prevents parsing "250g" as "250" + "g" (should be treated as single token)
        let (unit, afterUnit) = hadSpaceAfterQuantity ? extractUnit(from: remainingText) : (nil, remainingText)
        remainingText = afterUnit

        // Remaining text is the ingredient name
        let name = remainingText.trimmingCharacters(in: .whitespaces)

        return (qty, qtyMax, unit, name)
    }

    // MARK: - Quantity Extraction

    private static func extractQuantity(from text: String) -> (quantity: Double?, max: Double?, remaining: String, hadSpace: Bool) {
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil  // Don't skip whitespace automatically

        var quantity: Double?
        var quantityMax: Double?

        // Helper to skip whitespace manually
        func skipWhitespace() {
            while scanner.currentIndex < text.endIndex && text[scanner.currentIndex].isWhitespace {
                scanner.currentIndex = text.index(after: scanner.currentIndex)
            }
        }

        // Helper: Check for unicode fraction characters and convert to decimal
        func scanUnicodeFraction() -> Double? {
            let remainingText = String(text[scanner.currentIndex...]).trimmingCharacters(in: .whitespaces)
            guard !remainingText.isEmpty else { return nil }

            let unicodeFractions: [Character: Double] = [
                "¼": 0.25, "½": 0.5, "¾": 0.75,
                "⅐": 1.0/7, "⅑": 1.0/9, "⅒": 0.1,
                "⅓": 1.0/3, "⅔": 2.0/3,
                "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8,
                "⅙": 1.0/6, "⅚": 5.0/6,
                "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
            ]

            let firstChar = remainingText.first!
            if let value = unicodeFractions[firstChar] {
                // Move scanner past the unicode fraction character
                scanner.currentIndex = remainingText.index(after: remainingText.startIndex)
                return value
            }
            return nil
        }

        // Helper: Check if text at current position looks like a fraction (e.g., "1/4")
        func looksLikeFraction() -> Bool {
            let remainingText = String(text[scanner.currentIndex...]).trimmingCharacters(in: .whitespaces)
            // Match pattern: digit(s) followed by / or ⁄ followed by digit(s)
            let fractionPattern = "^\\d+[/⁄]\\d+"
            return remainingText.range(of: fractionPattern, options: .regularExpression) != nil
        }

        // Skip leading whitespace
        skipWhitespace()

        var hadSpaceAfterNumber = false

        // Try unicode fraction first (e.g., "½ cup")
        if let unicodeFrac = scanUnicodeFraction() {
            quantity = unicodeFrac
            // Check if there's a space after the fraction
            let beforeSpace = scanner.currentIndex
            skipWhitespace()
            hadSpaceAfterNumber = beforeSpace != scanner.currentIndex
            let remaining = String(text[scanner.currentIndex...])
            return (quantity, nil, remaining, hadSpaceAfterNumber)
        }

        // Try to scan a fraction first if it looks like one (e.g., "1/4" not "1.5")
        if looksLikeFraction(), let fraction = scanFraction(scanner: scanner) {
            quantity = fraction

            // Check for space right after the fraction
            let posAfterFraction = scanner.currentIndex
            skipWhitespace()
            hadSpaceAfterNumber = scanner.currentIndex != posAfterFraction

            // Check for range with fractions (e.g., "1/4-1/2", "1/4 to 1/2", "1/4 or 1/2")
            if scanner.scanString("-") != nil || scanner.scanString("to") != nil || scanner.scanString("or") != nil {
                skipWhitespace()
                if let fraction2 = scanFraction(scanner: scanner) {
                    quantityMax = fraction2
                    // Check for space after the second fraction
                    let posAfterFraction2 = scanner.currentIndex
                    skipWhitespace()
                    hadSpaceAfterNumber = scanner.currentIndex != posAfterFraction2
                } else if let secondNumber = scanner.scanDouble() {
                    quantityMax = secondNumber
                    // Check for space after the second number
                    let posAfterNumber2 = scanner.currentIndex
                    skipWhitespace()
                    hadSpaceAfterNumber = scanner.currentIndex != posAfterNumber2
                } else {
                    // Couldn't parse second value, check for space anyway
                    let posAfterRange = scanner.currentIndex
                    skipWhitespace()
                    hadSpaceAfterNumber = scanner.currentIndex != posAfterRange
                }
            }
        } else if let firstNumber = scanner.scanDouble() {
            // Not a simple fraction, try whole/decimal number
            quantity = firstNumber

            // Check for space right after the number
            let posAfterNumber = scanner.currentIndex
            skipWhitespace()
            hadSpaceAfterNumber = scanner.currentIndex != posAfterNumber

            // Check for fraction after whole number (e.g., "2 1/4")
            if let fraction = scanFraction(scanner: scanner) {
                quantity! += fraction
                // Update space check after fraction
                let posAfterFraction = scanner.currentIndex
                skipWhitespace()
                hadSpaceAfterNumber = scanner.currentIndex != posAfterFraction
            }

            // Check for range (e.g., "2-3", "2 to 3", "2 or 3")
            if scanner.scanString("-") != nil || scanner.scanString("to") != nil || scanner.scanString("or") != nil {
                skipWhitespace()
                if let fraction = scanFraction(scanner: scanner) {
                    quantityMax = fraction
                } else if let secondNumber = scanner.scanDouble() {
                    quantityMax = secondNumber
                    // Check for space after the range's second number
                    let posAfterSecondNumber = scanner.currentIndex
                    skipWhitespace()
                    hadSpaceAfterNumber = scanner.currentIndex != posAfterSecondNumber

                    if let fraction = scanFraction(scanner: scanner) {
                        quantityMax! += fraction
                        // Update space check after fraction
                        let posAfterFraction = scanner.currentIndex
                        skipWhitespace()
                        hadSpaceAfterNumber = scanner.currentIndex != posAfterFraction
                    }
                } else {
                    // If we couldn't parse the second number, check for space anyway
                    let posAfterRange = scanner.currentIndex
                    skipWhitespace()
                    hadSpaceAfterNumber = scanner.currentIndex != posAfterRange
                }
            }
        }

        // If no quantity was parsed, allow unit extraction
        let hadSpace = quantity == nil || hadSpaceAfterNumber

        let remaining = String(text[scanner.currentIndex...])
        return (quantity, quantityMax, remaining, hadSpace)
    }

    private static func scanFraction(scanner: Scanner) -> Double? {
        let start = scanner.currentIndex

        // Try to scan numerator
        guard let numerator = scanner.scanInt() else {
            scanner.currentIndex = start
            return nil
        }

        // Try to scan slash (regular or unicode)
        guard scanner.scanString("/") != nil || scanner.scanString("⁄") != nil else {
            scanner.currentIndex = start
            return nil
        }

        // Try to scan denominator
        guard let denominator = scanner.scanInt(), denominator != 0 else {
            scanner.currentIndex = start
            return nil
        }

        return Double(numerator) / Double(denominator)
    }

    // MARK: - Unit Extraction

    private static func extractUnit(from text: String) -> (unit: String?, remaining: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return (nil, trimmed) }

        // Helper to check if a unit matches at the start
        func matchUnit(_ unit: String, caseSensitive: Bool = false) -> Bool {
            let options: NSRegularExpression.Options = caseSensitive ? [] : .caseInsensitive
            let pattern = "^" + NSRegularExpression.escapedPattern(for: unit) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return false }
            return regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
        }

        // Helper to extract matched unit
        func extractMatched(_ unit: String) -> (String, String) {
            let afterUnit = String(trimmed.dropFirst(unit.count)).trimmingCharacters(in: .whitespaces)
            return (unit, afterUnit)
        }

        // SPECIAL CASE: Single-letter abbreviations with case-sensitivity rules
        // T (capital) = tablespoon, t (lowercase) = teaspoon, c = cup (case-insensitive)
        let firstChar = trimmed.first!
        if trimmed.count == 1 || (trimmed.count > 1 && trimmed[trimmed.index(after: trimmed.startIndex)].isWhitespace) {
            // It's a single letter followed by space or end of string
            if firstChar == "T" { return extractMatched("T") }
            if firstChar == "t" { return extractMatched("t") }
            if firstChar == "c" || firstChar == "C" { return extractMatched(String(firstChar)) }
        }

        // Common units (sorted by length descending to match longer units first)
        let units = [
            // Volume - longest to shortest
            "tablespoons", "tablespoon",
            "teaspoons", "teaspoon",
            "fluid ounces", "fluid ounce",
            "milliliters", "milliliter",
            "kilograms", "kilogram",
            "fl. oz.", "fl oz.", "fl. oz", "fl oz",
            "tbsp.", "tbsp", "tbs.", "tbs",
            "tsp.", "tsp",
            "cups", "cup", "c.",
            "pints", "pint", "pt.", "pt",
            "quarts", "quart", "qt.", "qt",
            "gallons", "gallon", "gal.", "gal",
            "liters", "liter", "l.", "l",
            "ml.", "ml",

            // Weight - longest to shortest
            "pounds", "pound", "lbs.", "lbs", "lb.", "lb",
            "ounces", "ounce", "oz.", "oz",
            "grams", "gram", "g.", "g",
            "kg.", "kg",

            // Other - longest to shortest
            "packages", "package", "pkg.", "pkg",
            "bunches", "bunch",
            "cloves", "clove",
            "slices", "slice",
            "pieces", "piece",
            "sticks", "stick",
            "pinches", "pinch",
            "dashes", "dash",
            "cans", "can",
            "large", "medium", "small",
        ]

        // Try to match each unit (case-insensitive)
        for unit in units {
            if matchUnit(unit) {
                let (matchedUnit, remaining) = extractMatched(unit)
                // Normalize to canonical form
                let normalized = normalizeUnit(matchedUnit)
                return (normalized, remaining)
            }
        }

        return (nil, trimmed)
    }

    // MARK: - Unit Normalization

    /// Normalizes units to their canonical singular form
    /// Examples: "cups" → "cup", "tablespoons" → "tablespoon", "oz" → "oz."
    private static func normalizeUnit(_ unit: String) -> String {
        let normalized: String

        switch unit.lowercased() {
        // Volume - normalize to singular
        case "cups": normalized = "cup"
        case "tablespoons", "tbsp", "tbsp.": normalized = "tablespoon"
        case "teaspoons", "tsp", "tsp.": normalized = "teaspoon"
        case "pints", "pt", "pt.": normalized = "pint"
        case "quarts", "qt", "qt.": normalized = "quart"
        case "gallons", "gal", "gal.": normalized = "gallon"
        case "liters", "l", "l.": normalized = "liter"
        case "milliliters", "ml", "ml.": normalized = "milliliter"
        case "fluid ounces", "fl oz", "fl oz.", "fl. oz", "fl. oz.": normalized = "fluid ounce"

        // Weight - normalize to singular
        case "pounds", "lbs", "lbs.", "lb", "lb.": normalized = "pound"
        case "ounces", "oz": normalized = "oz."  // Add period for consistency
        case "oz.": normalized = "oz."  // Already has period
        case "grams", "g", "g.": normalized = "gram"
        case "kilograms", "kg", "kg.": normalized = "kilogram"

        // Count/piece units - normalize to singular
        case "packages", "pkg", "pkg.": normalized = "package"
        case "bunches": normalized = "bunch"
        case "cloves": normalized = "clove"
        case "slices": normalized = "slice"
        case "pieces": normalized = "piece"
        case "sticks": normalized = "stick"
        case "pinches": normalized = "pinch"
        case "dashes": normalized = "dash"
        case "cans": normalized = "can"

        // Already singular or special cases
        default: normalized = unit
        }

        return normalized
    }
}
