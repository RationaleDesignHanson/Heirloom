import Foundation
import Vision
import AVFoundation
import CoreImage

actor OnScreenTextDetector {

    /// Detect on-screen recipe text in video frames
    func detect(in videoURL: URL) async throws -> OnScreenTextResult {
        // 1. Extract key frames
        let frames = try await extractKeyFrames(from: videoURL, count: 8)

        guard !frames.isEmpty else {
            return OnScreenTextResult(
                hasRecipeText: false,
                detectedText: nil,
                recipeRelevanceScore: 0,
                confidence: 0,
                frameCount: 0,
                reasoning: "Could not extract frames"
            )
        }

        // 2. Run OCR on each frame
        var allDetectedText: [String] = []
        var totalConfidence: Float = 0

        for frame in frames {
            let (text, confidence) = try await performOCR(on: frame)
            if !text.isEmpty {
                allDetectedText.append(text)
                totalConfidence += confidence
            }
        }

        // 3. Combine and deduplicate text
        let combinedText = deduplicateText(allDetectedText)
        let avgConfidence = allDetectedText.isEmpty ? 0 : totalConfidence / Float(allDetectedText.count)

        // 4. Check recipe relevance
        let relevanceScore = RecipeKeywords.relevanceScore(for: combinedText)

        // 5. Determine if text is useful
        let hasRecipeText = relevanceScore >= 0.2 && avgConfidence >= 0.5

        let reasoning: String
        if hasRecipeText {
            reasoning = "Found recipe text: \(Int(relevanceScore * 100))% relevance, \(Int(avgConfidence * 100))% OCR confidence"
        } else if relevanceScore < 0.2 {
            reasoning = "Text found but not recipe-related (\(Int(relevanceScore * 100))% relevance)"
        } else {
            reasoning = "OCR confidence too low (\(Int(avgConfidence * 100))%)"
        }

        return OnScreenTextResult(
            hasRecipeText: hasRecipeText,
            detectedText: hasRecipeText ? combinedText : nil,
            recipeRelevanceScore: relevanceScore,
            confidence: avgConfidence,
            frameCount: frames.count,
            reasoning: reasoning
        )
    }

    // MARK: - Frame Extraction

    private func extractKeyFrames(from url: URL, count: Int) async throws -> [CGImage] {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration).seconds

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

        // Sample evenly across video
        var frames: [CGImage] = []
        let interval = duration / Double(count + 1)

        for i in 1...count {
            let time = CMTime(seconds: interval * Double(i), preferredTimescale: 600)
            if let image = try? await generator.image(at: time).image {
                frames.append(image)
            }
        }

        return frames
    }

    // MARK: - OCR

    private func performOCR(on image: CGImage) async throws -> (text: String, confidence: Float) {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ("", 0))
                    return
                }

                var texts: [String] = []
                var totalConfidence: Float = 0

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    texts.append(topCandidate.string)
                    totalConfidence += topCandidate.confidence
                }

                let combinedText = texts.joined(separator: " ")
                let avgConfidence = texts.isEmpty ? 0 : totalConfidence / Float(texts.count)

                continuation.resume(returning: (combinedText, avgConfidence))
            }

            // Configure for accurate text recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Text Processing

    private func deduplicateText(_ texts: [String]) -> String {
        // Combine all text
        let allText = texts.joined(separator: "\n")

        // Split into words and remove duplicates while preserving order
        var seenWords = Set<String>()
        var uniqueWords: [String] = []

        let words = allText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        for word in words {
            let normalized = word.lowercased()
            if !seenWords.contains(normalized) {
                seenWords.insert(normalized)
                uniqueWords.append(word)
            }
        }

        return uniqueWords.joined(separator: " ")
    }
}
