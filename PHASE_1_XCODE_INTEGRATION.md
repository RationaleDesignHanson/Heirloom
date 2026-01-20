# Phase 1: Xcode Integration - Step by Step

**Time Estimate:** 30 minutes
**Difficulty:** Easy (mostly clicking checkboxes in Xcode)

---

## Prerequisites

- [ ] Xcode open with Heirloom.xcodeproj
- [ ] On branch `feature/share-extension-unified-import`
- [ ] All files visible in Xcode file navigator

---

## Step 1.1: Verify Share Extension Target Exists (5 min)

### Check if HeirloomShareExtension target exists:

1. In Xcode, click on project file (blue icon at top of navigator)
2. Look at TARGETS list
3. **Expected targets:**
   - [ ] Heirloom (main app)
   - [ ] HeirloomShareExtension (share extension)
   - [ ] HeirloomTests or HeirloomTestsV2 (tests)

### If HeirloomShareExtension doesn't exist:

**Create it:**
1. Click "+" at bottom of targets list
2. Choose "Share Extension" template
3. Name: `HeirloomShareExtension`
4. Language: Swift
5. Click Finish

**Important Settings:**
- Bundle ID: `com.matthanson.heirloom.ShareExtension`
- Deployment Target: iOS 17.0
- App Groups: `group.com.matthanson.heirloom.shared`

---

## Step 1.2: Add Files to BOTH Targets (Main + Share Extension) (10 min)

These 8 files must be included in **BOTH** Heirloom AND HeirloomShareExtension targets:

### Models (5 files):

1. **Heirloom/Core/Models/ExtractionMode.swift**
   - [ ] Right-click file → Show File Inspector (⌥⌘1)
   - [ ] Under "Target Membership": Check BOTH ☑️ Heirloom AND ☑️ HeirloomShareExtension

2. **Heirloom/Core/Models/AudioAnalysisResult.swift**
   - [ ] Target Membership: ☑️ Heirloom, ☑️ HeirloomShareExtension

3. **Heirloom/Core/Models/OnScreenTextResult.swift**
   - [ ] Target Membership: ☑️ Heirloom, ☑️ HeirloomShareExtension

4. **Heirloom/Core/Models/PendingVideoImport.swift**
   - [ ] Target Membership: ☑️ Heirloom, ☑️ HeirloomShareExtension

5. **Heirloom/Core/Models/VideoImportResult.swift**
   - [ ] Target Membership: ☑️ Heirloom, ☑️ HeirloomShareExtension

### Services (3 files):

6. **Heirloom/Core/Config/SharedConstants.swift**
   - [ ] Target Membership: ☑️ Heirloom, ☑️ HeirloomShareExtension

7. **Heirloom/Core/Services/Video/PlatformDetector.swift**
   - [ ] Target Membership: ☑️ Heirloom, ☑️ HeirloomShareExtension

8. **Heirloom/Core/Services/Video/RecipeKeywords.swift**
   - [ ] Target Membership: ☑️ Heirloom, ☑️ HeirloomShareExtension

---

## Step 1.3: Add Files to Main App Only (5 min)

These files should only be in the **Heirloom** target (not Share Extension):

### Core Services - Video Processing (Check each):

- [ ] **Heirloom/Core/Services/Video/AudioAnalyzer.swift** → ☑️ Heirloom only
- [ ] **Heirloom/Core/Services/Video/OnScreenTextDetector.swift** → ☑️ Heirloom only
- [ ] **Heirloom/Core/Services/Video/WatermarkDetector.swift** → ☑️ Heirloom only
- [ ] **Heirloom/Core/Services/Video/AttributionResolver.swift** → ☑️ Heirloom only
- [ ] **Heirloom/Core/Services/Video/SocialMetadataService.swift** → ☑️ Heirloom only
- [ ] **Heirloom/Core/Services/Video/PendingImportManager.swift** → ☑️ Heirloom only
- [ ] **Heirloom/Core/Services/Video/PendingImportProcessor.swift** → ☑️ Heirloom only

### Deep Link (Check):

- [ ] **Heirloom/Core/Services/DeepLink/DeepLinkHandler.swift** → ☑️ Heirloom only

### UI Files (Check):

- [ ] **Heirloom/App/HeirloomApp.swift** → ☑️ Heirloom only
- [ ] **Heirloom/Features/Recipes/VideoImport/UnifiedVideoImportView.swift** → ☑️ Heirloom only

### Modified Existing Files (Verify):

- [ ] **Heirloom/Features/Subscription/PaywallManager.swift** → ☑️ Heirloom only
- [ ] **Heirloom/Core/Models/ProvenanceMetadata.swift** → ☑️ Heirloom only

---

## Step 1.4: Add Files to Share Extension Only (2 min)

These files should only be in **HeirloomShareExtension** target:

- [ ] **HeirloomShareExtension/ShareViewController.swift** → ☑️ HeirloomShareExtension only
- [ ] **HeirloomShareExtension/ShareExtensionView.swift** → ☑️ HeirloomShareExtension only

**Verify Info.plist:**
- [ ] HeirloomShareExtension should have its own `Info.plist`
- [ ] Contains `NSExtension` dictionary with proper configuration

---

## Step 1.5: Add Test Files to Test Target (2 min)

Verify these are in **HeirloomTestsV2** target:

- [ ] **HeirloomTestsV2/Unit/Features/ShareExtension/PlatformDetectorBaselineTests.swift**
- [ ] **HeirloomTestsV2/Unit/Features/ShareExtension/PlatformDetectorAdversarialTests.swift**
- [ ] **HeirloomTestsV2/Unit/Features/ShareExtension/RecipeKeywordsTests.swift**
- [ ] **HeirloomTestsV2/Unit/Features/ShareExtension/AudioAnalyzerTests.swift**

---

## Step 1.6: Verify App Groups Configuration (5 min)

### Main App (Heirloom):

1. Select Heirloom target
2. Go to "Signing & Capabilities" tab
3. **Check for "App Groups" capability:**
   - [ ] App Groups capability present
   - [ ] Identifier: `group.com.matthanson.heirloom.shared` is checked

**If App Groups missing:**
```
1. Click "+ Capability"
2. Search for "App Groups"
3. Add it
4. Click "+" under App Groups
5. Add: group.com.matthanson.heirloom.shared
```

### Share Extension (HeirloomShareExtension):

1. Select HeirloomShareExtension target
2. Go to "Signing & Capabilities" tab
3. **Check for "App Groups" capability:**
   - [ ] App Groups capability present
   - [ ] **SAME identifier**: `group.com.matthanson.heirloom.shared` is checked

**Critical:** Both targets MUST use the exact same App Group identifier!

---

## Step 1.7: Verify URL Scheme for Deep Links (2 min)

### Main App Only (Heirloom):

1. Select Heirloom target
2. Go to "Info" tab
3. Expand "URL Types"
4. **Verify entry exists:**
   - [ ] URL Schemes: `heirloom`
   - [ ] Identifier: `com.matthanson.heirloom`
   - [ ] Role: Editor

**If missing:**
```
1. Click "+" under URL Types
2. URL Schemes: heirloom
3. Identifier: com.matthanson.heirloom
4. Role: Editor
```

**Do NOT add URL scheme to Share Extension** (not needed)

---

## Step 1.8: Verify Anthropic API Key in Config (3 min)

### Check Config.xcconfig:

1. Open `Heirloom/Config/Config.xcconfig` (or similar path)
2. **Verify this line exists:**
   ```
   DEFAULT_ANTHROPIC_KEY = sk-ant-api03-...your-corporate-key...
   ```

**If file doesn't exist or key missing:**

**Option A: Create Config.xcconfig**
```bash
# Create file
touch Heirloom/Config/Config.xcconfig

# Add this content:
DEFAULT_ANTHROPIC_KEY = sk-ant-api03-YOUR-CORPORATE-KEY-HERE
```

**Option B: Add to Info.plist directly**
1. Open Heirloom/Info.plist (XML view)
2. Add:
```xml
<key>DEFAULT_ANTHROPIC_KEY</key>
<string>sk-ant-api03-YOUR-CORPORATE-KEY-HERE</string>
```

### Verify Info.plist reads it:

1. Open Heirloom target → Build Settings
2. Search for "Preprocessor Macros" or "Info.plist Values"
3. Verify `DEFAULT_ANTHROPIC_KEY` is defined

**Test it in code:**
```swift
// This should NOT be nil
let key = Bundle.main.object(forInfoDictionaryKey: "DEFAULT_ANTHROPIC_KEY") as? String
print("API Key present: \(key != nil)")
```

---

## Step 1.9: Clean Build (2 min)

### Clean All Targets:

1. **Product → Clean Build Folder** (⇧⌘K)
2. Wait for "Clean Finished"

---

## Step 1.10: Build Main App (5 min)

### Build Heirloom Target:

1. Select Heirloom scheme (top toolbar)
2. Select device or simulator
3. **Product → Build** (⌘B)

**Expected Result:**
- [ ] Build succeeds (✅ "Build Succeeded")
- [ ] Zero errors
- [ ] Zero warnings (or only pre-existing warnings)

**If build fails:**
- Check error messages
- Common issues:
  - Missing target membership (go back to Step 1.2)
  - Import errors (verify shared files)
  - SwiftData/actor errors (check @MainActor annotations)

---

## Step 1.11: Build Share Extension (3 min)

### Build HeirloomShareExtension Target:

1. Select HeirloomShareExtension scheme (if available)
   - If not available: Edit Scheme → Create new scheme for HeirloomShareExtension

2. **Product → Build** (⌘B)

**Expected Result:**
- [ ] Build succeeds (✅ "Build Succeeded")
- [ ] Zero errors
- [ ] Can import shared models (ExtractionMode, PendingVideoImport, etc.)

**If build fails:**
- Most common: Missing target membership for shared files
- Verify Step 1.2 was completed correctly

---

## Step 1.12: Run Unit Tests (3 min)

### Run All Tests:

1. Select Heirloom scheme
2. Select Test target (HeirloomTestsV2)
3. **Product → Test** (⌘U)

**Expected Result:**
- [ ] All tests pass
- [ ] Specifically verify:
  - [ ] PlatformDetectorBaselineTests (13 tests)
  - [ ] PlatformDetectorAdversarialTests (12 tests)
  - [ ] RecipeKeywordsTests (16 tests)
  - [ ] AudioAnalyzerTests (14 tests)
- [ ] **Total new tests: 55 tests pass**

**If tests fail:**
- Read failure messages
- Common issues:
  - Model initialization errors
  - Missing dependencies
  - @MainActor context issues

---

## Step 1.13: Build & Run on Device (5 min)

### Connect Physical iPhone:

⚠️ **CRITICAL**: Share Extensions cannot be tested in simulator. You MUST use a real device.

1. Connect iPhone via USB
2. Unlock device
3. Trust computer if prompted
4. In Xcode, select your iPhone from device list (top toolbar)

### Build and Run:

1. Select Heirloom scheme
2. Select your physical iPhone
3. **Product → Run** (⌘R)

**Expected Result:**
- [ ] App installs on device
- [ ] App launches successfully
- [ ] No immediate crashes
- [ ] Home screen appears

### Verify Share Extension is Installed:

1. On iPhone, go to **Settings → General → Share Extension**
2. OR go to Photos app → Select any photo → Tap Share button
3. Scroll down share sheet, tap "Edit Actions" or "More"
4. **Look for "Heirloom"**
   - [ ] Heirloom appears in list
   - [ ] Toggle is ON (enabled)

**If Heirloom doesn't appear:**
- Rebuild and reinstall app
- Check Share Extension target is included in build
- Verify Info.plist in Share Extension has NSExtension configuration

---

## ✅ Phase 1 Complete Checklist

Before proceeding to Phase 2, verify ALL items:

### Xcode Configuration:
- [ ] HeirloomShareExtension target exists
- [ ] 8 shared files in BOTH targets (Main + Share Extension)
- [ ] Main app files only in Heirloom target
- [ ] Share Extension files only in HeirloomShareExtension target
- [ ] Test files in HeirloomTestsV2 target

### Capabilities:
- [ ] App Groups enabled in Main App: `group.com.matthanson.heirloom.shared`
- [ ] App Groups enabled in Share Extension: `group.com.matthanson.heirloom.shared`
- [ ] URL Scheme in Main App: `heirloom://`

### Build Success:
- [ ] Main app builds without errors (⌘B)
- [ ] Share Extension builds without errors
- [ ] All unit tests pass (⌘U) - 55 new tests
- [ ] App runs on physical iPhone (⌘R)
- [ ] Share Extension appears in iOS share sheet

### API Key:
- [ ] Corporate Anthropic key in Config.xcconfig or Info.plist
- [ ] Key accessible via `Bundle.main.object(forInfoDictionaryKey: "DEFAULT_ANTHROPIC_KEY")`

---

## 🚨 Common Issues & Fixes

### Issue 1: "Cannot find type 'PendingVideoImport' in scope"
**Fix:** Add `PendingVideoImport.swift` to BOTH targets (Step 1.2)

### Issue 2: Share Extension doesn't appear in share sheet
**Fix:**
- Rebuild app
- Delete app from device, reinstall
- Check NSExtension in Share Extension Info.plist

### Issue 3: "No such module 'Heirloom'"
**Fix:** Don't import Heirloom in Share Extension. Shared files should be added to target membership instead.

### Issue 4: App Groups not working
**Fix:**
- Verify EXACT same identifier in both targets
- Enable App Groups capability (not just add to plist)
- Check provisioning profile includes App Groups

### Issue 5: Deep link not opening app
**Fix:**
- Verify URL scheme `heirloom` in Main App Info → URL Types
- Test with: `xcrun simctl openurl booted "heirloom://import?id=test"`

---

## 📊 Time Tracker

| Step | Estimated | Actual | Status |
|------|-----------|--------|--------|
| 1.1 Verify targets | 5 min | ___ min | ⬜ |
| 1.2 Add shared files | 10 min | ___ min | ⬜ |
| 1.3 Add main app files | 5 min | ___ min | ⬜ |
| 1.4 Add Share Ext files | 2 min | ___ min | ⬜ |
| 1.5 Add test files | 2 min | ___ min | ⬜ |
| 1.6 App Groups | 5 min | ___ min | ⬜ |
| 1.7 URL Scheme | 2 min | ___ min | ⬜ |
| 1.8 API Key | 3 min | ___ min | ⬜ |
| 1.9 Clean build | 2 min | ___ min | ⬜ |
| 1.10 Build main app | 5 min | ___ min | ⬜ |
| 1.11 Build Share Ext | 3 min | ___ min | ⬜ |
| 1.12 Run tests | 3 min | ___ min | ⬜ |
| 1.13 Run on device | 5 min | ___ min | ⬜ |
| **TOTAL** | **30 min** | **___ min** | ⬜ |

---

## ✅ Ready for Phase 2?

**All items above complete?** → Proceed to **PHASE_2_DEVICE_SETUP.md**

**Any issues?** → Stop and fix before continuing. Phase 2 requires working builds.

---

**Status:** Phase 1 - Xcode Integration
**Next:** Phase 2 - Device Testing Setup
