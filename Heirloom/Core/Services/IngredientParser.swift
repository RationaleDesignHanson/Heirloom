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

        // Common units (including abbreviations and plural forms)
        let units = [
            // Volume
            "cup", "cups", "c", "c.",
            "tablespoon", "tablespoons", "tbsp", "tbsp.", "tbs", "tbs.", "T",
            "teaspoon", "teaspoons", "tsp", "tsp.", "t",
            "fluid ounce", "fluid ounces", "fl oz", "fl. oz.", "fl oz.", "fl. oz",
            "milliliter", "milliliters", "ml", "ml.",
            "liter", "liters", "l", "l.",
            "pint", "pints", "pt", "pt.",
            "quart", "quarts", "qt", "qt.",
            "gallon", "gallons", "gal", "gal.",

            // Weight
            "pound", "pounds", "lb", "lb.", "lbs", "lbs.",
            "ounce", "ounces", "oz", "oz.",
            "gram", "grams", "g", "g.",
            "kilogram", "kilograms", "kg", "kg.",

            // Other
            "can", "cans",
            "package", "packages", "pkg", "pkg.",
            "bunch", "bunches",
            "clove", "cloves",
            "slice", "slices",
            "piece", "pieces",
            "stick", "sticks",
            "pinch", "pinches",
            "dash", "dashes",
            "large", "medium", "small",
        ]

        // Try to find a unit at the beginning
        for unit in units {
            let pattern = "^" + NSRegularExpression.escapedPattern(for: unit) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                let matchedUnit = String(trimmed[Range(match.range, in: trimmed)!])
                let afterUnit = String(trimmed.dropFirst(matchedUnit.count)).trimmingCharacters(in: .whitespaces)
                return (matchedUnit, afterUnit)
            }
        }

        return (nil, trimmed)
    }
}
