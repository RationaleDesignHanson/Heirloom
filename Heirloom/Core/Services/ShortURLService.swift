import Foundation
import CoreImage
import UIKit

/// Service for generating shortened URLs and QR codes for recipe sharing
///
/// Features:
/// - Short URL generation with custom codes
/// - QR code generation with customization
/// - URL code validation and expiration
/// - Analytics tracking for sharing metrics
@MainActor
final class ShortURLService {
    // MARK: - Dependencies

    private let analytics: AnalyticsService
    private let session: URLSession

    init(analytics: AnalyticsService) {
        self.analytics = analytics

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Constants

    /// Base domain for short URLs
    private let baseDomain = "heirloom.app"

    /// Path prefix for recipe short links
    private let recipePath = "/r/"

    /// Backend API endpoint
    /// TODO: Replace with production URL after deploying Firebase Functions
    private let apiEndpoint = "https://us-central1-heirloom-ios-prod.cloudfunctions.net/shortenURL"

    /// Length of generated short codes
    private let codeLength = 6

    /// Character set for generating codes
    private let codeCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    // MARK: - URL Shortening

    /// Generate a short URL for a CloudKit share URL
    /// - Parameters:
    ///   - longURL: The full CloudKit share URL
    ///   - customCode: Optional custom code (e.g., "grandmas-cookies"). If nil, generates random code
    /// - Returns: Shortened URL (e.g., https://heirloom.app/r/abc123)
    func generateShortURL(from longURL: URL, customCode: String? = nil) async throws -> URL {
        Log.info("Generating short URL", category: .network, metadata: ["url": longURL.absoluteString])

        // Try to call the backend API
        do {
            let result = try await callBackendToShortenURL(longURL: longURL, customCode: customCode)

            // Cache locally for offline access
            saveMapping(code: result.code, longURL: longURL)

            // Track analytics
            trackShortURLGenerated(code: result.code, longURL: longURL)

            Log.info("Short URL generated via backend", category: .network, metadata: ["shortURL": result.shortURL.absoluteString])
            return result.shortURL

        } catch {
            Log.warning("Backend API failed, falling back to local URL generation", category: .network, metadata: ["error": error.localizedDescription])

            // Fallback to local generation
            let code = try validateAndGenerateCode(customCode: customCode)
            let shortURLString = "https://\(baseDomain)\(recipePath)\(code)"
            guard let shortURL = URL(string: shortURLString) else {
                throw ShortURLError.invalidURL
            }

            // Store mapping locally
            saveMapping(code: code, longURL: longURL)

            // Track analytics
            trackShortURLGenerated(code: code, longURL: longURL)

            Log.info("Short URL generated locally", category: .network, metadata: ["shortURL": shortURLString])
            return shortURL
        }
    }

    /// Expand a short code back to the original URL
    /// - Parameter code: The short code (e.g., "abc123")
    /// - Returns: Original CloudKit share URL
    func expandShortURL(code: String) -> URL? {
        return loadMapping(code: code)
    }

    /// Generate a unique short code
    /// - Returns: Random 6-character code
    private func generateCode() -> String {
        return String((0..<codeLength).map { _ in
            codeCharacters.randomElement()!
        })
    }

    /// Validate custom code or generate new one
    /// - Parameter customCode: Optional custom code
    /// - Returns: Valid code to use
    private func validateAndGenerateCode(customCode: String?) throws -> String {
        if let custom = customCode {
            // Validate custom code
            guard custom.count >= 3 && custom.count <= 20 else {
                throw ShortURLError.invalidCustomCode("Custom code must be 3-20 characters")
            }

            // Check if code is already in use
            let normalizedCode = custom.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }

            if loadMapping(code: normalizedCode) != nil {
                throw ShortURLError.codeAlreadyInUse
            }

            return normalizedCode
        } else {
            // Generate random code and ensure uniqueness
            var code = generateCode()
            var attempts = 0
            while loadMapping(code: code) != nil && attempts < 10 {
                code = generateCode()
                attempts += 1
            }
            return code
        }
    }

    // MARK: - QR Code Generation

    /// Generate a QR code image for a URL
    /// - Parameters:
    ///   - url: The URL to encode
    ///   - size: Size of the QR code image (default: 512x512)
    ///   - foregroundColor: QR code color (default: black)
    ///   - backgroundColor: Background color (default: white)
    /// - Returns: UIImage with QR code
    func generateQRCode(
        for url: URL,
        size: CGFloat = 512,
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white
    ) -> UIImage? {
        Log.debug("Generating QR code", category: .general, metadata: ["url": url.absoluteString])

        let data = url.absoluteString.data(using: .utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            Log.error("QR code generator not available", category: .general)
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let ciImage = filter.outputImage else {
            Log.error("Failed to generate QR code output", category: .general)
            return nil
        }

        // Apply color filters
        let coloredImage = applyColors(
            to: ciImage,
            foreground: foregroundColor,
            background: backgroundColor
        )

        // Scale up the image
        let scale = size / ciImage.extent.width
        let scaledImage = coloredImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Convert to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            Log.error("Failed to create CGImage from QR code", category: .general)
            return nil
        }

        let image = UIImage(cgImage: cgImage)

        // Track analytics
        trackQRCodeGenerated(url: url)

        Log.debug("QR code generated successfully", category: .general)

        return image
    }

    /// Generate QR code with app branding
    /// - Parameters:
    ///   - url: The URL to encode
    ///   - size: Size of the QR code image
    /// - Returns: Branded QR code with Heirloom colors
    func generateBrandedQRCode(for url: URL, size: CGFloat = 512) -> UIImage? {
        // Use Heirloom tomato color for the QR code
        // Note: This would use HeirloomColors.tomato in a real implementation
        let brandColor = UIColor(red: 0.898, green: 0.376, blue: 0.310, alpha: 1.0)
        let lightBackground = UIColor(red: 0.988, green: 0.953, blue: 0.941, alpha: 1.0)

        return generateQRCode(
            for: url,
            size: size,
            foregroundColor: brandColor,
            backgroundColor: lightBackground
        )
    }

    /// Apply colors to QR code using CIFilters
    private func applyColors(
        to image: CIImage,
        foreground: UIColor,
        background: UIColor
    ) -> CIImage {
        guard let colorFilter = CIFilter(name: "CIFalseColor") else {
            return image
        }

        colorFilter.setValue(image, forKey: "inputImage")
        colorFilter.setValue(CIColor(color: foreground), forKey: "inputColor0")
        colorFilter.setValue(CIColor(color: background), forKey: "inputColor1")

        return colorFilter.outputImage ?? image
    }

    // MARK: - Storage (Local)

    /// Save short code mapping to UserDefaults
    /// In production, this would be saved to your backend
    private func saveMapping(code: String, longURL: URL) {
        let key = "shortURL_\(code)"
        UserDefaults.standard.set(longURL.absoluteString, forKey: key)

        // Also save reverse mapping for lookup
        let reverseKey = "longURL_\(longURL.absoluteString.hash)"
        UserDefaults.standard.set(code, forKey: reverseKey)

        // Save creation date for expiration tracking
        let dateKey = "shortURL_date_\(code)"
        UserDefaults.standard.set(Date(), forKey: dateKey)
    }

    /// Load long URL from short code
    private func loadMapping(code: String) -> URL? {
        let key = "shortURL_\(code)"
        guard let urlString = UserDefaults.standard.string(forKey: key),
              let url = URL(string: urlString) else {
            return nil
        }

        // Check expiration (optional - could implement expiration logic here)
        // let dateKey = "shortURL_date_\(code)"
        // if let creationDate = UserDefaults.standard.object(forKey: dateKey) as? Date {
        //     // Check if expired
        // }

        return url
    }

    /// Find existing short code for a long URL
    func findExistingShortCode(for longURL: URL) -> String? {
        let reverseKey = "longURL_\(longURL.absoluteString.hash)"
        return UserDefaults.standard.string(forKey: reverseKey)
    }

    // MARK: - Validation

    /// Check if a short code is available
    func isCodeAvailable(_ code: String) -> Bool {
        return loadMapping(code: code) == nil
    }

    /// Validate URL format
    func isValidURL(_ url: URL) -> Bool {
        // Check if URL has scheme and host
        guard url.scheme != nil, url.host != nil else {
            return false
        }

        // Check if it's a CloudKit URL or our short URL domain
        let urlString = url.absoluteString
        return urlString.contains("icloud.com") || urlString.contains(baseDomain)
    }

    // MARK: - Analytics

    private func trackShortURLGenerated(code: String, longURL: URL) {
        analytics.track(event: .featureUsed, properties: [
            "feature": "short_url_generated",
            "code_length": code.count,
            "is_custom_code": code.count > codeLength,
            "original_length": longURL.absoluteString.count,
            "shortened_length": "https://\(baseDomain)\(recipePath)\(code)".count
        ])
    }

    private func trackQRCodeGenerated(url: URL) {
        analytics.track(event: .featureUsed, properties: [
            "feature": "qr_code_generated",
            "url_length": url.absoluteString.count,
            "is_short_url": url.absoluteString.contains(baseDomain)
        ])
    }
}

// MARK: - Error Types

extension ShortURLService {
    enum ShortURLError: LocalizedError {
        case invalidURL
        case invalidCustomCode(String)
        case codeAlreadyInUse
        case networkError(Error)
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL format"
            case .invalidCustomCode(let message):
                return message
            case .codeAlreadyInUse:
                return "This custom code is already in use. Please choose another."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .serverError(let message):
                return "Server error: \(message)"
            }
        }
    }
}

// MARK: - Convenience Methods

extension ShortURLService {
    /// Generate short URL and QR code together
    /// - Parameters:
    ///   - longURL: Original CloudKit share URL
    ///   - customCode: Optional custom code
    ///   - qrSize: Size for QR code (default: 512)
    /// - Returns: Tuple with short URL and QR code image
    func generateSharePackage(
        from longURL: URL,
        customCode: String? = nil,
        qrSize: CGFloat = 512
    ) async throws -> (shortURL: URL, qrCode: UIImage?) {
        // Check if we already have a short code for this URL
        if let existingCode = findExistingShortCode(for: longURL) {
            let shortURL = URL(string: "https://\(baseDomain)\(recipePath)\(existingCode)")!
            let qrCode = generateBrandedQRCode(for: shortURL, size: qrSize)
            return (shortURL, qrCode)
        }

        // Generate new short URL
        let shortURL = try await generateShortURL(from: longURL, customCode: customCode)

        // Generate QR code for short URL
        let qrCode = generateBrandedQRCode(for: shortURL, size: qrSize)

        return (shortURL, qrCode)
    }

    /// Create a shareable image with QR code and recipe info
    /// - Parameters:
    ///   - url: The URL to encode
    ///   - recipeTitle: Recipe name to display
    ///   - qrSize: Size of QR code
    /// - Returns: Composite image with QR code and text
    func generateShareableImage(
        url: URL,
        recipeTitle: String,
        qrSize: CGFloat = 512
    ) -> UIImage? {
        guard let qrImage = generateBrandedQRCode(for: url, size: qrSize) else {
            return nil
        }

        // Create composite image with QR code and text
        let padding: CGFloat = 40
        let textHeight: CGFloat = 100
        let totalHeight = qrSize + textHeight + (padding * 3)
        let size = CGSize(width: qrSize + (padding * 2), height: totalHeight)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw QR code
            qrImage.draw(in: CGRect(x: padding, y: padding, width: qrSize, height: qrSize))

            // Draw recipe title
            let titleY = qrSize + (padding * 2)
            let titleRect = CGRect(x: padding, y: titleY, width: qrSize, height: 50)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]

            recipeTitle.draw(in: titleRect, withAttributes: titleAttributes)

            // Draw instructions
            let instructionsY = titleY + 50
            let instructionsRect = CGRect(x: padding, y: instructionsY, width: qrSize, height: 50)

            let instructionsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: paragraphStyle
            ]

            "Scan to view recipe".draw(in: instructionsRect, withAttributes: instructionsAttributes)
        }

        return image
    }
}

// MARK: - Backend Integration

extension ShortURLService {
    /// Call the backend API to shorten a URL
    /// - Parameters:
    ///   - longURL: The full CloudKit share URL
    ///   - customCode: Optional custom code
    /// - Returns: Shortened URL data
    private func callBackendToShortenURL(longURL: URL, customCode: String?) async throws -> (code: String, shortURL: URL) {
        guard let endpoint = URL(string: apiEndpoint) else {
            throw ShortURLError.invalidURL
        }

        // 1. Prepare request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // 2. Create request body
        var body: [String: Any] = [
            "url": longURL.absoluteString
        ]

        if let customCode = customCode {
            body["customCode"] = customCode
        }

        // TODO: Add user ID and recipe ID when available
        // body["userId"] = currentUserID
        // body["recipeId"] = recipeID

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 3. Make request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShortURLError.networkError(NSError(domain: "ShortURL", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"]))
        }

        // 4. Check status code
        guard httpResponse.statusCode == 200 else {
            // Try to parse error message from response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                throw ShortURLError.serverError(errorMessage)
            }
            throw ShortURLError.serverError("HTTP \(httpResponse.statusCode)")
        }

        // 5. Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success == true,
              let shortURLString = json["shortUrl"] as? String,
              let code = json["code"] as? String,
              let shortURL = URL(string: shortURLString) else {
            throw ShortURLError.serverError("Invalid response format")
        }

        return (code: code, shortURL: shortURL)
    }
}
