# Physical Device Testing Checklist

**Last Updated**: 2026-01-23
**Version**: 1.12.0 (Build 24)
**Purpose**: Pre-TestFlight validation on real hardware

---

## Overview

Testing on a physical iPhone is **critical** before TestFlight submission. The simulator doesn't replicate:
- Real network conditions
- Actual device performance
- Camera/photo library access
- Push notifications
- True memory constraints
- Battery impact
- Thermal throttling
- Haptic feedback

---

## Pre-Testing Setup

### 1. Connect Your iPhone
- [ ] Connect iPhone via USB cable
- [ ] Trust computer if prompted
- [ ] Ensure iPhone is unlocked

### 2. Select Device in Xcode
- [ ] Xcode → Window → Devices and Simulators
- [ ] Select your iPhone from the list
- [ ] Verify iOS version matches minimum supported (iOS 17.0+)

### 3. Set Build Configuration
- [ ] Product → Scheme → Edit Scheme
- [ ] Run → Build Configuration → **Debug** (for testing)
- [ ] Close scheme editor

### 4. Build and Run
- [ ] Press Cmd+R to build and install
- [ ] Wait for app to launch on device
- [ ] Grant permissions when prompted (Photos, Camera, Notifications)

---

## Critical User Flows to Test

### Flow 1: Authentication (5 minutes)

**Sign in with Apple**
- [ ] Tap "Sign in with Apple"
- [ ] Complete Face ID/Touch ID authentication
- [ ] Verify successful sign in
- [ ] Check user profile shows correct name
- [ ] Sign out
- [ ] Sign in again (verify persistence)

**Sign in with Google**
- [ ] Tap "Sign in with Google"
- [ ] Select Google account
- [ ] Grant permissions
- [ ] Verify successful sign in
- [ ] Check user profile shows correct email
- [ ] Sign out
- [ ] Sign in again

**Expected Behavior**:
- ✅ Smooth authentication flow
- ✅ No crashes or freezes
- ✅ Credentials persist after app restart
- ✅ User can switch between accounts

---

### Flow 2: Recipe Creation (5 minutes)

**Manual Recipe Entry**
- [ ] Tap "+" to create new recipe
- [ ] Enter title: "Test Recipe Device"
- [ ] Add 3-5 ingredients
- [ ] Add 3-5 instruction steps
- [ ] Add a photo from camera roll
- [ ] Set cooking time and servings
- [ ] Tap "Save"
- [ ] Verify recipe appears in main list

**Quick Checks**:
- [ ] Keyboard input is smooth
- [ ] Photo picker works correctly
- [ ] Scrolling is smooth (60fps)
- [ ] No lag when typing
- [ ] Save button is responsive

---

### Flow 3: Recipe Import (10 minutes)

**Import from URL**
- [ ] Open Safari on device
- [ ] Navigate to: https://www.allrecipes.com/recipe/229960/crispy-and-tender-baked-chicken-thighs/
- [ ] Copy URL to clipboard
- [ ] Return to Heirloom
- [ ] Tap import/add button
- [ ] Paste URL
- [ ] Tap "Import"
- [ ] Wait for Claude AI to process (10-30 seconds)
- [ ] Review imported recipe
- [ ] Verify: Title, ingredients, instructions populated
- [ ] Save recipe

**Import from Photo**
- [ ] Tap import button
- [ ] Select "Import from Photo"
- [ ] Choose a recipe photo from camera roll (or take new photo)
- [ ] Wait for processing
- [ ] Verify OCR extracted text correctly
- [ ] Save recipe

**Import from PDF**
- [ ] Have a recipe PDF ready (email yourself one if needed)
- [ ] Share PDF to Heirloom via Share Sheet
- [ ] Verify import flow works
- [ ] Check extracted data is accurate

**Expected Behavior**:
- ✅ No network timeout errors
- ✅ Progress indicators show clearly
- ✅ Imported data is accurate
- ✅ Images load and display correctly
- ✅ No memory warnings or crashes

---

### Flow 4: Shopping List (5 minutes)

**Add Items to Shopping List**
- [ ] Open a recipe with ingredients
- [ ] Tap shopping list icon
- [ ] Select 3-5 ingredients to add
- [ ] Tap "Add to Shopping List"
- [ ] Navigate to Shopping tab
- [ ] Verify ingredients appear in list
- [ ] Check off 2-3 items
- [ ] Uncheck 1 item
- [ ] Delete 1 item
- [ ] Add manual item: "Test Item"

**Expected Behavior**:
- ✅ Smooth list animations
- ✅ Checkboxes respond immediately
- ✅ No duplicate items
- ✅ List persists after app restart

---

### Flow 5: Recipe Sharing (10 minutes)

**Create a Share**
- [ ] Open any recipe
- [ ] Tap share button
- [ ] Tap "Create Share Link"
- [ ] Wait for share link generation (5-10 seconds)
- [ ] Verify share link created: `https://heirloom.app/share/[ID]`
- [ ] Copy link to clipboard
- [ ] Verify success message shows

**Accept a Share** (requires second device or friend)
- [ ] Send share link to yourself via Messages/Email
- [ ] Open link on **second device** or have friend open it
- [ ] Verify deep link opens Heirloom (or prompts to download)
- [ ] Tap "Accept Recipe"
- [ ] Wait for recipe to import
- [ ] Verify recipe appears in your collection
- [ ] Check all data copied correctly (title, ingredients, instructions, image)

**Share via Native Share Sheet**
- [ ] Open recipe
- [ ] Tap share button
- [ ] Tap "Share Recipe"
- [ ] Choose Messages, Email, or AirDrop
- [ ] Send to yourself or friend
- [ ] Verify recipient can access and accept

**Expected Behavior**:
- ✅ Share link generates quickly (< 10 seconds)
- ✅ dSYM upload happens automatically (Release builds only)
- ✅ Deep links open app correctly
- ✅ No data loss when accepting shares
- ✅ Images transfer correctly

---

### Flow 6: Sync Across Devices (10 minutes)

**Test Multi-Device Sync** (requires 2 devices or iPad)
- [ ] Sign in to same account on Device 1
- [ ] Create new recipe: "Sync Test Recipe"
- [ ] Wait 5-10 seconds
- [ ] Open app on Device 2 (signed in to same account)
- [ ] Pull to refresh recipe list
- [ ] Verify "Sync Test Recipe" appears on Device 2
- [ ] Edit recipe on Device 2 (change title to "Sync Test Edited")
- [ ] Save changes
- [ ] Return to Device 1
- [ ] Pull to refresh
- [ ] Verify title changed to "Sync Test Edited"

**Conflict Resolution Test**
- [ ] Enable airplane mode on both devices
- [ ] Device 1: Edit recipe title to "Version A"
- [ ] Device 2: Edit same recipe title to "Version B"
- [ ] Device 1: Disable airplane mode (changes sync first)
- [ ] Device 2: Disable airplane mode (conflict!)
- [ ] Verify conflict is resolved gracefully (last write wins, or merge dialog)

**Expected Behavior**:
- ✅ Changes sync within 10-15 seconds
- ✅ No data loss
- ✅ Conflicts handled gracefully
- ✅ No duplicate recipes created

---

### Flow 7: Offline Mode (5 minutes)

**Test Offline Functionality**
- [ ] Ensure you have 3-5 recipes already synced
- [ ] Enable Airplane Mode
- [ ] Force quit and reopen app
- [ ] Browse recipe list (should load from local cache)
- [ ] Open individual recipes (should display fully)
- [ ] Try to create new recipe (should work)
- [ ] Try to import from URL (should show "offline" message)
- [ ] Try to share recipe (should show "offline" message)
- [ ] Disable Airplane Mode
- [ ] Wait for sync (10-15 seconds)
- [ ] Verify offline changes synced to cloud

**Expected Behavior**:
- ✅ App doesn't crash in offline mode
- ✅ Local data remains accessible
- ✅ Appropriate error messages for network-dependent features
- ✅ Changes made offline sync when back online

---

### Flow 8: Crashlytics Verification (5 minutes)

**Test Crash Reporting**
- [ ] Go to Settings in the app
- [ ] Scroll to DEBUG section (only visible in Debug builds)
- [ ] Tap "Test Crash Reporting" button
- [ ] App crashes immediately (expected!)
- [ ] Reopen app (this sends crash report to Firebase)
- [ ] Wait 2-3 minutes
- [ ] Open Firebase Console → Crashlytics
- [ ] Verify crash appears with full stack trace
- [ ] Check that `SettingsView.swift:702` is readable (symbolicated)

**Expected Behavior**:
- ✅ Crash report uploads on next app launch
- ✅ Stack trace is fully symbolicated (readable file names)
- ✅ Shows exact line number where crash occurred
- ✅ Custom log message appears: "User triggered test crash from Settings"

---

### Flow 9: Performance & Memory (10 minutes)

**Scroll Performance**
- [ ] Create or import 20+ recipes
- [ ] Scroll rapidly through recipe list
- [ ] Check for smooth 60fps scrolling
- [ ] No stuttering or frame drops
- [ ] Images load progressively (not all at once)

**Memory Pressure**
- [ ] Xcode → Debug → Simulate Memory Warning
- [ ] Verify app doesn't crash
- [ ] Verify images reload after memory warning
- [ ] Check that app state is preserved

**App Launch Time**
- [ ] Force quit app
- [ ] Time how long to launch (stopwatch)
- [ ] Should be < 2 seconds to interactive UI
- [ ] Should be < 5 seconds to fully loaded (Apple requirement)

**Battery Usage** (test over 1 hour)
- [ ] Use app normally for 30-60 minutes
- [ ] Settings → Battery → Show Battery Usage by App
- [ ] Check Heirloom battery usage
- [ ] Should be reasonable (< 10% for 1 hour of use)

**Expected Behavior**:
- ✅ Smooth scrolling at all times
- ✅ No memory leaks or crashes under pressure
- ✅ Fast app launch (< 2 seconds)
- ✅ Reasonable battery consumption

---

### Flow 10: Accessibility Testing (5 minutes)

**VoiceOver**
- [ ] Settings → Accessibility → VoiceOver → On
- [ ] Navigate app using VoiceOver gestures
- [ ] Verify buttons have clear labels
- [ ] Verify recipe content is readable
- [ ] Turn VoiceOver off

**Dynamic Type**
- [ ] Settings → Display & Brightness → Text Size
- [ ] Set to largest size
- [ ] Open Heirloom
- [ ] Verify text scales appropriately
- [ ] No text cutoff or overlap
- [ ] Set back to default size

**Dark Mode**
- [ ] Settings → Display & Brightness → Dark
- [ ] Open Heirloom
- [ ] Browse all screens
- [ ] Verify no visual glitches
- [ ] Check contrast is readable
- [ ] Switch back to Light mode

**Expected Behavior**:
- ✅ All interactive elements have VoiceOver labels
- ✅ Text scales without breaking layout
- ✅ Dark mode is fully supported with good contrast

---

## Known Issues to Watch For

Based on earlier development, watch for these potential issues:

### Firebase-Related
- [ ] Authentication token expiry (sign out/in if API calls fail)
- [ ] Firestore write limits (max 500/sec)
- [ ] Storage upload failures (check network quality)

### Share-Related
- [ ] Deep links not opening app (check URL scheme configured)
- [ ] Share images not transferring (check Storage permissions)
- [ ] Duplicate recipes when accepting shares (sync issue)

### Import-Related
- [ ] PDF imports timing out (long documents)
- [ ] URL imports failing (some websites block scraping)
- [ ] Claude API rate limiting (too many imports quickly)

### General
- [ ] Keyboard dismissal issues on certain screens
- [ ] Search not updating results live
- [ ] Images not loading on slow networks

---

## After Testing: Report Issues

### Create Bug Reports
For any issues found, document:
1. **What you did** (steps to reproduce)
2. **What happened** (actual behavior)
3. **What should happen** (expected behavior)
4. **Device info** (iPhone model, iOS version)
5. **Screenshots or screen recording** (if applicable)

### Check Crashlytics Dashboard
- [ ] Firebase Console → Crashlytics
- [ ] Look for new crashes from your testing
- [ ] Verify crash reports are symbolicated
- [ ] Note any critical issues

### Check Mixpanel Analytics
- [ ] Mixpanel Dashboard → Live View
- [ ] Verify events are being tracked
- [ ] Check user properties are set correctly
- [ ] Confirm no errors in event transmission

---

## Sign-Off Checklist

Before declaring "Ready for TestFlight":
- [ ] All 10 critical flows tested and passed
- [ ] No crash-on-launch bugs
- [ ] No data loss bugs
- [ ] Authentication works reliably
- [ ] Sync works across devices
- [ ] Offline mode works as expected
- [ ] Performance is acceptable (smooth scrolling, fast launch)
- [ ] Crashlytics reports appearing in Firebase
- [ ] No memory leaks detected
- [ ] Accessibility features work

**Tester**: _________________________
**Date**: _________________________
**Device**: _________________________
**iOS Version**: _________________________
**Result**: ☐ Pass  ☐ Fail (notes below)

---

## Next Steps After Physical Testing

Once physical device testing passes:

1. **Archive for TestFlight**
   ```bash
   # In Xcode:
   Product → Archive
   Wait for archive to complete
   Distribute App → App Store Connect
   Upload
   ```

2. **Set Up TestFlight**
   - Add internal testers
   - Write "What to Test" notes
   - Enable automatic distribution

3. **Monitor First TestFlight Build**
   - Check Crashlytics for new crashes
   - Watch for tester feedback
   - Fix critical issues before external testing

4. **Expand to External Testing**
   - Add external testers once stable
   - Submit for Beta App Review
   - Collect feedback for 1-2 weeks

5. **Prepare for App Store Submission**
   - Address all major feedback
   - Update screenshots if needed
   - Final polish and bug fixes
   - Submit for App Store Review

---

**Remember**: Physical device testing is the **last gate** before real users. Take your time and be thorough!
