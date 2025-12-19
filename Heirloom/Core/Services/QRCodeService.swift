import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

/// Service for generating and managing QR codes for recipe sharing
@MainActor
final class QRCodeService {

    // MARK: - Singleton

    static let shared = QRCodeService()

    private init() {}

    // MARK: - QR Code Generation

    /// Generate QR code image from share URL
    /// - Parameters:
    ///   - url: The share URL to encode
    ///   - size: The desired size of the QR code (default: 512x512)
    ///   - foregroundColor: QR code foreground color (default: black)
    ///   - backgroundColor: QR code background color (default: white)
    /// - Returns: UIImage of the QR code, or nil if generation fails
    func generateQRCode(
        from url: URL,
        size: CGFloat = 512,
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white
    ) -> UIImage? {
        let data = url.absoluteString.data(using: .utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            print("❌ Failed to create QR code filter")
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let ciImage = filter.outputImage else {
            print("❌ Failed to generate QR code CIImage")
            return nil
        }

        // Scale up the QR code to desired size
        let scaleX = size / ciImage.extent.size.width
        let scaleY = size / ciImage.extent.size.height
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Apply colors
        let coloredImage = applyColors(
            to: scaledImage,
            foreground: foregroundColor,
            background: backgroundColor
        )

        // Convert to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(coloredImage, from: coloredImage.extent) else {
            print("❌ Failed to create CGImage from CIImage")
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Generate QR code with app branding
    /// - Parameters:
    ///   - url: The share URL to encode
    ///   - size: The desired size of the QR code
    /// - Returns: UIImage with QR code and Heirloom branding
    func generateBrandedQRCode(
        from url: URL,
        size: CGFloat = 600
    ) -> UIImage? {
        // Generate base QR code
        guard let qrImage = generateQRCode(
            from: url,
            size: size * 0.8, // Leave room for branding
            foregroundColor: UIColor(HeirloomColors.charcoal),
            backgroundColor: .white
        ) else {
            return nil
        }

        // Create canvas for branded version
        let canvasSize = CGSize(width: size, height: size + 80)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            let cgContext = context.cgContext

            // Background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: canvasSize))

            // QR Code
            let qrRect = CGRect(
                x: (size - qrImage.size.width) / 2,
                y: 20,
                width: qrImage.size.width,
                height: qrImage.size.height
            )
            qrImage.draw(in: qrRect)

            // Branding text
            let brandingText = "Scan to import recipe"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: UIColor(HeirloomColors.charcoal)
            ]
            let textSize = brandingText.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size - textSize.width) / 2,
                y: qrRect.maxY + 15,
                width: textSize.width,
                height: textSize.height
            )
            brandingText.draw(in: textRect, withAttributes: attributes)
        }
    }

    // MARK: - QR Code Customization

    /// Apply custom colors to QR code
    private func applyColors(
        to image: CIImage,
        foreground: UIColor,
        background: UIColor
    ) -> CIImage {
        guard let colorFilter = CIFilter(name: "CIFalseColor") else {
            return image
        }

        colorFilter.setValue(image, forKey: kCIInputImageKey)
        colorFilter.setValue(CIColor(color: foreground), forKey: "inputColor0")
        colorFilter.setValue(CIColor(color: background), forKey: "inputColor1")

        return colorFilter.outputImage ?? image
    }

    // MARK: - Save QR Code

    /// Save QR code image to Photos library
    /// - Parameter image: The QR code image to save
    /// - Returns: Success or failure
    func saveQRCodeToPhotos(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { continuation in
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            continuation.resume()
        }
    }

    /// Generate and save QR code in one operation
    /// - Parameter url: The share URL to encode
    /// - Returns: The generated image
    func generateAndSaveQRCode(from url: URL) async throws -> UIImage {
        guard let qrImage = generateBrandedQRCode(from: url) else {
            throw QRCodeError.generationFailed
        }

        try await saveQRCodeToPhotos(qrImage)
        return qrImage
    }

    // MARK: - QR Code Scanning

    /// Validate and extract URL from QR code data
    /// - Parameter data: The scanned QR code data
    /// - Returns: Validated share URL, or nil if invalid
    func validateQRCodeData(_ data: String) -> URL? {
        // Check if it's a valid Heirloom share URL
        guard let url = URL(string: data) else {
            return nil
        }

        // Validate it's a Heirloom share URL
        if url.scheme == "heirloom" && url.host() == "share" {
            return url
        }

        // Also support https://heirloom.app/share/{id}
        if url.host() == "heirloom.app" && url.pathComponents.contains("share") {
            return url
        }

        return nil
    }
}

// MARK: - Errors

enum QRCodeError: LocalizedError {
    case generationFailed
    case saveFailed(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate QR code"
        case .saveFailed(let error):
            return "Failed to save QR code: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid share URL"
        }
    }
}

// MARK: - QR Code History

/// Track QR code generation history for analytics
struct QRCodeShareRecord: Codable {
    let shareID: String
    let recipeTitle: String
    let generatedAt: Date
    let scannedCount: Int

    var id: String { shareID }
}
