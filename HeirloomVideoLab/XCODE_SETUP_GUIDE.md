# Xcode Target Setup & Test-Fix-Test Guide

**Purpose**: Step-by-step Xcode target creation with rapid iteration workflow for debugging

**Estimated Time**: 30 minutes initial setup + ongoing test-fix-test cycles

---

## Part 1: Initial Xcode Target Creation (30 minutes)

### Step 1: Create HeirloomVideoLab Target (5 min)

1. **Open Xcode project**:
   ```bash
   cd /Users/matthanson/Heirloom
   open Heirloom.xcodeproj
   ```

2. **Create new target**:
   - Click project name in navigator
   - Click `+` at bottom of targets list
   - **Template**: iOS → App
   - Click **Next**

3. **Configure target**:
   ```
   Product Name:    HeirloomVideoLab
   Team:            [Your Development Team]
   Organization ID: com.matthanson
   Bundle ID:       com.matthanson.heirloom.videolab
   Interface:       SwiftUI
   Language:        Swift
   ✅ Include Tests
   ```

4. **Click Finish**

5. **Delete auto-generated files** (we have our own):
   - Delete `HeirloomVideoLab/HeirloomVideoLabApp.swift` (auto-generated)
   - Delete `HeirloomVideoLab/ContentView.swift` (auto-generated)
   - Delete `HeirloomVideoLab/Assets.xcassets` (auto-generated, we'll use our own)
   - Keep the test target folder

✅ **Checkpoint**: You should now see HeirloomVideoLab target in target list

---

### Step 2: Add Implementation Files (10 min)

**Add all HeirloomVideoLab files to target**:

1. **Select App folder**:
   - Navigate to `HeirloomVideoLab/App/`
   - Select `VideoLabApp.swift`
   - File Inspector (⌥⌘1) → Target Membership
   - ✅ Check `HeirloomVideoLab`

2. **Repeat for all directories**:
   ```
   HeirloomVideoLab/
   ├── App/
   │   └── VideoLabApp.swift                    [Add ✅]
   ├── Features/VideoImport/
   │   ├── Protocols/
   │   │   └── VideoProcessingProtocols.swift    [Add ✅]
   │   ├── Models/
   │   │   └── VideoRecipeModels.swift           [Add ✅]
   │   ├── Services/
   │   │   ├── MockVideoServices.swift           [Add ✅]
   │   │   ├── AudioExtractionService.swift      [Add ✅]
   │   │   ├── WhisperKitTranscriptionService.swift [Add ✅]
   │   │   ├── FrameAnalysisService.swift        [Add ✅]
   │   │   ├── ClaudeRecipeStructurer.swift      [Add ✅]
   │   │   └── VideoRecipeProcessor.swift        [Add ✅]
   │   └── Views/
   │       ├── VideoImportView.swift             [Add ✅]
   │       ├── VideoProcessingView.swift         [Add ✅]
   │       └── VideoRecipeReviewView.swift       [Add ✅]
   ```

**Quick method**: Select all files in HeirloomVideoLab folder, then bulk-add to target

✅ **Checkpoint**: Build (⌘B) - Should have ~20 errors about missing Core models

---

### Step 3: Link Core Models from Main App (5 min)

**Share existing Core models between both targets**:

1. **Navigate to Heirloom/Core/Models/**:
   - Select `Recipe.swift`
   - File Inspector → Target Membership
   - ✅ Check `HeirloomVideoLab` (keep Heirloom checked too)

2. **Repeat for these Core files**:
   ```
   Heirloom/Core/Models/
   ├── Recipe.swift                [Add ✅ to both targets]
   ├── Ingredient.swift            [Add ✅ to both targets]
   └── ProvenanceMetadata.swift    [Add ✅ to both targets]

   Heirloom/Core/Services/AI/
   ├── Protocols/AIServiceProtocol.swift     [Add ✅ to both targets]
   └── Clients/AnthropicAIService.swift      [Add ✅ to both targets]
   ```

⚠️ **Important**: Keep both targets checked - these are shared files

✅ **Checkpoint**: Build (⌘B) - Should have fewer errors, mainly about WhisperKit

---

### Step 4: Add WhisperKit Package (5 min)

1. **File → Add Package Dependencies**

2. **Enter URL**:
   ```
   https://github.com/argmaxinc/WhisperKit
   ```

3. **Select version**:
   - Dependency Rule: **Up to Next Major Version**
   - Minimum: **0.7.2**

4. **Add to Target**:
   - ✅ Check `HeirloomVideoLab`
   - ⬜ Leave `Heirloom` unchecked (for now)

5. **Click Add Package**

6. **Wait for package resolution** (~30 seconds)

✅ **Checkpoint**: Build (⌘B) - Should succeed with 0 errors!

---

### Step 5: Remove Placeholder Types (2 min)

**Update WhisperKitTranscriptionService.swift**:

1. Open `HeirloomVideoLab/Features/VideoImport/Services/WhisperKitTranscriptionService.swift`

2. **Delete lines 11-67** (all placeholder types):
   ```swift
   // DELETE THESE:
   struct WhisperKit { ... }
   struct WhisperKitResult { ... }
   // ... all placeholder structs
   ```

3. **Add import at top** (around line 10):
   ```swift
   import WhisperKit
   ```

4. **Save**

**Update ClaudeRecipeStructurer.swift**:

1. Open `HeirloomVideoLab/Features/VideoImport/Services/ClaudeRecipeStructurer.swift`

2. **Delete lines 12-63** (placeholder protocol and types)

3. **Verify import** exists (should already be there):
   ```swift
   // These should now reference real types from Core
   ```

✅ **Checkpoint**: Build (⌘B) - Should succeed with 0 errors!

---

### Step 6: Create Test Target Files (3 min)

1. **Add test files to HeirloomVideoLabTests target**:

   Navigate to `HeirloomVideoLab/Tests/` and select all test files:
   ```
   - AudioExtractionServiceTests.swift
   - TranscriptionServiceTests.swift
   - FrameAnalysisServiceTests.swift
   - ClaudeRecipeStructurerTests.swift
   - VideoRecipeProcessorTests.swift
   ```

2. **For each file**:
   - File Inspector → Target Membership
   - ✅ Check `HeirloomVideoLabTests`

3. **Add TestResources to test bundle**:
   - Run: `./HeirloomVideoLab/Scripts/setup-test-resources.sh`
   - Drag `TestResources/` folder into Xcode
   - Select: **Create folder references** (blue folder icon)
   - Target: `HeirloomVideoLabTests`

✅ **Checkpoint**: Tests should be visible in Test Navigator (⌘6)

---

## Part 2: Test-Fix-Test Workflow (Iterative)

### Quick Build Validation

**Run after any code change**:

```bash
# Terminal (fastest)
xcodebuild -scheme HeirloomVideoLab -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Or in Xcode
⌘B
```

**Expected result**: ✅ Build Succeeded

---

### Test Cycle 1: Unit Tests (Simulator) - 1 minute

**Goal**: Validate all services compile and basic logic works

```bash
# Run all unit tests
xcodebuild test -scheme HeirloomVideoLab \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:HeirloomVideoLabTests
```

**Or in Xcode**: ⌘U

#### Expected Results

✅ **All tests should pass** (72/72)

```
Test Suite 'All tests' passed at 2026-01-XX XX:XX:XX
     Executed 72 tests, with 0 failures (0 unexpected) in 45.2 seconds
```

#### If Tests Fail

**Common Issue #1: "Test video not found"**

```
❌ Test failed: XCTSkip - Test video not found
```

**Fix**:
1. Check TestResources added to test target
2. Verify files exist: `ls HeirloomVideoLab/TestResources/Videos/`
3. Re-run setup script: `./HeirloomVideoLab/Scripts/setup-test-resources.sh`

**Common Issue #2: "Cannot find type in scope"**

```
❌ Error: Cannot find 'VideoRecipeProcessor' in scope
```

**Fix**:
1. Check file added to target: File Inspector → Target Membership
2. Verify `@testable import HeirloomVideoLab` at top of test file
3. Clean build folder: ⇧⌘K, then rebuild

**Common Issue #3: Tests timeout**

```
❌ Test exceeded 30 second timeout
```

**Fix**:
1. Mock services should be fast (<1 sec) - check you're using mocks
2. Increase timeout in test: `executionTimeAllowance = 60`
3. Check for infinite loops or deadlocks

---

### Test Cycle 2: Device Integration Test - 5 minutes

**Goal**: Validate WhisperKit works on physical device

⚠️ **Requires**: Physical iPhone connected via USB

```bash
# List connected devices
xcrun xctrace list devices

# Run on device (replace with your device name)
xcodebuild test -scheme HeirloomVideoLab \
  -destination 'platform=iOS,name=YOUR_DEVICE_NAME' \
  -only-testing:HeirloomVideoLabTests/TranscriptionServiceTests
```

**Or in Xcode**:
1. Select device in device dropdown
2. Test Navigator (⌘6)
3. Right-click TranscriptionServiceTests → Run

#### Expected Results

✅ **Transcription tests pass on device**

⚠️ **First run**: WhisperKit model downloads (30 sec - 2 min)
- You'll see: "Downloading base.en model..."
- Subsequent runs are fast

#### If Tests Fail on Device

**Common Issue #1: "WhisperKit not available"**

```
❌ Test failed: isAvailable = false
```

**Fix**:
1. WhisperKit doesn't work on simulator (expected)
2. Ensure testing on physical device
3. Check device has iOS 16+
4. Check internet connection (first run only)

**Common Issue #2: "Model download failed"**

```
❌ Failed to download model: Network error
```

**Fix**:
1. Check internet connection (WiFi or cellular)
2. Check available storage (need ~100MB)
3. Try smaller model: Change to `tiny.en` in code temporarily
4. Wait and retry - GitHub releases can be slow

**Common Issue #3: "Out of memory"**

```
❌ App crashed: Memory pressure
```

**Fix**:
1. Close other apps on device
2. Use smaller model: `tiny.en` instead of `base.en`
3. Test on newer device (iPhone 12+)

---

### Test Cycle 3: Manual App Test - 10 minutes

**Goal**: Full end-to-end test with real video

1. **Run app on device**:
   ```bash
   xcodebuild -scheme HeirloomVideoLab \
     -destination 'platform=iOS,name=YOUR_DEVICE' \
     -configuration Debug
   ```

   Or in Xcode: ⌘R with device selected

2. **Import test video**:
   - App launches → Tap "Import Video"
   - Select video from Photos (add a cooking video first)
   - Watch processing stages

3. **Validate each stage**:
   ```
   Stage 1: Audio Extraction (5%)
   ✓ Shows progress bar
   ✓ No errors
   ✓ Takes ~5-10 seconds

   Stage 2: Transcription (5-75%)
   ✓ Shows "Transcribing audio..."
   ✓ Progress updates smoothly
   ✓ Takes 30-120 seconds depending on video length

   Stage 3: Frame Analysis (75-85%) [Optional]
   ✓ Only runs if transcript confidence <0.85
   ✓ Shows "Analyzing frames..."
   ✓ Takes 10-30 seconds if enabled

   Stage 4: Structuring Recipe (85-100%)
   ✓ Shows "Structuring recipe..."
   ✓ Takes 5-15 seconds
   ✓ Reaches 100%

   Stage 5: Review
   ✓ Recipe fields populated
   ✓ Attribution section at top
   ✓ Can edit all fields
   ✓ Save button works
   ```

#### Quick Validation Checklist

- [ ] App launches without crash
- [ ] Can select video from Photos
- [ ] Processing progresses through all stages
- [ ] No ANRs or freezes
- [ ] Extracted recipe looks reasonable
- [ ] Attribution fields present
- [ ] Can save recipe
- [ ] Check console for cost estimate (~$0.02-0.03)

#### If App Crashes or Hangs

**Use Xcode Debugger**:

1. **Run with debugger attached** (⌘R)
2. **Check Console** (⇧⌘C) for errors:
   ```
   Look for:
   - "Fatal error: ..."
   - "Assertion failed: ..."
   - API errors from Claude
   - AVFoundation errors
   ```

3. **Set breakpoints**:
   - Open VideoRecipeProcessor.swift
   - Click line number gutter to add breakpoint
   - Rerun and step through (F6)

4. **Check memory**:
   - Debug Navigator (⌘7) → Memory
   - Should stay <500MB
   - Watch for leaks or spikes

**Common App Issues**:

**Issue: "Video has no audio track"**
- Expected for `silent_video.mp4` test
- Use a real cooking video with audio

**Issue: "Network error"**
- Check internet for Claude API
- Check API key in AnthropicAIService

**Issue: Processing hangs at X%**
- Check console for specific error
- May be WhisperKit download (first run)
- May be Claude API timeout (slow network)

---

## Part 3: Debug Workflow (When Things Break)

### Systematic Debugging Steps

**When build fails**:

1. **Read error message carefully**:
   - ⚠️ Yellow = Warning (ok to ignore initially)
   - ❌ Red = Error (must fix)

2. **Common patterns**:
   ```
   "Cannot find X in scope"
   → File not added to target

   "No such module 'X'"
   → Package dependency missing or not added

   "Ambiguous use of 'X'"
   → Name conflict, need to qualify

   "Value of type 'X' has no member 'Y'"
   → Wrong import or outdated API
   ```

3. **Fix order**:
   - Fix module/import errors first
   - Then fix type errors
   - Then fix logic errors
   - Warnings last

4. **After each fix**:
   - ⌘B (build)
   - If successful → commit change
   - If failed → repeat

---

### Debugging Test Failures

**Workflow**:

1. **Identify failing test**:
   ```bash
   # Run single test
   xcodebuild test -scheme HeirloomVideoLab \
     -only-testing:HeirloomVideoLabTests/AudioExtractionServiceTests/testExtractAudioFromValidVideo
   ```

2. **Read failure message**:
   ```
   ❌ testExtractAudioFromValidVideo failed:
       XCTAssertTrue failed - Audio file does not exist
   ```

3. **Add debugging**:
   ```swift
   func testExtractAudioFromValidVideo() async throws {
       print("🔍 Test starting...")
       print("🔍 Video URL: \(testVideoURL)")

       let audioURL = try await sut.extractAudio(from: testVideoURL)

       print("🔍 Audio URL: \(audioURL)")
       print("🔍 File exists: \(FileManager.default.fileExists(atPath: audioURL.path))")

       XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))
   }
   ```

4. **Rerun and check console**:
   - Look for your 🔍 prints
   - Identify where it fails
   - Add more prints if needed

5. **Fix issue**:
   - Update code
   - Rerun test
   - Repeat until green ✅

---

### Performance Debugging

**If processing is too slow**:

1. **Profile with Instruments**:
   ```bash
   # In Xcode:
   Product → Profile (⌘I)
   Select: Time Profiler
   ```

2. **Record while processing video**:
   - Click red record button
   - Import video in app
   - Wait for completion
   - Click stop

3. **Analyze**:
   - Look at Call Tree
   - Find heaviest stack trace
   - Identify bottleneck

4. **Common bottlenecks**:
   - WhisperKit transcription: Expected, can't optimize much
   - Frame extraction: Reduce frame count or skip
   - OCR: Use faster recognition level
   - API calls: Check network latency

---

### Cost Debugging

**If cost is too high**:

1. **Check console logs**:
   ```
   Look for:
   Claude API Usage:
     Input tokens: 5000 ($0.0150)
     Output tokens: 800 ($0.0120)
     Total cost: $0.0270
   ```

2. **Analyze token usage**:
   - Input tokens = transcript + prompt
   - Output tokens = recipe JSON

3. **Reduce if needed**:
   - Skip frame analysis (saves minimal cost)
   - Summarize transcript before sending (risky)
   - Use smaller Claude model (may reduce quality)

---

## Part 4: Quick Reference

### Build & Test Commands

```bash
# Clean build
xcodebuild clean -scheme HeirloomVideoLab

# Build only
xcodebuild -scheme HeirloomVideoLab -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Run all tests (simulator)
xcodebuild test -scheme HeirloomVideoLab -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run all tests (device)
xcodebuild test -scheme HeirloomVideoLab -destination 'platform=iOS,name=YOUR_DEVICE'

# Run specific test class
xcodebuild test -scheme HeirloomVideoLab -only-testing:HeirloomVideoLabTests/AudioExtractionServiceTests

# Run specific test method
xcodebuild test -scheme HeirloomVideoLab -only-testing:HeirloomVideoLabTests/AudioExtractionServiceTests/testExtractAudioFromValidVideo

# With code coverage
xcodebuild test -scheme HeirloomVideoLab -enableCodeCoverage YES -resultBundlePath TestResults.xcresult
```

### Xcode Keyboard Shortcuts

```
⌘B         Build
⌘R         Run
⌘U         Test
⌘.         Stop
⌘K         Clear console
⇧⌘K        Clean build folder
⇧⌘O        Open quickly (search files)
⌘6         Test Navigator
⌘7         Debug Navigator
⌘9         Report Navigator
⌥⌘1        File Inspector
F6         Step over (debugging)
F7         Step into (debugging)
⌃I         Re-indent
```

### Test Status Indicators

```
✅ Green checkmark   = Test passed
❌ Red X             = Test failed
◆ Gray diamond      = Test not run yet
⏸ Gray pause       = Test skipped (XCTSkip)
```

---

## Part 5: Success Checklist

### Initial Setup Complete When:

- [ ] ✅ Build succeeds (⌘B) with 0 errors
- [ ] ✅ All 72 unit tests pass on simulator
- [ ] ✅ Transcription tests pass on physical device
- [ ] ✅ App launches and runs on device
- [ ] ✅ Can import and process a test video end-to-end
- [ ] ✅ Cost estimate appears in console (~$0.02-0.03)
- [ ] ✅ Processing time meets target (2-4 min for 15-min video)

### Ready for Development When:

- [ ] ✅ Can make code changes and rebuild quickly
- [ ] ✅ Tests run automatically and reliably
- [ ] ✅ Debugging workflow is smooth
- [ ] ✅ Understand how to add new tests
- [ ] ✅ Can profile performance when needed

---

## Troubleshooting Quick Links

- **Setup issues**: See Part 1 checkpoints
- **Test failures**: See Part 2 → If Tests Fail sections
- **App crashes**: See Part 2 → If App Crashes section
- **Build errors**: See Part 3 → Systematic Debugging
- **Performance issues**: See Part 3 → Performance Debugging
- **Cost issues**: See Part 3 → Cost Debugging

---

## Getting Help

If stuck after trying above:

1. Check console output carefully
2. Search error message in docs
3. Review recent git changes
4. Try clean build (⇧⌘K)
5. Restart Xcode
6. Check TESTING_GUIDE.md for more details

---

**Estimated total time for setup + first successful test**: 30-45 minutes

**Subsequent test-fix-test cycles**: 1-5 minutes per iteration

Good luck! 🚀
