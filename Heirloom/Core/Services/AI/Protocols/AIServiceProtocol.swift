import Foundation

/// Protocol defining AI service capabilities
/// Adapted from Zero Inbox's service protocol pattern
@MainActor
protocol AIServiceProtocol {
    /// The AI provider name (e.g., "Anthropic", "OpenAI")
    var providerName: String { get }

    /// Check if the service is configured and ready
    var isConfigured: Bool { get }

    /// Complete a text prompt with AI
    /// - Parameters:
    ///   - prompt: The input prompt text
    ///   - options: Optional configuration (model, temperature, etc.)
    /// - Returns: AI completion response
    func complete(
        prompt: String,
        options: AICompletionOptions?
    ) async throws -> AICompletionResponse

    /// Complete a structured prompt (for JSON responses)
    /// - Parameters:
    ///   - prompt: The input prompt text
    ///   - schema: Expected JSON schema
    ///   - options: Optional configuration
    /// - Returns: Structured AI response
    func completeStructured<T: Decodable>(
        prompt: String,
        schema: T.Type,
        options: AICompletionOptions?
    ) async throws -> T

    /// Estimate cost for a completion
    /// - Parameters:
    ///   - inputTokens: Estimated input token count
    ///   - outputTokens: Estimated output token count
    /// - Returns: Estimated cost in USD
    func estimateCost(inputTokens: Int, outputTokens: Int) -> Decimal
}

// MARK: - Supporting Types

/// Options for AI completion requests
struct AICompletionOptions {
    /// Model to use (e.g., "claude-3-haiku", "gpt-4o")
    var model: String?

    /// Temperature (0.0 to 1.0, higher = more creative)
    var temperature: Double?

    /// Maximum tokens to generate
    var maxTokens: Int?

    /// System message/context
    var systemMessage: String?

    /// Stop sequences
    var stopSequences: [String]?

    static let `default` = AICompletionOptions(
        model: nil,
        temperature: 0.7,
        maxTokens: 1024,
        systemMessage: nil,
        stopSequences: nil
    )
}

/// AI completion response
struct AICompletionResponse {
    /// The generated text
    var content: String

    /// Model used for generation
    var model: String

    /// Token usage statistics
    var usage: TokenUsage

    /// Additional metadata
    var metadata: [String: Any]?
}

/// Token usage statistics (adapted from Zero's cost tracking)
struct TokenUsage {
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int

    var totalCost: Decimal {
        // Will be calculated by specific AI service
        return 0
    }
}

// MARK: - Protocol Extensions

extension AIServiceProtocol {
    /// Complete with default options
    func complete(prompt: String) async throws -> AICompletionResponse {
        try await complete(prompt: prompt, options: .default)
    }

    /// Complete structured with default options
    func completeStructured<T: Decodable>(
        prompt: String,
        schema: T.Type
    ) async throws -> T {
        try await completeStructured(prompt: prompt, schema: schema, options: .default)
    }
}
