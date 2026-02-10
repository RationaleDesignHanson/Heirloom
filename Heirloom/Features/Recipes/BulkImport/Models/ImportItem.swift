import Foundation
import SwiftData

/// Import source type for unified queue processing
enum ImportSource: String, Codable {
    case url           // Video/recipe URL (existing)
    case pdf           // PDF document
    case camera        // Camera capture
    case photoLibrary  // Photo library import
}

/// Tracks individual recipe extraction attempt within multi-recipe item
struct ExtractionResult: Codable, Hashable {
    /// Title detected during detection phase
    let detectedTitle: String

    /// Whether extraction succeeded
    let success: Bool

    /// Created recipe ID (if success)
    var recipeID: UUID?

    /// Error category (if failed)
    let errorType: String?

    /// Detailed error message (if failed)
    let errorMessage: String?

    /// Location in source image
    let boundingBox: BoundingBox?

    /// Extraction duration
    let extractionDuration: TimeInterval

    /// Bounding box structure
    struct BoundingBox: Codable, Hashable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }
}

/// Phases of the import process for unified progress tracking
enum ImportPhase: String, Codable, CaseIterable {
    case validation       // Validating PDF files
    case analysis         // Detecting page boundaries and extracting images
    case extraction       // Extracting recipe details via AI
    case imageGeneration  // Generating AI images for recipes
    case completed        // All done

    /// Sort order for phase comparison
    var sortOrder: Int {
        switch self {
        case .validation: return 0
        case .analysis: return 1
        case .extraction: return 2
        case .imageGeneration: return 3
        case .completed: return 4
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .validation: return "Validating..."
        case .analysis: return "Analyzing..."
        case .extraction: return "Extracting recipes..."
        case .imageGeneration: return "Generating images..."
        case .completed: return "Import complete"
        }
    }

    /// Icon name for UI
    var iconName: String {
        switch self {
        case .validation: return "doc.text.magnifyingglass"
        case .analysis: return "doc.text.image"
        case .extraction: return "text.badge.checkmark"
        case .imageGeneration: return "sparkles"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

/// Represents a single item to import within a bulk import job
/// Supports URL-based imports (video/recipe) and image-based imports (PDF/camera/photo)
@Model
final class ImportItem {
    // MARK: - Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var processedAt: Date?

    // MARK: - Checkpoint Tracking
    /// Timestamp when page analysis completed
    var analysisCompletedAt: Date?

    /// Timestamp when recipe extraction started
    var extractionStartedAt: Date?

    /// Flag indicating this item was checkpointed (for resume)
    var wasCheckpointed: Bool = false

    // MARK: - Progressive Enhancement
    /// Placeholder recipe ID created at import start for immediate UI feedback
    /// This recipe appears in the list with "Processing..." status while extraction happens
    var placeholderRecipeID: UUID?

    // MARK: - Source Type
    var source: ImportSource = ImportSource.url

    // MARK: - URL Information (for .url source)
    var urlString: String? // Optional: only used for URL imports
    var normalizedURL: String? // For duplicate detection

    // MARK: - Image Information (for .pdf, .camera, .photoLibrary sources)
    var imageData: Data?          // Stored image for processing
    var pdfURL: String?           // Original PDF file path (if applicable)
    var pageNumber: Int?          // PDF page number (for progress tracking)
    var totalPages: Int?          // Total pages in group (for multi-page recipes)
    var isMultiPageRecipe: Bool?  // True if recipe spans multiple pages

    // MARK: - Cookbook Metadata (extracted from PDF front matter)
    var cookbookTitle: String?    // Extracted cookbook title
    var cookbookAuthor: String?   // Extracted cookbook author

    // MARK: - Status
    var status: ImportItemStatus = ImportItemStatus.pending
    var errorMessage: String?
    var retryCount: Int = 0

    // MARK: - Relationships
    var job: ImportJob?

    // MARK: - Multi-Recipe Support

    /// All recipe IDs extracted from this source
    var recipeIDs: [UUID] = []

    /// Detailed extraction results per recipe attempt
    var extractionResults: [ExtractionResult] = []

    /// Total recipes detected in this source
    var detectedRecipeCount: Int?

    /// Legacy single recipe ID (for backward compatibility)
    /// Returns first recipe ID if available
    var recipeID: UUID? {
        recipeIDs.first
    }

    // MARK: - Pre-Extracted Data (Text Pipeline)
    /// Recipe title extracted via text pipeline (skips Vision API)
    var preExtractedTitle: String?

    /// Ingredients extracted via text pipeline
    var preExtractedIngredients: [String]?

    /// Instructions extracted via text pipeline
    var preExtractedInstructions: [String]?

    /// Servings extracted via text pipeline
    var preExtractedServings: String?

    /// Prep time extracted via text pipeline
    var preExtractedPrepTime: String?

    /// Cook time extracted via text pipeline
    var preExtractedCookTime: String?

    /// Notes extracted via text pipeline
    var preExtractedNotes: String?

    /// Source/brand name extracted via text pipeline (e.g., "The Flavor Labs")
    var preExtractedSource: String?

    /// Whether this item has pre-extracted data (from text pipeline)
    var hasPreExtractedData: Bool {
        preExtractedTitle != nil && preExtractedIngredients != nil
    }

    // MARK: - AI Suggestions (Phase 3)
    /// AI-suggested collections for this recipe
    var suggestedCollections: [String]?

    /// AI-suggested tags for this recipe
    var suggestedTags: [String]?

    /// Confidence score for AI suggestions (0.0 - 1.0)
    var suggestionConfidence: Double?

    // MARK: - Initialization

    /// Initialize for URL-based import (video/recipe)
    init(urlString: String, normalizedURL: String? = nil) {
        self.source = .url
        self.urlString = urlString
        self.normalizedURL = normalizedURL
    }

    /// Initialize for image-based import (PDF/camera/photo)
    init(
        source: ImportSource,
        imageData: Data,
        pdfURL: String? = nil,
        pageNumber: Int? = nil,
        totalPages: Int? = nil,
        isMultiPageRecipe: Bool? = nil
    ) {
        self.source = source
        self.imageData = imageData
        self.pdfURL = pdfURL
        self.pageNumber = pageNumber
        self.totalPages = totalPages
        self.isMultiPageRecipe = isMultiPageRecipe
    }
}

// MARK: - ImportItemStatus

enum ImportItemStatus: String, Codable {
    case pending        // Waiting to be processed
    case processing     // Currently importing
    case success        // Successfully imported
    case failed         // Import failed
    case skipped        // Skipped (duplicate)
}

// MARK: - Convenience Extensions

extension ImportItem {
    /// Mark item as processing
    func startProcessing() {
        status = .processing
    }

    /// Mark item as successfully completed (single recipe - legacy)
    func markSuccess(recipeID: UUID) {
        status = .success
        self.recipeIDs = [recipeID]
        processedAt = Date()
    }

    /// Mark item as successfully completed (multiple recipes)
    func markSuccess(recipeIDs: [UUID]) {
        status = .success
        self.recipeIDs = recipeIDs
        processedAt = Date()
    }

    /// Mark item as partially successful (some recipes extracted, some failed)
    func markPartialSuccess(recipeIDs: [UUID]) {
        status = .success  // Still considered success overall
        self.recipeIDs = recipeIDs
        processedAt = Date()

        // Include partial failure details in error message
        let failed = (detectedRecipeCount ?? 0) - recipeIDs.count
        if failed > 0 {
            errorMessage = "\(recipeIDs.count)/\(detectedRecipeCount ?? 0) recipes extracted (\(failed) failed)"
        }
    }

    /// Mark item as failed with error message
    func markFailed(error: String) {
        status = .failed
        errorMessage = error
        processedAt = Date()
    }

    /// Mark item as skipped (duplicate)
    func markSkipped(reason: String) {
        status = .skipped
        errorMessage = reason
        processedAt = Date()
    }

    /// Increment retry counter
    func incrementRetry() {
        retryCount += 1
        status = .pending
    }

    /// Whether this item can be retried
    var canRetry: Bool {
        (status == .failed || status == .skipped) && retryCount < 3
    }

    /// Whether this item is completed (success, failed, or skipped)
    var isCompleted: Bool {
        switch status {
        case .success, .failed, .skipped:
            return true
        case .pending, .processing:
            return false
        }
    }

    // MARK: - Multi-Recipe Progress Tracking

    /// Successfully extracted recipe count
    var successfulRecipeCount: Int {
        recipeIDs.count
    }

    /// Failed extraction count
    var failedRecipeCount: Int {
        extractionResults.filter { !$0.success }.count
    }

    /// Whether all detected recipes were extracted successfully
    var isFullSuccess: Bool {
        guard let detected = detectedRecipeCount, detected > 0 else {
            return recipeIDs.count > 0
        }
        return successfulRecipeCount == detected && failedRecipeCount == 0
    }

    /// Whether this is a multi-recipe extraction (more than 1 recipe)
    var isMultiRecipeExtraction: Bool {
        (detectedRecipeCount ?? 0) > 1
    }
}

// MARK: - Duplicate Detection

extension ImportItem {
    /// Check if this item is a duplicate of another URL
    func isDuplicate(of other: ImportItem) -> Bool {
        guard let myNormalized = normalizedURL,
              let otherNormalized = other.normalizedURL else {
            return false
        }
        return myNormalized == otherNormalized
    }
}
