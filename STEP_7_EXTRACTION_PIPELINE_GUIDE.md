# Step 7: Connect Extraction Pipelines

## Overview
The `extractRecipe()` method in `PendingImportProcessor.swift` currently has TODOs. You need to wire it to existing VideoImport and ASMRVideoImport services.

## Existing Services Available

### 1. VideoRecipeProcessor (Audio + OCR)
**Location**: `HeirloomVideoLab/Features/VideoImport/Services/VideoRecipeProcessor.swift`

**Usage**:
```swift
let processor = VideoRecipeProcessor(
    transcriptionService: WhisperKitTranscriptionService.shared,
    recipeStructurer: ClaudeRecipeStructurer()
)

let extraction = try await processor.process(videoURL: videoURL)
// Returns: VideoRecipeExtraction with structuredRecipe, transcript, visualElements
```

### 2. ASMRVideoImport (Visual Frames)
**Location**: `Heirloom/Features/Recipes/ASMRVideoImport/Views/ASMRVideoImportView.swift`

You'll need to extract the core processing logic or reference how it calls Claude's vision API for frame-by-frame analysis.

---

## Implementation Guide

### File to Update:
`Heirloom/Core/Services/Video/PendingImportProcessor.swift`

### Current Code (Lines 134-158):
```swift
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
```

---

## Suggested Implementation

### Step 7a: Add Dependency Injection

Add VideoRecipeProcessor to PendingImportProcessor's dependencies:

```swift
actor PendingImportProcessor {

    // Use existing services
    private let audioAnalyzer: AudioAnalyzer
    private let onScreenTextDetector: OnScreenTextDetector
    private let watermarkDetector: WatermarkDetector
    private let socialMetadataService: SocialMetadataService
    private let subscriptionManager: SubscriptionManager
    private let paywallManager: PaywallManager

    // NEW: Add video processor
    private let videoProcessor: VideoRecipeProcessor?

    init(audioAnalyzer: AudioAnalyzer,
         subscriptionManager: SubscriptionManager,
         paywallManager: PaywallManager,
         videoProcessor: VideoRecipeProcessor? = nil) {  // NEW parameter
        self.audioAnalyzer = audioAnalyzer
        self.onScreenTextDetector = OnScreenTextDetector()
        self.watermarkDetector = WatermarkDetector()
        self.socialMetadataService = SocialMetadataService()
        self.subscriptionManager = subscriptionManager
        self.paywallManager = paywallManager
        self.videoProcessor = videoProcessor  // NEW
    }

    /// Convenience factory method
    static func make(subscriptionManager: SubscriptionManager,
                     paywallManager: PaywallManager) async -> PendingImportProcessor {
        let audioAnalyzer = await AudioAnalyzer.makeDefault()

        // Initialize video processor with existing services
        let transcriptionService = WhisperKitTranscriptionService.shared
        let recipeStructurer = ClaudeRecipeStructurer()
        let videoProcessor = VideoRecipeProcessor(
            transcriptionService: transcriptionService,
            recipeStructurer: recipeStructurer
        )

        return PendingImportProcessor(
            audioAnalyzer: audioAnalyzer,
            subscriptionManager: subscriptionManager,
            paywallManager: paywallManager,
            videoProcessor: videoProcessor
        )
    }
```

### Step 7b: Implement extractRecipe for Audio + OCR

```swift
private func extractRecipe(
    from videoURL: URL,
    mode: ExtractionMode,
    transcript: String?,
    onScreenText: String?,
    provenanceMetadata: ProvenanceMetadata?
) async throws -> Recipe {

    switch mode {
    case .audioTranscript, .onScreenText:
        // Use existing VideoRecipeProcessor for audio/OCR extraction
        guard let processor = videoProcessor else {
            throw ImportError.extractionFailed("Video processor not initialized")
        }

        let extraction = try await processor.process(videoURL: videoURL)

        // Convert VideoRecipeExtraction → Recipe
        return convertToRecipe(
            extraction: extraction,
            provenanceMetadata: provenanceMetadata
        )

    case .visualFrames:
        // Visual extraction (ASMR) - see Step 7c
        throw ImportError.extractionFailed("Visual frame extraction not yet connected")
    }
}

/// Convert VideoRecipeExtraction to Recipe model
private func convertToRecipe(
    extraction: VideoRecipeExtraction,
    provenanceMetadata: ProvenanceMetadata?
) -> Recipe {
    let structured = extraction.structuredRecipe

    // Convert ExtractedIngredient → Ingredient
    let ingredients = structured.ingredients.map { extracted in
        Ingredient(
            item: extracted.item,
            quantity: extracted.quantity,
            unit: extracted.unit,
            preparation: extracted.preparation,
            originalText: extracted.originalText
        )
    }

    // Convert ExtractedStep → Step
    let steps = structured.steps.enumerated().map { index, extracted in
        Step(
            order: index + 1,
            instruction: extracted.instruction,
            duration: extracted.duration,
            temperature: extracted.temperature
        )
    }

    return Recipe(
        title: structured.title,
        recipeDescription: structured.description,
        ingredients: ingredients,
        steps: steps,
        servings: structured.servings,
        prepTime: structured.prepTime,
        cookTime: structured.cookTime,
        provenanceMetadata: provenanceMetadata,
        dateCreated: Date()
    )
}
```

### Step 7c: Implement Visual Extraction (ASMR)

For visual extraction, you have two options:

**Option 1: Extract Core Logic from ASMRVideoImportView**

Look at `Heirloom/Features/Recipes/ASMRVideoImport/Views/ASMRVideoImportView.swift` and extract the frame extraction + Claude vision API logic into a reusable service.

**Option 2: Create New Visual Extraction Service**

```swift
// NEW FILE: Heirloom/Core/Services/Video/VisualRecipeExtractor.swift

import AVFoundation
import UIKit

actor VisualRecipeExtractor {

    func extract(from videoURL: URL) async throws -> Recipe {
        // 1. Extract key frames (8-12 frames across video)
        let frames = try await extractKeyFrames(from: videoURL, count: 12)

        // 2. Send to Claude vision API for recipe extraction
        let claudeService = ServiceContainer.shared.resolve(ClaudeService.self)
        let recipeData = try await claudeService.extractRecipeFromFrames(frames)

        // 3. Convert to Recipe model
        return convertToRecipe(recipeData)
    }

    private func extractKeyFrames(from videoURL: URL, count: Int) async throws -> [UIImage] {
        // Use existing FrameAnalysisService or implement frame extraction
        let frameService = FrameAnalysisService()
        return try await frameService.extractKeyFrames(from: videoURL, count: count)
    }

    private func convertToRecipe(_ data: Any) -> Recipe {
        // Convert Claude API response to Recipe
        // Implementation depends on Claude API response format
        fatalError("TODO: Implement conversion from Claude vision API response")
    }
}
```

Then wire it up in extractRecipe:

```swift
case .visualFrames:
    // Use visual extraction for ASMR videos
    let visualExtractor = VisualRecipeExtractor()
    var recipe = try await visualExtractor.extract(from: videoURL)

    // Add provenance metadata
    recipe.provenanceMetadata = provenanceMetadata

    return recipe
```

---

## Key Data Models to Understand

### VideoRecipeExtraction (from VideoRecipeProcessor)
```swift
struct VideoRecipeExtraction {
    let structuredRecipe: StructuredRecipe
    let transcript: TranscriptionResult
    let visualElements: [String]
    let metadata: VideoImportMetadata
    let processingTime: TimeInterval
    let estimatedCost: Decimal
}
```

### StructuredRecipe
```swift
struct StructuredRecipe {
    let title: String
    let description: String?
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let ingredients: [ExtractedIngredient]
    let steps: [ExtractedStep]
    let overallConfidence: Double
    let warnings: [String]
}
```

### Your Recipe Model
**Location**: Check `Heirloom/Core/Models/Recipe.swift`

Map the fields appropriately based on your existing Recipe model structure.

---

## Testing After Implementation

1. **Audio Mode**: Import a video with clear narration
2. **OCR Mode**: Import a video with text overlays (no speech)
3. **Visual Mode**: Import an ASMR video (premium user)

Expected: All three modes should successfully create Recipe objects.

---

## Alternative: Minimal Implementation

If you want to unblock testing quickly, you can create placeholder recipes:

```swift
private func extractRecipe(
    from videoURL: URL,
    mode: ExtractionMode,
    transcript: String?,
    onScreenText: String?,
    provenanceMetadata: ProvenanceMetadata?
) async throws -> Recipe {

    // TEMPORARY: Create placeholder recipe for testing
    let title: String
    let description: String

    switch mode {
    case .audioTranscript:
        title = "Recipe from Audio"
        description = "Extracted using audio transcript: \(transcript?.prefix(100) ?? "")"
    case .onScreenText:
        title = "Recipe from On-Screen Text"
        description = "Extracted using OCR: \(onScreenText?.prefix(100) ?? "")"
    case .visualFrames:
        title = "Recipe from Visual Analysis"
        description = "Extracted using frame-by-frame visual analysis"
    }

    return Recipe(
        title: title,
        recipeDescription: description,
        ingredients: [
            Ingredient(item: "Placeholder ingredient", quantity: "1", unit: "cup")
        ],
        steps: [
            Step(order: 1, instruction: "Placeholder step - real extraction not yet implemented")
        ],
        provenanceMetadata: provenanceMetadata,
        dateCreated: Date()
    )
}
```

This lets you test the entire flow (Share Extension → Deep Link → Import → Paywall) while you work on the real extraction logic.

---

## Next Steps After Implementation

1. Test on physical device
2. Import videos in all three modes
3. Verify recipes are created correctly
4. Check attribution is preserved
5. Confirm paywall shows for visual mode (non-premium)

---

## Need Help?

If you get stuck on data model conversion or API signatures, check:
- `ARCHITECTURE_NOTES.md` - Has API signatures for existing services
- `HeirloomVideoLab/Features/VideoImport/Models/VideoRecipeModels.swift` - Data models
- `Heirloom/Core/Models/Recipe.swift` - Your Recipe model structure
