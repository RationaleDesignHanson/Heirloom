//
//  UnitConversionServiceTests.swift
//  HeirloomTests
//
//  Unit tests for UnitConversionService - Regional unit conversions
//

import XCTest
@testable import Heirloom

final class UnitConversionServiceTests: XCTestCase {

    // MARK: - Japanese Cup Conversions (200ml)

    func testJapaneseCupToUSCup() {
        // Japanese cup = 200ml, US cup = 237ml
        // 1 Japanese cup = 200/237 = ~0.844 US cups
        let result = UnitConversionService.adjustQuantity(
            1.0,
            unit: "cup",
            sourceLanguage: "ja"
        )

        XCTAssertEqual(result, 0.844, accuracy: 0.001,
                      "1 Japanese cup should convert to ~0.844 US cups")
    }

    func testJapaneseCupConversionMultiple() {
        // 2 Japanese cups = 400ml = 1.688 US cups
        let result = UnitConversionService.adjustQuantity(
            2.0,
            unit: "cup",
            sourceLanguage: "ja"
        )

        XCTAssertEqual(result, 1.688, accuracy: 0.001,
                      "2 Japanese cups should convert to ~1.688 US cups")
    }

    func testJapaneseCupWithOriginalUnit() {
        // Test with original unit "カップ"
        let result = UnitConversionService.adjustQuantity(
            1.0,
            unit: "cup",
            sourceLanguage: "ja",
            originalUnit: "カップ"
        )

        XCTAssertEqual(result, 0.844, accuracy: 0.001,
                      "Japanese カップ should convert correctly")
    }

    // MARK: - Korean Cup Conversions (200ml)

    func testKoreanCupToUSCup() {
        // Korean cup = 200ml, US cup = 237ml (same as Japanese)
        let result = UnitConversionService.adjustQuantity(
            1.0,
            unit: "cup",
            sourceLanguage: "ko"
        )

        XCTAssertEqual(result, 0.844, accuracy: 0.001,
                      "1 Korean cup should convert to ~0.844 US cups")
    }

    func testKoreanCupWithOriginalUnit() {
        // Test with original unit "컵"
        let result = UnitConversionService.adjustQuantity(
            1.5,
            unit: "cup",
            sourceLanguage: "ko",
            originalUnit: "컵"
        )

        XCTAssertEqual(result, 1.266, accuracy: 0.001,
                      "1.5 Korean 컵 should convert to ~1.266 US cups")
    }

    // MARK: - Korean Traditional Units

    func testKoreanGeun() {
        // 1 근 (geun) = 600g
        let result = UnitConversionService.adjustQuantity(
            1.0,
            unit: "g",
            sourceLanguage: "ko",
            originalUnit: "근"
        )

        XCTAssertEqual(result, 600.0, accuracy: 0.1,
                      "1 근 should convert to 600g")
    }

    func testKoreanGeunMultiple() {
        // 0.5 근 = 300g
        let result = UnitConversionService.adjustQuantity(
            0.5,
            unit: "g",
            sourceLanguage: "ko",
            originalUnit: "근"
        )

        XCTAssertEqual(result, 300.0, accuracy: 0.1,
                      "0.5 근 should convert to 300g")
    }

    func testKoreanDon() {
        // 1 돈 (don) = 3.75g
        let result = UnitConversionService.adjustQuantity(
            1.0,
            unit: "g",
            sourceLanguage: "ko",
            originalUnit: "돈"
        )

        XCTAssertEqual(result, 3.75, accuracy: 0.01,
                      "1 돈 should convert to 3.75g")
    }

    func testKoreanDonMultiple() {
        // 10 돈 = 37.5g
        let result = UnitConversionService.adjustQuantity(
            10.0,
            unit: "g",
            sourceLanguage: "ko",
            originalUnit: "돈"
        )

        XCTAssertEqual(result, 37.5, accuracy: 0.01,
                      "10 돈 should convert to 37.5g")
    }

    // MARK: - French Metric Cup (250ml)

    func testFrenchCupToUSCup() {
        // French cup = 250ml, US cup = 237ml
        // 1 French cup = 250/237 = ~1.055 US cups
        let result = UnitConversionService.adjustQuantity(
            1.0,
            unit: "cup",
            sourceLanguage: "fr"
        )

        XCTAssertEqual(result, 1.055, accuracy: 0.001,
                      "1 French cup should convert to ~1.055 US cups")
    }

    func testFrenchCupMultiple() {
        // 2 French cups = 500ml = 2.110 US cups
        let result = UnitConversionService.adjustQuantity(
            2.0,
            unit: "cup",
            sourceLanguage: "fr"
        )

        XCTAssertEqual(result, 2.110, accuracy: 0.001,
                      "2 French cups should convert to ~2.110 US cups")
    }

    // MARK: - English (No Conversion)

    func testEnglishNoConversion() {
        // English recipes should not be converted
        let result = UnitConversionService.adjustQuantity(
            1.0,
            unit: "cup",
            sourceLanguage: "en"
        )

        XCTAssertEqual(result, 1.0, accuracy: 0.001,
                      "English measurements should not be converted")
    }

    func testEnglishWithNilLanguage() {
        // Nil language should default to no conversion
        let result = UnitConversionService.adjustQuantity(
            2.5,
            unit: "tbsp",
            sourceLanguage: nil
        )

        XCTAssertEqual(result, 2.5, accuracy: 0.001,
                      "Nil language should not convert")
    }

    // MARK: - Edge Cases

    func testZeroQuantity() {
        let result = UnitConversionService.adjustQuantity(
            0.0,
            unit: "cup",
            sourceLanguage: "ja"
        )

        XCTAssertEqual(result, 0.0, accuracy: 0.001,
                      "Zero quantity should remain zero")
    }

    func testNilUnit() {
        // No unit means no conversion
        let result = UnitConversionService.adjustQuantity(
            1.0,
            unit: nil,
            sourceLanguage: "ja"
        )

        XCTAssertEqual(result, 1.0, accuracy: 0.001,
                      "Nil unit should not convert")
    }

    func testNonConvertibleUnit() {
        // Units that don't have regional variations should pass through
        let result = UnitConversionService.adjustQuantity(
            100.0,
            unit: "kg",
            sourceLanguage: "ja"
        )

        XCTAssertEqual(result, 100.0, accuracy: 0.001,
                      "Non-convertible units should pass through unchanged")
    }

    func testUnsupportedLanguage() {
        // Unsupported languages should not convert
        let result = UnitConversionService.adjustQuantity(
            1.0,
            unit: "cup",
            sourceLanguage: "xx"
        )

        XCTAssertEqual(result, 1.0, accuracy: 0.001,
                      "Unsupported language should not convert")
    }

    // MARK: - Conversion Info

    func testConversionInfoJapaneseCup() {
        let info = UnitConversionService.conversionInfo(
            for: "cup",
            sourceLanguage: "ja"
        )

        XCTAssertNotNil(info, "Should provide conversion info for Japanese cup")
        XCTAssertTrue(info!.contains("200ml") || info!.contains("200 ml"),
                     "Info should mention Japanese cup volume")
    }

    func testConversionInfoKoreanGeun() {
        let info = UnitConversionService.conversionInfo(
            for: "g",
            sourceLanguage: "ko"
        )

        XCTAssertNotNil(info, "Should provide conversion info for Korean weight")
        XCTAssertTrue(info!.contains("600") || info!.contains("근"),
                     "Info should mention Korean weight units")
    }

    func testConversionInfoEnglish() {
        let info = UnitConversionService.conversionInfo(
            for: "cup",
            sourceLanguage: "en"
        )

        XCTAssertNil(info, "English should not have conversion info")
    }

    func testConversionInfoNonConvertible() {
        let info = UnitConversionService.conversionInfo(
            for: "kg",
            sourceLanguage: "ja"
        )

        XCTAssertNil(info, "Non-convertible unit should not have conversion info")
    }
}
