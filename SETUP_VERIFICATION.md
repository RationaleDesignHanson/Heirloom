# Setup Verification Checklist

Quick verification that Steps 1-3 are complete.

## Verify in Apple Developer Portal

Go to [Identifiers](https://developer.apple.com/account/resources/identifiers/list)

### 1. App ID Check
- Dropdown: **"App IDs"**
- Look for: `com.matthanson.heirloom` or "Heirloom"
- Click on it
- Scroll to Capabilities section
- Should see:
  - ✅ **iCloud** - Enabled with "Configurable"
  - ✅ **App Groups** - Enabled with "Configurable"

### 2. CloudKit Container Check
- Change dropdown to: **"iCloud Containers"**
- Should see: `iCloud.com.matthanson.heirloom`
- Status: Active

### 3. App Group Check
- Change dropdown to: **"App Groups"**
- Should see: `group.com.matthanson.heirloom.shared`
- Status: Active

## If All Three Pass ✅

You're ready for Step 4: Provisioning Profiles!

## If Something is Missing ❌

Let me know which one and I'll help you fix it.
