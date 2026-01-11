//
//  ASMRFrameExtractionService.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import Foundation
import AVFoundation
import UIKit

/// Extracts strategic frames from video for ASMR vision analysis
class ASMRFrameExtractionService {

    // MARK: - Public API

    /// Extract frames strategically distributed across the video
    /// - 5 final frames (last 30s) - finished dish
    /// - 10 cooking frames (middle 60%) - cooking actions
    /// - 5 setup frames (first 60s) - ingredients
    func extractFrames(from videoURL: URL) async throws -> FrameExtractionResult {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let _ = CMTimeGetSeconds(duration) // Validate duration is valid

        // Extract frames from different sections
        let finalFrames = try await extractFinalFrames(asset: asset, duration: duration, count: 5)
        let cookingFrames = try await extractCookingFrames(asset: asset, duration: duration, count: 10)
        let setupFrames = try await extractSetupFrames(asset: asset, duration: duration, count: 5)

        return FrameExtractionResult(
            finalFrames: finalFrames,
            cookingFrames: cookingFrames,
            setupFrames: setupFrames,
            totalFrames: finalFrames.count + cookingFrames.count + setupFrames.count
        )
    }

    // MARK: - Private Methods

    /// Extract frames from the last 30 seconds showing finished dish
    private func extractFinalFrames(
        asset: AVAsset,
        duration: CMTime,
        count: Int
    ) async throws -> [ExtractedFrame] {
        let durationSeconds = CMTimeGetSeconds(duration)

        // Last 30 seconds (or last 10% if video is shorter)
        let startTime = max(0, durationSeconds - 30)
        let endTime = durationSeconds

        return try await extractFramesInRange(
            asset: asset,
            startTime: startTime,
            endTime: endTime,
            count: count,
            frameType: .final
        )
    }

    /// Extract frames from middle 60% showing cooking actions
    private func extractCookingFrames(
        asset: AVAsset,
        duration: CMTime,
        count: Int
    ) async throws -> [ExtractedFrame] {
        let durationSeconds = CMTimeGetSeconds(duration)

        // Middle 60% of video (skip first 20% and last 20%)
        let startTime = durationSeconds * 0.2
        let endTime = durationSeconds * 0.8

        return try await extractFramesInRange(
            asset: asset,
            startTime: startTime,
            endTime: endTime,
            count: count,
            frameType: .cooking
        )
    }

    /// Extract frames from first 60 seconds showing ingredients/setup
    private func extractSetupFrames(
        asset: AVAsset,
        duration: CMTime,
        count: Int
    ) async throws -> [ExtractedFrame] {
        let durationSeconds = CMTimeGetSeconds(duration)

        // First 60 seconds (or first 10% if video is shorter)
        let endTime = min(60, durationSeconds * 0.1)

        return try await extractFramesInRange(
            asset: asset,
            startTime: 0,
            endTime: endTime,
            count: count,
            frameType: .setup
        )
    }

    /// Extract frames evenly distributed in a time range
    private func extractFramesInRange(
        asset: AVAsset,
        startTime: Double,
        endTime: Double,
        count: Int,
        frameType: FrameType
    ) async throws -> [ExtractedFrame] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        // Calculate evenly distributed timestamps
        let interval = (endTime - startTime) / Double(count)
        var frames: [ExtractedFrame] = []

        for i in 0..<count {
            let timestamp = startTime + (Double(i) * interval)
            let time = CMTime(seconds: timestamp, preferredTimescale: 600)

            do {
                let cgImage = try await generator.image(at: time).image
                let uiImage = UIImage(cgImage: cgImage)

                frames.append(ExtractedFrame(
                    image: uiImage,
                    timestamp: timestamp,
                    frameIndex: frames.count,
                    frameType: frameType
                ))
            } catch {
                print("⚠️ Failed to extract frame at \(timestamp)s: \(error.localizedDescription)")
                // Continue with other frames even if one fails
            }
        }

        // Verify we got at least some frames
        guard !frames.isEmpty else {
            throw FrameExtractionError.noFramesExtracted
        }

        return frames
    }

    /// Create a grid of images for efficient API usage (combines multiple frames)
    func createImageGrid(from images: [UIImage], maxSize: CGSize = CGSize(width: 1024, height: 1024)) async throws -> UIImage {
        guard !images.isEmpty else {
            throw FrameExtractionError.noFramesProvided
        }

        // Arrange images in grid (2 columns, multiple rows)
        let cols = min(2, images.count)
        let rows = (images.count + cols - 1) / cols
        let cellWidth = maxSize.width / CGFloat(cols)
        let cellHeight = maxSize.height / CGFloat(rows)

        let renderer = UIGraphicsImageRenderer(size: maxSize)
        return renderer.image { context in
            // Fill background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: maxSize))

            // Draw images in grid
            for (index, image) in images.enumerated() {
                let col = index % cols
                let row = index / cols
                let rect = CGRect(
                    x: CGFloat(col) * cellWidth,
                    y: CGFloat(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                image.draw(in: rect)
            }
        }
    }
}

// MARK: - Frame Extraction Error

enum FrameExtractionError: LocalizedError {
    case noFramesExtracted
    case noFramesProvided
    case invalidTimeRange
    case imageGenerationFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noFramesExtracted:
            return "Failed to extract any frames from video"
        case .noFramesProvided:
            return "No frames provided for grid creation"
        case .invalidTimeRange:
            return "Invalid time range for frame extraction"
        case .imageGenerationFailed(let error):
            return "Image generation failed: \(error.localizedDescription)"
        }
    }
}
