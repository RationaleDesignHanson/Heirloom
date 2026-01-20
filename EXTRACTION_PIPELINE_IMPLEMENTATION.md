# Proper Extraction Pipeline Implementation

## Current Issue
The `PendingImportProcessor.extractRecipe()` method currently uses basic pattern matching instead of the proper `VideoRecipeProcessor` + Claude AI pipeline that exists in `HeirloomVideoLab`.

## Architecture (from main branch)

### API Key Management:
- **Corporate Key**: Stored in `Config.xcconfig` → `Info.plist` → `DEFAULT_ANTHROPIC_KEY`
- **Personal Keys**: Stored in iOS Keychain (user-provided, optional)
- **Priority**: Personal key first → Corporate key fallback
- **Auto-recovery**: 401 errors auto-remove invalid personal keys

### Extraction Pipeline:
```
VideoRecipeProcessor
    ├── WhisperKitTranscriptionService (audio → transcript)
    ├── FrameAnalysisService (video → OCR text from frames)
    └── ClaudeRecipeStructurer (transcript + OCR → structured recipe via Claude AI)
            └── AnthropicAIService (uses corporate/personal key)
```

## Implementation Steps

### Step 1: Update PendingImportProcessor to use VideoRecipeProcessor

**File**: `Heirloom/Core/Services/Video/PendingImportProcessor.swift`

Replace the current `extractRecipe()` implementation with proper VideoRecipeProcessor integration:

```swift
actor PendingImportProcessor {

    // Existing services
    private let audioAnalyzer: AudioAnalyzer
    private let onScreenTextDetector: OnScreenTextDetector
    private let watermarkDetector: WatermarkDetector
    private let socialMetadataService: SocialMetadataService
    private let subscriptionManager: SubscriptionManager
    private let paywallManager: PaywallManager

    // NEW: Add VideoRecipeProcessor
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
    private static func makeVideoProcessor() -> VideoRecipeProcessor {
        // Get AI configuration and services from ServiceContainer
        let aiConfig = ServiceContainer.shared.resolve(AIConfiguration.self)
        let usageTracker = ServiceContainer.shared.resolve(AIUsageTracker.self)

        // Create AnthropicAIService (uses corporate key from Config.xcconfig)
        let anthropicService = AnthropicAIService(
            configuration: aiConfig,
            usageTracker: usageTracker
        )

        // Create ClaudeRecipeStructurer with AnthropicAIService
        let recipeStructurer = ClaudeRecipeStructurer(aiService: anthropicService)

        // Create VideoRecipeProcessor with all services
        let videoProcessor = VideoRecipeProcessor(
            transcriptionService: WhisperKitTranscriptionService.shared,
            recipeStructurer: recipeStructurer,
            enableFrameAnalysis: true,
            enableCaching: true
        )

        return videoProcessor
    }

    private func extractRecipe(
        from videoURL: URL,
        mode: ExtractionMode,
        transcript: String?,
        onScreenText: String?,
        provenanceMetadata: ProvenanceMetadata?
    ) async throws -> Recipe {

        guard let processor = videoProcessor else {
            throw ImportError.extractionFailed("Video processor not initialized")
        }

        // Use VideoRecipeProcessor for all modes (it handles audio, OCR, and visual)
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

        // Add ingredients
        for extracted in structured.ingredients {
            let ingredient = Ingredient()
            ingredient.item = extracted.item
            ingredient.quantity = extracted.quantity
            ingredient.unit = extracted.unit
            ingredient.preparation = extracted.preparation
            ingredient.recipe = recipe
            recipe.ingredients?.append(ingredient)
        }

        // Set provenance metadata
        recipe.provenance = provenanceMetadata

        // Add extraction metadata to notes if there are warnings
        if !structured.warnings.isEmpty {
            recipe.notes = """
            Imported from video using Claude AI

            ⚠️ Review needed:
            \(structured.warnings.joined(separator: "\n"))

            Overall confidence: \(Int(structured.overallConfidence * 100))%
            """
        }

        return recipe
    }
}
```

### Step 2: Update ClaudeRecipeStructurer to Accept AIService

**File**: `HeirloomVideoLab/Features/VideoImport/Services/ClaudeRecipeStructurer.swift`

The file already has the right structure, just needs to remove the `fatalError` in the convenience init:

```swift
/// Convenience initializer for production use
convenience init() {
    // Use AnthropicAIService from ServiceContainer
    let aiConfig = ServiceContainer.shared.resolve(AIConfiguration.self)
    let usageTracker = ServiceContainer.shared.resolve(AIUsageTracker.self)
    let anthropicService = AnthropicAIService(
        configuration: aiConfig,
        usageTracker: usageTracker
    )
    self.init(aiService: anthropicService)
}
```

### Step 3: Verify Config.xcconfig

**File**: `Heirloom/Config/Config.xcconfig`

Ensure your corporate Anthropic key is set:

```
// Anthropic API Configuration
DEFAULT_ANTHROPIC_KEY = sk-ant-api03-your-corporate-key-here
```

This gets read by `Info.plist` and accessed via:
```swift
Bundle.main.object(forInfoDictionaryKey: "DEFAULT_ANTHROPIC_KEY")
```

### Step 4: Remove Pattern Matching Implementation

Delete the current pattern matching implementation (extractTitle, extractInstructions, extractIngredients) since VideoRecipeProcessor + Claude AI handles this properly.

## Benefits of Proper Implementation

1. **Uses Claude AI**: Much better extraction quality than pattern matching
2. **Corporate Key**: Uses your Config.xcconfig key automatically
3. **Personal Key Support**: Users can optionally provide their own keys
4. **Auto-fallback**: Invalid personal keys automatically revert to corporate key
5. **Rate Limiting**: Built-in quota management for default key
6. **Caching**: VideoRecipeProcessor caches transcripts to avoid re-processing
7. **Usage Tracking**: All AI requests tracked via AIUsageTracker

## Testing

After implementation:

1. **Test with corporate key**:
   - Remove any personal keys from Keychain
   - Import a video → should use corporate key

2. **Test personal key fallback**:
   - Add invalid personal key via settings
   - Import video → should auto-remove invalid key, use corporate key

3. **Test quality**:
   - Compare extraction quality to pattern matching
   - Claude AI should extract much better structured data

## Notes

- The corporate key is **build-time configuration** (Config.xcconfig → Info.plist)
- Personal keys are **runtime configuration** (user-provided, stored in Keychain)
- The system is designed to handle both gracefully with automatic fallback
