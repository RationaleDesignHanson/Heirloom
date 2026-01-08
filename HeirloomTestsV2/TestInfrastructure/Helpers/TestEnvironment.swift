//
//  TestEnvironment.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-06
//

import Foundation
import XCTest
@testable import Heirloom

/// Standardized test environment setup for all tests
/// Provides consistent mock configuration and test isolation
@MainActor
class TestEnvironment {

    // MARK: - Shared Mocks
    var mockAuth: MockFirebaseAuth!
    var mockFirestore: MockFirestore!
    var mockClaudeAPI: MockClaudeAPI!

    // MARK: - Configuration
    var isAuthenticated: Bool
    var defaultLanguage: String

    // MARK: - Initialization

    init(authenticated: Bool = false, language: String = "en") {
        self.isAuthenticated = authenticated
        self.defaultLanguage = language
        setupMocks()
    }

    // MARK: - Setup

    private func setupMocks() {
        mockAuth = MockFirebaseAuth(authenticated: isAuthenticated)
        mockFirestore = MockFirestore()
        mockClaudeAPI = MockClaudeAPI()

        if defaultLanguage != "en" {
            configureLanguage(defaultLanguage)
        }
    }

    // MARK: - Language Configuration

    func configureLanguage(_ language: String) {
        switch language {
        case "fr":
            mockClaudeAPI.configureFrenchDetection()
        case "ja":
            mockClaudeAPI.configureJapaneseDetection()
        case "ko":
            mockClaudeAPI.configureKoreanDetection()
        default:
            mockClaudeAPI.configureEnglishDetection()
        }
    }

    // MARK: - Authentication Helpers

    func signIn() async throws {
        try await mockAuth.signInWithGoogle()
    }

    func signOut() throws {
        try mockAuth.signOut()
    }

    func authenticateUser(id: String, email: String) {
        mockAuth.simulateAuthenticatedUser(id: id, email: email)
    }

    // MARK: - Firestore Helpers

    func seedRecipes(_ recipes: [Recipe]) {
        var documents: [String: [String: Any]] = [:]
        for recipe in recipes {
            documents[recipe.id.uuidString] = [
                "id": recipe.id.uuidString,
                "title": recipe.title,
                "servings": recipe.servings
            ]
        }
        mockFirestore.seed(collection: "recipes", documents: documents)
    }

    // MARK: - Reset

    func reset() {
        mockAuth.reset()
        mockFirestore.reset()
        mockClaudeAPI.reset()
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Create a test environment with default configuration
    @MainActor
    func createTestEnvironment(authenticated: Bool = false, language: String = "en") -> TestEnvironment {
        return TestEnvironment(authenticated: authenticated, language: language)
    }
}
