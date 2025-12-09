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

        // Try to scan a number (handles decimals)
        if let firstNumber = scanner.scanDouble() {
            quantity = firstNumber

            // Check for fraction after whole number (e.g., "2 1/4")
            if let fraction = scanFraction(scanner: scanner) {
                quantity! += fraction
            }

            // Check for range (e.g., "2-3" or "2 to 3")
            if scanner.scanString("-") != nil || scanner.scanString("to") != nil {
                if let secondNumber = scanner.scanDouble() {
                    quantityMax = secondNumber
                    if let fraction = scanFraction(scanner: scanner) {
                        quantityMax! += fraction
                    }
                }
            }
        } else {
            // Try to scan fraction without whole number (e.g., "1/4")
            if let fraction = scanFraction(scanner: scanner) {
                quantity = fraction
            }
        }

        let remaining = String(text[scanner.currentIndex...])
        return (quantity, quantityMax, remaining)
    }

    private static func scanFraction(scanner: Scanner) -> Double? {
        let start = scanner.currentIndex

        if scanner.scanString("/") != nil || scanner.scanString("⁄") != nil {
            // Backtrack to get numerator
            scanner.currentIndex = start
            guard let numerator = scanner.scanInt() else { return nil }
            _ = scanner.scanString("/") ?? scanner.scanString("⁄")
            guard let denominator = scanner.scanInt(), denominator != 0 else { return nil }
            return Double(numerator) / Double(denominator)
        }

        return nil
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
