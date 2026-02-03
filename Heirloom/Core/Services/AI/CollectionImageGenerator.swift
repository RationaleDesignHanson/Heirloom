import Foundation
import UIKit

/// Generates themed background images for collections using OpenAI DALL-E 3 via Firebase
actor CollectionImageGenerator {
    private let imageStorage: ImageStorageService
    private let styleConfig: VisualStyleConfiguration
    private let firebaseService: FirebaseImageGenerationService

    init(imageStorage: ImageStorageService, styleConfig: VisualStyleConfiguration, firebaseService: FirebaseImageGenerationService) {
        self.imageStorage = imageStorage
        self.styleConfig = styleConfig
        self.firebaseService = firebaseService
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

    private func buildPrompt(for collection: RecipeCollection) -> String {
        let recipes = collection.recipes ?? []
        let recipeNames = recipes.prefix(5).map { $0.title }.joined(separator: ", ")
        let selectedStyle = styleConfig.selectedStyle

        // Base subject varies by collection type
        var subject: String

        switch collection.type {
        case .videoImports:
            subject = "A modern kitchen scene showing a content creator filming a recipe"
            if !recipeNames.isEmpty {
                subject += " making \(recipeNames.components(separatedBy: ", ").first ?? "a delicious dish")"
            }

        case .cookbook:
            subject = "A vintage cookbook open on a kitchen counter with worn pages and handwritten notes"
            if !recipeNames.isEmpty {
                subject += " featuring recipes like \(recipeNames)"
            }

        case .photoImports:
            subject = "A beautifully styled overhead flat lay of homemade food"
            if !recipeNames.isEmpty {
                subject += " showing \(recipeNames.components(separatedBy: ", ").first ?? "delicious dishes")"
            }

        case .webImports:
            subject = "A modern kitchen scene with a tablet showing a recipe"
            if !recipeNames.isEmpty {
                subject += " for \(recipeNames.components(separatedBy: ", ").first ?? "cooking")"
            }

        case .communityRecipes:
            subject = "A warm, inviting community kitchen scene with diverse people sharing recipes and cooking together"
            if !recipeNames.isEmpty {
                subject += " featuring dishes like \(recipeNames.components(separatedBy: ", ").first ?? "traditional favorites")"
            }

        default:
            subject = "A warm, nostalgic kitchen scene representing a family cookbook collection"
            if !recipeNames.isEmpty {
                subject += " featuring dishes like \(recipeNames)"
            }
        }

        // Add custom description if provided
        if let description = collection.desc, !description.isEmpty {
            subject += ". Additional theme: \(description)"
        }

        // Combine subject with user's selected visual style
        let prompt = "\(subject). \(selectedStyle.promptModifier)"

        return prompt
    }

    private func downloadAndSave(imageURL: URL, collectionId: UUID) async throws -> String {
        // Download image
        let (data, _) = try await URLSession.shared.data(from: imageURL)
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
