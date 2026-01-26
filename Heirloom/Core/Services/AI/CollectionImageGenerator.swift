import Foundation
import UIKit

/// Generates themed background images for collections using OpenAI DALL-E 3
actor CollectionImageGenerator {
    private let aiConfig: AIConfiguration
    private let imageStorage: ImageStorageService

    init(aiConfig: AIConfiguration, imageStorage: ImageStorageService) {
        self.aiConfig = aiConfig
        self.imageStorage = imageStorage
    }

    /// Generate background image for collection
    func generateBackground(for collection: RecipeCollection) async throws -> String {
        // Check for API key
        guard let apiKey = await aiConfig.apiKey(for: .openai) else {
            throw ImageGenerationError.noAPIKey
        }

        // Build prompt
        let prompt = buildPrompt(for: collection)
        Log.info("Generating collection image", category: .general, metadata: ["prompt": prompt])

        // Call DALL-E API
        let imageURL = try await generateWithDALLE(prompt: prompt, apiKey: apiKey)

        // Download and save locally
        let localPath = try await downloadAndSave(imageURL: imageURL, collectionId: collection.id)

        // Update collection metadata
        await MainActor.run {
            collection.generatedBackgroundImagePath = localPath
            collection.lastImageGenerationDate = Date()
            collection.lastRecipeCountAtGeneration = collection.recipes?.count ?? 0
        }

        return localPath
    }

    private func buildPrompt(for collection: RecipeCollection) -> String {
        let recipes = collection.recipes ?? []
        let recipeNames = recipes.prefix(5).map { $0.title }.joined(separator: ", ")

        var prompt = "A warm, nostalgic kitchen scene representing a family cookbook collection"

        if !recipeNames.isEmpty {
            prompt += " featuring dishes like \(recipeNames)"
        }

        if let description = collection.desc, !description.isEmpty {
            prompt += ". Theme: \(description)"
        }

        prompt += ". Style: soft natural lighting, cozy atmosphere, watercolor illustration, warm tones, no text or words"

        return prompt
    }

    private func generateWithDALLE(prompt: String, apiKey: String) async throws -> URL {
        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // DALL-E can take a while

        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1792x1024", // Landscape for collection cards
            "quality": "standard"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                Log.error("DALL-E API error", category: .general, metadata: ["error": message])
                throw ImageGenerationError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
            throw ImageGenerationError.apiError(statusCode: httpResponse.statusCode, message: nil)
        }

        let dalleResponse = try JSONDecoder().decode(DALLEResponse.self, from: data)

        guard let urlString = dalleResponse.data.first?.url,
              let imageURL = URL(string: urlString) else {
            throw ImageGenerationError.noImageReturned
        }

        return imageURL
    }

    private func downloadAndSave(imageURL: URL, collectionId: UUID) async throws -> String {
        // Download image
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        guard let uiImage = UIImage(data: data) else {
            throw ImageGenerationError.invalidImageData
        }

        // Save with special naming for collection backgrounds
        let fileName = "collection-bg-ai-\(collectionId.uuidString).jpg"
        let savedPath = try await imageStorage.saveImage(uiImage, fileName: fileName)

        Log.info("Saved AI-generated collection image", category: .general, metadata: [
            "fileName": fileName,
            "collectionId": collectionId.uuidString
        ])

        return savedPath
    }
}

// MARK: - Response Models
struct DALLEResponse: Codable {
    let data: [ImageData]

    struct ImageData: Codable {
        let url: String?
        let b64_json: String?
    }
}

enum ImageGenerationError: Error, LocalizedError {
    case noAPIKey
    case noImageReturned
    case invalidImageData
    case invalidResponse
    case apiError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured. Please add your API key in Settings."
        case .noImageReturned:
            return "No image was returned from the API"
        case .invalidImageData:
            return "Could not decode image data"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let code, let message):
            if let message = message {
                return "API error (\(code)): \(message)"
            }
            return "API error with status code \(code)"
        }
    }
}
