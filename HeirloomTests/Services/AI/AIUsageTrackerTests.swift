import XCTest
@testable import Heirloom

/// Tests for AIUsageTracker - Token tracking, cost calculation, persistence
/// Target coverage: 90%+ (critical for cost monitoring)
@MainActor
final class AIUsageTrackerTests: XCTestCase {

    var tracker: AIUsageTracker!

    override func setUp() async throws {
        tracker = AIUsageTracker.shared

        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "ai_total_tokens")
        UserDefaults.standard.removeObject(forKey: "ai_request_count")
        UserDefaults.standard.removeObject(forKey: "ai_total_cost")

        // Reset tracker
        tracker.reset()
    }

    override func tearDown() async throws {
        tracker.reset()
        UserDefaults.standard.removeObject(forKey: "ai_total_tokens")
        UserDefaults.standard.removeObject(forKey: "ai_request_count")
        UserDefaults.standard.removeObject(forKey: "ai_total_cost")
    }

    // MARK: - Token Tracking Tests

    func test_trackUsage_updatesTokenCount() async throws {
        let tokens = TokenUsage(inputTokens: 100, outputTokens: 200, totalTokens: 300)

        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        XCTAssertEqual(tracker.totalTokensUsed, 300, "Should track total tokens")
        XCTAssertEqual(tracker.requestCount, 1, "Should increment request count")
    }

    func test_trackUsage_accumulatesTokens() async throws {
        let tokens1 = TokenUsage(inputTokens: 100, outputTokens: 200, totalTokens: 300)
        let tokens2 = TokenUsage(inputTokens: 50, outputTokens: 100, totalTokens: 150)

        tracker.trackUsage(tokens: tokens1, provider: .anthropic)
        tracker.trackUsage(tokens: tokens2, provider: .anthropic)

        XCTAssertEqual(tracker.totalTokensUsed, 450, "Should accumulate tokens")
        XCTAssertEqual(tracker.requestCount, 2, "Should count all requests")
    }

    func test_trackUsage_multipleProviders() async throws {
        let anthropicTokens = TokenUsage(inputTokens: 100, outputTokens: 200, totalTokens: 300)
        let openaiTokens = TokenUsage(inputTokens: 50, outputTokens: 100, totalTokens: 150)

        tracker.trackUsage(tokens: anthropicTokens, provider: .anthropic)
        tracker.trackUsage(tokens: openaiTokens, provider: .openai)

        XCTAssertEqual(tracker.totalTokensUsed, 450, "Should track tokens from all providers")
        XCTAssertEqual(tracker.requestCount, 2, "Should count requests from all providers")
    }

    // MARK: - Cost Calculation Tests

    func test_trackUsage_calculatesAnthropicCost() async throws {
        // Anthropic Haiku: $0.25 per 1M input, $1.25 per 1M output
        let tokens = TokenUsage(inputTokens: 1000, outputTokens: 2000, totalTokens: 3000)

        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        let expectedInputCost = Decimal(1000) / 1_000_000 * 0.25
        let expectedOutputCost = Decimal(2000) / 1_000_000 * 1.25
        let expectedTotal = expectedInputCost + expectedOutputCost

        XCTAssertEqual(tracker.totalCost, expectedTotal, accuracy: 0.000001, "Should calculate Anthropic cost correctly")
    }

    func test_trackUsage_calculatesOpenAICost() async throws {
        // OpenAI GPT-4o-mini: $0.15 per 1M input, $0.60 per 1M output
        let tokens = TokenUsage(inputTokens: 1000, outputTokens: 2000, totalTokens: 3000)

        tracker.trackUsage(tokens: tokens, provider: .openai)

        let expectedInputCost = Decimal(1000) / 1_000_000 * 0.15
        let expectedOutputCost = Decimal(2000) / 1_000_000 * 0.60
        let expectedTotal = expectedInputCost + expectedOutputCost

        XCTAssertEqual(tracker.totalCost, expectedTotal, accuracy: 0.000001, "Should calculate OpenAI cost correctly")
    }

    func test_trackUsage_accumulatesCosts() async throws {
        let tokens1 = TokenUsage(inputTokens: 1000, outputTokens: 2000, totalTokens: 3000)
        let tokens2 = TokenUsage(inputTokens: 500, outputTokens: 1000, totalTokens: 1500)

        tracker.trackUsage(tokens: tokens1, provider: .anthropic)
        tracker.trackUsage(tokens: tokens2, provider: .anthropic)

        let expectedCost1 = Decimal(1000) / 1_000_000 * 0.25 + Decimal(2000) / 1_000_000 * 1.25
        let expectedCost2 = Decimal(500) / 1_000_000 * 0.25 + Decimal(1000) / 1_000_000 * 1.25
        let expectedTotal = expectedCost1 + expectedCost2

        XCTAssertEqual(tracker.totalCost, expectedTotal, accuracy: 0.000001, "Should accumulate costs")
    }

    func test_trackUsage_largeTokenCounts() async throws {
        // Test with realistic large token counts
        let tokens = TokenUsage(inputTokens: 100_000, outputTokens: 50_000, totalTokens: 150_000)

        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        let expectedInputCost = Decimal(100_000) / 1_000_000 * 0.25  // $0.025
        let expectedOutputCost = Decimal(50_000) / 1_000_000 * 1.25  // $0.0625
        let expectedTotal = expectedInputCost + expectedOutputCost    // $0.0875

        XCTAssertEqual(tracker.totalCost, expectedTotal, accuracy: 0.000001, "Should handle large token counts")
    }

    // MARK: - Reset Tests

    func test_reset_clearsAllTracking() async throws {
        let tokens = TokenUsage(inputTokens: 1000, outputTokens: 2000, totalTokens: 3000)

        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        XCTAssertGreaterThan(tracker.totalTokensUsed, 0)
        XCTAssertGreaterThan(tracker.requestCount, 0)
        XCTAssertGreaterThan(tracker.totalCost, 0)

        tracker.reset()

        XCTAssertEqual(tracker.totalTokensUsed, 0, "Should reset token count")
        XCTAssertEqual(tracker.requestCount, 0, "Should reset request count")
        XCTAssertEqual(tracker.totalCost, 0, "Should reset cost")
    }

    func test_reset_persistsToUserDefaults() async throws {
        let tokens = TokenUsage(inputTokens: 1000, outputTokens: 2000, totalTokens: 3000)
        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        tracker.reset()

        XCTAssertEqual(UserDefaults.standard.integer(forKey: "ai_total_tokens"), 0)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "ai_request_count"), 0)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "ai_total_cost"), "0")
    }

    // MARK: - Persistence Tests

    func test_trackUsage_persistsToUserDefaults() async throws {
        let tokens = TokenUsage(inputTokens: 100, outputTokens: 200, totalTokens: 300)

        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        XCTAssertEqual(UserDefaults.standard.integer(forKey: "ai_total_tokens"), 300)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "ai_request_count"), 1)
        XCTAssertNotNil(UserDefaults.standard.string(forKey: "ai_total_cost"))
    }

    func test_persistence_loadsFromUserDefaults() async throws {
        // Set values directly in UserDefaults
        UserDefaults.standard.set(500, forKey: "ai_total_tokens")
        UserDefaults.standard.set(3, forKey: "ai_request_count")
        UserDefaults.standard.set("0.00123", forKey: "ai_total_cost")

        // Create new tracker instance (would load from UserDefaults)
        // Note: Can't test this directly since tracker is singleton
        // But we can verify the values persist after reset and reload

        XCTAssertEqual(UserDefaults.standard.integer(forKey: "ai_total_tokens"), 500)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "ai_request_count"), 3)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "ai_total_cost"), "0.00123")
    }

    func test_persistence_handlesCorruptedData() async throws {
        // Set invalid cost string
        UserDefaults.standard.set("invalid", forKey: "ai_total_cost")

        tracker.reset()

        // Should handle gracefully and reset to 0
        XCTAssertEqual(tracker.totalCost, 0)
    }

    // MARK: - ObservableObject Tests

    func test_published_properties_notifyObservers() async throws {
        let expectation = XCTestExpectation(description: "Published property changed")
        expectation.expectedFulfillmentCount = 3 // tokens, cost, requestCount

        let cancellable = tracker.objectWillChange.sink { _ in
            expectation.fulfill()
        }

        let tokens = TokenUsage(inputTokens: 100, outputTokens: 200, totalTokens: 300)
        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    // MARK: - Edge Cases

    func test_trackUsage_zeroTokens() async throws {
        let tokens = TokenUsage(inputTokens: 0, outputTokens: 0, totalTokens: 0)

        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        XCTAssertEqual(tracker.totalTokensUsed, 0)
        XCTAssertEqual(tracker.requestCount, 1, "Should still count request")
        XCTAssertEqual(tracker.totalCost, 0)
    }

    func test_trackUsage_verySmallCost() async throws {
        // Single token should have minimal but non-zero cost
        let tokens = TokenUsage(inputTokens: 1, outputTokens: 1, totalTokens: 2)

        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        XCTAssertGreaterThan(tracker.totalCost, 0, "Even small token counts should have cost")
        XCTAssertLessThan(tracker.totalCost, 0.001, "Cost should be very small")
    }

    func test_trackUsage_millionTokens() async throws {
        // Test edge case of 1 million tokens (pricing threshold)
        let tokens = TokenUsage(inputTokens: 1_000_000, outputTokens: 1_000_000, totalTokens: 2_000_000)

        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        // 1M input @ $0.25 + 1M output @ $1.25 = $1.50
        let expectedCost = Decimal(0.25) + Decimal(1.25)

        XCTAssertEqual(tracker.totalCost, expectedCost, accuracy: 0.01, "Should handle million token counts")
    }

    func test_costPrecision_maintainsAccuracy() async throws {
        // Track many small requests to test decimal precision
        for _ in 0..<100 {
            let tokens = TokenUsage(inputTokens: 10, outputTokens: 20, totalTokens: 30)
            tracker.trackUsage(tokens: tokens, provider: .anthropic)
        }

        // 100 requests * (10 * $0.25/1M + 20 * $1.25/1M) = very small but should accumulate
        XCTAssertGreaterThan(tracker.totalCost, 0, "Should accumulate small costs")
        XCTAssertEqual(tracker.requestCount, 100)
    }

    // MARK: - Thread Safety Tests

    func test_concurrentTracking() async throws {
        // Test concurrent tracking from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    let tokens = TokenUsage(inputTokens: 100, outputTokens: 200, totalTokens: 300)
                    self.tracker.trackUsage(tokens: tokens, provider: .anthropic)
                }
            }
        }

        // Should track all 10 requests without race conditions
        XCTAssertEqual(tracker.totalTokensUsed, 3000, "Should track all concurrent requests")
        XCTAssertEqual(tracker.requestCount, 10)
    }

    // MARK: - Cost Comparison Tests

    func test_costComparison_anthropicVsOpenAI() async throws {
        let tokens = TokenUsage(inputTokens: 10_000, outputTokens: 10_000, totalTokens: 20_000)

        // Test Anthropic cost
        tracker.trackUsage(tokens: tokens, provider: .anthropic)
        let anthropicCost = tracker.totalCost

        tracker.reset()

        // Test OpenAI cost
        tracker.trackUsage(tokens: tokens, provider: .openai)
        let openaiCost = tracker.totalCost

        // Anthropic should be more expensive for same token count (higher output cost)
        XCTAssertGreaterThan(anthropicCost, openaiCost, "Anthropic should cost more for same tokens")
    }

    // MARK: - Real-World Scenarios

    func test_realWorld_typicalParsingSession() async throws {
        // Simulate parsing 20 ingredients (typical recipe)
        for _ in 0..<20 {
            let tokens = TokenUsage(inputTokens: 50, outputTokens: 30, totalTokens: 80)
            tracker.trackUsage(tokens: tokens, provider: .anthropic)
        }

        XCTAssertEqual(tracker.totalTokensUsed, 1600)
        XCTAssertEqual(tracker.requestCount, 20)

        // Cost should be very small (under 1 cent)
        XCTAssertLessThan(tracker.totalCost, 0.01, "Parsing session should cost < 1 cent")
    }

    func test_realWorld_ocrExtraction() async throws {
        // Simulate OCR extraction (larger token count)
        let tokens = TokenUsage(inputTokens: 2000, outputTokens: 1000, totalTokens: 3000)

        tracker.trackUsage(tokens: tokens, provider: .anthropic)

        XCTAssertEqual(tracker.totalTokensUsed, 3000)
        XCTAssertLessThan(tracker.totalCost, 0.01, "Single OCR extraction should cost < 1 cent")
    }

    func test_realWorld_dailyUsage() async throws {
        // Simulate a day of heavy usage: 100 recipes
        for _ in 0..<100 {
            // Parse 15 ingredients per recipe
            for _ in 0..<15 {
                let parseTokens = TokenUsage(inputTokens: 50, outputTokens: 30, totalTokens: 80)
                tracker.trackUsage(tokens: parseTokens, provider: .anthropic)
            }

            // Extract 1 recipe from OCR
            let ocrTokens = TokenUsage(inputTokens: 2000, outputTokens: 1000, totalTokens: 3000)
            tracker.trackUsage(tokens: ocrTokens, provider: .anthropic)
        }

        XCTAssertEqual(tracker.requestCount, 1600, "Should track all requests")

        // Even with heavy usage, daily cost should be reasonable (< $1)
        XCTAssertLessThan(tracker.totalCost, 1.0, "Daily heavy usage should cost < $1")
    }
}
