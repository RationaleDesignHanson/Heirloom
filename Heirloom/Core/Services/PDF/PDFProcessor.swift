import PDFKit
import UIKit

/// Handles PDF rendering and processing for recipe import
/// - Renders PDF pages to images for OCR/Vision processing
/// - Validates page counts and enforces limits
/// - Memory-efficient streaming for large PDFs
///
/// # Architecture
///
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │                   PDF Processing Pipeline                    │
/// └─────────────────────────────────────────────────────────────┘
///
///    iOS Files App
///         │
///         │ (1) User selects PDF
///         ▼
///  PDFDocumentPicker ──────┐
///         │                │ (2) Returns security-scoped URL
///         │                │
///         ▼                │
///  PDFProcessor.validatePDF()  ◄───┘
///         │
///         │ (3) Check page count, premium status, password
///         ├─────► [Success(pageCount)]
///         ├─────► [RequiresPremium(fileName, pageCount)]
///         └─────► [Failure(error)]
///
///  PDFProcessor.renderPDFPages()
///         │
///         │ (4) Load PDFDocument with security scope
///         │ (5) Iterate pages 0..<pageCount
///         │ (6) Render each page at 2x scale
///         │
///         ▼
///  [(pageNumber: Int, image: UIImage)]
///         │
///         │ (7) Pass to MultiPageRecipeAnalyzer
///         ▼
///  [RecipePageGroup]
///         │
///         │ (8) Create ImportJob with grouped recipes
///         ▼
///  ImportJobManager.startJob()
/// ```
///
/// # Premium Gates
///
/// - **Free Tier**: Up to 50 pages per PDF
/// - **Premium ($4.99)**: Up to 250 pages per PDF
/// - **Hard Cap**: 250 pages maximum (even for premium)
///
/// # Rendering Configuration
///
/// - **Scale**: 2x (renderScale = 2.0) for retina/OCR quality
/// - **Compression**: 0.9 JPEG quality
/// - **Memory**: Pages rendered on-demand, not cached
/// - **Background**: White background for consistent OCR
///
/// # Usage Example
///
/// ```swift
/// // Validate PDF before processing
/// let result = await pdfProcessor.validatePDF(pdfURL)
///
/// switch result {
/// case .success(let pageCount):
///     print("Valid PDF with \(pageCount) pages")
///
///     // Render all pages
///     let pages = try await pdfProcessor.renderPDFPages(from: pdfURL)
///     // pages = [(1, UIImage), (2, UIImage), ...]
///
/// case .requiresPremium(let fileName, let pageCount):
///     // Show paywall for 50+ pages
///     paywallManager.show(.largePDFImport(pageCount: pageCount))
///
/// case .failure(let error):
///     // Handle error (corrupted, password-protected, too large)
///     print("Error: \(error.localizedDescription)")
/// }
/// ```
@MainActor
final class PDFProcessor {

    // MARK: - Configuration
    private let renderScale: CGFloat = 2.0  // 2x for retina/OCR quality
    private let compressionQuality: CGFloat = 0.9
    private let hardPageLimit = 250  // Hard cap for all users
    private let premiumPageThreshold = 50  // Requires premium

    // MARK: - Dependencies
    private let subscriptionManager: SubscriptionManager
    private let analytics: AnalyticsService

    init(subscriptionManager: SubscriptionManager, analytics: AnalyticsService) {
        self.subscriptionManager = subscriptionManager
        self.analytics = analytics
    }

    // MARK: - Public API

    /// Render all pages of a PDF to images for processing
    /// - Parameter url: URL to PDF file (from document picker)
    /// - Returns: Array of (pageNumber, image) tuples
    /// - Throws: PDFError for various failure modes
    func renderPDFPages(from url: URL) async throws -> [(pageNumber: Int, image: UIImage)] {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            Log.warning("Failed to access security-scoped PDF", category: .import, metadata: [
                "file": url.lastPathComponent
            ])
            throw PDFImportError.unreadable(fileName: url.lastPathComponent)
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Load PDF document
        guard let document = PDFDocument(url: url) else {
            Log.warning("Could not load PDF document", category: .import, metadata: [
                "file": url.lastPathComponent
            ])
            throw PDFImportError.unreadable(fileName: url.lastPathComponent)
        }

        // Check if password protected
        if document.isLocked {
            Log.warning("PDF is password protected", category: .import, metadata: [
                "file": url.lastPathComponent
            ])
            throw PDFImportError.passwordProtected(fileName: url.lastPathComponent)
        }

        let pageCount = document.pageCount

        // Enforce hard page limit (250 pages)
        if pageCount > hardPageLimit {
            Log.warning("PDF exceeds hard page limit", category: .import, metadata: [
                "file": url.lastPathComponent,
                "pages": pageCount,
                "limit": hardPageLimit
            ])
            throw PDFImportError.tooManyPages(
                fileName: url.lastPathComponent,
                pageCount: pageCount,
                max: hardPageLimit
            )
        }

        // Check premium gate for 50+ pages
        if pageCount >= premiumPageThreshold {
            let isPremium = subscriptionManager.isPremium

            if !isPremium {
                Log.info("Premium required for PDF with 50+ pages", category: .import, metadata: [
                    "file": url.lastPathComponent,
                    "pages": pageCount
                ])
                throw PDFImportError.requiresPremium(
                    fileName: url.lastPathComponent,
                    pageCount: pageCount
                )
            }
        }

        Log.info("Starting PDF rendering", category: .import, metadata: [
            "file": url.lastPathComponent,
            "pages": pageCount
        ])

        // Render each page
        var pages: [(Int, UIImage)] = []

        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else {
                Log.warning("Could not load PDF page", category: .import, metadata: [
                    "file": url.lastPathComponent,
                    "page": pageIndex + 1
                ])
                continue
            }

            // Render page to image
            let image = renderPage(page, scale: renderScale)
            pages.append((pageIndex + 1, image))  // 1-indexed page numbers

            // Log progress for large PDFs
            if pageCount >= 20 && (pageIndex + 1) % 10 == 0 {
                Log.info("PDF rendering progress", category: .import, metadata: [
                    "file": url.lastPathComponent,
                    "rendered": pageIndex + 1,
                    "total": pageCount
                ])
            }
        }

        Log.info("PDF rendering complete", category: .import, metadata: [
            "file": url.lastPathComponent,
            "pages_rendered": pages.count
        ])

        return pages
    }

    /// Get page count without rendering (for quick validation)
    /// - Parameter url: URL to PDF file
    /// - Returns: Page count or nil if unreadable
    func getPageCount(_ url: URL) -> Int? {
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: url) else {
            return nil
        }

        // Skip locked PDFs
        if document.isLocked {
            return nil
        }

        return document.pageCount
    }

    /// Check if PDF meets page requirements (not locked, within limits)
    /// - Parameter url: URL to PDF file
    /// - Returns: Validation result with page count or error
    func validatePDF(_ url: URL) async -> PDFValidationResult {
        guard url.startAccessingSecurityScopedResource() else {
            let error = PDFImportError.unreadable(fileName: url.lastPathComponent)

            // Track analytics: PDF validation failed
            analytics.track(event: AnalyticsEvent.pdfValidationFailed, properties: [
                "file_name": url.lastPathComponent,
                "error_type": "unreadable",
                "error": error.localizedDescription
            ])

            return .failure(error)
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: url) else {
            let error = PDFImportError.unreadable(fileName: url.lastPathComponent)

            // Track analytics: PDF validation failed
            analytics.track(event: AnalyticsEvent.pdfValidationFailed, properties: [
                "file_name": url.lastPathComponent,
                "error_type": "unreadable",
                "error": error.localizedDescription
            ])

            return .failure(error)
        }

        if document.isLocked {
            let error = PDFImportError.passwordProtected(fileName: url.lastPathComponent)

            // Track analytics: PDF validation failed
            analytics.track(event: AnalyticsEvent.pdfValidationFailed, properties: [
                "file_name": url.lastPathComponent,
                "error_type": "password_protected",
                "error": error.localizedDescription
            ])

            return .failure(error)
        }

        let pageCount = document.pageCount

        if pageCount > hardPageLimit {
            let error = PDFImportError.tooManyPages(
                fileName: url.lastPathComponent,
                pageCount: pageCount,
                max: hardPageLimit
            )

            // Track analytics: PDF validation failed
            analytics.track(event: AnalyticsEvent.pdfValidationFailed, properties: [
                "file_name": url.lastPathComponent,
                "error_type": "too_many_pages",
                "page_count": pageCount,
                "limit": hardPageLimit,
                "error": error.localizedDescription
            ])

            return .failure(error)
        }

        // Check premium requirement
        if pageCount >= premiumPageThreshold {
            let isPremium = subscriptionManager.isPremium

            if !isPremium {
                return .requiresPremium(
                    fileName: url.lastPathComponent,
                    pageCount: pageCount
                )
            }
        }

        return .success(pageCount: pageCount)
    }

    // MARK: - Private Helpers

    /// Render a single PDF page to UIImage
    /// - Parameters:
    ///   - page: PDFPage to render
    ///   - scale: Scaling factor (2.0 = 2x for retina)
    /// - Returns: Rendered UIImage
    private func renderPage(_ page: PDFPage, scale: CGFloat) -> UIImage {
        let pageRect = page.bounds(for: .mediaBox)

        // Calculate render size (scale for retina/OCR quality)
        let renderSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: renderSize)

        let image = renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            // Scale and render PDF
            context.cgContext.scaleBy(x: scale, y: scale)
            context.cgContext.translateBy(x: 0, y: pageRect.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        return image
    }
}

// MARK: - Validation Result

enum PDFValidationResult {
    case success(pageCount: Int)
    case requiresPremium(fileName: String, pageCount: Int)
    case failure(PDFImportError)

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var pageCount: Int? {
        switch self {
        case .success(let count), .requiresPremium(_, let count):
            return count
        case .failure:
            return nil
        }
    }

    var error: PDFImportError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
