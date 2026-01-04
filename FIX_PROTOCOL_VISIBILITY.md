# Fix Protocol Visibility Issue

## Problem

Build errors:
```
FirebaseLineageService.swift:22: error: cannot find type 'FirebaseSyncServiceProtocol' in scope
DeepLinkHandler.swift:13: error: cannot find type 'FirebaseShareServiceProtocol' in scope
```

## Root Cause

The `FirebaseServiceProtocols.swift` file may not be properly added to the Xcode project target, causing the protocols to not be visible to other files in the same module.

## Solution

### Option 1: Verify Target Membership in Xcode (RECOMMENDED)

1. Open `Heirloom.xcodeproj` in Xcode
2. Navigate to `Heirloom/Core/Services/Firebase/Protocols/FirebaseServiceProtocols.swift` in Project Navigator
3. Select the file
4. Open File Inspector (⌥⌘1 or View → Inspectors → File)
5. Check the **Target Membership** section
6. Ensure **Heirloom** checkbox is **CHECKED** ✅
7. Clean build folder (⇧⌘K)
8. Build (⌘B)

### Option 2: Re-add the File

If target membership is already checked:

1. In Xcode Project Navigator, **delete** `FirebaseServiceProtocols.swift` (select "Remove Reference" NOT "Move to Trash")
2. Right-click on `Protocols` folder → "Add Files to 'Heirloom'..."
3. Navigate to and select `FirebaseServiceProtocols.swift`
4. **IMPORTANT:** Ensure these are checked:
   - ☑ "Add to targets: Heirloom"
   - ☑ "Create groups"
   - ☐ "Copy items if needed" (should be UNCHECKED)
5. Click "Add"
6. Clean build folder (⇧⌘K)
7. Build (⌘B)

### Option 3: Check Build Phases

1. In Xcode, select the **Heirloom** project in Project Navigator
2. Select the **Heirloom** target
3. Go to **Build Phases** tab
4. Expand **Compile Sources**
5. Verify `FirebaseServiceProtocols.swift` is listed
6. If not, click **+** and add it
7. Clean build folder (⇧⌘K)
8. Build (⌘B)

## Verification

After applying the fix, these imports should work:

```swift
// In FirebaseLineageService.swift
private let firebaseSync: FirebaseSyncServiceProtocol  // Should compile

// In DeepLinkHandler.swift
private let firebaseShare: FirebaseShareServiceProtocol  // Should compile
```

## Why This Happened

When you manually added the DI files to Xcode, you may have:
- Forgotten to check the "Heirloom" target checkbox
- Selected "Create Folder References" instead of "Create Groups"
- Not added `FirebaseServiceProtocols.swift` at all (only the DI folder files)

## Alternative: Explicit Module Import (Not Recommended)

If the above doesn't work, you could theoretically make protocols public and import them, but since everything is in the same module, this shouldn't be necessary:

```swift
// NOT RECOMMENDED - All files are in same module
public protocol FirebaseSyncServiceProtocol { ... }
```

## Expected Behavior

All Swift files in the same target should be able to see each other's types without explicit imports. If protocols defined in `FirebaseServiceProtocols.swift` are not visible, it means that file is not being compiled as part of the target.

## Status

**Build Status:** ❌ Failing (3 protocol visibility errors)
**DI Migration:** 18% complete (9/52 services)
**Next Step:** Fix target membership, then build should succeed

