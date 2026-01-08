//
//  ExampleTest.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-06
//  Example test to validate infrastructure setup
//

import XCTest
@testable import Heirloom

/// Example test demonstrating the new testing infrastructure
/// This validates that mocks, factories, and helpers are working correctly
@MainActor
final class ExampleTest: XCTestCase {

    // MARK: - Properties
    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        env = createTestEnvironment(authenticated: false, language: "en")
    }

    override func tearDown() {
        env.reset()
        env = nil
        super.tearDown()
    }

    // MARK: - Mock Infrastructure Tests

    func testMockFirebaseAuth_SignIn_Success() async throws {
        // GIVEN: Mock auth configured
        env.mockAuth.configureUser(
            email: "test@example.com",
            displayName: "Test User"
        )

        // WHEN: User signs in
        try await env.mockAuth.signInWithGoogle()

        // THEN: User is authenticated
        XCTAssertTrue(env.mockAuth.isAuthenticated)
        XCTAssertEqual(env.mockAuth.currentUserEmail, "test@example.com")
        XCTAssertEqual(env.mockAuth.signInCallCount, 1)
        XCTAssertTrue(env.mockAuth.wasCalled("signInWithGoogle"))
    }

    func testMockFirestore_DocumentOperations_Success() async throws {
        // GIVEN: Mock Firestore
        let collection = "recipes"
        let documentID = "test-recipe-123"
        let data: [String: Any] = [
            "id": documentID,
            "title": "Test Recipe",
            "servings": "4"
        ]

        // WHEN: Create document
        try env.mockFirestore.setDocument(collection: collection, id: documentID, data: data)

        // THEN: Document exists
        XCTAssertTrue(env.mockFirestore.documentExists(collection: collection, id: documentID))
        XCTAssertEqual(env.mockFirestore.documentCount(in: collection), 1)

        // WHEN: Fetch document
        let fetched = try env.mockFirestore.getDocument(collection: collection, id: documentID)

        // THEN: Data matches
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?["title"] as? String, "Test Recipe")
    }

    func testMockClaudeAPI_LanguageDetection_French() async throws {
        // GIVEN: Mock Claude API configured for French
        env.mockClaudeAPI.configureFrenchDetection(confidence: 0.95)

        // WHEN: Detect language
        let result = try await env.mockClaudeAPI.detectLanguage(
            text: "Tarte aux pommes",
            url: nil,
            domain: "marmiton.org"
        )

        // THEN: French detected
        XCTAssertEqual(result.language, "fr")
        XCTAssertEqual(result.languageName, "French")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertTrue(result.needsTranslation)
        XCTAssertEqual(result.detectedUnitSystem, "metric")
        XCTAssertEqual(env.mockClaudeAPI.detectionRequests.count, 1)
    }

    // MARK: - Factory Tests

    func testRecipeFactory_CreateEnglish_Success() {
        // WHEN: Create English recipe
        let recipe = RecipeFactory.createEnglish(title: "Test Cookies")

        // THEN: Recipe created correctly
        XCTAssertEqual(recipe.title, "Test Cookies")
        XCTAssertEqual(recipe.sourceLanguage, "en")
        XCTAssertFalse(recipe.wasTranslated)
        XCTAssertGreaterThan(recipe.ingredients.count, 0)
        XCTAssertGreaterThan(recipe.instructions.count, 0)
    }

    func testRecipeFactory_CreateFrench_Success() {
        // WHEN: Create French recipe
        let recipe = RecipeFactory.createFrench()

        // THEN: Recipe created with French metadata
        XCTAssertEqual(recipe.sourceLanguage, "fr")
        XCTAssertTrue(recipe.wasTranslated)
        XCTAssertGreaterThan(recipe.ingredients.count, 0)
    }

    func testRecipeFactory_CreateJapanese_Success() {
        // WHEN: Create Japanese recipe
        let recipe = RecipeFactory.createJapanese()

        // THEN: Recipe created with Japanese metadata
        XCTAssertEqual(recipe.sourceLanguage, "ja")
        XCTAssertTrue(recipe.wasTranslated)
        XCTAssertGreaterThan(recipe.ingredients.count, 0)
    }

    func testIngredientFactory_CreateWithConversion_Japanese() {
        // WHEN: Create Japanese ingredient with cup measurement
        let ingredient = IngredientFactory.createJapanese(
            name: "小麦粉",
            quantity: 2.0,
            unit: "カップ"
        )

        // THEN: Conversion applied (200ml Japanese → 237ml US)
        XCTAssertTrue(ingredient.wasConverted)
        XCTAssertNotNil(ingredient.convertedQuantity)
        XCTAssertEqual(ingredient.convertedQuantity!, 1.688, accuracy: 0.001) // 2 * 0.844
        XCTAssertNotNil(ingredient.conversionNote)
        XCTAssertTrue(ingredient.conversionNote!.contains("200ml"))
    }

    func testIngredientFactory_CreateWithConversion_Korean() {
        // WHEN: Create Korean ingredient with traditional unit (근)
        let ingredient = IngredientFactory.createKorean(
            name: "쇠고기",
            quantity: 1.0,
            unit: "근"
        )

        // THEN: Conversion applied (1근 = 600g)
        XCTAssertTrue(ingredient.wasConverted)
        XCTAssertEqual(ingredient.convertedQuantity!, 600.0, accuracy: 0.1)
        XCTAssertEqual(ingredient.unit, "g")
        XCTAssertNotNil(ingredient.conversionNote)
        XCTAssertTrue(ingredient.conversionNote!.contains("600g"))
    }

    // MARK: - Async Helper Tests

    func testAsyncHelpers_WaitFor_Success() async throws {
        // GIVEN: Async condition that becomes true
        var counter = 0

        // WHEN: Wait for condition
        try await AsyncTestHelpers.waitFor(timeout: 1.0) {
            counter += 1
            return counter >= 5
        }

        // THEN: Condition met
        XCTAssertGreaterThanOrEqual(counter, 5)
    }

    func testAsyncHelpers_Measure_Success() async throws {
        // WHEN: Measure async operation
        let (result, duration) = try await AsyncTestHelpers.measure {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            return "completed"
        }

        // THEN: Operation measured
        XCTAssertEqual(result, "completed")
        XCTAssertGreaterThan(duration, 0.09) // At least 90ms
        XCTAssertLessThan(duration, 0.2)     // Less than 200ms
    }

    // MARK: - Integration Test Example

    func testIntegration_FullFlow_Success() async throws {
        // GIVEN: Authenticated user
        env.mockAuth.configureUser(email: "user@example.com")
        try await env.mockAuth.signInWithGoogle()

        // GIVEN: French recipe
        let recipe = RecipeFactory.createFrench()

        // GIVEN: Mock language detection
        env.mockClaudeAPI.configureFrenchDetection()

        // WHEN: Detect language
        let detection = try await env.mockClaudeAPI.detectLanguage(
            text: recipe.title,
            url: nil,
            domain: nil
        )

        // THEN: Everything works together
        XCTAssertTrue(env.mockAuth.isAuthenticated)
        XCTAssertEqual(detection.language, "fr")
        XCTAssertEqual(recipe.sourceLanguage, "fr")

        // WHEN: Save to Firestore
        let recipeData: [String: Any] = [
            "id": recipe.id.uuidString,
            "title": recipe.title,
            "sourceLanguage": recipe.sourceLanguage ?? "en"
        ]
        try env.mockFirestore.setDocument(
            collection: "recipes",
            id: recipe.id.uuidString,
            data: recipeData
        )

        // THEN: Recipe saved
        XCTAssertTrue(env.mockFirestore.documentExists(
            collection: "recipes",
            id: recipe.id.uuidString
        ))
    }

    // MARK: - Error Injection Tests

    func testMockAuth_SignInFailure_ThrowsError() async throws {
        // GIVEN: Mock configured to fail
        env.mockAuth.simulateSignInFailure(error: AuthError.invalidCredentials)

        // WHEN/THEN: Sign in throws error
        await XCTAssertThrowsErrorAsync(try await env.mockAuth.signInWithGoogle()) { error in
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
    }

    func testMockFirestore_OfflineMode_ThrowsError() async throws {
        // GIVEN: Firestore in offline mode
        env.mockFirestore.simulateOffline = true

        // WHEN/THEN: Operations throw offline error
        await XCTAssertThrowsErrorAsync(
            try await env.mockFirestore.setDocument(
                collection: "test",
                id: "1",
                data: [:]
            )
        ) { error in
            XCTAssertEqual(error as? FirestoreError, .offline)
        }
    }
}
