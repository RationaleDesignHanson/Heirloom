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
        // Check for API key (with fallback to default key)
        guard let apiKey = await aiConfig.apiKeyWithFallback(for: .openai) else {
            throw ImageGenerationError.noAPIKey
        }

        // Build prompt
        let prompt = buildPrompt(for: collection)
        Log.info("Generating collection image", category: .general, metadata: ["prompt": prompt])

        // Call DALL-E API
        let imageURL = try await generateWithDALLE(prompt: prompt, apiKey: apiKey)

        // Download and save locally
        let localPath = try await downloadAndSave(imageURL: imageURL, collectionId: collection.id)

        // Return path - caller will update collection metadata
        return localPath
    }

    private func buildPrompt(for collection: RecipeCollection) -> String {
        let recipes = collection.recipes ?? []
        let recipeNames = recipes.prefix(5).map { $0.title }.joined(separator: ", ")

        // Base prompt varies by collection type
        var prompt: String

        switch collection.type {
        case .videoImports:
            // User feedback: "a creator making a recipe as the contents subject"
            prompt = "A modern kitchen scene showing a content creator filming a recipe"
            if !recipeNames.isEmpty {
                prompt += " making \(recipeNames.components(separatedBy: ", ").first ?? "a delicious dish")"
            }
            prompt += ". Style: bright natural lighting, contemporary kitchen, camera setup visible, YouTube aesthetic, warm inviting atmosphere, no text or words"

        case .cookbook:
            // Vintage cookbook aesthetic
            prompt = "A vintage cookbook open on a kitchen counter with worn pages and handwritten notes"
            if !recipeNames.isEmpty {
                prompt += " featuring recipes like \(recipeNames)"
            }
            prompt += ". Style: nostalgic, warm sepia tones, vintage cookbook photography, soft lighting, heirloom quality, no text or words"

        case .photoImports:
            // Clean food photography
            prompt = "A beautifully styled overhead flat lay of homemade food"
            if !recipeNames.isEmpty {
                prompt += " showing \(recipeNames.components(separatedBy: ", ").first ?? "delicious dishes")"
            }
            prompt += ". Style: clean food photography, natural lighting, minimalist aesthetic, Instagram-worthy, warm tones, no text or words"

        case .webImports:
            // Modern digital recipe aesthetic
            prompt = "A modern kitchen scene with a tablet showing a recipe"
            if !recipeNames.isEmpty {
                prompt += " for \(recipeNames.components(separatedBy: ", ").first ?? "cooking")"
            }
            prompt += ". Style: contemporary, bright natural lighting, clean aesthetic, tech-savvy cooking, warm atmosphere, no text or words"

        case .communityRecipes:
            // Community-shared recipes aesthetic
            prompt = "A warm, inviting community kitchen scene with diverse people sharing recipes and cooking together"
            if !recipeNames.isEmpty {
                prompt += " featuring dishes like \(recipeNames.components(separatedBy: ", ").first ?? "traditional favorites")"
            }
            prompt += ". Style: diverse community gathering, warm natural lighting, shared cooking experience, cultural exchange, cozy welcoming atmosphere, no text or words"

        default:
            // Default warm nostalgic scene for user-created and theme collections
            prompt = "A warm, nostalgic kitchen scene representing a family cookbook collection"
            if !recipeNames.isEmpty {
                prompt += " featuring dishes like \(recipeNames)"
            }
        }

        // Add custom description if provided (for all types)
        if let description = collection.desc, !description.isEmpty {
            prompt += ". Additional theme: \(description)"
        }

        // Add default style notes for non-type-specific cases
        if collection.type != .videoImports &&
           collection.type != .cookbook &&
           collection.type != .photoImports &&
           collection.type != .webImports &&
           collection.type != .communityRecipes {
            prompt += ". Style: soft natural lighting, cozy atmosphere, watercolor illustration, warm tones, no text or words"
        }

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
