# File-Based Logging - Build 1.1.3 (20)

**Date:** 2025-12-28
**Critical Discovery:** NSLog, print(), and os_log Logger ALL fail to appear on TestFlight devices
**Solution:** File-based logging that writes to app Documents directory

---

## The Logging Problem

### What We Tried (All Failed):
1. **print()** - Only works in Xcode debugger ❌
2. **NSLog()** - Doesn't appear on TestFlight devices ❌
3. **os_log Logger** - Doesn't appear in Console.app ❌

### Evidence from Testing:
```
✅ App launches successfully on device
✅ UI loads and functions normally
❌ ZERO custom logs visible in Console.app
❌ ZERO logs visible with subsystem filter
❌ ZERO logs in device system logs
```

**Proof:** `/Users/matthanson/Desktop/errrrrr.txt` shows app running but no initialization logs at all

---

## The Solution: File-Based Logging

### How It Works:
1. **DeviceLogger** writes to: `Documents/heirloom_debug.log`
2. Log file is accessible via:
   - Settings → Developer Testing → **View Debug Log** (in-app viewer)
   - Files app → On My iPhone → Heirloom
   - Xcode → Devices → Download Container
   - Share button to export log file

### Implementation:

**DeviceLogger.swift** - Singleton logger service
```swift
DeviceLogger.shared.log("🚀 App starting...")
DeviceLogger.shared.log("❌ Error occurred", level: .error)
```

**DebugLogView.swift** - In-app log viewer
- Refresh, Clear, and Share buttons
- Monospaced text display
- Text selection enabled for copying
- Accessible from Settings → Developer Testing

---

## Testing Build 1.1.3 (20)

### Pre-Flight:
1. Archive in Xcode → Distribute → TestFlight
2. Upload to App Store Connect
3. Wait for processing (~5-10 min)
4. Install from TestFlight on device

### Step 1: Launch and Generate Logs

**On iPhone:**
1. Install build **1.1.3 (20)** from TestFlight
2. Launch Heirloom
3. App will automatically log:
   - Initialization sequence
   - SwiftData setup
   - Service initialization
   - CloudKit status (disabled for Phase 1)

### Step 2: View Debug Log

**In Heirloom App:**
1. Tap **Settings** tab (gear icon)
2. Scroll to **Developer Testing** section
3. Tap **View Debug Log** (📁 icon)
4. You should see:
   ```
   2025-12-28T... [ℹ️] 🚀 [Heirloom] HeirloomApp.init() called - starting initialization
   2025-12-28T... [ℹ️] 🔧 [Heirloom] Configuring SwiftData schema...
   2025-12-28T... [ℹ️] ✅ [Heirloom] SwiftData initialized (Local storage, manual CloudKit sync)
   2025-12-28T... [ℹ️] ⏸️  [Heirloom] CloudKit sync DISABLED for Phase 1 testing
   ```

### Step 3: Test Recipe Operations

**Create a Recipe:**
1. Tap **Add** tab (+)
2. Create test recipe with ingredients and instructions
3. Save recipe
4. Go back to **Settings → View Debug Log**
5. Tap **Refresh** button
6. Verify recipe creation was logged

**Edit a Recipe:**
1. Open existing recipe
2. Make edits
3. Save changes
4. Check debug log for edit operations

**Delete a Recipe:**
1. Swipe to delete recipe
2. Confirm deletion
3. Check debug log

### Step 4: Export Log File

**Share Log for Analysis:**
1. In Debug Log viewer, tap **Share** button
2. Options:
   - AirDrop to Mac
   - Save to Files app
   - Send via Messages/Email
3. Save to `/Users/matthanson/Desktop/device_log.txt`

---

## Expected Log Output

### Successful Launch:
```
2025-12-28T20:XX:XX [ℹ️] 📁 Log file created at: /var/.../Documents/heirloom_debug.log
2025-12-28T20:XX:XX [ℹ️] 🚀 [Heirloom] HeirloomApp.init() called - starting initialization
2025-12-28T20:XX:XX [ℹ️] 🔧 [Heirloom] Configuring SwiftData schema...
2025-12-28T20:XX:XX [ℹ️] ✅ [Heirloom] SwiftData initialized (Local storage, manual CloudKit sync)
2025-12-28T20:XX:XX [ℹ️] ⏸️  [Heirloom] CloudKit sync DISABLED for Phase 1 testing
```

### If Errors Occur:
```
2025-12-28T20:XX:XX [❌] ❌ [Heirloom] Failed to configure SwiftData: <error details>
```

---

## Success Criteria

**Build 1.1.3 (20) PASSES if:**
- ✅ Log file is created on launch
- ✅ Initialization logs appear in Debug Log viewer
- ✅ Can view log in-app (Settings → Developer Testing)
- ✅ Can refresh and see new logs
- ✅ Can export log file via Share
- ✅ App functions normally (create/edit/delete recipes)

**Build 1.1.3 (20) FAILS if:**
- ❌ No log file created
- ❌ Log viewer shows "Unable to load log file"
- ❌ No initialization logs
- ❌ App crashes on launch

---

## Advantages of File-Based Logging

1. **Guaranteed to work** - Not subject to iOS system log filtering
2. **Always accessible** - Available even after app closes
3. **Persistent** - Survives app restarts
4. **Shareable** - Can export and analyze on Mac
5. **In-app viewer** - No need for Mac/Console.app
6. **User-friendly** - Copy/paste text, share button

---

## Next Steps After Phase 1 Passes

### Phase 2: Enable CloudKit with Comprehensive Logging
1. Uncomment CloudKit initialization in HeirloomApp.swift
2. Add DeviceLogger calls throughout CloudKitSyncService
3. Log every sync operation, upload, download
4. Archive build 1.1.3 (21)
5. Test and capture CloudKit errors in debug log

### Phase 3: Fix CloudKit Schema & Test End-to-End
1. Fix "recordName not queryable" in CloudKit Dashboard
2. Test recipe sync end-to-end
3. Verify recipes appear in CloudKit Dashboard
4. Test sharing with synced recipes

---

## Log File Location

**On Device:**
- Path: `/var/mobile/Containers/Data/Application/<UUID>/Documents/heirloom_debug.log`
- Access via: Settings → Developer Testing → View Debug Log

**Export Methods:**
1. **In-App Share:** Tap Share button in Debug Log viewer
2. **Files App:** On My iPhone → Heirloom folder
3. **Xcode:** Window → Devices → Select device → Download Container

---

## Troubleshooting

### Log Viewer Shows "No logs yet"
- Close and relaunch app
- Tap Refresh button
- Check if app has file write permissions

### Can't Find Debug Log Option
- Verify build 1.1.3 (20) installed
- Go to Settings tab (not iOS Settings)
- Scroll to "Developer Testing" section
- Look for "View Debug Log" with 📁 icon

### Log File Too Large
- Tap **Clear** button to reset log
- Only keeps current session logs
- Fresh start for each test

---

**Build:** 1.1.3 (20)
**Status:** Ready for archive and TestFlight upload
**Testing Priority:** CRITICAL - This is our only way to see what's happening on device
