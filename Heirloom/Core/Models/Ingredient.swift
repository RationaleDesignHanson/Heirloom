import Foundation
import SwiftData

@Model
final class Ingredient {
    var id: UUID = UUID()
    var originalText: String = ""

    // MARK: - Parsed Components
    var quantity: Double?
    var quantityMax: Double?  // For ranges like "1-2 cups"
    var unit: String?
    var normalizedUnit: String?  // Singular, standardized (e.g., "cup" not "cups")
    var name: String = ""
    var preparation: String?  // "sifted", "chopped", etc.
    var size: String?  // "large" for eggs, etc.

    // MARK: - Organization
    var category: GroceryCategory?
    var orderIndex: Int = 0

    // MARK: - State
    var isSelected: Bool = true  // For shopping list selection
    var isCheckedOff: Bool = false  // For shopping list completion
    var isOptional: Bool = false

    // MARK: - Relationships
    var recipe: Recipe?  // Inverse is specified on Recipe.ingredients

    @Relationship(deleteRule: .cascade, inverse: \Substitution.ingredient)
    var substitutions: [Substitution]?

    // MARK: - Multilingual Support (SchemaV2)
    /// Original ingredient name in source language
    /// Nil for English ingredients, populated for foreign language imports
    var originalLanguageName: String?

    /// Translated ingredient name (if translated from foreign language)
    /// Nil for English ingredients or untranslated foreign ingredients
    var translatedName: String?

    /// Original unit before conversion (e.g., "カップ" for Japanese cup)
    /// Nil for English/standard units, populated for regional units requiring conversion
    var originalLanguageUnit: String?

    /// Quantity after unit conversion (e.g., Japanese 200ml cup → 0.83 US cups)
    /// Nil if no conversion was needed
    var convertedQuantity: Double?

    /// Unit after conversion (e.g., "cup" after converting from Japanese "カップ")
    /// Nil if no conversion was needed
    var convertedUnit: String?

    /// Human-readable explanation of conversion for UI display
    /// Example: "Japanese cup (200ml) converted to 0.83 US cups (240ml)"
    /// Nil if no conversion was needed
    var conversionNote: String?

    /// Whether this ingredient required regional unit conversion
    /// Helps UI show conversion badges/indicators
    var wasConverted: Bool = false

    // MARK: - Initialization
    init(
        originalText: String = "",
        name: String = "",
        quantity: Double? = nil,
        unit: String? = nil,
        category: GroceryCategory = .other,
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.originalText = originalText
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.orderIndex = orderIndex
        self.isSelected = true
        self.isCheckedOff = false
        self.isOptional = false
        self.substitutions = []
    }
}

// MARK: - Display
extension Ingredient {
    var displayText: String {
        // Fallback to originalText if name is empty (for unparsed ingredients)
        if name.isEmpty && !originalText.isEmpty {
            return originalText
        }

        var parts: [String] = []

        if let qty = quantity {
            parts.append(formatQuantity(qty))
            if let max = quantityMax {
                parts.append("-\(formatQuantity(max))")
            }
        }

        if let unit = unit {
            parts.append(unit)
        }

        parts.append(name)

        if let prep = preparation {
            parts.append("(\(prep))")
        }

        if isOptional {
            parts.append("(optional)")
        }

        return parts.joined(separator: " ")
    }

    private func formatQuantity(_ value: Double) -> String {
        // Handle zero or very small values
        if value < 0.05 {
            return ""
        }

        // Determine if this is a metric unit (use decimals) or imperial (use fractions)
        let isMetric = isMetricUnit(unit)

        if isMetric {
            // Metric: use decimals, round to 1 decimal place
            let rounded = round(value * 10) / 10
            if rounded == Double(Int(rounded)) {
                return "\(Int(rounded))"
            }
            return String(format: "%.1f", rounded)
        } else {
            // Imperial: use practical fractions only (no ridiculous ones like ⅜, ⅝, ⅞)
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

    /// Determines if a unit is metric (true) or imperial (false)
    private func isMetricUnit(_ unit: String?) -> Bool {
        guard let unit = unit?.lowercased() else { return false }

        // Metric units
        let metricUnits = [
            "g", "gram", "grams", "kg", "kilogram", "kilograms",
            "mg", "milligram", "milligrams",
            "l", "liter", "liters", "litre", "litres",
            "ml", "milliliter", "milliliters", "millilitre", "millilitres",
            "cl", "centiliter", "centiliters",
            "dl", "deciliter", "deciliters"
        ]

        return metricUnits.contains(unit)
    }
}

// MARK: - Scaling Support
extension Ingredient {
    /// Determines if this ingredient has a flexible quantity that shouldn't be flagged as missing.
    /// Examples: "salt to taste", "pinch of pepper", spices without quantities
    var isFlexibleQuantity: Bool {
        // Only check ingredients with nil quantity
        guard quantity == nil else { return false }

        let text = originalText.lowercased()

        // Pattern detection for common flexible quantity phrases
        let flexiblePatterns = [
            "to taste",
            "pinch",
            "pinch of",
            "dash",
            "dash of",
            "as needed",
            "for garnish",
            "for serving",
            "optional"
        ]

        if flexiblePatterns.contains(where: { text.contains($0) }) {
            return true
        }

        // Common seasonings by category
        if category == .spices {
            return true
        }

        // Specific ingredient names that are typically "to taste"
        let ingredientName = name.lowercased()
        let commonSeasonings = ["salt", "pepper", "seasoning"]

        return commonSeasonings.contains(where: { ingredientName.contains($0) })
    }
}

// MARK: - GroceryCategory
enum GroceryCategory: String, Codable, CaseIterable, Identifiable {
    case produce = "Produce"
    case dairy = "Dairy & Eggs"
    case meat = "Meat & Seafood"
    case bakery = "Bakery"
    case pantry = "Pantry"
    case frozen = "Frozen"
    case spices = "Spices & Seasonings"
    case condiments = "Condiments & Sauces"
    case beverages = "Beverages"
    case other = "Other"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "cup.and.saucer.fill"
        case .meat: return "fish.fill"
        case .bakery: return "birthday.cake.fill"
        case .pantry: return "cabinet.fill"
        case .frozen: return "snowflake"
        case .spices: return "leaf.circle.fill"
        case .condiments: return "drop.fill"
        case .beverages: return "mug.fill"
        case .other: return "basket.fill"
        }
    }

    /// Sort order optimized for typical supermarket layout:
    /// Fresh items first (perimeter), pantry/dry goods in middle, cold items last
    var sortOrder: Int {
        switch self {
        case .produce: return 0      // Perimeter - fresh, grab first
        case .bakery: return 1        // Perimeter - fresh items
        case .meat: return 2          // Perimeter - can handle cart time
        case .pantry: return 3        // Center aisles - bulk of shopping
        case .spices: return 4        // Center aisles - with pantry
        case .condiments: return 5    // Center aisles
        case .beverages: return 6     // Center aisles or near end
        case .dairy: return 7         // Back wall - grab near end to keep cold
        case .frozen: return 8        // Back wall - grab LAST to stay frozen
        case .other: return 9         // Catch-all
        }
    }

    /// Typical store location hint
    var aisleHint: String {
        switch self {
        case .produce: return "Perimeter / Front"
        case .bakery: return "Perimeter"
        case .meat: return "Perimeter / Back"
        case .pantry: return "Center Aisles"
        case .spices: return "Center Aisles"
        case .condiments: return "Center Aisles"
        case .beverages: return "Center Aisles"
        case .dairy: return "Back Wall"
        case .frozen: return "Back Wall"
        case .other: return "Varies"
        }
    }

    /// Auto-categorize an ingredient by name
    /// Will be enhanced with CommonIngredients cache in Day 3-4
    static func categorize(_ ingredientName: String) -> GroceryCategory {
        let lowercased = ingredientName.lowercased()

        // Frozen (check FIRST before dairy/produce since "ice cream" contains "cream" and we want frozen)
        if lowercased.contains("frozen") || lowercased.contains("ice cream") || lowercased.contains("ice-cream") || lowercased.contains("popsicle") {
            return .frozen
        }

        // Beverages (check BEFORE produce since "orange juice" contains "orange" but should be beverage)
        // Note: Exclude "baking soda" - check for "soda" only if not preceded by "baking"
        // Note: Use word boundaries for "tea" to avoid matching "steak"
        if lowercased.contains("juice") || lowercased.contains("coffee") || lowercased.contains(" tea") || lowercased.hasPrefix("tea ") || lowercased == "tea" || (lowercased.contains("soda") && !lowercased.contains("baking soda")) || lowercased.contains("water") {
            return .beverages
        }

        // Dairy & Eggs (exclude "eggplant" explicitly)
        if !lowercased.contains("eggplant") && (lowercased.contains("milk") || lowercased.contains("cheese") || lowercased.contains("butter") || lowercased.contains("cream") || lowercased.contains("yogurt") || lowercased.contains(" egg") || lowercased.hasPrefix("egg")) {
            return .dairy
        }

        // Condiments & Sauces (check BEFORE produce so "tomato sauce" matches condiments, not produce)
        if lowercased.contains("sauce") || lowercased.contains("ketchup") || lowercased.contains("mustard") || lowercased.contains("mayonnaise") || lowercased.contains("mayo") || lowercased.contains("dressing") {
            return .condiments
        }

        // Bakery (check BEFORE pantry so "flour tortillas" matches bakery, not pantry)
        if lowercased.contains("bread") || lowercased.contains("roll") || lowercased.contains("bun") || lowercased.contains("tortilla") {
            return .bakery
        }

        // Pantry (check vinegar BEFORE produce so "apple cider vinegar" matches pantry, not produce)
        if lowercased.contains("vinegar") || lowercased.contains("flour") || lowercased.contains("sugar") || lowercased.contains("rice") || lowercased.contains("pasta") || lowercased.contains("baking soda") || lowercased.contains("baking powder") || lowercased.contains("chocolate chip") || lowercased.contains("cocoa") || lowercased.contains("oil") || lowercased.contains("honey") || lowercased.contains("maple syrup") {
            return .pantry
        }

        // Meat & Seafood
        if lowercased.contains("chicken") || lowercased.contains("beef") || lowercased.contains("pork") || lowercased.contains("fish") || lowercased.contains("meat") || lowercased.contains("bacon") || lowercased.contains("sausage") || lowercased.contains("turkey") || lowercased.contains("salmon") || lowercased.contains("tuna") || lowercased.contains("shrimp") || lowercased.contains("cod") || lowercased.contains("seafood") || lowercased.contains("steak") {
            return .meat
        }

        // Produce
        if lowercased.contains("apple") || lowercased.contains("tomato") || lowercased.contains("onion") || lowercased.contains("garlic") || lowercased.contains("lettuce") || lowercased.contains("carrot") || lowercased.contains("celery") || lowercased.contains("potato") || lowercased.contains("lemon") || lowercased.contains("lime") || lowercased.contains("orange") || lowercased.contains("banana") {
            return .produce
        }

        // Spices & Seasonings (includes extracts and generic "seasoning" keyword)
        if lowercased.contains("salt") || lowercased.contains("pepper") || lowercased.contains("cumin") || lowercased.contains("paprika") || lowercased.contains("vanilla") || lowercased.contains("cinnamon") || lowercased.contains("oregano") || lowercased.contains("basil") || lowercased.contains("thyme") || lowercased.contains("extract") || lowercased.contains("saffron") || lowercased.contains("turmeric") || lowercased.contains("ginger") || lowercased.contains("nutmeg") || lowercased.contains("cardamom") || lowercased.contains("clove") || lowercased.contains("bay leaf") || lowercased.contains("rosemary") || lowercased.contains("parsley") || lowercased.contains("cilantro") || lowercased.contains("chili powder") || lowercased.contains("cayenne") || lowercased.contains("seasoning") {
            return .spices
        }

        return .other
    }
}

// MARK: - Phase 2 Stub Models
@Model
final class CardStyle {
    var id: UUID = UUID()
    var recipe: Recipe?

    @Relationship(deleteRule: .cascade, inverse: \Sticker.cardStyle)
    var stickers: [Sticker]?

    @Relationship(deleteRule: .cascade, inverse: \Annotation.cardStyle)
    var annotations: [Annotation]?

    init() {
        self.id = UUID()
        self.stickers = []
        self.annotations = []
    }
}

@Model
final class Sticker {
    var id: UUID = UUID()
    var cardStyle: CardStyle?  // Inverse is on CardStyle.stickers

    init() {
        self.id = UUID()
    }
}

@Model
final class Annotation {
    var id: UUID = UUID()
    var text: String = ""
    var cardStyle: CardStyle?  // Inverse is on CardStyle.annotations

    init(text: String = "") {
        self.id = UUID()
        self.text = text
    }
}

@Model
final class Substitution {
    var id: UUID = UUID()
    var originalIngredient: String = ""
    var substituteIngredient: String = ""
    var ingredient: Ingredient?  // Inverse is on Ingredient.substitutions

    init(original: String = "", substitute: String = "") {
        self.id = UUID()
        self.originalIngredient = original
        self.substituteIngredient = substitute
    }
}
