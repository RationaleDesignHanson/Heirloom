import Foundation

/// Represents bulk content from Notes (multiple URLs and/or recipe text)
struct BulkImportContent: Codable {
    let urls: [String]
    let plainText: String?
    let hasRecipeText: Bool

    var totalItems: Int {
        urls.count + (hasRecipeText ? 1 : 0)
    }
}

/// Represents a video import in progress (for Share Extension handoff)
struct PendingVideoImport: Codable, Identifiable {
    let id: UUID
    let sourceType: SourceType
    var localVideoURL: URL?
    var originalURL: URL?
    var detectedPlatform: SocialPlatform
    var audioAnalysis: AudioAnalysisResult?
    var onScreenTextResult: OnScreenTextResult?
    var provenanceMetadata: ProvenanceMetadata?
    var processingStatus: ProcessingStatus
    let createdAt: Date
    var errorMessage: String?
    var bulkContent: BulkImportContent?  // For Notes with URLs + text
    var imageURLs: [URL]?  // For multiple images from Share Extension

    enum SourceType: String, Codable {
        case shareExtensionVideo
        case shareExtensionURL
        case shareExtensionPDF
        case shareExtensionImage
        case shareExtensionImageBatch  // Multiple images from Photos share
        case shareExtensionBulk  // Multiple URLs + optional text
        case photoLibrary
        case cameraCapture
    }

    enum ProcessingStatus: String, Codable {
        case pending
        case analyzingAudio
        case analyzingOnScreenText
        case fetchingMetadata
        case extractingRecipe
        case completed
        case failed
    }

    init(id: UUID = UUID(),
         sourceType: SourceType,
         localVideoURL: URL? = nil,
         originalURL: URL? = nil,
         detectedPlatform: SocialPlatform = .unknown) {
        self.id = id
        self.sourceType = sourceType
        self.localVideoURL = localVideoURL
        self.originalURL = originalURL
        self.detectedPlatform = detectedPlatform
        self.processingStatus = .pending
        self.createdAt = Date()
    }
}
