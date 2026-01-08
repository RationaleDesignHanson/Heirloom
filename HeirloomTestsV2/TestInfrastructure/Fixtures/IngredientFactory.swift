//
//  IngredientFactory.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-06
//

import Foundation
@testable import Heirloom

/// Factory for creating Ingredient test fixtures
/// Supports all 7 languages with realistic ingredient data
enum IngredientFactory {

    // MARK: - Basic Ingredient Creation

    static func create(
        id: UUID = UUID(),
        name: String = "Test Ingredient",
        quantity: Double? = 1.0,
        quantityMax: Double? = nil,
        unit: String? = "cup",
        notes: String? = nil,
        originalLanguageName: String? = nil,
        originalLanguageUnit: String? = nil,
        wasConverted: Bool = false,
        convertedQuantity: Double? = nil,
        conversionNote: String? = nil
    ) -> Ingredient {
        return Ingredient(
            id: id,
            name: name,
            quantity: quantity,
            quantityMax: quantityMax,
            unit: unit,
            notes: notes,
            originalLanguageName: originalLanguageName,
            originalLanguageUnit: originalLanguageUnit,
            wasConverted: wasConverted,
            convertedQuantity: convertedQuantity,
            conversionNote: conversionNote
        )
    }

    // MARK: - English Ingredients

    static func createEnglish(
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        notes: String? = nil
    ) -> Ingredient {
        return create(
            name: name,
            quantity: quantity,
            unit: unit,
            notes: notes
        )
    }

    // MARK: - French Ingredients

    static func createFrench(
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        translated: Bool = true
    ) -> Ingredient {
        let englishUnit = unit.flatMap { frenchUnitToEnglish($0) }
        let englishName = translated ? "[FR→EN] \(name)" : name

        return create(
            name: englishName,
            quantity: quantity,
            unit: englishUnit ?? unit,
            originalLanguageName: name,
            originalLanguageUnit: unit,
            wasConverted: unit != nil && englishUnit != nil
        )
    }

    // MARK: - Japanese Ingredients (with regional cup conversion)

    static func createJapanese(
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        translated: Bool = true
    ) -> Ingredient {
        let englishUnit = unit.flatMap { japaneseUnitToEnglish($0) }
        let englishName = translated ? "[JA→EN] \(name)" : name

        // Japanese cups are 200ml, US cups are 237ml
        // 1 Japanese cup = 0.844 US cups
        var convertedQty: Double? = nil
        var conversionNote: String? = nil

        if unit == "カップ" || unit == "cup", let qty = quantity {
            convertedQty = qty * 0.844
            conversionNote = "Japanese cup (200ml) converted to US cup (237ml)"
        }

        return create(
            name: englishName,
            quantity: convertedQty ?? quantity,
            unit: englishUnit ?? unit,
            originalLanguageName: name,
            originalLanguageUnit: unit,
            wasConverted: convertedQty != nil,
            convertedQuantity: convertedQty,
            conversionNote: conversionNote
        )
    }

    // MARK: - Korean Ingredients (with traditional units)

    static func createKorean(
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        translated: Bool = true
    ) -> Ingredient {
        let englishUnit = unit.flatMap { koreanUnitToEnglish($0) }
        let englishName = translated ? "[KO→EN] \(name)" : name

        // Korean traditional units: 1근 = 600g, 1돈 = 3.75g
        var convertedQty: Double? = nil
        var conversionNote: String? = nil

        if unit == "근", let qty = quantity {
            convertedQty = qty * 600.0
            conversionNote = "Korean geun (근) converted to grams (1근 = 600g)"
        } else if unit == "돈", let qty = quantity {
            convertedQty = qty * 3.75
            conversionNote = "Korean don (돈) converted to grams (1돈 = 3.75g)"
        } else if unit == "컵" || unit == "cup", let qty = quantity {
            // Korean cups are also 200ml
            convertedQty = qty * 0.844
            conversionNote = "Korean cup (200ml) converted to US cup (237ml)"
        }

        return create(
            name: englishName,
            quantity: convertedQty ?? quantity,
            unit: convertedQty != nil ? "g" : (englishUnit ?? unit),
            originalLanguageName: name,
            originalLanguageUnit: unit,
            wasConverted: convertedQty != nil,
            convertedQuantity: convertedQty,
            conversionNote: conversionNote
        )
    }

    // MARK: - Spanish Ingredients

    static func createSpanish(
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        translated: Bool = true
    ) -> Ingredient {
        let englishUnit = unit.flatMap { spanishUnitToEnglish($0) }
        let englishName = translated ? "[ES→EN] \(name)" : name

        return create(
            name: englishName,
            quantity: quantity,
            unit: englishUnit ?? unit,
            originalLanguageName: name,
            originalLanguageUnit: unit,
            wasConverted: unit != nil && englishUnit != nil
        )
    }

    // MARK: - German Ingredients

    static func createGerman(
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        translated: Bool = true
    ) -> Ingredient {
        let englishUnit = unit.flatMap { germanUnitToEnglish($0) }
        let englishName = translated ? "[DE→EN] \(name)" : name

        return create(
            name: englishName,
            quantity: quantity,
            unit: englishUnit ?? unit,
            originalLanguageName: name,
            originalLanguageUnit: unit,
            wasConverted: unit != nil && englishUnit != nil
        )
    }

    // MARK: - Chinese Ingredients

    static func createChinese(
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        translated: Bool = true
    ) -> Ingredient {
        let englishUnit = unit.flatMap { chineseUnitToEnglish($0) }
        let englishName = translated ? "[ZH→EN] \(name)" : name

        return create(
            name: englishName,
            quantity: quantity,
            unit: englishUnit ?? unit,
            originalLanguageName: name,
            originalLanguageUnit: unit,
            wasConverted: unit != nil && englishUnit != nil
        )
    }

    // MARK: - Common Test Patterns

    /// Create ingredient with range quantity (e.g., "2-3 cups")
    static func createWithRange(name: String, min: Double, max: Double, unit: String) -> Ingredient {
        return create(
            name: name,
            quantity: min,
            quantityMax: max,
            unit: unit
        )
    }

    /// Create ingredient without quantity (e.g., "salt to taste")
    static func createWithoutQuantity(name: String, notes: String = "to taste") -> Ingredient {
        return create(
            name: name,
            quantity: nil,
            unit: nil,
            notes: notes
        )
    }

    /// Create fractional ingredient (e.g., "1/4 cup")
    static func createFractional(name: String, numerator: Int, denominator: Int, unit: String) -> Ingredient {
        let quantity = Double(numerator) / Double(denominator)
        return create(name: name, quantity: quantity, unit: unit)
    }

    // MARK: - Unit Translation Helpers

    private static func frenchUnitToEnglish(_ unit: String) -> String? {
        let mapping: [String: String] = [
            "tasse": "cup",
            "tasses": "cup",
            "cuillère à soupe": "tbsp",
            "cuillères à soupe": "tbsp",
            "cuillère à café": "tsp",
            "cuillères à café": "tsp",
            "g": "g",
            "kg": "kg",
            "ml": "ml",
            "l": "l"
        ]
        return mapping[unit.lowercased()]
    }

    private static func japaneseUnitToEnglish(_ unit: String) -> String? {
        let mapping: [String: String] = [
            "カップ": "cup",
            "cup": "cup",
            "大さじ": "tbsp",
            "小さじ": "tsp",
            "g": "g",
            "グラム": "g",
            "kg": "kg",
            "キログラム": "kg",
            "ml": "ml",
            "ミリリットル": "ml",
            "l": "l",
            "リットル": "l",
            "個": "piece",
            "本": "piece"
        ]
        return mapping[unit]
    }

    private static func koreanUnitToEnglish(_ unit: String) -> String? {
        let mapping: [String: String] = [
            "컵": "cup",
            "cup": "cup",
            "큰술": "tbsp",
            "작은술": "tsp",
            "g": "g",
            "그램": "g",
            "kg": "kg",
            "킬로그램": "kg",
            "ml": "ml",
            "l": "l",
            "개": "piece",
            "근": "g",  // Will be converted in factory
            "돈": "g"   // Will be converted in factory
        ]
        return mapping[unit]
    }

    private static func spanishUnitToEnglish(_ unit: String) -> String? {
        let mapping: [String: String] = [
            "taza": "cup",
            "tazas": "cup",
            "cucharada": "tbsp",
            "cucharadas": "tbsp",
            "cucharadita": "tsp",
            "cucharaditas": "tsp",
            "g": "g",
            "kg": "kg",
            "ml": "ml",
            "l": "l",
            "pizca": "pinch"
        ]
        return mapping[unit.lowercased()]
    }

    private static func germanUnitToEnglish(_ unit: String) -> String? {
        let mapping: [String: String] = [
            "Tasse": "cup",
            "Tassen": "cup",
            "EL": "tbsp",
            "Esslöffel": "tbsp",
            "TL": "tsp",
            "Teelöffel": "tsp",
            "g": "g",
            "Gramm": "g",
            "kg": "kg",
            "Kilogramm": "kg",
            "ml": "ml",
            "Milliliter": "ml",
            "l": "l",
            "Liter": "l",
            "Prise": "pinch"
        ]
        return mapping[unit]
    }

    private static func chineseUnitToEnglish(_ unit: String) -> String? {
        let mapping: [String: String] = [
            "杯": "cup",
            "大勺": "tbsp",
            "大匙": "tbsp",
            "小勺": "tsp",
            "小匙": "tsp",
            "克": "g",
            "千克": "kg",
            "公斤": "kg",
            "毫升": "ml",
            "升": "l",
            "个": "piece",
            "只": "piece"
        ]
        return mapping[unit]
    }
}

// MARK: - Ingredient Model (Test Support)

struct Ingredient: Codable, Equatable {
    let id: UUID
    let name: String
    let quantity: Double?
    let quantityMax: Double?
    let unit: String?
    let notes: String?
    let originalLanguageName: String?
    let originalLanguageUnit: String?
    let wasConverted: Bool
    let convertedQuantity: Double?
    let conversionNote: String?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double? = nil,
        quantityMax: Double? = nil,
        unit: String? = nil,
        notes: String? = nil,
        originalLanguageName: String? = nil,
        originalLanguageUnit: String? = nil,
        wasConverted: Bool = false,
        convertedQuantity: Double? = nil,
        conversionNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.quantityMax = quantityMax
        self.unit = unit
        self.notes = notes
        self.originalLanguageName = originalLanguageName
        self.originalLanguageUnit = originalLanguageUnit
        self.wasConverted = wasConverted
        self.convertedQuantity = convertedQuantity
        self.conversionNote = conversionNote
    }
}

// MARK: - Recipe Model (Test Support)

struct Recipe: Codable, Equatable {
    let id: UUID
    let title: String
    let servings: String
    let prepTime: String
    let cookTime: String
    let totalTime: String
    let ingredients: [Ingredient]
    let instructions: [String]
    let dateAdded: Date
    let lastModified: Date
    let sourceLanguage: String?
    let wasTranslated: Bool

    init(
        id: UUID = UUID(),
        title: String,
        servings: String,
        prepTime: String,
        cookTime: String,
        totalTime: String,
        ingredients: [Ingredient],
        instructions: [String],
        dateAdded: Date = Date(),
        lastModified: Date = Date(),
        sourceLanguage: String? = nil,
        wasTranslated: Bool = false
    ) {
        self.id = id
        self.title = title
        self.servings = servings
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.ingredients = ingredients
        self.instructions = instructions
        self.dateAdded = dateAdded
        self.lastModified = lastModified
        self.sourceLanguage = sourceLanguage
        self.wasTranslated = wasTranslated
    }
}
