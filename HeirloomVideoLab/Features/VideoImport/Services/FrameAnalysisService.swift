//
//  FrameAnalysisService.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Video frame extraction and OCR using Vision framework

import Foundation
import AVFoundation
import Vision
import UIKit

/// Production frame analysis service using AVFoundation + Vision
class FrameAnalysisService: FrameAnalysisServiceProtocol {

    // MARK: - Frame Extraction

    func extractKeyFrames(from videoURL: URL, count: Int) async throws -> [UIImage] {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)

        // Configure for quality and performance
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // Limit frame size for memory efficiency
        // 1280x720 is sufficient for text recognition
        generator.maximumSize = CGSize(width: 1280, height: 720)

        // Calculate sample times
        let duration = try await asset.load(.duration)
        let times = calculateSampleTimes(duration: duration, count: count)

        // Extract frames
        var frames: [UIImage] = []
        for time in times {
            autoreleasepool {
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    let uiImage = UIImage(cgImage: cgImage)
                    frames.append(uiImage)
                } catch {
                    // Skip failed frames, don't fail entire extraction
                    print("Failed to extract frame at \(time.seconds)s: \(error)")
                }
            }
        }

        guard !frames.isEmpty else {
            throw FrameAnalysisError.noFramesExtracted
        }

        return frames
    }

    // MARK: - OCR Analysis

    func analyzeForRecipeElements(_ frames: [UIImage]) async throws -> [String] {
        var detectedElements: [String] = []

        for frame in frames {
            let elements = try await performOCR(on: frame)
            detectedElements.append(contentsOf: elements)
        }

        // Remove duplicates and return unique elements
        return Array(Set(detectedElements)).sorted()
    }

    /// Perform OCR on a single frame
    private func performOCR(on image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            return []
        }

        // Create Vision text recognition request
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true

        // Perform request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }

        // Extract recipe-relevant text
        var recipeElements: [String] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else {
                continue
            }

            let text = candidate.string

            // Only include recipe-relevant text
            if isRecipeRelevant(text) {
                recipeElements.append(text)
            }
        }

        return recipeElements
    }

    // MARK: - Relevance Filtering

    /// Check if detected text is recipe-relevant
    private func isRecipeRelevant(_ text: String) -> Bool {
        // Patterns for recipe-relevant text
        let patterns = [
            // Temperatures
            #"\d+\s*°[FCfc]"#,
            #"\d+\s*degrees?"#,

            // Times
            #"\d+\s*(min|minute|minutes|hour|hours|hr|hrs|sec|seconds?)"#,

            // Measurements
            #"\d+\s*(cup|cups|tablespoon|tbsp|teaspoon|tsp|ounce|oz|pound|lb|gram|g|kilogram|kg|milliliter|ml|liter|l)"#,

            // Quantities
            #"\d+/\d+"#,  // Fractions like 1/2
            #"\d+\.\d+"#,  // Decimals like 2.5

            // Common recipe words (with numbers nearby)
            #".*\d+.*(?:flour|sugar|salt|butter|egg|oil|water|milk)"#,
        ]

        // Check if text matches any pattern
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Time Calculation

    /// Calculate sample times for frame extraction
    private func calculateSampleTimes(duration: CMTime, count: Int) -> [CMTime] {
        let totalSeconds = duration.seconds
        let interval = totalSeconds / Double(count + 1)

        var times: [CMTime] = []
        for i in 1...count {
            let seconds = interval * Double(i)
            times.append(CMTime(seconds: seconds, preferredTimescale: 600))
        }

        return times
    }
}

// MARK: - Errors

enum FrameAnalysisError: LocalizedError {
    case noFramesExtracted
    case ocrFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noFramesExtracted:
            return "Failed to extract any frames from video"
        case .ocrFailed(let error):
            return "OCR analysis failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Advanced Frame Analysis (Future Enhancement)

extension FrameAnalysisService {
    /// Detect if frame contains on-screen text overlays
    func detectTextOverlays(in frame: UIImage) async throws -> Bool {
        guard let cgImage = frame.cgImage else {
            return false
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast  // Faster check for presence of text

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        // If we find any text, assume there are overlays
        return (request.results?.count ?? 0) > 0
    }

    /// Smart sampling: Extract more frames where text is detected
    func extractKeyFramesAdaptive(from videoURL: URL, maxFrames: Int = 10) async throws -> [UIImage] {
        // First pass: Sample uniformly
        let initialFrames = try await extractKeyFrames(from: videoURL, count: 5)

        var selectedFrames: [UIImage] = []

        // Second pass: Prioritize frames with text
        for frame in initialFrames {
            let hasText = try await detectTextOverlays(in: frame)
            if hasText || selectedFrames.count < 3 {
                selectedFrames.append(frame)
            }
        }

        return Array(selectedFrames.prefix(maxFrames))
    }
}

// MARK: - Performance Optimization

extension FrameAnalysisService {
    /// Check if frame analysis should be skipped (e.g., if transcript is high quality)
    static func shouldSkipFrameAnalysis(transcriptConfidence: Double) -> Bool {
        // If transcript confidence is very high (>0.85), frame analysis may not add much value
        // Skip to save processing time and cost
        return transcriptConfidence >= 0.85
    }

    /// Estimate processing time for frame analysis
    static func estimateProcessingTime(frameCount: Int) -> TimeInterval {
        // Approximate: 0.5-1 second per frame for extraction + OCR
        return Double(frameCount) * 0.75
    }
}
