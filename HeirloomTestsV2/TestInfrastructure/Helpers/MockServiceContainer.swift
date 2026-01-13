//
//  MockServiceContainer.swift
//  HeirloomTestsV2
//
//  Test-specific service container with mock implementations
//  Created: 2026-01-13
//

import Foundation
import XCTest
@testable import Heirloom

/// Mock service container for testing
/// Provides clean ServiceContainer instance with test mocks registered
@MainActor
final class MockServiceContainer {

    // MARK: - Factory Method

    /// Create a new ServiceContainer configured for testing
    /// - Returns: ServiceContainer with all test mocks registered
    static func create() -> ServiceContainer {
        let container = ServiceContainer(forTesting: true)
        registerTestMocks(in: container)
        return container
    }

    // MARK: - Mock Registration

    /// Register all test mocks in the container
    private static func registerTestMocks(in container: ServiceContainer) {
        // Core Services (mocked for testing)
        container.register(LoggingService.self) { _ in
            MockLoggingService()
        }

        // Note: AnalyticsService not registered - tests use real AnalyticsService (console logging)
        // Note: StoreManager, SubscriptionManager, PaywallManager, and Firebase services
        // are NOT registered here. Tests create real instances directly when needed.
        // State builders (TrialStateBuilder, PaywallStateBuilder) handle test setup.
    }

    // MARK: - Reset

    /// Reset all singletons in container for test isolation
    /// - Parameter container: Container to reset
    static func resetForTest(_ container: ServiceContainer) {
        container.resetSingletons()
    }
}

// MARK: - Mock Implementations

/// Mock LoggingService for testing
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
}
