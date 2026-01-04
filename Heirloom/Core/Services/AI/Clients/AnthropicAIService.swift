import Foundation
import UIKit

/// Image use case for optimized processing
enum ImageUseCase {
    case ocr        // High quality for text recognition (2048px, 0.95 compression)
    case display    // Balanced quality for general use (1600px, 0.85 compression)

    var maxDimension: CGFloat {
        switch self {
        case .ocr: return 2048
        case .display: return 1600
        }
    }

    var compressionQuality: CGFloat {
        switch self {
        case .ocr: return 0.95
        case .display: return 0.85
        }
    }
}

/// Anthropic Claude AI service client
/// Adapted from Zero Inbox's OpenAI integration pattern
/// Uses Claude API for food/recipe domain expertise including vision capabilities
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

    // MARK: - Vision API Methods

    /// Complete with vision (image + text prompt)
    func completeWithVision(
        image: UIImage,
        prompt: String,
        options: AICompletionOptions? = nil,
        useCase: ImageUseCase = .display
    ) async throws -> AICompletionResponse {
        // Check rate limit
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

        // Prepare image with quality preservation for OCR
        let (processedImage, imageData, format) = try prepareImageForVisionAPI(image, useCase: useCase)
        let base64Image = imageData.base64EncodedString()

        Log.debug("Preparing image for vision API", category: .ocr, metadata: [
            "originalWidth": Int(image.size.width),
            "originalHeight": Int(image.size.height),
            "processedWidth": Int(processedImage.size.width),
            "processedHeight": Int(processedImage.size.height),
            "sizeKB": imageData.count / 1024,
            "format": format,
            "scale": image.scale
        ])

        // Build request with vision content
        let opts = options ?? .default
        let model = opts.model ?? AIConfiguration.shared.model(for: .vision)

        let requestBody = AnthropicVisionRequest(
            model: model,
            maxTokens: opts.maxTokens ?? 1500,
            messages: [
                AnthropicVisionMessage(
                    role: "user",
                    content: [
                        .image(source: AnthropicImageSource(
                            type: "base64",
                            mediaType: format == "png" ? "image/png" : "image/jpeg",
                            data: base64Image
                        )),
                        .text(prompt)
                    ]
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

        // Execute request with retry logic
        let response = try await executeWithRetry(request, maxAttempts: 3)

        return response
    }

    /// Complete with vision and structured output
    func completeWithVisionStructured<T: Decodable>(
        image: UIImage,
        prompt: String,
        schema: T.Type,
        options: AICompletionOptions? = nil,
        useCase: ImageUseCase = .display
    ) async throws -> T {
        // Add JSON formatting instructions
        let structuredPrompt = """
        \(prompt)

        IMPORTANT: Respond ONLY with valid JSON. No markdown, no explanations, just raw JSON.
        """

        let response = try await completeWithVision(
            image: image,
            prompt: structuredPrompt,
            options: options,
            useCase: useCase
        )

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

                Log.warning("Retrying Anthropic API request", category: .network, metadata: ["attempt": attempt + 2, "maxAttempts": maxAttempts])
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

    /// Prepare image for Vision API with quality preservation
    /// Strategy: Only resize/compress if necessary to stay under Claude's 5MB limit
    /// Returns: (processed image, image data, format string)
    private func prepareImageForVisionAPI(_ image: UIImage, useCase: ImageUseCase) throws -> (UIImage, Data, String) {
        let maxFileSize = 4_500_000 // 4.5MB (leave headroom for 5MB limit)

        // Try PNG first (lossless) - best for OCR
        if let pngData = image.pngData(), pngData.count <= maxFileSize {
            Log.debug("Using PNG lossless format for OCR", category: .ocr, metadata: ["sizeKB": pngData.count / 1024])
            return (image, pngData, "png")
        }

        // PNG too large, try high-quality JPEG without resizing
        if let jpegData = image.jpegData(compressionQuality: 0.95), jpegData.count <= maxFileSize {
            Log.debug("Using JPEG with high quality, no resize", category: .ocr, metadata: ["sizeKB": jpegData.count / 1024, "quality": 0.95])
            return (image, jpegData, "jpeg")
        }

        // Still too large, need to resize
        Log.debug("Image too large for OCR, resizing required", category: .ocr, metadata: ["originalSizeKB": (image.jpegData(compressionQuality: 0.95)?.count ?? 0) / 1024])

        let resizedImage = resizeImagePreservingQuality(image, targetFileSize: maxFileSize)

        // Try PNG on resized image
        if let pngData = resizedImage.pngData(), pngData.count <= maxFileSize {
            Log.debug("Using PNG after resizing for OCR", category: .ocr, metadata: ["sizeKB": pngData.count / 1024])
            return (resizedImage, pngData, "png")
        }

        // Fall back to JPEG
        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.92) else {
            throw AIError.invalidRequest(reason: "Could not convert image to JPEG")
        }

        Log.debug("Using JPEG after resizing for OCR", category: .ocr, metadata: ["sizeKB": jpegData.count / 1024, "quality": 0.92])
        return (resizedImage, jpegData, "jpeg")
    }

    /// Resize image while preserving quality and aspect ratio
    private func resizeImagePreservingQuality(_ image: UIImage, targetFileSize: Int) -> UIImage {
        let size = image.size

        // Estimate scale factor needed (rough approximation)
        let currentSize = image.jpegData(compressionQuality: 0.95)?.count ?? Int(size.width * size.height * 4)
        let scaleFactor = sqrt(Double(targetFileSize) / Double(currentSize))

        // Apply scale factor to dimensions
        let newSize = CGSize(
            width: size.width * scaleFactor * 0.9, // 0.9 for safety margin
            height: size.height * scaleFactor * 0.9
        )

        Log.debug("Resizing image for OCR", category: .ocr, metadata: [
            "fromWidth": Int(size.width),
            "fromHeight": Int(size.height),
            "toWidth": Int(newSize.width),
            "toHeight": Int(newSize.height)
        ])

        // Use high-quality rendering
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Don't apply device scale, keep pixels 1:1
        format.opaque = false // Preserve alpha channel
        format.preferredRange = .standard // sRGB color space

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { context in
            // Use high-quality interpolation
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: newSize))
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

// MARK: - Vision API Types

private struct AnthropicVisionRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [AnthropicVisionMessage]
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

private struct AnthropicVisionMessage: Encodable {
    let role: String
    let content: [AnthropicContentBlock]
}

private enum AnthropicContentBlock: Encodable {
    case text(String)
    case image(source: AnthropicImageSource)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)

        case .image(let source):
            try container.encode("image", forKey: .type)
            try container.encode(source, forKey: .source)
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case source
    }
}

private struct AnthropicImageSource: Encodable {
    let type: String           // "base64"
    let mediaType: String      // "image/jpeg" or "image/png"
    let data: String           // base64 encoded image

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}
