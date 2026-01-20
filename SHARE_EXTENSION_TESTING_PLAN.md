# Share Extension Testing Plan - Pre-Merge Checklist

**Feature:** Social Media → Recipe Card Share Extension
**Branch:** `feature/share-extension-unified-import`
**Priority:** 🔴 FLAGSHIP FEATURE - Must work flawlessly before merge

---

## Phase 1: Xcode Integration (30 min)

### 1.1 Add Files to Targets

**Main App Target:**
- [ ] `Heirloom/Core/Services/DeepLink/DeepLinkHandler.swift`
- [ ] `Heirloom/App/HeirloomApp.swift`
- [ ] `Heirloom/Features/Recipes/VideoImport/UnifiedVideoImportView.swift`
- [ ] `Heirloom/Core/Services/Video/PendingImportProcessor.swift`

**Share Extension Target:**
- [ ] All files in `HeirloomShareExtension/`
- [ ] Ensure `ShareExtensionConfig.swift` is in target
- [ ] Ensure `PendingImportModels.swift` is in BOTH targets (Main + Share)

**Test Target:**
- [ ] All files in `HeirloomTestsV2/Unit/Features/ShareExtension/`

### 1.2 Verify Configuration

- [ ] **Config.xcconfig** has `DEFAULT_ANTHROPIC_KEY` set to your corporate key
- [ ] **Info.plist** includes `DEFAULT_ANTHROPIC_KEY` entry
- [ ] **App Groups** enabled for both Main App and Share Extension
  - Identifier: `group.com.matthanson.heirloom.shared`
- [ ] **Deep Link URL Scheme** configured in Main App
  - Scheme: `heirloom`
  - Example: `heirloom://import?id=<UUID>`

### 1.3 Build Verification

```bash
# Clean build
xcodebuild clean -project Heirloom.xcodeproj -scheme Heirloom

# Build main app
xcodebuild build -project Heirloom.xcodeproj -scheme Heirloom

# Build share extension
xcodebuild build -project Heirloom.xcodeproj -scheme HeirloomShareExtension
```

- [ ] Main app builds without errors
- [ ] Share Extension builds without errors
- [ ] No warnings related to Share Extension code
- [ ] Run unit tests: `CMD+U` - all tests pass

---

## Phase 2: Device Testing Setup (15 min)

### 2.1 Physical Device Required

⚠️ **CRITICAL**: Share sheets cannot be fully tested in simulator. Use physical iPhone.

- [ ] iPhone running iOS 17.0+
- [ ] Device connected to Mac
- [ ] Developer mode enabled
- [ ] Trust computer on device

### 2.2 Install Build

- [ ] Build and run on device (CMD+R)
- [ ] Share Extension appears in Settings → General → Share Extension
- [ ] Heirloom Share Extension is toggled ON

### 2.3 Test Apps Installed

Install these apps on test device to test sharing:
- [ ] TikTok (for TikTok video testing)
- [ ] Instagram (for Reels testing)
- [ ] YouTube (for Shorts/regular videos)
- [ ] Safari (for URL sharing)

---

## Phase 3: Platform-Specific Testing (60 min)

### 3.1 TikTok Video Sharing 🎯

**Test Case 1: Full-length TikTok Video with Clear Speech**

1. Open TikTok app
2. Find a recipe video with:
   - Clear narration (ingredients and steps spoken)
   - 60+ seconds duration
   - Good audio quality (no loud background music)
3. Tap Share → Heirloom
4. **Expected Results:**
   - [ ] Share Extension loads within 3 seconds
   - [ ] Shows "Analyzing audio..." status
   - [ ] Detects platform as TikTok (shows TikTok icon)
   - [ ] Shows creator username (e.g., @chefname)
   - [ ] Recommends "Audio Transcript" mode
   - [ ] Shows transcript preview (30+ words)
   - [ ] "Import to Heirloom" button enabled
5. Tap "Import to Heirloom"
6. **Expected Results:**
   - [ ] Main app opens automatically
   - [ ] Shows video import sheet
   - [ ] Begins processing video
   - [ ] Extracts recipe with Claude AI
   - [ ] Creates recipe card with:
     - Title
     - Ingredients list
     - Instructions
     - Source: TikTok + creator attribution
     - Source URL linked

**Test Case 2: TikTok Short URL (vm.tiktok.com)**

1. Copy a TikTok share link (e.g., `https://vm.tiktok.com/ABC123`)
2. Open Notes app → Paste URL
3. Long press URL → Share → Heirloom
4. **Expected Results:**
   - [ ] Share Extension detects short URL
   - [ ] Shows TikTok platform
   - [ ] Marks as short URL (may need to fetch full URL)
   - [ ] Allows import

**Test Case 3: TikTok Video with Background Music Only**

1. Find TikTok video with:
   - Just background music (no speech)
   - Text overlay with recipe
2. Share to Heirloom
3. **Expected Results:**
   - [ ] Detects low word count (<30 words)
   - [ ] Recommends "On-Screen Text (OCR)" mode
   - [ ] Shows reasoning: "Insufficient speech detected"
   - [ ] Import still works

### 3.2 Instagram Reels Sharing 🎯

**Test Case 4: Instagram Reel with Recipe**

1. Open Instagram app
2. Find a recipe Reel with clear narration
3. Tap Share → Heirloom
4. **Expected Results:**
   - [ ] Detects Instagram platform
   - [ ] Shows Instagram icon
   - [ ] Extracts Reel ID from URL
   - [ ] Analyzes audio successfully
   - [ ] Creates recipe card with Instagram attribution

**Test Case 5: Instagram Post (not Reel)**

1. Find regular Instagram post (not Reel/video)
2. Share to Heirloom
3. **Expected Results:**
   - [ ] Either shows error "Not a video URL"
   - [ ] OR gracefully handles as unknown platform

### 3.3 YouTube Shorts/Videos Sharing 🎯

**Test Case 6: YouTube Shorts**

1. Open YouTube app
2. Find a recipe Short (e.g., `youtube.com/shorts/abc123`)
3. Share to Heirloom
4. **Expected Results:**
   - [ ] Detects YouTube platform
   - [ ] Extracts video ID correctly
   - [ ] Processes audio
   - [ ] Creates recipe with YouTube source

**Test Case 7: Regular YouTube Video**

1. Find full-length recipe video (e.g., `youtube.com/watch?v=abc123`)
2. Share to Heirloom
3. **Expected Results:**
   - [ ] Detects YouTube platform from `watch?v=` format
   - [ ] Extracts video ID
   - [ ] Processes successfully

**Test Case 8: YouTube Short URL (youtu.be)**

1. Share `https://youtu.be/abc123` link
2. **Expected Results:**
   - [ ] Detects YouTube platform
   - [ ] Marks as short URL
   - [ ] Extracts video ID
   - [ ] Processes normally

### 3.4 Facebook Video Sharing 🎯

**Test Case 9: Facebook Watch Video**

1. Open Facebook app
2. Find recipe video in Watch tab
3. Share to Heirloom
4. **Expected Results:**
   - [ ] Detects Facebook platform
   - [ ] Processes video
   - [ ] Creates recipe card

---

## Phase 4: Three-Tier Cascade Testing (30 min)

### 4.1 Tier 1: Audio Transcript Mode

**Test Case 10: High-Quality Audio (Free Tier)**

1. Share video with:
   - 150+ words spoken
   - Speech confidence >0.8
   - Recipe relevance score >0.5
2. **Expected Results:**
   - [ ] Recommends "Audio Transcript" mode
   - [ ] Does NOT trigger paywall (free tier)
   - [ ] Processes successfully
   - [ ] Recipe quality is high

### 4.2 Tier 2: On-Screen Text (OCR) Mode

**Test Case 11: Low Audio Quality → OCR Fallback**

1. Share video with:
   - Loud background music
   - Low word count (<30 words)
   - OR low confidence (<0.4)
2. **Expected Results:**
   - [ ] Recommends "On-Screen Text (OCR)" mode
   - [ ] Shows reasoning (e.g., "Background music detected")
   - [ ] Does NOT trigger paywall (free tier)
   - [ ] Falls back to OCR processing

### 4.3 Tier 3: Visual Analysis Mode (Premium)

**Test Case 12: Manual Visual Mode Selection**

1. Share any video
2. In Share Extension, manually select "Visual Analysis" mode
3. **Expected Results:**
   - [ ] Shows premium badge/indicator
   - [ ] Allows selection
   - [ ] On import, triggers paywall if not subscribed
   - [ ] Blocks processing until subscription confirmed

---

## Phase 5: Error Handling & Edge Cases (45 min)

### 5.1 Invalid URLs

**Test Case 13: Malformed URL**

1. Share text: `"not a url at all"`
2. **Expected Results:**
   - [ ] Shows error message
   - [ ] Does not crash
   - [ ] Provides helpful guidance

**Test Case 14: Non-Video URL**

1. Share URL: `https://www.google.com`
2. **Expected Results:**
   - [ ] Shows error: "Not a supported video platform"
   - [ ] Lists supported platforms
   - [ ] Does not crash

**Test Case 15: Video URL Missing Video ID**

1. Share: `https://www.tiktok.com/@user/video/`
2. **Expected Results:**
   - [ ] Shows error or marks as invalid
   - [ ] Does not crash

### 5.2 Network Errors

**Test Case 16: No Internet Connection**

1. Turn off WiFi and cellular data
2. Share a video URL
3. **Expected Results:**
   - [ ] Shows error: "No internet connection"
   - [ ] Suggests trying again when online
   - [ ] Does not crash or hang

**Test Case 17: Slow Network**

1. Enable airplane mode, then disable (to simulate slow network)
2. Share video
3. **Expected Results:**
   - [ ] Shows loading indicator
   - [ ] Times out gracefully (e.g., after 30 seconds)
   - [ ] Shows retry option

### 5.3 Video Processing Errors

**Test Case 18: Video Cannot Be Downloaded**

1. Share a very old TikTok URL (likely deleted)
2. **Expected Results:**
   - [ ] Shows error: "Could not download video"
   - [ ] Suggests checking URL
   - [ ] Does not crash

**Test Case 19: Extremely Long URL**

1. Share URL with 10,000+ characters
2. **Expected Results:**
   - [ ] Handles gracefully (truncates or validates)
   - [ ] Does not crash
   - [ ] Shows error if invalid

**Test Case 20: Unicode/Emoji in URL**

1. Share URL: `https://www.tiktok.com/@用户/video/123`
2. **Expected Results:**
   - [ ] Handles unicode gracefully
   - [ ] Encodes properly
   - [ ] Processes or shows error (no crash)

### 5.4 Audio Analysis Edge Cases

**Test Case 21: Silent Video**

1. Share video with no audio track
2. **Expected Results:**
   - [ ] Detects no audio (0 words)
   - [ ] Recommends OCR mode
   - [ ] Shows reasoning: "No audio track detected"
   - [ ] Still processes

**Test Case 22: Very Short Video (<5 seconds)**

1. Share 3-second TikTok
2. **Expected Results:**
   - [ ] Processes audio (likely low word count)
   - [ ] Falls back to OCR
   - [ ] Creates recipe (may be low quality)

**Test Case 23: Very Long Video (10+ minutes)**

1. Share 15-minute YouTube recipe video
2. **Expected Results:**
   - [ ] Processes without timeout
   - [ ] Shows progress indicator
   - [ ] Completes successfully (may take 30+ seconds)

---

## Phase 6: Deep Link Handoff Testing (20 min)

### 6.1 Share Extension → Main App Flow

**Test Case 24: Basic Handoff**

1. Share video in Share Extension
2. Tap "Import to Heirloom"
3. **Expected Results:**
   - [ ] Share Extension closes
   - [ ] Main app opens within 2 seconds
   - [ ] Deep link detected: `heirloom://import?id=<UUID>`
   - [ ] Video import sheet appears
   - [ ] Begins processing immediately

**Test Case 25: App Already Running**

1. Open main Heirloom app (leave it in background)
2. Share video from TikTok
3. Tap "Import to Heirloom"
4. **Expected Results:**
   - [ ] Switches to already-running app (no cold start)
   - [ ] Video import sheet appears
   - [ ] Previous app state preserved

**Test Case 26: App Not Installed (Edge Case)**

This shouldn't happen, but test anyway:
1. (Hypothetically) Share without main app
2. **Expected Results:**
   - [ ] Share Extension shows error
   - [ ] Suggests installing Heirloom app

### 6.2 Shared Container Verification

**Test Case 27: Video File Saved to Shared Container**

1. Share video
2. Before importing, check shared container:
   ```swift
   // In debugger or logging
   let sharedContainer = FileManager.default.containerURL(
       forSecurityApplicationGroupIdentifier: "group.com.matthanson.heirloom.shared"
   )
   print(sharedContainer?.path)
   ```
3. **Expected Results:**
   - [ ] Video file exists at `Videos/<UUID>.mp4`
   - [ ] Metadata file exists at `PendingImports/<UUID>.json`

**Test Case 28: Cleanup After Import**

1. Complete video import
2. Check shared container again
3. **Expected Results:**
   - [ ] Video file deleted from shared container
   - [ ] Metadata JSON deleted
   - [ ] No leftover files

---

## Phase 7: Performance & UX Testing (30 min)

### 7.1 Speed Benchmarks

**Test Case 29: Share Extension Load Time**

1. Share video
2. Measure time from tap "Heirloom" to Share Extension UI appearing
3. **Success Criteria:**
   - [ ] <3 seconds on WiFi
   - [ ] <5 seconds on cellular

**Test Case 30: Audio Analysis Time**

1. Share 60-second video
2. Measure time from "Analyzing audio..." to result
3. **Success Criteria:**
   - [ ] <10 seconds for 60-second video
   - [ ] Shows progress indicator

**Test Case 31: Full Import Time (E2E)**

1. Share video → Import → Recipe created
2. Measure total time
3. **Success Criteria:**
   - [ ] <30 seconds for typical recipe video (60s)
   - [ ] <60 seconds for long video (10+ min)

### 7.2 User Experience

**Test Case 32: Clear Feedback at Every Step**

1. Go through full import flow
2. **Expected Results:**
   - [ ] Loading indicators show during analysis
   - [ ] Progress messages clear ("Analyzing audio...", "Extracting recipe...")
   - [ ] Success/error states obvious
   - [ ] No confusing states or blank screens

**Test Case 33: Attribution Displayed**

1. Import recipe from TikTok (@chefname)
2. View recipe card
3. **Expected Results:**
   - [ ] Shows "Source: TikTok"
   - [ ] Shows creator username "@chefname"
   - [ ] Source URL is tappable (opens original video)

**Test Case 34: Cancel/Dismiss Behavior**

1. Share video
2. Tap "Cancel" or swipe down Share Extension
3. **Expected Results:**
   - [ ] Share Extension dismisses
   - [ ] Returns to original app (TikTok/Instagram)
   - [ ] No data saved
   - [ ] No memory leaks

---

## Phase 8: Subscription/Paywall Integration (15 min)

### 7.3 Premium Features

**Test Case 35: Free User - Visual Mode Blocked**

1. Sign in as non-premium user
2. Share video and select "Visual Analysis" mode
3. **Expected Results:**
   - [ ] Paywall appears when trying to import
   - [ ] Shows pricing
   - [ ] Blocks processing until subscribed
   - [ ] Can go back and select Audio/OCR instead

**Test Case 36: Premium User - Visual Mode Allowed**

1. Sign in as premium subscriber
2. Share video and select "Visual Analysis" mode
3. **Expected Results:**
   - [ ] No paywall
   - [ ] Processes immediately
   - [ ] Uses frame analysis

**Test Case 37: Premium User - Usage Tracking**

1. Import several videos as premium user
2. Check AI usage tracking
3. **Expected Results:**
   - [ ] Tracks API calls to Claude
   - [ ] Logs usage in analytics
   - [ ] Does not block (unlimited for premium)

---

## Phase 9: Regression Testing (20 min)

### 9.1 Existing Features Still Work

**Test Case 38: Manual Video Import (Non-Share)**

1. Open Heirloom app directly
2. Go to "Import Recipe" → "From Video"
3. Enter YouTube URL manually
4. **Expected Results:**
   - [ ] Still works as before
   - [ ] No regression from Share Extension changes

**Test Case 39: Other Recipe Import Methods**

1. Try importing recipe via:
   - Text/OCR scan
   - Web URL
   - Manual entry
2. **Expected Results:**
   - [ ] All import methods still functional
   - [ ] No conflicts with Share Extension code

**Test Case 40: Deep Links for Other Features**

1. Test existing deep links (if any):
   - Recipe viewing (`heirloom://recipe/<id>`)
   - Settings, etc.
2. **Expected Results:**
   - [ ] Other deep links still work
   - [ ] No conflicts with video import deep link

---

## Phase 10: Final Checklist Before Merge

### 10.1 Code Quality

- [ ] No TODO comments in production code
- [ ] No debug `print()` statements left in
- [ ] No hardcoded API keys or secrets
- [ ] All force-unwraps (`!`) justified or removed
- [ ] No compiler warnings
- [ ] SwiftLint passes (if using)

### 10.2 Documentation

- [ ] `README.md` updated with Share Extension instructions
- [ ] Architecture docs (`ARCHITECTURE_NOTES.md`) reflect Share Extension
- [ ] Testing docs explain how to test Share Extension
- [ ] Comments added to complex logic

### 10.3 Testing

- [ ] All unit tests pass (`CMD+U`)
- [ ] All manual test cases above completed
- [ ] No crashes during testing
- [ ] No memory leaks detected (Instruments)

### 10.4 Stakeholder Review

- [ ] Demo to team/stakeholders
- [ ] Collect feedback on UX
- [ ] Verify social sharing works as expected
- [ ] Get sign-off for merge

---

## Success Criteria Summary

### Must Pass Before Merge:

1. ✅ **All platforms work**: TikTok, Instagram, YouTube, Facebook
2. ✅ **Three-tier cascade functions**: Audio → OCR → Visual (with paywall)
3. ✅ **Deep link handoff smooth**: Share Extension → Main App <2 seconds
4. ✅ **No crashes**: All error cases handled gracefully
5. ✅ **Attribution correct**: Source + creator shown on recipe card
6. ✅ **Performance acceptable**:
   - Share Extension load: <3s
   - Audio analysis: <10s
   - Full E2E import: <30s
7. ✅ **Paywall works**: Premium features blocked for free users
8. ✅ **No regressions**: Existing features still work

---

## Test Tracking

### Test Session Log

**Date:** ___________
**Tester:** ___________
**Device:** ___________ (iOS version: ______)
**Build:** ___________ (Git commit: ______)

| Test # | Test Name | Status | Notes |
|--------|-----------|--------|-------|
| 1 | TikTok clear speech | ⬜ Pass / ⬜ Fail | |
| 2 | TikTok short URL | ⬜ Pass / ⬜ Fail | |
| 3 | TikTok music only | ⬜ Pass / ⬜ Fail | |
| 4 | Instagram Reel | ⬜ Pass / ⬜ Fail | |
| 5 | Instagram Post | ⬜ Pass / ⬜ Fail | |
| ... | ... | ... | |

---

## Emergency Rollback Plan

If critical bugs found during testing:

1. **Do NOT merge to main**
2. Document bug in GitHub Issues
3. Fix on `feature/share-extension-unified-import` branch
4. Re-test affected test cases
5. Repeat until all tests pass

---

## Post-Merge Monitoring

After merge and production release:

1. Monitor crash reports (Crashlytics/Sentry)
2. Track Share Extension usage analytics
3. Monitor Claude API costs
4. Collect user feedback on social sharing
5. Identify most-used platforms for optimization

---

**Last Updated:** 2026-01-20
**Status:** 🟡 Ready for Testing Phase
