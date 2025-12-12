# Create Development Profile (Physical Device Testing)

For testing Heirloom on your iPhone or iPad.

## Step 1: Register Your Device(s)

### Find Your Device UDID

#### Method A: Using Finder (macOS Catalina+)
1. Connect your iPhone/iPad to Mac via USB
2. Open **Finder**
3. Select your device in the sidebar
4. Click on the device info below the device name
5. Click multiple times to cycle through: Name → Model → Serial Number → **UDID**
6. Right-click the UDID → **Copy**

#### Method B: Using Xcode
1. Connect device via USB
2. Open **Xcode**
3. Menu: **Window → Devices and Simulators**
4. Select your device
5. **Identifier** field shows the UDID
6. Right-click → Copy

### Register in Portal:
1. Go to [Devices](https://developer.apple.com/account/resources/devices/list)
2. Click **+** button
3. **Platform**: iOS/iPadOS
4. **Device Name**: e.g., "Matt's iPhone 15 Pro"
5. **Device ID (UDID)**: Paste the UDID you copied
6. Click **Continue**
7. Click **Register**

Repeat for each device you want to test on.

## Step 2: Create Certificate Signing Request (CSR)

### On Your Mac:
1. Open **Keychain Access** (Applications → Utilities)
2. Menu: **Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority**
3. Fill in:
   - **User Email Address**: Your Apple ID email
   - **Common Name**: Your name
   - **CA Email Address**: Leave blank
   - **Request is**: Select **"Saved to disk"**
4. Click **Continue**
5. Save as: `HeirloomDevelopment.certSigningRequest`
6. Save to Desktop
7. Click **Done**

## Step 3: Create Development Certificate

### In Apple Developer Portal:
1. Go to [Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Click **+** button
3. Under **Software**, select **Apple Development**
4. Click **Continue**
5. Click **Choose File**
6. Select `HeirloomDevelopment.certSigningRequest`
7. Click **Continue**
8. Click **Download**
9. **Double-click the downloaded .cer file** to install in Keychain

### Verify:
1. Open **Keychain Access**
2. Select **My Certificates**
3. Should see: **Apple Development: [Your Name] ([Team ID])**
4. Should have a private key underneath

## Step 4: Create Development Provisioning Profile

### In Apple Developer Portal:
1. Go to [Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Click **+** button
3. Under **Development**, select **iOS App Development**
4. Click **Continue**
5. **App ID**: Select `com.matthanson.heirloom` (Heirloom)
6. Click **Continue**
7. **Select Certificate**: Check your Apple Development certificate
8. Click **Continue**
9. **Select Devices**: Check all devices you want to test on
10. Click **Continue**
11. **Provisioning Profile Name**: `Heirloom Development`
12. Click **Generate**
13. Click **Download**
14. **Double-click the .mobileprovision file** to install in Xcode

## Step 5: Configure Xcode for Development

### In Xcode:
1. Open `Heirloom.xcodeproj`
2. Select **Heirloom** project in navigator
3. Select **Heirloom** target
4. **Signing & Capabilities** tab
5. Make sure **Debug** is selected at the top

### Signing Settings:
**Option A - Automatic (Recommended):**
- ✅ Check **Automatically manage signing**
- **Team**: Select your team (Q2HHH2GDN8)
- Xcode will automatically select the right profile

**Option B - Manual:**
- ☐ Uncheck **Automatically manage signing**
- **Provisioning Profile**: Select "Heirloom Development"
- **Signing Certificate**: Apple Development

## Step 6: Test on Device

### Run on Device:
1. Connect your iPhone/iPad via USB
2. Trust the computer if prompted on device
3. In Xcode, select your device from the device dropdown (top toolbar)
4. Click **Run** button (⌘R) or Menu: **Product → Run**
5. First time: May see "Could not launch [app]" alert
6. On your device: **Settings → General → VPN & Device Management**
7. Under "Developer App", tap your Apple ID
8. Tap **Trust "[Your Name]"**
9. Tap **Trust** again
10. Go back to Xcode and click Run again

### Test CloudKit:
1. Make sure you're signed into iCloud on the device
2. Create a recipe in the app
3. Force quit the app
4. Open on another device (or reinstall) - recipe should sync

## Troubleshooting

### "Unable to install app"
- Device must be registered in Developer Portal
- Must be added to the Development Provisioning Profile
- Re-download and install profile after adding device

### "This app cannot be installed because its integrity could not be verified"
- Go to Settings → General → VPN & Device Management
- Trust the developer certificate

### "Code signing failed"
- Verify certificate is installed in Keychain
- Check that certificate has a private key
- Try automatic signing instead of manual

### CloudKit not working on device
- Sign into iCloud on device: Settings → [Your Name] → iCloud
- Turn on iCloud Drive
- Check internet connection
- Verify in CloudKit Console that container exists

### "Provisioning profile doesn't support iCloud"
- Your App ID must have iCloud enabled (Step 1)
- Regenerate the provisioning profile after enabling iCloud
- Download and reinstall the new profile

---

## ✅ Success Criteria

Development setup complete when:
- [ ] Device(s) registered in portal
- [ ] Development certificate installed
- [ ] Development profile installed
- [ ] App builds and runs on physical device
- [ ] Device shows trusted in Settings
- [ ] App launches successfully
- [ ] CloudKit syncing works

**Now you can develop and test Heirloom on real hardware!**
