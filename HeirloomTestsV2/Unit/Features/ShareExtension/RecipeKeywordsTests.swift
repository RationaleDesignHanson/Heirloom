//
//  RecipeKeywordsTests.swift
//  HeirloomTestsV2
//
//  Tests for recipe relevance scoring using keyword matching
//  Created: 2026-01-20
//

import XCTest
@testable import Heirloom

@MainActor
final class RecipeKeywordsTests: XCTestCase {

    // MARK: - High Relevance Tests

    func test_recipeTranscript_highRelevanceScore() {
        // Given: Transcript with many recipe keywords (ingredients, cooking verbs, measurements)
        let transcript = """
        Add two cups of flour and one teaspoon of salt.
        Mix in the eggs and butter. Preheat the oven to 350 degrees.
        Bake for 30 minutes until golden brown.
        """

        // When: Calculate relevance score
        let score = RecipeKeywords.relevanceScore(for: transcript)

        // Then: Should be high relevance (>50%)
        XCTAssertGreaterThan(score, 0.5, "Recipe transcript should have high relevance score")
    }

    func test_ingredientList_highRelevanceScore() {
        // Given: Text with many ingredients
        let ingredients = """
        2 cups all-purpose flour
        1 teaspoon salt
        3 eggs
        1/2 cup butter
        1 tablespoon vanilla extract
        """

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: ingredients)

        // Then: Should be high relevance
        XCTAssertGreaterThan(score, 0.4, "Ingredient list should have high relevance")
    }

    func test_cookingInstructions_highRelevanceScore() {
        // Given: Cooking instructions with verbs and measurements
        let instructions = """
        Whisk together the flour and salt.
        Beat the eggs and gradually add to the mixture.
        Stir in melted butter and vanilla.
        Bake at 350°F for 25-30 minutes.
        """

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: instructions)

        // Then: Should be high relevance
        XCTAssertGreaterThan(score, 0.5, "Cooking instructions should have high relevance")
    }

    // MARK: - Low Relevance Tests

    func test_nonRecipeText_lowRelevanceScore() {
        // Given: Text with no recipe keywords
        let nonRecipe = """
        Today we're going to talk about the weather.
        The sun is shining and birds are singing.
        It's a beautiful day outside.
        """

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: nonRecipe)

        // Then: Should be very low relevance (<15%)
        XCTAssertLessThan(score, 0.15, "Non-recipe text should have low relevance")
    }

    func test_newsArticle_lowRelevanceScore() {
        // Given: News article text
        let news = """
        The stock market rose today by 2%.
        Technology companies led the gains.
        Analysts expect continued growth next quarter.
        """

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: news)

        // Then: Should be very low relevance
        XCTAssertLessThan(score, 0.1, "News article should have very low relevance")
    }

    // MARK: - Edge Cases

    func test_emptyString_zeroRelevance() {
        // Given: Empty string
        let empty = ""

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: empty)

        // Then: Should be exactly zero
        XCTAssertEqual(score, 0, "Empty string should have zero relevance")
    }

    func test_whitespaceOnly_zeroRelevance() {
        // Given: Whitespace only
        let whitespace = "   \n\t  \n  "

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: whitespace)

        // Then: Should be zero or very close to zero
        XCTAssertLessThan(score, 0.01, "Whitespace should have near-zero relevance")
    }

    func test_singleWord_appropriateScore() {
        // Given: Single recipe word
        let singleWord = "flour"

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: singleWord)

        // Then: Should have some relevance but not high
        XCTAssertGreaterThan(score, 0, "Single recipe word should have some relevance")
        XCTAssertLessThan(score, 0.5, "Single word should not have high relevance")
    }

    // MARK: - Unicode and Special Characters

    func test_unicodeText_handledGracefully() {
        // Given: Text with emoji and unicode
        let unicodeText = "🍕 Add 2️⃣ cups of 小麦粉 (flour) and mix 🥣"

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: unicodeText)

        // Then: Should not crash and should detect "flour"
        XCTAssertGreaterThan(score, 0, "Should handle unicode text and detect flour")
    }

    func test_mixedLanguage_englishKeywordsDetected() {
        // Given: Mixed language text with English recipe words
        let mixedText = "Mezcla 2 cups de flour con salt y water"

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: mixedText)

        // Then: Should detect English keywords
        XCTAssertGreaterThan(score, 0.2, "Should detect English keywords in mixed text")
    }

    func test_specialCharacters_handledCorrectly() {
        // Given: Text with special characters
        let specialChars = "Add 1/2 cup sugar & 3-4 eggs (beaten) to the mixture; stir well!"

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: specialChars)

        // Then: Should detect keywords despite special chars
        XCTAssertGreaterThan(score, 0.3, "Should handle special characters")
    }

    // MARK: - Case Sensitivity

    func test_mixedCase_detectedCorrectly() {
        // Given: Text with mixed case
        let mixedCase = "ADD two CUPS of FLOUR and one TEASPOON of SALT"

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: mixedCase)

        // Then: Should detect keywords regardless of case
        XCTAssertGreaterThan(score, 0.5, "Should be case-insensitive")
    }

    func test_allUppercase_detectedCorrectly() {
        // Given: All uppercase text
        let uppercase = "MIX FLOUR, EGGS, AND BUTTER. BAKE FOR 30 MINUTES."

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: uppercase)

        // Then: Should detect keywords
        XCTAssertGreaterThan(score, 0.4, "Should handle all uppercase")
    }

    // MARK: - Boundary Testing

    func test_extremelyLongText_handledEfficiently() {
        // Given: Very long text (10,000 words of recipe content)
        let recipeChunk = "Add flour and sugar. Mix well. Bake for 30 minutes. "
        let longText = String(repeating: recipeChunk, count: 200)

        // When: Calculate relevance (should not timeout)
        let startTime = Date()
        let score = RecipeKeywords.relevanceScore(for: longText)
        let duration = Date().timeIntervalSince(startTime)

        // Then: Should complete quickly (<1 second) and have high relevance
        XCTAssertLessThan(duration, 1.0, "Should process long text efficiently")
        XCTAssertGreaterThan(score, 0.5, "Long recipe text should have high relevance")
    }

    func test_partialMatch_contributesToScore() {
        // Given: Text with partial keyword matches
        let partial = "flowing through the mixing process"

        // When: Calculate relevance
        let score = RecipeKeywords.relevanceScore(for: partial)

        // Then: Should have some relevance (contains "mix")
        XCTAssertGreaterThan(score, 0, "Partial matches should contribute to score")
    }
}
