//
//  MultilingualIngredientParsingTests.swift
//  HeirloomTests
//
//  Tests for multilingual ingredient parsing across 6 languages
//

import XCTest
@testable import Heirloom

final class MultilingualIngredientParsingTests: XCTestCase {

    // MARK: - French Ingredient Parsing

    func testFrenchCupParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "2 tasses de farine",
            language: "fr"
        )

        XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01, "Should parse French quantity")
        XCTAssertNil(qtyMax, "Should not have max quantity")
        XCTAssertEqual(unit, "cup", "Should normalize 'tasse' to 'cup'")
        XCTAssertEqual(name, "farine", "Should extract ingredient name")
    }

    func testFrenchGramsParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "500 g de sucre",
            language: "fr"
        )

        XCTAssertEqual(qty ?? 0, 500.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "g")
        XCTAssertEqual(name, "sucre")
    }

    func testFrenchTablespoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "3 cuillères à soupe d'huile",
            language: "fr"
        )

        XCTAssertEqual(qty ?? 0, 3.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tbsp", "Should normalize 'cuillère à soupe' to 'tbsp'")
        XCTAssertEqual(name, "huile")
    }

    func testFrenchTeaspoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "1 cuillère à café de sel",
            language: "fr"
        )

        XCTAssertEqual(qty ?? 0, 1.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tsp", "Should normalize 'cuillère à café' to 'tsp'")
        XCTAssertEqual(name, "sel")
    }

    func testFrenchLiterParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "1.5 litres d'eau",
            language: "fr"
        )

        XCTAssertEqual(qty ?? 0, 1.5, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "L")
        XCTAssertEqual(name, "eau")
    }

    // MARK: - Spanish Ingredient Parsing

    func testSpanishCupParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "3 tazas de harina",
            language: "es"
        )

        XCTAssertEqual(qty ?? 0, 3.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "cup", "Should normalize 'taza' to 'cup'")
        XCTAssertEqual(name, "harina")
    }

    func testSpanishTablespoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "2 cucharadas de aceite",
            language: "es"
        )

        XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tbsp", "Should normalize 'cucharada' to 'tbsp'")
        XCTAssertEqual(name, "aceite")
    }

    func testSpanishTeaspoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "1 cucharadita de sal",
            language: "es"
        )

        XCTAssertEqual(qty ?? 0, 1.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tsp", "Should normalize 'cucharadita' to 'tsp'")
        XCTAssertEqual(name, "sal")
    }

    func testSpanishKilogramParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "2 kg de carne",
            language: "es"
        )

        XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "kg")
        XCTAssertEqual(name, "carne")
    }

    // MARK: - German Ingredient Parsing

    func testGermanCupParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "2 Tassen Mehl",
            language: "de"
        )

        XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "cup", "Should normalize 'Tasse' to 'cup'")
        XCTAssertEqual(name, "Mehl")
    }

    func testGermanTablespoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "3 Esslöffel Öl",
            language: "de"
        )

        XCTAssertEqual(qty ?? 0, 3.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tbsp", "Should normalize 'Esslöffel' to 'tbsp'")
        XCTAssertEqual(name, "Öl")
    }

    func testGermanTeaspoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "1 Teelöffel Salz",
            language: "de"
        )

        XCTAssertEqual(qty ?? 0, 1.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tsp", "Should normalize 'Teelöffel' to 'tsp'")
        XCTAssertEqual(name, "Salz")
    }

    func testGermanGramParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "250 g Zucker",
            language: "de"
        )

        XCTAssertEqual(qty ?? 0, 250.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "g")
        XCTAssertEqual(name, "Zucker")
    }

    // MARK: - Japanese Ingredient Parsing

    func testJapaneseCupParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "2カップの小麦粉",
            language: "ja"
        )

        XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "cup", "Should normalize 'カップ' to 'cup'")
        XCTAssertEqual(name, "小麦粉")
    }

    func testJapaneseTablespoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "大さじ3の油",
            language: "ja"
        )

        XCTAssertEqual(qty ?? 0, 3.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tbsp", "Should normalize '大さじ' to 'tbsp'")
        XCTAssertEqual(name, "油")
    }

    func testJapaneseTeaspoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "小さじ1の塩",
            language: "ja"
        )

        XCTAssertEqual(qty ?? 0, 1.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tsp", "Should normalize '小さじ' to 'tsp'")
        XCTAssertEqual(name, "塩")
    }

    func testJapaneseGramParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "300gの砂糖",
            language: "ja"
        )

        XCTAssertEqual(qty ?? 0, 300.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "g")
        XCTAssertEqual(name, "砂糖")
    }

    // MARK: - Chinese Ingredient Parsing

    func testChineseCupParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "2杯面粉",
            language: "zh"
        )

        XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "cup", "Should normalize '杯' to 'cup'")
        XCTAssertEqual(name, "面粉")
    }

    func testChineseTablespoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "3大勺油",
            language: "zh"
        )

        XCTAssertEqual(qty ?? 0, 3.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tbsp", "Should normalize '大勺' to 'tbsp'")
        XCTAssertEqual(name, "油")
    }

    func testChineseTeaspoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "1小勺盐",
            language: "zh"
        )

        XCTAssertEqual(qty ?? 0, 1.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tsp", "Should normalize '小勺' to 'tsp'")
        XCTAssertEqual(name, "盐")
    }

    func testChineseGramParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "500克糖",
            language: "zh"
        )

        XCTAssertEqual(qty ?? 0, 500.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "g", "Should normalize '克' to 'g'")
        XCTAssertEqual(name, "糖")
    }

    // MARK: - Korean Ingredient Parsing

    func testKoreanCupParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "2컵 밀가루",
            language: "ko"
        )

        XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "cup", "Should normalize '컵' to 'cup'")
        XCTAssertEqual(name, "밀가루")
    }

    func testKoreanTablespoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "큰술 3 식용유",
            language: "ko"
        )

        XCTAssertEqual(qty ?? 0, 3.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tbsp", "Should normalize '큰술' to 'tbsp'")
        XCTAssertEqual(name, "식용유")
    }

    func testKoreanTeaspoonParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "작은술 1 소금",
            language: "ko"
        )

        XCTAssertEqual(qty ?? 0, 1.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tsp", "Should normalize '작은술' to 'tsp'")
        XCTAssertEqual(name, "소금")
    }

    func testKoreanGramParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "300g 설탕",
            language: "ko"
        )

        XCTAssertEqual(qty ?? 0, 300.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "g")
        XCTAssertEqual(name, "설탕")
    }

    func testKoreanTraditionalGeun() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "1근 쇠고기",
            language: "ko"
        )

        XCTAssertEqual(qty ?? 0, 1.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "g", "Should normalize '근' to 'g' for conversion")
        XCTAssertEqual(name, "쇠고기")
    }

    func testKoreanTraditionalDon() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "5돈 인삼",
            language: "ko"
        )

        XCTAssertEqual(qty ?? 0, 5.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "g", "Should normalize '돈' to 'g' for conversion")
        XCTAssertEqual(name, "인삼")
    }

    // MARK: - English Baseline (Zero-Regression)

    func testEnglishParsingUnchanged() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "2 cups flour",
            language: "en"
        )

        XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "cup")
        XCTAssertEqual(name, "flour")
    }

    func testEnglishDefaultLanguage() {
        // Default language should be "en"
        let (qty, qtyMax, unit, name) = IngredientParser.parse("1 tbsp butter")

        XCTAssertEqual(qty ?? 0, 1.0, accuracy: 0.01)
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "tbsp")
        XCTAssertEqual(name, "butter")
    }

    // MARK: - Range Parsing (Multiple Languages)

    func testFrenchRangeParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "2-3 tasses de farine",
            language: "fr"
        )

        XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01)
        XCTAssertEqual(qtyMax ?? 0, 3.0, accuracy: 0.01, "Should parse range")
        XCTAssertEqual(unit, "cup")
        XCTAssertEqual(name, "farine")
    }

    func testJapaneseRangeParsing() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "1〜2カップの水",
            language: "ja"
        )

        XCTAssertEqual(qty ?? 0, 1.0, accuracy: 0.01)
        XCTAssertEqual(qtyMax ?? 0, 2.0, accuracy: 0.01, "Should parse Japanese range with 〜")
        XCTAssertEqual(unit, "cup")
        XCTAssertEqual(name, "水")
    }

    // MARK: - Edge Cases

    func testNoQuantityIngredient() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "塩（適量）",
            language: "ja"
        )

        XCTAssertNil(qty, "Should return nil for no quantity")
        XCTAssertNil(qtyMax)
        XCTAssertNil(unit)
        XCTAssertEqual(name, "塩（適量）", "Should return full text as name")
    }

    func testFractionalQuantityFrench() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "1/2 tasse de sucre",
            language: "fr"
        )

        XCTAssertEqual(qty ?? 0, 0.5, accuracy: 0.01, "Should parse fraction")
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "cup")
        XCTAssertEqual(name, "sucre")
    }

    func testDecimalQuantityGerman() {
        let (qty, qtyMax, unit, name) = IngredientParser.parse(
            "1,5 Liter Milch",
            language: "de"
        )

        XCTAssertEqual(qty ?? 0, 1.5, accuracy: 0.01, "Should parse German decimal (comma)")
        XCTAssertNil(qtyMax)
        XCTAssertEqual(unit, "L")
        XCTAssertEqual(name, "Milch")
    }
}
