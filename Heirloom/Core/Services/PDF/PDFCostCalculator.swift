//
//  PDFCostCalculator.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation
import PDFKit

/// Calculates credit cost for PDFs BEFORE starting import
/// - Performs quick classification to determine text-rich vs scanned
/// - Returns cost breakdown and quota availability check
@MainActor
final class PDFCostCalculator {

    // MARK: - Types

    enum PDFContentType {
        case textRich    // >50 chars/page average
        case scanned     // <50 chars/page average
        case mixed       // Some pages text-rich, some scanned

        var creditCost: Int {
            switch self {
            case .textRich:
                return UserCredits.PDFCreditCost.textRich.rawValue
            case .scanned:
                return UserCredits.PDFCreditCost.scanned.rawValue
            case .mixed:
                return UserCredits.PDFCreditCost.mixed.rawValue
            }
        }

        var displayName: String {
            switch self {
            case .textRich: return "Text-rich PDF"
            case .scanned: return "Scanned PDF"
            case .mixed: return "Mixed PDF"
            }
        }
    }

    struct CostBreakdown {
        let totalCredits: Int
        let textRichCount: Int
        let scannedCount: Int
        let mixedCount: Int
        let classifications: [URL: PDFContentType]
        let canAfford: Bool
        let needsCredits: Int  // How many credits short

        var hasTextRich: Bool { textRichCount > 0 }
        var hasScanned: Bool { scannedCount > 0 }
        var hasMixed: Bool { mixedCount > 0 }
    }

    // MARK: - Constants

    /// Minimum characters per page to be considered "text-rich"
    private static let textRichThreshold = 50

    /// Number of pages to sample for quick classification (faster than analyzing all pages)
    private static let sampleSize = 10

    // MARK: - Public Methods

    /// Calculate cost for PDFs BEFORE starting import
    /// - Parameters:
    ///   - pdfURLs: URLs of PDFs to analyze
    ///   - userCredits: User's current credit balance
    /// - Returns: Cost breakdown with affordability check
    func calculateCost(
        for pdfURLs: [URL],
        userCredits: UserCredits
    ) async throws -> CostBreakdown {

        var totalCredits = 0
        var textRich = 0
        var scanned = 0
        var mixed = 0
        var classifications: [URL: PDFContentType] = [:]

        Log.info("Calculating cost for \(pdfURLs.count) PDFs", category: .general)

        for url in pdfURLs {
            // Quick classification (samples first N pages)
            let contentType = try classifyPDF(at: url)
            classifications[url] = contentType

            totalCredits += contentType.creditCost

            switch contentType {
            case .textRich:
                textRich += 1
            case .scanned:
                scanned += 1
            case .mixed:
                mixed += 1
            }

            Log.debug("PDF classified", category: .general, metadata: [
                "url": url.lastPathComponent,
                "type": contentType.displayName,
                "cost": contentType.creditCost
            ])
        }

        let available = userCredits.availableToday
        let canAfford = totalCredits <= available
        let needsCredits = max(0, totalCredits - available)

        Log.info("Cost calculation complete", category: .general, metadata: [
            "totalCredits": totalCredits,
            "textRich": textRich,
            "scanned": scanned,
            "mixed": mixed,
            "available": available,
            "canAfford": canAfford
        ])

        return CostBreakdown(
            totalCredits: totalCredits,
            textRichCount: textRich,
            scannedCount: scanned,
            mixedCount: mixed,
            classifications: classifications,
            canAfford: canAfford,
            needsCredits: needsCredits
        )
    }

    // MARK: - Private Methods

    /// Classify a single PDF by sampling pages
    /// - Parameter url: URL of the PDF
    /// - Returns: Classification (text-rich, scanned, or mixed)
    private func classifyPDF(at url: URL) throws -> PDFContentType {
        guard let document = PDFDocument(url: url) else {
            throw PDFCostError.cannotOpenPDF(url: url)
        }

        let totalPages = document.pageCount
        guard totalPages > 0 else {
            throw PDFCostError.emptyPDF(url: url)
        }

        // Sample up to N pages (or all if fewer)
        let pagesToSample = min(totalPages, Self.sampleSize)
        var textRichPages = 0
        var scannedPages = 0

        // Sample evenly distributed pages (first, middle, last, etc.)
        let sampleIndices = calculateSampleIndices(totalPages: totalPages, sampleSize: pagesToSample)

        for pageIndex in sampleIndices {
            guard let page = document.page(at: pageIndex) else { continue }

            let text = page.string ?? ""
            let charCount = text.count

            if charCount >= Self.textRichThreshold {
                textRichPages += 1
            } else {
                scannedPages += 1
            }
        }

        // Classify based on ratio
        let textRichRatio = Double(textRichPages) / Double(pagesToSample)

        if textRichRatio >= 0.8 {
            // 80%+ pages are text-rich → text-rich PDF
            return .textRich
        } else if textRichRatio <= 0.2 {
            // 80%+ pages are scanned → scanned PDF
            return .scanned
        } else {
            // Mixed content
            return .mixed
        }
    }

    /// Calculate evenly distributed sample indices
    /// - Parameters:
    ///   - totalPages: Total number of pages
    ///   - sampleSize: Number of pages to sample
    /// - Returns: Array of page indices to sample
    private func calculateSampleIndices(totalPages: Int, sampleSize: Int) -> [Int] {
        guard totalPages > sampleSize else {
            // Sample all pages if fewer than sample size
            return Array(0..<totalPages)
        }

        // Evenly distribute samples across the document
        let stride = Double(totalPages) / Double(sampleSize)

        return (0..<sampleSize).map { i in
            Int(floor(stride * Double(i)))
        }
    }
}

// MARK: - Errors

enum PDFCostError: LocalizedError {
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
