# Apple Developer Account Setup Guide

Complete guide for registering Heirloom with Apple Developer and enabling CloudKit + App Groups.

---

## Prerequisites

- **Apple Developer Account**: You need an active Apple Developer Program membership ($99/year)
- **Team ID**: Your team ID is `Q2HHH2GDN8` (found in your project settings)
- **Bundle ID**: `com.matthanson.heirloom`

---

## Step 1: Register App Identifier

### 1.1 Navigate to Identifiers
1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Sign in with your Apple ID
3. Click **Certificates, Identifiers & Profiles**
4. Select **Identifiers** from the left sidebar
5. Click the **+** button (top right)

### 1.2 Create New App ID
1. Select **App IDs** → Click **Continue**
2. Select **App** → Click **Continue**
3. Fill in the details:
   - **Description**: `Heirloom - Family Recipe Manager`
   - **Bundle ID**: Select **Explicit**
   - **Bundle ID**: Enter `com.matthanson.heirloom`

### 1.3 Enable Required Capabilities
Scroll down to **Capabilities** and check these boxes:

✅ **iCloud** (Required for CloudKit sync)
- Check "Include CloudKit support"

✅ **App Groups** (Required for data sharing)
- Check this capability

✅ **Push Notifications** (Optional but recommended)
- For recipe reminders and sharing notifications

### 1.4 Complete Registration
1. Click **Continue**
2. Review your settings
3. Click **Register**

**✓ Step 1 Complete** - Your app identifier is now registered!

---

## Step 2: Create CloudKit Container

### 2.1 Navigate to iCloud Containers
1. In **Certificates, Identifiers & Profiles**
2. Select **Identifiers** from the left sidebar
3. Click the **+** button
4. Select **iCloud Containers** → Click **Continue**

### 2.2 Configure Container
1. **Description**: `Heirloom CloudKit Container`
2. **Identifier**: `iCloud.com.matthanson.heirloom`
3. Click **Continue**
4. Click **Register**

### 2.3 Link Container to App ID
1. Go back to **Identifiers**
2. Select your app ID: `com.matthanson.heirloom`
3. Click **Edit**
4. Scroll to **iCloud**
5. Click **Configure** next to iCloud
6. Select your container: `iCloud.com.matthanson.heirloom`
7. Click **Save**
8. Click **Continue**
9. Click **Save** on the confirmation

**✓ Step 2 Complete** - CloudKit container is configured!

---

## Step 3: Create App Group

### 3.1 Navigate to App Groups
1. In **Certificates, Identifiers & Profiles**
2. Select **Identifiers** from the left sidebar
3. Click the **+** button
4. Select **App Groups** → Click **Continue**

### 3.2 Configure App Group
1. **Description**: `Heirloom Shared Data`
2. **Identifier**: `group.com.matthanson.heirloom.shared`
3. Click **Continue**
4. Click **Register**

### 3.3 Link App Group to App ID
1. Go back to **Identifiers**
2. Select your app ID: `com.matthanson.heirloom`
3. Click **Edit**
4. Scroll to **App Groups**
5. Click **Configure** (or **Edit**)
6. Check the box for: `group.com.matthanson.heirloom.shared`
7. Click **Continue**
8. Click **Save**

**✓ Step 3 Complete** - App Group is configured!

---

## Step 4: Generate Provisioning Profiles

You'll need TWO provisioning profiles: one for development and one for distribution.

### 4.1 Development Provisioning Profile

#### Create Development Certificate (if you don't have one)
1. Go to **Certificates** (left sidebar)
2. Click **+** button
3. Select **Apple Development** → Click **Continue**
4. Follow instructions to create Certificate Signing Request (CSR) from Keychain Access:
   - Open **Keychain Access** on Mac
   - Menu: **Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority**
   - Email: Your email address
   - Common Name: Your name
   - Request: **Saved to disk**
   - Click **Continue** and save the file
5. Upload the CSR file
6. Click **Continue** → Download the certificate
7. Double-click to install in Keychain

#### Create Development Profile
1. Go to **Profiles** (left sidebar)
2. Click **+** button
3. Select **iOS App Development** → Click **Continue**
4. **App ID**: Select `com.matthanson.heirloom`
5. Click **Continue**
6. **Select Certificate**: Check your development certificate
7. Click **Continue**
8. **Select Devices**: Check all devices you want to test on
   - If you haven't registered devices, go to **Devices** first and add them (UDID required)
9. Click **Continue**
10. **Profile Name**: `Heirloom Development`
11. Click **Generate**
12. Download the profile
13. Double-click to install in Xcode

### 4.2 Distribution Provisioning Profile (for App Store)

#### Create Distribution Certificate (if you don't have one)
1. Go to **Certificates** (left sidebar)
2. Click **+** button
3. Select **Apple Distribution** → Click **Continue**
4. Create and upload CSR (same process as development)
5. Download and install the certificate

#### Create Distribution Profile
1. Go to **Profiles** (left sidebar)
2. Click **+** button
3. Select **App Store** under Distribution → Click **Continue**
4. **App ID**: Select `com.matthanson.heirloom`
5. Click **Continue**
6. **Select Certificate**: Check your distribution certificate
7. Click **Continue**
8. **Profile Name**: `Heirloom App Store Distribution`
9. Click **Generate**
10. Download the profile
11. Double-click to install in Xcode

**✓ Step 4 Complete** - Provisioning profiles are ready!

---

## Step 5: Configure Xcode

### 5.1 Update Signing Settings
1. Open Xcode
2. Select the **Heirloom** project in the navigator
3. Select the **Heirloom** target
4. Go to **Signing & Capabilities** tab

#### For Development
1. Uncheck **Automatically manage signing** (if you want manual control)
2. **Team**: Select your team (Q2HHH2GDN8)
3. **Provisioning Profile**: Select "Heirloom Development"
4. Or keep **Automatically manage signing** checked and Xcode will handle it

#### Verify Capabilities
Ensure these are present:
- ✅ **iCloud** with CloudKit
  - Container: `iCloud.com.matthanson.heirloom`
- ✅ **App Groups**
  - Group: `group.com.matthanson.heirloom.shared`

### 5.2 Test on Physical Device
1. Connect your iPhone/iPad via USB
2. Select your device from the device dropdown (top toolbar)
3. Click **Run** (⌘R)
4. Xcode will sign the app with your development profile and install it

---

## Verification Checklist

Before submitting to App Store, verify:

- [ ] App ID registered: `com.matthanson.heirloom`
- [ ] CloudKit container created: `iCloud.com.matthanson.heirloom`
- [ ] App Group created: `group.com.matthanson.heirloom.shared`
- [ ] Development certificate installed in Keychain
- [ ] Distribution certificate installed in Keychain
- [ ] Development provisioning profile downloaded and installed
- [ ] Distribution provisioning profile downloaded and installed
- [ ] App builds and runs on physical device
- [ ] CloudKit sync works on physical device
- [ ] App Groups functionality tested

---

## Troubleshooting

### "Profile doesn't include entitlements"
- Go back to your App ID in the portal
- Click Edit → Verify iCloud and App Groups are enabled
- Re-generate your provisioning profiles
- Download and reinstall them

### "Profile doesn't match identifier"
- Make sure your Bundle ID in Xcode matches exactly: `com.matthanson.heirloom`
- Check that entitlements file has correct identifiers

### CloudKit not working on device
- Ensure you're signed into iCloud on the test device
- Check that the CloudKit container is properly linked to your App ID
- Verify the device has internet connectivity
- Check CloudKit dashboard for any errors: [CloudKit Console](https://icloud.developer.apple.com/dashboard)

### Device not showing up
- Register device UDID in **Devices** section
- Add device to your development provisioning profile
- Re-download and install the profile

---

## Next Steps

Once everything is working:

1. **Test thoroughly** on physical devices
2. **Prepare App Store metadata** (see `APP_STORE_LISTING.md`)
3. **Create screenshots** (see `DESIGN_ASSETS_COMPLETE.md`)
4. **Archive for distribution**:
   - Product → Archive in Xcode
   - Validate → Upload to App Store Connect
5. **Submit for review**

---

## Useful Links

- [Apple Developer Portal](https://developer.apple.com/account)
- [CloudKit Console](https://icloud.developer.apple.com/dashboard)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Xcode Help - Signing](https://help.apple.com/xcode/mac/current/#/dev60b6fbbc7)
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)

---

**Last Updated**: December 8, 2025
**Bundle ID**: `com.matthanson.heirloom`
**Team ID**: `Q2HHH2GDN8`
