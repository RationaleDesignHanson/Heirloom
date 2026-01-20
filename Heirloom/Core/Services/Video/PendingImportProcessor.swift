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

        // Create recipe with extracted content
        let recipe = Recipe(
            title: extractTitle(from: transcript, onScreenText: onScreenText, mode: mode),
            sourceType: .video,
            sourceURL: provenanceMetadata?.sourceURL,
            instructions: extractInstructions(from: transcript, onScreenText: onScreenText, mode: mode),
            servings: nil,  // Could be extracted from transcript
            prepTime: nil,  // Could be extracted from transcript
            cookTime: nil   // Could be extracted from transcript
        )

        // Add ingredients extracted from text
        let extractedIngredients = extractIngredients(from: transcript, onScreenText: onScreenText)
        for ingredientText in extractedIngredients {
            let ingredient = Ingredient()
            ingredient.item = ingredientText
            ingredient.recipe = recipe
            recipe.ingredients?.append(ingredient)
        }

        // Set provenance metadata for attribution
        recipe.provenance = provenanceMetadata

        // Add extraction mode metadata to notes
        let modeDescription: String = {
            switch mode {
            case .audioTranscript: return "Extracted using audio transcript"
            case .onScreenText: return "Extracted using on-screen text (OCR)"
            case .visualFrames: return "Extracted using frame-by-frame visual analysis"
            }
        }()

        recipe.notes = """
        Imported from video

        Extraction method: \(modeDescription)

        ⚠️ Please review and edit this recipe:
        - Verify ingredients and quantities
        - Check cooking times and temperatures
        - Add any missing steps or details

        This recipe was automatically extracted and may need refinement.
        """

        return recipe

        // TODO: For production-quality extraction, integrate with:
        // - VideoRecipeProcessor for audio/OCR modes (uses Claude AI for structuring)
        // - ASMRVideoImportView logic for visual frame analysis
        // See STEP_7_EXTRACTION_PIPELINE_GUIDE.md for details
    }

    /// Extract recipe title from text content
    private func extractTitle(from transcript: String?, onScreenText: String?, mode: ExtractionMode) -> String {
        let text = transcript ?? onScreenText ?? ""

        // Try to find recipe title patterns
        let patterns = [
            "(?:recipe|how to make|making|baking) ([^.!?\\n]+)",
            "(?:^|\\n)([^\\n]{10,60}?)(?:recipe|ingredients|method|steps)",
            "(?:^|\\n)([A-Z][^\\n]{10,60}?)(?:\\n|$)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let titleRange = Range(match.range(at: 1), in: text) {
                let title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if title.count > 5 && title.count < 80 {
                    return title
                }
            }
        }

        // Fallback: Use first substantial line or generic title
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 10 && $0.count < 80 }

        if let firstLine = lines.first {
            return firstLine
        }

        // Generic title based on mode
        switch mode {
        case .audioTranscript: return "Recipe from Video (Audio)"
        case .onScreenText: return "Recipe from Video (Text)"
        case .visualFrames: return "Recipe from Video (Visual)"
        }
    }

    /// Extract cooking instructions from text
    private func extractInstructions(from transcript: String?, onScreenText: String?, mode: ExtractionMode) -> [String] {
        let text = transcript ?? onScreenText ?? ""

        // Split into sentences and filter for instruction-like content
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { sentence in
                // Keep sentences that look like instructions
                sentence.count > 20 &&
                sentence.count < 500 &&
                (sentence.lowercased().contains(any: ["add", "mix", "cook", "bake", "heat", "stir", "place", "pour", "combine", "whisk", "blend"]) ||
                 sentence.contains(any: ["°F", "°C", "minutes", "hours", "cups", "tablespoon", "teaspoon"]))
            }

        if sentences.isEmpty {
            // Fallback: Return the full text as a single instruction
            let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedText.isEmpty ? ["No instructions extracted. Please add cooking steps."] : [cleanedText]
        }

        return sentences
    }

    /// Extract ingredient list from text
    private func extractIngredients(from transcript: String?, onScreenText: String?) -> [String] {
        let text = transcript ?? onScreenText ?? ""

        // Look for ingredient patterns
        let ingredientKeywords = RecipeKeywords.ingredients
        var ingredients: [String] = []

        // Split into lines and look for ingredient-like patterns
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        for line in lines {
            let lowercased = line.lowercased()

            // Check if line contains ingredient keywords
            if ingredientKeywords.contains(where: { lowercased.contains($0) }) {
                // Line mentions an ingredient
                if line.count > 5 && line.count < 200 {
                    ingredients.append(line)
                }
            }

            // Look for measurement patterns (suggests ingredient line)
            if line.range(of: "\\d+\\s*(cup|tablespoon|teaspoon|gram|kg|lb|oz|ml|liter)", options: .regularExpression) != nil {
                if line.count > 5 && line.count < 200 && !ingredients.contains(line) {
                    ingredients.append(line)
                }
            }
        }

        if ingredients.isEmpty {
            // Fallback: Return placeholder
            return ["Ingredients not automatically extracted. Please add ingredients manually."]
        }

        // Deduplicate and limit
        return Array(Set(ingredients)).prefix(20).map { String($0) }
    }
}

// MARK: - Helper Extensions

private extension String {
    /// Check if string contains any of the given substrings
    func contains(any substrings: [String]) -> Bool {
        return substrings.contains { self.contains($0) }
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
