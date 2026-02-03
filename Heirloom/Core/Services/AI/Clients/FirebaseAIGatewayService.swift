import Foundation
import UIKit
import FirebaseFunctions

/// Firebase AI Gateway Service
/// Secure proxy to backend AI services - NO API KEYS IN CLIENT
/// All API keys remain server-side in Firebase Cloud Functions
@MainActor
class FirebaseAIGatewayService: AIServiceProtocol {
    // MARK: - Dependencies

    private let configuration: AIConfigurationProtocol
    private let usageTracker: AIUsageTracker
    private let functions: Functions

    // MARK: - AIServiceProtocol

    var providerName: String { "Firebase Gateway" }

    var isConfigured: Bool {
        // Gateway is always configured - handles auth via Firebase tokens
        return true
    }

    // MARK: - Initialization

    init(configuration: AIConfigurationProtocol, usageTracker: AIUsageTracker) {
        self.configuration = configuration
        self.usageTracker = usageTracker
        self.functions = Functions.functions()

        // Use emulator for local development
        #if DEBUG
        // Uncomment to use local emulator:
        // functions.useEmulator(withHost: "localhost", port: 5001)
        #endif
    }

    // MARK: - Completion Methods

    func complete(
        prompt: String,
        options: AICompletionOptions? = nil
    ) async throws -> AICompletionResponse {
        let opts = options ?? .default

        let data: [String: Any] = [
            "prompt": prompt,
            "provider": configuration.selectedProvider.rawValue.lowercased(),
            "model": opts.model ?? configuration.model(for: .parsing),
            "temperature": opts.temperature ?? 0.7,
            "maxTokens": opts.maxTokens ?? 1024,
            "systemMessage": opts.systemMessage as Any,
        ]

        do {
            let result = try await functions.httpsCallable("aiComplete").call(data)

            guard let responseData = result.data as? [String: Any] else {
                throw AIError.invalidResponse(reason: "Invalid response format from gateway")
            }

            return try parseAIResponse(responseData)
        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            throw handleFirebaseFunctionError(error)
        } catch {
            throw AIError.networkError(underlying: error)
        }
    }

    func completeStructured<T: Decodable>(
        prompt: String,
        schema: T.Type,
        options: AICompletionOptions? = nil
    ) async throws -> T {
        let opts = options ?? .default

        let data: [String: Any] = [
            "prompt": prompt,
            "provider": configuration.selectedProvider.rawValue.lowercased(),
            "model": opts.model ?? configuration.model(for: .parsing),
            "temperature": opts.temperature ?? 0.7,
            "maxTokens": opts.maxTokens ?? 1024,
            "systemMessage": opts.systemMessage as Any,
        ]

        do {
            let result = try await functions.httpsCallable("aiCompleteStructured").call(data)

            guard let responseData = result.data as? [String: Any],
                  let content = responseData["content"] as? String else {
                throw AIError.invalidResponse(reason: "Invalid structured response from gateway")
            }

            // Parse JSON response
            guard let jsonData = content.data(using: .utf8) else {
                throw AIError.invalidResponse(reason: "Could not convert response to data")
            }

            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch let error as DecodingError {
            Log.error("Failed to decode JSON from gateway response", category: .network, error: error)
            throw AIError.jsonDecodingFailed(underlying: error)
        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            throw handleFirebaseFunctionError(error)
        } catch {
            throw AIError.networkError(underlying: error)
        }
    }

    func estimateCost(inputTokens: Int, outputTokens: Int) -> Decimal {
        // Use current provider's pricing
        if configuration.selectedProvider == .anthropic {
            let inputCost = Decimal(inputTokens) / 1_000_000 * 0.25
            let outputCost = Decimal(outputTokens) / 1_000_000 * 1.25
            return inputCost + outputCost
        } else {
            let inputCost = Decimal(inputTokens) / 1_000_000 * 0.15
            let outputCost = Decimal(outputTokens) / 1_000_000 * 0.6
            return inputCost + outputCost
        }
    }

    // MARK: - Vision API Methods

    func completeWithVisionStructured<T: Decodable>(
        image: UIImage,
        prompt: String,
        schema: T.Type,
        options: AICompletionOptions? = nil,
        useCase: ImageUseCase = .display
    ) async throws -> T {
        // Compress image for network transfer
        guard let imageData = await compressImage(image, maxBytes: 2_000_000) else {
            throw AIError.invalidRequest(reason: "Failed to compress image")
        }

        let base64Image = imageData.base64EncodedString()
        let opts = options ?? .default

        let data: [String: Any] = [
            "imageBase64": base64Image,
            "prompt": prompt,
            "provider": configuration.selectedProvider.rawValue.lowercased(),
            "model": opts.model ?? configuration.model(for: .vision),
            "temperature": opts.temperature ?? 0.7,
            "maxTokens": opts.maxTokens ?? 1500,
            "systemMessage": opts.systemMessage as Any,
            "structured": true,
        ]

        Log.info("Requesting vision AI through gateway", category: .ai, metadata: [
            "imageSizeKB": imageData.count / 1024,
            "provider": configuration.selectedProvider.rawValue
        ])

        do {
            let result = try await functions.httpsCallable("aiCompleteWithVision").call(data)

            guard let responseData = result.data as? [String: Any],
                  let content = responseData["content"] as? String else {
                throw AIError.invalidResponse(reason: "Invalid vision response from gateway")
            }

            // Parse JSON response
            guard let jsonData = content.data(using: .utf8) else {
                throw AIError.invalidResponse(reason: "Could not convert response to data")
            }

            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch let error as DecodingError {
            Log.error("Failed to decode JSON from gateway vision response", category: .network, error: error)
            throw AIError.jsonDecodingFailed(underlying: error)
        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            throw handleFirebaseFunctionError(error)
        } catch {
            throw AIError.networkError(underlying: error)
        }
    }

    // MARK: - Helper Methods

    private func parseAIResponse(_ data: [String: Any]) throws -> AICompletionResponse {
        guard let content = data["content"] as? String,
              let model = data["model"] as? String,
              let usageData = data["usage"] as? [String: Any],
              let inputTokens = usageData["input_tokens"] as? Int,
              let outputTokens = usageData["output_tokens"] as? Int,
              let totalTokens = usageData["total_tokens"] as? Int else {
            throw AIError.invalidResponse(reason: "Missing required fields in gateway response")
        }

        let usage = TokenUsage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens
        )

        // Track usage locally
        usageTracker.trackUsage(tokens: usage, provider: configuration.selectedProvider)

        return AICompletionResponse(
            content: content,
            model: model,
            usage: usage,
            metadata: data["metadata"] as? [String: Any]
        )
    }

    private func handleFirebaseFunctionError(_ error: NSError) -> AIError {
        let code = FunctionsErrorCode(rawValue: error.code)

        switch code {
        case .unauthenticated:
            return .unauthorized
        case .resourceExhausted:
            return .quotaExceeded(
                provider: providerName,
                limit: 100,
                resetDate: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            )
        case .invalidArgument:
            return .invalidRequest(reason: error.localizedDescription)
        case .internal, .unknown:
            return .apiError(statusCode: 500, message: error.localizedDescription)
        default:
            return .networkError(underlying: error)
        }
    }

    private func compressImage(_ image: UIImage, maxBytes: Int) async -> Data? {
        var workingImage = image

        // Resize first if image is too large
        let maxDimension: CGFloat = 2048
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)

        if scale < 1.0 {
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            let renderer = UIGraphicsImageRenderer(size: newSize)
            workingImage = renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        // Iteratively reduce quality until under max size
        var compression: CGFloat = 0.9
        var imageData = workingImage.jpegData(compressionQuality: compression)

        while let data = imageData, data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            imageData = workingImage.jpegData(compressionQuality: compression)
        }

        return imageData
    }
}
