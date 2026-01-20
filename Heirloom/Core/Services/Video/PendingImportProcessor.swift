import Foundation

actor PendingImportProcessor {

    // Use existing services
    private let audioAnalyzer: AudioAnalyzer
    private let onScreenTextDetector: OnScreenTextDetector
    private let watermarkDetector: WatermarkDetector
    private let socialMetadataService: SocialMetadataService
    private let subscriptionManager: SubscriptionManager
    private let paywallManager: PaywallManager
    private let videoProcessor: VideoRecipeProcessor?

    init(audioAnalyzer: AudioAnalyzer,
         subscriptionManager: SubscriptionManager,
         paywallManager: PaywallManager,
         videoProcessor: VideoRecipeProcessor? = nil) {
        self.audioAnalyzer = audioAnalyzer
        self.onScreenTextDetector = OnScreenTextDetector()
        self.watermarkDetector = WatermarkDetector()
        self.socialMetadataService = SocialMetadataService()
        self.subscriptionManager = subscriptionManager
        self.paywallManager = paywallManager
        self.videoProcessor = videoProcessor
    }

    /// Convenience factory method
    static func make(subscriptionManager: SubscriptionManager,
                     paywallManager: PaywallManager) async -> PendingImportProcessor {
        let audioAnalyzer = await AudioAnalyzer.makeDefault()

        // Initialize VideoRecipeProcessor with proper services
        let videoProcessor = await makeVideoProcessor()

        return PendingImportProcessor(
            audioAnalyzer: audioAnalyzer,
            subscriptionManager: subscriptionManager,
            paywallManager: paywallManager,
            videoProcessor: videoProcessor
        )
    }

    @MainActor
    private static func makeVideoProcessor() async -> VideoRecipeProcessor {
        // Get AI configuration and services from ServiceContainer
        let aiConfig = ServiceContainer.shared.resolve(AIConfiguration.self)
        let usageTracker = ServiceContainer.shared.resolve(AIUsageTracker.self)

        // Create AnthropicAIService (uses corporate key from Config.xcconfig)
        let anthropicService = AnthropicAIService(
            configuration: aiConfig,
            usageTracker: usageTracker
        )

        // Create services
        let transcriptionService = await WhisperKitTranscriptionService()
        let recipeStructurer = ClaudeRecipeStructurer(aiService: anthropicService)

        // Create VideoRecipeProcessor using convenience initializer
        // This will automatically create AudioExtractionService and FrameAnalysisService
        let videoProcessor = VideoRecipeProcessor(
            transcriptionService: transcriptionService,
            recipeStructurer: recipeStructurer,
            aiService: anthropicService,
            enableFrameAnalysis: true,
            enableCaching: true,
            enableAugmentation: false  // Disable augmentation for Share Extension imports
        )

        return videoProcessor
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
        let isPremium = await subscriptionManager.isPremium
        if isPremium {
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
            throw VideoImportError.noVideoFile
        }

        // Watermark detection for attribution (parallel to extraction)
        let watermarkResult = try await watermarkDetector.detect(in: videoURL)

        // Resolve attribution from multiple sources
        let (sourceURL, sourceAttribution, _) = AttributionResolver.resolve(
            urlPlatformInfo: nil,
            watermarkResult: watermarkResult,
            socialMetadata: nil
        )

        // Create ProvenanceMetadata
        let provenanceMetadata = ProvenanceMetadata(
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

        guard let processor = videoProcessor else {
            throw VideoImportError.extractionFailed("Video processor not initialized")
        }

        // Use VideoRecipeProcessor for all modes
        // It handles: audio extraction → transcription → frame analysis → Claude AI structuring
        let extraction = try await processor.process(videoURL: videoURL)

        // Convert VideoRecipeExtraction → Recipe
        return convertToRecipe(
            extraction: extraction,
            provenanceMetadata: provenanceMetadata
        )
    }

    /// Convert VideoRecipeExtraction to Recipe model
    private func convertToRecipe(
        extraction: VideoRecipeExtraction,
        provenanceMetadata: ProvenanceMetadata?
    ) -> Recipe {
        let structured = extraction.structuredRecipe

        // Create recipe
        let recipe = Recipe(
            title: structured.title,
            sourceType: .video,
            sourceURL: provenanceMetadata?.sourceURL,
            instructions: structured.steps.map { $0.instruction },
            servings: structured.servings,
            prepTime: structured.prepTime,
            cookTime: structured.cookTime
        )

        // Add ingredients with full details
        for extracted in structured.ingredients {
            let ingredient = Ingredient()
            ingredient.name = extracted.item  // Note: Ingredient model uses 'name' not 'item'
            ingredient.originalText = extracted.item  // Store original text too
            if let qty = Double(extracted.quantity ?? "") {
                ingredient.quantity = qty
            }
            ingredient.unit = extracted.unit
            ingredient.preparation = extracted.preparation
            ingredient.recipe = recipe
            recipe.ingredients?.append(ingredient)
        }

        // Set provenance metadata for attribution
        recipe.provenance = provenanceMetadata

        // Add extraction metadata to notes if there are warnings
        if !structured.warnings.isEmpty {
            recipe.notes = """
            Imported from video using Claude AI

            ⚠️ Review needed:
            \(structured.warnings.joined(separator: "\n"))

            Overall confidence: \(Int(structured.overallConfidence * 100))%
            Processing time: \(String(format: "%.1f", extraction.processingTime))s
            """
        }

        return recipe
    }

}
