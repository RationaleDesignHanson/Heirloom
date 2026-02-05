//
//  MockFirebaseAuth.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-06
//

import Foundation
import Combine
import FirebaseAuth
@testable import Heirloom

/// Mock implementation of FirebaseAuthServiceProtocol for testing
/// Provides full state simulation and error injection capabilities
@MainActor
class MockFirebaseAuth: FirebaseAuthServiceProtocol, MockTracking, MockErrorInjection, MockStateSimulation {

    // MARK: - ObservableObject
    nonisolated(unsafe) let objectWillChange = ObservableObjectPublisher()

    // MARK: - MockTracking
    var callLog: [String] = []

    // MARK: - MockErrorInjection
    var shouldFail = false
    var injectedError: Error?

    // MARK: - FirebaseAuthServiceProtocol Properties
    var isAuthenticated = false
    var currentUser: FirebaseAuth.User? { nil } // Firebase SDK type - can't instantiate in tests
    var currentUserId: String? { mockUserID }
    var currentUserEmail: String? { mockEmail }
    var isAuthenticating = false
    var authError: Error?

    // MARK: - Mock-Specific Properties
    var mockUserID: String?
    var mockEmail: String?
    var mockDisplayName: String?
    var mockPhotoURL: String?

    // MARK: - Behavior Configuration
    var signInDelay: TimeInterval = 0
    var signOutDelay: TimeInterval = 0
    var autoGenerateUser = true

    // MARK: - Test Inspection
    private(set) var signInCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var lastSignInMethod: String?

    // MARK: - Initialization
    init(authenticated: Bool = false) {
        self.isAuthenticated = authenticated
    }

    // MARK: - FirebaseAuthServiceProtocol Required Methods

    func signOut() throws {
        recordCall("signOut")
        signOutCallCount += 1

        if shouldFail {
            throw injectedError ?? AuthError.signOutFailed
        }

        isAuthenticated = false
        mockUserID = nil
        mockEmail = nil
    }

    // MARK: - FirebaseAuthServiceProtocol Required Methods

    func signInWithApple() async throws {
        recordCall("signInWithApple")
        signInCallCount += 1
        lastSignInMethod = "apple"

        if signInDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(signInDelay * 1_000_000_000))
        }

        if shouldFail {
            throw injectedError ?? AuthError.signInFailed
        }

        isAuthenticated = true
        mockUserID = mockUserID ?? "00000000-0000-0000-0000-000000000002"
        mockEmail = mockEmail ?? "apple@example.com"
    }

    func signInWithGoogle() async throws {
        recordCall("signInWithGoogle")
        signInCallCount += 1
        lastSignInMethod = "google"

        if signInDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(signInDelay * 1_000_000_000))
        }

        if shouldFail {
            throw injectedError ?? AuthError.signInFailed
        }

        isAuthenticated = true
        mockUserID = mockUserID ?? "00000000-0000-0000-0000-000000000001"
        mockEmail = mockEmail ?? "test@example.com"
    }

    func signInWithEmail(email: String, password: String) async throws {
        recordCall("signInWithEmail")
        signInCallCount += 1
        lastSignInMethod = "email"

        if signInDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(signInDelay * 1_000_000_000))
        }

        if shouldFail {
            throw injectedError ?? AuthError.signInFailed
        }

        isAuthenticated = true
        mockUserID = mockUserID ?? UUID().uuidString
        mockEmail = email
    }

    func createAccountWithEmail(email: String, password: String) async throws {
        recordCall("createAccountWithEmail")
        signInCallCount += 1
        lastSignInMethod = "email_create"

        if shouldFail {
            throw injectedError ?? AuthError.userCreationFailed
        }

        isAuthenticated = true
        mockUserID = mockUserID ?? UUID().uuidString
        mockEmail = email
    }

    func sendPasswordReset(email: String) async throws {
        recordCall("sendPasswordReset")

        if shouldFail {
            throw injectedError ?? AuthError.networkError
        }

        // Simulate password reset email sent
    }

    func deleteAccount() async throws {
        recordCall("deleteAccount")

        if shouldFail {
            throw injectedError ?? AuthError.userNotFound
        }

        isAuthenticated = false
        mockUserID = nil
        mockEmail = nil
    }

    // MARK: - MockStateSimulation

    func reset() {
        callLog.removeAll()
        isAuthenticated = false
        isAuthenticating = false
        authError = nil
        shouldFail = false
        injectedError = nil
        signInCallCount = 0
        signOutCallCount = 0
        lastSignInMethod = nil
        signInDelay = 0
        signOutDelay = 0
        autoGenerateUser = true
        mockUserID = nil
        mockEmail = nil
        mockDisplayName = nil
        mockPhotoURL = nil
    }

    // MARK: - Test Helpers

    /// Configure mock to return specific user on sign in
    func configureUser(id: String? = nil, email: String? = nil, displayName: String? = nil, photoURL: String? = nil) {
        mockUserID = id
        mockEmail = email
        mockDisplayName = displayName
        mockPhotoURL = photoURL
    }

    /// Simulate user already authenticated
    func simulateAuthenticatedUser(id: String, email: String) {
        isAuthenticated = true
        mockUserID = id
        mockEmail = email
    }

    /// Simulate sign-in failure with specific error
    func simulateSignInFailure(error: Error? = nil) {
        shouldFail = true
        injectedError = error ?? AuthError.signInFailed
    }
}

// MARK: - AuthError

enum AuthError: Error, Equatable {
    case signInFailed
    case signOutFailed
    case userCreationFailed
    case refreshFailed
    case networkError
    case invalidCredentials
    case userNotFound

    var localizedDescription: String {
        switch self {
        case .signInFailed: return "Sign in failed"
        case .signOutFailed: return "Sign out failed"
        case .userCreationFailed: return "User creation failed"
        case .refreshFailed: return "Auth refresh failed"
        case .networkError: return "Network error"
        case .invalidCredentials: return "Invalid credentials"
        case .userNotFound: return "User not found"
        }
    }
}

