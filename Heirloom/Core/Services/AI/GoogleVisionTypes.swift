import Foundation

// MARK: - Shared Google Vision Types

/// Result from Google Vision OCR
struct GoogleVisionResult {
    let text: String
    let confidence: Double
}

/// Google Vision API errors
enum GoogleVisionError: LocalizedError {
    case invalidImage
    case invalidURL
    case invalidResponse
    case invalidJSON
    case httpError(Int)
    case apiError(String)
    case noResults
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not convert image to data"
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Invalid response from Google Vision API"
        case .invalidJSON:
            return "Could not parse JSON response"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .apiError(let message):
            return "Google Vision API error: \(message)"
        case .noResults:
            return "No results returned from Google Vision API"
        case .noTextFound:
            return "No text found in image"
        }
    }
}
