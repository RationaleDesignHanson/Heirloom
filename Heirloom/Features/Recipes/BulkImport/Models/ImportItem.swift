import Foundation
import SwiftData

/// Represents a single URL to import within a bulk import job
@Model
final class ImportItem {
    // MARK: - Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var processedAt: Date?

    // MARK: - URL Information
    var urlString: String = ""
    var normalizedURL: String? // For duplicate detection

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
    init(urlString: String, normalizedURL: String? = nil) {
        self.urlString = urlString
        self.normalizedURL = normalizedURL
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
