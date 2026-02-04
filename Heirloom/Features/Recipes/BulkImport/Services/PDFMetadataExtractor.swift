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

        // FIRST: Check PDF document attributes (embedded metadata) - most reliable
        if let attributes = pdfDocument.documentAttributes {
            let embeddedTitle = attributes[PDFDocumentAttribute.titleAttribute] as? String
            let embeddedAuthor = attributes[PDFDocumentAttribute.authorAttribute] as? String

            // Use embedded metadata if available and looks valid
            if let title = embeddedTitle, !title.isEmpty, title.count > 3, title.count < 100 {
                Log.info("Found embedded PDF metadata", category: .import, metadata: [
                    "title": title,
                    "author": embeddedAuthor ?? "nil"
                ])
                return CookbookMetadata(title: title, author: embeddedAuthor)
            }
        }

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

        // Pattern 2: Look for "Author:", "Written by:", "Compiled by:", "Edited by:" labels
        if author == nil {
            for line in lines {
                let lowercased = line.lowercased()

                // Check for various author attribution patterns
                let authorPatterns = [
                    "author:",
                    "written by:",
                    "compiled by:",
                    "edited by:",
                    "compiled and edited by:",
                    "original text compiled and edited by:",
                    "created by:",
                    "developed by:"
                ]

                for pattern in authorPatterns {
                    if lowercased.contains(pattern) {
                        author = line.replacingOccurrences(of: pattern, with: "", options: [.caseInsensitive])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        Log.debug("Found author via pattern", category: .import, metadata: [
                            "pattern": pattern,
                            "author": author ?? "nil"
                        ])
                        break
                    }
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

                    // Skip obvious recipe section headers
                    let recipeHeaders = ["ingredients", "directions", "instructions", "preparation",
                                        "method", "serves", "servings", "yield", "cook time",
                                        "prep time", "total time", "qty", "quantity", "amount",
                                        "notes", "tips", "variations"]
                    let containsOnlyHeaders = recipeHeaders.contains { header in
                        let headerPattern = "\\b\(header)\\b"
                        return lowercased.range(of: headerPattern, options: [.regularExpression, .caseInsensitive]) != nil
                    }
                    let isHeaderList = lowercased.split(separator: ":").count > 2 // Multiple colons suggests header list
                    if containsOnlyHeaders || isHeaderList {
                        Log.debug("Skipping recipe header/list", category: .import, metadata: ["line": line])
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

                    // Check if this looks like an author name (has professional credentials)
                    // Patterns: "Name, RD, MPA", "Name, PhD", "Name, MD", etc.
                    let credentialPatterns = [
                        "\\b(RD|MPA|PhD|MD|MS|MA|MBA|JD|DO|RN|LPN|CPA|LCSW|LPC|CNS|CNP)\\b",  // Common credentials
                        "\\b(Dr\\.|Prof\\.|Chef)\\s",  // Titles
                        "\\bby\\s+\\w",  // "by Name"
                        "compiled.*by",  // "compiled by", "compiled and edited by"
                        "edited.*by",
                        "written.*by"
                    ]
                    let looksLikeAuthor = credentialPatterns.contains { pattern in
                        line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
                    }
                    if looksLikeAuthor {
                        // This is likely an author, not a title - extract as author if we don't have one
                        if author == nil {
                            // Extract name (remove "by", credentials, etc.)
                            var extractedAuthor = line
                            if let byRange = extractedAuthor.range(of: "by\\s+", options: [.regularExpression, .caseInsensitive]) {
                                extractedAuthor = String(extractedAuthor[byRange.upperBound...])
                            }
                            author = extractedAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
                            Log.debug("Extracted author from credential pattern", category: .import, metadata: ["author": author ?? "nil"])
                        }
                        continue // Skip this line as a title candidate
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

        // Final validation: Reject title if it looks like a recipe header
        if let currentTitle = title {
            let lowercased = currentTitle.lowercased()
            let suspiciousPatterns = ["ingredients:", "directions:", "qty:", "amount:", "cook time:", "prep time:"]
            if suspiciousPatterns.contains(where: { lowercased.contains($0) }) {
                Log.warning("Rejecting suspicious title that looks like recipe header", category: .import, metadata: ["rejected_title": currentTitle])
                title = nil
            }
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
