import XCTest
@testable import Heirloom

/// Tests for AIError - Error types, messages, retry logic, user-facing text
/// Target coverage: 100% (errors are critical for UX)
@MainActor
final class AIErrorTests: XCTestCase {

    // MARK: - Configuration Error Tests

    func test_notConfigured_error() {
        let error = AIError.notConfigured(provider: "Anthropic")

        XCTAssertEqual(
            error.errorDescription,
            "Anthropic AI service is not configured. Please add API key in settings."
        )
        XCTAssertTrue(error.context["provider"] as? String == "Anthropic")
        XCTAssertFalse(error.isRetryable, "Configuration errors should not be retryable")
    }

    func test_invalidAPIKey_error() {
        let error = AIError.invalidAPIKey(provider: "OpenAI")

        XCTAssertEqual(
            error.errorDescription,
            "OpenAI API key is invalid. Please check your configuration."
        )
        XCTAssertTrue(error.context["provider"] as? String == "OpenAI")
        XCTAssertFalse(error.isRetryable)
    }

    func test_missingConfiguration_error() {
        let error = AIError.missingConfiguration(field: "api_key")

        XCTAssertEqual(
            error.errorDescription,
            "Missing required configuration: api_key"
        )
        XCTAssertTrue(error.context["field"] as? String == "api_key")
        XCTAssertFalse(error.isRetryable)
    }

    // MARK: - Network Error Tests

    func test_networkError_error() {
        let underlyingError = URLError(.notConnectedToInternet)
        let error = AIError.networkError(underlying: underlyingError)

        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
        XCTAssertNotNil(error.context["underlying_error"])
        XCTAssertTrue(error.isRetryable, "Network errors should be retryable")
    }

    func test_timeout_error() {
        let error = AIError.timeout(duration: 30.0)

        XCTAssertEqual(
            error.errorDescription,
            "Request timed out after 30.0 seconds"
        )
        XCTAssertTrue(error.context["duration"] as? TimeInterval == 30.0)
        XCTAssertTrue(error.isRetryable, "Timeout errors should be retryable")
    }

    func test_rateLimited_withRetryAfter() {
        let error = AIError.rateLimited(retryAfter: 60.0)

        XCTAssertEqual(
            error.errorDescription,
            "Rate limit exceeded. Retry after 60 seconds."
        )
        XCTAssertTrue(error.context["retry_after"] as? TimeInterval == 60.0)
        XCTAssertTrue(error.isRetryable, "Rate limit errors should be retryable")
    }

    func test_rateLimited_withoutRetryAfter() {
        let error = AIError.rateLimited(retryAfter: nil)

        XCTAssertEqual(
            error.errorDescription,
            "Rate limit exceeded. Please try again later."
        )
        XCTAssertNil(error.context["retry_after"])
        XCTAssertTrue(error.isRetryable)
    }

    func test_unauthorized_error() {
        let error = AIError.unauthorized

        XCTAssertEqual(
            error.errorDescription,
            "Unauthorized. Please check your API key."
        )
        XCTAssertFalse(error.isRetryable, "Unauthorized errors should not be retryable")
    }

    // MARK: - API Error Tests

    func test_apiError_withMessage() {
        let error = AIError.apiError(statusCode: 500, message: "Internal server error")

        XCTAssertEqual(
            error.errorDescription,
            "API error (500): Internal server error"
        )
        XCTAssertTrue(error.context["status_code"] as? Int == 500)
        XCTAssertTrue(error.context["message"] as? String == "Internal server error")
        XCTAssertTrue(error.isRetryable, "5xx errors should be retryable")
    }

    func test_apiError_withoutMessage() {
        let error = AIError.apiError(statusCode: 404, message: nil)

        XCTAssertEqual(
            error.errorDescription,
            "API error (404): Unknown error"
        )
        XCTAssertFalse(error.isRetryable, "4xx errors should not be retryable")
    }

    func test_apiError_retryability() {
        // 4xx errors (client errors) - not retryable
        let error400 = AIError.apiError(statusCode: 400, message: nil)
        XCTAssertFalse(error400.isRetryable)

        let error404 = AIError.apiError(statusCode: 404, message: nil)
        XCTAssertFalse(error404.isRetryable)

        // 5xx errors (server errors) - retryable
        let error500 = AIError.apiError(statusCode: 500, message: nil)
        XCTAssertTrue(error500.isRetryable)

        let error503 = AIError.apiError(statusCode: 503, message: nil)
        XCTAssertTrue(error503.isRetryable)
    }

    func test_invalidRequest_error() {
        let error = AIError.invalidRequest(reason: "Missing required parameter")

        XCTAssertEqual(
            error.errorDescription,
            "Invalid request: Missing required parameter"
        )
        XCTAssertTrue(error.context["reason"] as? String == "Missing required parameter")
        XCTAssertFalse(error.isRetryable)
    }

    func test_invalidResponse_error() {
        let error = AIError.invalidResponse(reason: "No content in response")

        XCTAssertEqual(
            error.errorDescription,
            "Invalid response: No content in response"
        )
        XCTAssertTrue(error.context["reason"] as? String == "No content in response")
        XCTAssertFalse(error.isRetryable)
    }

    func test_quotaExceeded_error() {
        let error = AIError.quotaExceeded(provider: "Anthropic")

        XCTAssertEqual(
            error.errorDescription,
            "Anthropic API quota exceeded. Please check your billing."
        )
        XCTAssertTrue(error.context["provider"] as? String == "Anthropic")
        XCTAssertFalse(error.isRetryable, "Quota errors should not be retryable")
    }

    // MARK: - Processing Error Tests

    func test_parsingFailed_error() {
        let error = AIError.parsingFailed(reason: "Invalid JSON structure")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to parse AI response: Invalid JSON structure"
        )
        XCTAssertTrue(error.context["reason"] as? String == "Invalid JSON structure")
        XCTAssertFalse(error.isRetryable)
    }

    func test_jsonDecodingFailed_error() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test decoding error" }
        }

        let underlyingError = TestError()
        let error = AIError.jsonDecodingFailed(underlying: underlyingError)

        XCTAssertTrue(error.errorDescription?.contains("Failed to decode JSON") ?? false)
        XCTAssertNotNil(error.context["underlying_error"])
        XCTAssertFalse(error.isRetryable)
    }

    func test_promptTooLong_error() {
        let error = AIError.promptTooLong(tokens: 150000, limit: 100000)

        XCTAssertEqual(
            error.errorDescription,
            "Prompt too long: 150000 tokens (limit: 100000)"
        )
        XCTAssertTrue(error.context["tokens"] as? Int == 150000)
        XCTAssertTrue(error.context["limit"] as? Int == 100000)
        XCTAssertFalse(error.isRetryable)
    }

    func test_unsupportedModel_error() {
        let error = AIError.unsupportedModel(model: "gpt-5-turbo")

        XCTAssertEqual(
            error.errorDescription,
            "Unsupported model: gpt-5-turbo"
        )
        XCTAssertTrue(error.context["model"] as? String == "gpt-5-turbo")
        XCTAssertFalse(error.isRetryable)
    }

    // MARK: - Retry Logic Tests

    func test_retryDelay_exponentialBackoff() {
        let error = AIError.networkError(underlying: URLError(.timedOut))

        // Attempt 0: 2^0 = 1 second
        XCTAssertEqual(error.retryDelay(attempt: 0), 1.0, accuracy: 0.01)

        // Attempt 1: 2^1 = 2 seconds
        XCTAssertEqual(error.retryDelay(attempt: 1), 2.0, accuracy: 0.01)

        // Attempt 2: 2^2 = 4 seconds
        XCTAssertEqual(error.retryDelay(attempt: 2), 4.0, accuracy: 0.01)

        // Attempt 3: 2^3 = 8 seconds
        XCTAssertEqual(error.retryDelay(attempt: 3), 8.0, accuracy: 0.01)

        // Attempt 6: 2^6 = 64 seconds (should be capped at 60)
        XCTAssertEqual(error.retryDelay(attempt: 6), 60.0, accuracy: 0.01)
    }

    func test_retryDelay_rateLimited_withRetryAfter() {
        let error = AIError.rateLimited(retryAfter: 120.0)

        // Should use the explicit retry-after value
        XCTAssertEqual(error.retryDelay(attempt: 0), 120.0, accuracy: 0.01)
        XCTAssertEqual(error.retryDelay(attempt: 5), 120.0, accuracy: 0.01)
    }

    func test_retryDelay_rateLimited_withoutRetryAfter() {
        let error = AIError.rateLimited(retryAfter: nil)

        // Should fall back to exponential backoff
        XCTAssertEqual(error.retryDelay(attempt: 0), 1.0, accuracy: 0.01)
        XCTAssertEqual(error.retryDelay(attempt: 3), 8.0, accuracy: 0.01)
    }

    func test_retryable_errors() {
        // Retryable errors
        XCTAssertTrue(AIError.networkError(underlying: URLError(.timedOut)).isRetryable)
        XCTAssertTrue(AIError.timeout(duration: 30).isRetryable)
        XCTAssertTrue(AIError.rateLimited(retryAfter: nil).isRetryable)
        XCTAssertTrue(AIError.apiError(statusCode: 500, message: nil).isRetryable)
        XCTAssertTrue(AIError.apiError(statusCode: 503, message: nil).isRetryable)

        // Non-retryable errors
        XCTAssertFalse(AIError.notConfigured(provider: "Test").isRetryable)
        XCTAssertFalse(AIError.invalidAPIKey(provider: "Test").isRetryable)
        XCTAssertFalse(AIError.unauthorized.isRetryable)
        XCTAssertFalse(AIError.apiError(statusCode: 400, message: nil).isRetryable)
        XCTAssertFalse(AIError.apiError(statusCode: 404, message: nil).isRetryable)
        XCTAssertFalse(AIError.quotaExceeded(provider: "Test").isRetryable)
        XCTAssertFalse(AIError.parsingFailed(reason: "Test").isRetryable)
        XCTAssertFalse(AIError.promptTooLong(tokens: 100, limit: 50).isRetryable)
    }

    // MARK: - User Message Tests

    func test_userMessage_notConfigured() {
        let error = AIError.notConfigured(provider: "Anthropic")

        XCTAssertEqual(
            error.userMessage,
            "AI features are not set up yet. Enable them in Settings."
        )
    }

    func test_userMessage_networkError() {
        let error = AIError.networkError(underlying: URLError(.notConnectedToInternet))

        XCTAssertEqual(
            error.userMessage,
            "Network connection issue. Please try again."
        )
    }

    func test_userMessage_timeout() {
        let error = AIError.timeout(duration: 30)

        XCTAssertEqual(
            error.userMessage,
            "Network connection issue. Please try again."
        )
    }

    func test_userMessage_rateLimited() {
        let error = AIError.rateLimited(retryAfter: 60)

        XCTAssertEqual(
            error.userMessage,
            "Too many requests. Please wait a moment."
        )
    }

    func test_userMessage_quotaExceeded() {
        let error = AIError.quotaExceeded(provider: "Anthropic")

        XCTAssertEqual(
            error.userMessage,
            "AI service limit reached. Please contact support."
        )
    }

    func test_userMessage_genericFallback() {
        let error = AIError.parsingFailed(reason: "Test")

        XCTAssertEqual(
            error.userMessage,
            "Something went wrong. Using standard parsing instead."
        )
    }

    // MARK: - User Visibility Tests

    func test_shouldShowToUser_configurationErrors() {
        XCTAssertTrue(AIError.notConfigured(provider: "Test").shouldShowToUser)
        XCTAssertTrue(AIError.quotaExceeded(provider: "Test").shouldShowToUser)
    }

    func test_shouldShowToUser_networkErrors() {
        XCTAssertTrue(AIError.networkError(underlying: URLError(.timedOut)).shouldShowToUser)
        XCTAssertTrue(AIError.timeout(duration: 30).shouldShowToUser)
        XCTAssertTrue(AIError.rateLimited(retryAfter: nil).shouldShowToUser)
    }

    func test_shouldShowToUser_processingErrors() {
        // Processing errors should NOT be shown to user (logged only)
        XCTAssertFalse(AIError.parsingFailed(reason: "Test").shouldShowToUser)
        XCTAssertFalse(AIError.jsonDecodingFailed(underlying: URLError(.unknown)).shouldShowToUser)
        XCTAssertFalse(AIError.invalidResponse(reason: "Test").shouldShowToUser)
        XCTAssertFalse(AIError.invalidAPIKey(provider: "Test").shouldShowToUser)
        XCTAssertFalse(AIError.unauthorized.shouldShowToUser)
    }

    // MARK: - Context Tests

    func test_context_containsErrorType() throws {
        let error = AIError.notConfigured(provider: "Test")

        print("DEBUG AIError context: \(error.context)")
        XCTAssertNotNil(error.context["error_type"], "Context should have error_type key")
        // String(describing:) returns full enum case like "notConfigured(provider: \"Test\")"
        let errorTypeString = error.context["error_type"] as? String
        print("DEBUG error_type value: '\(errorTypeString ?? "nil")'")
        XCTAssertTrue(errorTypeString?.contains("notConfigured") ?? false, "error_type should contain 'notConfigured', got: \(errorTypeString ?? "nil")")
    }

    func test_context_providesRelevantData() {
        // Test that context includes all relevant error data

        let promptError = AIError.promptTooLong(tokens: 150000, limit: 100000)
        XCTAssertEqual(promptError.context["tokens"] as? Int, 150000)
        XCTAssertEqual(promptError.context["limit"] as? Int, 100000)

        let timeoutError = AIError.timeout(duration: 45.5)
        XCTAssertEqual(timeoutError.context["duration"] as? TimeInterval, 45.5)

        let apiError = AIError.apiError(statusCode: 429, message: "Too many requests")
        XCTAssertEqual(apiError.context["status_code"] as? Int, 429)
        XCTAssertEqual(apiError.context["message"] as? String, "Too many requests")
    }

    // MARK: - CustomStringConvertible Tests

    func test_description_matchesErrorDescription() {
        let error = AIError.notConfigured(provider: "Anthropic")

        XCTAssertEqual(error.description, error.errorDescription)
    }

    func test_description_handlesNilErrorDescription() {
        // All AIError cases should have non-nil errorDescription
        // But we test the fallback behavior

        let error = AIError.unauthorized

        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.description.isEmpty)
    }

    // MARK: - Edge Cases

    func test_retryDelay_maxCap() {
        let error = AIError.timeout(duration: 30)

        // Very large attempt number should still cap at 60 seconds
        let delay = error.retryDelay(attempt: 100)

        XCTAssertLessThanOrEqual(delay, 60.0, "Retry delay should be capped at 60 seconds")
    }

    func test_errorDescription_allCasesHaveDescription() {
        // Verify every error type has a non-nil, non-empty description

        let errors: [AIError] = [
            .notConfigured(provider: "Test"),
            .invalidAPIKey(provider: "Test"),
            .missingConfiguration(field: "test"),
            .networkError(underlying: URLError(.timedOut)),
            .timeout(duration: 30),
            .rateLimited(retryAfter: 60),
            .rateLimited(retryAfter: nil),
            .unauthorized,
            .apiError(statusCode: 500, message: "Test"),
            .apiError(statusCode: 404, message: nil),
            .invalidRequest(reason: "Test"),
            .invalidResponse(reason: "Test"),
            .quotaExceeded(provider: "Test"),
            .parsingFailed(reason: "Test"),
            .jsonDecodingFailed(underlying: URLError(.unknown)),
            .promptTooLong(tokens: 100, limit: 50),
            .unsupportedModel(model: "test-model")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error \(error) description should not be empty")
        }
    }

    func test_context_allCasesHaveErrorType() {
        let errors: [AIError] = [
            .notConfigured(provider: "Test"),
            .networkError(underlying: URLError(.timedOut)),
            .parsingFailed(reason: "Test")
        ]

        for error in errors {
            XCTAssertNotNil(error.context["error_type"], "Error \(error) should have error_type in context")
        }
    }

    // MARK: - Real-World Scenario Tests

    func test_realWorld_userSeesAppropriateMessages() {
        // Configuration error - user should see it
        let configError = AIError.notConfigured(provider: "Anthropic")
        XCTAssertTrue(configError.shouldShowToUser)
        XCTAssertTrue(configError.userMessage.contains("Settings"))

        // Network error - user should see it
        let networkError = AIError.networkError(underlying: URLError(.notConnectedToInternet))
        XCTAssertTrue(networkError.shouldShowToUser)
        XCTAssertTrue(networkError.userMessage.contains("Network"))

        // Parsing error - user should NOT see it (fallback silently)
        let parsingError = AIError.parsingFailed(reason: "Invalid JSON")
        XCTAssertFalse(parsingError.shouldShowToUser)
        XCTAssertTrue(parsingError.userMessage.contains("standard parsing"))
    }

    func test_realWorld_retryLogic_behavesCorrectly() {
        // Scenario: Network timeout with exponential backoff

        let timeoutError = AIError.timeout(duration: 30)

        // Should be retryable
        XCTAssertTrue(timeoutError.isRetryable)

        // Should have increasing delays
        let delay1 = timeoutError.retryDelay(attempt: 0)
        let delay2 = timeoutError.retryDelay(attempt: 1)
        let delay3 = timeoutError.retryDelay(attempt: 2)

        XCTAssertLessThan(delay1, delay2, "Delays should increase")
        XCTAssertLessThan(delay2, delay3, "Delays should increase")

        // Should cap at reasonable maximum
        let maxDelay = timeoutError.retryDelay(attempt: 10)
        XCTAssertLessThanOrEqual(maxDelay, 60.0, "Should cap at 60 seconds")
    }
}
