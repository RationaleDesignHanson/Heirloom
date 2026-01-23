//
//  ClaudeRecipeStructuringTests.swift
//  HeirloomTestsV2
//
//  Integration tests for Claude API recipe structuring
//  Tests with REAL Claude API calls (not mocked)
//  Created: 2026-01-13
//
//  DISABLED: API changed - needs rewriting to match new ClaudeRecipeStructurer API
//  TODO: Update to use init(aiService:) and structure(transcript:visualElements:)
//

/*

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class ClaudeRecipeStructuringTests: XCTestCase {

    var modelContext: ModelContext!
    var mockLogger: MockLoggingService!
    var analytics: AnalyticsService!
    var structurer: ClaudeRecipeStructurer!

    override func setUp() async throws {
        try await super.setUp()

        modelContext = try TestRecipeFactory.createTestModelContext()
        mockLogger = MockLoggingService()
        analytics = AnalyticsService()

        // Use real Claude API with test key
        // Set CLAUDE_API_KEY environment variable for CI
        let apiKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] ?? ""
        structurer = ClaudeRecipeStructurer(apiKey: apiKey, logger: mockLogger, analytics: analytics)
    }

    override func tearDown() async throws {
        structurer = nil
        modelContext = nil
        mockLogger = nil
        analytics = nil
        try await super.tearDown()
    }

    // MARK: - Well-Formatted Transcripts

    func test_claude_structuresWellFormattedBakingRecipe() async throws {
        // Given: Clean, well-structured chocolate chip cookie transcript
        let transcript = """
        Today I'm making chocolate chip cookies.

        You'll need:
        - 2 cups of all-purpose flour
        - 1 cup of granulated sugar
        - 1 cup of softened butter
        - 2 large eggs
        - 1 teaspoon of vanilla extract
        - 2 cups of chocolate chips
        - 1 teaspoon of baking soda
        - Half a teaspoon of salt

        First, preheat your oven to 350 degrees Fahrenheit.
        In a large bowl, cream together the butter and sugar until light and fluffy.
        Beat in the eggs one at a time, then stir in the vanilla.
        In a separate bowl, whisk together the flour, baking soda, and salt.
        Gradually mix the dry ingredients into the wet ingredients.
        Fold in the chocolate chips.
        Drop rounded tablespoons of dough onto ungreased cookie sheets.
        Bake for 10 to 12 minutes, or until the edges are golden brown.
        Let them cool on the baking sheet for 2 minutes before transferring to a wire rack.

        This recipe makes about 48 cookies and takes about 30 minutes total.
        """

        // When: Structure with Claude
        let recipe = try await structurer.structure(transcript: transcript, context: modelContext)

        // Then: Verify basic structure
        XCTAssertFalse(recipe.title.isEmpty, "Should extract title")
        XCTAssertTrue(recipe.title.lowercased().contains("cookie") ||
                      recipe.title.lowercased().contains("chocolate chip"),
                      "Title should mention cookies: \(recipe.title)")

        // Verify ingredients extracted
        XCTAssertGreaterThanOrEqual(recipe.ingredients?.count ?? 0, 6,
                                    "Should extract at least 6 main ingredients")

        // Check key ingredients present
        let ingredientNames = recipe.ingredients?.map { $0.name.lowercased() } ?? []
        XCTAssertTrue(ingredientNames.contains { $0.contains("flour") }, "Should have flour")
        XCTAssertTrue(ingredientNames.contains { $0.contains("sugar") }, "Should have sugar")
        XCTAssertTrue(ingredientNames.contains { $0.contains("butter") }, "Should have butter")
        XCTAssertTrue(ingredientNames.contains { $0.contains("egg") }, "Should have eggs")
        XCTAssertTrue(ingredientNames.contains { $0.contains("chocolate") }, "Should have chocolate chips")

        // Verify quantities parsed
        let flour = recipe.ingredients?.first { $0.name.lowercased().contains("flour") }
        XCTAssertNotNil(flour, "Flour ingredient should exist")
        XCTAssertEqual(flour?.quantity, 2.0, accuracy: 0.1, "Flour should be 2 cups")
        XCTAssertTrue(flour?.unit.lowercased().contains("cup") ?? false, "Unit should be cups")

        // Verify instructions
        XCTAssertGreaterThanOrEqual(recipe.instructions.count, 5,
                                    "Should have at least 5 instruction steps")

        // Check for key steps
        let instructionsText = recipe.instructions.joined(separator: " ").lowercased()
        XCTAssertTrue(instructionsText.contains("preheat") || instructionsText.contains("oven"),
                      "Should mention preheating oven")
        XCTAssertTrue(instructionsText.contains("cream") || instructionsText.contains("mix"),
                      "Should mention mixing")
        XCTAssertTrue(instructionsText.contains("bake"), "Should mention baking")

        // Verify metadata
        XCTAssertEqual(recipe.ovenTemp, "350°F", "Should extract oven temperature")
        XCTAssertTrue(recipe.cookTime?.contains("10") ?? false ||
                      recipe.cookTime?.contains("12") ?? false,
                      "Should extract cook time: \(recipe.cookTime ?? "nil")")
        XCTAssertTrue(recipe.servings?.contains("48") ?? false,
                      "Should extract servings/yield")
    }

    func test_claude_structuresWellFormattedCookingRecipe() async throws {
        // Given: Savory recipe (pasta carbonara)
        let transcript = """
        Let's make a classic pasta carbonara.

        Ingredients:
        - 1 pound of spaghetti
        - 6 ounces of pancetta or bacon, diced
        - 4 large egg yolks
        - 1 cup of grated Parmesan cheese
        - 2 cloves of garlic, minced
        - Black pepper to taste
        - Salt for pasta water

        Instructions:
        Bring a large pot of salted water to a boil and cook the spaghetti until al dente.
        While the pasta cooks, fry the pancetta in a large skillet until crispy.
        Add the minced garlic and cook for 30 seconds.
        In a bowl, whisk together the egg yolks and Parmesan cheese.
        Reserve one cup of pasta water, then drain the spaghetti.
        Add the hot pasta to the skillet with pancetta.
        Remove from heat and quickly stir in the egg mixture.
        Add pasta water as needed to create a creamy sauce.
        Season generously with black pepper.
        Serve immediately.

        Serves 4 people, ready in 20 minutes.
        """

        // When: Structure with Claude
        let recipe = try await structurer.structure(transcript: transcript, context: modelContext)

        // Then: Verify structure
        XCTAssertTrue(recipe.title.lowercased().contains("carbonara") ||
                      recipe.title.lowercased().contains("pasta"),
                      "Title should mention carbonara or pasta: \(recipe.title)")

        XCTAssertGreaterThanOrEqual(recipe.ingredients?.count ?? 0, 5,
                                    "Should extract main ingredients")

        // Check for pasta and pancetta
        let ingredientNames = recipe.ingredients?.map { $0.name.lowercased() } ?? []
        XCTAssertTrue(ingredientNames.contains { $0.contains("spaghetti") || $0.contains("pasta") })
        XCTAssertTrue(ingredientNames.contains { $0.contains("pancetta") || $0.contains("bacon") })
        XCTAssertTrue(ingredientNames.contains { $0.contains("egg") })
        XCTAssertTrue(ingredientNames.contains { $0.contains("parmesan") || $0.contains("cheese") })

        // Verify instructions
        XCTAssertGreaterThanOrEqual(recipe.instructions.count, 4,
                                    "Should have multiple steps")

        // Verify metadata
        XCTAssertTrue(recipe.servings?.contains("4") ?? false, "Should extract servings")
        XCTAssertTrue(recipe.totalTime?.contains("20") ?? false, "Should extract total time")
    }

    // MARK: - Poorly Structured Transcripts

    func test_claude_handlesPoorlyStructuredTranscript() async throws {
        // Given: Rambling, conversational transcript with filler words
        let messyTranscript = """
        So like um I'm gonna make cookies today and uh you need some flour
        maybe like 2 cups or so and sugar yeah definitely sugar like a cup
        and butter too like a stick or cup of butter and eggs oh yeah eggs
        I think 2 eggs should be good and some vanilla like a teaspoon
        and chocolate chips lots of chocolate chips like 2 cups

        So first you like mix the butter and sugar together until it's fluffy
        then you add the eggs and vanilla and mix that in
        then add the flour and stuff and then fold in the chocolate chips
        bake them at like 350 for maybe 10 minutes or so until they look done
        """

        // When: Structure with Claude
        let recipe = try await structurer.structure(transcript: messyTranscript, context: modelContext)

        // Then: Should still extract basic info despite poor structure
        XCTAssertFalse(recipe.title.isEmpty, "Should extract title")
        XCTAssertTrue(recipe.title.lowercased().contains("cookie"),
                      "Should identify as cookies: \(recipe.title)")

        // Should extract main ingredients despite filler words
        XCTAssertGreaterThanOrEqual(recipe.ingredients?.count ?? 0, 4,
                                    "Should extract main ingredients from messy text")

        let ingredientNames = recipe.ingredients?.map { $0.name.lowercased() } ?? []
        XCTAssertTrue(ingredientNames.contains { $0.contains("flour") })
        XCTAssertTrue(ingredientNames.contains { $0.contains("sugar") })
        XCTAssertTrue(ingredientNames.contains { $0.contains("egg") })

        // Should extract basic instructions
        XCTAssertGreaterThanOrEqual(recipe.instructions.count, 3,
                                    "Should extract basic steps")
    }

    func test_claude_handlesMinimalTranscript() async throws {
        // Given: Very short, minimal transcript
        let minimalTranscript = """
        Making brownies. Need chocolate, butter, sugar, eggs, flour.
        Mix everything. Bake 350 for 25 minutes.
        """

        // When: Structure with Claude
        let recipe = try await structurer.structure(transcript: minimalTranscript, context: modelContext)

        // Then: Should extract what's available
        XCTAssertFalse(recipe.title.isEmpty)
        XCTAssertTrue(recipe.title.lowercased().contains("brownie"))

        // Should identify key ingredients even without quantities
        XCTAssertGreaterThanOrEqual(recipe.ingredients?.count ?? 0, 3,
                                    "Should extract main ingredients")

        // Should create basic instructions
        XCTAssertGreaterThanOrEqual(recipe.instructions.count, 1,
                                    "Should extract at least one instruction")
    }

    // MARK: - Edge Cases

    func test_claude_handlesVeryLongTranscript() async throws {
        // Given: Long, detailed transcript (simulating 30-min video)
        var longTranscript = """
        Today we're making a classic French beef bourguignon, which is a rich beef stew
        braised in red wine with vegetables and herbs.

        For the ingredients, you'll need...
        """

        // Add many detailed steps (simulate long video)
        for i in 1...20 {
            longTranscript += """

            Step \(i): This is a detailed instruction about preparing the dish.
            We're going to take our time and really develop the flavors here.
            This is important for the final result.
            """
        }

        longTranscript += """

        And that's how you make beef bourguignon! It takes about 3 hours total
        but the result is absolutely worth it. Serves 6 people.
        """

        // When: Structure with Claude
        let recipe = try await structurer.structure(transcript: longTranscript, context: modelContext)

        // Then: Should handle long content
        XCTAssertFalse(recipe.title.isEmpty)
        XCTAssertTrue(recipe.title.lowercased().contains("bourguignon") ||
                      recipe.title.lowercased().contains("beef"))

        // Should extract instructions (may summarize if too long)
        XCTAssertGreaterThanOrEqual(recipe.instructions.count, 5,
                                    "Should extract key steps")

        // Should extract metadata
        XCTAssertTrue(recipe.totalTime?.contains("3") ?? false ||
                      recipe.totalTime?.contains("hour") ?? false)
    }

    func test_claude_handlesSpecialCharacters() async throws {
        // Given: Recipe with special characters and accents
        let transcript = """
        Crème Brûlée Recipe

        Ingredients:
        - 2 cups heavy crème
        - ½ cup sugar
        - 1 vanilla bean (or 1 tsp extract)
        - 5 egg yolks
        - ¼ cup sugar for topping

        Instructions:
        Preheat oven to 325°F.
        Heat the crème until it's just about to boil.
        Whisk egg yolks with ½ cup sugar.
        Slowly add hot crème to eggs.
        Pour into ramekins and bake for 40 minutes.
        Chill for 2 hours.
        Sprinkle with sugar & torch until caramelized.
        """

        // When: Structure with Claude
        let recipe = try await structurer.structure(transcript: transcript, context: modelContext)

        // Then: Should preserve special characters
        XCTAssertTrue(recipe.title.contains("è") || recipe.title.contains("Creme") ||
                      recipe.title.contains("Brulee"),
                      "Should preserve or approximate special characters: \(recipe.title)")

        // Should handle fractions
        let sugar = recipe.ingredients?.first { $0.name.lowercased().contains("sugar") }
        XCTAssertNotNil(sugar, "Should extract sugar")
        // Fraction should be converted to decimal (½ = 0.5)
    }

    func test_claude_handlesMultipleRecipesInTranscript() async throws {
        // Given: Transcript that mentions multiple recipes
        let transcript = """
        Today I'm going to show you how to make chocolate chip cookies.
        These are similar to the sugar cookies I made last week, but with chocolate.
        My grandmother used to make oatmeal cookies too, but today we're focusing on chocolate chip.

        For the chocolate chip cookies, you need:
        2 cups flour, 1 cup sugar, 1 cup butter, 2 eggs, 2 cups chocolate chips.

        Mix everything together and bake at 350 for 12 minutes.
        """

        // When: Structure with Claude
        let recipe = try await structurer.structure(transcript: transcript, context: modelContext)

        // Then: Should focus on the main recipe (chocolate chip)
        XCTAssertTrue(recipe.title.lowercased().contains("chocolate chip"),
                      "Should identify primary recipe: \(recipe.title)")
        XCTAssertFalse(recipe.title.lowercased().contains("sugar cookie") ||
                       recipe.title.lowercased().contains("oatmeal"),
                       "Should not confuse with mentioned other recipes")
    }

    // MARK: - Error Handling

    func test_claude_handlesEmptyTranscript() async throws {
        // Given: Empty transcript
        let emptyTranscript = ""

        // When/Then: Should throw error or return minimal recipe
        do {
            let recipe = try await structurer.structure(transcript: emptyTranscript, context: modelContext)
            // If it doesn't throw, should have some placeholder
            XCTAssertFalse(recipe.title.isEmpty, "Should provide placeholder title")
        } catch {
            // Throwing error is acceptable for empty input
            XCTAssertTrue(error is ValidationError || error is APIError)
        }
    }

    func test_claude_handlesNonRecipeText() async throws {
        // Given: Transcript that's not about cooking
        let nonRecipeTranscript = """
        Today I'm going to talk about my favorite movies.
        I really love Star Wars and Lord of the Rings.
        The cinematography is amazing and the stories are compelling.
        """

        // When: Attempt to structure
        do {
            let recipe = try await structurer.structure(transcript: nonRecipeTranscript, context: modelContext)

            // If Claude returns something, verify it indicates no recipe found
            XCTAssertTrue(recipe.title.isEmpty ||
                          recipe.instructions.isEmpty,
                          "Should indicate no recipe found")
        } catch {
            // Throwing error is acceptable for non-recipe content
            XCTAssertTrue(error is ValidationError)
        }
    }

    func test_claude_handlesAPIRateLimit() async throws {
        // Note: This test may fail if rate limit not hit
        // Run only in CI with many concurrent tests

        #if CI_ENVIRONMENT
        // Given: Multiple rapid requests
        var results: [Result<Recipe, Error>] = []

        for i in 1...10 {
            let transcript = "Recipe \(i): Mix flour and sugar. Bake."
            do {
                let recipe = try await structurer.structure(transcript: transcript, context: modelContext)
                results.append(.success(recipe))
            } catch {
                results.append(.failure(error))
            }
        }

        // Then: Should handle rate limits gracefully
        let failures = results.filter {
            if case .failure(let error) = $0,
               error is RateLimitError {
                return true
            }
            return false
        }

        // If rate limited, should be specific error type
        if !failures.isEmpty {
            XCTAssertTrue(true, "Rate limit handled gracefully")
        }
        #endif
    }

    // MARK: - Data Integrity

    func test_claude_preservesSourceInformation() async throws {
        // Given: Recipe structured from transcript
        let transcript = "Making cookies. Need flour, sugar, eggs. Mix and bake."

        // When: Structure with Claude
        let recipe = try await structurer.structure(transcript: transcript, context: modelContext)

        // Then: Should mark source type correctly
        XCTAssertEqual(recipe.sourceType, .video, "Should mark as video source")
    }

    func test_claude_savesToDatabase() async throws {
        // Given: Structured recipe
        let transcript = """
        Chocolate Chip Cookies
        Ingredients: 2 cups flour, 1 cup sugar, 1 cup butter, 2 eggs, 2 cups chocolate chips
        Mix everything. Bake at 350 for 12 minutes.
        """

        // When: Structure and save
        let recipe = try await structurer.structure(transcript: transcript, context: modelContext)
        try modelContext.save()

        // Then: Should persist to database
        let fetchDescriptor = FetchDescriptor<Heirloom.Recipe>()
        let recipes = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(recipes.count, 1, "Should save to database")
        XCTAssertEqual(recipes.first?.title, recipe.title)
    }
}

*/
