//
//  PDFTextExtractor.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation
import PDFKit
import Vision
import UIKit

/// Extracts text from PDF pages for text-rich cookbook imports
/// Uses PDFKit's native text extraction (fast, free) with Vision OCR fallback
///
/// # Architecture
///
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │              Text Extraction Pipeline                        │
/// └─────────────────────────────────────────────────────────────┘
///
///  PDF URL
///     │
///     ▼
///  PDFTextExtractor.extractText()
///     │
///     │ For each page:
///     ├───► page.string (PDFKit native)
///     │          │
///     │          ├─ Has text? → Use it (fast, free)
///     │          │
///     │          └─ No text? → Vision OCR fallback
///     │                              │
///     │                              ▼
///     │                       Render to image
///     │                       VNRecognizeTextRequest
///     │                              │
///     ▼                              │
///  [ExtractedPage]  ◄────────────────┘
///     │
///     │ Contains:
///     │  - pageNumber: Int
///     │  - text: String
///     │  - extractionMethod: .native | .ocr
///     │  - charCount: Int
///     │
///     ▼
///  CookbookBatchAnalyzer (next step)
/// ```
///
/// # Cost Comparison
///
/// - **Native PDFKit**: Free, ~10ms per page
/// - **Vision OCR**: Free (on-device), ~200ms per page
/// - **Claude Vision API**: ~$0.01-0.02 per page
///
/// For a 100-page text-rich cookbook:
/// - Text extraction: FREE
/// - Claude Vision: ~$1.00-2.00
///
/// # Usage Example
///
/// ```swift
/// let extractor = PDFTextExtractor()
/// let pages = try await extractor.extractText(from: pdfURL)
///
/// for page in pages {
///     print("Page \(page.pageNumber): \(page.charCount) chars via \(page.extractionMethod)")
/// }
///
/// // Combine all text for batch analysis
/// let fullText = pages.map { $0.text }.joined(separator: "\n\n---PAGE BREAK---\n\n")
/// ```
@MainActor
final class PDFTextExtractor {

    // MARK: - Types

    enum ExtractionMethod: String {
        case native = "native"   // PDFKit page.string
        case ocr = "ocr"         // Vision framework OCR
        case failed = "failed"   // Could not extract
    }

    struct ExtractedPage {
        let pageNumber: Int
        let text: String
        let extractionMethod: ExtractionMethod
        let charCount: Int

        /// Whether this page has meaningful text content
        var hasContent: Bool {
            charCount >= 50  // Same threshold as PDFCostCalculator
        }
    }

    struct ExtractionResult {
        let pages: [ExtractedPage]
        let totalCharCount: Int
        let nativeCount: Int
        let ocrCount: Int
        let failedCount: Int

        /// Combined text from all pages with page break markers
        var fullText: String {
            pages.map { page in
                "--- PAGE \(page.pageNumber) ---\n\(page.text)"
            }.joined(separator: "\n\n")
        }

        /// Pages with actual content (>50 chars)
        var contentPages: [ExtractedPage] {
            pages.filter { $0.hasContent }
        }

        /// Whether most pages were extracted natively (good for text routing)
        var isTextRich: Bool {
            guard !pages.isEmpty else { return false }
            let nativeRatio = Double(nativeCount) / Double(pages.count)
            return nativeRatio >= 0.8
        }
    }

    // MARK: - Public API

    /// Extract text from all pages of a PDF
    /// - Parameters:
    ///   - pdfURL: URL to the PDF file
    ///   - useOCRFallback: Whether to use Vision OCR for pages without embedded text (default: true)
    /// - Returns: ExtractionResult with all pages and statistics
    func extractText(
        from pdfURL: URL,
        useOCRFallback: Bool = true
    ) async throws -> ExtractionResult {
        // Access security-scoped resource if needed
        let needsSecurityScope = pdfURL.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                pdfURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: pdfURL) else {
            throw PDFTextExtractionError.cannotOpenPDF(url: pdfURL)
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw PDFTextExtractionError.emptyPDF(url: pdfURL)
        }

        Log.info("Starting text extraction", category: .import, metadata: [
            "file": pdfURL.lastPathComponent,
            "pages": pageCount,
            "ocr_fallback": useOCRFallback
        ])

        var extractedPages: [ExtractedPage] = []
        var nativeCount = 0
        var ocrCount = 0
        var failedCount = 0
        var totalChars = 0

        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else {
                extractedPages.append(ExtractedPage(
                    pageNumber: pageIndex + 1,
                    text: "",
                    extractionMethod: .failed,
                    charCount: 0
                ))
                failedCount += 1
                continue
            }

            // Try native text extraction first
            if let nativeText = page.string, !nativeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = cleanExtractedText(nativeText)
                extractedPages.append(ExtractedPage(
                    pageNumber: pageIndex + 1,
                    text: cleaned,
                    extractionMethod: .native,
                    charCount: cleaned.count
                ))
                nativeCount += 1
                totalChars += cleaned.count
            } else if useOCRFallback {
                // Fall back to OCR
                let ocrText = await performOCR(on: page)
                let cleaned = cleanExtractedText(ocrText ?? "")
                extractedPages.append(ExtractedPage(
                    pageNumber: pageIndex + 1,
                    text: cleaned,
                    extractionMethod: cleaned.isEmpty ? .failed : .ocr,
                    charCount: cleaned.count
                ))
                if cleaned.isEmpty {
                    failedCount += 1
                } else {
                    ocrCount += 1
                    totalChars += cleaned.count
                }
            } else {
                // No OCR, mark as failed
                extractedPages.append(ExtractedPage(
                    pageNumber: pageIndex + 1,
                    text: "",
                    extractionMethod: .failed,
                    charCount: 0
                ))
                failedCount += 1
            }

            // Log progress for large PDFs
            if pageCount >= 20 && (pageIndex + 1) % 10 == 0 {
                Log.info("Text extraction progress", category: .import, metadata: [
                    "file": pdfURL.lastPathComponent,
                    "extracted": pageIndex + 1,
                    "total": pageCount
                ])
            }
        }

        Log.info("Text extraction complete", category: .import, metadata: [
            "file": pdfURL.lastPathComponent,
            "total_pages": pageCount,
            "native_pages": nativeCount,
            "ocr_pages": ocrCount,
            "failed_pages": failedCount,
            "total_chars": totalChars
        ])

        return ExtractionResult(
            pages: extractedPages,
            totalCharCount: totalChars,
            nativeCount: nativeCount,
            ocrCount: ocrCount,
            failedCount: failedCount
        )
    }

    /// Extract text from specific page range (for batched processing)
    /// - Parameters:
    ///   - pdfURL: URL to the PDF file
    ///   - pageRange: Range of pages to extract (0-indexed)
    ///   - useOCRFallback: Whether to use Vision OCR fallback
    /// - Returns: Array of ExtractedPage for the specified range
    func extractText(
        from pdfURL: URL,
        pageRange: Range<Int>,
        useOCRFallback: Bool = true
    ) async throws -> [ExtractedPage] {
        let needsSecurityScope = pdfURL.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                pdfURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: pdfURL) else {
            throw PDFTextExtractionError.cannotOpenPDF(url: pdfURL)
        }

        var extractedPages: [ExtractedPage] = []

        for pageIndex in pageRange {
            guard pageIndex < document.pageCount,
                  let page = document.page(at: pageIndex) else {
                continue
            }

            if let nativeText = page.string, !nativeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = cleanExtractedText(nativeText)
                extractedPages.append(ExtractedPage(
                    pageNumber: pageIndex + 1,
                    text: cleaned,
                    extractionMethod: .native,
                    charCount: cleaned.count
                ))
            } else if useOCRFallback {
                let ocrText = await performOCR(on: page)
                let cleaned = cleanExtractedText(ocrText ?? "")
                extractedPages.append(ExtractedPage(
                    pageNumber: pageIndex + 1,
                    text: cleaned,
                    extractionMethod: cleaned.isEmpty ? .failed : .ocr,
                    charCount: cleaned.count
                ))
            } else {
                extractedPages.append(ExtractedPage(
                    pageNumber: pageIndex + 1,
                    text: "",
                    extractionMethod: .failed,
                    charCount: 0
                ))
            }
        }

        return extractedPages
    }

    // MARK: - Private Helpers

    /// Perform OCR on a PDF page using Vision framework
    private func performOCR(on page: PDFPage) async -> String? {
        // Render page to image
        let pageBounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0  // 2x for better OCR accuracy
        let renderSize = CGSize(
            width: pageBounds.width * scale,
            height: pageBounds.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let pageImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: renderSize))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.translateBy(x: 0, y: pageBounds.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }

        guard let cgImage = pageImage.cgImage else { return nil }

        // Perform OCR using Vision
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text.isEmpty ? nil : text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                Log.warning("OCR failed for page: \(error.localizedDescription)", category: .import)
                continuation.resume(returning: nil)
            }
        }
    }

    /// Clean extracted text by normalizing whitespace and removing artifacts
    private func cleanExtractedText(_ text: String) -> String {
        var cleaned = text

        // Normalize line endings
        cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")

        // Remove excessive whitespace (more than 2 newlines)
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        // Trim leading/trailing whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}

// MARK: - Errors

enum PDFTextExtractionError: LocalizedError {
    case cannotOpenPDF(url: URL)
    case emptyPDF(url: URL)

    var errorDescription: String? {
        switch self {
        case .cannotOpenPDF(let url):
            return "Cannot open PDF: \(url.lastPathComponent)"
        case .emptyPDF(let url):
            return "PDF is empty: \(url.lastPathComponent)"
        }
    }
}
