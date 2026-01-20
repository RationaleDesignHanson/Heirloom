# Share Extension + Unified Video Import Implementation Summary

## Overview
This feature adds two related capabilities:
1. **Share Extension** - Import videos/URLs directly from TikTok, Instagram, Photos, etc.
2. **Unified Video Import** - Single "Import from Video" option with automatic three-tier extraction

## Three-Tier Extraction Cascade

### Tier 1: Audio Transcript (FREE)
- Uses existing `WhisperKitTranscriptionService`
- Analyzes audio for spoken recipe instructions
- Checks: word count, speech confidence, recipe relevance
- **Thresholds**:
  - ≥30 words
  - ≥20 words per minute (not just background music)
  - ≥0.4 speech confidence
  - ≥0.15 recipe relevance score

### Tier 2: On-Screen Text (FREE - NEW)
- Uses Vision framework OCR
- Extracts text from 8 key frames across video
- Looks for recipe ingredients, measurements, instructions
- **Thresholds**:
  - ≥20% recipe relevance score
  - ≥50% OCR confidence

### Tier 3: Visual Frames (PREMIUM)
- Uses existing ASMR video extraction pipeline
- Frame-by-frame visual analysis
- **Hard paywall** - requires subscription
- PaywallTrigger: `.visualVideoExtraction`

## Architecture Integration

### Extensions to Existing Code
- **ProvenanceMetadata** - Added `SocialPlatform` and `AttributionDetectionMethod` enums
- **PaywallManager** - Added `.visualVideoExtraction` case (hard wall, no cooldown)
- **WhisperKitTranscriptionService** - Used as-is for audio analysis

### New Services
- **PlatformDetector** - Detects TikTok, Instagram, YouTube, Facebook from URLs
- **AudioAnalyzer** - Wraps WhisperKitTranscriptionService with recipe relevance scoring
- **RecipeKeywords** - 200+ keywords for recipe relevance scoring
- **OnScreenTextDetector** - Vision OCR for on-screen recipe text
- **WatermarkDetector** - Vision OCR for creator watermarks in video corners
- **AttributionResolver** - Consolidates attribution from multiple sources
- **SocialMetadataService** - Fetches creator info via oEmbed APIs
- **PendingImportProcessor** - Three-tier cascade orchestrator
- **PendingImportManager** - Manages Share Extension → Main App handoff

### New UI Components
- **ShareExtensionView** - SwiftUI view for Share Extension
- **UnifiedVideoImportView** - Main app video import with paywall UI
- **CreatorAttributionBadge** - Platform-specific creator badge
- **RecipeSourceSection** - Recipe detail source attribution section

## Attribution Priority
1. **URL Metadata** (most reliable) - Username extracted from URL
2. **oEmbed API** - Creator info from TikTok/Instagram/YouTube APIs
3. **Watermark Detection** (≥60% confidence) - OCR from video corners

## App Groups & Deep Linking
- **App Group**: `group.com.matthanson.heirloom.shared`
- **Deep Link**: `heirloom://import?id=<UUID>`
- Share Extension saves video to shared container → opens main app via deep link → main app processes

## File Structure

```
Heirloom/
├── Core/
│   ├── Models/
│   │   ├── ExtractionMode.swift
│   │   ├── AudioAnalysisResult.swift
│   │   ├── OnScreenTextResult.swift
│   │   ├── PendingVideoImport.swift
│   │   ├── VideoImportResult.swift
│   │   └── SocialMetadata.swift
│   ├── Config/
│   │   └── SharedConstants.swift
│   ├── Services/
│   │   ├── Store/
│   │   │   └── PaywallManager.swift (modified)
│   │   └── Video/
│   │       ├── PlatformDetector.swift
│   │       ├── RecipeKeywords.swift
│   │       ├── AudioAnalyzer.swift
│   │       ├── OnScreenTextDetector.swift
│   │       ├── WatermarkDetector.swift
│   │       ├── AttributionResolver.swift
│   │       ├── SocialMetadataService.swift
│   │       ├── PendingImportProcessor.swift
│   │       └── PendingImportManager.swift
│   └── Design/
│       └── Components/
│           └── CreatorAttributionBadge.swift
├── Features/
│   └── Recipes/
│       ├── VideoImport/
│       │   └── UnifiedVideoImportView.swift
│       └── Components/
│           └── RecipeSourceSection.swift
└── HeirloomShareExtension/
    ├── ShareExtensionView.swift
    └── ShareViewController.swift (modified)
```

## Testing
See `TESTING.md` for comprehensive test matrix.

Unit tests created:
- `PlatformDetectorTests.swift` - URL detection and parsing
- `RecipeKeywordsTests.swift` - Recipe relevance scoring
- `AudioAnalyzerModeSelectionTests.swift` - Mode selection logic

## Next Steps (Before Merging to Main)

1. **Add files to Xcode targets**
   - Add new Swift files to Heirloom and HeirloomShareExtension targets
   - Add test files to HeirloomTests target

2. **Configure App Group**
   - Verify `group.com.matthanson.heirloom.shared` in both targets
   - Check Signing & Capabilities

3. **Register URL Scheme**
   - Add `heirloom://` URL scheme to main app Info.plist

4. **Connect Extraction Pipelines**
   - Wire `PendingImportProcessor.extractRecipe()` to:
     - Existing `VideoImport/` for audio/OCR modes
     - Existing `ASMRVideoImport/` for visual mode

5. **Manual Testing**
   - Run through TESTING.md checklist on physical device
   - Test Share Extension from TikTok, Instagram, Photos
   - Verify three-tier cascade with different video types
   - Confirm paywall triggers correctly

6. **Performance Validation**
   - Audio analysis: < 10s
   - OCR analysis: < 15s
   - Watermark detection: < 5s

## Known Limitations
- Share Extension cannot download videos directly from URLs (platform API restrictions)
- Instagram oembed API frequently blocks requests
- Watermark detection only works for visible @username in corners
- Short URLs (vm.tiktok.com) require network to expand

## Subscription Model
This feature uses existing subscription infrastructure:
- **Free tier**: Audio + OCR extraction
- **Premium tier**: Visual extraction (hard wall)
- No credit system
- Subscription status: `.none`, `.trial`, `.monthly`
