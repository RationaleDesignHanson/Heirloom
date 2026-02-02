import Foundation
import UIKit

/// Detects multiple recipes in images using Claude vision API
/// Returns bounding boxes for each detected recipe
/// Ported from rationale-public web demo's detect-recipes API
@MainActor
class AIRecipeDetector {

    private let aiConfig: AIConfiguration
    private let aiService: AnthropicAIService

    init(aiConfig: AIConfiguration, aiService: AnthropicAIService) {
        self.aiConfig = aiConfig
        self.aiService = aiService
    }

    // MARK: - Detection

    /// Detect recipes in an image with bounding boxes
    func detectRecipes(from image: UIImage) async throws -> [DetectedRecipe] {
        let prompt = """
        Analyze this image and detect all distinct recipes present. For each recipe you find, provide:
        1. A descriptive title
        2. A bounding box (x, y, width, height as percentages 0-100 of image dimensions)
        3. A confidence level (high/medium/low)

        IMPORTANT: Only detect SEPARATE recipes that result in distinct final dishes.
        - DO NOT split a single recipe into multiple parts (e.g., "Crust" and "Filling" are ONE recipe, not two)
        - A recipe with subsections like "For the dough" and "For the topping" is still ONE recipe
        - Only return multiple recipes if there are truly distinct dishes (e.g., "Chocolate Chip Cookies" AND "Sugar Cookies")

        Common mistakes to avoid:
        - Splitting recipes by ingredients section and instructions section
        - Treating component recipes (dough, filling, frosting) as separate when they make one dish
        - Detecting section headers as separate recipes

        Return ONLY valid JSON in this exact format:
        {
          "recipes": [
            {
              "id": "1",
              "title": "Recipe Name",
              "boundingBox": {
                "x": 10,
                "y": 20,
                "width": 40,
                "height": 60
              },
              "confidence": "high"
            }
          ]
        }

        The bounding box should encompass the ENTIRE recipe including all sub-sections.
        Coordinates are percentages (0-100) of the image width/height.
        """

        let options = AICompletionOptions(
            model: aiConfig.model(for: .pdfVision),
            temperature: 0.3, // Lower temperature for more consistent detection
            maxTokens: 1000
        )

        do {
            let response: DetectionResponse = try await aiService.completeWithVisionStructured(
                image: image,
                prompt: prompt,
                schema: DetectionResponse.self,
                options: options
            )

            return response.recipes
        } catch {
            Log.warning("Recipe detection failed, assuming single recipe", category: .ocr, metadata: ["error": error.localizedDescription])
            // If detection fails, assume single recipe covering whole image
            return [DetectedRecipe.fullImage()]
        }
    }
}

// MARK: - Detection Models

struct DetectedRecipe: Codable {
    let id: String
    let title: String
    let boundingBox: BoundingBox
    let confidence: ConfidenceLevel

    /// Create a detected recipe covering the full image (fallback)
    static func fullImage() -> DetectedRecipe {
        return DetectedRecipe(
            id: "1",
            title: "Recipe",
            boundingBox: BoundingBox(x: 0, y: 0, width: 100, height: 100),
            confidence: .medium
        )
    }
}

struct BoundingBox: Codable {
    let x: Double      // % of image width (0-100)
    let y: Double      // % of image height (0-100)
    let width: Double  // % of image width (0-100)
    let height: Double // % of image height (0-100)

    /// Check if this bounding box covers the full image
    var isFullImage: Bool {
        return x <= 5 && y <= 5 && width >= 90 && height >= 90
    }

    /// Convert percentage coordinates to pixel coordinates
    func toPixelCoordinates(imageWidth: CGFloat, imageHeight: CGFloat) -> CGRect {
        let pixelX = (x / 100) * imageWidth
        let pixelY = (y / 100) * imageHeight
        let pixelWidth = (width / 100) * imageWidth
        let pixelHeight = (height / 100) * imageHeight

        return CGRect(x: pixelX, y: pixelY, width: pixelWidth, height: pixelHeight)
    }
}

enum ConfidenceLevel: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var score: Double {
        switch self {
        case .high: return 0.9
        case .medium: return 0.7
        case .low: return 0.5
        }
    }

    var displayText: String {
        switch self {
        case .high: return "High Confidence"
        case .medium: return "Medium Confidence"
        case .low: return "Low Confidence"
        }
    }
}

// MARK: - Cookbook Metadata Detection

extension AIRecipeDetector {
    /// Detect cookbook name from scanned image (cover or pages with header/footer)
    /// - Parameter image: Scanned cookbook page or cover
    /// - Returns: Detected cookbook title, or nil if not found
    func detectCookbookName(from image: UIImage) async throws -> String? {
        let prompt = """
        Analyze this image to identify the cookbook title.

        Look for:
        1. **Cover page** - Large title text, author name, publisher
        2. **Page headers/footers** - Small text at top/bottom of recipe pages showing book title
        3. **Title pages** - Copyright page, table of contents with book name
        4. **Spine text** - If visible in the image

        Common patterns:
        - "The Joy of Cooking"
        - "Better Homes and Gardens New Cook Book"
        - "Mastering the Art of French Cooking"
        - Page headers like "BETTY CROCKER'S COOKBOOK"

        IMPORTANT:
        - Return ONLY the cookbook title (no author, no subtitle, no "by...")
        - If this appears to be a regular recipe page without clear cookbook branding, return null
        - Ignore recipe titles - we want the BOOK title
        - Prefer full titles over abbreviated headers

        Return ONLY valid JSON in this exact format:
        {
          "cookbookTitle": "The Actual Book Name" or null,
          "confidence": "high" or "medium" or "low",
          "source": "cover" or "header" or "footer" or "none"
        }

        Examples:
        {"cookbookTitle": "Betty Crocker's Cookbook", "confidence": "high", "source": "header"}
        {"cookbookTitle": null, "confidence": "low", "source": "none"}
        """

        let options = AICompletionOptions(
            model: aiConfig.model(for: .pdfVision),
            temperature: 0.2,  // Lower temperature for more consistent detection
            maxTokens: 500
        )

        struct CookbookDetectionResponse: Codable {
            let cookbookTitle: String?
            let confidence: String
            let source: String
        }

        let detection: CookbookDetectionResponse
        do {
            detection = try await aiService.completeWithVisionStructured(
                image: image,
                prompt: prompt,
                schema: CookbookDetectionResponse.self,
                options: options
            )
        } catch {
            Log.warning("Cookbook name detection failed", category: .import, metadata: [
                "error": error.localizedDescription
            ])
            return nil
        }

        // Only return high/medium confidence detections
        guard detection.confidence == "high" || detection.confidence == "medium" else {
            Log.info("Low confidence cookbook detection, ignoring", category: .import, metadata: [
                "title": detection.cookbookTitle ?? "nil",
                "confidence": detection.confidence
            ])
            return nil
        }

        if let title = detection.cookbookTitle, !title.isEmpty {
            Log.info("✅ Detected cookbook title", category: .import, metadata: [
                "title": title,
                "confidence": detection.confidence,
                "source": detection.source
            ])
            return title
        }

        return nil
    }
}

// MARK: - API Response

private struct DetectionResponse: Codable {
    let recipes: [DetectedRecipe]
}
