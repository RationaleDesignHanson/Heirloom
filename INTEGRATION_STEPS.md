# Share Extension Integration Steps

## Step 1: Add Files to Xcode Targets ⚙️

### Files for BOTH Main App + Share Extension:
**Right-click each file → Show File Inspector → Check both targets**

```
Heirloom/Core/Config/SharedConstants.swift
Heirloom/Core/Models/ExtractionMode.swift
Heirloom/Core/Models/AudioAnalysisResult.swift
Heirloom/Core/Models/OnScreenTextResult.swift
Heirloom/Core/Models/PendingVideoImport.swift
Heirloom/Core/Models/VideoImportResult.swift
Heirloom/Core/Services/Video/PlatformDetector.swift
Heirloom/Core/Services/Video/RecipeKeywords.swift
```

**Also need** `SocialMetadata` struct - but it's embedded in SocialMetadataService.swift.
You may need to extract it to a separate file or duplicate it in Share Extension.

### Files for Main App ONLY:
**These should already be in Heirloom target, just verify**

```
Heirloom/Core/Design/Components/CreatorAttributionBadge.swift
Heirloom/Features/Recipes/Components/RecipeSourceSection.swift
Heirloom/Features/Recipes/VideoImport/UnifiedVideoImportView.swift
Heirloom/Core/Services/Video/AudioAnalyzer.swift
Heirloom/Core/Services/Video/OnScreenTextDetector.swift
Heirloom/Core/Services/Video/WatermarkDetector.swift
Heirloom/Core/Services/Video/AttributionResolver.swift
Heirloom/Core/Services/Video/SocialMetadataService.swift
Heirloom/Core/Services/Video/PendingImportManager.swift
Heirloom/Core/Services/Video/PendingImportProcessor.swift
```

### Files for Share Extension ONLY:
```
HeirloomShareExtension/ShareExtensionView.swift
HeirloomShareExtension/ShareViewController.swift
```

### Test Files:
**Add to HeirloomTests target**
```
HeirloomTests/PlatformDetectorTests.swift
HeirloomTests/RecipeKeywordsTests.swift
HeirloomTests/AudioAnalyzerModeSelectionTests.swift
```

---

## Step 2: Verify App Groups ✅

**Already configured!** Both entitlements files have:
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.matthanson.heirloom.shared</string>
</array>
```

**In Xcode:**
1. Select Heirloom target → Signing & Capabilities
2. Verify "App Groups" capability exists with `group.com.matthanson.heirloom.shared` checked
3. Repeat for HeirloomShareExtension target

---

## Step 3: Verify URL Scheme ✅

**Already configured!** `heirloom://` URL scheme is registered in Info.plist.

---

## Step 4: Extend Deep Link Handling 🔧

### A. Add Published State to DeepLinkHandler

**File**: `Heirloom/Core/Services/DeepLink/DeepLinkHandler.swift`

**Find** (around line 20):
```swift
// URL import state (for share extension)
@Published var pendingImportURL: URL?
@Published var showURLImportSheet = false
```

**Add after**:
```swift
// Video import state (for share extension video imports)
@Published var pendingVideoImportID: UUID?
@Published var showVideoImportSheet = false
```

### B. Extend handleHeirloomURL Method

**Find** (around line 199):
```swift
} else if components.host == "import" {
    // Handle URL import from share extension
    guard let urlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
          let importURL = URL(string: urlString) else {
        Log.error("Invalid import URL in heirloom:// URL", category: .general)
        DeviceLogger.shared.log("❌ [DeepLink] Invalid import URL in heirloom:// URL")
        return
    }

    Log.info("Extracted import URL from deep link", category: .general, metadata: ["importUrl": importURL.absoluteString])
    DeviceLogger.shared.log("✅ [DeepLink] Extracted import URL: \(importURL.absoluteString)")

    handleURLImport(importURL)
```

**Replace with**:
```swift
} else if components.host == "import" {
    // Check for video import with ID (new Share Extension format)
    if let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
       let importID = UUID(uuidString: idString) {
        Log.info("Extracted video import ID from deep link", category: .general, metadata: ["importId": importID.uuidString])
        DeviceLogger.shared.log("✅ [DeepLink] Extracted video import ID: \(importID.uuidString)")

        handleVideoImport(importID)
        return
    }

    // Fallback: Handle URL import (old format)
    if let urlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
       let importURL = URL(string: urlString) {
        Log.info("Extracted import URL from deep link", category: .general, metadata: ["importUrl": importURL.absoluteString])
        DeviceLogger.shared.log("✅ [DeepLink] Extracted import URL: \(importURL.absoluteString)")

        handleURLImport(importURL)
        return
    }

    Log.error("Invalid import parameters in heirloom:// URL", category: .general)
    DeviceLogger.shared.log("❌ [DeepLink] Invalid import parameters in heirloom:// URL")
```

### C. Add handleVideoImport Method

**Find** the `handleURLImport` method (around line 281) and **add after it**:
```swift
private func handleVideoImport(_ importID: UUID) {
    Log.info("Handling video import from share extension", category: .general, metadata: ["importId": importID.uuidString])
    DeviceLogger.shared.log("🎥 [DeepLink] Handling video import from share extension: \(importID.uuidString)")

    // Store import ID for import flow
    pendingVideoImportID = importID
    showVideoImportSheet = true

    Log.info("Video import sheet triggered", category: .ui)
    DeviceLogger.shared.log("✅ [DeepLink] Video import sheet triggered")
}
```

### D. Add clearPendingVideoImport Method

**Find** the `clearPendingImport` method (around line 342) and **add after it**:
```swift
/// Clear pending video import (called after processing)
func clearPendingVideoImport() {
    Log.debug("Clearing pending video import", category: .general)
    DeviceLogger.shared.log("🧹 [DeepLink] Clearing pending video import")
    pendingVideoImportID = nil
    showVideoImportSheet = false
}
```

---

## Step 5: Add Video Import Sheet to ContentView 📱

**File**: `Heirloom/App/HeirloomApp.swift`

**Find** (around line 828):
```swift
.sheet(isPresented: $deepLinkCoordinator.showURLImportSheet) {
    if let importURL = deepLinkCoordinator.pendingImportURL {
        RecipeImportView(url: importURL)
            .onDisappear {
                deepLinkCoordinator.clearPendingImport()
            }
    }
}
```

**Add after**:
```swift
.sheet(isPresented: $deepLinkCoordinator.showVideoImportSheet) {
    if let importID = deepLinkCoordinator.pendingVideoImportID {
        UnifiedVideoImportView(pendingImportID: importID)
            .environmentObject(ServiceContainer.shared.resolve(SubscriptionManager.self))
            .environmentObject(ServiceContainer.shared.resolve(PaywallManager.self))
            .onDisappear {
                deepLinkCoordinator.clearPendingVideoImport()
            }
    }
}
```

---

## Step 6: Update UnifiedVideoImportView for Deep Link Support 🔧

**File**: `Heirloom/Features/Recipes/VideoImport/UnifiedVideoImportView.swift`

**Find** the struct declaration (line 4):
```swift
struct UnifiedVideoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var paywallManager: PaywallManager

    @State private var selectedItem: PhotosPickerItem?
    @State private var importState: ImportState = .selecting
```

**Add optional init parameter**:
```swift
struct UnifiedVideoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var paywallManager: PaywallManager

    // Optional: Import from Share Extension via deep link
    let pendingImportID: UUID?

    @State private var selectedItem: PhotosPickerItem?
    @State private var importState: ImportState = .selecting
```

**Add default init**:
```swift
init(pendingImportID: UUID? = nil) {
    self.pendingImportID = pendingImportID
}
```

**Find** the `.task` modifier (around line 51) and update:
```swift
.task {
    // Initialize processor
    self.processor = await PendingImportProcessor.make(
        subscriptionManager: subscriptionManager,
        paywallManager: paywallManager
    )

    // If launched from Share Extension, process pending import
    if let importID = pendingImportID {
        await processPendingImport(importID)
    }
}
```

**Add new method** to handle pending imports:
```swift
private func processPendingImport(_ importID: UUID) async {
    importState = .analyzing(stage: "Loading video from Share Extension...")

    // Load pending import
    guard let pendingImport = await PendingImportManager.shared.load(id: importID) else {
        importState = .error("Could not find pending import")
        return
    }

    guard let videoURL = pendingImport.localVideoURL else {
        importState = .error("No video file available")
        return
    }

    self.videoURL = videoURL

    // Process using same flow as photo library import
    do {
        guard let processor = self.processor else {
            throw ImportError.extractionFailed("Processor not initialized")
        }

        importState = .analyzing(stage: "Analyzing audio...")

        let result = try await processor.analyzeVideo(at: videoURL)

        switch result {
        case .canProceedFree(let mode, let transcript, let onScreenText):
            importState = .extracting(mode: mode, progress: 0)

            let recipe = try await processor.processImport(
                pendingImport,
                mode: mode,
                transcript: transcript,
                onScreenText: onScreenText
            )

            importedRecipe = recipe
            importState = .success

            // Clean up pending import
            await PendingImportManager.shared.delete(id: importID)

        case .requiresPremium(let audioReasoning, let ocrReasoning):
            if subscriptionManager.isPremium {
                proceedWithVisualExtraction(videoURL: videoURL)
            } else {
                importState = .premiumRequired(
                    audioReasoning: audioReasoning,
                    ocrReasoning: ocrReasoning
                )
            }

        case .failed(let error):
            importState = .error(error.localizedDescription)
        }

    } catch {
        importState = .error(error.localizedDescription)
    }
}
```

---

## Step 7: Connect Extraction Pipelines (TODO in Code) 🚧

**File**: `Heirloom/Core/Services/Video/PendingImportProcessor.swift`

**Find** `extractRecipe` method (around line 134) - currently has TODOs.

You need to connect:
- **Audio transcript** → Existing VideoImport pipeline
- **On-screen text** → Existing VideoImport pipeline (with OCR text as input)
- **Visual frames** → Existing ASMRVideoImport pipeline

Reference ARCHITECTURE_NOTES.md for the exact API signatures of existing services.

---

## Step 8: Build and Test 🧪

### Build Steps:
1. Clean Build Folder (⇧⌘K)
2. Build main app target
3. Build HeirloomShareExtension target
4. Build HeirloomTests target (for unit tests)

### Manual Testing (on physical device):
1. **Share Extension - Video**:
   - Open Photos app
   - Select a recipe video
   - Tap Share → Heirloom
   - Should save video and open main app

2. **Share Extension - URL**:
   - Copy TikTok URL
   - Open Safari, paste URL
   - Tap Share → Heirloom
   - Should detect platform

3. **Three-Tier Cascade**:
   - Import video with clear narration → Should use audio (free)
   - Import video with text overlays → Should use OCR (free)
   - Import silent ASMR video → Should show paywall

4. **Paywall**:
   - Non-premium user with ASMR video → Should show paywall
   - Premium user with ASMR video → Should proceed

5. **Attribution**:
   - Import TikTok video with watermark → Should detect @username
   - Import clean video → Should show "Add source credit"

### Run Unit Tests:
```bash
⌘U in Xcode
```

Expected: All tests pass
- PlatformDetectorTests: 6 tests
- RecipeKeywordsTests: 3 tests
- AudioAnalyzerModeSelectionTests: 2 tests

---

## Step 9: Verification Checklist ✅

Before considering feature complete:

- [ ] All files added to correct targets
- [ ] App Groups capability present in both targets
- [ ] URL scheme registered
- [ ] Deep link handling extended
- [ ] UnifiedVideoImportView handles deep links
- [ ] Share Extension shows in share sheet
- [ ] Videos copied to shared container
- [ ] Deep link opens main app
- [ ] Pending import processed successfully
- [ ] Three-tier cascade selects correct mode
- [ ] Paywall shows for visual extraction (non-premium)
- [ ] Attribution detected from watermarks
- [ ] Unit tests pass

---

## Known Issues & Limitations ⚠️

1. **SocialMetadata struct**: Currently embedded in SocialMetadataService.swift. You may need to extract it to a separate file to share with Share Extension, or accept that Share Extension won't fetch social metadata.

2. **Extraction Pipeline Connection**: The `extractRecipe` method in PendingImportProcessor has TODOs. You need to wire it to existing VideoImport/ and ASMRVideoImport/ services.

3. **Share Extension**: Cannot download videos from URLs directly (platform API restrictions). User must provide video file.

4. **Instagram oEmbed**: Frequently blocks API requests. Watermark detection is more reliable.

---

## Next Steps After Integration 🚀

1. Test on physical device (Share Extension requires device)
2. Connect extraction pipelines (complete TODOs)
3. Test with real TikTok/Instagram videos
4. Verify paywall triggers correctly
5. Review TESTING.md for comprehensive test matrix
6. Merge to main when ready

---

## Rollback Plan 🔄

If issues arise:
```bash
git checkout main
git branch -D feature/share-extension-unified-import
```

All changes are isolated to the feature branch. No changes to main until you're ready.
