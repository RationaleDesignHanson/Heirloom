import Foundation

actor PendingImportProcessor {

    // Use existing services
    private let audioAnalyzer: AudioAnalyzer
    private let onScreenTextDetector: OnScreenTextDetector
    private let watermarkDetector: WatermarkDetector
    private let socialMetadataService: SocialMetadataService
    private let subscriptionManager: SubscriptionManager
    private let paywallManager: PaywallManager

    init(audioAnalyzer: AudioAnalyzer,
         subscriptionManager: SubscriptionManager,
         paywallManager: PaywallManager) {
        self.audioAnalyzer = audioAnalyzer
        self.onScreenTextDetector = OnScreenTextDetector()
        self.watermarkDetector = WatermarkDetector()
        self.socialMetadataService = SocialMetadataService()
        self.subscriptionManager = subscriptionManager
        self.paywallManager = paywallManager
    }

    /// Convenience factory method
    static func make(subscriptionManager: SubscriptionManager,
                     paywallManager: PaywallManager) async -> PendingImportProcessor {
        let audioAnalyzer = await AudioAnalyzer.makeDefault()
        return PendingImportProcessor(
            audioAnalyzer: audioAnalyzer,
            subscriptionManager: subscriptionManager,
            paywallManager: paywallManager
        )
    }

    /// Analyze video to determine extraction mode and check if premium is required
    func analyzeVideo(at videoURL: URL) async throws -> VideoImportAnalysisResult {

        // TIER 1: Audio Analysis (FREE)
        let audioResult = try await audioAnalyzer.analyze(videoAt: videoURL)

        if audioResult.recommendedMode == .audioTranscript {
            // Audio is good - proceed for free
            return .canProceedFree(
                mode: .audioTranscript,
                transcript: audioResult.transcript,
                onScreenText: nil
            )
        }

        // TIER 2: On-Screen Text Detection (FREE)
        let ocrResult = try await onScreenTextDetector.detect(in: videoURL)

        if ocrResult.hasRecipeText {
            // OCR found recipe text - proceed for free
            return .canProceedFree(
                mode: .onScreenText,
                transcript: nil,
                onScreenText: ocrResult.detectedText
            )
        }

        // TIER 3: Visual Analysis Required (PREMIUM)
        // Check if user has premium access
        if subscriptionManager.isPremium {
            return .canProceedFree(
                mode: .visualFrames,
                transcript: nil,
                onScreenText: nil
            )
        }

        // User needs premium for visual extraction
        return .requiresPremium(
            audioReasoning: audioResult.reasoning,
            ocrReasoning: ocrResult.reasoning
        )
    }

    /// Process import after user confirms (or has premium)
    func processImport(
        _ pendingImport: PendingVideoImport,
        mode: ExtractionMode,
        transcript: String?,
        onScreenText: String?
    ) async throws -> Recipe {
        var updated = pendingImport

        guard let videoURL = updated.localVideoURL else {
            throw ImportError.noVideoFile
        }

        // Watermark detection for attribution (parallel to extraction)
        let watermarkResult = try await watermarkDetector.detect(in: videoURL)

        // Resolve attribution from multiple sources
        let (sourceURL, sourceAttribution, platform) = AttributionResolver.resolve(
            urlPlatformInfo: nil, // TODO: Pass from pending import if available
            watermarkResult: watermarkResult,
            socialMetadata: nil // TODO: Fetch if URL available
        )

        // Create ProvenanceMetadata
        var provenanceMetadata = ProvenanceMetadata(
            sourceType: .video,
            sourceURL: sourceURL,
            sourceAttribution: sourceAttribution
        )

        updated.provenanceMetadata = provenanceMetadata

        // Extract recipe using determined mode
        updated.processingStatus = .extractingRecipe

        let recipe = try await extractRecipe(
            from: videoURL,
            mode: mode,
            transcript: transcript,
            onScreenText: onScreenText,
            provenanceMetadata: updated.provenanceMetadata
        )

        updated.processingStatus = .completed

        return recipe
    }

    /// Trigger paywall for visual extraction
    func triggerVisualExtractionPaywall() {
        Task { @MainActor in
            paywallManager.show(for: .visualVideoExtraction)
        }
    }

    private func extractRecipe(
        from videoURL: URL,
        mode: ExtractionMode,
        transcript: String?,
        onScreenText: String?,
        provenanceMetadata: ProvenanceMetadata?
    ) async throws -> Recipe {

        // TODO: Connect to existing extraction pipelines
        // Reference ARCHITECTURE_NOTES.md for exact implementation

        switch mode {
        case .audioTranscript:
            // Use existing VideoImport/ extraction with transcript
            throw ImportError.extractionFailed("Audio transcript extraction not yet connected")

        case .onScreenText:
            // Use on-screen text as input (similar to standard but with OCR text)
            throw ImportError.extractionFailed("OCR text extraction not yet connected")

        case .visualFrames:
            // Use existing ASMRVideoImport/ visual extraction
            throw ImportError.extractionFailed("Visual frame extraction not yet connected")
        }
    }
}

enum ImportError: LocalizedError {
    case videoRequired(platform: SocialPlatform)
    case noVideoFile
    case extractionFailed(String)
    case premiumRequired

    var errorDescription: String? {
        switch self {
        case .videoRequired(let platform):
            return "Please provide the video from \(platform.displayName)"
        case .noVideoFile:
            return "No video file available"
        case .extractionFailed(let reason):
            return "Could not extract recipe: \(reason)"
        case .premiumRequired:
            return "Premium subscription required for visual extraction"
        }
    }
}
