import Foundation
import UIKit

/// Generates themed background images for collections using AI image generation via Firebase
/// Supports Replicate Flux (default, faster) or DALL-E 3
actor CollectionImageGenerator {
    private let imageStorage: ImageStorageService
    private let styleConfig: VisualStyleConfiguration
    private let firebaseService: FirebaseImageGenerationService
    private let session: URLSession

    init(imageStorage: ImageStorageService, styleConfig: VisualStyleConfiguration, firebaseService: FirebaseImageGenerationService) {
        self.imageStorage = imageStorage
        self.styleConfig = styleConfig
        self.firebaseService = firebaseService

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    /// Generate background image for collection
    func generateBackground(for collection: RecipeCollection) async throws -> String {
        // Build prompt
        let prompt = buildPrompt(for: collection)
        Log.info("Generating collection image", category: .general, metadata: ["prompt": prompt])

        // Call DALL-E via Firebase Function
        let imageURL = try await firebaseService.generateImage(prompt: prompt)

        // Download and save locally
        let localPath = try await downloadAndSave(imageURL: imageURL, collectionId: collection.id)

        // Return path - caller will update collection metadata
        return localPath
    }

    /// Build an optimized prompt for Flux/DALL-E collection image generation
    /// Structure: [scene description], [food elements], [style modifiers]
    private func buildPrompt(for collection: RecipeCollection) -> String {
        let recipes = collection.recipes ?? []
        let firstRecipe = recipes.first?.title
        let selectedStyle = styleConfig.selectedStyle

        // Build scene description based on collection type
        var sceneDescription: String

        switch collection.type {
        case .videoImports:
            sceneDescription = "modern kitchen scene, content creator filming cooking video"
            if let recipe = firstRecipe {
                sceneDescription += ", preparing \(recipe)"
            }

        case .cookbook:
            sceneDescription = "vintage cookbook open on rustic wooden table, worn pages with handwritten notes, kitchen background"
            if let recipe = firstRecipe {
                sceneDescription += ", recipe for \(recipe)"
            }

        case .photoImports:
            sceneDescription = "beautiful overhead flat lay food photography, artfully arranged homemade dishes"
            if let recipe = firstRecipe {
                sceneDescription += ", featuring \(recipe)"
            }

        case .webImports:
            sceneDescription = "modern bright kitchen, tablet displaying recipe, fresh ingredients on counter"
            if let recipe = firstRecipe {
                sceneDescription += ", making \(recipe)"
            }

        case .communityRecipes:
            sceneDescription = "warm inviting community kitchen, diverse group cooking together, shared meal preparation"
            if let recipe = firstRecipe {
                sceneDescription += ", preparing \(recipe)"
            }

        default:
            sceneDescription = "cozy family kitchen scene, heirloom cookbook collection, warm nostalgic atmosphere"
            if let recipe = firstRecipe {
                sceneDescription += ", featuring \(recipe)"
            }
        }

        // Add custom description if provided
        if let description = collection.desc, !description.isEmpty {
            sceneDescription += ", \(description)"
        }

        // Combine with style modifier (which includes quality keywords)
        let prompt = "\(sceneDescription), \(selectedStyle.promptModifier)"

        return prompt
    }

    private func downloadAndSave(imageURL: URL, collectionId: UUID) async throws -> String {
        // Download image
        let (data, _) = try await session.data(from: imageURL)
        guard let uiImage = UIImage(data: data) else {
            throw ImageGenerationError.invalidImageData
        }

        // Save with special naming for collection backgrounds (include timestamp to force UI refresh on regeneration)
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "collection-bg-ai-\(collectionId.uuidString)-\(timestamp).jpg"
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
