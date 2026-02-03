//
//  FirebaseImageGenerationService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation
import FirebaseFunctions

/// Service for generating images via Firebase Cloud Functions
@MainActor
class FirebaseImageGenerationService {
    private let functions: Functions

    init(functions: Functions = Functions.functions()) {
        self.functions = functions
    }

    /// Generate an image using DALL-E via Firebase Function
    func generateImage(prompt: String, size: String = "1792x1024", quality: String = "standard") async throws -> URL {
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

            Log.info("Firebase image generation successful", category: .general, metadata: [
                "url": imageUrlString
            ])

            return imageUrl

        } catch let error as NSError {
            Log.error("Firebase image generation failed", category: .general, error: error)

            // Parse Firebase Functions error
            if let code = FunctionsErrorCode(rawValue: error.code) {
                switch code {
                case .unauthenticated:
                    throw ImageGenerationError.apiError(statusCode: 401, message: "User not authenticated")
                case .resourceExhausted:
                    throw ImageGenerationError.apiError(statusCode: 429, message: "Rate limit exceeded")
                case .invalidArgument:
                    throw ImageGenerationError.apiError(statusCode: 400, message: error.localizedDescription)
                default:
                    throw ImageGenerationError.apiError(statusCode: 500, message: error.localizedDescription)
                }
            }

            throw ImageGenerationError.apiError(statusCode: 500, message: error.localizedDescription)
        }
    }
}
