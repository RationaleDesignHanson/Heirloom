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

        // Convert decimals to fractions for better display
        let fractions: [(Double, String)] = [
            (0.125, "⅛"), (0.25, "¼"), (0.333, "⅓"),
            (0.375, "⅜"), (0.5, "½"), (0.625, "⅝"),
            (0.667, "⅔"), (0.75, "¾"), (0.875, "⅞")
        ]

        let whole = Int(value)
        let fraction = value - Double(whole)

        // If it's essentially a whole number
        if fraction < 0.05 {
            return "\(whole)"
        }

        // Try to match common fractions
        for (threshold, symbol) in fractions {
            if abs(fraction - threshold) < 0.05 {
                return whole > 0 ? "\(whole) \(symbol)" : symbol
            }
        }

        // Fallback: use decimal notation for odd values
        // Round to 1 decimal place
        let rounded = round(value * 10) / 10
        if rounded == Double(Int(rounded)) {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
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
        if lowercased.contains("juice") || lowercased.contains("coffee") || lowercased.contains("tea") || (lowercased.contains("soda") && !lowercased.contains("baking soda")) || lowercased.contains("water") {
            return .beverages
        }

        // Dairy & Eggs (check eggs BEFORE produce since "egg" might match in "eggplant")
        if lowercased.contains("milk") || lowercased.contains("cheese") || lowercased.contains("butter") || lowercased.contains("cream") || lowercased.contains("yogurt") || lowercased.contains(" egg") || lowercased.hasPrefix("egg") {
            return .dairy
        }

        // Meat & Seafood
        if lowercased.contains("chicken") || lowercased.contains("beef") || lowercased.contains("pork") || lowercased.contains("fish") || lowercased.contains("meat") || lowercased.contains("bacon") || lowercased.contains("sausage") || lowercased.contains("turkey") || lowercased.contains("salmon") || lowercased.contains("tuna") || lowercased.contains("shrimp") || lowercased.contains("cod") || lowercased.contains("seafood") {
            return .meat
        }

        // Produce
        if lowercased.contains("apple") || lowercased.contains("tomato") || lowercased.contains("onion") || lowercased.contains("garlic") || lowercased.contains("lettuce") || lowercased.contains("carrot") || lowercased.contains("celery") || lowercased.contains("potato") || lowercased.contains("lemon") || lowercased.contains("lime") || lowercased.contains("orange") || lowercased.contains("banana") {
            return .produce
        }

        // Bakery
        if lowercased.contains("bread") || lowercased.contains("roll") || lowercased.contains("bun") || lowercased.contains("tortilla") {
            return .bakery
        }

        // Pantry (includes baking supplies and staples)
        if lowercased.contains("flour") || lowercased.contains("sugar") || lowercased.contains("rice") || lowercased.contains("pasta") || lowercased.contains("baking soda") || lowercased.contains("baking powder") || lowercased.contains("chocolate chip") || lowercased.contains("cocoa") || lowercased.contains("oil") || lowercased.contains("vinegar") || lowercased.contains("honey") || lowercased.contains("maple syrup") {
            return .pantry
        }

        // Spices & Seasonings (includes extracts)
        if lowercased.contains("salt") || lowercased.contains("pepper") || lowercased.contains("cumin") || lowercased.contains("paprika") || lowercased.contains("vanilla") || lowercased.contains("cinnamon") || lowercased.contains("oregano") || lowercased.contains("basil") || lowercased.contains("thyme") || lowercased.contains("extract") {
            return .spices
        }

        // Condiments & Sauces
        if lowercased.contains("sauce") || lowercased.contains("ketchup") || lowercased.contains("mustard") || lowercased.contains("mayonnaise") || lowercased.contains("mayo") || lowercased.contains("dressing") {
            return .condiments
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
