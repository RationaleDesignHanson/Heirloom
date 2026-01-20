import UIKit

/// Intelligently analyzes PDF pages to detect recipe boundaries
/// Uses Claude Vision API to determine if recipes span multiple pages
/// Groups continuation pages with their starting pages for unified extraction
///
/// # Architecture
///
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │              Multi-Page Recipe Detection Pipeline            │
/// └─────────────────────────────────────────────────────────────┘
///
///  PDFProcessor Output
///  [(1, image), (2, image), (3, image), ...]
///         │
///         ▼
///  MultiPageRecipeAnalyzer.analyzePageBoundaries()
///         │
///         │ For each page:
///         ├───► analyzePage() ──► Claude Vision API
///         │                            │
///         │                            ▼
///         │                  PageAnalysis {
///         │                    type: recipeStart | recipeContinuation | completeRecipe | nonRecipe
///         │                    title: "Chocolate Chip Cookies"
///         │                    confidence: 0.92
///         │                    reasoning: "..."
///         │                  }
///         │                            │
///         │                            ▼
///         ├───► State Machine ────────┘
///         │          │
///         │          ├─ recipeStart        ──► New RecipePageGroup
///         │          ├─ recipeContinuation ──► Append to current group
///         │          ├─ completeRecipe     ──► Single-page group
///         │          └─ nonRecipe          ──► Close current group (skip page)
///         │
///         ▼
///  [RecipePageGroup]
///  ├─ Group 1: "Brownies" (Page 5)
///  ├─ Group 2: "Chocolate Chip Cookies" (Pages 7-9) ← Multi-page!
///  └─ Group 3: "Apple Pie" (Page 12)
///         │
///         │ For multi-page groups:
///         ├───► combinedImage() ──► Stacks images vertically
///         │
///         ▼
///  ImportJobManager.createPDFImportJob()
///  - 3 ImportItems created (one per recipe)
///  - Multi-page recipes get single tall combined image
/// ```
///
/// # State Machine for Page Analysis
///
/// ```
///                   ┌───────────────┐
///                   │  Initial State │
///                   └───────┬───────┘
///                           │
///              ┌────────────┴────────────┐
///              │                         │
///              ▼                         ▼
///      ┌──────────────┐          ┌──────────────┐
///      │ recipeStart  │          │completeRecipe│
///      │ (New recipe) │          │ (Standalone) │
///      └──────┬───────┘          └──────┬───────┘
///             │                         │
///             │ Creates new group       │ Creates group + closes
///             ▼                         ▼
///      ┌──────────────────┐      ┌──────────────┐
///      │ recipeContinuation│      │  nonRecipe   │
///      │ (Extends group)   │      │ (Skip page)  │
///      └──────┬───────────┘      └──────────────┘
///             │                         │
///             │ Appends to group        │ Closes current group
///             └─────────────────────────┘
/// ```
///
/// # Grouping Examples
///
/// **Example 1: Simple Cookbook**
/// ```
/// Page 1: Table of Contents     → nonRecipe        (skipped)
/// Page 2: Introduction          → nonRecipe        (skipped)
/// Page 3: "Brownies"            → completeRecipe   → Group 1 (Page 3)
/// Page 4: "Cookies" (title)     → recipeStart      → Group 2 starts
/// Page 5: "Cookies" (cont.)     → recipeContinuation → Group 2 (Pages 4-5)
/// Page 6: "Apple Pie"           → completeRecipe   → Group 3 (Page 6)
///
/// Result: 3 RecipePageGroups (2 single-page, 1 multi-page)
/// ```
///
/// **Example 2: Long Recipe Spanning 3 Pages**
/// ```
/// Page 40: "Homemade Pizza Dough" (title + ingredients) → recipeStart → Group starts
/// Page 41: (instructions continued)                      → recipeContinuation → Append
/// Page 42: (final steps + notes)                         → recipeContinuation → Append
/// Page 43: "Marinara Sauce" (new recipe)                 → recipeStart → Group closed, new starts
///
/// Result: Group 1 = Pages 40-42 combined into single tall image
/// ```
///
/// **Example 3: Edge Case - Continuation Without Start**
/// ```
/// Page 1: (middle of instructions, no title) → recipeContinuation
///
/// Handling: Create new group anyway (fallback behavior)
/// Logs warning: "Recipe continuation without start"
/// ```
///
/// # Performance Characteristics
///
/// - **API Calls**: 1 Claude Vision API call per page (~3-5 seconds each)
/// - **Concurrency**: Sequential page analysis (to maintain context)
/// - **Memory**: Holds all page images in memory during analysis
/// - **Cost**: ~$0.01-0.02 per page (Claude Vision pricing)
///
/// # Usage Example
///
/// ```swift
/// let pdfPages = try await pdfProcessor.renderPDFPages(from: pdfURL)
/// // pdfPages = [(1, image1), (2, image2), ...]
///
/// let analyzer = MultiPageRecipeAnalyzer(aiService: aiService, analytics: analytics)
/// let groups = try await analyzer.analyzePageBoundaries(pages: pdfPages)
///
/// for group in groups {
///     print("\(group.title): \(group.pageRange)")
///     // "Chocolate Chip Cookies: Pages 5-7"
///     // "Apple Pie: Page 10"
///
///     if group.isMultiPage {
///         let combinedImage = group.combinedImage()  // Tall vertical image
///         // Use for single extraction call
///     }
/// }
/// ```
@MainActor
final class MultiPageRecipeAnalyzer {

    // MARK: - Dependencies
    private let aiService: AIServiceProtocol
    private let analytics: AnalyticsService

    // MARK: - Stateful Batch Processing
    private var groups: [RecipePageGroup] = []
    private var currentGroup: RecipePageGroup?

    init(aiService: AIServiceProtocol, analytics: AnalyticsService) {
        self.aiService = aiService
        self.analytics = analytics
    }

    // MARK: - Public API

    /// Process a single batch of pages and maintain state across batches
    /// Use this for memory-efficient streaming processing of large PDFs
    /// Call `finalizeGroups()` after all batches are processed
    func processBatch(
        _ batch: [(pageNumber: Int, image: UIImage)],
        progressCallback: ((Int) async -> Void)? = nil
    ) async throws {
        guard !batch.isEmpty else { return }

        // Analyze all pages in this batch concurrently
        let batchResults = try await withThrowingTaskGroup(
            of: (pageNumber: Int, image: UIImage, analysis: PageAnalysis).self
        ) { group in
            for (pageNum, image) in batch {
                group.addTask {
                    let analysis = try await self.analyzePage(image, pageNumber: pageNum)
                    return (pageNumber: pageNum, image: image, analysis: analysis)
                }
            }

            // Collect results
            var results: [(pageNumber: Int, image: UIImage, analysis: PageAnalysis)] = []
            for try await result in group {
                results.append(result)
            }

            // Sort by page number to maintain order
            return results.sorted { $0.pageNumber < $1.pageNumber }
        }

        // Process batch results sequentially to maintain state machine logic
        for (pageNum, image, analysis) in batchResults {
            // Report progress
            await progressCallback?(pageNum)

            Log.info("Page analysis result", category: .import, metadata: [
                "page": pageNum,
                "type": analysis.type.rawValue,
                "confidence": analysis.confidence,
                "title": analysis.title ?? "none"
            ])

            // Compress image and save to disk to prevent memory crashes
            let compressedImage = compressForStorage(image)
            let imagePath = saveImageToDisk(compressedImage, pageNumber: pageNum)

            switch analysis.type {
            case .recipeStart:
                // New recipe begins - save any existing group first
                if let existing = currentGroup {
                    groups.append(existing)
                    Log.info("Completed recipe group", category: .import, metadata: [
                        "title": existing.title,
                        "pages": "\(existing.startPage)-\(existing.endPage)",
                        "page_count": existing.pageCount
                    ])
                }

                // Start new group
                currentGroup = RecipePageGroup(
                    title: analysis.title ?? "Recipe",
                    startPage: pageNum,
                    endPage: pageNum,
                    pageImagePaths: [imagePath],
                    confidence: analysis.confidence
                )

            case .recipeContinuation:
                // Continues previous recipe
                if currentGroup != nil {
                    currentGroup?.endPage = pageNum
                    currentGroup?.pageImagePaths.append(imagePath)

                    // Mark as multi-page on first continuation
                    if currentGroup?.isMultiPage == false {
                        currentGroup?.isMultiPage = true

                        // Track analytics: Multi-page recipe detected
                        analytics.track(event: AnalyticsEvent.multiPageRecipeDetected, properties: [
                            "recipe_title": currentGroup?.title ?? "Unknown",
                            "start_page": currentGroup?.startPage ?? 0
                        ])
                    }
                } else {
                    // Edge case: continuation with no start (treat as new recipe)
                    Log.warning("Recipe continuation without start", category: .import, metadata: [
                        "page": pageNum
                    ])
                    currentGroup = RecipePageGroup(
                        title: analysis.title ?? "Recipe",
                        startPage: pageNum,
                        endPage: pageNum,
                        pageImagePaths: [imagePath],
                        confidence: analysis.confidence
                    )
                }

            case .completeRecipe:
                // Save any existing group first
                if let existing = currentGroup {
                    groups.append(existing)
                    Log.info("Completed recipe group", category: .import, metadata: [
                        "title": existing.title,
                        "pages": "\(existing.startPage)-\(existing.endPage)",
                        "page_count": existing.pageCount
                    ])
                }

                // Single-page recipe - create and save immediately
                let singlePageGroup = RecipePageGroup(
                    title: analysis.title ?? "Recipe",
                    startPage: pageNum,
                    endPage: pageNum,
                    pageImagePaths: [imagePath],
                    confidence: analysis.confidence,
                    isMultiPage: false
                )
                groups.append(singlePageGroup)

                Log.info("Completed single-page recipe", category: .import, metadata: [
                    "title": singlePageGroup.title,
                    "page": pageNum
                ])

                // Clear current group since this was complete
                currentGroup = nil

            case .multipleRecipes:
                // Multiple complete recipes on one page - create separate groups for each
                if let existing = currentGroup {
                    groups.append(existing)
                    Log.info("Completed recipe group before multiple recipes page", category: .import, metadata: [
                        "title": existing.title,
                        "pages": "\(existing.startPage)-\(existing.endPage)",
                        "page_count": existing.pageCount
                    ])
                }

                // Get all recipe titles from the analysis
                let recipeTitles = analysis.titles ?? []

                // Create a separate group for each recipe
                for (index, recipeTitle) in recipeTitles.enumerated() {
                    let multiRecipeGroup = RecipePageGroup(
                        title: recipeTitle,
                        startPage: pageNum,
                        endPage: pageNum,
                        pageImagePaths: [imagePath],  // All recipes share the same page image
                        confidence: analysis.confidence,
                        isMultiPage: false
                    )
                    groups.append(multiRecipeGroup)

                    Log.info("Created recipe group from multi-recipe page", category: .import, metadata: [
                        "title": recipeTitle,
                        "page": pageNum,
                        "recipe_index": index + 1,
                        "total_recipes_on_page": recipeTitles.count
                    ])
                }

                // Track analytics: Multiple recipes on one page detected
                analytics.track(event: AnalyticsEvent.multiPageRecipeDetected, properties: [
                    "recipes_on_page": recipeTitles.count,
                    "page": pageNum
                ])

                // Clear current group since these were complete
                currentGroup = nil

            case .nonRecipe:
                // Non-recipe page - complete any open group
                if let existing = currentGroup {
                    groups.append(existing)
                    Log.info("Completed recipe group before non-recipe page", category: .import, metadata: [
                        "title": existing.title,
                        "pages": "\(existing.startPage)-\(existing.endPage)",
                        "page_count": existing.pageCount,
                        "next_page": pageNum
                    ])
                    currentGroup = nil
                }

                Log.info("Non-recipe page detected", category: .import, metadata: [
                    "page": pageNum,
                    "reasoning": analysis.reasoning
                ])
            }
        }

        // Force memory cleanup after batch
        await Task.yield()
    }

    /// Finalize groups after all batches are processed
    /// Call this once after all `processBatch()` calls are complete
    func finalizeGroups() -> [RecipePageGroup] {
        // Save any remaining group
        if let existing = currentGroup {
            groups.append(existing)
            Log.info("Finalized last recipe group", category: .import, metadata: [
                "title": existing.title,
                "pages": "\(existing.startPage)-\(existing.endPage)",
                "page_count": existing.pageCount
            ])
        }

        let finalGroups = groups

        // Reset state for next analysis
        groups = []
        currentGroup = nil

        return finalGroups
    }

    /// Analyze PDF pages to detect recipe boundaries and group multi-page recipes
    /// - Parameter pages: Array of (pageNumber, image) tuples from PDF
    /// - Returns: Array of RecipePageGroup objects representing distinct recipes
    func analyzePageBoundaries(
        pages: [(pageNumber: Int, image: UIImage)],
        progressCallback: ((Int) async -> Void)? = nil
    ) async throws -> [RecipePageGroup] {
        guard !pages.isEmpty else {
            return []
        }

        Log.info("Starting multi-page recipe analysis with BATCH PROCESSING", category: .import, metadata: [
            "total_pages": pages.count,
            "batch_size": 3
        ])

        var groups: [RecipePageGroup] = []
        var currentGroup: RecipePageGroup?

        // Process pages in batches of 3 for concurrent API calls (reduced from 5 to prevent memory crashes)
        let batchSize = 3
        let batches = pages.chunked(into: batchSize)

        Log.info("PDF pages split into batches", category: .import, metadata: [
            "batch_count": batches.count,
            "batch_size": batchSize
        ])

        for (batchIndex, batch) in batches.enumerated() {
            let batchStartTime = Date()
            Log.info("Starting batch processing", category: .import, metadata: [
                "batch_index": batchIndex + 1,
                "batch_total": batches.count,
                "pages_in_batch": batch.count
            ])

            // Analyze all pages in this batch concurrently
            let batchResults = try await withThrowingTaskGroup(
                of: (pageNumber: Int, image: UIImage, analysis: PageAnalysis).self
            ) { group in
                for (pageNum, image) in batch {
                    group.addTask {
                        let analysis = try await self.analyzePage(image, pageNumber: pageNum)
                        return (pageNumber: pageNum, image: image, analysis: analysis)
                    }
                }

                // Collect results
                var results: [(pageNumber: Int, image: UIImage, analysis: PageAnalysis)] = []
                for try await result in group {
                    results.append(result)
                }

                // Sort by page number to maintain order
                return results.sorted { $0.pageNumber < $1.pageNumber }
            }

            let batchDuration = Date().timeIntervalSince(batchStartTime)
            Log.info("Batch processing completed", category: .import, metadata: [
                "batch_index": batchIndex + 1,
                "duration_seconds": String(format: "%.1f", batchDuration),
                "pages_processed": batchResults.count,
                "seconds_per_page": String(format: "%.1f", batchDuration / Double(batchResults.count))
            ])

            // Process batch results sequentially to maintain state machine logic
            for (pageNum, image, analysis) in batchResults {
                // Report progress
                await progressCallback?(pageNum)

                Log.info("Page analysis result", category: .import, metadata: [
                    "page": pageNum,
                    "type": analysis.type.rawValue,
                    "confidence": analysis.confidence,
                    "title": analysis.title ?? "none"
                ])

                // Compress image and save to disk to prevent memory crashes
                let compressedImage = compressForStorage(image)
                let imagePath = saveImageToDisk(compressedImage, pageNumber: pageNum)

                switch analysis.type {
            case .recipeStart:
                // New recipe begins - save any existing group first
                if let existing = currentGroup {
                    groups.append(existing)
                    Log.info("Completed recipe group", category: .import, metadata: [
                        "title": existing.title,
                        "pages": "\(existing.startPage)-\(existing.endPage)",
                        "page_count": existing.pageCount
                    ])
                }

                // Start new group
                currentGroup = RecipePageGroup(
                    title: analysis.title ?? "Recipe",
                    startPage: pageNum,
                    endPage: pageNum,
                    pageImagePaths: [imagePath],
                    confidence: analysis.confidence
                )

            case .recipeContinuation:
                // Continues previous recipe
                if currentGroup != nil {
                    currentGroup?.endPage = pageNum
                    currentGroup?.pageImagePaths.append(imagePath)

                    // Mark as multi-page on first continuation
                    if currentGroup?.isMultiPage == false {
                        currentGroup?.isMultiPage = true

                        // Track analytics: Multi-page recipe detected
                        analytics.track(event: AnalyticsEvent.multiPageRecipeDetected, properties: [
                            "recipe_title": currentGroup?.title ?? "Unknown",
                            "start_page": currentGroup?.startPage ?? 0
                        ])
                    }
                } else {
                    // Edge case: continuation with no start (treat as new recipe)
                    Log.warning("Recipe continuation without start", category: .import, metadata: [
                        "page": pageNum
                    ])
                    currentGroup = RecipePageGroup(
                        title: analysis.title ?? "Recipe",
                        startPage: pageNum,
                        endPage: pageNum,
                        pageImagePaths: [imagePath],
                        confidence: analysis.confidence
                    )
                }

            case .completeRecipe:
                // Standalone recipe on single page - save existing and create new
                if let existing = currentGroup {
                    groups.append(existing)
                    Log.info("Completed recipe group", category: .import, metadata: [
                        "title": existing.title,
                        "pages": "\(existing.startPage)-\(existing.endPage)",
                        "page_count": existing.pageCount
                    ])
                }

                // Add complete recipe as its own group
                groups.append(RecipePageGroup(
                    title: analysis.title ?? "Recipe",
                    startPage: pageNum,
                    endPage: pageNum,
                    pageImagePaths: [imagePath],
                    confidence: analysis.confidence
                ))

                currentGroup = nil

            case .multipleRecipes:
                // Multiple recipes on one page - create separate groups for each
                if let existing = currentGroup {
                    groups.append(existing)
                    Log.info("Completed recipe group before multiple recipes page", category: .import, metadata: [
                        "title": existing.title,
                        "pages": "\(existing.startPage)-\(existing.endPage)",
                        "page_count": existing.pageCount
                    ])
                }

                // Create a separate group for each recipe title
                let recipeTitles = analysis.titles ?? []
                for recipeTitle in recipeTitles {
                    groups.append(RecipePageGroup(
                        title: recipeTitle,
                        startPage: pageNum,
                        endPage: pageNum,
                        pageImagePaths: [imagePath],
                        confidence: analysis.confidence
                    ))

                    Log.info("Created recipe group from multi-recipe page", category: .import, metadata: [
                        "title": recipeTitle,
                        "page": pageNum,
                        "total_recipes_on_page": recipeTitles.count
                    ])
                }

                currentGroup = nil

            case .nonRecipe:
                // Not a recipe (table of contents, intro, index, etc.)
                // Save any existing group and reset
                if let existing = currentGroup {
                    groups.append(existing)
                    Log.info("Completed recipe group before non-recipe page", category: .import, metadata: [
                        "title": existing.title,
                        "pages": "\(existing.startPage)-\(existing.endPage)",
                        "page_count": existing.pageCount,
                        "next_page": pageNum
                    ])
                    currentGroup = nil
                }

                Log.info("Non-recipe page detected", category: .import, metadata: [
                    "page": pageNum,
                    "reasoning": analysis.reasoning
                ])
            }
            }

            // Force memory cleanup after batch
            await Task.yield() // Let system reclaim memory

            // Small delay between batches to prevent memory spikes
            if batchIndex < batches.count - 1 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }

        // Append final group if exists
        if let final = currentGroup {
            groups.append(final)
            Log.info("Completed final recipe group", category: .import, metadata: [
                "title": final.title,
                "pages": "\(final.startPage)-\(final.endPage)",
                "page_count": final.pageCount
            ])
        }

        Log.info("Multi-page analysis complete", category: .import, metadata: [
            "total_pages": pages.count,
            "recipe_groups": groups.count,
            "multi_page_recipes": groups.filter { $0.isMultiPage }.count
        ])

        // Track analytics
        analytics.track(event: AnalyticsEvent.multiPageAnalysisComplete, properties: [
            "total_pages": pages.count,
            "recipe_groups": groups.count,
            "multi_page_count": groups.filter { $0.isMultiPage }.count,
            "avg_confidence": groups.map { $0.confidence }.reduce(0, +) / Double(max(groups.count, 1))
        ])

        return groups
    }

    // MARK: - Private Helpers

    /// Analyze a single page to determine its role in the recipe document
    /// - Parameters:
    ///   - image: Page image to analyze
    ///   - pageNumber: Page number for logging
    /// - Returns: PageAnalysis with type, title, confidence
    private func analyzePage(_ image: UIImage, pageNumber: Int) async throws -> PageAnalysis {
        let prompt = """
        Analyze this page from a PDF document and determine its role in a cookbook or recipe collection.

        Respond with:
        1. **type**: One of these exact values:
           - "recipe_start": A new recipe begins on this page (has a recipe title/heading at the top)
           - "recipe_continuation": This page continues the previous recipe (no new title, continues instructions/notes)
           - "complete_recipe": A complete standalone recipe that fits on this single page
           - "multiple_recipes": TWO OR MORE complete recipes on this single page (each with title, ingredients, instructions)
           - "non_recipe": Not a recipe (table of contents, introduction, index, blank page, etc.)

        2. **title**: Recipe title if visible (for single recipe types), or null
        3. **titles**: Array of ALL recipe titles (ONLY for "multiple_recipes" type), or null
        4. **confidence**: 0.0-1.0 float indicating how confident you are
        5. **reasoning**: Brief 1-2 sentence explanation of your decision

        **Key indicators:**

        For **recipe_start**:
        - Clear recipe title/heading at or near the top
        - Ingredient list begins
        - May have partial instructions (continues on next page)
        - Look for "continued..." or "(cont.)" hints

        For **recipe_continuation**:
        - NO recipe title at the top
        - Continues instructions from previous page
        - May have page footer like "Chocolate Chip Cookies (continued)"
        - No new ingredient list

        For **complete_recipe**:
        - Clear recipe title
        - Full ingredient list
        - Complete instructions
        - Everything fits on one page
        - ONLY ONE recipe on the page

        For **multiple_recipes**: **IMPORTANT - USE THIS FOR PAGES WITH 2+ RECIPES**
        - TWO OR MORE distinct recipes on the same page
        - Each recipe has its own title/heading
        - Common in cookbooks with short recipes (smoothies, snacks, simple dishes)
        - Examples: "Smoothie Template" + "Chocolate Banana Shake" on same page
        - When this type is detected, populate the "titles" array with ALL recipe names found

        For **non_recipe**:
        - Table of contents
        - Introduction/foreword
        - Index
        - Blank or decorative pages
        - Chapter dividers

        **Important:**
        - Be conservative with recipe_continuation. Only use it if there's clear evidence the page continues the previous recipe (no new title, continues mid-instruction).
        - ALWAYS use "multiple_recipes" if you see 2+ complete recipes on one page, no matter how short they are.
        """

        let options = AICompletionOptions(
            model: "claude-sonnet-4-5-20250929",  // Claude Sonnet 4.5 (latest, active model)
            temperature: 0.3,  // Lower for more consistent classification
            maxTokens: 500
        )

        do {
            let response: PageAnalysis = try await aiService.completeWithVisionStructured(
                image: image,
                prompt: prompt,
                schema: PageAnalysis.self,
                options: options,
                useCase: .ocr
            )

            return response

        } catch {
            Log.warning("Page analysis failed, assuming complete recipe", category: .import, metadata: [
                "page": pageNumber,
                "error": error.localizedDescription
            ])

            // Fallback: assume complete recipe
            return PageAnalysis(
                type: .completeRecipe,
                title: "Recipe",
                titles: nil,
                confidence: 0.5,
                reasoning: "Analysis failed, assuming complete recipe as fallback"
            )
        }
    }

    // MARK: - Memory Management

    /// Compress image to reduce memory footprint
    /// Reduces ~2-3MB images to ~300KB while maintaining quality for OCR
    private func compressForStorage(_ image: UIImage) -> UIImage {
        // Target max dimension of 1200px (good for OCR, smaller memory)
        let maxDimension: CGFloat = 1200
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)

        if scale < 1.0 {
            // Downscale if needed
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resized = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return resized ?? image
        }

        return image
    }

    /// Save image to temp directory and return file path
    /// This prevents memory crashes by keeping images on disk instead of RAM
    private func saveImageToDisk(_ image: UIImage, pageNumber: Int) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "pdf_page_\(pageNumber)_\(UUID().uuidString).jpg"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Save as JPEG with 0.8 quality (good balance of size/quality)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }

        return fileURL.path
    }
}

// MARK: - Models

/// Result of analyzing a single PDF page
struct PageAnalysis: Codable {
    enum PageType: String, Codable {
        case recipeStart = "recipe_start"
        case recipeContinuation = "recipe_continuation"
        case completeRecipe = "complete_recipe"
        case multipleRecipes = "multiple_recipes"  // NEW: Multiple complete recipes on one page
        case nonRecipe = "non_recipe"
    }

    let type: PageType
    let title: String?
    let titles: [String]?  // NEW: For multiple_recipes type
    let confidence: Double
    let reasoning: String
}

/// Represents a group of pages that form a single recipe
struct RecipePageGroup: Identifiable {
    let id = UUID()
    var title: String
    var startPage: Int
    var endPage: Int
    var pageImagePaths: [String] // Changed from [UIImage] to file paths
    var confidence: Double
    var isMultiPage: Bool = false

    /// Load images from disk when needed
    var pages: [UIImage] {
        pageImagePaths.compactMap { path in
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let image = UIImage(data: data) else {
                return nil
            }
            return image
        }
    }

    /// Human-readable page range
    var pageRange: String {
        if startPage == endPage {
            return "Page \(startPage)"
        } else {
            return "Pages \(startPage)-\(endPage)"
        }
    }

    /// Number of pages in this recipe
    var pageCount: Int {
        pageImagePaths.count
    }

    /// Combine all pages into single tall image (for multi-page recipes)
    func combinedImage() -> UIImage {
        guard pages.count > 1 else {
            return pages.first ?? UIImage()
        }

        // Calculate total height
        let totalHeight = pages.reduce(0) { $0 + $1.size.height }
        let maxWidth = pages.map { $0.size.width }.max() ?? 0

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: maxWidth, height: totalHeight))

        return renderer.image { context in
            var yOffset: CGFloat = 0

            for image in pages {
                image.draw(at: CGPoint(x: 0, y: yOffset))
                yOffset += image.size.height
            }
        }
    }
}

// MARK: - Array Extension for Batching

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

