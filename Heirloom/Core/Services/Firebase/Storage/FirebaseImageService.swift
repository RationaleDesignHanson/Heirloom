//
//  FirebaseImageService.swift
//  Heirloom
//
//  Phase 2 Week 3: Service Layer Refactoring
//  Firebase Storage operations for recipe images
//

import Foundation
import UIKit
import FirebaseStorage

/// Handles Firebase Storage operations for recipe images
/// Responsibilities: Upload, download, delete images with compression
@MainActor
class FirebaseImageService: FirebaseImageServiceProtocol {

    // MARK: - Singleton

    static let shared = FirebaseImageService()

    private init() {}

    // MARK: - Dependencies

    private var config: FirebaseConfiguration {
        FirebaseConfiguration.shared
    }

    // MARK: - Upload Operations

    /// Upload recipe image to Firebase Storage
    /// - Parameter recipe: Recipe with local image to upload
    /// - Returns: Download URL string, or nil if no image to upload
    /// - Throws: FirebaseError if upload fails
    func uploadImage(for recipe: Recipe) async throws -> String? {
        guard config.isAuthenticated, let userId = config.currentUserId else {
            throw FirebaseError.notAuthenticated
        }

        // Check if recipe has a local image
        guard recipe.imageFileName != nil else {
            return nil
        }

        // Load image data from local storage
        guard let image = await recipe.loadImage() else {
            print("⚠️ [Firebase Storage] No local image found for recipe: \(recipe.title)")
            return nil
        }

        // Compress image (max 1MB for efficient upload)
        guard let imageData = await compressImage(image, maxBytes: 1_000_000) else {
            print("⚠️ [Firebase Storage] Failed to compress image for recipe: \(recipe.title)")
            return nil
        }

        let recipeId = recipe.id.uuidString
        let storagePath = "users/\(userId)/recipes/\(recipeId)/image.jpg"
        let storageRef = config.storage.reference().child(storagePath)

        print("📤 [Firebase Storage] Uploading image for recipe: \(recipe.title)")

        // Upload image data
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)

        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        let urlString = downloadURL.absoluteString

        print("✅ [Firebase Storage] Image uploaded: \(storagePath)")

        return urlString
    }

    // MARK: - Download Operations

    /// Download recipe image from Firebase Storage and cache locally
    /// - Parameter recipe: Recipe with Firebase image URL to download
    /// - Throws: FirebaseError if download fails
    func downloadImage(for recipe: Recipe) async throws {
        guard let firebaseImageURL = recipe.firebaseImageURL else {
            return
        }

        // Skip if already cached locally
        if let imageFileName = recipe.imageFileName,
           await recipe.loadImage() != nil {
            print("✅ [Firebase Storage] Image already cached locally: \(imageFileName)")
            return
        }

        print("📥 [Firebase Storage] Downloading image for recipe: \(recipe.title)")

        // Download from Firebase Storage
        let storageRef = config.storage.reference(forURL: firebaseImageURL)
        let imageData = try await storageRef.data(maxSize: 10 * 1024 * 1024) // Max 10MB

        guard let image = UIImage(data: imageData) else {
            print("⚠️ [Firebase Storage] Failed to decode image data")
            throw FirebaseError.downloadFailed(
                NSError(domain: "FirebaseStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
            )
        }

        // Save to local cache
        try await recipe.saveImage(image)

        print("✅ [Firebase Storage] Image downloaded and cached: \(recipe.imageFileName ?? "unknown")")
    }

    // MARK: - Delete Operations

    /// Delete recipe image from Firebase Storage
    /// - Parameter recipeId: ID of recipe whose image should be deleted
    /// - Throws: FirebaseError if delete fails
    func deleteImage(for recipeId: UUID) async throws {
        guard let userId = config.currentUserId else {
            throw FirebaseError.notAuthenticated
        }

        let storagePath = "users/\(userId)/recipes/\(recipeId.uuidString)/image.jpg"
        let storageRef = config.storage.reference().child(storagePath)

        print("🗑️ [Firebase Storage] Deleting image: \(storagePath)")

        do {
            try await storageRef.delete()
            print("✅ [Firebase Storage] Image deleted: \(storagePath)")
        } catch {
            // Ignore "not found" errors (image may not exist)
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                print("ℹ️ [Firebase Storage] Image not found (already deleted): \(storagePath)")
            } else {
                throw error
            }
        }
    }

    /// Delete image from Firebase Storage by URL
    /// - Parameter url: Firebase Storage URL of image to delete
    /// - Throws: FirebaseError if delete fails
    func deleteImage(at url: String) async throws {
        let storageRef = config.storage.reference(forURL: url)

        print("🗑️ [Firebase Storage] Deleting image at URL: \(url)")

        do {
            try await storageRef.delete()
            print("✅ [Firebase Storage] Image deleted")
        } catch {
            // Ignore "not found" errors
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                print("ℹ️ [Firebase Storage] Image not found (already deleted)")
            } else {
                throw error
            }
        }
    }

    // MARK: - Image Compression

    /// Compress UIImage to target size
    /// Strategy: Resize first for efficiency, then reduce quality iteratively
    /// - Parameters:
    ///   - image: Image to compress
    ///   - maxBytes: Maximum size in bytes
    /// - Returns: Compressed JPEG data, or nil if compression failed
    private func compressImage(_ image: UIImage, maxBytes: Int) async -> Data? {
        var workingImage = image

        // Step 1: Resize first if image is too large (more efficient than quality reduction)
        let maxDimension: CGFloat = 1200
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)

        if scale < 1.0 {
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            let renderer = UIGraphicsImageRenderer(size: newSize)
            workingImage = renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        // Step 2: Iteratively reduce quality until under max size
        var compression: CGFloat = 0.9
        var imageData = workingImage.jpegData(compressionQuality: compression)

        while let data = imageData, data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            imageData = workingImage.jpegData(compressionQuality: compression)
        }

        return imageData
    }
}
