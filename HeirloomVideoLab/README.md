# HeirloomVideoLab - Setup Guide

## Overview

HeirloomVideoLab is an isolated development target for testing video-to-recipe extraction. All code files have been created and are ready to be added to Xcode.

**Status**: Week 1 - Mock Services Implementation ✅

## Files Created

### Core Files
- ✅ `App/VideoLabApp.swift` - Main entry point
- ✅ `Features/VideoImport/Protocols/VideoProcessingProtocols.swift` - Service protocols
- ✅ `Features/VideoImport/Models/VideoRecipeModels.swift` - Data models with attribution
- ✅ `Features/VideoImport/Services/MockVideoServices.swift` - Mock implementations
- ✅ `Features/VideoImport/Views/VideoImportView.swift` - Video selection UI
- ✅ `Features/VideoImport/Views/VideoProcessingView.swift` - Progress indicator UI
- ✅ `Features/VideoImport/Views/VideoRecipeReviewView.swift` - Recipe review UI with attribution

### Key Features Implemented
- ✅ **Attribution Support**: VideoSourceAttribution struct tracks creator, platform, URL
- ✅ **Mock Pipeline**: Full video → recipe flow without real transcription
- ✅ **Progress Tracking**: Deterministic progress indicators
- ✅ **Review UI**: Edit ingredients, steps, and add attribution before saving

## Creating the Xcode Target (When Ready)

**⚠️ Wait until your main app session is complete to avoid project file conflicts**

### Step 1: Create New Target

1. Open `Heirloom.xcodeproj` in Xcode
2. File → New → Target
3. Select **iOS → App**
4. Configure:
   - Product Name: `HeirloomVideoLab`
   - Bundle Identifier: `com.matthanson.heirloom.videolab`
   - Language: Swift
   - User Interface: SwiftUI
   - Uncheck "Include Tests" (we'll add manually)

### Step 2: Add Files to Target

1. Select all files in `HeirloomVideoLab/` folder in Finder
2. Drag into Xcode project navigator under "HeirloomVideoLab" group
3. In "Add Files" dialog:
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ Add to targets: **HeirloomVideoLab**

### Step 3: Link Core Models (Shared with Main App)

These files should be added to **BOTH** targets (Heirloom AND HeirloomVideoLab):

1. Select each file in Xcode
2. File Inspector → Target Membership
3. Check **both** boxes:
   - ✅ Heirloom
   - ✅ HeirloomVideoLab

**Files to share**:
- `Heirloom/Core/Models/Recipe.swift`
- `Heirloom/Core/Models/Ingredient.swift`
- `Heirloom/Core/Models/ProvenanceMetadata.swift`
- Any other Core/Models files needed

### Step 4: Configure Build Settings

1. Select HeirloomVideoLab target
2. Build Settings → Search for:
   - `PRODUCT_BUNDLE_IDENTIFIER`: `com.matthanson.heirloom.videolab`
   - `SWIFT_ACTIVE_COMPILATION_CONDITIONS`: Add `VIDEO_LAB`
   - `ASSETCATALOG_COMPILER_APPICON_NAME`: `AppIcon` (or create VideoLab variant)

### Step 5: Update VideoLabApp.swift Schema

Once Recipe/Ingredient models are linked, update `VideoLabApp.swift` line 32-33:

```swift
let config = ModelConfiguration(
    schema: Schema([Recipe.self, Ingredient.self]),  // ← Add models here
    url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("VideoLabRecipes.store")
)

modelContainer = try ModelContainer(
    for: Schema([Recipe.self, Ingredient.self]),  // ← And here
    configurations: config
)
```

### Step 6: Create VideoLab App Icon (Optional)

1. Create orange-tinted variant of main app icon
2. Add to `HeirloomVideoLab/Resources/Assets.xcassets/AppIcon`
3. Makes it easy to distinguish from main app on device

### Step 7: Build & Run

1. Select "HeirloomVideoLab" scheme
2. Select iPhone simulator
3. Press ⌘R to build and run
4. App should launch with "Import Video Recipe" button

## Expected Behavior (Week 1)

1. **Tap "Import Video Recipe"**
   - Video picker appears (PHPicker)
   - Select any video from camera roll

2. **Processing View**
   - Shows deterministic progress
   - ~10 seconds total (mocked)
   - Stages: Audio → Transcribing → Frames → Structuring

3. **Review View**
   - Pre-filled with mock "Chocolate Chip Cookies" recipe
   - **Attribution section at top** (required)
   - Edit ingredients, steps, servings
   - View transcript
   - Save button (currently just prints to console)

## Attribution Integration

The review UI prominently displays attribution fields:
- **Creator Name** (required) - e.g., "Gordon Ramsay"
- **Video Title** (optional) - e.g., "Perfect Chocolate Chip Cookies"
- **Platform** (picker) - YouTube, Instagram, TikTok, Camera Roll, etc.
- **Notes** (optional) - Additional context

Attribution is stored in `VideoImportMetadata.attribution` and will be saved to Recipe's ProvenanceMetadata during integration.

## Troubleshooting

### "Cannot find type 'Recipe'" error
- Recipe model not linked to VideoLab target
- Fix: Add Recipe.swift to HeirloomVideoLab target membership

### "No such module 'SwiftData'" error
- Target not configured properly
- Fix: Ensure iOS 17+ deployment target

### App crashes on launch
- ModelContainer configuration issue
- Fix: Check Schema([]) is updated with actual models

### Video picker doesn't show
- Missing photo library permission
- Fix: Add `NSPhotoLibraryUsageDescription` to Info.plist

## Next Steps (Week 2)

Once Week 1 is validated:

1. Replace MockAudioExtractionService with real AVFoundation implementation
2. Integrate WhisperKit for transcription
3. Add Vision framework for OCR
4. Connect to AnthropicAIService for recipe structuring

## Testing

Once target is created, run:

```bash
xcodebuild test -scheme HeirloomVideoLab -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Questions?

Refer to full implementation plan at:
`/Users/matthanson/.claude/plans/lucky-whistling-truffle.md`
