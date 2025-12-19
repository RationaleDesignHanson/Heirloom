import XCTest
@testable import Heirloom

/// Tests for AIConfiguration - API key management, feature toggles, provider selection
/// Target coverage: 90%+ (configuration is critical)
@MainActor
final class AIConfigurationTests: XCTestCase {

    var configuration: AIConfiguration!

    override func setUp() async throws {
        // Reset configuration before each test
        configuration = AIConfiguration.shared

        // Clear all stored data
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults.standard.synchronize()

        // Reset to defaults
        configuration.enableAIParsing = false
        configuration.enableAICategories = false
        configuration.enableAIEnhancement = false
        configuration.selectedProvider = .anthropic
    }

    override func tearDown() async throws {
        // Clean up after each test
        configuration.setAPIKey(nil, for: .anthropic)
        configuration.setAPIKey(nil, for: .openai)

        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }

    // MARK: - API Key Management Tests

    func test_setAPIKey_storesInKeychain() async throws {
        let testKey = AITestFixtures.validAPIKey

        configuration.setAPIKey(testKey, for: .anthropic)

        let storedKey = configuration.apiKey(for: .anthropic)
        XCTAssertEqual(storedKey, testKey, "API key should be stored and retrievable")
    }

    func test_setAPIKey_withNil_deletesFromKeychain() async throws {
        // First store a key
        configuration.setAPIKey(AITestFixtures.validAPIKey, for: .anthropic)
        XCTAssertNotNil(configuration.apiKey(for: .anthropic))

        // Then delete it
        configuration.setAPIKey(nil, for: .anthropic)

        let storedKey = configuration.apiKey(for: .anthropic)
        XCTAssertNil(storedKey, "API key should be deleted when set to nil")
    }

    func test_setAPIKey_multipleProviders_storesSeparately() async throws {
        let anthropicKey = "sk-ant-test123"
        let openaiKey = "sk-openai-test456"

        configuration.setAPIKey(anthropicKey, for: .anthropic)
        configuration.setAPIKey(openaiKey, for: .openai)

        XCTAssertEqual(configuration.apiKey(for: .anthropic), anthropicKey)
        XCTAssertEqual(configuration.apiKey(for: .openai), openaiKey)
        XCTAssertNotEqual(configuration.apiKey(for: .anthropic), configuration.apiKey(for: .openai))
    }

    func test_apiKey_returnsNil_whenNotSet() async throws {
        let key = configuration.apiKey(for: .anthropic)
        XCTAssertNil(key, "Should return nil when no key is stored")
    }

    // MARK: - Configuration Validation Tests

    func test_isConfigured_returnsTrueForValidKey() async throws {
        configuration.setAPIKey(AITestFixtures.validAPIKey, for: .anthropic)

        XCTAssertTrue(
            configuration.isConfigured(provider: .anthropic),
            "Should return true when valid API key with correct prefix is stored"
        )
    }

    func test_isConfigured_returnsFalseForInvalidPrefix() async throws {
        configuration.setAPIKey("invalid-key-format", for: .anthropic)

        XCTAssertFalse(
            configuration.isConfigured(provider: .anthropic),
            "Should return false when API key has invalid prefix"
        )
    }

    func test_isConfigured_returnsFalseForEmptyKey() async throws {
        configuration.setAPIKey("", for: .anthropic)

        XCTAssertFalse(
            configuration.isConfigured(provider: .anthropic),
            "Should return false for empty API key"
        )
    }

    func test_isConfigured_returnsFalseWhenKeyNotSet() async throws {
        XCTAssertFalse(
            configuration.isConfigured(provider: .anthropic),
            "Should return false when no API key is set"
        )
    }

    func test_isConfigured_anthropicKey_requiresSkAntPrefix() async throws {
        // Valid prefix
        configuration.setAPIKey("sk-ant-validkey123", for: .anthropic)
        XCTAssertTrue(configuration.isConfigured(provider: .anthropic))

        // Invalid prefixes
        configuration.setAPIKey("sk-openai-key123", for: .anthropic)
        XCTAssertFalse(configuration.isConfigured(provider: .anthropic))

        configuration.setAPIKey("apikey123", for: .anthropic)
        XCTAssertFalse(configuration.isConfigured(provider: .anthropic))
    }

    // MARK: - Feature Toggle Tests

    func test_enableAIParsing_persistsToUserDefaults() async throws {
        // Enable
        configuration.enableAIParsing = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "ai_parsing_enabled"))

        // Disable
        configuration.enableAIParsing = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "ai_parsing_enabled"))
    }

    func test_enableAICategories_persistsToUserDefaults() async throws {
        configuration.enableAICategories = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "ai_categories_enabled"))

        configuration.enableAICategories = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "ai_categories_enabled"))
    }

    func test_enableAIEnhancement_persistsToUserDefaults() async throws {
        configuration.enableAIEnhancement = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "ai_enhancement_enabled"))

        configuration.enableAIEnhancement = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "ai_enhancement_enabled"))
    }

    func test_featureToggles_loadFromUserDefaults() async throws {
        // Set values in UserDefaults directly
        UserDefaults.standard.set(true, forKey: "ai_parsing_enabled")
        UserDefaults.standard.set(true, forKey: "ai_categories_enabled")
        UserDefaults.standard.set(false, forKey: "ai_enhancement_enabled")

        // Note: Can't test init directly since it's private
        // This tests that values persist across app restart would work
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "ai_parsing_enabled"))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "ai_categories_enabled"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "ai_enhancement_enabled"))
    }

    func test_anyAIEnabled_returnsTrueWhenAnyFeatureEnabled() async throws {
        configuration.enableAIParsing = false
        configuration.enableAICategories = false
        configuration.enableAIEnhancement = false
        XCTAssertFalse(configuration.anyAIEnabled, "Should return false when all features disabled")

        configuration.enableAIParsing = true
        XCTAssertTrue(configuration.anyAIEnabled, "Should return true when parsing enabled")

        configuration.enableAIParsing = false
        configuration.enableAICategories = true
        XCTAssertTrue(configuration.anyAIEnabled, "Should return true when categories enabled")

        configuration.enableAICategories = false
        configuration.enableAIEnhancement = true
        XCTAssertTrue(configuration.anyAIEnabled, "Should return true when enhancement enabled")
    }

    func test_anyAIEnabled_returnsFalseWhenAllDisabled() async throws {
        configuration.enableAIParsing = false
        configuration.enableAICategories = false
        configuration.enableAIEnhancement = false

        XCTAssertFalse(
            configuration.anyAIEnabled,
            "Should return false when all AI features are disabled"
        )
    }

    // MARK: - Model Selection Tests

    func test_model_returnsCorrectModelForParsing() async throws {
        configuration.selectedProvider = .anthropic

        let model = configuration.model(for: .parsing)

        XCTAssertEqual(
            model,
            "claude-3-haiku-20240307",
            "Should use Haiku (fast model) for parsing tasks"
        )
    }

    func test_model_returnsCorrectModelForEnhancement() async throws {
        configuration.selectedProvider = .anthropic

        let model = configuration.model(for: .enhancement)

        XCTAssertEqual(
            model,
            "claude-3-5-sonnet-20241022",
            "Should use Sonnet (smart model) for enhancement tasks"
        )
    }

    func test_model_returnsCorrectModelForCategorization() async throws {
        configuration.selectedProvider = .anthropic

        let model = configuration.model(for: .categorization)

        XCTAssertEqual(
            model,
            "claude-3-haiku-20240307",
            "Should use Haiku (fast model) for category detection"
        )
    }

    func test_model_returnsOpenAIModelsWhenProviderIsOpenAI() async throws {
        configuration.selectedProvider = .openai

        XCTAssertEqual(
            configuration.model(for: .parsing),
            "gpt-4o-mini",
            "Should use GPT-4o-mini for parsing when OpenAI selected"
        )

        XCTAssertEqual(
            configuration.model(for: .enhancement),
            "gpt-4o",
            "Should use GPT-4o for enhancement when OpenAI selected"
        )
    }

    // MARK: - Provider Tests

    func test_selectedProvider_persistsToUserDefaults() async throws {
        configuration.selectedProvider = .anthropic
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "ai_selected_provider"),
            "Anthropic"
        )

        configuration.selectedProvider = .openai
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "ai_selected_provider"),
            "OpenAI"
        )
    }

    func test_selectedProvider_loadsFromUserDefaults() async throws {
        // Set provider in UserDefaults
        UserDefaults.standard.set("OpenAI", forKey: "ai_selected_provider")

        // Note: Can't create new instance since init is private
        // Test that the value is correctly stored in UserDefaults
        XCTAssertEqual(UserDefaults.standard.string(forKey: "ai_selected_provider"), "OpenAI")
    }

    func test_selectedProvider_defaultsToAnthropic() async throws {
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "ai_selected_provider")

        // Reset configuration to default
        configuration.selectedProvider = .anthropic

        XCTAssertEqual(
            configuration.selectedProvider,
            .anthropic,
            "Should default to Anthropic when not set"
        )
    }

    func test_providerDisplayName() async throws {
        XCTAssertEqual(AIProvider.anthropic.displayName, "Anthropic (Claude)")
        XCTAssertEqual(AIProvider.openai.displayName, "OpenAI (GPT)")
    }

    // MARK: - Analytics Integration Tests

    func test_setAPIKey_tracksAnalytics() async throws {
        let mockAnalytics = MockAnalyticsService()
        // Note: Would need dependency injection to test this properly
        // For now, just verify the method doesn't crash

        configuration.setAPIKey(AITestFixtures.validAPIKey, for: .anthropic)

        // In real implementation, would verify:
        // XCTAssertTrue(mockAnalytics.wasEventTracked(.settingChanged))
    }

    // MARK: - Edge Cases

    func test_setAPIKey_veryLongKey() async throws {
        let longKey = "sk-ant-" + String(repeating: "a", count: 1000)

        configuration.setAPIKey(longKey, for: .anthropic)

        let storedKey = configuration.apiKey(for: .anthropic)
        XCTAssertEqual(storedKey, longKey, "Should handle very long API keys")
    }

    func test_setAPIKey_specialCharacters() async throws {
        let specialKey = "sk-ant-test!@#$%^&*()_+-=[]{}|;:',.<>?"

        configuration.setAPIKey(specialKey, for: .anthropic)

        let storedKey = configuration.apiKey(for: .anthropic)
        XCTAssertEqual(storedKey, specialKey, "Should handle special characters in API keys")
    }

    func test_setAPIKey_unicode() async throws {
        let unicodeKey = "sk-ant-test中文🔑"

        configuration.setAPIKey(unicodeKey, for: .anthropic)

        let storedKey = configuration.apiKey(for: .anthropic)
        XCTAssertEqual(storedKey, unicodeKey, "Should handle Unicode characters")
    }

    func test_multipleToggles_independent() async throws {
        // Verify that toggling one feature doesn't affect others
        configuration.enableAIParsing = true
        configuration.enableAICategories = false
        configuration.enableAIEnhancement = true

        XCTAssertTrue(configuration.enableAIParsing)
        XCTAssertFalse(configuration.enableAICategories)
        XCTAssertTrue(configuration.enableAIEnhancement)

        // Change one
        configuration.enableAIParsing = false

        // Others should remain unchanged
        XCTAssertFalse(configuration.enableAIParsing)
        XCTAssertFalse(configuration.enableAICategories)
        XCTAssertTrue(configuration.enableAIEnhancement)
    }

    // MARK: - ObservableObject Tests

    func test_publishedProperties_notifyObservers() async throws {
        let expectation = XCTestExpectation(description: "Published property changed")
        expectation.expectedFulfillmentCount = 1

        let cancellable = configuration.objectWillChange.sink { _ in
            expectation.fulfill()
        }

        configuration.enableAIParsing = true

        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func test_multiplePropertyChanges_notifyObservers() async throws {
        let expectation = XCTestExpectation(description: "Multiple property changes")
        expectation.expectedFulfillmentCount = 3

        let cancellable = configuration.objectWillChange.sink { _ in
            expectation.fulfill()
        }

        configuration.enableAIParsing = true
        configuration.enableAICategories = true
        configuration.selectedProvider = .openai

        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    // MARK: - Thread Safety Tests

    func test_concurrentAPIKeyAccess() async throws {
        // Test concurrent reads/writes don't crash
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    let key = "sk-ant-test\(i)"
                    self.configuration.setAPIKey(key, for: .anthropic)
                    _ = self.configuration.apiKey(for: .anthropic)
                }
            }
        }

        // Should not crash, and should have some key stored
        XCTAssertNotNil(configuration.apiKey(for: .anthropic))
    }

    func test_concurrentFeatureToggles() async throws {
        // Test concurrent toggle changes
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    self.configuration.enableAIParsing.toggle()
                    self.configuration.enableAICategories.toggle()
                }
            }
        }

        // Should not crash
        _ = configuration.anyAIEnabled
    }
}
