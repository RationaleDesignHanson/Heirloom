import Foundation
import SwiftUI

/// Google Cloud Vision API integration for handwriting-optimized OCR
/// Uses DOCUMENT_TEXT_DETECTION for superior handwriting recognition
@MainActor
class GoogleVisionOCRService {

    // MARK: - Configuration

    private let apiKey: String
    private let endpoint = "https://vision.googleapis.com/v1/images:annotate"
    private let session: URLSession

    // MARK: - Initialization

    init(apiKey: String) {
        self.apiKey = apiKey

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - OCR Methods

    /// Recognize handwritten text from an image using Google Vision API
    /// - Parameter image: UIImage containing handwritten recipe
    /// - Returns: Extracted text with high accuracy for handwriting
    func recognizeHandwriting(in image: UIImage) async throws -> GoogleVisionResult {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw GoogleVisionError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()

        // Build request
        let request: [String: Any] = [
            "requests": [
                [
                    "image": ["content": base64Image],
                    "features": [
                        [
                            "type": "DOCUMENT_TEXT_DETECTION",
                            "model": "builtin/latest"  // Uses latest handwriting model
                        ]
                    ],
                    "imageContext": [
                        "languageHints": ["en"],
                        "textDetectionParams": [
                            "enableTextDetectionConfidenceScore": true
                        ]
                    ]
                ]
            ]
        ]

        // Send to Google Vision API
        let response = try await sendRequest(request)

        // Parse response
        return try parseResponse(response)
    }

    // MARK: - Private Methods

    private func sendRequest(_ request: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: endpoint) else {
            throw GoogleVisionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleVisionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GoogleVisionError.apiError(message)
            }
            throw GoogleVisionError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GoogleVisionError.invalidJSON
        }

        return json
    }

    private func parseResponse(_ response: [String: Any]) throws -> GoogleVisionResult {
        guard let responses = response["responses"] as? [[String: Any]],
              let firstResponse = responses.first else {
            throw GoogleVisionError.noResults
        }

        // Check for errors in response
        if let error = firstResponse["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw GoogleVisionError.apiError(message)
        }

        // Extract full text annotation
        guard let fullTextAnnotation = firstResponse["fullTextAnnotation"] as? [String: Any],
              let text = fullTextAnnotation["text"] as? String else {
            throw GoogleVisionError.noTextFound
        }

        // Extract confidence scores from pages (if available)
        var averageConfidence: Double = 0.8 // Default confidence
        if let pages = fullTextAnnotation["pages"] as? [[String: Any]], !pages.isEmpty {
            var totalConfidence = 0.0
            var count = 0

            for page in pages {
                if let blocks = page["blocks"] as? [[String: Any]] {
                    for block in blocks {
                        if let confidence = block["confidence"] as? Double {
                            totalConfidence += confidence
                            count += 1
                        }
                    }
                }
            }

            if count > 0 {
                averageConfidence = totalConfidence / Double(count)
            }
        }

        Log.info("✅ Google Vision OCR complete", category: .ocr, metadata: [
            "text_length": text.count,
            "confidence": String(format: "%.2f", averageConfidence)
        ])

        return GoogleVisionResult(
            text: text,
            confidence: averageConfidence
        )
    }
}
