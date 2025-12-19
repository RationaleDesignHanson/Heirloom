# Device B Setup Instructions

Complete guide for setting up a second iOS device for CloudKit sharing tests.

## Prerequisites

- 2 physical iOS devices (iPhone or iPad running iOS 18+)
- 2 different iCloud accounts
- Mac with Xcode installed
- Heirloom project building successfully

## Why 2 Physical Devices?

CloudKit sharing features don't work fully in the simulator. You need:
- Device A: Your primary development device (your iCloud account)
- Device B: Secondary test device (different iCloud account)

---

## Device B Setup Steps

### 1. Prepare iCloud Account

**Option A: Use existing account** (recommended)
- Use a family member or friend's iCloud account
- Ask them to share their device or credentials temporarily

**Option B: Create new Apple ID**
1. Go to https://appleid.apple.com/account
2. Click "Create Your Apple ID"
3. Use a different email address (can use `+` addressing: your+test@email.com)
4. Complete verification

### 2. Sign Into Device B

1. Go to **Settings** on Device B
2. Tap **Sign in to your iPhone/iPad** at the top
3. Enter the different iCloud credentials
4. Complete two-factor authentication if prompted
5. Choose **Merge** or **Don't Merge** for existing data (your choice)

### 3. Enable iCloud Drive

**Critical:** iCloud Drive must be enabled for CloudKit to work

1. Settings → [Your Name] → **iCloud**
2. Find **iCloud Drive** in the list
3. **Toggle ON** if it's off
4. Wait for "Syncing..." to complete

### 4. Install Heirloom on Device B

**Option A: TestFlight (Recommended)**
1. On your Mac, open Xcode
2. Select **Product** → **Archive**
3. Once archived, click **Distribute App**
4. Choose **TestFlight Internal Testing**
5. Follow prompts to upload to App Store Connect
6. On Device B:
   - Install TestFlight from App Store
   - Open invitation link or search for Heirloom
   - Install the build

**Option B: Direct Install (Development)**
1. Connect Device B to your Mac via USB
2. In Xcode, select Device B from the device menu (next to scheme selector)
3. Click **Run** (⌘R) or **Product** → **Run**
4. On Device B, trust the developer certificate:
   - Settings → General → VPN & Device Management
   - Tap your developer account
   - Tap **Trust**
5. App will install and launch

### 5. Verify CloudKit Access

On Device B, after installing Heirloom:

1. **Check account status**:
   - Open the app
   - Navigate to Settings (if available)
   - Look for CloudKit account status
   - Should show "Available" or "Signed In"

2. **Test basic functionality**:
   - Create a sample recipe
   - Wait 10 seconds
   - Check if recipe syncs (you may see it on Device A if private DB sync is working)

### 6. Test Sharing Flow

Now test the complete share flow:

**On Device A** (your primary device):
1. Open Heirloom
2. Select a recipe
3. Tap **Share** button
4. Choose share method (Messages, Email, AirDrop, or Copy Link)
5. Send share to Device B's account

**On Device B:**
1. Receive the share (via Messages, Email, or paste link)
2. Tap the share link
3. Should open Heirloom with share preview
4. Tap **Accept** or **Add to Collection**
5. Recipe should appear in Device B's recipe list

### 7. Verify Share Acceptance

**On Device A:**
- Check share status in Settings or Share History
- Should show "1 participant accepted"

**On Device B:**
- Check recipe details
- Should show "Shared by [Device A User]" attribution
- Provenance metadata should be linked

---

## Troubleshooting

### "Not Signed In to iCloud"
- Go to Settings → [Your Name]
- Sign out and sign back in
- Make sure iCloud Drive is ON

### "Share Link Doesn't Open App"
- Make sure app is installed on Device B
- Try copying link and pasting into Safari first
- Universal links may take a few seconds to work after install

### "Share Appears But Can't Accept"
- Check iCloud account status in Settings
- Verify you're using DIFFERENT iCloud accounts on each device
- Try signing out and back in on Device B

### "Recipe Not Syncing"
- Check Internet connection on both devices
- Wait 30 seconds (CloudKit has delays)
- Pull to refresh on recipe list
- Check CloudKit dashboard for errors

### Container ID Mismatch Error
- Verify both devices are using the same build
- Check entitlements file has correct container ID
- Rebuild and reinstall on Device B

---

## CloudKit Dashboard Verification

Check your CloudKit records online:

1. Go to https://icloud.developer.apple.com/dashboard
2. Sign in with your Apple Developer account
3. Select **Heirloom** app
4. Choose **Development** environment
5. Select **Data** → **Records**
6. You should see:
   - Recipe records from Device A
   - CKShare records when you create a share
   - Accept should create records visible to Device B

---

## Best Practices

### Keep Both Devices Nearby
- Makes testing faster
- Easier to debug issues
- Can compare screens side-by-side

### Use Different Networks
- Test offline scenarios
- Verify sync when coming online
- Simulate real-world conditions

### Document Test Results
- Keep a log of what works/fails
- Note error messages
- Take screenshots of issues

### Reset Test Data Periodically
- Delete test recipes
- Clear CloudKit cache
- Fresh start for each major test

---

## Quick Test Checklist

Use this checklist for each test session:

- [ ] Device A: iCloud signed in
- [ ] Device B: Different iCloud signed in
- [ ] Both devices: iCloud Drive enabled
- [ ] Both devices: Heirloom app installed
- [ ] Device A: Can create recipe
- [ ] Device A: Can create share
- [ ] Device B: Receives share link
- [ ] Device B: Can open share preview
- [ ] Device B: Can accept share
- [ ] Device A: Shows participant accepted
- [ ] Device B: Shows recipe with provenance
- [ ] CloudKit Dashboard: Shows records

---

## Support

If you encounter issues:

1. Check logs in Xcode Console
2. Look for CloudKit error messages
3. Verify container IDs match
4. Check entitlements configuration
5. Ensure both devices on iOS 18+

---

**Last Updated:** December 18, 2024
**Status:** Ready for Testing
**Next Step:** Complete Phase 2A testing checklist
