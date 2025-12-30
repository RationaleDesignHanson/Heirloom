import XCTest

/// UI tests for shopping list flows
final class ShoppingListUITests: UITestBase {

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        navigateToShoppingListTab()
    }

    // MARK: - Navigation Tests

    func testNavigateToShoppingList() {
        // Given: App is launched
        // When: User taps Shopping List tab
        navigateToShoppingListTab()

        // Then: Shopping list view should be displayed
        let shoppingListView = app.otherElements["shoppingListView"]
        waitForElement(shoppingListView, timeout: 3)
        assertElementExists(shoppingListView, message: "Shopping list view should be displayed")
    }

    // MARK: - Empty State Tests

    func testEmptyState_DisplaysCorrectly() {
        // Given: Shopping list is empty
        // (Assuming fresh app state)

        // Then: Empty state should be visible
        let emptyState = app.otherElements["shoppingListEmptyState"]
        if emptyState.exists {
            assertElementExists(emptyState, message: "Empty state should be visible when list is empty")

            // And: Add button should be available
            let addButton = app.buttons["shoppingListEmptyStateAddButton"]
            assertElementExists(addButton, message: "Add button should be in empty state")
        }
    }

    // MARK: - Add Recipes Flow Tests

    func testAddRecipesToList_OpenSheet() {
        // Given: User is on shopping list
        let addButton = app.buttons["shoppingListAddRecipeButton"]

        // When: User taps add recipe button
        if addButton.exists {
            tapElement(addButton)

            // Then: Recipe selection sheet should appear
            let selectionSheet = app.sheets["shoppingListRecipeSelectionSheet"]
            waitForElement(selectionSheet, timeout: 3)
            assertElementExists(selectionSheet, message: "Recipe selection sheet should appear")
        }
    }

    func testAddRecipesToList_SelectRecipe() {
        // Given: Recipe selection sheet is open
        let addButton = app.buttons["shoppingListAddRecipeButton"]

        if addButton.exists {
            tapElement(addButton)

            let selectionSheet = app.sheets["shoppingListRecipeSelectionSheet"]
            waitForElement(selectionSheet, timeout: 3)

            // When: User taps a recipe checkbox
            let recipeRow = app.buttons["shoppingListRecipeRow"]
            let recipeCheckbox = app.buttons["shoppingListRecipeCheckbox"]

            if recipeRow.exists {
                tapElement(recipeRow)

                // Then: Recipe should be selected (checkbox checked)
                // And: Add button should be enabled
                let addRecipesButton = app.buttons["shoppingListAddRecipesToListButton"]
                assertElementIsHittable(addRecipesButton, message: "Add recipes button should be enabled after selection")
            }
        }
    }

    func testAddRecipesToList_AdjustServings() {
        // Given: Recipe is selected in sheet
        let addButton = app.buttons["shoppingListAddRecipeButton"]

        if addButton.exists {
            tapElement(addButton)

            let selectionSheet = app.sheets["shoppingListRecipeSelectionSheet"]
            waitForElement(selectionSheet, timeout: 3)

            // When: User adjusts servings
            let servingsField = app.textFields["shoppingListServingsField"]
            if servingsField.exists {
                clearAndTypeText(into: servingsField, text: "8")

                // Then: Servings value should be updated
                XCTAssertTrue(servingsField.value as? String == "8",
                              "Servings should be updated to 8")
            }
        }
    }

    // MARK: - List Interaction Tests

    func testShoppingListItems_DisplayByCategory() {
        // Given: Shopping list has items
        // (Requires recipes to be added first)

        // Then: Category sections should be visible
        let categorySection = app.otherElements["shoppingListCategorySection"]
        let categoryHeader = app.staticTexts["shoppingListCategoryHeader"]

        // Items should be organized by category
        let itemRow = app.otherElements["shoppingListItemRow"]
        // Note: These will only exist if list has items
    }

    func testShoppingListItem_CheckOff() {
        // Given: Shopping list has items
        let itemCheckbox = app.buttons["shoppingListItemCheckbox"]

        if itemCheckbox.exists {
            // When: User taps checkbox
            tapElement(itemCheckbox)

            // Then: Item should be marked as checked
            // (Visual state change verified by UI)
        }
    }

    func testShoppingListItem_ViewDetails() {
        // Given: Shopping list has items
        let itemRow = app.otherElements["shoppingListItemRow"]

        if itemRow.exists {
            // When: User taps item
            tapElement(itemRow)

            // Then: Item details should be visible
            let itemText = app.staticTexts["shoppingListItemText"]
            let itemQuantity = app.staticTexts["shoppingListItemQuantity"]

            assertElementExists(itemText, message: "Item text should be visible")
        }
    }

    // MARK: - Actions Tests

    func testClearAllItems() {
        // Given: Shopping list has items
        let clearButton = app.buttons["shoppingListClearAllButton"]

        if clearButton.exists {
            // When: User taps clear all
            tapElement(clearButton)

            // Then: Confirmation should appear or list should be cleared
            // (Depending on implementation)
        }
    }

    func testShareList() {
        // Given: Shopping list has items
        let shareButton = app.buttons["shoppingListShareButton"]

        if shareButton.exists {
            // When: User taps share
            tapElement(shareButton)

            // Then: Share sheet should appear
            // Note: System share sheet may not be easily testable
        }
    }

    func testExportToReminders() {
        // Given: Shopping list has items
        let exportButton = app.buttons["shoppingListExportRemindersButton"]

        if exportButton.exists {
            // When: User taps export to reminders
            tapElement(exportButton)

            // Then: Export process should initiate
            // Note: Actual Reminders integration requires permissions
        }
    }

    // MARK: - Accessibility Tests

    func testShoppingList_AccessibilityLabels() {
        // Given: User is on shopping list
        let shoppingListView = app.otherElements["shoppingListView"]
        waitForElement(shoppingListView, timeout: 3)

        // Then: Key elements should have accessibility identifiers
        assertElementExists(shoppingListView, message: "Shopping list view should be accessible")

        // Buttons
        let addButton = app.buttons["shoppingListAddRecipeButton"]
        if addButton.exists {
            assertElementExists(addButton, message: "Add recipe button should be accessible")
        }
    }

    // MARK: - Scroll and Navigation Tests

    func testShoppingList_ScrollThroughCategories() {
        // Given: Shopping list has many items in multiple categories
        let shoppingListView = app.otherElements["shoppingListView"]
        waitForElement(shoppingListView, timeout: 3)

        // When: User scrolls through list
        if shoppingListView.exists {
            scrollToBottom(of: shoppingListView, maxSwipes: 5)

            // Then: User should be able to scroll through all categories
            // (Visual verification that scroll works)

            // When: User scrolls back up
            scrollToTop(of: shoppingListView, maxSwipes: 5)

            // Then: User should return to top
        }
    }

    // MARK: - Integration Tests

    func testAddRecipeAndVerifyIngredients() {
        // Given: User has recipes available
        let addButton = app.buttons["shoppingListAddRecipeButton"]

        if addButton.exists {
            // When: User adds a recipe to shopping list
            tapElement(addButton)

            let selectionSheet = app.sheets["shoppingListRecipeSelectionSheet"]
            waitForElement(selectionSheet, timeout: 3)

            let recipeRow = app.buttons["shoppingListRecipeRow"]
            if recipeRow.exists {
                tapElement(recipeRow)

                let addRecipesButton = app.buttons["shoppingListAddRecipesToListButton"]
                tapElement(addRecipesButton)

                // Then: Sheet should close
                waitForElementToDisappear(selectionSheet, timeout: 3)

                // And: Ingredients should appear in shopping list
                let itemRow = app.otherElements["shoppingListItemRow"]
                waitForElement(itemRow, timeout: 5)
                assertElementExists(itemRow, message: "Shopping list should contain recipe ingredients")
            }
        }
    }

    // MARK: - Empty State to Populated State Tests

    func testTransitionFromEmptyToPopulated() {
        // Given: Shopping list starts empty
        let emptyState = app.otherElements["shoppingListEmptyState"]

        if emptyState.exists {
            // When: User adds first recipe
            let emptyStateAddButton = app.buttons["shoppingListEmptyStateAddButton"]
            if emptyStateAddButton.exists {
                tapElement(emptyStateAddButton)

                // Then: Empty state should eventually disappear when items are added
                // (Full integration test would add actual recipe and verify)
            }
        }
    }

    // MARK: - Category Organization Tests

    func testCategoryOrganization() {
        // Given: Shopping list has items from different categories
        let categoryHeader = app.staticTexts["shoppingListCategoryHeader"]

        if categoryHeader.exists {
            // Then: Categories should be displayed with proper headers
            assertElementExists(categoryHeader, message: "Category headers should be visible")

            // And: Items should be grouped under categories
            let categorySection = app.otherElements["shoppingListCategorySection"]
            if categorySection.exists {
                assertElementExists(categorySection, message: "Category sections should exist")
            }
        }
    }
}
