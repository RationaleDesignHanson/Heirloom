import Foundation
import Security

/// AI service configuration and API key management
/// Adapted from Zero Inbox's environment variable pattern
/// Uses iOS Keychain for secure storage instead of .env files
@MainActor
class AIConfiguration: ObservableObject {
    static let shared = AIConfiguration()

    // MARK: - Published Properties

    @Published var enableAIParsing: Bool {
        didSet { UserDefaults.standard.set(enableAIParsing, forKey: Keys.enableAIParsing) }
    }

    @Published var enableAICategories: Bool {
        didSet { UserDefaults.standard.set(enableAICategories, forKey: Keys.enableAICategories) }
    }

    @Published var enableAIEnhancement: Bool {
        didSet { UserDefaults.standard.set(enableAIEnhancement, forKey: Keys.enableAIEnhancement) }
    }

    @Published var selectedProvider: AIProvider {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: Keys.selectedProvider) }
    }

    // MARK: - Initialization

    private init() {
        self.enableAIParsing = UserDefaults.standard.bool(forKey: Keys.enableAIParsing)
        self.enableAICategories = UserDefaults.standard.bool(forKey: Keys.enableAICategories)
        self.enableAIEnhancement = UserDefaults.standard.bool(forKey: Keys.enableAIEnhancement)

        if let providerRaw = UserDefaults.standard.string(forKey: Keys.selectedProvider),
           let provider = AIProvider(rawValue: providerRaw) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .anthropic // Default to Anthropic
        }
    }

    // MARK: - API Key Management (Keychain Storage)

    /// Get API key for a provider
    func apiKey(for provider: AIProvider) -> String? {
        return Keychain.shared.get(provider.keychainKey)
    }

    /// Set API key for a provider
    func setAPIKey(_ key: String?, for provider: AIProvider) {
        if let key = key {
            Keychain.shared.set(provider.keychainKey, value: key)
        } else {
            Keychain.shared.delete(provider.keychainKey)
        }
        objectWillChange.send()
    }

    /// Check if a provider is configured
    func isConfigured(provider: AIProvider) -> Bool {
        guard let key = apiKey(for: provider) else { return false }
        return !key.isEmpty && key.hasPrefix(provider.keyPrefix)
    }

    /// Get the current active provider's API key
    var currentAPIKey: String? {
        return apiKey(for: selectedProvider)
    }

    /// Check if any AI feature is enabled
    var anyAIEnabled: Bool {
        return enableAIParsing || enableAICategories || enableAIEnhancement
    }

    // MARK: - Provider Configuration

    /// Get model name for a specific task
    func model(for task: AITask) -> String {
        switch (selectedProvider, task) {
        case (.anthropic, .parsing), (.anthropic, .categorization):
            return "claude-3-haiku-20240307" // Fast, cheap for simple tasks
        case (.anthropic, .enhancement):
            return "claude-3-5-sonnet-20241022" // Smarter for complex tasks
        case (.openai, .parsing), (.openai, .categorization):
            return "gpt-4o-mini" // Fast, cheap
        case (.openai, .enhancement):
            return "gpt-4o" // Smarter
        }
    }

    // MARK: - Constants

    private enum Keys {
        static let enableAIParsing = "ai_parsing_enabled"
        static let enableAICategories = "ai_categories_enabled"
        static let enableAIEnhancement = "ai_enhancement_enabled"
        static let selectedProvider = "ai_selected_provider"
    }
}

// MARK: - AI Provider

enum AIProvider: String, CaseIterable, Identifiable {
    case anthropic = "Anthropic"
    case openai = "OpenAI"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI (GPT)"
        }
    }

    var keychainKey: String {
        switch self {
        case .anthropic: return "anthropic_api_key"
        case .openai: return "openai_api_key"
        }
    }

    var keyPrefix: String {
        switch self {
        case .anthropic: return "sk-ant-"
        case .openai: return "sk-"
        }
    }

    var apiEndpoint: String {
        switch self {
        case .anthropic: return "https://api.anthropic.com/v1"
        case .openai: return "https://api.openai.com/v1"
        }
    }
}

// MARK: - AI Task Types

enum AITask {
    case parsing       // Ingredient parsing
    case categorization // Recipe categorization
    case enhancement   // Full recipe enhancement
}

// MARK: - Keychain Helper (Adapted from Zero's secure storage pattern)

class Keychain {
    static let shared = Keychain()
    private init() {}

    /// Store a value in Keychain
    func set(_ key: String, value: String) {
        // Delete existing item first
        delete(key)

        // Add new item
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ Keychain: Failed to save \(key): \(status)")
        }
    }

    /// Retrieve a value from Keychain
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Delete a value from Keychain
    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Check if a key exists in Keychain
    func exists(_ key: String) -> Bool {
        return get(key) != nil
    }
}

// MARK: - Cost Tracking (Zero's Pattern)

@MainActor
class AIUsageTracker: ObservableObject {
    static let shared = AIUsageTracker()

    @Published var totalTokensUsed: Int = 0
    @Published var totalCost: Decimal = 0
    @Published var requestCount: Int = 0

    private init() {
        loadFromUserDefaults()
    }

    func trackUsage(tokens: TokenUsage, provider: AIProvider) {
        totalTokensUsed += tokens.totalTokens
        requestCount += 1

        // Calculate cost based on provider
        let cost = calculateCost(tokens: tokens, provider: provider)
        totalCost += cost

        saveToUserDefaults()

        // Track in analytics
        AnalyticsService.shared.track(.aiTokensUsed, properties: [
            "provider": provider.rawValue,
            "input_tokens": tokens.inputTokens,
            "output_tokens": tokens.outputTokens,
            "total_tokens": tokens.totalTokens,
            "cost": cost
        ])
    }

    private func calculateCost(tokens: TokenUsage, provider: AIProvider) -> Decimal {
        // Pricing as of Jan 2025
        switch provider {
        case .anthropic:
            // Claude Haiku: $0.25 per 1M input, $1.25 per 1M output
            // Claude Sonnet: $3 per 1M input, $15 per 1M output
            let inputCost = Decimal(tokens.inputTokens) / 1_000_000 * 0.25
            let outputCost = Decimal(tokens.outputTokens) / 1_000_000 * 1.25
            return inputCost + outputCost

        case .openai:
            // GPT-4o-mini: $0.15 per 1M input, $0.60 per 1M output
            // GPT-4o: $2.50 per 1M input, $10 per 1M output
            let inputCost = Decimal(tokens.inputTokens) / 1_000_000 * 0.15
            let outputCost = Decimal(tokens.outputTokens) / 1_000_000 * 0.60
            return inputCost + outputCost
        }
    }

    func reset() {
        totalTokensUsed = 0
        totalCost = 0
        requestCount = 0
        saveToUserDefaults()
    }

    private func loadFromUserDefaults() {
        totalTokensUsed = UserDefaults.standard.integer(forKey: "ai_total_tokens")
        requestCount = UserDefaults.standard.integer(forKey: "ai_request_count")

        if let costString = UserDefaults.standard.string(forKey: "ai_total_cost"),
           let cost = Decimal(string: costString) {
            totalCost = cost
        }
    }

    private func saveToUserDefaults() {
        UserDefaults.standard.set(totalTokensUsed, forKey: "ai_total_tokens")
        UserDefaults.standard.set(requestCount, forKey: "ai_request_count")
        UserDefaults.standard.set(totalCost.description, forKey: "ai_total_cost")
    }
}

// MARK: - Analytics Extension

extension AnalyticsEvent {
    static let aiTokensUsed = AnalyticsEvent(rawValue: "AI Tokens Used")
    static let aiIngredientParseSuccess = AnalyticsEvent(rawValue: "AI Ingredient Parse Success")
    static let aiIngredientParseFailed = AnalyticsEvent(rawValue: "AI Ingredient Parse Failed")
    static let aiCategoryDetectionSuccess = AnalyticsEvent(rawValue: "AI Category Detection Success")
    static let aiCategoryDetectionFailed = AnalyticsEvent(rawValue: "AI Category Detection Failed")
    static let aiEnhancementSuccess = AnalyticsEvent(rawValue: "AI Enhancement Success")
    static let aiEnhancementFailed = AnalyticsEvent(rawValue: "AI Enhancement Failed")
}
