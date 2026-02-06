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
/// Uses multi-source extraction with confidence scoring:
/// 1. Embedded PDF metadata (most reliable)
/// 2. Filename parsing (fast, often accurate)
/// 3. Text extraction + pattern matching (fallback)
/// 4. AI Vision (expensive but accurate tiebreaker)
@MainActor
class PDFMetadataExtractor {

    // MARK: - Dependencies

    private var aiService: (any AIServiceProtocol)? {
        ServiceContainer.shared.resolveOptional((any AIServiceProtocol).self)
    }

    // MARK: - Confidence Tracking

    /// Represents metadata extracted from a specific source
    private struct MetadataCandidate {
        let title: String?
        let author: String?
        let source: MetadataSource
        let confidence: Double // 0.0 to 1.0

        enum MetadataSource: String {
            case embedded = "embedded"
            case filename = "filename"
            case textParsing = "text_parsing"
            case aiVision = "ai_vision"
        }
    }

    // MARK: - Public API

    /// Extract cookbook metadata from a PDF file
    /// - Parameters:
    ///   - pdfURL: URL to the PDF file
    ///   - useVisionFallback: Whether to use AI vision if other methods disagree (default: true)
    /// - Returns: CookbookMetadata if found, nil otherwise
    func extractMetadata(from pdfURL: URL, useVisionFallback: Bool = true) async -> CookbookMetadata? {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            Log.warning("Failed to open PDF for metadata extraction", category: .import)
            return nil
        }

        return await extractMetadata(from: pdfDocument, pdfURL: pdfURL, useVisionFallback: useVisionFallback)
    }

    /// Extract cookbook metadata from a PDFDocument
    /// - Parameters:
    ///   - pdfDocument: The PDF document to scan
    ///   - pdfURL: Optional URL for filename-based extraction
    ///   - useVisionFallback: Whether to use AI vision if other methods disagree
    /// - Returns: CookbookMetadata if found, nil otherwise
    func extractMetadata(from pdfDocument: PDFDocument, pdfURL: URL? = nil, useVisionFallback: Bool = true) async -> CookbookMetadata? {
        let pageCount = pdfDocument.pageCount

        Log.info("Starting multi-source metadata extraction", category: .import, metadata: [
            "total_pages": pageCount,
            "has_url": pdfURL != nil,
            "use_vision_fallback": useVisionFallback
        ])

        var candidates: [MetadataCandidate] = []

        // SOURCE 1: Embedded PDF metadata (highest confidence when present)
        if let embedded = extractEmbeddedMetadata(from: pdfDocument) {
            candidates.append(embedded)
        }

        // SOURCE 2: Filename parsing (fast, often reliable)
        if let url = pdfURL, let filenameCandidate = extractFromFilename(url: url) {
            candidates.append(filenameCandidate)
        }

        // SOURCE 3: Text extraction + pattern matching
        if let textCandidate = await extractFromText(pdfDocument: pdfDocument) {
            candidates.append(textCandidate)
        }

        // Log all candidates
        Log.info("Metadata candidates collected", category: .import, metadata: [
            "candidate_count": candidates.count,
            "sources": candidates.map { $0.source.rawValue }.joined(separator: ", ")
        ])

        // Evaluate candidates and decide if we need AI vision
        let result = evaluateCandidates(candidates)

        if let highConfidenceResult = result.metadata, result.confidence >= 0.7 {
            Log.info("High confidence metadata found", category: .import, metadata: [
                "title": highConfidenceResult.title ?? "nil",
                "author": highConfidenceResult.author ?? "nil",
                "confidence": result.confidence,
                "source": result.primarySource?.rawValue ?? "combined"
            ])
            return highConfidenceResult
        }

        // Low confidence or disagreement - use AI vision if enabled
        if useVisionFallback, let visionCandidate = await extractWithAIVision(pdfDocument: pdfDocument) {
            candidates.append(visionCandidate)

            // Re-evaluate with vision result (vision gets high weight)
            let finalResult = evaluateCandidates(candidates)
            if let metadata = finalResult.metadata {
                Log.info("Final metadata after AI vision", category: .import, metadata: [
                    "title": metadata.title ?? "nil",
                    "author": metadata.author ?? "nil",
                    "confidence": finalResult.confidence
                ])
                return metadata
            }
        }

        // Return best effort even if low confidence
        if let metadata = result.metadata {
            Log.info("Returning low-confidence metadata", category: .import, metadata: [
                "title": metadata.title ?? "nil",
                "author": metadata.author ?? "nil",
                "confidence": result.confidence
            ])
            return metadata
        }

        Log.debug("No cookbook metadata found in PDF", category: .import)
        return nil
    }

    // MARK: - Source 1: Embedded Metadata

    private func extractEmbeddedMetadata(from pdfDocument: PDFDocument) -> MetadataCandidate? {
        guard let attributes = pdfDocument.documentAttributes else { return nil }

        let title = attributes[PDFDocumentAttribute.titleAttribute] as? String
        let author = attributes[PDFDocumentAttribute.authorAttribute] as? String

        // Validate: must have title with reasonable length
        guard let validTitle = title, !validTitle.isEmpty, validTitle.count > 3, validTitle.count < 150 else {
            return nil
        }

        // Skip if title looks like a filename or generic
        let lowercased = validTitle.lowercased()
        if lowercased.hasSuffix(".pdf") || lowercased == "untitled" || lowercased == "document" {
            return nil
        }

        Log.debug("Found embedded PDF metadata", category: .import, metadata: [
            "title": validTitle,
            "author": author ?? "nil"
        ])

        return MetadataCandidate(
            title: validTitle,
            author: author?.isEmpty == false ? author : nil,
            source: .embedded,
            confidence: 0.9 // Embedded metadata is highly reliable
        )
    }

    // MARK: - Source 2: Filename Parsing

    private func extractFromFilename(url: URL) -> MetadataCandidate? {
        let filename = url.deletingPathExtension().lastPathComponent

        // Skip generic filenames
        let lowercased = filename.lowercased()
        if lowercased == "document" || lowercased == "untitled" || lowercased.hasPrefix("scan") ||
           lowercased.count < 5 || filename.allSatisfy({ $0.isNumber || $0 == "-" || $0 == "_" }) {
            return nil
        }

        var title: String?
        var author: String?

        // Pattern 1: "Title - Author" or "Title by Author"
        let separatorPatterns = [" - ", " — ", " – ", " by ", " By "]
        for separator in separatorPatterns {
            if let range = filename.range(of: separator) {
                let potentialTitle = String(filename[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let potentialAuthor = String(filename[range.upperBound...]).trimmingCharacters(in: .whitespaces)

                if potentialTitle.count > 3 && potentialAuthor.count > 2 {
                    title = cleanFilenameComponent(potentialTitle)
                    author = cleanFilenameComponent(potentialAuthor)
                    break
                }
            }
        }

        // Pattern 2: "Author - Title" (some formats)
        // Try to detect if first part is author (short, likely a name)
        if title == nil, let dashRange = filename.range(of: " - ") {
            let firstPart = String(filename[..<dashRange.lowerBound])
            let secondPart = String(filename[dashRange.upperBound...])

            // If first part looks like a name (2-3 words, capitalized) and second part is longer
            let firstWords = firstPart.split(separator: " ")
            if firstWords.count <= 3 && secondPart.count > firstPart.count {
                let looksLikeName = firstWords.allSatisfy { word in
                    guard let first = word.first else { return false }
                    return first.isUppercase
                }
                if looksLikeName {
                    author = cleanFilenameComponent(firstPart)
                    title = cleanFilenameComponent(secondPart)
                }
            }
        }

        // Pattern 3: Just the title (no author in filename)
        if title == nil {
            // Clean up underscores and common patterns
            var cleanedFilename = filename
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")

            // Remove common suffixes like "(1)", "copy", "final", etc.
            let suffixPatterns = [
                "\\s*\\(\\d+\\)$",
                "\\s*copy\\s*\\d*$",
                "\\s*final$",
                "\\s*v\\d+$",
                "\\s*\\d{4}$" // Year at end
            ]
            for pattern in suffixPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    cleanedFilename = regex.stringByReplacingMatches(
                        in: cleanedFilename,
                        range: NSRange(cleanedFilename.startIndex..., in: cleanedFilename),
                        withTemplate: ""
                    )
                }
            }

            title = cleanFilenameComponent(cleanedFilename)
        }

        guard let validTitle = title, validTitle.count > 3 else { return nil }

        Log.debug("Extracted metadata from filename", category: .import, metadata: [
            "filename": filename,
            "title": validTitle,
            "author": author ?? "nil"
        ])

        // Filename confidence depends on whether we found author too
        let confidence: Double = author != nil ? 0.7 : 0.5

        return MetadataCandidate(
            title: validTitle,
            author: author,
            source: .filename,
            confidence: confidence
        )
    }

    private func cleanFilenameComponent(_ component: String) -> String {
        var cleaned = component
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")

        // Title case if all lowercase or all uppercase
        if cleaned.lowercased() == cleaned || cleaned.uppercased() == cleaned {
            cleaned = cleaned.capitalized
        }

        return cleaned
    }

    // MARK: - Source 3: Text Extraction + Pattern Matching

    private func extractFromText(pdfDocument: PDFDocument) async -> MetadataCandidate? {
        let pagesToScan = min(10, pdfDocument.pageCount)
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
        return parseMetadataFromText(allText)
    }

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

    /// Parse cookbook metadata from extracted text
    private func parseMetadataFromText(_ text: String) -> MetadataCandidate? {
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

        // Pattern 2: Look for author attribution labels
        if author == nil {
            let authorPatterns = [
                "author:", "written by:", "compiled by:", "edited by:",
                "compiled and edited by:", "created by:", "developed by:"
            ]

            for line in lines {
                let lowercased = line.lowercased()
                for pattern in authorPatterns {
                    if lowercased.contains(pattern) {
                        author = line.replacingOccurrences(of: pattern, with: "", options: [.caseInsensitive])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        break
                    }
                }
                if author != nil { break }
            }
        }

        // Pattern 3: Copyright page parsing (© 2024 Author Name)
        if author == nil {
            for line in lines {
                // Match "© YYYY Name" or "Copyright YYYY Name"
                let copyrightPatterns = [
                    "©\\s*\\d{4}\\s+(.+?)(?:\\.|All|$)",
                    "Copyright\\s+(?:©\\s*)?\\d{4}\\s+(.+?)(?:\\.|All|$)"
                ]
                for pattern in copyrightPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                       let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                       match.numberOfRanges > 1,
                       let nameRange = Range(match.range(at: 1), in: line) {
                        let extractedAuthor = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if extractedAuthor.count > 2 && extractedAuthor.count < 100 {
                            author = extractedAuthor
                            break
                        }
                    }
                }
                if author != nil { break }
            }
        }

        // Pattern 4: Title scoring for best candidate
        if title == nil {
            title = findBestTitleCandidate(from: lines)
        }

        // If we found author but not title, use first substantial line
        if title == nil && author != nil {
            title = lines.first { $0.count > 5 && !$0.contains("©") && !$0.lowercased().contains("copyright") }
        }

        // Clean up and validate
        title = cleanExtractedText(title)
        author = cleanExtractedText(author)

        guard title != nil || author != nil else { return nil }

        // Calculate confidence based on what we found
        var confidence: Double = 0.4
        if title != nil && author != nil { confidence = 0.6 }
        if title != nil && title!.count > 10 && title!.count < 60 { confidence += 0.1 }

        return MetadataCandidate(
            title: title,
            author: author,
            source: .textParsing,
            confidence: confidence
        )
    }

    private func findBestTitleCandidate(from lines: [String]) -> String? {
        var bestCandidate: (line: String, score: Int)?

        for line in lines.prefix(20) {
            if line.count > 10 && line.count < 100 {
                let lowercased = line.lowercased()

                // Skip non-title lines
                let skipPatterns = ["copyright", "isbn", "published", "all rights reserved",
                                   "edition", "printing", "ingredients", "directions",
                                   "instructions", "preparation", "method", "serves"]
                if skipPatterns.contains(where: { lowercased.contains($0) }) {
                    continue
                }

                // Score this candidate
                var score = 0
                let words = line.split(separator: " ")

                // Prefer shorter text (titles are usually concise)
                if line.count < 40 { score += 3 }
                else if line.count < 60 { score += 2 }

                // Prefer title case
                let titleCaseWords = words.filter { $0.first?.isUppercase == true && $0.count > 2 }
                if Double(titleCaseWords.count) / Double(max(words.count, 1)) > 0.5 {
                    score += 2
                }

                // Prefer all-caps
                if line.uppercased() == line && line.lowercased() != line {
                    score += 3
                }

                if bestCandidate == nil || score > bestCandidate!.score {
                    bestCandidate = (line, score)
                }
            }
        }

        return bestCandidate?.line
    }

    private func cleanExtractedText(_ text: String?) -> String? {
        guard let text = text else { return nil }
        let cleaned = text
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .replacingOccurrences(of: "  ", with: " ")
        return cleaned.isEmpty ? nil : cleaned
    }

    // MARK: - Source 4: AI Vision

    private func extractWithAIVision(pdfDocument: PDFDocument) async -> MetadataCandidate? {
        guard let aiService = aiService else {
            Log.warning("AI service not available for vision extraction", category: .import)
            return nil
        }

        // Render first page (likely cover) and second page (likely title page) as images
        var images: [UIImage] = []
        for pageIndex in 0..<min(3, pdfDocument.pageCount) {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            let pageBounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0 // Higher resolution for better OCR
            let scaledSize = CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale)

            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            let pageImage = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: scaledSize))
                ctx.cgContext.scaleBy(x: scale, y: scale)
                ctx.cgContext.translateBy(x: 0, y: pageBounds.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(pageImage)
        }

        guard let firstImage = images.first else {
            Log.warning("Failed to render PDF pages for vision extraction", category: .import)
            return nil
        }

        Log.info("Using AI vision to extract cookbook metadata", category: .import, metadata: [
            "pages_analyzed": images.count
        ])

        do {
            let response = try await aiService.completeWithVisionStructured(
                image: firstImage,
                prompt: """
                This is the cover or title page of a cookbook PDF. Extract the cookbook's title and author.

                Look for:
                - The main title (usually the largest/most prominent text)
                - The author's name (often preceded by "by" or below the title)
                - Ignore subtitles, taglines, publisher names, and edition info

                If you can't confidently identify the title or author, use null for that field.
                """,
                schema: AIMetadataResponse.self,
                options: AICompletionOptions(
                    temperature: 0.1,
                    maxTokens: 200
                ),
                useCase: .ocr
            )

            guard response.title != nil || response.author != nil else {
                Log.debug("AI vision found no metadata", category: .import)
                return nil
            }

            Log.info("AI vision extracted metadata", category: .import, metadata: [
                "title": response.title ?? "nil",
                "author": response.author ?? "nil"
            ])

            return MetadataCandidate(
                title: response.title,
                author: response.author,
                source: .aiVision,
                confidence: 0.85 // AI vision is quite reliable
            )
        } catch {
            Log.error("AI vision extraction failed", category: .import, metadata: [
                "error": error.localizedDescription
            ])
            return nil
        }
    }

    // MARK: - Candidate Evaluation

    private struct EvaluationResult {
        let metadata: CookbookMetadata?
        let confidence: Double
        let primarySource: MetadataCandidate.MetadataSource?
    }

    private func evaluateCandidates(_ candidates: [MetadataCandidate]) -> EvaluationResult {
        guard !candidates.isEmpty else {
            return EvaluationResult(metadata: nil, confidence: 0, primarySource: nil)
        }

        // If only one candidate, use it
        if candidates.count == 1 {
            let c = candidates[0]
            return EvaluationResult(
                metadata: CookbookMetadata(title: c.title, author: c.author),
                confidence: c.confidence,
                primarySource: c.source
            )
        }

        // Extract all non-nil titles and authors
        let titles = candidates.compactMap { $0.title }
        let authors = candidates.compactMap { $0.author }

        // Check for agreement on title
        var bestTitle: String?
        var titleConfidence: Double = 0

        if !titles.isEmpty {
            // Group similar titles (fuzzy matching)
            let titleGroups = groupSimilarStrings(titles)
            if let largestGroup = titleGroups.max(by: { $0.count < $1.count }) {
                bestTitle = largestGroup.first
                // Higher confidence if multiple sources agree
                titleConfidence = largestGroup.count >= 2 ? 0.9 : 0.6
            }
        }

        // Check for agreement on author
        var bestAuthor: String?
        var authorConfidence: Double = 0

        if !authors.isEmpty {
            let authorGroups = groupSimilarStrings(authors)
            if let largestGroup = authorGroups.max(by: { $0.count < $1.count }) {
                bestAuthor = largestGroup.first
                authorConfidence = largestGroup.count >= 2 ? 0.9 : 0.6
            }
        }

        // If no agreement, prefer AI vision > embedded > filename > text
        if bestTitle == nil {
            let priorityOrder: [MetadataCandidate.MetadataSource] = [.aiVision, .embedded, .filename, .textParsing]
            for source in priorityOrder {
                if let candidate = candidates.first(where: { $0.source == source && $0.title != nil }) {
                    bestTitle = candidate.title
                    titleConfidence = candidate.confidence * 0.8 // Slightly lower since no agreement
                    break
                }
            }
        }

        if bestAuthor == nil {
            let priorityOrder: [MetadataCandidate.MetadataSource] = [.aiVision, .embedded, .filename, .textParsing]
            for source in priorityOrder {
                if let candidate = candidates.first(where: { $0.source == source && $0.author != nil }) {
                    bestAuthor = candidate.author
                    authorConfidence = candidate.confidence * 0.8
                    break
                }
            }
        }

        guard bestTitle != nil || bestAuthor != nil else {
            return EvaluationResult(metadata: nil, confidence: 0, primarySource: nil)
        }

        // Overall confidence is weighted average
        let overallConfidence = (titleConfidence + authorConfidence) / 2

        return EvaluationResult(
            metadata: CookbookMetadata(title: bestTitle, author: bestAuthor),
            confidence: overallConfidence,
            primarySource: candidates.first?.source
        )
    }

    /// Group strings that are similar (Levenshtein distance or substring matching)
    private func groupSimilarStrings(_ strings: [String]) -> [[String]] {
        var groups: [[String]] = []

        for string in strings {
            let normalized = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // Find a matching group
            var foundGroup = false
            for i in 0..<groups.count {
                let groupNormalized = groups[i][0].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                // Check if strings are similar (one contains the other, or very close)
                if normalized.contains(groupNormalized) || groupNormalized.contains(normalized) ||
                   levenshteinSimilarity(normalized, groupNormalized) > 0.8 {
                    groups[i].append(string)
                    foundGroup = true
                    break
                }
            }

            if !foundGroup {
                groups.append([string])
            }
        }

        return groups
    }

    /// Calculate Levenshtein similarity (0.0 to 1.0)
    private func levenshteinSimilarity(_ s1: String, _ s2: String) -> Double {
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        guard maxLength > 0 else { return 1.0 }
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[m][n]
    }
}

// MARK: - AI Response Model

private struct AIMetadataResponse: Codable {
    let title: String?
    let author: String?
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
