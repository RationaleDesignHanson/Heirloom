//
//  RecipeImageCropper.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation
import PDFKit
import Vision
import UIKit

/// Extracts food images from text-rich PDFs for use with CookbookBatchAnalyzer
/// Works with page groups to find the best food photo for each recipe
///
/// # Architecture
///
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │              Image Extraction for Text Pipeline              │
/// └─────────────────────────────────────────────────────────────┘
///
///  CookbookBatchAnalyzer.analyzeAndExtract()
///     │
///     ▼
///  [RecipeBoundary] { title, startPage, endPage }
///     │
///     │ For each recipe boundary:
///     ▼
///  RecipeImageCropper.extractImagesForRecipes()
///     │
///     ├───► Load PDF pages in range
///     │
///     ├───► Render each page to UIImage
///     │
///     ├───► Vision: Detect image regions
///     │
///     ├───► Score & select best food image
///     │          - Size (larger = better)
///     │          - Position (upper half = better)
///     │          - Aspect ratio (landscape/square = better)
///     │
///     └───► Return: [RecipeImageResult]
///                    - recipeTitle: String
///                    - pageNumber: Int (where image was found)
///                    - croppedImage: UIImage?
///                    - pageImages: [UIImage] (full page renders)
/// ```
///
/// # Usage Example
///
/// ```swift
/// let cropper = RecipeImageCropper()
///
/// // After batch text analysis
/// let boundaries = try await batchAnalyzer.detectRecipeBoundaries(from: extraction)
///
/// // Extract images for each recipe
/// let imageResults = try await cropper.extractImagesForRecipes(
///     boundaries: boundaries,
///     pdfURL: pdfURL
/// )
///
/// for result in imageResults {
///     print("\(result.recipeTitle): \(result.croppedImage != nil ? "has image" : "no image")")
/// }
/// ```
@MainActor
final class RecipeImageCropper {

    // MARK: - Types

    struct RecipeImageResult {
        let recipeTitle: String
        let startPage: Int
        let endPage: Int
        let pageNumber: Int?        // Page where food image was found
        let croppedImage: UIImage?  // Best food image cropped from page
        let pageImages: [UIImage]   // Full page renders for this recipe

        var hasImage: Bool { croppedImage != nil }
        var isMultiPage: Bool { endPage > startPage }
    }

    // MARK: - Configuration

    private let renderScale: CGFloat = 2.0
    private let minimumImageAreaRatio: Float = 0.15  // Minimum 15% of page

    // MARK: - Public API

    /// Extract food images for each recipe boundary
    /// - Parameters:
    ///   - boundaries: Recipe boundaries from CookbookBatchAnalyzer
    ///   - pdfURL: URL to the PDF file
    /// - Returns: Array of RecipeImageResult with extracted images
    func extractImagesForRecipes(
        boundaries: [CookbookBatchAnalyzer.RecipeBoundary],
        pdfURL: URL
    ) async throws -> [RecipeImageResult] {
        // Check if file exists before trying to open
        let fileExists = FileManager.default.fileExists(atPath: pdfURL.path)
        Log.info("RecipeImageCropper checking PDF", category: .import, metadata: [
            "file": pdfURL.lastPathComponent,
            "path": pdfURL.path,
            "exists": fileExists
        ])

        guard fileExists else {
            Log.error("PDF file not found for image extraction", category: .import, metadata: [
                "file": pdfURL.lastPathComponent,
                "path": pdfURL.path
            ])
            throw RecipeImageError.cannotOpenPDF(url: pdfURL)
        }

        // Access security-scoped resource (may not be needed for temp copies)
        let needsSecurityScope = pdfURL.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                pdfURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: pdfURL) else {
            Log.error("PDFDocument failed to open existing file", category: .import, metadata: [
                "file": pdfURL.lastPathComponent,
                "path": pdfURL.path
            ])
            throw RecipeImageError.cannotOpenPDF(url: pdfURL)
        }

        Log.info("Starting image extraction for recipes", category: .import, metadata: [
            "recipe_count": boundaries.count,
            "pdf_pages": document.pageCount
        ])

        var results: [RecipeImageResult] = []

        for boundary in boundaries {
            let result = await extractImageForRecipe(
                boundary: boundary,
                document: document
            )
            results.append(result)
        }

        let imageCount = results.filter { $0.hasImage }.count
        Log.info("Image extraction complete", category: .import, metadata: [
            "recipes_with_images": imageCount,
            "total_recipes": results.count
        ])

        return results
    }

    /// Extract food image for a single recipe boundary
    /// - Parameters:
    ///   - boundary: Recipe boundary
    ///   - document: Open PDF document
    /// - Returns: RecipeImageResult with extracted image (if found)
    func extractImageForRecipe(
        boundary: CookbookBatchAnalyzer.RecipeBoundary,
        document: PDFDocument
    ) async -> RecipeImageResult {
        var pageImages: [UIImage] = []
        var bestImage: UIImage?
        var bestImagePage: Int?
        var bestScore: Double = 0

        // Render and analyze each page in the recipe's range
        for pageNum in boundary.startPage...boundary.endPage {
            let pageIndex = pageNum - 1  // Convert to 0-indexed

            guard pageIndex >= 0, pageIndex < document.pageCount,
                  let page = document.page(at: pageIndex) else {
                continue
            }

            // Render page
            guard let pageImage = renderPage(page) else {
                continue
            }
            pageImages.append(pageImage)

            // Detect and score food images on this page
            if let (image, score) = await findBestFoodImage(in: pageImage) {
                if score > bestScore {
                    bestImage = image
                    bestScore = score
                    bestImagePage = pageNum
                }
            }
        }

        return RecipeImageResult(
            recipeTitle: boundary.title,
            startPage: boundary.startPage,
            endPage: boundary.endPage,
            pageNumber: bestImagePage,
            croppedImage: bestImage,
            pageImages: pageImages
        )
    }

    /// Extract image for a recipe from pre-rendered page images
    /// - Parameters:
    ///   - pageImages: Array of already-rendered page images
    ///   - recipeTitle: Title of the recipe
    ///   - startPage: Starting page number
    /// - Returns: Best food image found (if any)
    func extractImageFromPageImages(
        pageImages: [UIImage],
        recipeTitle: String,
        startPage: Int
    ) async -> (image: UIImage?, pageNumber: Int?) {
        var bestImage: UIImage?
        var bestImagePage: Int?
        var bestScore: Double = 0

        for (index, pageImage) in pageImages.enumerated() {
            if let (image, score) = await findBestFoodImage(in: pageImage) {
                if score > bestScore {
                    bestImage = image
                    bestScore = score
                    bestImagePage = startPage + index
                }
            }
        }

        return (bestImage, bestImagePage)
    }

    // MARK: - Private Helpers

    /// Render PDF page to UIImage
    private func renderPage(_ page: PDFPage) -> UIImage? {
        let pageBounds = page.bounds(for: .mediaBox)
        let scaledSize = CGSize(
            width: pageBounds.width * renderScale,
            height: pageBounds.height * renderScale
        )

        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: scaledSize))

            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: scaledSize.height)
            ctx.cgContext.scaleBy(x: renderScale, y: -renderScale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }

    /// Find best food image in a page using Vision
    private func findBestFoodImage(in pageImage: UIImage) async -> (image: UIImage, score: Double)? {
        guard let cgImage = pageImage.cgImage else { return nil }

        // Detect rectangles (potential image regions)
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 3.0
        request.minimumSize = minimumImageAreaRatio
        request.minimumConfidence = 0.5

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            Log.debug("Vision rectangle detection failed: \(error.localizedDescription)", category: .import)
            return nil
        }

        guard let results = request.results, !results.isEmpty else {
            return nil
        }

        // Score and select best region
        var bestResult: (rect: CGRect, score: Double)?

        for region in results {
            let normalizedRect = region.boundingBox
            let area = normalizedRect.width * normalizedRect.height

            // Must meet minimum size
            guard area >= Double(minimumImageAreaRatio) else { continue }

            let centerY = normalizedRect.midY
            let aspectRatio = normalizedRect.width / normalizedRect.height

            // Score components:
            // - Size: larger is better
            // - Position: upper half (food photos usually at top)
            // - Aspect: landscape/square preferred for food photography
            let positionScore = centerY > 0.4 ? 1.0 : 0.5
            let aspectScore = (0.75...1.5).contains(aspectRatio) ? 1.0 : 0.7
            let totalScore = area * positionScore * aspectScore

            if bestResult == nil || totalScore > bestResult!.score {
                // Convert to image coordinates
                let imageRect = CGRect(
                    x: normalizedRect.origin.x * pageImage.size.width,
                    y: (1 - normalizedRect.origin.y - normalizedRect.height) * pageImage.size.height,
                    width: normalizedRect.width * pageImage.size.width,
                    height: normalizedRect.height * pageImage.size.height
                )
                bestResult = (imageRect, totalScore)
            }
        }

        guard let best = bestResult,
              let croppedCGImage = cgImage.cropping(to: best.rect) else {
            return nil
        }

        let croppedImage = UIImage(
            cgImage: croppedCGImage,
            scale: pageImage.scale,
            orientation: pageImage.imageOrientation
        )

        return (croppedImage, best.score)
    }
}

// MARK: - Errors

enum RecipeImageError: LocalizedError {
    case cannotOpenPDF(url: URL)

    var errorDescription: String? {
        switch self {
        case .cannotOpenPDF(let url):
            return "Cannot open PDF: \(url.lastPathComponent)"
        }
    }
}
