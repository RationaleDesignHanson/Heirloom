import XCTest
@testable import Heirloom

#if false // Temporarily disabled - requires RecipeURLDetector from ShareExtension target

/// Tests for Share Extension functionality
/// NOTE: Disabled temporarily - requires RecipeURLDetector from ShareExtension target
/// TODO: Move RecipeURLDetector to main target or restructure tests
final class ShareExtensionTests: XCTestCase {

    // MARK: - Recipe URL Detection Tests

    func testRecipeURLDetector_KnownRecipeSites() {
        // Known recipe sites should be detected
        let knownSites = [
            "https://www.allrecipes.com/recipe/10813/best-chocolate-chip-cookies/",
            "https://www.foodnetwork.com/recipes/chocolate-chip-cookies",
            "https://www.bonappetit.com/recipe/chocolate-chip-cookies",
            "https://www.seriouseats.com/recipes/2013/12/chocolate-chip-cookie-recipe.html",
            "https://cooking.nytimes.com/recipes/1015819-chocolate-chip-cookies"
        ]

        for urlString in knownSites {
            let url = URL(string: urlString)!
            XCTAssertTrue(RecipeURLDetector.isLikelyRecipeURL(url), "Failed to detect: \(urlString)")
        }
    }

    func testRecipeURLDetector_RecipeKeywords() {
        // URLs with recipe keywords should be detected
        let keywordURLs = [
            "https://example.com/recipe/chocolate-cake",
            "https://blog.com/recipes/pasta-carbonara",
            "https://cooking.example.org/best-lasagna",
            "https://food.blog.com/baking-tips"
        ]

        for urlString in keywordURLs {
            let url = URL(string: urlString)!
            XCTAssertTrue(RecipeURLDetector.isLikelyRecipeURL(url), "Failed to detect keyword in: \(urlString)")
        }
    }

    func testRecipeURLDetector_NonRecipeURLs() {
        // Non-recipe URLs should not be detected
        let nonRecipeURLs = [
            "https://www.apple.com",
            "https://github.com/user/repo",
            "https://news.ycombinator.com",
            "https://www.wikipedia.org/wiki/Cooking"
        ]

        for urlString in nonRecipeURLs {
            let url = URL(string: urlString)!
            XCTAssertFalse(RecipeURLDetector.isLikelyRecipeURL(url), "Incorrectly detected: \(urlString)")
        }
    }

    func testRecipeURLDetector_CaseInsensitive() {
        // Detection should be case-insensitive
        let mixedCaseURLs = [
            "https://example.com/RECIPE/chocolate-cake",
            "https://example.com/Recipes/pasta",
            "https://COOKING.example.com/dish"
        ]

        for urlString in mixedCaseURLs {
            let url = URL(string: urlString)!
            XCTAssertTrue(RecipeURLDetector.isLikelyRecipeURL(url), "Failed case-insensitive detection: \(urlString)")
        }
    }

    // MARK: - Deep Link Handling Tests

    func testDeepLinkHandler_ImportURL() {
        let handler = DeepLinkHandler.shared

        // Create import deep link
        let testURL = URL(string: "https://www.allrecipes.com/recipe/test")!
        var components = URLComponents()
        components.scheme = "heirloom"
        components.host = "import"
        components.queryItems = [
            URLQueryItem(name: "url", value: testURL.absoluteString)
        ]

        let deepLink = components.url!
        let handled = handler.handleURL(deepLink)

        XCTAssertTrue(handled, "Deep link should be handled")
        XCTAssertTrue(handler.hasPendingImport, "Should have pending import")
        XCTAssertEqual(handler.pendingImportURL?.absoluteString, testURL.absoluteString)

        // Cleanup
        handler.clearPendingImport()
    }

    func testDeepLinkHandler_ImportURLWithoutQueryParameter() {
        let handler = DeepLinkHandler.shared

        // Deep link without URL parameter should still be handled (fallback to shared container)
        let deepLink = URL(string: "heirloom://import")!
        let handled = handler.handleURL(deepLink)

        XCTAssertTrue(handled, "Deep link should be handled even without query parameter")

        // Cleanup
        handler.clearPendingImport()
    }

    func testDeepLinkHandler_ClearPendingImport() {
        let handler = DeepLinkHandler.shared

        // Set up pending import
        handler.pendingImportURL = URL(string: "https://example.com")
        handler.showImportSheet = true

        XCTAssertTrue(handler.hasPendingImport)

        // Clear it
        handler.clearPendingImport()

        XCTAssertFalse(handler.hasPendingImport)
        XCTAssertNil(handler.pendingImportURL)
        XCTAssertFalse(handler.showImportSheet)
    }

    func testDeepLinkHandler_ExistingShareURLNotAffected() {
        let handler = DeepLinkHandler.shared

        // Set up existing share
        handler.pendingShareURL = URL(string: "heirloom://share/test123")
        handler.pendingShareID = "test123"

        // Handle import URL
        let testURL = URL(string: "https://www.allrecipes.com/recipe/test")!
        var components = URLComponents()
        components.scheme = "heirloom"
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "url", value: testURL.absoluteString)]
        _ = handler.handleURL(components.url!)

        // Share should still be there
        XCTAssertNotNil(handler.pendingShareURL)
        XCTAssertNotNil(handler.pendingShareID)

        // Import should also be set
        XCTAssertNotNil(handler.pendingImportURL)

        // Cleanup
        handler.clearPendingShare()
        handler.clearPendingImport()
    }

    // MARK: - Shared Container Tests

    func testSharedContainer_SaveAndRetrieve() {
        let groupDefaults = UserDefaults(suiteName: "group.com.matthanson.heirloom.shared")!

        // Save URL
        let testURL = "https://example.com/recipe"
        groupDefaults.set(testURL, forKey: "test_pendingImportURL")
        groupDefaults.set(Date(), forKey: "test_pendingImportTimestamp")
        groupDefaults.synchronize()

        // Retrieve
        let retrieved = groupDefaults.string(forKey: "test_pendingImportURL")
        XCTAssertEqual(retrieved, testURL)

        // Cleanup
        groupDefaults.removeObject(forKey: "test_pendingImportURL")
        groupDefaults.removeObject(forKey: "test_pendingImportTimestamp")
        groupDefaults.synchronize()
    }

    // MARK: - URL Parsing Tests

    func testDeepLink_URLExtraction() {
        // Test URL extraction from deep link query parameters
        let testURL = "https://www.example.com/recipe/test?id=123"

        var components = URLComponents()
        components.scheme = "heirloom"
        components.host = "import"
        components.queryItems = [
            URLQueryItem(name: "url", value: testURL)
        ]

        let deepLink = components.url!
        let urlComponents = URLComponents(url: deepLink, resolvingAgainstBaseURL: false)

        let extractedURLString = urlComponents?.queryItems?.first(where: { $0.name == "url" })?.value
        let extractedURL = extractedURLString.flatMap { URL(string: $0) }

        XCTAssertNotNil(extractedURL)
        XCTAssertEqual(extractedURL?.absoluteString, testURL)
    }

    func testDeepLink_MultipleQueryParameters() {
        // Ensure URL extraction works with multiple query parameters
        let testURL = "https://www.example.com/recipe"

        var components = URLComponents()
        components.scheme = "heirloom"
        components.host = "import"
        components.queryItems = [
            URLQueryItem(name: "url", value: testURL),
            URLQueryItem(name: "source", value: "safari"),
            URLQueryItem(name: "timestamp", value: "\(Date().timeIntervalSince1970)")
        ]

        let deepLink = components.url!
        let urlComponents = URLComponents(url: deepLink, resolvingAgainstBaseURL: false)

        let extractedURLString = urlComponents?.queryItems?.first(where: { $0.name == "url" })?.value
        XCTAssertEqual(extractedURLString, testURL)
    }
}

#endif // Temporarily disabled
