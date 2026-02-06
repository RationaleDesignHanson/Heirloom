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
        try await generateBackground(for: collection, recipes: nil)
    }

    /// Generate background image for collection with explicit recipes
    /// Use this overload when recipes might not be linked to the collection yet (e.g., during import)
    func generateBackground(for collection: RecipeCollection, recipes: [Recipe]?) async throws -> String {
        // Build prompt - prefer passed recipes, fall back to collection relationship
        let recipesToUse = recipes ?? collection.recipes ?? []
        let prompt = buildPrompt(for: collection, recipes: recipesToUse)
        Log.info("Generating collection image", category: .general, metadata: [
            "prompt": prompt,
            "recipeCount": recipesToUse.count
        ])

        // Call DALL-E via Firebase Function
        let imageURL = try await firebaseService.generateImage(prompt: prompt)

        // Download and save locally
        let localPath = try await downloadAndSave(imageURL: imageURL, collectionId: collection.id)

        // Return path - caller will update collection metadata
        return localPath
    }

    /// Build an optimized prompt for Flux/DALL-E collection image generation
    /// Structure: [scene description], [food elements], [style modifiers]
    private func buildPrompt(for collection: RecipeCollection, recipes: [Recipe]) -> String {
        let selectedStyle = styleConfig.selectedStyle

        // Build scene description based on collection type
        var sceneDescription: String

        switch collection.type {
        case .videoImports:
            sceneDescription = "modern kitchen scene, content creator filming cooking video"
            if let recipe = recipes.first?.title {
                sceneDescription += ", preparing \(recipe)"
            }

        case .cookbook:
            // Synthesize recipe content for contextually relevant image
            sceneDescription = buildCookbookPrompt(recipes: recipes, collectionName: collection.name)

        case .photoImports:
            sceneDescription = "beautiful overhead flat lay food photography, artfully arranged homemade dishes"
            if let recipe = recipes.first?.title {
                sceneDescription += ", featuring \(recipe)"
            }

        case .webImports:
            sceneDescription = "modern bright kitchen, tablet displaying recipe, fresh ingredients on counter"
            if let recipe = recipes.first?.title {
                sceneDescription += ", making \(recipe)"
            }

        case .communityRecipes:
            sceneDescription = "warm inviting community kitchen, diverse group cooking together, shared meal preparation"
            if let recipe = recipes.first?.title {
                sceneDescription += ", preparing \(recipe)"
            }

        default:
            sceneDescription = "cozy family kitchen scene, heirloom cookbook collection, warm nostalgic atmosphere"
            if let recipe = recipes.first?.title {
                sceneDescription += ", featuring \(recipe)"
            }
        }

        // Add custom description if provided (skip for cookbook since we already synthesize)
        if collection.type != .cookbook, let description = collection.desc, !description.isEmpty {
            sceneDescription += ", \(description)"
        }

        // Combine with style modifier (which includes quality keywords)
        let prompt = "\(sceneDescription), \(selectedStyle.promptModifier)"

        return prompt
    }

    /// Build a contextually relevant prompt for cookbook collections by analyzing recipe content
    private func buildCookbookPrompt(recipes: [Recipe], collectionName: String) -> String {
        guard !recipes.isEmpty else {
            return "beautiful food photography, artfully arranged dishes, warm kitchen lighting"
        }

        // Analyze recipe titles for common themes
        let titles = recipes.map { $0.title.lowercased() }

        // Detect cuisine type
        let cuisineKeywords: [(keywords: [String], cuisine: String, scene: String)] = [
            (["italian", "pasta", "risotto", "pizza", "lasagna", "gnocchi", "tiramisu", "pesto"], "Italian", "rustic Italian trattoria, fresh pasta, olive oil, tomatoes, basil"),
            (["mexican", "taco", "burrito", "enchilada", "salsa", "guacamole", "tamale", "chile"], "Mexican", "vibrant Mexican kitchen, colorful peppers, cilantro, lime, tortillas"),
            (["asian", "chinese", "japanese", "thai", "vietnamese", "korean", "sushi", "ramen", "curry", "stir fry", "wok"], "Asian", "elegant Asian cuisine, steaming bowls, fresh vegetables, delicate plating"),
            (["indian", "masala", "tikka", "biryani", "naan", "samosa", "dal", "paneer"], "Indian", "warm Indian kitchen, aromatic spices, colorful dishes, brass cookware"),
            (["french", "croissant", "baguette", "soufflé", "crêpe", "quiche", "ratatouille"], "French", "elegant French cuisine, refined plating, copper pans, herbs de provence"),
            (["mediterranean", "greek", "hummus", "falafel", "kebab", "pita"], "Mediterranean", "sunny Mediterranean spread, olive oil, feta, fresh herbs, grilled vegetables"),
            (["southern", "bbq", "fried chicken", "biscuit", "cornbread", "gumbo", "jambalaya", "cajun", "creole"], "Southern", "warm Southern kitchen, cast iron skillet, comfort food, family gathering"),
            (["baking", "cake", "cookie", "pie", "bread", "muffin", "pastry", "dessert", "cupcake", "brownie"], "Baking", "charming bakery scene, fresh baked goods, flour dusted counter, golden pastries"),
            (["breakfast", "pancake", "waffle", "egg", "bacon", "omelette", "brunch"], "Breakfast", "sunny breakfast scene, golden pancakes, fresh coffee, morning light through window"),
            (["soup", "stew", "chowder", "bisque", "broth"], "Soups", "cozy kitchen scene, steaming bowls, crusty bread, hearty comfort food"),
            (["salad", "fresh", "healthy", "green", "quinoa", "bowl"], "Healthy", "bright fresh food photography, colorful vegetables, clean eating, natural light"),
            (["seafood", "fish", "shrimp", "salmon", "lobster", "crab", "scallop"], "Seafood", "coastal kitchen, fresh catch, lemon wedges, seaside atmosphere"),
            (["grilling", "grill", "bbq", "steak", "burger", "ribs", "smoke"], "Grilling", "outdoor grilling scene, sizzling meat, charcoal glow, summer cookout"),
        ]

        // Find matching cuisine
        var bestMatch: (cuisine: String, scene: String)?
        var bestScore = 0

        for (keywords, cuisine, scene) in cuisineKeywords {
            let score = titles.reduce(0) { count, title in
                count + keywords.filter { title.contains($0) }.count
            }
            if score > bestScore {
                bestScore = score
                bestMatch = (cuisine, scene)
            }
        }

        // Build the prompt
        var prompt: String

        if let match = bestMatch, bestScore >= 2 {
            // Strong cuisine match - use themed scene
            prompt = match.scene
        } else {
            // No strong match - use collection name and sample recipes for context
            let sampleRecipes = Array(recipes.prefix(3)).map { $0.title }
            let recipeList = sampleRecipes.joined(separator: ", ")

            // Check collection name for cuisine hints
            let collectionNameLower = collectionName.lowercased()
            for (keywords, _, scene) in cuisineKeywords {
                if keywords.contains(where: { collectionNameLower.contains($0) }) {
                    prompt = scene
                    if !recipeList.isEmpty {
                        prompt += ", featuring \(recipeList)"
                    }
                    return prompt
                }
            }

            // Generic but contextual prompt based on actual recipes
            prompt = "beautiful artfully arranged food photography"
            if !recipeList.isEmpty {
                prompt += ", featuring \(recipeList)"
            }
            prompt += ", warm inviting kitchen atmosphere"
        }

        // Add a sample of recipe names for additional context (up to 2)
        let sampleTitles = Array(recipes.prefix(2)).map { $0.title }
        if !sampleTitles.isEmpty && bestScore < 4 {
            prompt += ", dishes like \(sampleTitles.joined(separator: " and "))"
        }

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
