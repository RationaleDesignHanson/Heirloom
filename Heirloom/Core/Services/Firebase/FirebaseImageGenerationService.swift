//
//  FirebaseImageGenerationService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation
import FirebaseFunctions

/// Image generation provider
enum ImageGenerationProvider {
    case dalle       // OpenAI DALL-E 3 (higher quality, slower, ~$0.04/image)
    case replicate   // Replicate Flux (fast, cheaper, ~$0.003/image)
}

/// Service for generating images via Firebase Cloud Functions
@MainActor
class FirebaseImageGenerationService {
    private let functions: Functions

    /// Default provider for image generation
    /// Using Replicate for speed and cost efficiency in bulk operations
    static let defaultProvider: ImageGenerationProvider = .replicate

    init(functions: Functions = Functions.functions()) {
        self.functions = functions
    }

    /// Generate an image using the default provider (Replicate for speed)
    func generateImage(prompt: String) async throws -> URL {
        return try await generateImage(prompt: prompt, provider: Self.defaultProvider)
    }

    /// Generate an image using DALL-E via Firebase Function
    func generateImage(prompt: String, provider: ImageGenerationProvider) async throws -> URL {
        switch provider {
        case .dalle:
            return try await generateImageWithDalle(prompt: prompt)
        case .replicate:
            return try await generateImageWithReplicate(prompt: prompt)
        }
    }

    // MARK: - DALL-E (Legacy)

    /// Generate an image using DALL-E via Firebase Function
    private func generateImageWithDalle(prompt: String, size: String = "1792x1024", quality: String = "standard") async throws -> URL {
        Log.info("Calling Firebase dalleGenerateImage function", category: .general, metadata: [
            "promptLength": "\(prompt.count)",
            "size": size,
            "quality": quality
        ])

        let data: [String: Any] = [
            "prompt": prompt,
            "size": size,
            "quality": quality
        ]

        do {
            let result = try await functions.httpsCallable("dalleGenerateImage").call(data)

            guard let resultData = result.data as? [String: Any],
                  let imageUrlString = resultData["imageUrl"] as? String,
                  let imageUrl = URL(string: imageUrlString) else {
                throw ImageGenerationError.invalidResponse
            }

            Log.info("DALL-E image generation successful", category: .general, metadata: [
                "url": imageUrlString
            ])

            return imageUrl

        } catch let error as NSError {
            Log.error("DALL-E image generation failed", category: .general, error: error)
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Replicate Flux (Fast)

    /// Maximum retry attempts for rate-limited requests
    private static let maxRetryAttempts = 3

    /// Base delay for exponential backoff (in seconds)
    private static let baseRetryDelay: Double = 2.0

    /// Generate an image using Replicate Flux via Firebase Function
    /// Faster and cheaper than DALL-E, great for bulk operations
    /// Includes retry logic with exponential backoff for rate limits
    private func generateImageWithReplicate(prompt: String, aspectRatio: String = "16:9") async throws -> URL {
        var lastError: Error?

        for attempt in 0..<Self.maxRetryAttempts {
            do {
                return try await attemptReplicateGeneration(prompt: prompt, aspectRatio: aspectRatio, attempt: attempt)
            } catch let error as ImageGenerationError {
                lastError = error

                // Only retry on rate limit errors
                if case .apiError(let statusCode, _) = error, statusCode == 429 {
                    let delay = Self.baseRetryDelay * pow(2.0, Double(attempt))
                    Log.info("Rate limited, retrying after \(delay)s", category: .general, metadata: [
                        "attempt": "\(attempt + 1)",
                        "maxAttempts": "\(Self.maxRetryAttempts)"
                    ])
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                // Don't retry other errors
                throw error
            } catch {
                lastError = error
                throw error
            }
        }

        throw lastError ?? ImageGenerationError.apiError(statusCode: 429, message: "Rate limit exceeded after retries")
    }

    /// Single attempt to generate image with Replicate
    private func attemptReplicateGeneration(prompt: String, aspectRatio: String, attempt: Int) async throws -> URL {
        Log.info("Calling Firebase replicateGenerateImage function", category: .general, metadata: [
            "promptLength": "\(prompt.count)",
            "aspectRatio": aspectRatio,
            "attempt": "\(attempt + 1)"
        ])

        let data: [String: Any] = [
            "prompt": prompt,
            "aspectRatio": aspectRatio,
            "outputFormat": "jpg",
            "outputQuality": 90
        ]

        do {
            let result = try await functions.httpsCallable("replicateGenerateImage").call(data)

            guard let resultData = result.data as? [String: Any],
                  let imageUrlString = resultData["imageUrl"] as? String,
                  let imageUrl = URL(string: imageUrlString) else {
                throw ImageGenerationError.invalidResponse
            }

            Log.info("Replicate image generation successful", category: .general, metadata: [
                "url": imageUrlString
            ])

            return imageUrl

        } catch let error as NSError {
            Log.error("Replicate image generation failed", category: .general, error: error)
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Error Mapping

    private func mapFirebaseError(_ error: NSError) -> ImageGenerationError {
        if let code = FunctionsErrorCode(rawValue: error.code) {
            switch code {
            case .unauthenticated:
                return ImageGenerationError.apiError(statusCode: 401, message: "User not authenticated")
            case .resourceExhausted:
                return ImageGenerationError.apiError(statusCode: 429, message: "Rate limit exceeded")
            case .invalidArgument:
                return ImageGenerationError.apiError(statusCode: 400, message: error.localizedDescription)
            case .deadlineExceeded:
                return ImageGenerationError.apiError(statusCode: 504, message: "Image generation timed out")
            default:
                return ImageGenerationError.apiError(statusCode: 500, message: error.localizedDescription)
            }
        }
        return ImageGenerationError.apiError(statusCode: 500, message: error.localizedDescription)
    }
}
