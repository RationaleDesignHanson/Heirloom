//
//  WatermarkDetectionService.swift
//  Heirloom
//
//  Created by Claude on 1/9/26.
//
//  Watermark detection using Claude's vision API

import Foundation
import UIKit

/// Result of watermark detection
struct WatermarkDetectionResult {
    let creatorHandle: String?
    let platform: VideoPlatform?
    let confidence: Double  // 0.0-1.0
    let detectionSource: String  // e.g., "@username in top-left corner"
}

/// Detects creator watermarks and handles in video frames using Claude's vision API
class WatermarkDetectionService {
    private let aiService: AnthropicAIService

    init(aiService: AnthropicAIService) {
        self.aiService = aiService
    }

    /// Detect watermarks across multiple video frames
    /// Analyzes 3-5 frames and returns most confident detection
    func detectWatermark(from frames: [UIImage]) async throws -> WatermarkDetectionResult? {
        guard !frames.isEmpty else {
            return nil
        }

        // Analyze first 3 frames (watermarks are usually consistent)
        let framesToAnalyze = Array(frames.prefix(3))
        var detections: [WatermarkDetectionResult] = []

        for (index, frame) in framesToAnalyze.enumerated() {
            print("🔍 Analyzing frame \(index + 1)/\(framesToAnalyze.count) for watermarks...")

            if let detection = try await detectWatermarkInFrame(frame) {
                detections.append(detection)
                print("   ✅ Found: \(detection.creatorHandle ?? "unknown") (confidence: \(String(format: "%.0f", detection.confidence * 100))%)")
            } else {
                print("   ❌ No watermark detected")
            }
        }

        guard !detections.isEmpty else {
            print("📊 No watermarks found in any frame")
            return nil
        }

        // Return most confident detection
        let bestDetection = detections.max(by: { $0.confidence < $1.confidence })

        if let best = bestDetection {
            print("✨ Best detection: \(best.creatorHandle ?? "unknown") (confidence: \(String(format: "%.0f", best.confidence * 100))%)")
        }

        return bestDetection
    }

    /// Detect watermark in a single frame using Claude's vision API
    private func detectWatermarkInFrame(_ frame: UIImage) async throws -> WatermarkDetectionResult? {
        // Construct prompt for watermark detection
        let prompt = """
        Analyze this video frame and detect any creator watermarks, handles, or attribution text.

        Look for:
        - Social media handles (e.g., @username, TikTok/@creator)
        - Channel names or creator names
        - URLs containing creator names
        - Watermarked text in corners or overlays

        If you find a watermark or creator attribution, respond with ONLY a JSON object in this format:
        {
          "creator": "username or creator name (without @ symbol)",
          "platform": "tiktok" or "youtube" or "instagram" or "other" or null,
          "confidence": 0.8,
          "source": "brief description of where found"
        }

        If NO watermark is found, respond with: {"creator": null}

        Important: Extract ONLY the creator name/handle, remove @ symbols and URL prefixes.
        Example: "@gordoncooking" → "gordoncooking"
        Example: "TikTok/@chef_maria" → "chef_maria"
        """

        // Call Claude with vision using existing completeWithVision method
        do {
            let response = try await aiService.completeWithVision(
                image: frame,
                prompt: prompt,
                options: AICompletionOptions(
                    temperature: 0.3,  // Lower temperature for more deterministic parsing
                    maxTokens: 300
                ),
                useCase: .ocr  // Optimize for text recognition
            )

            // Parse JSON response from the content
            if let result = parseWatermarkResponse(response.content) {
                return result
            }
        } catch {
            print("⚠️ Claude vision API error: \(error)")
            // Don't throw - just return nil for this frame
            return nil
        }

        return nil
    }

    /// Parse Claude's JSON response into WatermarkDetectionResult
    private func parseWatermarkResponse(_ response: String) -> WatermarkDetectionResult? {
        // Extract JSON from response (Claude sometimes wraps it in text)
        let jsonPattern = #"\{[^\}]+\}"#
        guard let regex = try? NSRegularExpression(pattern: jsonPattern, options: []),
              let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range, in: response) else {
            return nil
        }

        let jsonString = String(response[range])
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

            guard let creator = json?["creator"] as? String, !creator.isEmpty else {
                return nil  // No watermark found
            }

            let confidence = json?["confidence"] as? Double ?? 0.7
            let source = json?["source"] as? String ?? "detected in frame"

            // Parse platform
            var platform: VideoPlatform? = nil
            if let platformStr = json?["platform"] as? String {
                switch platformStr.lowercased() {
                case "tiktok": platform = .tiktok
                case "youtube": platform = .youtube
                case "instagram": platform = .instagram
                default: platform = .other
                }
            }

            return WatermarkDetectionResult(
                creatorHandle: creator,
                platform: platform,
                confidence: confidence,
                detectionSource: source
            )
        } catch {
            print("⚠️ Failed to parse watermark JSON: \(error)")
            return nil
        }
    }
}
