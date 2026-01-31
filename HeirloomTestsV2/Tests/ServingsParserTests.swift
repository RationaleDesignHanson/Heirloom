//
//  ServingsParserTests.swift
//  HeirloomTestsV2
//
//  Created by Claude on 2026-01-30.
//

import XCTest
@testable import Heirloom

/// Tests for ServingsParser multi-strategy parsing
final class ServingsParserTests: XCTestCase {

    // MARK: - Basic Formats

    func testBasicServings() {
        XCTAssertEqual(ServingsParser.parse("6 servings"), 6)
        XCTAssertEqual(ServingsParser.parse("Serves 4"), 4)
        XCTAssertEqual(ServingsParser.parse("Makes 12 cookies"), 12)
        XCTAssertEqual(ServingsParser.parse("8 servings"), 8)
        XCTAssertEqual(ServingsParser.parse("SERVES 10"), 10) // Case insensitive
    }

    // MARK: - Keyword Extraction

    func testKeywordExtraction() {
        XCTAssertEqual(ServingsParser.parse("Serves 4 people"), 4)
        XCTAssertEqual(ServingsParser.parse("Makes 24 cupcakes"), 24)
        XCTAssertEqual(ServingsParser.parse("Yield: 8 portions"), 8)
        XCTAssertEqual(ServingsParser.parse("6 portions"), 6)
    }

    // MARK: - Ranges

    func testServingsWithRanges() {
        // Should extract first number in range
        XCTAssertEqual(ServingsParser.parse("Serves 4-6 people"), 4)
        XCTAssertEqual(ServingsParser.parse("4 to 6 servings"), 4)
        XCTAssertEqual(ServingsParser.parse("Makes 8-10 cookies"), 8)
    }

    // MARK: - Dozen Unit

    func testDozens() {
        XCTAssertEqual(ServingsParser.parse("Makes 2 dozen"), 24)
        XCTAssertEqual(ServingsParser.parse("1 dozen cookies"), 12)
        XCTAssertEqual(ServingsParser.parse("3 dozen muffins"), 36)
        XCTAssertEqual(ServingsParser.parse("Makes 1 dozen"), 12)
    }

    // MARK: - Edge Cases

    func testEdgeCases() {
        XCTAssertEqual(ServingsParser.parse("Yield: 8 portions"), 8)
        XCTAssertEqual(ServingsParser.parse("About 20 cookies"), 20)
        XCTAssertEqual(ServingsParser.parse("Approximately 6 servings"), 6)
        XCTAssertEqual(ServingsParser.parse("1 9-inch pie"), 1) // Should extract 1, not 9
    }

    // MARK: - Temperature Filtering

    func testFiltersOutTemperatures() {
        // Should not return temperature values
        XCTAssertNotEqual(ServingsParser.parse("Bake at 350°F for 30 minutes, serves 6"), 350)
        XCTAssertEqual(ServingsParser.parse("Bake at 350°F for 30 minutes, serves 6"), 6)

        XCTAssertNotEqual(ServingsParser.parse("Heat to 400 degrees, makes 4 servings"), 400)
        XCTAssertEqual(ServingsParser.parse("Heat to 400 degrees, makes 4 servings"), 4)
    }

    // MARK: - Year Filtering

    func testFiltersOutYears() {
        // Should not return year values
        XCTAssertNotEqual(ServingsParser.parse("Recipe from 2020, serves 8"), 2020)
        XCTAssertEqual(ServingsParser.parse("Recipe from 2020, serves 8"), 8)
    }

    // MARK: - Invalid Inputs

    func testInvalidInputs() {
        XCTAssertNil(ServingsParser.parse(nil))
        XCTAssertNil(ServingsParser.parse(""))
        XCTAssertNil(ServingsParser.parse("No numbers here"))
        XCTAssertNil(ServingsParser.parse("Just text"))
    }

    // MARK: - Sanity Checks

    func testReasonableRange() {
        // Should not return numbers > 200
        XCTAssertNil(ServingsParser.parse("250 servings")) // Unreasonable
        XCTAssertEqual(ServingsParser.parse("200 servings"), 200) // Boundary
        XCTAssertEqual(ServingsParser.parse("1 serving"), 1) // Minimum
    }

    // MARK: - Real-World Examples

    func testRealWorldExamples() {
        // Common recipe site formats
        XCTAssertEqual(ServingsParser.parse("Servings: 4"), 4)
        XCTAssertEqual(ServingsParser.parse("Serves: 6-8"), 6)
        XCTAssertEqual(ServingsParser.parse("Yield: 2 dozen cookies"), 24)
        XCTAssertEqual(ServingsParser.parse("Makes about 12"), 12)
        XCTAssertEqual(ServingsParser.parse("4 people"), 4)

        // NYT Cooking format
        XCTAssertEqual(ServingsParser.parse("Yield 8 servings"), 8)

        // AllRecipes format
        XCTAssertEqual(ServingsParser.parse("12 servings"), 12)

        // Food Network format
        XCTAssertEqual(ServingsParser.parse("Servings: 6 to 8"), 6)
    }

    // MARK: - Strategy Priority

    func testStrategyPriority() {
        // Keyword extraction should take priority over raw number extraction
        XCTAssertEqual(ServingsParser.parse("350 degrees, serves 6"), 6) // Not 350
        XCTAssertEqual(ServingsParser.parse("Recipe #12, makes 6 servings"), 6) // Not 12
    }
}
