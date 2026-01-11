import Testing
import Foundation
import SwiftData

@testable import Heirloom

@Suite("Dinner Party Tests")
struct DinnerPartyTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: [Recipe.self, DinnerParty.self, DinnerPartyRecipe.self, Ingredient.self, Tag.self, RecipeCollection.self],
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - DinnerParty Initialization Tests

    @Test("DinnerParty initializes with required fields")
    func testDinnerParty_Init_WithRequiredFields() {
        // Arrange
        let mealTime = Date(timeIntervalSinceNow: 3600)

        // Act
        let party = DinnerParty(name: "Family Dinner", mealTime: mealTime)

        // Assert
        #expect(party.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(party.name == "Family Dinner")
        #expect(party.mealTime == mealTime)
        #expect(party.guestCount == 4)
        #expect(party.desc == nil)
        #expect(party.isActive == false)
    }

    @Test("DinnerParty initializes with description")
    func testDinnerParty_Init_WithDescription() {
        // Act
        let party = DinnerParty(
            name: "Birthday Party",
            description: "Celebrating Mom's 60th",
            mealTime: Date()
        )

        // Assert
        #expect(party.desc == "Celebrating Mom's 60th")
    }

    @Test("DinnerParty initializes with custom guest count")
    func testDinnerParty_Init_WithCustomGuestCount() {
        // Act
        let party = DinnerParty(
            name: "Dinner Party",
            guestCount: 12,
            mealTime: Date()
        )

        // Assert
        #expect(party.guestCount == 12)
    }

    @Test("DinnerParty sets timestamps on initialization")
    func testDinnerParty_Init_SetsTimestamps() {
        // Arrange
        let before = Date()

        // Act
        let party = DinnerParty(name: "Test", mealTime: Date())

        // Assert
        #expect(party.createdDate >= before)
        #expect(party.lastModified >= before)
    }

    @Test("DinnerParty initializes with empty recipes array")
    func testDinnerParty_Init_EmptyRecipes() {
        // Act
        let party = DinnerParty(name: "Test", mealTime: Date())

        // Assert
        #expect(party.recipes?.count == 0)
    }

    // MARK: - DinnerParty Computed Properties Tests

    @Test("DinnerParty recipeCount returns zero for empty party")
    func testDinnerParty_RecipeCount_EmptyParty() {
        // Arrange
        let party = DinnerParty(name: "Test", mealTime: Date())

        // Assert
        #expect(party.recipeCount == 0)
    }

    @Test("DinnerParty recipeCount returns correct count")
    func testDinnerParty_RecipeCount_WithRecipes() {
        // Arrange
        let context = createTestContext()
        let party = DinnerParty(name: "Test", mealTime: Date())
        context.insert(party)

        let recipe1 = Heirloom.Recipe(title: "Recipe 1", instructions: [])
        let recipe2 = Heirloom.Recipe(title: "Recipe 2", instructions: [])
        context.insert(recipe1)
        context.insert(recipe2)

        let dpRecipe1 = DinnerPartyRecipe(recipe: recipe1, startTimeOffset: 30)
        let dpRecipe2 = DinnerPartyRecipe(recipe: recipe2, startTimeOffset: 60)
        dpRecipe1.dinnerParty = party
        dpRecipe2.dinnerParty = party
        context.insert(dpRecipe1)
        context.insert(dpRecipe2)

        party.recipes = [dpRecipe1, dpRecipe2]

        // Assert
        #expect(party.recipeCount == 2)
    }

    @Test("DinnerParty totalPrepTime returns zero when no recipes")
    func testDinnerParty_TotalPrepTime_NoRecipes() {
        // Arrange
        let party = DinnerParty(name: "Test", mealTime: Date())

        // Assert
        #expect(party.totalPrepTime == 0)
    }

    @Test("DinnerParty totalPrepTime sums all recipe prep times")
    func testDinnerParty_TotalPrepTime_SumsRecipes() {
        // Arrange
        let context = createTestContext()
        let party = DinnerParty(name: "Test", mealTime: Date())
        context.insert(party)

        let recipe1 = Heirloom.Recipe(title: "Recipe 1", instructions: [])
        recipe1.prepTime = "15 min"
        let recipe2 = Heirloom.Recipe(title: "Recipe 2", instructions: [])
        recipe2.prepTime = "30 min"
        context.insert(recipe1)
        context.insert(recipe2)

        let dpRecipe1 = DinnerPartyRecipe(recipe: recipe1, startTimeOffset: 30)
        let dpRecipe2 = DinnerPartyRecipe(recipe: recipe2, startTimeOffset: 60)
        dpRecipe1.dinnerParty = party
        dpRecipe2.dinnerParty = party
        context.insert(dpRecipe1)
        context.insert(dpRecipe2)

        party.recipes = [dpRecipe1, dpRecipe2]

        // Assert
        #expect(party.totalPrepTime == 45) // 15 + 30
    }

    @Test("DinnerParty totalCookTime returns zero when no recipes")
    func testDinnerParty_TotalCookTime_NoRecipes() {
        // Arrange
        let party = DinnerParty(name: "Test", mealTime: Date())

        // Assert
        #expect(party.totalCookTime == 0)
    }

    @Test("DinnerParty totalCookTime sums all recipe cook times")
    func testDinnerParty_TotalCookTime_SumsRecipes() {
        // Arrange
        let context = createTestContext()
        let party = DinnerParty(name: "Test", mealTime: Date())
        context.insert(party)

        let recipe1 = Heirloom.Recipe(title: "Recipe 1", instructions: [])
        recipe1.cookTime = "20 min"
        let recipe2 = Heirloom.Recipe(title: "Recipe 2", instructions: [])
        recipe2.cookTime = "45 min"
        context.insert(recipe1)
        context.insert(recipe2)

        let dpRecipe1 = DinnerPartyRecipe(recipe: recipe1, startTimeOffset: 30)
        let dpRecipe2 = DinnerPartyRecipe(recipe: recipe2, startTimeOffset: 60)
        dpRecipe1.dinnerParty = party
        dpRecipe2.dinnerParty = party
        context.insert(dpRecipe1)
        context.insert(dpRecipe2)

        party.recipes = [dpRecipe1, dpRecipe2]

        // Assert
        #expect(party.totalCookTime == 65) // 20 + 45
    }

    @Test("DinnerParty earliestStartTime returns nil when no recipes")
    func testDinnerParty_EarliestStartTime_NoRecipes() {
        // Arrange
        let party = DinnerParty(name: "Test", mealTime: Date())

        // Assert
        #expect(party.earliestStartTime == nil)
    }

    @Test("DinnerParty earliestStartTime calculates correctly")
    func testDinnerParty_EarliestStartTime_CalculatesCorrectly() {
        // Arrange
        let context = createTestContext()
        let mealTime = Date(timeIntervalSinceNow: 3600) // 1 hour from now
        let party = DinnerParty(name: "Test", mealTime: mealTime)
        context.insert(party)

        let recipe1 = Heirloom.Recipe(title: "Recipe 1", instructions: [])
        let recipe2 = Heirloom.Recipe(title: "Recipe 2", instructions: [])
        context.insert(recipe1)
        context.insert(recipe2)

        // Recipe 1 starts 30 min before meal
        let dpRecipe1 = DinnerPartyRecipe(recipe: recipe1, startTimeOffset: 30)
        // Recipe 2 starts 60 min before meal (earliest)
        let dpRecipe2 = DinnerPartyRecipe(recipe: recipe2, startTimeOffset: 60)
        dpRecipe1.dinnerParty = party
        dpRecipe2.dinnerParty = party
        context.insert(dpRecipe1)
        context.insert(dpRecipe2)

        party.recipes = [dpRecipe1, dpRecipe2]

        // Act
        let earliestStart = party.earliestStartTime!

        // Assert - Should be 60 minutes before meal time
        let expectedStart = mealTime.addingTimeInterval(-60 * 60)
        #expect(abs(earliestStart.timeIntervalSince(expectedStart)) < 1.0)
    }

    // MARK: - DinnerParty Status Tests

    @Test("DinnerParty isUpcoming returns true when start time is future")
    func testDinnerParty_IsUpcoming_FutureStartTime() {
        // Arrange
        let context = createTestContext()
        let mealTime = Date(timeIntervalSinceNow: 7200) // 2 hours from now
        let party = DinnerParty(name: "Test", mealTime: mealTime)
        context.insert(party)

        let recipe = Heirloom.Recipe(title: "Recipe", instructions: [])
        context.insert(recipe)

        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 30)
        dpRecipe.dinnerParty = party
        context.insert(dpRecipe)
        party.recipes = [dpRecipe]

        // Assert
        #expect(party.isUpcoming == true)
    }

    @Test("DinnerParty isInProgress returns true when between start and meal time")
    func testDinnerParty_IsInProgress_BetweenStartAndMeal() {
        // Arrange
        let context = createTestContext()
        let mealTime = Date(timeIntervalSinceNow: 1800) // 30 min from now
        let party = DinnerParty(name: "Test", mealTime: mealTime)
        context.insert(party)

        let recipe = Heirloom.Recipe(title: "Recipe", instructions: [])
        context.insert(recipe)

        // Start time is 60 min before meal = 30 min ago (in past)
        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 60)
        dpRecipe.dinnerParty = party
        context.insert(dpRecipe)
        party.recipes = [dpRecipe]

        // Assert
        #expect(party.isInProgress == true)
    }

    @Test("DinnerParty isPast returns true when meal time passed")
    func testDinnerParty_IsPast_MealTimePassed() {
        // Arrange
        let mealTime = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        let party = DinnerParty(name: "Test", mealTime: mealTime)

        // Assert
        #expect(party.isPast == true)
    }

    // MARK: - DinnerParty Display Status Tests

    @Test("DinnerParty displayTimeStatus shows In Progress")
    func testDinnerParty_DisplayTimeStatus_InProgress() {
        // Arrange
        let context = createTestContext()
        let mealTime = Date(timeIntervalSinceNow: 1800)
        let party = DinnerParty(name: "Test", mealTime: mealTime)
        context.insert(party)

        let recipe = Heirloom.Recipe(title: "Recipe", instructions: [])
        context.insert(recipe)

        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 60)
        dpRecipe.dinnerParty = party
        context.insert(dpRecipe)
        party.recipes = [dpRecipe]

        // Assert
        #expect(party.displayTimeStatus == "In Progress")
    }

    @Test("DinnerParty displayTimeStatus shows Completed when past")
    func testDinnerParty_DisplayTimeStatus_Completed() {
        // Arrange
        let mealTime = Date(timeIntervalSinceNow: -3600)
        let party = DinnerParty(name: "Test", mealTime: mealTime)

        // Assert
        #expect(party.displayTimeStatus == "Completed")
    }

    @Test("DinnerParty displayTimeStatus shows time until start")
    func testDinnerParty_DisplayTimeStatus_TimeUntilStart() {
        // Arrange
        let context = createTestContext()
        let mealTime = Date(timeIntervalSinceNow: 7200) // 2 hours from now
        let party = DinnerParty(name: "Test", mealTime: mealTime)
        context.insert(party)

        let recipe = Heirloom.Recipe(title: "Recipe", instructions: [])
        context.insert(recipe)

        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 30)
        dpRecipe.dinnerParty = party
        context.insert(dpRecipe)
        party.recipes = [dpRecipe]

        // Act
        let status = party.displayTimeStatus

        // Assert
        #expect(status.contains("Starts in"))
    }

    // MARK: - DinnerPartyRecipe Initialization Tests

    @Test("DinnerPartyRecipe initializes with required fields")
    func testDinnerPartyRecipe_Init_WithRequiredFields() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe", instructions: [])
        context.insert(recipe)

        // Act
        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 45)
        context.insert(dpRecipe)

        // Assert
        #expect(dpRecipe.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(dpRecipe.recipe?.id == recipe.id)
        #expect(dpRecipe.startTimeOffset == 45)
        #expect(dpRecipe.scalingFactor == 1.0)
        #expect(dpRecipe.notes == nil)
        #expect(dpRecipe.isCompleted == false)
    }

    @Test("DinnerPartyRecipe initializes with custom scaling factor")
    func testDinnerPartyRecipe_Init_WithCustomScalingFactor() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe", instructions: [])
        context.insert(recipe)

        // Act
        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 30, scalingFactor: 2.0)
        context.insert(dpRecipe)

        // Assert
        #expect(dpRecipe.scalingFactor == 2.0)
    }

    // MARK: - DinnerPartyRecipe Start Time Tests

    @Test("DinnerPartyRecipe startTime returns nil when no dinner party")
    func testDinnerPartyRecipe_StartTime_NoDinnerParty() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe", instructions: [])
        context.insert(recipe)

        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 30)
        context.insert(dpRecipe)

        // Assert
        #expect(dpRecipe.startTime == nil)
    }

    @Test("DinnerPartyRecipe startTime calculates correctly")
    func testDinnerPartyRecipe_StartTime_CalculatesCorrectly() {
        // Arrange
        let context = createTestContext()
        let mealTime = Date(timeIntervalSinceNow: 3600)
        let party = DinnerParty(name: "Test", mealTime: mealTime)
        context.insert(party)

        let recipe = Heirloom.Recipe(title: "Test Recipe", instructions: [])
        context.insert(recipe)

        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 45)
        dpRecipe.dinnerParty = party
        context.insert(dpRecipe)

        // Act
        let startTime = dpRecipe.startTime!

        // Assert - Should be 45 minutes before meal time
        let expectedStart = mealTime.addingTimeInterval(-45 * 60)
        #expect(abs(startTime.timeIntervalSince(expectedStart)) < 1.0)
    }

    @Test("DinnerPartyRecipe shouldStartNow returns true when start time passed and not completed")
    func testDinnerPartyRecipe_ShouldStartNow_StartTimePassed() {
        // Arrange
        let context = createTestContext()
        let mealTime = Date(timeIntervalSinceNow: 1800) // 30 min from now
        let party = DinnerParty(name: "Test", mealTime: mealTime)
        context.insert(party)

        let recipe = Heirloom.Recipe(title: "Test Recipe", instructions: [])
        context.insert(recipe)

        // Start time is 60 min before meal = 30 min ago (in past)
        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 60)
        dpRecipe.dinnerParty = party
        dpRecipe.isCompleted = false
        context.insert(dpRecipe)

        // Assert
        #expect(dpRecipe.shouldStartNow == true)
    }

    @Test("DinnerPartyRecipe shouldStartNow returns false when completed")
    func testDinnerPartyRecipe_ShouldStartNow_WhenCompleted() {
        // Arrange
        let context = createTestContext()
        let mealTime = Date(timeIntervalSinceNow: 1800)
        let party = DinnerParty(name: "Test", mealTime: mealTime)
        context.insert(party)

        let recipe = Heirloom.Recipe(title: "Test Recipe", instructions: [])
        context.insert(recipe)

        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 60)
        dpRecipe.dinnerParty = party
        dpRecipe.isCompleted = true
        context.insert(dpRecipe)

        // Assert
        #expect(dpRecipe.shouldStartNow == false)
    }

    @Test("DinnerPartyRecipe timeUntilStart returns positive for future start")
    func testDinnerPartyRecipe_TimeUntilStart_FutureStart() {
        // Arrange
        let context = createTestContext()
        let mealTime = Date(timeIntervalSinceNow: 3600) // 1 hour from now
        let party = DinnerParty(name: "Test", mealTime: mealTime)
        context.insert(party)

        let recipe = Heirloom.Recipe(title: "Test Recipe", instructions: [])
        context.insert(recipe)

        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 30)
        dpRecipe.dinnerParty = party
        context.insert(dpRecipe)

        // Act
        let timeUntil = dpRecipe.timeUntilStart!

        // Assert - Should be positive (in the future)
        #expect(timeUntil > 0)
    }

    // MARK: - Edge Case Tests

    @Test("DinnerParty handles zero guest count")
    func testDinnerParty_ZeroGuestCount() {
        // Act
        let party = DinnerParty(name: "Test", guestCount: 0, mealTime: Date())

        // Assert
        #expect(party.guestCount == 0)
    }

    @Test("DinnerParty handles very large guest count")
    func testDinnerParty_LargeGuestCount() {
        // Act
        let party = DinnerParty(name: "Test", guestCount: 500, mealTime: Date())

        // Assert
        #expect(party.guestCount == 500)
    }

    @Test("DinnerPartyRecipe handles zero start time offset")
    func testDinnerPartyRecipe_ZeroStartTimeOffset() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe", instructions: [])
        context.insert(recipe)

        // Act
        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 0)
        context.insert(dpRecipe)

        // Assert
        #expect(dpRecipe.startTimeOffset == 0)
    }

    @Test("DinnerPartyRecipe handles notes")
    func testDinnerPartyRecipe_HandlesNotes() {
        // Arrange
        let context = createTestContext()
        let recipe = Heirloom.Recipe(title: "Test Recipe", instructions: [])
        context.insert(recipe)

        let dpRecipe = DinnerPartyRecipe(recipe: recipe, startTimeOffset: 30)
        context.insert(dpRecipe)

        // Act
        dpRecipe.notes = "Double the garlic"

        // Assert
        #expect(dpRecipe.notes == "Double the garlic")
    }

    @Test("DinnerParty can be marked as active")
    func testDinnerParty_CanBeMarkedActive() {
        // Arrange
        let party = DinnerParty(name: "Test", mealTime: Date())

        // Act
        party.isActive = true

        // Assert
        #expect(party.isActive == true)
    }
}
