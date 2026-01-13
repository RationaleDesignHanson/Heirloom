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
        // Store Services (for subscription testing)
        container.register(StoreManager.self) { _ in
            MockStoreManager()
        }

        container.register(SubscriptionManager.self) { container in
            let storeManager = container.resolve(StoreManager.self)
            let logger = container.resolve(LoggingService.self)
            let analytics = container.resolve(AnalyticsService.self)
            return SubscriptionManager(
                storeManager: storeManager,
                logger: logger,
                analytics: analytics
            )
        }

        container.register(PaywallManager.self) { container in
            let subscriptionManager = container.resolve(SubscriptionManager.self)
            let logger = container.resolve(LoggingService.self)
            let analytics = container.resolve(AnalyticsService.self)
            return PaywallManager(
                subscriptionManager: subscriptionManager,
                logger: logger,
                analytics: analytics
            )
        }

        // Core Services (mocked for testing)
        container.register(LoggingService.self) { _ in
            MockLoggingService()
        }

        container.register(AnalyticsService.self) { _ in
            MockAnalyticsService()
        }

        // Firebase Services (if needed)
        container.register(FirebaseAuthService.self) { _ in
            MockFirebaseAuth()
        }

        container.register(FirebaseSyncService.self) { container in
            let auth = container.resolve(FirebaseAuthService.self)
            let logger = container.resolve(LoggingService.self)
            return MockFirebaseSyncService(auth: auth, logger: logger)
        }
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

    override func log(_ message: String, category: LogCategory, level: LogLevel) {
        loggedMessages.append((message, category, level))
    }

    func reset() {
        loggedMessages.removeAll()
    }
}

/// Mock AnalyticsService for testing
@MainActor
final class MockAnalyticsService: AnalyticsService {
    var trackedEvents: [(name: String, params: [String: Any]?)] = []

    override func track(_ event: AnalyticsEvent) {
        switch event {
        case .custom(let name, let params):
            trackedEvents.append((name, params))
        default:
            trackedEvents.append((event.name, event.properties))
        }
    }

    func reset() {
        trackedEvents.removeAll()
    }
}

/// Mock FirebaseSyncService for testing
@MainActor
final class MockFirebaseSyncService: FirebaseSyncService {
    var syncCalled = false

    init(auth: FirebaseAuthService, logger: LoggingService) {
        // Mock initialization
    }

    func sync() async throws {
        syncCalled = true
    }

    func reset() {
        syncCalled = false
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Create a test container with mocks
    @MainActor
    func createTestContainer() -> ServiceContainer {
        return MockServiceContainer.create()
    }

    /// Reset container for test isolation
    @MainActor
    func resetTestContainer(_ container: ServiceContainer) {
        MockServiceContainer.resetForTest(container)
    }
}
