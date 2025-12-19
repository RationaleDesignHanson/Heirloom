import XCTest
@testable import Heirloom

@MainActor
final class QRCodeServiceTests: XCTestCase {

    var service: QRCodeService!

    override func setUp() async throws {
        try await super.setUp()
        service = QRCodeService.shared
    }

    // MARK: - QR Code Generation Tests

    func test_generateQRCode_createsValidImage() {
        let url = URL(string: "heirloom://share/test123")!

        let qrImage = service.generateQRCode(from: url)

        XCTAssertNotNil(qrImage)
        XCTAssertGreaterThan(qrImage!.size.width, 0)
        XCTAssertGreaterThan(qrImage!.size.height, 0)
    }

    func test_generateQRCode_withCustomSize() {
        let url = URL(string: "heirloom://share/test456")!
        let customSize: CGFloat = 1024

        let qrImage = service.generateQRCode(from: url, size: customSize)

        XCTAssertNotNil(qrImage)
        // Note: Actual size may be slightly different due to scaling
        XCTAssertGreaterThan(qrImage!.size.width, customSize * 0.9)
    }

    func test_generateQRCode_withCustomColors() {
        let url = URL(string: "heirloom://share/test789")!

        let qrImage = service.generateQRCode(
            from: url,
            foregroundColor: .red,
            backgroundColor: .white
        )

        XCTAssertNotNil(qrImage)
    }

    func test_generateBrandedQRCode_includesBranding() {
        let url = URL(string: "heirloom://share/branded123")!

        let brandedImage = service.generateBrandedQRCode(from: url)

        XCTAssertNotNil(brandedImage)
        // Branded image should be taller (includes branding text)
        XCTAssertGreaterThan(brandedImage!.size.height, 600)
    }

    func test_generateBrandedQRCode_withCustomSize() {
        let url = URL(string: "heirloom://share/branded456")!
        let customSize: CGFloat = 800

        let brandedImage = service.generateBrandedQRCode(from: url, size: customSize)

        XCTAssertNotNil(brandedImage)
        XCTAssertGreaterThan(brandedImage!.size.width, customSize * 0.9)
    }

    // MARK: - URL Validation Tests

    func test_validateQRCodeData_validHeirloomURL() {
        let validURL = "heirloom://share/abc123"

        let result = service.validateQRCodeData(validURL)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.scheme, "heirloom")
        XCTAssertEqual(result?.host(), "share")
    }

    func test_validateQRCodeData_validHTTPSURL() {
        let validURL = "https://heirloom.app/share/abc123"

        let result = service.validateQRCodeData(validURL)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host(), "heirloom.app")
    }

    func test_validateQRCodeData_invalidURL() {
        let invalidURL = "not-a-valid-url"

        let result = service.validateQRCodeData(invalidURL)

        XCTAssertNil(result)
    }

    func test_validateQRCodeData_wrongScheme() {
        let wrongScheme = "http://example.com/share/abc123"

        let result = service.validateQRCodeData(wrongScheme)

        XCTAssertNil(result)
    }

    func test_validateQRCodeData_wrongHost() {
        let wrongHost = "https://nothere loom.app/share/abc123"

        let result = service.validateQRCodeData(wrongHost)

        XCTAssertNil(result)
    }

    func test_validateQRCodeData_missingSharePath() {
        let missingPath = "heirloom://other/abc123"

        let result = service.validateQRCodeData(missingPath)

        // Should be nil because path doesn't contain "share"
        XCTAssertNil(result)
    }

    // MARK: - Error Handling Tests

    func test_generateQRCode_handlesEmptyURL() {
        // URL with empty string should still generate QR
        let url = URL(string: "heirloom://share/")!

        let qrImage = service.generateQRCode(from: url)

        XCTAssertNotNil(qrImage)
    }

    func test_generateQRCode_handlesLongURL() {
        // Very long URL should still work
        let longID = String(repeating: "a", count: 200)
        let url = URL(string: "heirloom://share/\(longID)")!

        let qrImage = service.generateQRCode(from: url)

        XCTAssertNotNil(qrImage)
    }

    // MARK: - QR Code Format Tests

    func test_generateQRCode_usesHighErrorCorrection() {
        // High error correction means QR should still scan with partial damage
        // This is set in the code with "H" correction level
        let url = URL(string: "heirloom://share/test")!

        let qrImage = service.generateQRCode(from: url)

        XCTAssertNotNil(qrImage)
        // Can't directly test correction level, but verify image is generated
    }

    func test_generateQRCode_maintainsAspectRatio() {
        let url = URL(string: "heirloom://share/ratio")!
        let size: CGFloat = 512

        let qrImage = service.generateQRCode(from: url, size: size)

        XCTAssertNotNil(qrImage)
        // QR codes should be square
        let aspectRatio = qrImage!.size.width / qrImage!.size.height
        XCTAssertEqual(aspectRatio, 1.0, accuracy: 0.1)
    }

    // MARK: - Share URL Generation Tests

    func test_generateQRCode_forRecipeShare() {
        // Test typical recipe share URL format
        let shareID = "recipe-abc-123-def"
        let url = URL(string: "heirloom://share/\(shareID)")!

        let qrImage = service.generateQRCode(from: url)

        XCTAssertNotNil(qrImage)
    }

    func test_generateQRCode_forUniversalLink() {
        // Test universal link format
        let shareID = "recipe-abc-123"
        let url = URL(string: "https://heirloom.app/share/\(shareID)")!

        let qrImage = service.generateQRCode(from: url)

        XCTAssertNotNil(qrImage)
    }

    // MARK: - Integration Tests

    func test_generateAndValidate_roundTrip() {
        let originalURL = "heirloom://share/roundtrip123"
        let url = URL(string: originalURL)!

        // Generate QR code
        let qrImage = service.generateQRCode(from: url)
        XCTAssertNotNil(qrImage)

        // Validate the same URL
        let validatedURL = service.validateQRCodeData(originalURL)
        XCTAssertNotNil(validatedURL)
        XCTAssertEqual(validatedURL?.absoluteString, originalURL)
    }

    // MARK: - Performance Tests

    func test_qrGeneration_performance() {
        let url = URL(string: "heirloom://share/perf-test")!

        measure {
            _ = service.generateQRCode(from: url)
        }

        // QR generation should be fast (< 100ms)
    }

    func test_brandedQRGeneration_performance() {
        let url = URL(string: "heirloom://share/branded-perf")!

        measure {
            _ = service.generateBrandedQRCode(from: url)
        }

        // Branded QR should still be reasonably fast (< 200ms)
    }
}
