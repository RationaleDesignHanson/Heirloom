# Create Distribution Profile (App Store)

Fast track for App Store submission without physical device testing.

## Step 1: Create Certificate Signing Request (CSR)

### On Your Mac:
1. Open **Keychain Access** (Applications → Utilities → Keychain Access)
2. Menu: **Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority**
3. Fill in:
   - **User Email Address**: Your Apple ID email
   - **Common Name**: Your name (e.g., "Matt Hanson")
   - **CA Email Address**: Leave blank
   - **Request is**: Select **"Saved to disk"**
4. Click **Continue**
5. Save as: `HeirloomDistribution.certSigningRequest`
6. Save to Desktop (you'll upload this)
7. Click **Done**

## Step 2: Create Distribution Certificate

### In Apple Developer Portal:
1. Go to [Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Click **+** button
3. Under **Software**, select **Apple Distribution**
4. Click **Continue**
5. Click **Choose File**
6. Select the `HeirloomDistribution.certSigningRequest` file you just created
7. Click **Continue**
8. Click **Download**
9. The file will be named something like `distribution.cer`
10. **Double-click the downloaded file** to install it in Keychain

### Verify Installation:
1. Open **Keychain Access**
2. Select **My Certificates** (left sidebar)
3. You should see: **Apple Distribution: [Your Name] ([Team ID])**
4. Expand it (click triangle) - should show a private key underneath

## Step 3: Create Distribution Provisioning Profile

### In Apple Developer Portal:
1. Go to [Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Click **+** button
3. Under **Distribution**, select **App Store**
4. Click **Continue**
5. **App ID**: Select `com.matthanson.heirloom` (Heirloom)
6. Click **Continue**
7. **Select Certificate**: Check the box for your Apple Distribution certificate
8. Click **Continue**
9. **Provisioning Profile Name**: `Heirloom App Store Distribution`
10. Click **Generate**
11. Click **Download**
12. **Double-click the downloaded .mobileprovision file** to install in Xcode

## Step 4: Configure Xcode

### Open Your Project:
1. Open Xcode
2. Open `Heirloom.xcodeproj`
3. Select **Heirloom** project in the navigator (left sidebar)
4. Select **Heirloom** target (under TARGETS)
5. Click **Signing & Capabilities** tab

### For Release/Archive:
1. Make sure **All** or **Release** is selected at the top
2. **Automatically manage signing**: Can keep checked (Xcode will use the right profile)
3. **Team**: Should show your team (Q2HHH2GDN8)
4. Or uncheck automatic and manually select:
   - **Provisioning Profile**: "Heirloom App Store Distribution"

### Verify Capabilities:
Scroll down and verify these capabilities are present:
- ✅ **Signing & Capabilities tab should show:**
  - **iCloud**
    - Services: CloudKit
    - Containers: iCloud.com.matthanson.heirloom
  - **App Groups**
    - Container: group.com.matthanson.heirloom.shared

## Step 5: Test Archive

### Create Archive:
1. In Xcode, select **Any iOS Device (arm64)** from device dropdown
2. Menu: **Product → Archive**
3. Wait for build to complete
4. Xcode Organizer should open showing your archive

### Validate:
1. Select your archive
2. Click **Distribute App**
3. Select **App Store Connect**
4. Click **Next**
5. Select **Upload**
6. Click **Next**
7. Click **Automatically manage signing** (or select your profile)
8. Click **Next**
9. Click **Upload**

If validation succeeds, you're ready to submit to App Store! ✅

---

## Troubleshooting

### "No signing certificate found"
- Make sure you double-clicked the .cer file to install it
- Check Keychain Access → My Certificates
- Should see Apple Distribution certificate with private key

### "Profile doesn't include required entitlements"
- Go back to your App ID
- Verify iCloud and App Groups are enabled
- Re-generate the provisioning profile
- Download and re-install it

### "Invalid provisioning profile"
- Make sure you selected the correct App ID when creating profile
- Profile must be for "App Store" distribution, not Ad Hoc or Development
- Try regenerating the profile

---

## ✅ Success Criteria

You're ready for App Store when:
- [ ] Distribution certificate installed in Keychain
- [ ] Distribution provisioning profile installed
- [ ] Xcode shows no signing errors
- [ ] Archive builds successfully
- [ ] Validation passes in Organizer

**Next**: Prepare App Store metadata, screenshots, and submit for review!
