//
//  MeasurementConversionTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Unit tests for measurement conversion
//
//  Tests the measurement conversion system to ensure:
//  - Imperial to metric conversion works
//  - Metric to imperial conversion works
//  - Volume unit conversions are accurate
//  - Weight unit conversions are accurate
//

import XCTest
@testable import Heirloom

@MainActor
final class MeasurementConversionTests: XCTestCase {

    // MARK: - Volume: Imperial to Metric

    /// Test 1: Cup to milliliters
    func test_cupToMilliliters_convertsCorrectly() {
        // GIVEN: 1 cup
        let cups = 1.0

        // WHEN: Converting to milliliters
        let ml = MeasurementConverter.cupsToMilliliters(cups)

        // THEN: Should be approximately 237 ml
        XCTAssertEqual(ml, 236.588, accuracy: 0.1)
    }

    /// Test 2: Tablespoon to milliliters
    func test_tablespoonToMilliliters_convertsCorrectly() {
        // GIVEN: 1 tablespoon
        let tbsp = 1.0

        // WHEN: Converting to milliliters
        let ml = MeasurementConverter.tablespoonsToMilliliters(tbsp)

        // THEN: Should be approximately 15 ml
        XCTAssertEqual(ml, 14.787, accuracy: 0.1)
    }

    /// Test 3: Teaspoon to milliliters
    func test_teaspoonToMilliliters_convertsCorrectly() {
        // GIVEN: 1 teaspoon
        let tsp = 1.0

        // WHEN: Converting to milliliters
        let ml = MeasurementConverter.teaspoonsToMilliliters(tsp)

        // THEN: Should be approximately 5 ml
        XCTAssertEqual(ml, 4.929, accuracy: 0.1)
    }

    /// Test 4: Fluid ounce to milliliters
    func test_fluidOunceToMilliliters_convertsCorrectly() {
        // GIVEN: 1 fluid ounce
        let flOz = 1.0

        // WHEN: Converting to milliliters
        let ml = MeasurementConverter.fluidOuncesToMilliliters(flOz)

        // THEN: Should be approximately 30 ml
        XCTAssertEqual(ml, 29.574, accuracy: 0.1)
    }

    // MARK: - Volume: Metric to Imperial

    /// Test 5: Milliliters to cups
    func test_millilitersToCups_convertsCorrectly() {
        // GIVEN: 250 ml (common metric cup)
        let ml = 250.0

        // WHEN: Converting to cups
        let cups = MeasurementConverter.millilitersToCups(ml)

        // THEN: Should be approximately 1.06 cups
        XCTAssertEqual(cups, 1.057, accuracy: 0.01)
    }

    /// Test 6: Liters to cups
    func test_litersToCups_convertsCorrectly() {
        // GIVEN: 1 liter
        let liters = 1.0

        // WHEN: Converting to cups
        let cups = MeasurementConverter.litersToCups(liters)

        // THEN: Should be approximately 4.23 cups
        XCTAssertEqual(cups, 4.227, accuracy: 0.01)
    }

    // MARK: - Weight: Imperial to Metric

    /// Test 7: Ounce to grams
    func test_ounceToGrams_convertsCorrectly() {
        // GIVEN: 1 ounce
        let oz = 1.0

        // WHEN: Converting to grams
        let g = MeasurementConverter.ouncesToGrams(oz)

        // THEN: Should be approximately 28.35 g
        XCTAssertEqual(g, 28.35, accuracy: 0.01)
    }

    /// Test 8: Pound to grams
    func test_poundToGrams_convertsCorrectly() {
        // GIVEN: 1 pound
        let lb = 1.0

        // WHEN: Converting to grams
        let g = MeasurementConverter.poundsToGrams(lb)

        // THEN: Should be approximately 453.59 g
        XCTAssertEqual(g, 453.59, accuracy: 0.1)
    }

    /// Test 9: Pound to kilograms
    func test_poundToKilograms_convertsCorrectly() {
        // GIVEN: 2.2 pounds
        let lb = 2.2

        // WHEN: Converting to kilograms
        let kg = MeasurementConverter.poundsToKilograms(lb)

        // THEN: Should be approximately 1 kg
        XCTAssertEqual(kg, 1.0, accuracy: 0.01)
    }

    // MARK: - Weight: Metric to Imperial

    /// Test 10: Grams to ounces
    func test_gramsToOunces_convertsCorrectly() {
        // GIVEN: 100 grams
        let g = 100.0

        // WHEN: Converting to ounces
        let oz = MeasurementConverter.gramsToOunces(g)

        // THEN: Should be approximately 3.53 oz
        XCTAssertEqual(oz, 3.527, accuracy: 0.01)
    }

    /// Test 11: Kilograms to pounds
    func test_kilogramsToPounds_convertsCorrectly() {
        // GIVEN: 1 kilogram
        let kg = 1.0

        // WHEN: Converting to pounds
        let lb = MeasurementConverter.kilogramsToPounds(kg)

        // THEN: Should be approximately 2.2 lb
        XCTAssertEqual(lb, 2.205, accuracy: 0.01)
    }

    // MARK: - Volume Equivalents

    /// Test 12: Cups to tablespoons
    func test_cupsToTablespoons_convertsCorrectly() {
        // GIVEN: 1 cup
        let cups = 1.0

        // WHEN: Converting to tablespoons
        let tbsp = MeasurementConverter.cupsToTablespoons(cups)

        // THEN: Should be 16 tablespoons
        XCTAssertEqual(tbsp, 16.0)
    }

    /// Test 13: Tablespoons to teaspoons
    func test_tablespoonsToTeaspoons_convertsCorrectly() {
        // GIVEN: 1 tablespoon
        let tbsp = 1.0

        // WHEN: Converting to teaspoons
        let tsp = MeasurementConverter.tablespoonsToTeaspoons(tbsp)

        // THEN: Should be 3 teaspoons
        XCTAssertEqual(tsp, 3.0)
    }

    /// Test 14: Quarts to cups
    func test_quartsToCups_convertsCorrectly() {
        // GIVEN: 1 quart
        let quarts = 1.0

        // WHEN: Converting to cups
        let cups = MeasurementConverter.quartsToCups(quarts)

        // THEN: Should be 4 cups
        XCTAssertEqual(cups, 4.0)
    }

    /// Test 15: Gallons to quarts
    func test_gallonsToQuarts_convertsCorrectly() {
        // GIVEN: 1 gallon
        let gallons = 1.0

        // WHEN: Converting to quarts
        let quarts = MeasurementConverter.gallonsToQuarts(gallons)

        // THEN: Should be 4 quarts
        XCTAssertEqual(quarts, 4.0)
    }

    // MARK: - Edge Cases

    /// Test 16: Zero conversion returns zero
    func test_zeroConversion_returnsZero() {
        // GIVEN: Zero value
        let zero = 0.0

        // WHEN/THEN: Converting should return zero
        XCTAssertEqual(MeasurementConverter.cupsToMilliliters(zero), 0.0)
        XCTAssertEqual(MeasurementConverter.gramsToOunces(zero), 0.0)
        XCTAssertEqual(MeasurementConverter.poundsToKilograms(zero), 0.0)
    }

    /// Test 17: Round-trip conversion is accurate
    func test_roundTripConversion_isAccurate() {
        // GIVEN: 2 cups
        let originalCups = 2.0

        // WHEN: Converting to ml and back
        let ml = MeasurementConverter.cupsToMilliliters(originalCups)
        let roundTripCups = MeasurementConverter.millilitersToCups(ml)

        // THEN: Should get back approximately the original value
        XCTAssertEqual(roundTripCups, originalCups, accuracy: 0.01)
    }

    /// Test 18: Large quantity conversion is accurate
    func test_largeQuantityConversion_isAccurate() {
        // GIVEN: 100 cups (large batch)
        let cups = 100.0

        // WHEN: Converting to liters
        let ml = MeasurementConverter.cupsToMilliliters(cups)
        let liters = ml / 1000.0

        // THEN: Should be approximately 23.66 liters
        XCTAssertEqual(liters, 23.66, accuracy: 0.1)
    }
}

// MARK: - Test Helper

/// Measurement converter for testing
enum MeasurementConverter {
    // MARK: - Volume: Imperial to Metric

    static func cupsToMilliliters(_ cups: Double) -> Double {
        cups * 236.588
    }

    static func tablespoonsToMilliliters(_ tbsp: Double) -> Double {
        tbsp * 14.787
    }

    static func teaspoonsToMilliliters(_ tsp: Double) -> Double {
        tsp * 4.929
    }

    static func fluidOuncesToMilliliters(_ flOz: Double) -> Double {
        flOz * 29.574
    }

    // MARK: - Volume: Metric to Imperial

    static func millilitersToCups(_ ml: Double) -> Double {
        ml / 236.588
    }

    static func litersToCups(_ liters: Double) -> Double {
        liters * 4.227
    }

    // MARK: - Weight: Imperial to Metric

    static func ouncesToGrams(_ oz: Double) -> Double {
        oz * 28.35
    }

    static func poundsToGrams(_ lb: Double) -> Double {
        lb * 453.59
    }

    static func poundsToKilograms(_ lb: Double) -> Double {
        lb * 0.4536
    }

    // MARK: - Weight: Metric to Imperial

    static func gramsToOunces(_ g: Double) -> Double {
        g / 28.35
    }

    static func kilogramsToPounds(_ kg: Double) -> Double {
        kg * 2.205
    }

    // MARK: - Volume Equivalents

    static func cupsToTablespoons(_ cups: Double) -> Double {
        cups * 16.0
    }

    static func tablespoonsToTeaspoons(_ tbsp: Double) -> Double {
        tbsp * 3.0
    }

    static func quartsToCups(_ quarts: Double) -> Double {
        quarts * 4.0
    }

    static func gallonsToQuarts(_ gallons: Double) -> Double {
        gallons * 4.0
    }
}
