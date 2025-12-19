import Foundation

/// Simple ingredient parser to extract quantity, unit, and name from text
/// This is a basic implementation - will be enhanced in later phases
struct IngredientParser {

    static func parse(_ text: String) -> (quantity: Double?, quantityMax: Double?, unit: String?, name: String) {
        var remainingText = text.trimmingCharacters(in: .whitespaces)

        // Extract quantity (including fractions and ranges)
        let (qty, qtyMax, afterQty) = extractQuantity(from: remainingText)
        remainingText = afterQty

        // Extract unit
        let (unit, afterUnit) = extractUnit(from: remainingText)
        remainingText = afterUnit

        // Remaining text is the ingredient name
        let name = remainingText.trimmingCharacters(in: .whitespaces)

        return (qty, qtyMax, unit, name)
    }

    // MARK: - Quantity Extraction

    private static func extractQuantity(from text: String) -> (quantity: Double?, max: Double?, remaining: String) {
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = CharacterSet.whitespaces

        var quantity: Double?
        var quantityMax: Double?

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

        // Try unicode fraction first (e.g., "½ cup")
        if let unicodeFrac = scanUnicodeFraction() {
            quantity = unicodeFrac
            // No range support for unicode fractions yet
            let remaining = String(text[scanner.currentIndex...])
            return (quantity, nil, remaining)
        }

        // Try to scan a fraction first if it looks like one (e.g., "1/4" not "1.5")
        if looksLikeFraction(), let fraction = scanFraction(scanner: scanner) {
            quantity = fraction

            // Check for range with fractions (e.g., "1/4-1/2")
            if scanner.scanString("-") != nil || scanner.scanString("to") != nil {
                if let fraction2 = scanFraction(scanner: scanner) {
                    quantityMax = fraction2
                } else if let secondNumber = scanner.scanDouble() {
                    quantityMax = secondNumber
                }
            }
        } else if let firstNumber = scanner.scanDouble() {
            // Not a simple fraction, try whole/decimal number
            quantity = firstNumber

            // Check for fraction after whole number (e.g., "2 1/4")
            if let fraction = scanFraction(scanner: scanner) {
                quantity! += fraction
            }

            // Check for range (e.g., "2-3" or "2 to 3")
            if scanner.scanString("-") != nil || scanner.scanString("to") != nil {
                if let fraction = scanFraction(scanner: scanner) {
                    quantityMax = fraction
                } else if let secondNumber = scanner.scanDouble() {
                    quantityMax = secondNumber
                    if let fraction = scanFraction(scanner: scanner) {
                        quantityMax! += fraction
                    }
                }
            }
        }

        let remaining = String(text[scanner.currentIndex...])
        return (quantity, quantityMax, remaining)
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
            // Volume
            "tablespoon", "tablespoons", "teaspoon", "teaspoons",
            "fluid ounce", "fluid ounces",
            "milliliter", "milliliters",
            "kilogram", "kilograms",
            "fl oz.", "fl. oz.", "fl oz", "fl. oz",
            "tbsp.", "tbsp", "tbs.", "tbs",
            "tsp.", "tsp",
            "cups", "cup", "c.",
            "pint", "pints", "pt.", "pt",
            "quart", "quarts", "qt.", "qt",
            "gallon", "gallons", "gal.", "gal",
            "liter", "liters", "l.", "l",
            "ml.", "ml",

            // Weight
            "pound", "pounds", "lbs.", "lbs", "lb.", "lb",
            "ounce", "ounces", "oz.", "oz",
            "gram", "grams", "g.", "g",
            "kg.", "kg",

            // Other
            "package", "packages", "pkg.", "pkg",
            "bunch", "bunches",
            "clove", "cloves",
            "slice", "slices",
            "piece", "pieces",
            "stick", "sticks",
            "pinch", "pinches",
            "dash", "dashes",
            "can", "cans",
            "large", "medium", "small",
        ]

        // Try to match each unit (case-insensitive)
        for unit in units {
            if matchUnit(unit) {
                return extractMatched(unit)
            }
        }

        return (nil, trimmed)
    }
}
