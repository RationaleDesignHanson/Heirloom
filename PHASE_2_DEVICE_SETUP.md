# Phase 2: Device Testing Setup - Step by Step

**Time Estimate:** 15 minutes
**Prerequisites:** Phase 1 complete (Xcode integration done, app runs on device)

---

## Prerequisites Verification

Before starting Phase 2:
- [ ] Phase 1 complete (all checkboxes checked)
- [ ] App running on physical iPhone
- [ ] Share Extension visible in share sheet
- [ ] iPhone connected to Mac

---

## Step 2.1: Verify Device Requirements (2 min)

### Check iPhone Specs:

1. On iPhone: **Settings → General → About**
2. **Verify:**
   - [ ] iOS version: **17.0 or higher** (Share Extension requires iOS 17+)
   - [ ] Storage: At least **2 GB free** (for video processing)
   - [ ] Model: iPhone 11 or newer (for performance)

**If iOS too old:**
- Update to iOS 17.0+ via Settings → General → Software Update
- Restart device after update

---

## Step 2.2: Install Required Apps (5 min)

### Install these apps from App Store on test iPhone:

1. **TikTok**
   - [ ] Open App Store
   - [ ] Search "TikTok"
   - [ ] Install
   - [ ] Open and create/login to account (optional)
   - **Why:** Primary test platform for recipe videos

2. **Instagram**
   - [ ] Install from App Store
   - [ ] Login to account
   - **Why:** Test Instagram Reels import

3. **YouTube**
   - [ ] Install from App Store
   - [ ] Login to account (optional)
   - **Why:** Test YouTube Shorts and full videos

4. **Safari** (pre-installed)
   - [ ] Already on device
   - **Why:** Test URL sharing

**Optional but helpful:**
5. **Notes app** (pre-installed)
   - **Why:** Useful for pasting/sharing URLs

---

## Step 2.3: Enable Developer Mode (if needed) (2 min)

### Check if Developer Mode is enabled:

1. Try running app from Xcode (⌘R)
2. If you see error: "Developer Mode disabled"

**Enable it:**
1. On iPhone: **Settings → Privacy & Security → Developer Mode**
2. Toggle ON
3. Restart iPhone when prompted
4. After restart, confirm enabling Developer Mode

- [ ] Developer Mode enabled
- [ ] App runs from Xcode without errors

---

## Step 2.4: Configure Share Extension Permissions (3 min)

### Enable Heirloom in Share Sheet:

1. On iPhone, open **Photos app**
2. Select any photo or video
3. Tap **Share button** (square with arrow)
4. Scroll down to bottom of share sheet
5. Tap **"Edit Actions"** or **"More"**
6. **Find "Heirloom" in list:**
   - [ ] Toggle is **ON** (green)
   - [ ] Heirloom is visible in top section (not hidden)

**If Heirloom not in list:**
- Rebuild app from Xcode (⌘R)
- Delete app from iPhone, reinstall
- Check Share Extension target in Xcode (Phase 1)

### Test Share Sheet Appearance:

1. Open TikTok app
2. Find any video
3. Tap **Share button**
4. **Verify:**
   - [ ] "Heirloom" appears in share options
   - [ ] Has app icon visible
   - [ ] Tapping it opens Share Extension UI

---

## Step 2.5: Verify Network Connection (1 min)

### Check Internet Connection:

- [ ] WiFi connected (Settings → WiFi)
- [ ] OR Cellular Data enabled
- [ ] Strong signal (3+ bars)

**Why:** Share Extension needs network for:
- Downloading videos
- Fetching creator metadata
- Claude AI recipe extraction
- oEmbed API calls

### Test Network:

1. Open Safari
2. Visit `https://www.google.com`
3. **Verify:** Page loads quickly

**For testing offline scenarios later:**
- Know how to enable Airplane Mode: Settings → Airplane Mode toggle

---

## Step 2.6: Test Corporate Anthropic Key (2 min)

### Verify API Key is Working:

**We'll test this in Phase 3, but prepare now:**

1. In Xcode, open `Heirloom/Core/Config/AIConfiguration.swift` (or similar)
2. **Verify** this code path exists:
   ```swift
   Bundle.main.object(forInfoDictionaryKey: "DEFAULT_ANTHROPIC_KEY")
   ```

3. Add temporary logging (optional):
   ```swift
   let key = Bundle.main.object(forInfoDictionaryKey: "DEFAULT_ANTHROPIC_KEY") as? String
   print("🔑 API Key present: \(key != nil)")
   print("🔑 API Key prefix: \(key?.prefix(10) ?? "nil")")
   ```

4. Run app (⌘R)
5. Check Xcode console output
6. **Verify:**
   - [ ] Prints "API Key present: true"
   - [ ] Prefix shows "sk-ant-api"

**If API key missing:**
- Go back to Phase 1, Step 1.8
- Add corporate key to Config.xcconfig or Info.plist

---

## Step 2.7: Test Account Setup (Optional) (5 min)

### Prepare Test Accounts:

**Free User Account:**
1. If you have account system, create/use a free tier account
2. Login to Heirloom app
3. **Verify:**
   - [ ] Can access app
   - [ ] Not subscribed to premium
   - **Why:** To test paywall for visual extraction mode

**Premium User Account:**
1. Create/use premium subscriber account
2. Login to Heirloom app
3. **Verify:**
   - [ ] Can access app
   - [ ] Has premium subscription active
   - **Why:** To test premium features (visual analysis)

**If no account system yet:**
- [ ] Skip this step (not required for basic testing)

---

## Step 2.8: Find Test Videos (5 min)

### Prepare Sample Videos for Testing:

**Locate these in each app:**

#### TikTok Videos:

1. **Good Audio Recipe Video:**
   - Open TikTok app
   - Search: "recipe" or "cooking tutorial"
   - Find video with:
     - Clear narration (person speaking recipe steps)
     - 60+ seconds long
     - Ingredients mentioned
     - No loud background music
   - [ ] Bookmark or save this video
   - [ ] Note the @username

2. **Background Music Only Video:**
   - Search TikTok for "recipe asmr" or cooking videos with just music
   - Find video with:
     - NO speaking (just background music)
     - Text overlays with recipe
   - [ ] Bookmark this video

3. **TikTok Short URL:**
   - On any TikTok video, tap Share
   - Tap "Copy Link"
   - Paste in Notes app
   - **Verify** URL format: `https://vm.tiktok.com/XXXXX`
   - [ ] Save this URL

#### Instagram Reels:

4. **Instagram Reel with Recipe:**
   - Open Instagram
   - Go to Reels tab
   - Search for recipe content
   - Find a cooking Reel
   - [ ] Save this Reel

#### YouTube Shorts/Videos:

5. **YouTube Shorts:**
   - Open YouTube app
   - Go to Shorts section
   - Find cooking Short
   - [ ] Save this Short

6. **Regular YouTube Video:**
   - Search YouTube: "recipe video"
   - Find regular-length cooking video
   - [ ] Save this video

**Keep these videos accessible** - you'll share them in Phase 3-4 testing.

---

## Step 2.9: Configure Xcode Console for Logging (2 min)

### Enable Detailed Logging:

1. In Xcode, with app running
2. Open **Console** pane (bottom of Xcode)
3. **Filter settings:**
   - [ ] Click filter icon
   - [ ] Set to "All Messages" (not just errors)
   - [ ] Add filter for "Share Extension" or "PendingImport"

**Why:** You'll want to see detailed logs during testing to debug issues.

**Optional: Add Logging to Code:**

In `ShareViewController.swift`, add:
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    print("🎯 Share Extension loaded")
}
```

In `PendingImportProcessor.swift`, add:
```swift
print("📹 Processing video: \(videoURL)")
print("🎬 Mode selected: \(mode)")
```

---

## Step 2.10: Test Basic Share Flow (Smoke Test) (3 min)

### Quick End-to-End Test:

**Purpose:** Verify everything is wired correctly before deep testing.

1. **On iPhone, open Photos app**
2. **Select any video** (doesn't matter what)
3. **Tap Share button**
4. **Tap "Heirloom"**

**Expected Results:**
- [ ] Share Extension opens (fullscreen or modal)
- [ ] UI loads (no blank screen)
- [ ] Shows platform detection or analysis UI
- [ ] Does NOT crash

5. **Tap "Import" or "Save"** (if button exists)

**Expected Results:**
- [ ] Share Extension closes
- [ ] Main Heirloom app opens
- [ ] Shows video import screen or processing indicator
- [ ] Does NOT crash

**If this works:** ✅ You're ready for detailed testing!

**If this crashes or fails:**
- Check Xcode console for errors
- Verify Phase 1 was completed correctly
- Common issues:
  - Missing target membership
  - App Groups not configured
  - Deep link not working

---

## ✅ Phase 2 Complete Checklist

Before proceeding to Phase 3, verify ALL items:

### Device Setup:
- [ ] iPhone running iOS 17.0+
- [ ] At least 2 GB free storage
- [ ] Developer Mode enabled
- [ ] Strong internet connection (WiFi or cellular)

### Apps Installed:
- [ ] TikTok installed
- [ ] Instagram installed
- [ ] YouTube installed
- [ ] Safari available (default)

### Share Extension:
- [ ] Heirloom appears in iOS share sheet
- [ ] Share Extension enabled/toggled ON
- [ ] Share Extension opens when tapped
- [ ] Does not crash on basic test

### Test Videos:
- [ ] Found good audio TikTok recipe video
- [ ] Found background music only TikTok video
- [ ] Found Instagram Reel recipe video
- [ ] Found YouTube Shorts/video
- [ ] All videos bookmarked/saved for testing

### Xcode:
- [ ] Console logging enabled
- [ ] App running on device
- [ ] Can see debug output in console

### API Key:
- [ ] Corporate Anthropic key verified working
- [ ] Console shows "API Key present: true"

### Smoke Test:
- [ ] Basic share flow works (Photos → Heirloom → Main app)
- [ ] No immediate crashes

---

## 🎯 Ready for Testing!

**All items above complete?** → Proceed to **PHASE_3_PLATFORM_TESTING.md**

You now have:
- ✅ Working builds
- ✅ Configured device
- ✅ Test apps installed
- ✅ Sample videos ready
- ✅ Basic functionality verified

**Next:** Comprehensive platform-specific testing (TikTok, Instagram, YouTube, Facebook)

---

**Status:** Phase 2 - Device Testing Setup Complete
**Next:** Phase 3 - Platform-Specific Testing (TikTok, Instagram, YouTube)
**Time to Phase 3:** Ready to start immediately
