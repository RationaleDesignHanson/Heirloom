//
//  PDFImageExtractor.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-16.
//

import PDFKit
import Vision
import UIKit

/// Extracts food images from PDF pages for recipe thumbnails
/// Uses Vision framework to detect and score image regions
@MainActor
class PDFImageExtractor {

    private let imageStorage: ImageStorageService

    init(imageStorage: ImageStorageService) {
        self.imageStorage = imageStorage
    }

    // MARK: - Public API

    /// Extract the most prominent food image from a PDF page
    /// - Parameters:
    ///   - page: PDFPage to extract from
    ///   - recipe: Recipe to save image for
    /// - Returns: Success/failure status
    func extractAndSaveImage(from page: PDFPage, for recipe: Recipe) async throws -> Bool {
        Log.info("Starting image extraction from PDF page", category: .import, metadata: ["recipeId": recipe.id.uuidString])

        // 1. Render page to high-res image
        guard let pageImage = renderPage(page, scale: 2.0) else {
            Log.warning("Failed to render PDF page", category: .import)
            return false
        }

        // 2-6. Use common extraction logic
        return await extractAndSaveImage(from: pageImage, for: recipe)
    }

    /// Extract the most prominent food image from a rendered page image
    /// - Parameters:
    ///   - pageImage: UIImage of the page (from PDF render or imageData)
    ///   - recipe: Recipe to save image for
    /// - Returns: Success/failure status
    func extractAndSaveImage(from pageImage: UIImage, for recipe: Recipe) async -> Bool {
        Log.info("Starting image extraction from page image", category: .import, metadata: ["recipeId": recipe.id.uuidString])

        // 1. Detect image regions using Vision
        guard let imageRegions = try? await detectImageRegions(in: pageImage) else {
            Log.info("No image regions detected in page", category: .import)
            return false
        }

        guard !imageRegions.isEmpty else {
            Log.info("No suitable image regions found", category: .import)
            return false
        }

        // 2. Find largest/most prominent image (likely the food photo)
        guard let foodImageRect = selectBestFoodImage(from: imageRegions, pageImage: pageImage) else {
            Log.info("No suitable food image candidate found", category: .import)
            return false
        }

        // 3. Crop to image region
        guard let croppedImage = cropImage(pageImage, to: foodImageRect) else {
            Log.warning("Failed to crop image region", category: .import)
            return false
        }

        // 4. Save via ImageStorageService (handles compression automatically)
        do {
            let fileName = try await imageStorage.saveImage(croppedImage, recipeId: recipe.id)
            recipe.imageFileName = fileName
            Log.info("Saved extracted image", category: .import, metadata: ["fileName": fileName])
        } catch {
            Log.error("Failed to save extracted image", category: .import, error: error)
            return false
        }

        // 5. Generate blurhash for progressive loading
        if let blurhash = BlurHashEncoder.encode(croppedImage) {
            recipe.blurhash = blurhash
            Log.debug("Generated blurhash for extracted image", category: .import)
        }

        return true
    }

    // MARK: - PDF Rendering

    /// Render PDF page to UIImage at specified scale
    private func renderPage(_ page: PDFPage, scale: CGFloat) -> UIImage? {
        let pageBounds = page.bounds(for: .mediaBox)
        let scaledSize = CGSize(
            width: pageBounds.width * scale,
            height: pageBounds.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { ctx in
            // Fill with white background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: scaledSize))

            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: scaledSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }

    // MARK: - Vision Image Detection

    /// Use Vision framework to detect image regions in page
    private func detectImageRegions(in image: UIImage) async throws -> [VNRectangleObservation]? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3  // Exclude very thin regions (likely text lines)
        request.maximumAspectRatio = 3.0  // Exclude very wide regions (likely headers)
        request.minimumSize = 0.15        // Must be at least 15% of page area
        request.minimumConfidence = 0.5   // Medium confidence threshold

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return request.results
    }

    // MARK: - Image Selection

    /// Select best food image candidate (largest, most centered, good aspect ratio)
    private func selectBestFoodImage(
        from regions: [VNRectangleObservation],
        pageImage: UIImage
    ) -> CGRect? {
        guard !regions.isEmpty else { return nil }

        // Score each region based on:
        // - Size (larger = better)
        // - Position (upper half of page = better for recipes)
        // - Aspect ratio (close to 4:3 or 16:9 = better)

        let scored = regions.compactMap { region -> (rect: CGRect, score: Double)? in
            let normalizedRect = region.boundingBox
            let area = normalizedRect.width * normalizedRect.height

            // Minimum area threshold (15% of page)
            guard area >= 0.15 else { return nil }

            let centerY = normalizedRect.midY
            let aspectRatio = normalizedRect.width / normalizedRect.height

            // Prefer images in upper 60% of page (where food photos typically are)
            let positionScore = centerY > 0.4 ? 1.0 : 0.5

            // Prefer landscape or square images (typical for food photography)
            // Ideal range: 0.75 (3:4) to 1.5 (3:2)
            let aspectScore = (0.75...1.5).contains(aspectRatio) ? 1.0 : 0.7

            // Size is the primary factor
            let totalScore = area * positionScore * aspectScore

            // Convert normalized coordinates to image coordinates
            let imageSize = pageImage.size
            let imageRect = CGRect(
                x: normalizedRect.origin.x * imageSize.width,
                y: (1 - normalizedRect.origin.y - normalizedRect.height) * imageSize.height,
                width: normalizedRect.width * imageSize.width,
                height: normalizedRect.height * imageSize.height
            )

            return (imageRect, totalScore)
        }

        guard let best = scored.max(by: { $0.score < $1.score }) else {
            return nil
        }

        Log.debug("Selected best image region", category: .import, metadata: [
            "score": best.score,
            "area": best.rect.width * best.rect.height / (pageImage.size.width * pageImage.size.height)
        ])

        return best.rect
    }

    // MARK: - Image Cropping

    /// Crop image to specified rectangle
    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage?.cropping(to: rect) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
