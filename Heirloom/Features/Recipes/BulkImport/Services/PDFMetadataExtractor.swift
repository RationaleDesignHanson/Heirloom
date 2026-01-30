//
//  PDFMetadataExtractor.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-16.
//

import Foundation
import PDFKit
import Vision
import UIKit

/// Extracts cookbook metadata (title, author) from PDF front matter
/// Scans first 5-10 pages looking for title page, copyright page, etc.
@MainActor
class PDFMetadataExtractor {

    // MARK: - Public API

    /// Extract cookbook metadata from a PDF file
    /// - Parameter pdfURL: URL to the PDF file
    /// - Returns: CookbookMetadata if found, nil otherwise
    func extractMetadata(from pdfURL: URL) async -> CookbookMetadata? {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            Log.warning("Failed to open PDF for metadata extraction", category: .import)
            return nil
        }

        return await extractMetadata(from: pdfDocument)
    }

    /// Extract cookbook metadata from a PDFDocument
    /// - Parameter pdfDocument: The PDF document to scan
    /// - Returns: CookbookMetadata if found, nil otherwise
    func extractMetadata(from pdfDocument: PDFDocument) async -> CookbookMetadata? {
        let pageCount = pdfDocument.pageCount
        let pagesToScan = min(10, pageCount) // Scan first 10 pages max

        Log.info("Scanning PDF for cookbook metadata", category: .import, metadata: [
            "pages_to_scan": pagesToScan,
            "total_pages": pageCount
        ])

        var allText = ""

        // Extract text from first pages
        for pageIndex in 0..<pagesToScan {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            // Try built-in PDF text extraction first (faster)
            if let pageText = page.string {
                allText += pageText + "\n\n"
            } else {
                // Fall back to OCR if no embedded text
                if let ocrText = await performOCR(on: page) {
                    allText += ocrText + "\n\n"
                }
            }
        }

        // Parse metadata from extracted text
        return parseMetadata(from: allText)
    }

    // MARK: - OCR

    /// Perform OCR on a PDF page using Vision framework
    private func performOCR(on page: PDFPage) async -> String? {
        // Render page to image
        let pageBounds = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
        let pageImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pageBounds.size))
            ctx.cgContext.translateBy(x: 0, y: pageBounds.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }

        guard let cgImage = pageImage.cgImage else { return nil }

        // Perform OCR
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let observations = request.results else { return nil }

        // Combine all recognized text
        let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        return text.isEmpty ? nil : text
    }

    // MARK: - Metadata Parsing

    /// Parse cookbook metadata from extracted text
    private func parseMetadata(from text: String) -> CookbookMetadata? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var title: String?
        var author: String?

        // Pattern 1: Look for "by [Author]" pattern (common on title pages)
        for (index, line) in lines.enumerated() {
            if line.lowercased().hasPrefix("by ") {
                author = line.replacingOccurrences(of: "by ", with: "", options: [.caseInsensitive, .anchored])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Title is likely the previous non-empty line
                if index > 0 {
                    title = lines[index - 1]
                }
                break
            }
        }

        // Pattern 2: Look for "Author:" or "Written by:" labels
        if author == nil {
            for line in lines {
                if line.lowercased().contains("author:") {
                    author = line.replacingOccurrences(of: "author:", with: "", options: [.caseInsensitive])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.lowercased().contains("written by:") {
                    author = line.replacingOccurrences(of: "written by:", with: "", options: [.caseInsensitive])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

                if author != nil { break }
            }
        }

        // Pattern 3: Title is often the largest/first text on early pages
        // If we found author but not title, use first substantial line as title
        if title == nil && author != nil {
            title = lines.first { $0.count > 5 && !$0.contains("©") && !$0.lowercased().contains("copyright") }
        }

        // Pattern 4: If no "by" pattern, check for large text blocks that might be title
        if title == nil {
            // Look for lines that are likely titles (all caps, or substantial length)
            // Score each candidate and pick the best one
            var bestCandidate: (line: String, score: Int)?

            for line in lines.prefix(20) { // Check first 20 lines
                if line.count > 10 && line.count < 100 {
                    // Skip copyright lines, ISBNs, publisher info
                    let lowercased = line.lowercased()
                    if lowercased.contains("copyright") ||
                       lowercased.contains("isbn") ||
                       lowercased.contains("published") ||
                       lowercased.contains("all rights reserved") ||
                       lowercased.contains("edition") ||
                       lowercased.contains("printing") {
                        continue
                    }

                    // Skip obvious taglines (repetitive patterns like "Cook Together Eat Together")
                    let words = line.split(separator: " ")
                    let uniqueWords = Set(words.map { $0.lowercased() })
                    let repetitionRatio = Double(words.count) / Double(uniqueWords.count)
                    if repetitionRatio > 1.5 { // High repetition suggests tagline
                        Log.debug("Skipping potential tagline (repetitive)", category: .import, metadata: ["line": line])
                        continue
                    }

                    // Score this candidate
                    var score = 0

                    // Prefer shorter text (titles are usually concise)
                    if line.count < 40 { score += 3 }
                    else if line.count < 60 { score += 2 }
                    else { score += 1 }

                    // Prefer title case formatting
                    let titleCaseWords = words.filter { word in
                        guard let first = word.first else { return false }
                        return first.isUppercase && word.count > 2
                    }
                    if Double(titleCaseWords.count) / Double(words.count) > 0.5 {
                        score += 2 // More than half the words are title-cased
                    }

                    // Prefer text without too many common words
                    let commonWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for"])
                    let commonWordCount = words.filter { commonWords.contains($0.lowercased()) }.count
                    if Double(commonWordCount) / Double(words.count) < 0.3 {
                        score += 2 // Low common word ratio suggests title-like text
                    }

                    // Prefer all-caps (common for titles)
                    if line.uppercased() == line && line.lowercased() != line {
                        score += 3
                    }

                    // Update best candidate if this scores higher
                    if bestCandidate == nil || score > bestCandidate!.score {
                        bestCandidate = (line, score)
                    }
                }
            }

            // Use the best candidate if we found one
            if let best = bestCandidate {
                title = best.line
                Log.debug("Selected title candidate", category: .import, metadata: [
                    "title": best.line,
                    "score": best.score
                ])
            }
        }

        // Clean up extracted values
        if let cleanTitle = title?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)),
           !cleanTitle.isEmpty {
            title = cleanTitle
        }

        if let cleanAuthor = author?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)),
           !cleanAuthor.isEmpty {
            author = cleanAuthor
        }

        // Return metadata if we found at least one field
        if title != nil || author != nil {
            Log.info("Extracted cookbook metadata", category: .import, metadata: [
                "title": title ?? "nil",
                "author": author ?? "nil"
            ])

            return CookbookMetadata(title: title, author: author)
        }

        Log.debug("No cookbook metadata found in PDF", category: .import)
        return nil
    }
}

// MARK: - CookbookMetadata

/// Metadata extracted from a cookbook PDF
struct CookbookMetadata {
    let title: String?
    let author: String?

    /// Format as attribution string for display
    var attributionString: String? {
        switch (title, author) {
        case let (title?, author?):
            return "\(title) by \(author)"
        case let (title?, nil):
            return title
        case let (nil, author?):
            return "by \(author)"
        case (nil, nil):
            return nil
        }
    }
}
