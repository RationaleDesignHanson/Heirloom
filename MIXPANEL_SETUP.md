# Mixpanel Analytics Setup Guide

## Overview
Mixpanel analytics has been integrated into Heirloom to track user behavior and improve the product experience.

---

## Step 1: Add Mixpanel Package

### Using Swift Package Manager (Recommended)

1. **Open Xcode project**
2. **Go to:** File → Add Package Dependencies...
3. **Enter package URL:** `https://github.com/mixpanel/mixpanel-swift`
4. **Version:** Use "Up to Next Major Version" with 4.0.0 minimum
5. **Click "Add Package"**
6. **Select target:** Check "Heirloom"
7. **Click "Add Package"**

---

## Step 2: Get Your Mixpanel Token

1. **Sign up at:** https://mixpanel.com
2. **Create a new project** called "Heirloom"
3. **Get your project token:**
   - Navigate to Settings → Project Settings
   - Copy the "Project Token"
4. **Create two projects (recommended):**
   - `Heirloom Dev` (for development/testing)
   - `Heirloom Production` (for App Store releases)

---

## Step 3: Add Tokens to Code

### Update MixpanelService.swift

Open: `/Users/matthanson/Heirloom/Heirloom/Core/Services/Analytics/MixpanelService.swift`

Find this section (around line 54):
```swift
func initialize() {
    // Production token: Replace with your actual Mixpanel token
    let token = isProduction ? "YOUR_PRODUCTION_TOKEN" : "YOUR_DEV_TOKEN"
```

Replace with your actual tokens:
```swift
func initialize() {
    let token = isProduction ? "abc123prod" : "xyz789dev"
```

**Security Note:** For production apps, store tokens in:
- Xcode Configuration files (.xcconfig)
- Environment variables
- Never commit production tokens to git

---

## Events Being Tracked

### App Lifecycle
- ✅ `App Launched` - When app starts
- ✅ `App Backgrounded` - When app goes to background
- ✅ `App Foregrounded` - When app returns to foreground

### Recipe Actions
- ✅ `Recipe Viewed` - When user opens recipe detail
- ✅ `Recipe Created` - When user creates new recipe
- ✅ `Recipe Edited` - When user edits existing recipe
- ✅ `Recipe Deleted` - When user deletes recipe
- ✅ `Recipe Favorited` - When user favorites recipe
- ✅ `Recipe Unfavorited` - When user removes favorite

### Shopping List
- ✅ `Added to Shopping List` - Recipe ingredients added
- ✅ `Removed from Shopping List` - Recipe ingredients removed

### Search & Discovery
- ✅ `Search Performed` - User searches recipes
- ✅ `Filter Applied` - User applies filters

### Import & Export
- ✅ `Recipe Imported` - Recipe imported from URL
- ✅ `Recipe Exported` - Recipe exported/shared
- ✅ `Recipe Shared` - Recipe shared via system share

### Cooking
- ✅ `Cooking Started` - User begins cooking mode
- ✅ `Cooking Completed` - User finishes cooking

---

## Event Properties

Each event includes contextual properties:

### Recipe Viewed
```swift
{
  "Recipe ID": "uuid-string",
  "Recipe Title": "Grandma's Cookies",
  "Source Type": "url" | "manual" | "imported",
  "Has Image": true/false,
  "Times Cooked": 5,
  "Is Favorite": true/false
}
```

### Recipe Created
```swift
{
  "Recipe ID": "uuid-string",
  "Source Type": "url" | "manual" | "imported",
  "Has Image": true/false,
  "Ingredient Count": 12,
  "Instruction Count": 8,
  "Has Notes": true/false
}
```

### All Events Include
```swift
{
  "Environment": "Production" | "Development",
  "Timestamp": "2024-12-08T15:30:00Z",
  "Platform": "iOS",
  "App Version": "1.0.0",
  "Build Number": "1",
  "Device Model": "iPhone14,2",
  "iOS Version": "17.0"
}
```

---

## User Properties

User profiles are automatically updated with:
- **Platform:** iOS
- **App Version:** Current version
- **Build Number:** Current build
- **Device Model:** iPhone model identifier
- **iOS Version:** iOS version
- **Total Recipes:** Count of user's recipes
- **Favorite Recipes:** Count of favorited recipes
- **Last Active:** Timestamp of last activity

---

## Testing Analytics

### Debug Mode (Automatic)
When running in DEBUG mode, all analytics events are printed to console:
```
📊 Mixpanel initialized (Development)
📊 Analytics: Recipe Viewed
   Properties: ["Recipe Title": "Test Recipe", "Recipe ID": "abc-123"]
```

### Verify in Mixpanel Dashboard
1. Open Mixpanel dashboard
2. Navigate to "Events" → "Live View"
3. Perform actions in the app
4. Events should appear within seconds

---

## Privacy Considerations

### What We Track
- ✅ User actions (views, creates, edits, deletes)
- ✅ Feature usage patterns
- ✅ App performance metrics
- ✅ Anonymous device identifiers

### What We DON'T Track
- ❌ Personal information (names, emails, phone numbers)
- ❌ Recipe content in detail (only titles for context)
- ❌ IDFA or advertising identifiers
- ❌ Location data

### Device Identifier
We use a UUID stored in UserDefaults (not IDFA) for user consistency:
```swift
private func getDeviceIdentifier() -> String {
    if let uuid = UserDefaults.standard.string(forKey: "DeviceUUID") {
        return uuid
    }
    let uuid = UUID().uuidString
    UserDefaults.standard.set(uuid, forKey: "DeviceUUID")
    return uuid
}
```

---

## Usage in Code

### Track Simple Event
```swift
MixpanelService.shared.track(event: .appLaunched)
```

### Track Event with Properties
```swift
MixpanelService.shared.track(event: .searchPerformed, properties: [
    "Query": "chocolate chip cookies",
    "Result Count": 12
])
```

### Track Recipe-Specific Events
```swift
// Recipe viewed
MixpanelService.shared.trackRecipeViewed(recipe: recipe)

// Recipe favorited
MixpanelService.shared.trackRecipeFavorited(recipe: recipe, isFavorite: true)

// Shopping list toggle
MixpanelService.shared.trackShoppingListToggle(recipe: recipe, isInList: true)
```

### Update User Properties
```swift
MixpanelService.shared.updateUserProperties(
    totalRecipes: 25,
    favoriteRecipes: 8
)
```

---

## Files Modified

### New Files Created
- ✅ `Core/Services/Analytics/MixpanelService.swift` - Analytics service wrapper

### Files Updated with Analytics
- ✅ `App/HeirloomApp.swift` - Initialize Mixpanel on launch
- ✅ `Features/Recipes/RecipeDetail/RecipeDetailView.swift` - Track recipe actions

---

## Next Steps

1. **Add Mixpanel Package** via Swift Package Manager
2. **Get tokens** from Mixpanel dashboard
3. **Update tokens** in MixpanelService.swift
4. **Test in simulator** - watch console for analytics events
5. **Verify in Mixpanel** - check Live View in dashboard

---

## Common Issues

### Build Error: "Cannot find 'Mixpanel' in scope"
- **Solution:** Add the Mixpanel package via Xcode (Step 1 above)

### Events Not Appearing in Dashboard
- **Solution:** Check you're using the correct token for the environment
- **Solution:** Ensure internet connection is available
- **Solution:** Call `MixpanelService.shared.flush()` to force send events

### Debug Logs Not Showing
- **Solution:** Make sure you're running in DEBUG mode (simulator or debug build)
- **Solution:** Check console output for 📊 emoji

---

**Status:** ⏳ Ready to add package and tokens
**Next:** Add Mixpanel Swift package to complete integration
