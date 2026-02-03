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
    private let maxBoundaryDetectionChars = 50000  // ~12.5k tokens

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

    /// Analyze extracted text and return recipe groups with extracted recipes
    /// - Parameters:
    ///   - extraction: Result from PDFTextExtractor
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: BatchAnalysisResult with boundaries and extracted recipes
    func analyzeAndExtract(
        from extraction: PDFTextExtractor.ExtractionResult,
        progressCallback: ((String, Int, Int) async -> Void)? = nil
    ) async throws -> BatchAnalysisResult {
        Log.info("Starting batch text analysis", category: .import, metadata: [
            "total_pages": extraction.pages.count,
            "total_chars": extraction.totalCharCount,
            "is_text_rich": extraction.isTextRich
        ])

        // Phase 1: Detect recipe boundaries
        await progressCallback?("Detecting recipes", 0, 2)
        let boundaries = try await detectRecipeBoundaries(from: extraction)

        Log.info("Recipe boundaries detected", category: .import, metadata: [
            "recipe_count": boundaries.count,
            "multi_page_count": boundaries.filter { $0.isMultiPage }.count
        ])

        // Phase 2: Extract each recipe
        await progressCallback?("Extracting recipes", 1, 2)
        var extractedRecipes: [AIRecipeExtractor.ExtractedRecipe] = []
        var pageGroups: [RecipePageGroup] = []

        for (index, boundary) in boundaries.enumerated() {
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
        from extraction: PDFTextExtractor.ExtractionResult
    ) async throws -> [RecipeBoundary] {
        // Build text with page markers for boundary detection
        let markedText = buildMarkedText(from: extraction.pages)

        // Split into chunks if text is too long
        if markedText.count > maxBoundaryDetectionChars {
            return try await detectBoundariesInChunks(
                pages: extraction.pages,
                chunkSize: maxBoundaryDetectionChars
            )
        }

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

    /// Detect boundaries in text using Claude text API
    private func detectBoundariesInText(_ text: String) async throws -> [RecipeBoundary] {
        let prompt = """
        Analyze this cookbook text and identify each distinct recipe. The text has page markers like "=== PAGE N ===".

        For each recipe, provide:
        - title: The recipe name
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
        - High confidence (0.9+): Clear title, ingredients, instructions
        - Medium confidence (0.7-0.9): Partial recipe or unclear boundaries
        - Low confidence (<0.7): Uncertain if it's a recipe

        Return JSON:
        {
          "recipes": [
            {"title": "Chocolate Chip Cookies", "startPage": 12, "endPage": 12, "confidence": 0.95},
            {"title": "Banana Bread", "startPage": 14, "endPage": 15, "confidence": 0.88}
          ],
          "nonRecipePages": [1, 2, 3, 100, 101]
        }
        """

        let options = AICompletionOptions(
            model: configuration.model(for: .pdfEnhancement),  // Use text model (Haiku for cost)
            temperature: 0.3,
            maxTokens: 2000,
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
        chunkSize: Int
    ) async throws -> [RecipeBoundary] {
        var allBoundaries: [RecipeBoundary] = []
        var currentChunk = ""
        var pagesInChunk: [PDFTextExtractor.ExtractedPage] = []

        for page in pages {
            let pageText = "=== PAGE \(page.pageNumber) ===\n\(page.text)\n\n"

            if currentChunk.count + pageText.count > chunkSize && !pagesInChunk.isEmpty {
                // Process current chunk
                let boundaries = try await detectBoundariesInText(currentChunk)
                allBoundaries.append(contentsOf: boundaries)

                // Start new chunk
                currentChunk = pageText
                pagesInChunk = [page]
            } else {
                currentChunk += pageText
                pagesInChunk.append(page)
            }
        }

        // Process final chunk
        if !pagesInChunk.isEmpty {
            let boundaries = try await detectBoundariesInText(currentChunk)
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

