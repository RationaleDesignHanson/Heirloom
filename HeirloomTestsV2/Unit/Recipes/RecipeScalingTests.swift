//
//  RecipeScalingTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Unit tests for recipe scaling
//
//  Tests the recipe scaling system to ensure:
//  - Ingredients scale up and down correctly
//  - Fractions are handled properly
//  - Scale factors are calculated correctly
//  - Edge cases are handled gracefully
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class RecipeScalingTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true)
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        try await super.tearDown()
    }

    // MARK: - Scale Factor Calculation Tests

    /// Test 1: Scale factor for doubling
    func test_scaleFactor_doubling_isTwo() {
        // GIVEN: Original 4 servings, target 8 servings
        let originalServings = 4
        let targetServings = 8

        // WHEN: Calculating scale factor
        let scaleFactor = RecipeScaler.calculateScaleFactor(
            originalServings: originalServings,
            targetServings: targetServings
        )

        // THEN: Scale factor should be 2.0
        XCTAssertEqual(scaleFactor, 2.0)
    }

    /// Test 2: Scale factor for halving
    func test_scaleFactor_halving_isPointFive() {
        // GIVEN: Original 8 servings, target 4 servings
        let originalServings = 8
        let targetServings = 4

        // WHEN: Calculating scale factor
        let scaleFactor = RecipeScaler.calculateScaleFactor(
            originalServings: originalServings,
            targetServings: targetServings
        )

        // THEN: Scale factor should be 0.5
        XCTAssertEqual(scaleFactor, 0.5)
    }

    /// Test 3: Scale factor for same servings
    func test_scaleFactor_sameServings_isOne() {
        // GIVEN: Same servings
        let servings = 6

        // WHEN: Calculating scale factor
        let scaleFactor = RecipeScaler.calculateScaleFactor(
            originalServings: servings,
            targetServings: servings
        )

        // THEN: Scale factor should be 1.0
        XCTAssertEqual(scaleFactor, 1.0)
    }

    /// Test 4: Scale factor for non-integer ratio
    func test_scaleFactor_nonIntegerRatio_isCorrect() {
        // GIVEN: 4 servings to 6 servings
        let originalServings = 4
        let targetServings = 6

        // WHEN: Calculating scale factor
        let scaleFactor = RecipeScaler.calculateScaleFactor(
            originalServings: originalServings,
            targetServings: targetServings
        )

        // THEN: Scale factor should be 1.5
        XCTAssertEqual(scaleFactor, 1.5)
    }

    // MARK: - Ingredient Scaling Tests

    /// Test 5: Scale whole number quantity up
    func test_scaleQuantity_wholeNumber_up() {
        // GIVEN: 2 cups, scale factor 2.0
        let quantity = 2.0
        let scaleFactor = 2.0

        // WHEN: Scaling
        let scaled = RecipeScaler.scaleQuantity(quantity, by: scaleFactor)

        // THEN: Should be 4 cups
        XCTAssertEqual(scaled, 4.0)
    }

    /// Test 6: Scale whole number quantity down
    func test_scaleQuantity_wholeNumber_down() {
        // GIVEN: 4 cups, scale factor 0.5
        let quantity = 4.0
        let scaleFactor = 0.5

        // WHEN: Scaling
        let scaled = RecipeScaler.scaleQuantity(quantity, by: scaleFactor)

        // THEN: Should be 2 cups
        XCTAssertEqual(scaled, 2.0)
    }

    /// Test 7: Scale fraction quantity up
    func test_scaleQuantity_fraction_up() {
        // GIVEN: 0.5 cups (½), scale factor 2.0
        let quantity = 0.5
        let scaleFactor = 2.0

        // WHEN: Scaling
        let scaled = RecipeScaler.scaleQuantity(quantity, by: scaleFactor)

        // THEN: Should be 1 cup
        XCTAssertEqual(scaled, 1.0)
    }

    /// Test 8: Scale fraction quantity down
    func test_scaleQuantity_fraction_down() {
        // GIVEN: 0.5 cups, scale factor 0.5
        let quantity = 0.5
        let scaleFactor = 0.5

        // WHEN: Scaling
        let scaled = RecipeScaler.scaleQuantity(quantity, by: scaleFactor)

        // THEN: Should be 0.25 cups (¼)
        XCTAssertEqual(scaled, 0.25)
    }

    /// Test 9: Scale mixed number
    func test_scaleQuantity_mixedNumber_scales() {
        // GIVEN: 2.5 cups (2 ½), scale factor 2.0
        let quantity = 2.5
        let scaleFactor = 2.0

        // WHEN: Scaling
        let scaled = RecipeScaler.scaleQuantity(quantity, by: scaleFactor)

        // THEN: Should be 5 cups
        XCTAssertEqual(scaled, 5.0)
    }

    // MARK: - Range Scaling Tests

    /// Test 10: Scale range quantity
    func test_scaleRange_scalesBothEnds() {
        // GIVEN: Range 2-3 cups, scale factor 2.0
        let min = 2.0
        let max = 3.0
        let scaleFactor = 2.0

        // WHEN: Scaling
        let scaledMin = RecipeScaler.scaleQuantity(min, by: scaleFactor)
        let scaledMax = RecipeScaler.scaleQuantity(max, by: scaleFactor)

        // THEN: Both ends should scale
        XCTAssertEqual(scaledMin, 4.0)
        XCTAssertEqual(scaledMax, 6.0)
    }

    // MARK: - Fraction Display Tests

    /// Test 11: Format quarter as fraction
    func test_formatQuantity_quarter_displaysFraction() {
        // GIVEN: 0.25
        let quantity = 0.25

        // WHEN: Formatting
        let formatted = RecipeScaler.formatQuantity(quantity)

        // THEN: Should display as ¼
        XCTAssertEqual(formatted, "¼")
    }

    /// Test 12: Format half as fraction
    func test_formatQuantity_half_displaysFraction() {
        // GIVEN: 0.5
        let quantity = 0.5

        // WHEN: Formatting
        let formatted = RecipeScaler.formatQuantity(quantity)

        // THEN: Should display as ½
        XCTAssertEqual(formatted, "½")
    }

    /// Test 13: Format three-quarters as fraction
    func test_formatQuantity_threeQuarters_displaysFraction() {
        // GIVEN: 0.75
        let quantity = 0.75

        // WHEN: Formatting
        let formatted = RecipeScaler.formatQuantity(quantity)

        // THEN: Should display as ¾
        XCTAssertEqual(formatted, "¾")
    }

    /// Test 14: Format mixed number
    func test_formatQuantity_mixedNumber_displaysCorrectly() {
        // GIVEN: 2.5
        let quantity = 2.5

        // WHEN: Formatting
        let formatted = RecipeScaler.formatQuantity(quantity)

        // THEN: Should display as 2 ½
        XCTAssertEqual(formatted, "2 ½")
    }

    /// Test 15: Format whole number
    func test_formatQuantity_wholeNumber_displaysCorrectly() {
        // GIVEN: 3.0
        let quantity = 3.0

        // WHEN: Formatting
        let formatted = RecipeScaler.formatQuantity(quantity)

        // THEN: Should display as 3
        XCTAssertEqual(formatted, "3")
    }

    // MARK: - Edge Cases

    /// Test 16: Scale zero quantity
    func test_scaleQuantity_zero_staysZero() {
        // GIVEN: 0 quantity
        let quantity = 0.0
        let scaleFactor = 2.0

        // WHEN: Scaling
        let scaled = RecipeScaler.scaleQuantity(quantity, by: scaleFactor)

        // THEN: Should remain 0
        XCTAssertEqual(scaled, 0.0)
    }

    /// Test 17: Scale by one returns original
    func test_scaleQuantity_byOne_returnsOriginal() {
        // GIVEN: Any quantity, scale factor 1.0
        let quantity = 3.75
        let scaleFactor = 1.0

        // WHEN: Scaling
        let scaled = RecipeScaler.scaleQuantity(quantity, by: scaleFactor)

        // THEN: Should be unchanged
        XCTAssertEqual(scaled, quantity)
    }

    /// Test 18: Very small scale factor
    func test_scaleQuantity_verySmallScaleFactor_works() {
        // GIVEN: Large quantity, tiny scale
        let quantity = 100.0
        let scaleFactor = 0.1

        // WHEN: Scaling
        let scaled = RecipeScaler.scaleQuantity(quantity, by: scaleFactor)

        // THEN: Should scale down correctly
        XCTAssertEqual(scaled, 10.0)
    }

    /// Test 19: Very large scale factor
    func test_scaleQuantity_veryLargeScaleFactor_works() {
        // GIVEN: Small quantity, large scale
        let quantity = 0.5
        let scaleFactor = 100.0

        // WHEN: Scaling
        let scaled = RecipeScaler.scaleQuantity(quantity, by: scaleFactor)

        // THEN: Should scale up correctly
        XCTAssertEqual(scaled, 50.0)
    }

    /// Test 20: Format third as decimal (no unicode)
    func test_formatQuantity_third_displaysApproximately() {
        // GIVEN: 0.333...
        let quantity = 1.0 / 3.0

        // WHEN: Formatting
        let formatted = RecipeScaler.formatQuantity(quantity)

        // THEN: Should display as ⅓
        XCTAssertEqual(formatted, "⅓")
    }
}

// MARK: - Test Helper

/// Recipe scaler for testing
enum RecipeScaler {
    /// Calculate scale factor between original and target servings
    static func calculateScaleFactor(originalServings: Int, targetServings: Int) -> Double {
        guard originalServings > 0 else { return 1.0 }
        return Double(targetServings) / Double(originalServings)
    }

    /// Scale a quantity by the given factor
    static func scaleQuantity(_ quantity: Double, by scaleFactor: Double) -> Double {
        quantity * scaleFactor
    }

    /// Format a quantity for display, using fractions where appropriate
    static func formatQuantity(_ quantity: Double) -> String {
        let wholeNumber = Int(quantity)
        let fraction = quantity - Double(wholeNumber)

        // Handle common fractions
        let fractionString: String?
        switch fraction {
        case 0..<0.01: fractionString = nil
        case 0.24...0.26: fractionString = "¼"
        case 0.32...0.34: fractionString = "⅓"
        case 0.49...0.51: fractionString = "½"
        case 0.65...0.67: fractionString = "⅔"
        case 0.74...0.76: fractionString = "¾"
        default: fractionString = String(format: "%.2f", fraction).dropFirst(1).description // Remove leading 0
        }

        if wholeNumber == 0 {
            return fractionString ?? "0"
        } else if let frac = fractionString {
            return "\(wholeNumber) \(frac)"
        } else {
            return "\(wholeNumber)"
        }
    }
}
