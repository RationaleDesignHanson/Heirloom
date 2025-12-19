import Foundation
@preconcurrency import Vision
import UIKit

/// Enhanced OCR service using Vision framework for recipe card text recognition
/// Supports both printed and handwritten text with confidence scoring
@MainActor
final class EnhancedOCRService {
    // MARK: - Singleton

    static let shared = EnhancedOCRService()

    private init() {}

    // MARK: - Public API

    /// Recognize text from an image with detailed results
    /// - Parameter image: The UIImage to process
    /// - Returns: OCRResult containing recognized text, regions, and metadata
    func recognizeText(from image: UIImage) async throws -> OCRResult {
        print("🔍 Starting OCR recognition...")

        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        // Detect text type (printed vs handwritten)
        let textType = detectTextType(image)
        print("📝 Detected text type: \(textType.displayName)")

        // Create appropriate Vision request
        let request = createVisionRequest(for: textType)

        // Perform recognition on background queue
        let observations = try await performVisionRequest(request, on: cgImage)

        // Process observations into structured result
        let result = processObservations(observations, imageSize: image.size, textType: textType)

        print("✅ OCR complete: \(result.recognizedText.count) characters, confidence: \(String(format: "%.1f%%", result.overallConfidence * 100))")

        return result
    }

    /// Quick text recognition for simple use cases
    /// - Parameter image: The UIImage to process
    /// - Returns: Plain text string of recognized content
    func recognizeTextSimple(from image: UIImage) async throws -> String {
        let result = try await recognizeText(from: image)
        return result.recognizedText
    }

    // MARK: - Text Type Detection

    /// Detect whether the image contains printed or handwritten text
    private func detectTextType(_ image: UIImage) -> TextType {
        // Simple heuristic: check image characteristics
        // In a production app, you could use ML to classify

        // For now, assume printed text by default
        // You could add user selection in UI
        return .printed
    }

    // MARK: - Vision Request Creation

    private func createVisionRequest(for textType: TextType) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()

        // Configure recognition level based on text type
        switch textType {
        case .printed:
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

        case .handwritten:
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Note: Vision can recognize both printed and handwritten with .accurate
        }

        // Set supported languages (English primarily, but Vision supports many)
        request.recognitionLanguages = ["en-US"]

        // Enable automatic language detection
        request.automaticallyDetectsLanguage = true

        return request
    }

    // MARK: - Vision Processing

    private func performVisionRequest(
        _ request: VNRecognizeTextRequest,
        on cgImage: CGImage
    ) async throws -> [VNRecognizedTextObservation] {
        // Create request handler
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: .up,
            options: [:]
        )
        
        // Perform request on background queue using Task
        return try await Task.detached(priority: .userInitiated) {
            try handler.perform([request])
            
            guard let observations = request.results, !observations.isEmpty else {
                throw OCRError.noTextFound
            }
            
            return observations
        }.value
    }

    // MARK: - Result Processing

    private func processObservations(
        _ observations: [VNRecognizedTextObservation],
        imageSize: CGSize,
        textType: TextType
    ) -> OCRResult {
        var textRegions: [TextRegion] = []
        var allText = ""
        var totalConfidence: Float = 0

        for observation in observations {
            // Get top candidate (most confident recognition)
            guard let candidate = observation.topCandidates(1).first else {
                continue
            }

            let text = candidate.string
            let confidence = candidate.confidence

            // Convert normalized bounding box to pixel coordinates
            let boundingBox = observation.boundingBox
            let rect = VNImageRectForNormalizedRect(
                boundingBox,
                Int(imageSize.width),
                Int(imageSize.height)
            )

            // Create text region
            let region = TextRegion(
                text: text,
                boundingBox: rect,
                confidence: confidence
            )

            textRegions.append(region)
            allText += text + "\n"
            totalConfidence += confidence
        }

        // Calculate overall confidence
        let overallConfidence = observations.isEmpty ? 0 : totalConfidence / Float(observations.count)

        // Determine quality
        let quality: RecognitionQuality
        if overallConfidence >= 0.9 {
            quality = .excellent
        } else if overallConfidence >= 0.75 {
            quality = .good
        } else if overallConfidence >= 0.5 {
            quality = .fair
        } else {
            quality = .poor
        }

        return OCRResult(
            recognizedText: allText.trimmingCharacters(in: .whitespacesAndNewlines),
            textRegions: textRegions,
            overallConfidence: overallConfidence,
            quality: quality,
            textType: textType,
            processingTime: 0 // Could add timing if needed
        )
    }
}

// MARK: - Supporting Types

extension EnhancedOCRService {

    /// Type of text detected in image
    enum TextType {
        case printed
        case handwritten

        var displayName: String {
            switch self {
            case .printed: return "Printed"
            case .handwritten: return "Handwritten"
            }
        }
    }

    /// OCR result containing all recognized data
    struct OCRResult {
        /// Full recognized text as a single string
        let recognizedText: String

        /// Individual text regions with positions and confidence
        let textRegions: [TextRegion]

        /// Overall confidence (0-1)
        let overallConfidence: Float

        /// Quality assessment
        let quality: RecognitionQuality

        /// Type of text recognized
        let textType: TextType

        /// Processing time in seconds
        let processingTime: TimeInterval

        /// Number of lines detected
        var lineCount: Int {
            recognizedText.components(separatedBy: .newlines).count
        }

        /// Whether the result is reliable for use
        var isReliable: Bool {
            overallConfidence >= 0.7
        }
    }

    /// Individual text region with location and confidence
    struct TextRegion {
        /// Recognized text in this region
        let text: String

        /// Bounding box in image coordinates
        let boundingBox: CGRect

        /// Confidence for this region (0-1)
        let confidence: Float

        /// Whether this region is reliable
        var isReliable: Bool {
            confidence >= 0.7
        }
    }

    /// Quality assessment of recognition
    enum RecognitionQuality {
        case excellent  // 90%+
        case good       // 75-89%
        case fair       // 50-74%
        case poor       // <50%

        var displayName: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            }
        }

        var icon: String {
            switch self {
            case .excellent: return "checkmark.circle.fill"
            case .good: return "checkmark.circle"
            case .fair: return "exclamationmark.triangle"
            case .poor: return "xmark.circle"
            }
        }

        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }

    /// OCR errors
    enum OCRError: LocalizedError {
        case invalidImage
        case noTextFound
        case visionError(Error)
        case processingFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Invalid or corrupted image"
            case .noTextFound:
                return "No text found in image"
            case .visionError(let error):
                return "Vision framework error: \(error.localizedDescription)"
            case .processingFailed:
                return "Failed to process OCR results"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .invalidImage:
                return "Try capturing a new image"
            case .noTextFound:
                return "Make sure the recipe card is clearly visible and well-lit"
            case .visionError:
                return "Check your device's camera permissions and try again"
            case .processingFailed:
                return "Try again with better lighting or a clearer image"
            }
        }
    }
}

// MARK: - Convenience Extensions

extension EnhancedOCRService.OCRResult {
    /// Get text regions sorted by vertical position (top to bottom)
    var regionsSortedByPosition: [EnhancedOCRService.TextRegion] {
        textRegions.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
    }

    /// Get only reliable regions (confidence >= 70%)
    var reliableRegions: [EnhancedOCRService.TextRegion] {
        textRegions.filter { $0.isReliable }
    }

    /// Get confidence as percentage string
    var confidencePercentage: String {
        String(format: "%.1f%%", overallConfidence * 100)
    }
}
