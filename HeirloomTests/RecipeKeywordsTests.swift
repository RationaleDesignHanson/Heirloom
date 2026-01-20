import XCTest
@testable import Heirloom

final class RecipeKeywordsTests: XCTestCase {

    func testHighRelevanceTranscript() {
        let transcript = """
        Add two cups of flour and one teaspoon of salt.
        Mix in the eggs and butter. Preheat the oven to 350 degrees.
        Bake for 30 minutes until golden brown.
        """

        let score = RecipeKeywords.relevanceScore(for: transcript)
        XCTAssertGreaterThan(score, 0.5)
    }

    func testLowRelevanceTranscript() {
        let transcript = """
        Today we're going to talk about the weather.
        The sun is shining and birds are singing.
        """

        let score = RecipeKeywords.relevanceScore(for: transcript)
        XCTAssertLessThan(score, 0.15)
    }

    func testEmptyTranscript() {
        let score = RecipeKeywords.relevanceScore(for: "")
        XCTAssertEqual(score, 0)
    }
}
