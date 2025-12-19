# Setup Instructions: Default API Key

This guide explains how to configure the default Anthropic API key for Heirloom.

## Overview

Heirloom now supports a default API key that all users can use without needing to configure their own. Users can optionally add their personal API key for unlimited usage.

## Step 1: Add Your API Key to Config.xcconfig

1. Open `/Users/matthanson/Heirloom/Config.xcconfig` in a text editor
2. Replace `YOUR_ANTHROPIC_API_KEY_HERE` with your actual Anthropic API key
3. Save the file

Example:
```
DEFAULT_ANTHROPIC_KEY = sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Important:** This file is already gitignored and will never be committed to version control.

## Step 2: Link Config.xcconfig to Xcode Project

### Option A: Using Xcode GUI

1. Open `Heirloom.xcodeproj` in Xcode
2. Select the project (blue icon) in the Project Navigator
3. In the main editor, under **PROJECT** (not TARGETS), select "Heirloom"
4. Go to the **Info** tab
5. Under **Configurations**, expand both Debug and Release
6. For both Debug and Release:
   - Click on "Heirloom" (the project name column)
   - Select `Config` from the dropdown menu
   - If `Config` doesn't appear, click "+" and navigate to select `Config.xcconfig`

### Option B: Manual Project File Edit (Advanced)

If you're comfortable editing the project file directly:

1. Close Xcode
2. Open `Heirloom.xcodeproj/project.pbxproj` in a text editor
3. Find the `PBXProject` section
4. Add the xcconfig file reference:
   ```
   buildConfigurationList = <key> /* Build configuration list for PBXProject "Heirloom" */;
   ```
5. In the build configuration sections, add:
   ```
   baseConfigurationReference = <fileRef> /* Config.xcconfig */;
   ```

## Step 3: Add DEFAULT_ANTHROPIC_KEY to Info.plist

The key needs to be accessible from the app bundle:

1. Open `Heirloom.xcodeproj` in Xcode
2. Select the Heirloom target
3. Go to **Build Settings**
4. Click "+" and select "Add User-Defined Setting"
5. Name it: `DEFAULT_ANTHROPIC_KEY`
6. Set value to: `$(DEFAULT_ANTHROPIC_KEY)`

This will inherit the value from Config.xcconfig.

## Step 4: Update Info.plist (if needed)

If the key isn't accessible via `Bundle.main.object(forInfoDictionaryKey:)`, you may need to add it to Info.plist:

1. Open `Info.plist` in Xcode
2. Add a new row:
   - Key: `DEFAULT_ANTHROPIC_KEY`
   - Type: String
   - Value: `$(DEFAULT_ANTHROPIC_KEY)`

The `$(DEFAULT_ANTHROPIC_KEY)` will be replaced at build time with the value from Config.xcconfig.

## Step 5: Verify the Setup

1. Build the project (⌘B)
2. Run the app in the simulator or on a device
3. Go to Settings → AI Features
4. You should see:
   - API Key: "Shared Key" badge
   - Masked key displayed (sk-ant-****)
   - Daily Quota: X/100 recipes

## How It Works

### Default Key Flow
1. User opens app for the first time
2. AI features work immediately using the default key
3. Daily limit: 100 recipe imports per user
4. Counter resets at midnight (local time)

### Personal Key Override
1. User goes to Settings → AI Features
2. Taps "Add Your Own Key (Unlimited)"
3. Enters their personal Anthropic API key
4. Now has unlimited usage
5. Can remove personal key anytime to fall back to shared key

### Rate Limiting
- **Default key**: 100 requests/day per device
- **Personal key**: Unlimited (subject to Anthropic's limits)
- Soft limit: Shows friendly message when limit reached
- User can add personal key for unlimited usage

## Security Notes

- ✅ Config.xcconfig is gitignored and never committed
- ✅ Keys are stored in iOS Keychain (user keys)
- ✅ Default key is embedded in app bundle (read-only)
- ✅ Keys are never logged or displayed in full
- ✅ All API calls use HTTPS

## Troubleshooting

### "API Key not configured" error
- Check that Config.xcconfig has the correct key format (sk-ant-...)
- Verify the xcconfig is linked in Xcode project settings
- Rebuild the project (⌘⇧K to clean, then ⌘B to build)

### Rate limit always shows 100/100
- Check that `AIConfiguration.shared.incrementRequestCount()` is called after successful requests
- Verify daily reset logic in `AIConfiguration.init()`

### Key not accessible from code
- Ensure `DEFAULT_ANTHROPIC_KEY` is in Build Settings
- Check that Info.plist includes the key (if needed)
- Try accessing via `Bundle.main.infoDictionary?["DEFAULT_ANTHROPIC_KEY"]`

## Testing

Test the implementation:

1. **Default key works:**
   - Clean install (delete app)
   - Launch app
   - Import a recipe with AI parsing enabled
   - Should work without any setup

2. **Rate limiting:**
   - Make 100 AI requests
   - 101st request should fail with quota message
   - Check Settings shows 0/100 remaining

3. **Personal key override:**
   - Add personal API key in Settings
   - Badge changes to "Personal Key"
   - Quota no longer displayed
   - Unlimited usage

4. **Fallback to default:**
   - Remove personal key
   - Badge changes back to "Shared Key"
   - Quota reappears
   - Rate limiting active again

## Next Steps

After setup is complete:

1. Test thoroughly on simulator and device
2. Monitor analytics for `key_source` (default vs user)
3. Track quota exceeded events
4. Consider adding warning at 90% quota used
5. Add TestFlight notes about shared vs personal keys

---

**Created:** December 2024
**Status:** ✅ Implementation Complete
