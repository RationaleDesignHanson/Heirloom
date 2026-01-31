# Bundle Identifier Migration - Fix Checklist

## Problem
After changing developer certificates from **Matt Hanson** to **Rationale Design LLC**, authentication was failing with error:
> "The audience in ID Token [com.rationaledesign.heirloom] does not match the expected audience."

## What Was Changed (✅ COMPLETED)

### 1. Code & Configuration Files
- ✅ `GoogleService-Info.plist` - Updated BUNDLE_ID to `com.rationaledesign.heirloom`
- ✅ `Info.plist` - Updated background task identifiers and URL scheme
- ✅ `HeirloomApp.swift` - Updated logger subsystem
- ✅ `SharedConstants.swift` - Updated app group to `group.com.rationaledesign.heirloom`
- ✅ `VideoProcessingJobManager.swift` - Updated background task IDs
- ✅ `CollectionImageRefreshTask.swift` - Updated task identifier
- ✅ `ShareViewController.swift` - Updated error domain
- ✅ `ProcessingMonitor.swift` - Updated logger subsystems
- ✅ `apple-app-site-association` - Updated Team ID from `Q2HHH2GDN8` to `SF39D6367Y`
- ✅ Firebase Hosting AASA redeployed

### 2. Team & Bundle ID Changes
- **Old Team ID**: Q2HHH2GDN8 (Matt Hanson)
- **New Team ID**: SF39D6367Y (Rationale Design LLC)
- **Old Bundle ID**: com.matthanson.heirloom
- **New Bundle ID**: com.rationaledesign.heirloom
- **Old App Group**: group.com.matthanson.heirloom.shared
- **New App Group**: group.com.rationaledesign.heirloom

---

## What You Need To Do in Xcode (⚠️ REQUIRED)

### Step 1: Update Signing & Capabilities

1. **Open Xcode** → Select **Heirloom** project
2. **Select Heirloom target** (main app)
3. Go to **Signing & Capabilities** tab

#### A. Signing Team
- **Team**: Select **Rationale Design Limited Liability Corporation (SF39D6367Y)**
- **Bundle Identifier**: Should already be `com.rationaledesign.heirloom`

#### B. App Groups
- Remove old: `group.com.matthanson.heirloom.shared`
- Add new: `group.com.rationaledesign.heirloom`

#### C. Associated Domains
- Verify: `applinks:heirloom-ios-prod.web.app`
- Verify: `applinks:heirloom-ios-prod.firebaseapp.com`
- **OR** if using custom domain: `applinks:heirloom.app`

#### D. Sign in with Apple
- Should be enabled with **"Default"** configuration

### Step 2: Update Share Extension Target

Repeat the same steps for **HeirloomShareExtension** target:
- **Team**: Rationale Design LLC (SF39D6367Y)
- **Bundle Identifier**: `com.rationaledesign.heirloom.HeirloomShareExtension`
- **App Group**: `group.com.rationaledesign.heirloom`

### Step 3: Clean Build
```bash
# In Xcode:
Product → Clean Build Folder (Cmd+Shift+K)
Product → Build (Cmd+B)
```

---

## What You Need To Do in Firebase Console (⚠️ CRITICAL)

### Step 1: Update iOS App Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **heirloom-ios-prod**
3. Click ⚙️ → **Project settings**
4. Scroll to **Your apps** section
5. Find your iOS app
6. Click the **...** menu → **Settings**

### Step 2: Update Bundle ID

**Option A: If You Can Edit Bundle ID Directly**
- Change Bundle ID from `com.matthanson.heirloom` to `com.rationaledesign.heirloom`

**Option B: If Bundle ID is Locked (More Likely)**
You'll need to register a NEW iOS app with the correct bundle ID:

1. **Add New iOS App**:
   - Bundle ID: `com.rationaledesign.heirloom`
   - App nickname: `Heirloom (Rationale Design)`
   - App Store ID: (leave empty if not published yet)

2. **Download NEW GoogleService-Info.plist**:
   - After creating the app, download the new plist file
   - **Replace** your current `GoogleService-Info.plist` in Xcode

3. **Copy Configuration**:
   - OAuth Client IDs (for Sign in with Apple/Google)
   - Firebase Storage rules
   - Any custom settings from the old app

4. **Update Sign in with Apple**:
   - Go to **Authentication** → **Sign-in method**
   - Ensure **Apple** is enabled
   - Verify it's configured for the new bundle ID

5. **Update Google Sign-In**:
   - Ensure **Google** is enabled
   - Download the new OAuth client configuration
   - Update `REVERSED_CLIENT_ID` in `Config.xcconfig` (if it changed)

### Step 3: Update Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. **Certificates, Identifiers & Profiles** → **Identifiers**
3. Find: `com.rationaledesign.heirloom`

#### A. Enable Sign in with Apple
- Check **Sign in with Apple** capability
- Configure **Primary App ID**

#### B. Update App Groups
- Add: `group.com.rationaledesign.heirloom`
- Remove old group if no longer needed

#### C. Update Associated Domains
- Add: `applinks:heirloom-ios-prod.web.app`
- Add: `applinks:heirloom-ios-prod.firebaseapp.com`

#### D. Provisioning Profiles
- **Delete old provisioning profiles** for `com.matthanson.heirloom`
- **Create new profiles** for:
  - Development: `com.rationaledesign.heirloom`
  - Distribution: `com.rationaledesign.heirloom`
  - Share Extension Development: `com.rationaledesign.heirloom.HeirloomShareExtension`
  - Share Extension Distribution: `com.rationaledesign.heirloom.HeirloomShareExtension`

---

## Testing Checklist (After Changes)

### 1. Sign in with Apple
```
1. Launch app
2. Tap "Sign in with Apple"
3. Complete Apple authentication
4. Verify successful login (no audience error)
```

### 2. Google Sign In
```
1. Launch app
2. Tap "Sign in with Google"
3. Complete Google authentication
4. Verify successful login
```

### 3. App Group (Share Extension)
```
1. Open Safari or Photos
2. Share a recipe image
3. Select "Heirloom" Share Extension
4. Verify import works
5. Check shared container access
```

### 4. Universal Links
```
1. Send yourself a profile URL: https://heirloom-ios-prod.web.app/u/{userId}
2. Tap link in Messages
3. Verify app opens (not Safari)
4. Verify PublicProfileSheet displays
```

### 5. Background Tasks
```
1. Import a video recipe
2. Force quit app
3. Wait 15 minutes
4. Relaunch app
5. Verify video processing resumed
```

---

## Common Issues & Solutions

### Issue: "Audience in ID Token does not match"
**Cause**: Firebase still expecting old bundle ID
**Fix**: Update Firebase Console iOS app configuration (see above)

### Issue: "Cannot access shared container"
**Cause**: App group not configured correctly
**Fix**:
1. Xcode → Signing & Capabilities → App Groups
2. Add `group.com.rationaledesign.heirloom`
3. Apple Developer Portal → Update identifier

### Issue: Universal links open Safari instead of app
**Cause**: AASA file not associated with new Team ID
**Fix**: Already deployed, but verify:
```bash
curl https://heirloom-ios-prod.web.app/.well-known/apple-app-site-association
# Should show: SF39D6367Y.com.rationaledesign.heirloom
```

### Issue: Share Extension can't import
**Cause**: Share Extension bundle ID or app group mismatch
**Fix**:
1. Update Share Extension target bundle ID
2. Add app group to Share Extension capabilities
3. Rebuild

---

## Verification Commands

### Check Current Bundle ID in Build
```bash
cd /Users/matthanson/Heirloom
xcodebuild -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER
# Should show: com.rationaledesign.heirloom
```

### Verify AASA Deployment
```bash
curl https://heirloom-ios-prod.web.app/.well-known/apple-app-site-association | jq
# Should show new Team ID: SF39D6367Y
```

### Check App Group in Code
```bash
grep -r "group\.com" --include="*.swift" --include="*.plist"
# All should reference: group.com.rationaledesign.heirloom
```

---

## Rollback Plan (If Needed)

If you need to revert:

1. **Git revert**:
   ```bash
   git revert 3fd4a5f
   ```

2. **Restore old GoogleService-Info.plist**

3. **Xcode**: Change back to old Team ID

4. **Apple Developer Portal**: Re-enable old bundle ID

---

## Status: 🟡 PARTIALLY COMPLETE

### ✅ Completed
- Code bundle ID references updated
- AASA file redeployed
- App group identifier updated
- Changes committed and pushed

### ⚠️ Required (In Xcode & Apple Developer)
- Update Xcode signing team
- Update app groups capability
- Update Sign in with Apple configuration
- Create new provisioning profiles
- Update Firebase Console iOS app

### 📝 Next Steps
1. Open Xcode
2. Follow "What You Need To Do in Xcode" section above
3. Follow "What You Need To Do in Firebase Console" section
4. Test authentication
5. Mark as ✅ COMPLETE when all tests pass

---

**Created**: 2026-01-30
**Last Updated**: 2026-01-30
**Author**: Claude Sonnet 4.5
