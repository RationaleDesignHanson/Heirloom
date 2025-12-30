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

    // MARK: - Rate Limiting (for default key)

    private let dailyRequestLimit = 100 // Soft limit for default API key

    @Published var dailyRequestCount: Int {
        didSet {
            UserDefaults.standard.set(dailyRequestCount, forKey: Keys.dailyRequestCount)
            UserDefaults.standard.set(Date(), forKey: Keys.lastResetDate)
        }
    }

    private var lastResetDate: Date {
        get {
            return UserDefaults.standard.object(forKey: Keys.lastResetDate) as? Date ?? Date()
        }
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

        // Load or reset daily request count
        let savedCount = UserDefaults.standard.integer(forKey: Keys.dailyRequestCount)
        let lastReset = UserDefaults.standard.object(forKey: Keys.lastResetDate) as? Date ?? Date()

        // Reset counter if it's a new day
        if !Calendar.current.isDateInToday(lastReset) {
            self.dailyRequestCount = 0
        } else {
            self.dailyRequestCount = savedCount
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
    /// Checks user-provided key first, then falls back to default key from bundle
    var currentAPIKey: String? {
        // User-provided key takes precedence
        if let userKey = apiKey(for: selectedProvider), !userKey.isEmpty {
            return userKey
        }

        // Fall back to default key from bundle (Config.xcconfig)
        return defaultAPIKey(for: selectedProvider)
    }

    /// Get default API key from bundle configuration
    private func defaultAPIKey(for provider: AIProvider) -> String? {
        switch provider {
        case .anthropic:
            let key = Bundle.main.object(forInfoDictionaryKey: "DEFAULT_ANTHROPIC_KEY") as? String
            // Validate it's not the placeholder
            if let key = key, key != "YOUR_ANTHROPIC_API_KEY_HERE", !key.isEmpty {
                return key
            }
            return nil
        case .openai:
            return nil // No default OpenAI key configured
        }
    }

    /// Check if using the default (shared) API key
    var isUsingDefaultKey: Bool {
        let userKey = apiKey(for: selectedProvider)
        return userKey == nil || userKey?.isEmpty == true
    }

    /// Get masked version of current API key for display
    var maskedAPIKey: String? {
        guard let key = currentAPIKey else { return nil }
        let prefix = selectedProvider.keyPrefix
        let visibleLength = min(prefix.count + 4, key.count)
        if key.count > visibleLength {
            return String(key.prefix(visibleLength)) + String(repeating: "*", count: 12)
        }
        return key
    }

    /// Remaining quota for today (only relevant for default key)
    var remainingDailyQuota: Int {
        guard isUsingDefaultKey else { return Int.max } // Unlimited for personal keys
        return max(0, dailyRequestLimit - dailyRequestCount)
    }

    /// Check if we can make a request (for rate limiting)
    func canMakeRequest() -> Bool {
        // Personal keys have unlimited usage
        guard isUsingDefaultKey else { return true }

        // Check daily limit for default key
        return dailyRequestCount < dailyRequestLimit
    }

    /// Increment request counter (call after successful AI request)
    func incrementRequestCount() {
        guard isUsingDefaultKey else { return }
        dailyRequestCount += 1
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
        case (.anthropic, .enhancement), (.anthropic, .vision):
            return "claude-sonnet-4-20250514" // Latest model with vision capabilities
        case (.openai, .parsing), (.openai, .categorization):
            return "gpt-4o-mini" // Fast, cheap
        case (.openai, .enhancement), (.openai, .vision):
            return "gpt-4o" // Smarter with vision
        }
    }

    // MARK: - Constants

    private enum Keys {
        static let enableAIParsing = "ai_parsing_enabled"
        static let enableAICategories = "ai_categories_enabled"
        static let enableAIEnhancement = "ai_enhancement_enabled"
        static let selectedProvider = "ai_selected_provider"
        static let dailyRequestCount = "ai_daily_request_count"
        static let lastResetDate = "ai_last_reset_date"
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
    case enhancement   // Full recipe enhancement (text-based)
    case vision        // Vision API tasks (image analysis, OCR, recipe extraction)
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
        AnalyticsService.shared.track(event: .aiTokensUsed, properties: [
            "provider": provider.rawValue,
            "key_source": AIConfiguration.shared.isUsingDefaultKey ? "default" : "user",
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
