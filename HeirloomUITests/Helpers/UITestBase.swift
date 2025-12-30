import XCTest

/// Base class for UI tests with common setup and helper methods
class UITestBase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Navigation Helpers

    /// Navigate to the Recipes tab
    func navigateToRecipesTab() {
        let recipesTab = app.tabBars.buttons["Recipes"]
        if recipesTab.exists {
            recipesTab.tap()
        }
    }

    /// Navigate to the Shopping List tab
    func navigateToShoppingListTab() {
        let shoppingTab = app.tabBars.buttons["Shopping"]
        if shoppingTab.exists {
            shoppingTab.tap()
        }
    }

    /// Navigate to the Settings tab
    func navigateToSettingsTab() {
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
        }
    }

    // MARK: - Wait Helpers

    /// Wait for an element to exist with timeout
    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        if result != .completed {
            XCTFail("Element did not appear within \(timeout) seconds", file: file, line: line)
            return false
        }
        return true
    }

    /// Wait for an element to disappear with timeout
    @discardableResult
    func waitForElementToDisappear(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        if result != .completed {
            XCTFail("Element did not disappear within \(timeout) seconds", file: file, line: line)
            return false
        }
        return true
    }

    /// Wait for element to be hittable (visible and interactive)
    @discardableResult
    func waitForElementToBeHittable(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        if result != .completed {
            XCTFail("Element did not become hittable within \(timeout) seconds", file: file, line: line)
            return false
        }
        return true
    }

    // MARK: - Interaction Helpers

    /// Tap element safely with wait
    func tapElement(_ element: XCUIElement, timeout: TimeInterval = 10) {
        waitForElementToBeHittable(element, timeout: timeout)
        element.tap()
    }

    /// Type text into element safely
    func typeText(into element: XCUIElement, text: String, timeout: TimeInterval = 10) {
        waitForElementToBeHittable(element, timeout: timeout)
        element.tap()
        element.typeText(text)
    }

    /// Clear text field and type new text
    func clearAndTypeText(into element: XCUIElement, text: String, timeout: TimeInterval = 10) {
        waitForElementToBeHittable(element, timeout: timeout)
        element.tap()

        // Select all and delete
        if let stringValue = element.value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
            element.typeText(deleteString)
        }

        element.typeText(text)
    }

    /// Swipe to dismiss keyboard
    func dismissKeyboard() {
        app.swipeDown()
    }

    // MARK: - Assertion Helpers

    /// Assert element exists and is visible
    func assertElementExists(
        _ element: XCUIElement,
        message: String = "Element should exist",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, message, file: file, line: line)
    }

    /// Assert element does not exist
    func assertElementDoesNotExist(
        _ element: XCUIElement,
        message: String = "Element should not exist",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(element.exists, message, file: file, line: line)
    }

    /// Assert element is hittable (visible and interactive)
    func assertElementIsHittable(
        _ element: XCUIElement,
        message: String = "Element should be hittable",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.isHittable, message, file: file, line: line)
    }

    /// Take screenshot with name
    func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Scroll Helpers

    /// Scroll to element in a scroll view
    func scrollTo(element: XCUIElement, in scrollView: XCUIElement, maxSwipes: Int = 10) {
        var swipeCount = 0
        while !element.isHittable && swipeCount < maxSwipes {
            scrollView.swipeUp()
            swipeCount += 1
        }
    }

    /// Scroll to bottom of scroll view
    func scrollToBottom(of scrollView: XCUIElement, maxSwipes: Int = 10) {
        var swipeCount = 0
        while swipeCount < maxSwipes {
            scrollView.swipeUp()
            swipeCount += 1
        }
    }

    /// Scroll to top of scroll view
    func scrollToTop(of scrollView: XCUIElement, maxSwipes: Int = 10) {
        var swipeCount = 0
        while swipeCount < maxSwipes {
            scrollView.swipeDown()
            swipeCount += 1
        }
    }
}
