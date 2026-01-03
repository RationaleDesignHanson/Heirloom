//
//  MockAuth.swift
//  HeirloomTests
//
//  Mock implementation of Firebase Auth for testing
//

import Foundation
import FirebaseAuth
@testable import Heirloom

/// Mock Firebase Auth for testing
@MainActor
class MockAuth: AuthProtocol {
    var currentUser: UserProtocol?
    var shouldFailAuth = false
    var registeredUsers: [String: String] = [:] // email: password
    var authDelay: TimeInterval = 0.0

    func signIn(withEmail email: String, password: String) async throws -> AuthDataResultProtocol {
        if shouldFailAuth {
            throw NSError(
                domain: "MockAuth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Mock authentication failed"]
            )
        }

        if authDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(authDelay * 1_000_000_000))
        }

        // Check if user exists and password matches
        guard let storedPassword = registeredUsers[email], storedPassword == password else {
            throw NSError(
                domain: "MockAuth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid email or password"]
            )
        }

        let user = MockUser(uid: UUID().uuidString, email: email, displayName: nil)
        currentUser = user

        return MockAuthDataResult(user: user)
    }

    func signOut() throws {
        if shouldFailAuth {
            throw NSError(
                domain: "MockAuth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Mock sign out failed"]
            )
        }

        currentUser = nil
    }

    func createUser(withEmail email: String, password: String) async throws -> AuthDataResultProtocol {
        if shouldFailAuth {
            throw NSError(
                domain: "MockAuth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Mock user creation failed"]
            )
        }

        if authDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(authDelay * 1_000_000_000))
        }

        // Check if user already exists
        if registeredUsers[email] != nil {
            throw NSError(
                domain: "MockAuth",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User already exists"]
            )
        }

        registeredUsers[email] = password

        let user = MockUser(uid: UUID().uuidString, email: email, displayName: nil)
        currentUser = user

        return MockAuthDataResult(user: user)
    }

    func reset() {
        currentUser = nil
        shouldFailAuth = false
        registeredUsers.removeAll()
        authDelay = 0.0
    }

    // Helper methods for testing
    func simulateSignIn(uid: String, email: String) {
        let user = MockUser(uid: uid, email: email, displayName: nil)
        currentUser = user
    }
}

/// Mock Firebase User
struct MockUser: UserProtocol {
    let uid: String
    let email: String?
    let displayName: String?
}

/// Mock Auth data result
struct MockAuthDataResult: AuthDataResultProtocol {
    let user: UserProtocol
}
