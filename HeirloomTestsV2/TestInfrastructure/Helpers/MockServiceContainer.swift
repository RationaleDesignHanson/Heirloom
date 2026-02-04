//
//  MockServiceContainer.swift
//  HeirloomTestsV2
//
//  DEPRECATED: Use TestServiceContainer instead
//  This file is maintained for backward compatibility
//  Created: 2026-01-13
//

import Foundation
import XCTest
@testable import Heirloom

/// DEPRECATED: Use TestServiceContainer instead
/// This class is maintained for backward compatibility only
@available(*, deprecated, renamed: "TestServiceContainer", message: "Use TestServiceContainer for full mock registration")
@MainActor
final class MockServiceContainer {

    // MARK: - Factory Method (Deprecated)

    /// DEPRECATED: Use TestServiceContainer.create() instead
    @available(*, deprecated, renamed: "TestServiceContainer.create()", message: "Use TestServiceContainer for full mock registration")
    static func create() -> ServiceContainer {
        return TestServiceContainer.create()
    }

    // MARK: - Reset (Deprecated)

    /// DEPRECATED: Use TestServiceContainer.reset(_:) instead
    @available(*, deprecated, renamed: "TestServiceContainer.reset(_:)", message: "Use TestServiceContainer for full mock registration")
    static func resetForTest(_ container: ServiceContainer) {
        TestServiceContainer.reset(container)
    }
}

// MARK: - Mock Implementations

/// Mock LoggingService for testing
/// Captures log messages for test assertions
@MainActor
final class MockLoggingService: LoggingService {
    var loggedMessages: [(message: String, category: LogCategory, level: LogLevel)] = []
    var minimumLevel: LogLevel = .debug
    var enabledCategories: Set<LogCategory> = []

    func debug(_ message: String, category: LogCategory, metadata: LogMetadata?, file: String, function: String, line: Int) {
        loggedMessages.append((message, category, .debug))
    }

    func info(_ message: String, category: LogCategory, metadata: LogMetadata?, file: String, function: String, line: Int) {
        loggedMessages.append((message, category, .info))
    }

    func warning(_ message: String, category: LogCategory, metadata: LogMetadata?, file: String, function: String, line: Int) {
        loggedMessages.append((message, category, .warning))
    }

    func error(_ message: String, category: LogCategory, error: Error?, metadata: LogMetadata?, file: String, function: String, line: Int) {
        loggedMessages.append((message, category, .error))
    }

    func critical(_ message: String, category: LogCategory, error: Error?, metadata: LogMetadata?, file: String, function: String, line: Int) {
        loggedMessages.append((message, category, .critical))
    }

    func log(_ message: String, category: LogCategory, level: LogLevel, metadata: LogMetadata?, file: String, function: String, line: Int) {
        loggedMessages.append((message, category, level))
    }

    func log(_ message: String, category: LogCategory, level: LogLevel, metadata: LogMetadata?) {
        loggedMessages.append((message, category, level))
    }

    func measure<T>(_ label: String, category: LogCategory, metadata: LogMetadata?, file: String, function: String, line: Int, block: () throws -> T) rethrows -> T {
        try block()
    }

    func reset() {
        loggedMessages.removeAll()
    }

    // MARK: - Test Helpers

    /// Check if a message with specific content was logged
    func hasLoggedMessage(containing text: String) -> Bool {
        loggedMessages.contains { $0.message.contains(text) }
    }

    /// Check if a message was logged at a specific level
    func hasLoggedMessage(atLevel level: LogLevel) -> Bool {
        loggedMessages.contains { $0.level == level }
    }

    /// Check if a message was logged in a specific category
    func hasLoggedMessage(inCategory category: LogCategory) -> Bool {
        loggedMessages.contains { $0.category == category }
    }

    /// Get all messages at a specific level
    func messages(atLevel level: LogLevel) -> [String] {
        loggedMessages.filter { $0.level == level }.map { $0.message }
    }

    /// Get all messages in a specific category
    func messages(inCategory category: LogCategory) -> [String] {
        loggedMessages.filter { $0.category == category }.map { $0.message }
    }
}
