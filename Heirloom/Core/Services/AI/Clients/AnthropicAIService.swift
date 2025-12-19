import Foundation

/// Anthropic Claude AI service client
/// Adapted from Zero Inbox's OpenAI integration pattern
/// Uses Claude API for food/recipe domain expertise
@MainActor
class AnthropicAIService: AIServiceProtocol {
    static let shared = AnthropicAIService()

    private let apiVersion = "2023-06-01"
    private let baseURL = "https://api.anthropic.com/v1"
    private let session: URLSession

    // MARK: - AIServiceProtocol

    var providerName: String { "Anthropic" }

    var isConfigured: Bool {
        return AIConfiguration.shared.isConfigured(provider: .anthropic)
    }

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Completion Methods

    func complete(
        prompt: String,
        options: AICompletionOptions? = nil
    ) async throws -> AICompletionResponse {
        // Check rate limit (for default key users)
        let config = AIConfiguration.shared
        guard config.canMakeRequest() else {
            throw AIError.quotaExceeded(
                provider: providerName,
                limit: 100,
                resetDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            )
        }

        // Validate configuration
        guard let apiKey = config.currentAPIKey else {
            throw AIError.notConfigured(provider: providerName)
        }

        // Build request
        let opts = options ?? .default
        let model = opts.model ?? AIConfiguration.shared.model(for: .parsing)

        let requestBody = AnthropicRequest(
            model: model,
            maxTokens: opts.maxTokens ?? 1024,
            messages: [
                AnthropicMessage(
                    role: "user",
                    content: prompt
                )
            ],
            temperature: opts.temperature ?? 0.7,
            system: opts.systemMessage
        )

        // Create HTTP request
        var request = try createRequest(endpoint: "/messages")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONEncoder().encode(requestBody)

        // Execute request with retry logic (Zero's pattern)
        let response = try await executeWithRetry(request, maxAttempts: 3)

        return response
    }

    func completeStructured<T: Decodable>(
        prompt: String,
        schema: T.Type,
        options: AICompletionOptions? = nil
    ) async throws -> T {
        // Add JSON formatting instructions to prompt
        let structuredPrompt = """
        \(prompt)

        IMPORTANT: Respond ONLY with valid JSON matching this structure. No markdown, no explanations, just raw JSON.
        """

        let response = try await complete(prompt: structuredPrompt, options: options)

        // Parse JSON response
        guard let data = response.content.data(using: .utf8) else {
            throw AIError.invalidResponse(reason: "Could not convert response to data")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AIError.jsonDecodingFailed(underlying: error)
        }
    }

    func estimateCost(inputTokens: Int, outputTokens: Int) -> Decimal {
        // Claude Haiku pricing (default model)
        let inputCost = Decimal(inputTokens) / 1_000_000 * 0.25
        let outputCost = Decimal(outputTokens) / 1_000_000 * 1.25
        return inputCost + outputCost
    }

    // MARK: - Private Methods

    private func createRequest(endpoint: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint) else {
            throw AIError.invalidRequest(reason: "Invalid endpoint: \(endpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        return request
    }

    private func executeWithRetry(
        _ request: URLRequest,
        maxAttempts: Int
    ) async throws -> AICompletionResponse {
        var lastError: AIError?

        for attempt in 0..<maxAttempts {
            do {
                return try await execute(request)
            } catch let error as AIError {
                lastError = error

                // Only retry on retryable errors
                guard error.isRetryable else {
                    throw error
                }

                // Don't retry on last attempt
                guard attempt < maxAttempts - 1 else {
                    throw error
                }

                // Wait before retrying (exponential backoff)
                let delay = error.retryDelay(attempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                print("⚠️ Retrying Anthropic request (attempt \(attempt + 2)/\(maxAttempts))...")
            }
        }

        throw lastError ?? AIError.networkError(underlying: URLError(.unknown))
    }

    private func execute(_ request: URLRequest) async throws -> AICompletionResponse {
        let (data, urlResponse) = try await session.data(for: request)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw AIError.invalidResponse(reason: "Not an HTTP response")
        }

        // Handle HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw handleHTTPError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse Anthropic response
        let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        // Extract content
        guard let content = anthropicResponse.content.first?.text else {
            throw AIError.invalidResponse(reason: "No content in response")
        }

        // Build response with token usage
        let usage = TokenUsage(
            inputTokens: anthropicResponse.usage.inputTokens,
            outputTokens: anthropicResponse.usage.outputTokens,
            totalTokens: anthropicResponse.usage.inputTokens + anthropicResponse.usage.outputTokens
        )

        // Track usage
        AIUsageTracker.shared.trackUsage(tokens: usage, provider: .anthropic)

        // Increment request counter for rate limiting
        AIConfiguration.shared.incrementRequestCount()

        return AICompletionResponse(
            content: content,
            model: anthropicResponse.model,
            usage: usage,
            metadata: [
                "stop_reason": anthropicResponse.stopReason ?? "unknown",
                "id": anthropicResponse.id
            ]
        )
    }

    private func handleHTTPError(statusCode: Int, message: String?) -> AIError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 429:
            // Try to parse retry-after header
            return .rateLimited(retryAfter: nil)
        case 400...499:
            return .apiError(statusCode: statusCode, message: message ?? "Client error")
        case 500...599:
            return .apiError(statusCode: statusCode, message: message ?? "Server error")
        default:
            return .apiError(statusCode: statusCode, message: message ?? "Unknown error")
        }
    }
}

// MARK: - Anthropic API Types

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [AnthropicMessage]
    let temperature: Double?
    let system: String?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case temperature
        case system
    }
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicContent]
    let model: String
    let stopReason: String?
    let usage: AnthropicUsage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }
}

private struct AnthropicContent: Decodable {
    let type: String
    let text: String?
}

private struct AnthropicUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}
