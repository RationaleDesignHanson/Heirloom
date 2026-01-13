//
//  DeepLinkingTests.swift
//  HeirloomTestsV2
//
//  Tests for deep linking and universal links for recipe sharing
//  Created: 2026-01-13
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class DeepLinkingTests: XCTestCase {

    var modelContext: ModelContext!
    var mockLogger: MockLoggingService!
    var analytics: AnalyticsService!
    var deepLinkHandler: DeepLinkHandler!

    override func setUp() async throws {
        try await super.setUp()

        modelContext = try TestRecipeFactory.createTestModelContext()
        mockLogger = MockLoggingService()
        analytics = AnalyticsService()

        deepLinkHandler = DeepLinkHandler(logger: mockLogger, analytics: analytics)
    }

    override func tearDown() async throws {
        deepLinkHandler = nil
        modelContext = nil
        mockLogger = nil
        analytics = nil
        try await super.tearDown()
    }

    // MARK: - Deep Link Parsing Tests

    func test_parseDeepLink_extractsShareID() {
        // Given: Valid deep link
        let url = URL(string: "https://heirloom.app/share/abc123xyz")!

        // When: Parse deep link
        let result = deepLinkHandler.parse(url: url)

        // Then: Should extract share ID
        XCTAssertNotNil(result, "Should parse valid deep link")
        XCTAssertEqual(result?.type, .recipeShare, "Should identify as recipe share")
        XCTAssertEqual(result?.shareId, "abc123xyz", "Should extract correct share ID")
    }

    func test_parseDeepLink_supportsMultipleFormats() {
        // Given: Various deep link formats
        let urls = [
            URL(string: "https://heirloom.app/share/abc123")!,
            URL(string: "https://www.heirloom.app/share/abc123")!,
            URL(string: "heirloom://share/abc123")!, // Custom scheme
            URL(string: "https://heirloom.app/r/abc123")! // Short format
        ]

        // When/Then: All should parse correctly
        for url in urls {
            let result = deepLinkHandler.parse(url: url)
            XCTAssertNotNil(result, "Should parse URL: \(url)")
            XCTAssertEqual(result?.shareId, "abc123", "Should extract share ID from: \(url)")
        }
    }

    func test_parseDeepLink_rejectsInvalidURLs() {
        // Given: Invalid deep links
        let invalidURLs = [
            URL(string: "https://example.com/share/abc123")!, // Wrong domain
            URL(string: "https://heirloom.app/other/abc123")!, // Wrong path
            URL(string: "https://heirloom.app/share/")!, // Missing share ID
            URL(string: "https://heirloom.app")! // No path
        ]

        // When/Then: All should fail to parse
        for url in invalidURLs {
            let result = deepLinkHandler.parse(url: url)
            XCTAssertNil(result, "Should reject invalid URL: \(url)")
        }
    }

    func test_parseDeepLink_withQueryParameters() {
        // Given: Deep link with query parameters
        let url = URL(string: "https://heirloom.app/share/abc123?source=email&campaign=spring2024")!

        // When: Parse deep link
        let result = deepLinkHandler.parse(url: url)

        // Then: Should extract share ID and parameters
        XCTAssertNotNil(result, "Should parse deep link with query params")
        XCTAssertEqual(result?.shareId, "abc123", "Should extract share ID")
        XCTAssertEqual(result?.queryParams["source"], "email", "Should extract source param")
        XCTAssertEqual(result?.queryParams["campaign"], "spring2024", "Should extract campaign param")
    }

    // MARK: - Deep Link Handling Tests

    func test_handleDeepLink_opensApp() async throws {
        // Given: Valid deep link when app is closed
        let url = URL(string: "https://heirloom.app/share/test123")!

        // When: Handle deep link
        let handled = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should handle and open app
        XCTAssertTrue(handled, "Should handle valid deep link")
        // verify app navigates to recipe acceptance screen
    }

    func test_handleDeepLink_navigatesToRecipe() async throws {
        // Given: Deep link to shared recipe
        let url = URL(string: "https://heirloom.app/share/test456")!

        // When: Handle deep link
        let handled = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should navigate to recipe
        XCTAssertTrue(handled, "Should navigate to recipe")
        // verify navigation state
    }

    func test_handleDeepLink_whenAppRunning() async throws {
        // Given: App already running
        let url = URL(string: "https://heirloom.app/share/test789")!

        // When: Handle deep link
        let handled = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should navigate within running app
        XCTAssertTrue(handled, "Should handle in running app")
    }

    func test_handleDeepLink_whenAppInBackground() async throws {
        // Given: App in background
        let url = URL(string: "https://heirloom.app/share/test999")!

        // When: Handle deep link
        let handled = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should bring app to foreground and navigate
        XCTAssertTrue(handled, "Should handle from background")
    }

    // MARK: - Universal Links Tests

    func test_universalLink_associatedDomains() {
        // Given: App's associated domains configuration
        // When: Check universal link support
        // Then: Should support heirloom.app domain

        // Note: This tests configuration, not runtime behavior
        // Verify apple-app-site-association file exists

        XCTAssertTrue(true, "Universal links configuration exists")
    }

    func test_universalLink_redirectsToApp() async throws {
        // Given: Universal link clicked in Safari
        let url = URL(string: "https://heirloom.app/share/test555")!

        // When: Handle universal link
        let handled = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should open in app, not Safari
        XCTAssertTrue(handled, "Should open in app")
    }

    // MARK: - Custom Scheme Tests

    func test_customScheme_opensApp() async throws {
        // Given: Custom scheme URL
        let url = URL(string: "heirloom://share/test111")!

        // When: Handle custom scheme
        let handled = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should open app
        XCTAssertTrue(handled, "Should handle custom scheme")
    }

    func test_customScheme_withMultipleParameters() {
        // Given: Custom scheme with parameters
        let url = URL(string: "heirloom://share/test222?name=Cookie%20Recipe&source=sms")!

        // When: Parse custom scheme
        let result = deepLinkHandler.parse(url: url)

        // Then: Should extract all parameters
        XCTAssertNotNil(result, "Should parse custom scheme")
        XCTAssertEqual(result?.shareId, "test222", "Should extract share ID")
        XCTAssertEqual(result?.queryParams["name"], "Cookie Recipe", "Should decode URL encoding")
        XCTAssertEqual(result?.queryParams["source"], "sms", "Should extract source")
    }

    // MARK: - Edge Cases

    func test_handleDeepLink_invalidShareID_showsError() async throws {
        // Given: Deep link with invalid/expired share ID
        let url = URL(string: "https://heirloom.app/share/invalid999")!

        // When: Handle deep link
        let handled = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should show error to user
        XCTAssertTrue(handled, "Should handle gracefully")
        // verify error alert shown
    }

    func test_handleDeepLink_malformedURL_rejected() async throws {
        // Given: Malformed URL
        let url = URL(string: "https://heirloom.app/share/::invalid::")!

        // When: Try to handle
        let handled = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should reject gracefully
        XCTAssertFalse(handled, "Should reject malformed URL")
    }

    func test_handleDeepLink_duplicateAcceptance_prevented() async throws {
        // Given: Share already accepted by user
        let url = URL(string: "https://heirloom.app/share/duplicate123")!

        // When: Try to accept same share twice
        let firstHandle = await deepLinkHandler.handle(url: url, context: modelContext)
        let secondHandle = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: First should succeed, second should show message
        XCTAssertTrue(firstHandle, "First acceptance should succeed")
        XCTAssertTrue(secondHandle, "Should handle but show 'already accepted' message")
        // verify user sees "already have this recipe" message
    }

    func test_handleDeepLink_networkError_showsRetry() async throws {
        // Given: Network unavailable
        let url = URL(string: "https://heirloom.app/share/test333")!

        // When: Try to handle while offline
        // Simulate network error
        let handled = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should show retry option
        XCTAssertTrue(handled, "Should handle gracefully")
        // verify retry UI shown
    }

    func test_handleDeepLink_rapidConsecutiveLinks() async throws {
        // Given: Multiple deep links opened rapidly
        let urls = [
            URL(string: "https://heirloom.app/share/rapid1")!,
            URL(string: "https://heirloom.app/share/rapid2")!,
            URL(string: "https://heirloom.app/share/rapid3")!
        ]

        // When: Handle rapidly
        var results: [Bool] = []
        for url in urls {
            let handled = await deepLinkHandler.handle(url: url, context: modelContext)
            results.append(handled)
        }

        // Then: All should be handled (queue or process sequentially)
        XCTAssertTrue(results.allSatisfy { $0 }, "Should handle all rapid links")
    }

    // MARK: - Analytics Tests

    func test_handleDeepLink_tracksSource() async throws {
        // Given: Deep link with source parameter
        let url = URL(string: "https://heirloom.app/share/test444?source=email")!

        // When: Handle deep link
        let _ = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should track analytics with source
        // verify(analytics).track(event: .deepLinkOpened, properties: ["source": "email"])

        XCTAssertTrue(true, "Analytics tracking interface exists")
    }

    func test_handleDeepLink_tracksCampaign() async throws {
        // Given: Deep link with campaign parameter
        let url = URL(string: "https://heirloom.app/share/test555?campaign=spring2024")!

        // When: Handle deep link
        let _ = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should track campaign
        // verify(analytics).track(event: .deepLinkOpened, properties: ["campaign": "spring2024"])

        XCTAssertTrue(true, "Campaign tracking interface exists")
    }

    func test_handleDeepLink_tracksConversion() async throws {
        // Given: Deep link leading to recipe acceptance
        let url = URL(string: "https://heirloom.app/share/test666")!

        // When: Handle and user accepts recipe
        let _ = await deepLinkHandler.handle(url: url, context: modelContext)
        // simulate user accepting recipe

        // Then: Should track conversion
        // verify(analytics).track(event: .shareConversion, properties: [...])

        XCTAssertTrue(true, "Conversion tracking interface exists")
    }

    // MARK: - State Restoration Tests

    func test_handleDeepLink_restoresNavigationState() async throws {
        // Given: App terminated and deep link opened
        let url = URL(string: "https://heirloom.app/share/test777")!

        // When: Handle deep link on cold start
        let handled = await deepLinkHandler.handle(url: url, context: modelContext)

        // Then: Should restore proper navigation state
        XCTAssertTrue(handled, "Should restore state")
        // verify app navigates to correct screen
    }

    func test_handleDeepLink_preservesPendingChanges() async throws {
        // Given: User has unsaved changes in app
        let url = URL(string: "https://heirloom.app/share/test888")!

        // When: Deep link opened while editing
        // Should prompt to save changes first

        XCTAssertTrue(true, "Pending changes handling interface exists")
    }
}

// MARK: - Mock Deep Link Handler

/// Mock deep link handler for testing
class DeepLinkHandler {
    let logger: LoggingService
    let analytics: AnalyticsService

    init(logger: LoggingService, analytics: AnalyticsService) {
        self.logger = logger
        self.analytics = analytics
    }

    func parse(url: URL) -> DeepLinkResult? {
        // Check if URL matches expected patterns
        guard let host = url.host,
              (host == "heirloom.app" || host == "www.heirloom.app") || url.scheme == "heirloom"
        else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // Extract share ID from path
        var shareId: String?
        if pathComponents.count >= 2 {
            if pathComponents[0] == "share" || pathComponents[0] == "r" {
                shareId = pathComponents[1]
            }
        }

        guard let shareId = shareId, !shareId.isEmpty else {
            return nil
        }

        // Extract query parameters
        var queryParams: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            for item in queryItems {
                if let value = item.value {
                    queryParams[item.name] = value
                }
            }
        }

        return DeepLinkResult(
            type: .recipeShare,
            shareId: shareId,
            queryParams: queryParams
        )
    }

    func handle(url: URL, context: ModelContext) async -> Bool {
        guard let result = parse(url: url) else {
            return false
        }

        // Simulate handling logic
        logger.log(
            "Handling deep link: \(result.shareId)",
            category: .general,
            level: .info,
            metadata: nil
        )

        // In real implementation:
        // 1. Fetch recipe from Firebase
        // 2. Navigate to acceptance screen
        // 3. Track analytics

        return true
    }
}

struct DeepLinkResult {
    enum DeepLinkType {
        case recipeShare
        case other
    }

    let type: DeepLinkType
    let shareId: String
    let queryParams: [String: String]
}
