import Foundation
import UIKit

/// Manages recipe image storage in the file system (not database)
/// Per Systems Architect recommendation: prevents SwiftData/CloudKit bloat
actor ImageStorageService {
    private let fileManager = FileManager.default
    private let maxImageSizeBytes: Int = 1_000_000  // 1MB max per image
    private let imageCache: ImageCache

    /// Directory where recipe images are stored (initialized once to avoid race conditions)
    private let imagesDirectory: URL

    init(imageCache: ImageCache) {
        self.imageCache = imageCache
        // Initialize images directory once
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesPath = documentsPath.appendingPathComponent("RecipeImages", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: imagesPath.path) {
            try? fileManager.createDirectory(at: imagesPath, withIntermediateDirectories: true)
        }

        self.imagesDirectory = imagesPath
    }

    // MARK: - Save Image

    /// Save an image to the file system with compression
    /// Returns the file name (not full path) to store in Recipe model
    func saveImage(_ image: UIImage, recipeId: UUID) async throws -> String {
        let fileName = "recipe-\(recipeId.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        // Compress image to max 1MB
        guard let compressedData = await compressImage(image, maxBytes: maxImageSizeBytes) else {
            throw ImageError.compressionFailed
        }

        // Write to disk
        do {
            try compressedData.write(to: fileURL, options: .atomic)
            Log.info("Saved image", category: .storage, metadata: ["fileName": fileName, "sizeKB": compressedData.count / 1024])

            // Update cache
            imageCache.setImage(image, for: fileURL)

            return fileName
        } catch {
            throw ImageError.writeFailed(error)
        }
    }

    /// Download image from URL and save to file system
    /// Returns the file name (not full path) to store in Recipe model
    func downloadAndSaveImage(from urlString: String, recipeId: UUID) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ImageError.invalidURL
        }

        Log.info("Downloading recipe image", category: .storage, metadata: ["url": urlString])

        // Download image data
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ImageError.downloadFailed
        }

        guard let image = UIImage(data: data) else {
            throw ImageError.invalidImageData
        }

        Log.info("Downloaded recipe image", category: .storage, metadata: ["sizeKB": data.count / 1024])

        // Save using existing saveImage method
        return try await saveImage(image, recipeId: recipeId)
    }

    // MARK: - Load Image

    /// Load an image from the file system
    func loadImage(fileName: String) async -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        // Check cache first
        if let cachedImage = imageCache.image(for: fileURL) {
            return cachedImage
        }

        // Load from disk
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            Log.warning("Failed to load image from disk", category: .storage, metadata: ["fileName": fileName])
            return nil
        }

        // Update cache
        imageCache.setImage(image, for: fileURL)

        return image
    }

    // MARK: - Delete Image

    /// Delete an image file from the file system
    func deleteImage(fileName: String) async {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        do {
            try fileManager.removeItem(at: fileURL)
            imageCache.removeImage(for: fileURL)
            Log.info("Deleted image", category: .storage, metadata: ["fileName": fileName])
        } catch {
            Log.warning("Failed to delete image", category: .storage, metadata: ["fileName": fileName, "error": error.localizedDescription])
        }
    }

    // MARK: - Migration

    /// Migrate old image filenames to new "recipe-{uuid}.jpg" format
    /// Renames files on disk and returns a mapping of old filename → new filename
    /// to update Recipe.imageFileName properties
    func migrateImageFilenames() async -> [String: String] {
        do {
            let imageFiles = try fileManager.contentsOfDirectory(
                at: imagesDirectory,
                includingPropertiesForKeys: nil
            )

            var migrations: [String: String] = [:]
            Log.info("Starting image filename migration", category: .storage, metadata: ["imageCount": imageFiles.count])

            for fileURL in imageFiles {
                let oldFileName = fileURL.lastPathComponent

                // Skip if already in correct format
                if oldFileName.hasPrefix("recipe-") {
                    continue
                }

                // Only migrate .jpg files with UUID format
                guard oldFileName.hasSuffix(".jpg"),
                      let uuid = extractUUID(from: oldFileName) else {
                    Log.debug("Skipping non-standard file", category: .storage, metadata: ["fileName": oldFileName])
                    continue
                }

                // Generate new filename with "recipe-" prefix
                let newFileName = "recipe-\(uuid).jpg"
                let newFileURL = imagesDirectory.appendingPathComponent(newFileName)

                // Rename file on disk
                do {
                    try fileManager.moveItem(at: fileURL, to: newFileURL)
                    migrations[oldFileName] = newFileName
                    Log.info("Migrated image filename", category: .storage, metadata: ["oldName": oldFileName, "newName": newFileName])
                } catch {
                    Log.warning("Failed to migrate image filename", category: .storage, metadata: ["fileName": oldFileName, "error": error.localizedDescription])
                }
            }

            Log.info("Image filename migration complete", category: .storage, metadata: ["migratedCount": migrations.count])
            return migrations
        } catch {
            Log.error("Image filename migration failed", category: .storage, metadata: ["error": error.localizedDescription])
            return [:]
        }
    }

    /// Extract UUID from filename (handles both "uuid.jpg" and "recipe-uuid.jpg")
    private func extractUUID(from fileName: String) -> String? {
        let cleanName = fileName
            .replacingOccurrences(of: "recipe-", with: "")
            .replacingOccurrences(of: ".jpg", with: "")

        // Validate it's a UUID format
        guard UUID(uuidString: cleanName) != nil else {
            return nil
        }

        return cleanName
    }

    // MARK: - Cleanup

    /// Clean up orphaned images (images without corresponding recipes)
    /// Call this periodically or on app launch
    func performCleanup() {
        Task {
            let imageFiles = try? fileManager.contentsOfDirectory(
                at: imagesDirectory,
                includingPropertiesForKeys: nil
            )

            guard let imageFiles = imageFiles else { return }

            Log.info("Starting image cleanup", category: .storage, metadata: ["imageCount": imageFiles.count])

            // TODO: In Day 2, query SwiftData for all Recipe.imageFileName
            // and delete any files not in that list
            // For now, just report the count
        }
    }

    /// Calculate total storage used by all recipe images
    func calculateTotalStorageSize() async -> Int {
        do {
            let imageFiles = try fileManager.contentsOfDirectory(
                at: imagesDirectory,
                includingPropertiesForKeys: [.fileSizeKey]
            )

            var totalSize = 0
            for fileURL in imageFiles {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += fileSize
                }
            }

            return totalSize
        } catch {
            Log.warning("Failed to calculate storage size", category: .storage, metadata: ["error": error.localizedDescription])
            return 0
        }
    }

    // MARK: - Heritage Collections - Image Variants

    /// Image variant types for heritage collections
    enum ImageVariant: String, CaseIterable {
        case hero = "hero"              // 1200×900 (4:3)
        case card = "card"              // 800×600 (4:3)
        case thumbnail = "thumbnail"    // 400×300 (4:3)
        case collectionCover = "collection-cover"  // 1600×900 (16:9)

        var targetSize: CGSize {
            switch self {
            case .hero: return CGSize(width: 1200, height: 900)
            case .card: return CGSize(width: 800, height: 600)
            case .thumbnail: return CGSize(width: 400, height: 300)
            case .collectionCover: return CGSize(width: 1600, height: 900)
            }
        }

        var aspectRatio: CGFloat {
            targetSize.width / targetSize.height
        }
    }

    /// Save heritage image with all variants and generate blurhash
    /// Returns dictionary of variant names to filenames and blurhash
    func saveHeritageImage(_ image: UIImage, recipeId: UUID) async throws -> (variants: [String: String], blurhash: String?) {
        var variantFilenames: [String: String] = [:]

        // Generate and save each variant
        for variant in ImageVariant.allCases {
            let resizedImage = await resizeImage(image, to: variant.targetSize, aspectRatio: variant.aspectRatio)
            let fileName = "recipe-\(recipeId.uuidString)-\(variant.rawValue).jpg"
            let fileURL = imagesDirectory.appendingPathComponent(fileName)

            guard let imageData = resizedImage.jpegData(compressionQuality: 0.85) else {
                throw ImageError.compressionFailed
            }

            try imageData.write(to: fileURL, options: .atomic)
            variantFilenames[variant.rawValue] = fileName

            Log.info("Saved heritage image variant", category: .storage, metadata: [
                "variant": variant.rawValue,
                "fileName": fileName,
                "sizeKB": imageData.count / 1024
            ])
        }

        // Generate blurhash from thumbnail variant (smallest for fast generation)
        let blurhash: String?
        if let thumbnailFileName = variantFilenames[ImageVariant.thumbnail.rawValue],
           let thumbnailImage = await loadImage(fileName: thumbnailFileName) {
            // Generate blurhash with 4x3 components (good balance of quality and size)
            blurhash = BlurHashEncoder.encode(thumbnailImage, componentsX: 4, componentsY: 3)

            if let hash = blurhash {
                Log.info("Generated blurhash", category: .storage, metadata: ["hash": hash])
            }
        } else {
            blurhash = nil
        }

        return (variants: variantFilenames, blurhash: blurhash)
    }

    /// Load a specific image variant
    func loadImageVariant(fileName: String, variant: ImageVariant) async -> UIImage? {
        // Extract base filename and construct variant filename
        let baseFileName = fileName.replacingOccurrences(of: ".jpg", with: "")
        let variantFileName = "\(baseFileName)-\(variant.rawValue).jpg"

        return await loadImage(fileName: variantFileName)
    }

    /// Resize image to target size with aspect ratio preservation
    private func resizeImage(_ image: UIImage, to targetSize: CGSize, aspectRatio: CGFloat) async -> UIImage {
        // Calculate dimensions maintaining aspect ratio
        let imageAspectRatio = image.size.width / image.size.height
        let newSize = targetSize

        if imageAspectRatio != aspectRatio {
            // Crop to match target aspect ratio
            let cropRect: CGRect
            if imageAspectRatio > aspectRatio {
                // Image is wider - crop width
                let cropWidth = image.size.height * aspectRatio
                let cropX = (image.size.width - cropWidth) / 2
                cropRect = CGRect(x: cropX, y: 0, width: cropWidth, height: image.size.height)
            } else {
                // Image is taller - crop height
                let cropHeight = image.size.width / aspectRatio
                let cropY = (image.size.height - cropHeight) / 2
                cropRect = CGRect(x: 0, y: cropY, width: image.size.width, height: cropHeight)
            }

            // Crop and resize
            guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
                return resizeImageSimple(image, to: newSize)
            }

            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            return resizeImageSimple(croppedImage, to: newSize)
        }

        return resizeImageSimple(image, to: newSize)
    }

    /// Simple image resize without aspect ratio correction
    private func resizeImageSimple(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    // MARK: - Compression

    /// Compress UIImage to target size (resize first for efficiency, then compress quality)
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

    // MARK: - Storage Stats

    /// Get total storage used by recipe images
    func getTotalStorageUsed() async -> Int {
        guard let imageFiles = try? fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }

        let totalBytes = imageFiles.reduce(0) { total, url in
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + fileSize
        }

        return totalBytes
    }
}

// MARK: - Errors
enum ImageError: LocalizedError {
    case compressionFailed
    case writeFailed(Error)
    case notFound
    case invalidURL
    case downloadFailed
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .writeFailed(let error):
            return "Failed to save image: \(error.localizedDescription)"
        case .notFound:
            return "Image not found"
        case .invalidURL:
            return "Invalid image URL"
        case .downloadFailed:
            return "Failed to download image"
        case .invalidImageData:
            return "Downloaded data is not a valid image"
        }
    }
}
