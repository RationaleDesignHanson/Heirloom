# Sharing & Deep Link Troubleshooting Guide

This guide helps debug issues with recipe sharing, deep links, and CloudKit integration.

## Log Emoji Guide

Our logging uses emoji prefixes for quick visual scanning:

- 📤 **Outgoing operation** - Creating shares, uploading to CloudKit
- 📥 **Incoming operation** - Accepting shares, downloading from CloudKit
- ✅ **Success** - Operation completed successfully
- ❌ **Error** - Operation failed
- ⚠️ **Warning** - Non-critical issue or fallback behavior
- 🔍 **Investigation** - Checking status, querying data
- 🔄 **Retry** - Retrying failed operation
- ⏳ **Waiting** - Delay before retry or async operation
- 📱 **App Lifecycle** - App state changes, URL handling
- 🔗 **Deep Link** - URL processing, routing
- ☁️ **CloudKit** - CloudKit-specific operations
- 💾 **Data** - SwiftData operations, local storage
- 📦 **Component** - Card back, comments, ingredients
- 🎁 **Pass Down** - Family recipe sharing with generations
- 💌 **Notification** - Push notifications, thank you messages
- 📊 **Analytics** - Tracking, metrics
- 🧹 **Cleanup** - Removing old data, clearing cache

## Common Issues & Solutions

### 1. Share URL is Nil After Creation

**Symptoms:**
```
✅ Share created successfully: no URL
❌ Share exists but URL is nil
```

**Cause:** CloudKit doesn't populate `CKShare.url` immediately after save

**Solution:** Automatic retry logic (implemented)
- First attempt: Immediate (0s delay)
- Second attempt: 2s delay
- Third attempt: 5s delay

**Logs to Check:**
```
🔄 Fetching share (attempt 1/3)...
⏳ Waiting 2.0s before fetch attempt 2/3...
✅ Share URL obtained on attempt 2: https://www.icloud.com/...
```

### 2. Duplicate Shares Created

**Symptoms:**
- Multiple shares exist for the same recipe
- "Share already exists" errors when trying to use link

**Cause:** User taps "Create Share" multiple times before first completes

**Solution:** Duplicate prevention (implemented)
- Always check for existing share before creating new one
- Reuse existing share if found, even if URL is nil
- Refresh existing share to get URL

**Logs to Check:**
```
🔍 Checking for existing share...
ℹ️ Found existing share for recipe
✅ Existing share has URL, reusing
```

### 3. Duplicate Share Acceptance

**Symptoms:**
- Recipe appears twice in collection
- "You already have this recipe" message doesn't appear

**Cause:** Same share accepted multiple times

**Solution:** Duplicate acceptance prevention (implemented)
- Check `provenance.parentShareID` before accepting
- Return existing recipe if already accepted

**Logs to Check:**
```
🔍 Checking for already-accepted share...
ℹ️ This share was already accepted
```

### 4. Share Link Opens Safari Instead of App

**Symptoms:**
- CloudKit share URL opens in Safari
- User has to manually tap "Open in Heirloom"

**Cause:** Universal links not configured (expected behavior in Phase 1)

**Solution:** Deploy universal links in Phase 2
- See `ShortURLService.swift` migration guide
- Deploy apple-app-site-association file
- Uncomment associated domains in entitlements

### 5. iCloud Not Available

**Symptoms:**
```
⚠️ iCloud not available: 0 (notAuthenticated)
```

**Cause:** User not signed into iCloud

**Solution:** Automatic detection (implemented)
- Check iCloud status on share sheet open
- Show user-friendly message with instructions
- Disable share button when unavailable

**Logs to Check:**
```
✅ iCloud is available
⚠️ iCloud not available: 0 (notAuthenticated)
```

### 6. Network Errors During Sharing

**Symptoms:**
```
❌ Share creation failed: network unavailable
⚠️ Attempt 1/3 failed: No internet connection
```

**Cause:** No internet connection or CloudKit service unavailable

**Solution:** Automatic retry (implemented)
- Retry transient errors automatically
- Show user-friendly error messages
- Suggest actions (check connection, wait for iCloud)

**Logs to Check:**
```
⚠️ Attempt 1/3 failed: No internet connection
⏳ Retrying in 5.0s... (warning error)
✅ Operation succeeded on attempt 2/3
```

### 7. Card Back Not Transferring

**Symptoms:**
- Recipe transferred but no card back, rating, or notes
- Share options say "Include Card Back" but nothing appears

**Cause:** Card back not uploaded to CloudKit or not imported

**Solution:** Full component import (implemented)
- Upload card back when creating share
- Import card back when accepting share
- Handle missing components gracefully

**Logs to Check:**
```
📤 Uploading card back for Chocolate Chip Cookies
✅ Uploaded card back
📄 Fetching card back data...
✅ Found card back, importing...
✅ Card back imported
```

### 8. Deep Link Not Processing

**Symptoms:**
- Tap share link, nothing happens
- App opens but doesn't show acceptance sheet

**Cause:** URL queued but not processed, or app not marked ready

**Solution:** Robust URL queuing (implemented)
- Queue URLs during cold launch
- Process all queued URLs when app ready
- Prevent duplicate URL processing

**Logs to Check:**
```
📥 DeepLinkHandler received URL: https://www.icloud.com/...
⏳ App not ready, queuing URL for later
📝 Queue now has 1 URL(s)
✅ App marked as ready for deep links
📱 Processing 1 queued URL(s)
```

## Debugging Deep Links

### Testing Deep Link Flow

1. **Cold Launch** (app not running)
   ```
   📥 DeepLinkHandler received URL: ...
   ⏳ App not ready, queuing URL for later
   📝 Queue now has 1 URL(s)
   ✅ App marked as ready for deep links
   📱 Processing 1 queued URL(s)
   🔄 Processing URL: ...
   ☁️ Handling CloudKit share URL: ...
   🔍 Fetching share metadata...
   ✅ Share metadata fetched successfully
   ```

2. **Warm Launch** (app in background)
   ```
   📥 DeepLinkHandler received URL: ...
   ✅ App is ready, processing immediately
   🔄 Processing URL: ...
   ```

3. **Foreground** (app already open)
   ```
   📥 DeepLinkHandler received URL: ...
   ✅ App is ready, processing immediately
   🔄 Processing URL: ...
   ```

### Duplicate URL Prevention

```
📥 DeepLinkHandler received URL: https://www.icloud.com/share/xxx
⚠️ Ignoring duplicate URL (processed 0.5s ago)
```

## Debugging CloudKit Errors

### Error Categories

1. **Critical Errors** (user must act)
   - `.notAuthenticated` - Sign in to iCloud
   - `.permissionDenied` - Contact recipe owner
   - `.quotaExceeded` - Free up iCloud storage

2. **Warning Errors** (transient, will resolve)
   - `.networkUnavailable` - Check connection
   - `.serviceUnavailable` - CloudKit down
   - `.rateLimited` - Too many requests

3. **Info Errors** (handled automatically)
   - `.conflictDetected` - Merging changes
   - `.zoneBusy` - CloudKit processing

4. **Error Errors** (something wrong)
   - `.recordNotFound` - Recipe deleted
   - `.badRequest` - Invalid request
   - `.internalError` - CloudKit error

### Retry Behavior

```
⚠️ Attempt 1/3 failed: No internet connection
⏳ Retrying in 5.0s... (warning error)
⚠️ Attempt 2/3 failed: No internet connection
⏳ Retrying in 5.0s... (warning error)
❌ Operation failed (non-retryable or final attempt): No internet connection
```

Retry delays:
- `.rateLimited`: 30s
- `.zoneBusy`: 10s
- `.serviceUnavailable`: 15s
- `.conflictDetected`: 1s
- `.networkUnavailable`: 5s
- `.internalError`: 5s

## Testing Checklist

### Share Creation
- [ ] Create share with all options enabled
- [ ] Create share with minimal options
- [ ] Create share while offline (should fail gracefully)
- [ ] Create share when not signed into iCloud (should show error)
- [ ] Create share twice rapidly (should reuse existing)
- [ ] Create share after previous share deleted

### Share Acceptance
- [ ] Accept share from Messages
- [ ] Accept share from Safari
- [ ] Accept share from email
- [ ] Accept share during cold launch
- [ ] Accept share while app in background
- [ ] Accept same share twice (should show "already accepted")
- [ ] Accept share while offline (should retry)

### Component Transfer
- [ ] Share with card back enabled → verify received
- [ ] Share with rating enabled → verify received
- [ ] Share with notes enabled → verify received
- [ ] Share with pinned comments → verify received
- [ ] Share with all comments → verify received
- [ ] Share with stickers → verify received

### Error Handling
- [ ] Create share while offline
- [ ] Accept share while offline
- [ ] Create share with iCloud storage full
- [ ] Accept expired share
- [ ] Accept share from deleted recipe
- [ ] Revoke share, then try to accept

### Deep Links
- [ ] heirloom://share/{base64-url} opens app
- [ ] CloudKit URL opens app (not Safari)
- [ ] Multiple URLs queued during cold launch
- [ ] Duplicate URLs ignored within 2s window

## Logging Levels

Our app uses different logging levels based on severity:

1. **Debug** - Verbose logging for development
   - All emoji logs above
   - Function entry/exit
   - Variable values

2. **Info** - Important but not concerning
   - Share created
   - Share accepted
   - Components imported

3. **Warning** - Non-critical issues
   - Retry attempts
   - Fallback behavior
   - Missing optional data

4. **Error** - Critical failures
   - Share creation failed
   - Network errors
   - CloudKit errors

## Device Logger

Use `DeviceLogger.shared` for persistent logs:

```swift
DeviceLogger.shared.log("✅ Share URL ready for recipe: \(recipe.title)")
DeviceLogger.shared.log("❌ Share creation failed", level: .error)
```

Logs are stored locally and can be exported for debugging.

## Analytics Events

Key events tracked:
- Share created
- Share accepted
- Component transferred
- Error occurred
- Retry attempted
- URL processed

## Contact Support

If issues persist:
1. Export Device Logger logs
2. Note timestamp of issue
3. Include recipe title and share URL (if available)
4. Describe steps to reproduce
