# Firebase Crashlytics Setup

**Date**: 2026-01-23
**Status**: ✅ **Code Added** - Xcode Configuration Needed

---

## ✅ Completed (Code Changes)

### 1. Import Added
**File**: `Heirloom/App/HeirloomApp.swift`

```swift
import FirebaseCrashlytics  // Added
```

### 2. Initialization Added
**File**: `Heirloom/App/HeirloomApp.swift` (after FirebaseApp.configure())

```swift
// Enable Crashlytics for crash reporting and monitoring
DeviceLogger.shared.log("🔧 [Heirloom] Enabling Crashlytics...")
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
DeviceLogger.shared.log("✅ [Heirloom] Crashlytics enabled")
Log.info("Crashlytics crash reporting enabled", category: .general)
```

**Location**: Line ~165 in HeirloomApp.swift

---

## ⏳ TODO: Xcode Build Phase Configuration

To upload debug symbols (dSYMs) to Crashlytics, you need to add a build phase script.

### Steps in Xcode:

1. **Open Heirloom.xcodeproj in Xcode**

2. **Select the Heirloom Target**
   - In the Project Navigator, click on "Heirloom" (blue icon)
   - Select "Heirloom" target from the list

3. **Add Run Script Phase**
   - Click "Build Phases" tab
   - Click "+" button → "New Run Script Phase"
   - Drag it to be **after** "Compile Sources" but **before** "Copy Bundle Resources"

4. **Name the Script**
   - Expand the "Run Script" phase
   - Change name to: "Upload Crashlytics dSYMs"

5. **Add the Script**
   ```bash
   # Upload debug symbols to Crashlytics
   # This enables symbolicated crash reports

   if [ "${CONFIGURATION}" = "Release" ]; then
     "${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
   fi
   ```

6. **Configure Script Settings**
   - Check "Based on dependency analysis" (optional, improves build time)
   - Input Files: (leave empty)
   - Output Files: (leave empty)

7. **Build the App**
   - Build for Release configuration
   - Verify script runs without errors

---

## 🧪 Testing Crashlytics

### Test Crash in Debug Build

**Option 1: Add Test Crash Button (Recommended)**

Add to `SettingsView.swift` in a debug-only section:

```swift
#if DEBUG
Section("Debug Tools") {
    Button("Test Crash Reporting") {
        fatalError("Test crash for Crashlytics verification")
    }
    .foregroundStyle(.red)
}
#endif
```

**Option 2: Trigger Crash Programmatically**

Add this anywhere you can trigger it (like a button tap):

```swift
Crashlytics.crashlytics().log("About to crash for testing")
fatalError("Test crash")
```

### Verify in Firebase Console

1. **Trigger the crash** (tap test button or trigger crash code)
2. **App will crash and close**
3. **Reopen the app** (crash reports are sent on next launch)
4. **Wait 5-10 minutes** for processing
5. **Check Firebase Console**:
   - Go to: https://console.firebase.google.com/project/heirloom-ios-prod/crashlytics
   - You should see the crash report
   - Stack trace should be symbolicated (readable function names)

---

## 📊 What Crashlytics Tracks

### Automatic Crash Tracking ✅
- Fatal crashes (fatalError, force unwraps, etc.)
- Uncaught exceptions
- Stack traces with line numbers
- Device info (iOS version, model)
- App version and build number

### Custom Logging (Optional)
You can add breadcrumbs for context:

```swift
// Log events leading up to a crash
Crashlytics.crashlytics().log("User tapped share button")
Crashlytics.crashlytics().log("Fetching recipe data")

// Set custom keys
Crashlytics.crashlytics().setCustomValue(recipe.id, forKey: "recipe_id")
Crashlytics.crashlytics().setCustomValue(user.isPremium, forKey: "is_premium")

// Set user identifier (for tracking crashes per user)
Crashlytics.crashlytics().setUserID(userId)
```

### Non-Fatal Errors (Optional)
Track errors that don't crash the app:

```swift
do {
    try someRiskyOperation()
} catch {
    // Log non-fatal error to Crashlytics
    Crashlytics.crashlytics().record(error: error)
}
```

---

## 🚨 Monitoring Alerts

### Firebase Console Alerts

**Set up in Firebase Console**:
1. Go to Crashlytics
2. Click "Settings" (gear icon)
3. Configure alerts:
   - New issue detected
   - Velocity alert (spike in crashes)
   - Stability digest (daily summary)

**Recommended Settings**:
- ✅ Enable "New issue detected" (immediate Slack/email)
- ✅ Enable velocity alerts (threshold: 1% of sessions)
- ✅ Enable daily digest

### Crash-Free Users Target

**Goal**: > 99.5% crash-free users

**How to Track**:
- Firebase Console → Crashlytics → Dashboard
- "Crash-free users" metric prominently displayed
- Track trend over time

**Alert Thresholds**:
- 🔴 **Critical**: < 98% crash-free (immediate action)
- 🟡 **Warning**: < 99% crash-free (investigate)
- 🟢 **Good**: > 99.5% crash-free

---

## 🔧 Troubleshooting

### "No crash reports appearing"

**Check**:
1. ✅ FirebaseCrashlytics imported and initialized
2. ✅ App reopened after crash (reports sent on next launch)
3. ✅ Wait 5-10 minutes for processing
4. ✅ Build is Release configuration (Debug might not upload symbols)
5. ✅ GoogleService-Info.plist is in the bundle

### "Crash reports are not symbolicated"

**Fix**:
1. ✅ Add the dSYM upload script (Build Phase)
2. ✅ Ensure script runs in Release builds
3. ✅ Check script output for errors
4. ✅ Manually upload dSYMs if needed:
   ```bash
   # Find dSYM file
   find ~/Library/Developer/Xcode/DerivedData -name "*.dSYM"

   # Upload to Crashlytics (if automatic upload fails)
   # Use Firebase Console → Crashlytics → Missing dSYMs
   ```

### "Crashlytics disabled in test environment"

**Expected**: Crashlytics is only enabled in production builds (not in test environment).

The code checks `isRunningTests` before initializing Firebase and Crashlytics.

---

## 📋 Checklist

### Code Integration
- [x] Import FirebaseCrashlytics
- [x] Initialize Crashlytics after Firebase.configure()
- [x] Code committed to repository

### Xcode Configuration
- [ ] Add "Upload Crashlytics dSYMs" Run Script phase
- [ ] Verify script in Build Phases tab
- [ ] Build app in Release configuration

### Testing
- [ ] Add test crash button to SettingsView (debug only)
- [ ] Trigger test crash
- [ ] Reopen app (sends crash report)
- [ ] Verify crash appears in Firebase Console
- [ ] Verify stack trace is symbolicated (readable)

### Monitoring
- [ ] Configure Firebase Console alerts
- [ ] Set up Slack/email notifications
- [ ] Add Crashlytics to monitoring checklist
- [ ] Document crash-free users baseline

---

## 🎯 Success Criteria

**Crashlytics is working when**:
- ✅ Test crash appears in Firebase Console
- ✅ Stack trace shows actual function names (not hex addresses)
- ✅ Crash includes device info and context
- ✅ Alerts fire when new crashes detected
- ✅ Dashboard shows crash-free users %

---

## 📚 Resources

- **Firebase Crashlytics Docs**: https://firebase.google.com/docs/crashlytics/get-started?platform=ios
- **Console**: https://console.firebase.google.com/project/heirloom-ios-prod/crashlytics
- **Troubleshooting**: https://firebase.google.com/docs/crashlytics/troubleshooting?platform=ios

---

**Last Updated**: 2026-01-23
**Status**: Code ready, Xcode configuration pending
**Next Step**: Add Run Script phase in Xcode
