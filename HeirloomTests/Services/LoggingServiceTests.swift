//
//  LoggingServiceTests.swift
//  HeirloomTests
//
//  Phase 4: Code Quality & Cleanup
//  Tests for structured logging service
//

import XCTest
@testable import Heirloom

final class LoggingServiceTests: XCTestCase {

    var logger: MockLogger!

    override func setUp() {
        super.setUp()
        logger = MockLogger()
    }

    override func tearDown() {
        logger = nil
        super.tearDown()
    }

    // MARK: - Basic Logging Tests

    func testDebugLogging() {
        logger.debug("Test debug message", category: .general)

        XCTAssertEqual(logger.loggedMessages.count, 1)
        XCTAssertEqual(logger.loggedMessages[0].level, .debug)
        XCTAssertEqual(logger.loggedMessages[0].message, "Test debug message")
        XCTAssertEqual(logger.loggedMessages[0].category, .general)
    }

    func testInfoLogging() {
        logger.info("Test info message", category: .sync)

        XCTAssertEqual(logger.loggedMessages.count, 1)
        XCTAssertEqual(logger.loggedMessages[0].level, .info)
        XCTAssertEqual(logger.loggedMessages[0].category, .sync)
    }

    func testWarningLogging() {
        logger.warning("Test warning message", category: .firebase)

        XCTAssertEqual(logger.loggedMessages.count, 1)
        XCTAssertEqual(logger.loggedMessages[0].level, .warning)
    }

    func testErrorLogging() {
        let testError = NSError(domain: "test", code: 123, userInfo: nil)
        logger.error("Test error message", category: .network, error: testError)

        XCTAssertEqual(logger.loggedMessages.count, 1)
        XCTAssertEqual(logger.loggedMessages[0].level, .error)
        XCTAssertNotNil(logger.loggedMessages[0].error)
    }

    func testCriticalLogging() {
        logger.critical("Test critical message", category: .auth)

        XCTAssertEqual(logger.loggedMessages.count, 1)
        XCTAssertEqual(logger.loggedMessages[0].level, .critical)
    }

    // MARK: - Metadata Tests

    func testLoggingWithMetadata() {
        let metadata: LogMetadata = ["userId": "123", "action": "login"]
        logger.info("User action", category: .ui, metadata: metadata)

        XCTAssertEqual(logger.loggedMessages.count, 1)
        XCTAssertNotNil(logger.loggedMessages[0].metadata)
        XCTAssertEqual(logger.loggedMessages[0].metadata?["userId"] as? String, "123")
    }

    // MARK: - Filtering Tests

    func testMinimumLevelFiltering() {
        logger.minimumLevel = .warning

        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")

        XCTAssertEqual(logger.loggedMessages.count, 2) // Only warning and error
        XCTAssertEqual(logger.loggedMessages[0].level, .warning)
        XCTAssertEqual(logger.loggedMessages[1].level, .error)
    }

    func testCategoryFiltering() {
        logger.enabledCategories = [.firebase, .sync]

        logger.info("Firebase message", category: .firebase)
        logger.info("Sync message", category: .sync)
        logger.info("UI message", category: .ui)

        XCTAssertEqual(logger.loggedMessages.count, 2) // Only firebase and sync
    }

    // MARK: - Performance Measurement Tests

    func testPerformanceMeasurement() {
        let result = logger.measure("Test operation", category: .performance) {
            return 42
        }

        XCTAssertEqual(result, 42)
        XCTAssertEqual(logger.loggedMessages.count, 1)
        XCTAssertNotNil(logger.loggedMessages[0].metadata?["duration_ms"])
    }

    // MARK: - Log Level Comparison Tests

    func testLogLevelComparison() {
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
        XCTAssertTrue(LogLevel.error < LogLevel.critical)
    }

    // MARK: - Redaction Tests

    func testEmailRedaction() {
        let message = "User email: user@example.com"
        let redacted = LogRedactor.redact(message)

        XCTAssertFalse(redacted.contains("user@example.com"))
        XCTAssertTrue(redacted.contains("[REDACTED_EMAIL]"))
    }

    func testTokenRedaction() {
        let message = "Bearer token: abc123xyz456789012345678901234567890"
        let redacted = LogRedactor.redact(message)

        XCTAssertTrue(redacted.contains("[REDACTED_TOKEN]"))
    }

    func testSensitiveMetadataRedaction() {
        let metadata: LogMetadata = [
            "userId": "123",
            "password": "secret123",
            "api_key": "sk-1234567890",
            "username": "john"
        ]

        let redacted = LogRedactor.redactMetadata(metadata)

        XCTAssertEqual(redacted["userId"] as? String, "123")
        XCTAssertEqual(redacted["username"] as? String, "john")
        XCTAssertEqual(redacted["password"] as? String, "[REDACTED]")
        XCTAssertEqual(redacted["api_key"] as? String, "[REDACTED]")
    }
}

// MARK: - Mock Logger

/// Mock logger for testing
class MockLogger: LoggingService {
    struct LoggedMessage {
        let level: LogLevel
        let message: String
        let category: LogCategory
        let error: Error?
        let metadata: LogMetadata?
        let file: String
        let function: String
        let line: Int
    }

    var loggedMessages: [LoggedMessage] = []
    var minimumLevel: LogLevel = .debug
    var enabledCategories: Set<LogCategory> = []

    func debug(_ message: String, category: LogCategory, metadata: LogMetadata? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, category: category, error: nil, metadata: metadata, file: file, function: function, line: line)
    }

    func info(_ message: String, category: LogCategory, metadata: LogMetadata? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, category: category, error: nil, metadata: metadata, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: LogCategory, metadata: LogMetadata? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, category: category, error: nil, metadata: metadata, file: file, function: function, line: line)
    }

    func error(_ message: String, category: LogCategory, error: Error? = nil, metadata: LogMetadata? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, category: category, error: error, metadata: metadata, file: file, function: function, line: line)
    }

    func critical(_ message: String, category: LogCategory, error: Error? = nil, metadata: LogMetadata? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, message: message, category: category, error: error, metadata: metadata, file: file, function: function, line: line)
    }

    func measure<T>(_ label: String, category: LogCategory, metadata: LogMetadata? = nil, file: String = #file, function: String = #function, line: Int = #line, block: () throws -> T) rethrows -> T {
        let result = try block()
        var perfMetadata = metadata ?? [:]
        perfMetadata["duration_ms"] = "0.00"
        log(level: .debug, message: label, category: category, error: nil, metadata: perfMetadata, file: file, function: function, line: line)
        return result
    }

    func log(_ message: String, category: LogCategory, level: LogLevel, metadata: LogMetadata?, file: String = #fileID, function: String = #function, line: Int = #line) {
        log(level: level, message: message, category: category, error: nil, metadata: metadata, file: file, function: function, line: line)
    }

    func log(_ message: String, category: LogCategory, level: LogLevel, metadata: LogMetadata?) {
        log(level: level, message: message, category: category, error: nil, metadata: metadata, file: #fileID, function: #function, line: #line)
    }

    private func log(level: LogLevel, message: String, category: LogCategory, error: Error?, metadata: LogMetadata?, file: String, function: String, line: Int) {
        // Filter by level
        guard level >= minimumLevel else { return }

        // Filter by category
        guard enabledCategories.isEmpty || enabledCategories.contains(category) else { return }

        loggedMessages.append(LoggedMessage(
            level: level,
            message: message,
            category: category,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        ))
    }
}
