import Foundation
import Vision
import AVFoundation
import CoreImage

actor WatermarkDetector {

    struct WatermarkResult {
        let platform: SocialPlatform?
        let username: String?
        let confidence: Float
        let detectionMethod: AttributionDetectionMethod
        let rawOCRText: String?
    }

    /// Detect creator watermark in video
    func detect(in videoURL: URL) async throws -> WatermarkResult {
        // Extract frames from different points
        let frames = try await extractWatermarkFrames(from: videoURL)

        var bestResult: WatermarkResult?
        var bestConfidence: Float = 0

        for frame in frames {
            // Check watermark regions (corners where platforms place usernames)
            for region in WatermarkRegion.allCases {
                if let result = try await analyzeRegion(frame: frame, region: region) {
                    if result.confidence > bestConfidence {
                        bestResult = result
                        bestConfidence = result.confidence
                    }
                }
            }
        }

        return bestResult ?? WatermarkResult(
            platform: nil,
            username: nil,
            confidence: 0,
            detectionMethod: .watermark,
            rawOCRText: nil
        )
    }

    // MARK: - Watermark Regions

    private enum WatermarkRegion: CaseIterable {
        case bottomLeft   // TikTok primary
        case bottomRight  // Instagram, TikTok alternate
        case topLeft      // Some platforms

        func rect(for size: CGSize) -> CGRect {
            let width = size.width * 0.4
            let height = size.height * 0.15

            switch self {
            case .bottomLeft:
                return CGRect(x: 0, y: size.height - height, width: width, height: height)
            case .bottomRight:
                return CGRect(x: size.width - width, y: size.height - height, width: width, height: height)
            case .topLeft:
                return CGRect(x: 0, y: 0, width: width, height: height)
            }
        }
    }

    // MARK: - Frame Extraction

    private func extractWatermarkFrames(from url: URL) async throws -> [CGImage] {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration).seconds

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        // Sample: start, middle, end (watermarks are usually consistent)
        let times: [Double] = [0.5, duration * 0.5, max(0.5, duration - 0.5)]

        var frames: [CGImage] = []
        for time in times {
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            if let image = try? await generator.image(at: cmTime).image {
                frames.append(image)
            }
        }

        return frames
    }

    // MARK: - Region Analysis

    private func analyzeRegion(frame: CGImage, region: WatermarkRegion) async throws -> WatermarkResult? {
        let imageSize = CGSize(width: frame.width, height: frame.height)
        let regionRect = region.rect(for: imageSize)

        guard let croppedImage = frame.cropping(to: regionRect) else { return nil }

        // Run OCR
        let text = try await performOCR(on: croppedImage)
        guard !text.isEmpty else { return nil }

        // Look for username pattern (@username)
        let usernamePattern = /@([A-Za-z0-9._]+)/
        guard let match = text.firstMatch(of: usernamePattern) else {
            return nil
        }

        let username = String(match.1)
        let platform = detectPlatform(from: text)
        let confidence = calculateConfidence(username: username, platform: platform, rawText: text)

        return WatermarkResult(
            platform: platform,
            username: username,
            confidence: confidence,
            detectionMethod: .watermark,
            rawOCRText: text
        )
    }

    private func performOCR(on image: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ") ?? ""

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }

    private func detectPlatform(from text: String) -> SocialPlatform? {
        let lowercased = text.lowercased()

        if lowercased.contains("tiktok") || lowercased.contains("tik tok") {
            return .tiktok
        }
        if lowercased.contains("instagram") || lowercased.contains("reels") {
            return .instagram
        }
        if lowercased.contains("youtube") || lowercased.contains("shorts") {
            return .youtube
        }

        return nil
    }

    private func calculateConfidence(username: String, platform: SocialPlatform?, rawText: String) -> Float {
        var confidence: Float = 0.3  // Base for finding username pattern

        if platform != nil { confidence += 0.3 }
        if username.count >= 3 && username.count <= 30 { confidence += 0.2 }
        if rawText.contains("@") { confidence += 0.2 }

        return min(confidence, 1.0)
    }
}
