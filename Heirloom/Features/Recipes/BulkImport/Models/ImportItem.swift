import Foundation
import SwiftData

/// Import source type for unified queue processing
enum ImportSource: String, Codable {
    case url           // Video/recipe URL (existing)
    case pdf           // PDF document
    case camera        // Camera capture
    case photoLibrary  // Photo library import
}

/// Phases of the import process for unified progress tracking
enum ImportPhase: String, Codable, CaseIterable {
    case validation   // Validating PDF files
    case analysis     // Detecting page boundaries and extracting images
    case extraction   // Extracting recipe details via AI
    case completed    // All done

    /// Sort order for phase comparison
    var sortOrder: Int {
        switch self {
        case .validation: return 0
        case .analysis: return 1
        case .extraction: return 2
        case .completed: return 3
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .validation: return "Validating PDFs..."
        case .analysis: return "Analyzing pages..."
        case .extraction: return "Extracting recipes..."
        case .completed: return "Import complete"
        }
    }

    /// Icon name for UI
    var iconName: String {
        switch self {
        case .validation: return "doc.text.magnifyingglass"
        case .analysis: return "doc.text.image"
        case .extraction: return "text.badge.checkmark"
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

    /// Reference to created recipe (if successful)
    var recipeID: UUID?

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

    /// Mark item as successfully completed
    func markSuccess(recipeID: UUID) {
        status = .success
        self.recipeID = recipeID
        processedAt = Date()
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
