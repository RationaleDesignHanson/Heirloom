//
//  VideoThumbnailGenerator.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-20.
//

import AVFoundation
import UIKit
import Photos

/// Generates thumbnail images from video files
enum VideoThumbnailGenerator {

    /// Generate a thumbnail from a video URL or PHAsset identifier
    /// - Parameters:
    ///   - videoIdentifier: Either a file URL path or PHAsset local identifier
    ///   - size: Desired thumbnail size (defaults to 600x600 for high quality recipe card display)
    /// - Returns: Thumbnail image data in JPEG format, or nil if generation fails
    static func generateThumbnail(
        from videoIdentifier: String,
        size: CGSize = CGSize(width: 600, height: 600)
    ) async -> Data? {
        // Check if this is a PHAsset identifier
        if videoIdentifier.contains("/L0/001") || !videoIdentifier.hasPrefix("/") {
            return await generateThumbnailFromPHAsset(identifier: videoIdentifier, size: size)
        }

        // Otherwise treat as file URL
        let url = URL(fileURLWithPath: videoIdentifier)
        return await generateThumbnailFromURL(url: url, size: size)
    }

    /// Generate thumbnail from a PHAsset
    private static func generateThumbnailFromPHAsset(
        identifier: String,
        size: CGSize
    ) async -> Data? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            Log.warning("PHAsset not found", category: .video, metadata: ["identifier": identifier])
            return nil
        }

        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard let image = image else {
                    continuation.resume(returning: nil)
                    return
                }

                // Convert to JPEG data
                let thumbnailData = image.jpegData(compressionQuality: 0.8)
                continuation.resume(returning: thumbnailData)
            }
        }
    }

    /// Generate thumbnail from a file URL
    private static func generateThumbnailFromURL(
        url: URL,
        size: CGSize
    ) async -> Data? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = size

        do {
            // Generate thumbnail at 1 second into the video
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)

            // Convert to JPEG data
            return uiImage.jpegData(compressionQuality: 0.8)
        } catch {
            Log.warning("Failed to generate thumbnail", category: .video, metadata: [
                "url": url.path,
                "error": error.localizedDescription
            ])
            return nil
        }
    }
}
