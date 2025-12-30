import Foundation
import UIKit

/// Manages recipe image storage in the file system (not database)
/// Per Systems Architect recommendation: prevents SwiftData/CloudKit bloat
actor ImageStorageService {
    static let shared = ImageStorageService()

    private let fileManager = FileManager.default
    private let maxImageSizeBytes: Int = 1_000_000  // 1MB max per image

    /// Directory where recipe images are stored (initialized once to avoid race conditions)
    private let imagesDirectory: URL

    private init() {
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
            print("✅ Saved image: \(fileName) (\(compressedData.count / 1024)KB)")

            // Update cache
            ImageCache.shared.setImage(image, for: fileURL)

            return fileName
        } catch {
            throw ImageError.writeFailed(error)
        }
    }

    // MARK: - Load Image

    /// Load an image from the file system
    func loadImage(fileName: String) async -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        // Check cache first
        if let cachedImage = ImageCache.shared.image(for: fileURL) {
            return cachedImage
        }

        // Load from disk
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            print("⚠️ Failed to load image: \(fileName)")
            return nil
        }

        // Update cache
        ImageCache.shared.setImage(image, for: fileURL)

        return image
    }

    // MARK: - Delete Image

    /// Delete an image file from the file system
    func deleteImage(fileName: String) async {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        do {
            try fileManager.removeItem(at: fileURL)
            ImageCache.shared.removeImage(for: fileURL)
            print("🗑️ Deleted image: \(fileName)")
        } catch {
            print("⚠️ Failed to delete image: \(fileName), error: \(error)")
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
            print("🔄 Starting image filename migration. Found \(imageFiles.count) images.")

            for fileURL in imageFiles {
                let oldFileName = fileURL.lastPathComponent

                // Skip if already in correct format
                if oldFileName.hasPrefix("recipe-") {
                    continue
                }

                // Only migrate .jpg files with UUID format
                guard oldFileName.hasSuffix(".jpg"),
                      let uuid = extractUUID(from: oldFileName) else {
                    print("⏭️ Skipping non-standard file: \(oldFileName)")
                    continue
                }

                // Generate new filename with "recipe-" prefix
                let newFileName = "recipe-\(uuid).jpg"
                let newFileURL = imagesDirectory.appendingPathComponent(newFileName)

                // Rename file on disk
                do {
                    try fileManager.moveItem(at: fileURL, to: newFileURL)
                    migrations[oldFileName] = newFileName
                    print("✅ Migrated: \(oldFileName) → \(newFileName)")
                } catch {
                    print("⚠️ Failed to migrate \(oldFileName): \(error)")
                }
            }

            print("✅ Migration complete. Migrated \(migrations.count) files.")
            return migrations
        } catch {
            print("⚠️ Migration failed: \(error)")
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

            print("🧹 Starting image cleanup. Found \(imageFiles.count) images.")

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
            print("⚠️ Failed to calculate storage size: \(error)")
            return 0
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

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .writeFailed(let error):
            return "Failed to save image: \(error.localizedDescription)"
        case .notFound:
            return "Image not found"
        }
    }
}
