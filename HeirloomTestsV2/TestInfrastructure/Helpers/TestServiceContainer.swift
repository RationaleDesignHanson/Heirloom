//
//  TestServiceContainer.swift
//  HeirloomTestsV2
//
//  Functional test service container for comprehensive testing
//  Replaces the stub MockServiceContainer with full mock registration
//  Created: 2026-02-03
//

import Foundation
import SwiftData
@testable import Heirloom

/// Factory for creating ServiceContainer instances configured for testing
/// Provides clean state, mock registration, and builder-pattern configuration
@MainActor
final class TestServiceContainer {

    // MARK: - Configuration

    private var authState: MockAuthState = .signedOut
    private var firestoreState: MockFirestoreState = .empty
    private var shouldFailPurchases: Bool = false
    private var credits: Int = 25

    // MARK: - Builder Methods

    /// Configure authentication state
    func withAuth(_ state: MockAuthState) -> Self {
        self.authState = state
        return self
    }

    /// Configure with authenticated user
    func authenticated(
        userId: String = "test-user-123",
        email: String = "test@example.com"
    ) -> Self {
        self.authState = .authenticated(userId: userId, email: email)
        return self
    }

    /// Configure Firestore state
    func withFirestore(_ state: MockFirestoreState) -> Self {
        self.firestoreState = state
        return self
    }

    /// Configure purchase behavior
    func withPurchaseFailures(_ shouldFail: Bool) -> Self {
        self.shouldFailPurchases = shouldFail
        return self
    }

    /// Configure initial credits
    func withCredits(_ amount: Int) -> Self {
        self.credits = amount
        return self
    }

    // MARK: - Build

    /// Build a configured ServiceContainer with all mocks registered
    func build() -> ServiceContainer {
        let container = ServiceContainer(forTesting: true)
        registerAllMocks(in: container)
        return container
    }

    // MARK: - Mock Registration

    private func registerAllMocks(in container: ServiceContainer) {
        // Core Logging
        let mockLogger = MockLoggingService()
        container.register(LoggingService.self, instance: mockLogger)

        // Analytics (use real for console output during tests)
        container.register(AnalyticsService.self, lifecycle: .singleton) { _ in
            AnalyticsService()
        }

        // Firebase Auth
        let mockAuth = createMockAuth()
        container.register(FirebaseAuthServiceProtocol.self, instance: mockAuth)
        container.register(MockFirebaseAuth.self, instance: mockAuth)

        // Firebase Firestore
        let mockFirestore = createMockFirestore()
        container.register(MockFirestore.self, instance: mockFirestore)

        // Claude API
        let mockClaudeAPI = MockClaudeAPI()
        container.register(MockClaudeAPI.self, instance: mockClaudeAPI)

        // Store Manager
        let mockStoreManager = createMockStoreManager(logger: mockLogger)
        container.register(MockStoreManager.self, instance: mockStoreManager)

        // Note: SubscriptionManager, PaywallManager, and other services
        // should be created via their respective state builders for proper test setup
    }

    private func createMockAuth() -> MockFirebaseAuth {
        let mock = MockFirebaseAuth(authenticated: authState.isAuthenticated)

        switch authState {
        case .signedOut:
            break
        case .authenticated(let userId, let email):
            mock.simulateAuthenticatedUser(id: userId, email: email)
        case .authenticatedWithDisplayName(let userId, let email, let displayName):
            mock.simulateAuthenticatedUser(id: userId, email: email)
            mock.mockDisplayName = displayName
        }

        return mock
    }

    private func createMockFirestore() -> MockFirestore {
        let mock = MockFirestore()

        switch firestoreState {
        case .empty:
            break
        case .seeded(let collections):
            for (collectionPath, documents) in collections {
                mock.seed(collection: collectionPath, documents: documents)
            }
        case .offline:
            mock.simulateOffline = true
        case .failing(let error):
            mock.shouldFail = true
            mock.injectedError = error
        }

        return mock
    }

    private func createMockStoreManager(logger: LoggingService) -> MockStoreManager {
        let mock = MockStoreManager(logger: logger, analytics: AnalyticsService())
        mock.shouldFailPurchase = shouldFailPurchases
        return mock
    }

    // MARK: - Convenience Factory Methods

    /// Create a basic test container with default configuration
    static func create() -> ServiceContainer {
        return TestServiceContainer().build()
    }

    /// Create a test container with authenticated user
    static func createAuthenticated(
        userId: String = "test-user-123",
        email: String = "test@example.com"
    ) -> ServiceContainer {
        return TestServiceContainer()
            .authenticated(userId: userId, email: email)
            .build()
    }

    /// Create a test container configured for subscription testing
    static func createForSubscription(
        trialDay: Int = 1,
        credits: Int = 25
    ) -> ServiceContainer {
        return TestServiceContainer()
            .authenticated()
            .withCredits(credits)
            .build()
    }

    // MARK: - Reset Support

    /// Reset a container's singletons for test isolation
    static func reset(_ container: ServiceContainer) {
        container.resetSingletons()
    }

    /// Completely clear a container (registrations and singletons)
    static func clear(_ container: ServiceContainer) {
        container.reset()
    }
}

// MARK: - Mock State Enums

/// Authentication state for test configuration
enum MockAuthState {
    case signedOut
    case authenticated(userId: String, email: String)
    case authenticatedWithDisplayName(userId: String, email: String, displayName: String)

    var isAuthenticated: Bool {
        switch self {
        case .signedOut:
            return false
        case .authenticated, .authenticatedWithDisplayName:
            return true
        }
    }
}

/// Firestore state for test configuration
enum MockFirestoreState {
    case empty
    case seeded(collections: [String: [String: [String: Any]]])
    case offline
    case failing(error: Error)
}

// MARK: - XCTestCase Extension

import XCTest

extension XCTestCase {
    /// Create a test service container with default configuration
    @MainActor
    func createTestContainer() -> ServiceContainer {
        return TestServiceContainer.create()
    }

    /// Create a test service container with authenticated user
    @MainActor
    func createAuthenticatedTestContainer(
        userId: String = "test-user-123",
        email: String = "test@example.com"
    ) -> ServiceContainer {
        return TestServiceContainer.createAuthenticated(userId: userId, email: email)
    }
}
