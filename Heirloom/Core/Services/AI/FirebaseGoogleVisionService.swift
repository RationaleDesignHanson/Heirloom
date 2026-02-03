import Foundation
import SwiftUI
import FirebaseFunctions

/// Firebase-based Google Vision OCR service
/// Proxies requests through Cloud Functions - API keys stay server-side
@MainActor
class FirebaseGoogleVisionService {

    // MARK: - Properties

    private let functions: Functions

    // MARK: - Initialization

    init(functions: Functions? = nil) {
        self.functions = functions ?? Functions.functions()

        #if DEBUG
        // Use local emulator in debug mode if needed
        // self.functions.useEmulator(withHost: "localhost", port: 5001)
        #endif

        Log.info("Firebase Google Vision Service initialized", category: .ocr)
    }

    // MARK: - OCR Methods

    /// Recognize handwritten text from an image using Google Vision API via Firebase gateway
    /// - Parameter image: UIImage containing handwritten recipe
    /// - Returns: Extracted text with high accuracy for handwriting
    func recognizeHandwriting(in image: UIImage) async throws -> GoogleVisionResult {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw GoogleVisionError.invalidImage
        }

        let base64Image = imageData.base64EncodedString()

        Log.debug("Calling googleVisionOCR", category: .ocr, metadata: [
            "imageSizeKB": imageData.count / 1024
        ])

        // Build request
        let data: [String: Any] = [
            "imageBase64": base64Image
        ]

        do {
            // Call Firebase Function
            let result = try await functions.httpsCallable("googleVisionOCR").call(data)

            guard let response = result.data as? [String: Any] else {
                throw GoogleVisionError.invalidResponse
            }

            // Parse response
            guard let text = response["text"] as? String else {
                // Check if there's no text (empty result)
                if let text = response["text"] as? String, text.isEmpty {
                    throw GoogleVisionError.noTextFound
                }
                throw GoogleVisionError.invalidResponse
            }

            let confidence = response["confidence"] as? Double ?? 0.8

            Log.info("OCR complete", category: .ocr, metadata: [
                "textLength": text.count,
                "confidence": String(format: "%.2f", confidence)
            ])

            return GoogleVisionResult(
                text: text,
                confidence: confidence
            )

        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            // Handle Firebase Function errors
            let code = FunctionsErrorCode(rawValue: error.code)

            switch code {
            case .unauthenticated:
                throw GoogleVisionError.apiError("Authentication required")
            case .resourceExhausted:
                throw GoogleVisionError.apiError("Rate limit exceeded. Please try again later.")
            case .invalidArgument:
                throw GoogleVisionError.invalidImage
            default:
                Log.error("Google Vision API error", category: .ocr, error: error)
                throw GoogleVisionError.apiError(error.localizedDescription)
            }
        } catch let error as GoogleVisionError {
            throw error
        } catch {
            Log.error("Unexpected Google Vision error", category: .ocr, error: error)
            throw GoogleVisionError.apiError("OCR request failed: \(error.localizedDescription)")
        }
    }
}
