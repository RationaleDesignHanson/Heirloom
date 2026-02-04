//
//  CookbookBatchAnalyzer.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation
import UIKit

/// Analyzes text-rich PDF cookbooks using Claude text API (much cheaper than Vision)
/// Processes extracted text in batches to identify recipes and extract structured data
///
/// # Architecture
///
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │              Text-Based Recipe Extraction Pipeline           │
/// └─────────────────────────────────────────────────────────────┘
///
///  PDFTextExtractor.extractText()
///     │
///     ▼
///  ExtractionResult { pages, fullText, isTextRich }
///     │
///     │ If isTextRich (80%+ native text):
///     ▼
///  CookbookBatchAnalyzer.analyzeAndExtract()
///     │
///     ├───► Phase 1: Detect Recipe Boundaries
///     │          │
///     │          ▼
///     │     Claude Text API (cheap)
///     │     "Find recipe boundaries in this text..."
///     │          │
///     │          ▼
///     │     [RecipeBoundary] { title, startPage, endPage }
///     │
///     ├───► Phase 2: Extract Each Recipe
///     │          │
///     │          ▼
///     │     For each boundary:
///     │       - Get text slice for that page range
///     │       - Claude Text API: "Extract structured recipe..."
///     │          │
///     │          ▼
///     │     [ExtractedRecipe]
///     │
///     └───► Return: [RecipePageGroup] with extracted recipes
/// ```
///
/// # Cost Comparison (100-page cookbook)
///
/// **Vision API Path (scanned PDFs):**
/// - 100 pages × $0.015/page = ~$1.50
/// - Total: ~$1.50
///
/// **Text API Path (text-rich PDFs):**
/// - Boundary detection: ~$0.02 (one call)
/// - Recipe extraction: 25 recipes × $0.02 = ~$0.50
/// - Total: ~$0.52 (65% cheaper!)
///
/// # Usage Example
///
/// ```swift
/// let textExtractor = PDFTextExtractor()
/// let batchAnalyzer = CookbookBatchAnalyzer(aiService: aiService, analytics: analytics)
///
/// let extraction = try await textExtractor.extractText(from: pdfURL)
///
/// if extraction.isTextRich {
///     // Use cheap text pipeline
///     let groups = try await batchAnalyzer.analyzeAndExtract(from: extraction)
///     // groups contains RecipePageGroup with extracted recipes
/// } else {
///     // Fall back to vision pipeline
///     let groups = try await multiPageAnalyzer.analyzePageBoundaries(pages: renderedPages)
/// }
/// ```
@MainActor
final class CookbookBatchAnalyzer {

    // MARK: - Dependencies

    private let aiService: AIServiceProtocol
    private let analytics: AnalyticsService
    private let configuration: AIConfigurationProtocol

    // MARK: - Types

    /// Detected boundary of a recipe in the text
    struct RecipeBoundary: Codable {
        let title: String
        let startPage: Int
        let endPage: Int
        let confidence: Double

        var pageRange: ClosedRange<Int> {
            startPage...endPage
        }

        var isMultiPage: Bool {
            endPage > startPage
        }
    }

    /// Response from boundary detection API call
    struct BoundaryDetectionResponse: Codable {
        let recipes: [RecipeBoundary]
        let nonRecipePages: [Int]?
    }

    /// Result of batch analysis
    struct BatchAnalysisResult {
        let boundaries: [RecipeBoundary]
        let extractedRecipes: [AIRecipeExtractor.ExtractedRecipe]
        let pageGroups: [RecipePageGroup]
        let textExtractionStats: PDFTextExtractor.ExtractionResult

        var recipeCount: Int { boundaries.count }
        var multiPageCount: Int { boundaries.filter { $0.isMultiPage }.count }
    }

    // MARK: - Configuration

    /// Maximum characters to send in a single boundary detection call
    /// Reduced from 50k to 30k to limit recipes per chunk and prevent response truncation
    private let maxBoundaryDetectionChars = 30000  // ~7.5k tokens

    /// Maximum characters per recipe extraction call
    private let maxRecipeExtractionChars = 8000   // ~2k tokens

    // MARK: - Initialization

    init(
        aiService: AIServiceProtocol,
        analytics: AnalyticsService,
        configuration: AIConfigurationProtocol
    ) {
        self.aiService = aiService
        self.analytics = analytics
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Progress update for detailed tracking
    struct ProgressUpdate {
        let phase: String           // "detecting" or "extracting"
        let message: String         // Human-readable message
        let current: Int            // Current item
        let total: Int              // Total items
        let recipesFound: Int       // Recipes discovered so far
    }

    /// Analyze extracted text and return recipe groups with extracted recipes
    /// - Parameters:
    ///   - extraction: Result from PDFTextExtractor
    ///   - progressCallback: Optional callback for progress updates (legacy)
    ///   - detailedProgressCallback: Optional callback for detailed progress updates
    /// - Returns: BatchAnalysisResult with boundaries and extracted recipes
    func analyzeAndExtract(
        from extraction: PDFTextExtractor.ExtractionResult,
        progressCallback: ((String, Int, Int) async -> Void)? = nil,
        detailedProgressCallback: ((ProgressUpdate) async -> Void)? = nil
    ) async throws -> BatchAnalysisResult {
        Log.info("Starting batch text analysis", category: .import, metadata: [
            "total_pages": extraction.pages.count,
            "total_chars": extraction.totalCharCount,
            "is_text_rich": extraction.isTextRich
        ])

        // Phase 1: Detect recipe boundaries
        await progressCallback?("Detecting recipes", 0, 2)
        let boundaries = try await detectRecipeBoundaries(
            from: extraction,
            progressCallback: detailedProgressCallback
        )

        Log.info("Recipe boundaries detected", category: .import, metadata: [
            "recipe_count": boundaries.count,
            "multi_page_count": boundaries.filter { $0.isMultiPage }.count
        ])

        // Phase 2: Extract each recipe
        await progressCallback?("Extracting recipes", 1, 2)
        var extractedRecipes: [AIRecipeExtractor.ExtractedRecipe] = []
        var pageGroups: [RecipePageGroup] = []

        for (index, boundary) in boundaries.enumerated() {
            // Report progress
            await detailedProgressCallback?(ProgressUpdate(
                phase: "extracting",
                message: "Extracting \(boundary.title)",
                current: index + 1,
                total: boundaries.count,
                recipesFound: extractedRecipes.count
            ))
            // Get text for this recipe's page range
            let recipeText = getTextForPageRange(
                boundary.pageRange,
                from: extraction.pages
            )

            do {
                let recipe = try await extractRecipe(
                    from: recipeText,
                    expectedTitle: boundary.title
                )
                extractedRecipes.append(recipe)

                // Create page group (without images for now - will be added by RecipeImageCropper)
                let group = RecipePageGroup(
                    title: recipe.title,
                    startPage: boundary.startPage,
                    endPage: boundary.endPage,
                    pageImagePaths: [],  // Images added later
                    confidence: boundary.confidence,
                    isMultiPage: boundary.isMultiPage
                )
                pageGroups.append(group)

                Log.debug("Extracted recipe", category: .import, metadata: [
                    "index": index + 1,
                    "title": recipe.title,
                    "pages": "\(boundary.startPage)-\(boundary.endPage)",
                    "ingredients": recipe.ingredients.count,
                    "instructions": recipe.instructions.count
                ])
            } catch {
                Log.warning("Failed to extract recipe", category: .import, metadata: [
                    "title": boundary.title,
                    "error": error.localizedDescription
                ])
                // Continue with other recipes
            }
        }

        // Track analytics
        analytics.track(event: .multiPageAnalysisComplete, properties: [
            "total_pages": extraction.pages.count,
            "recipe_count": extractedRecipes.count,
            "multi_page_count": boundaries.filter { $0.isMultiPage }.count,
            "extraction_method": "text_api"
        ])

        return BatchAnalysisResult(
            boundaries: boundaries,
            extractedRecipes: extractedRecipes,
            pageGroups: pageGroups,
            textExtractionStats: extraction
        )
    }

    /// Quick boundary detection only (for cost estimation)
    func detectRecipeBoundaries(
        from extraction: PDFTextExtractor.ExtractionResult,
        progressCallback: ((ProgressUpdate) async -> Void)? = nil
    ) async throws -> [RecipeBoundary] {
        // Build text with page markers for boundary detection
        let markedText = buildMarkedText(from: extraction.pages)

        // Split into chunks if text is too long
        if markedText.count > maxBoundaryDetectionChars {
            return try await detectBoundariesInChunks(
                pages: extraction.pages,
                chunkSize: maxBoundaryDetectionChars,
                progressCallback: progressCallback
            )
        }

        await progressCallback?(ProgressUpdate(
            phase: "detecting",
            message: "Analyzing pages...",
            current: 1,
            total: 1,
            recipesFound: 0
        ))
        return try await detectBoundariesInText(markedText)
    }

    // MARK: - Private Helpers

    /// Build text with page markers for boundary detection
    private func buildMarkedText(from pages: [PDFTextExtractor.ExtractedPage]) -> String {
        return pages.map { page in
            "=== PAGE \(page.pageNumber) ===\n\(page.text)"
        }.joined(separator: "\n\n")
    }

    /// Get text for a specific page range
    private func getTextForPageRange(
        _ range: ClosedRange<Int>,
        from pages: [PDFTextExtractor.ExtractedPage]
    ) -> String {
        return pages
            .filter { range.contains($0.pageNumber) }
            .map { $0.text }
            .joined(separator: "\n\n")
    }

    /// Detect boundaries in text using Claude text API with retry
    private func detectBoundariesInText(_ text: String) async throws -> [RecipeBoundary] {
        // Retry up to 2 times on failure (3 total attempts)
        var lastError: Error?
        for attempt in 1...3 {
            do {
                return try await performBoundaryDetection(text)
            } catch {
                lastError = error
                Log.warning("Boundary detection attempt \(attempt) failed", category: .import, metadata: [
                    "error": error.localizedDescription,
                    "text_length": text.count
                ])
                if attempt < 3 {
                    // Wait a bit before retrying
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }
        throw lastError ?? AIError.invalidResponse(reason: "Boundary detection failed after 3 attempts")
    }

    /// Perform the actual boundary detection API call
    private func performBoundaryDetection(_ text: String) async throws -> [RecipeBoundary] {
        let prompt = """
        Analyze this cookbook text and identify each distinct recipe. The text has page markers like "=== PAGE N ===".

        For each recipe, provide:
        - title: The recipe name (keep it short)
        - startPage: Page number where recipe begins
        - endPage: Page number where recipe ends (same as start for single-page recipes)
        - confidence: 0.0-1.0 indicating certainty

        TEXT TO ANALYZE:
        \(text)

        Guidelines:
        - A recipe typically has: title, ingredients list, and instructions
        - Multi-page recipes are common - look for continuations
        - Skip non-recipe content: table of contents, introductions, indexes, chapter headers
        - If a recipe spans pages 5-7, startPage=5, endPage=7
        - Only include recipes with confidence >= 0.7

        Return ONLY this JSON format (no nonRecipePages needed):
        {"recipes":[{"title":"Recipe Name","startPage":1,"endPage":1,"confidence":0.9}]}
        """

        let options = AICompletionOptions(
            model: configuration.model(for: .pdfEnhancement),  // Use text model (Haiku for cost)
            temperature: 0.3,
            maxTokens: 4000,  // Increased for large cookbooks with many recipes
            systemMessage: """
            You are an expert at analyzing cookbook text and identifying recipe boundaries.
            Be thorough but accurate - it's better to miss an ambiguous recipe than to create false positives.
            Pay attention to page markers to accurately track multi-page recipes.
            """
        )

        let response: BoundaryDetectionResponse = try await aiService.completeStructured(
            prompt: prompt,
            schema: BoundaryDetectionResponse.self,
            options: options
        )

        return response.recipes
    }

    /// Detect boundaries in chunks for large documents
    private func detectBoundariesInChunks(
        pages: [PDFTextExtractor.ExtractedPage],
        chunkSize: Int,
        progressCallback: ((ProgressUpdate) async -> Void)? = nil
    ) async throws -> [RecipeBoundary] {
        var allBoundaries: [RecipeBoundary] = []
        var currentChunk = ""
        var pagesInChunk: [PDFTextExtractor.ExtractedPage] = []
        var chunks: [(text: String, startPage: Int, endPage: Int)] = []

        // First pass: build chunks
        for page in pages {
            let pageText = "=== PAGE \(page.pageNumber) ===\n\(page.text)\n\n"

            if currentChunk.count + pageText.count > chunkSize && !pagesInChunk.isEmpty {
                // Save current chunk
                chunks.append((
                    text: currentChunk,
                    startPage: pagesInChunk.first?.pageNumber ?? 0,
                    endPage: pagesInChunk.last?.pageNumber ?? 0
                ))

                // Start new chunk
                currentChunk = pageText
                pagesInChunk = [page]
            } else {
                currentChunk += pageText
                pagesInChunk.append(page)
            }
        }

        // Add final chunk
        if !pagesInChunk.isEmpty {
            chunks.append((
                text: currentChunk,
                startPage: pagesInChunk.first?.pageNumber ?? 0,
                endPage: pagesInChunk.last?.pageNumber ?? 0
            ))
        }

        // Second pass: process chunks with progress reporting
        for (index, chunk) in chunks.enumerated() {
            await progressCallback?(ProgressUpdate(
                phase: "detecting",
                message: "Analyzing pages \(chunk.startPage)-\(chunk.endPage)",
                current: index + 1,
                total: chunks.count,
                recipesFound: allBoundaries.count
            ))

            let boundaries = try await detectBoundariesInText(chunk.text)
            allBoundaries.append(contentsOf: boundaries)
        }

        // Deduplicate boundaries that might span chunks
        return deduplicateBoundaries(allBoundaries)
    }

    /// Remove duplicate boundaries from chunked detection
    private func deduplicateBoundaries(_ boundaries: [RecipeBoundary]) -> [RecipeBoundary] {
        var seen = Set<String>()
        var unique: [RecipeBoundary] = []

        for boundary in boundaries {
            let key = "\(boundary.title.lowercased())-\(boundary.startPage)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(boundary)
            }
        }

        return unique.sorted { $0.startPage < $1.startPage }
    }

    /// Extract a single recipe from text
    private func extractRecipe(
        from text: String,
        expectedTitle: String
    ) async throws -> AIRecipeExtractor.ExtractedRecipe {
        let prompt = """
        Extract the recipe "\(expectedTitle)" from this text.

        TEXT:
        \(text.prefix(maxRecipeExtractionChars))

        Extract and return JSON with:
        - title: Recipe name (use "\(expectedTitle)" if unclear)
        - servings: How many servings (e.g., "4", "6-8 servings", null if not found)
        - prep_time: Preparation time (e.g., "15 minutes", null if not found)
        - cook_time: Cooking time (e.g., "30 minutes", null if not found)
        - ingredients: Array of ingredient strings (clean and standardize)
        - instructions: Array of instruction steps (clean, in order)
        - notes: Any additional notes or tips (null if none)

        Guidelines:
        - Fix OCR/extraction errors
        - Standardize measurements (1/2 cup, not 1/2 c or .5 cups)
        - Combine multi-line ingredients into single entries
        - Number instructions if not already numbered
        - Preserve temperatures, times, and techniques

        Return ONLY valid JSON.
        """

        let options = AICompletionOptions(
            model: configuration.model(for: .pdfEnhancement),
            temperature: 0.3,
            maxTokens: 2000,
            systemMessage: """
            You are an expert recipe extractor. Extract structured recipe data accurately.
            Handle messy text, fix obvious errors, and produce clean, usable recipes.
            """
        )

        return try await aiService.completeStructured(
            prompt: prompt,
            schema: AIRecipeExtractor.ExtractedRecipe.self,
            options: options
        )
    }
}

