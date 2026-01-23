# Mixpanel Analytics Setup

**Date**: 2026-01-23
**Status**: ⚠️ **NEEDS TOKEN CONFIGURATION**

---

## Current Status

### ✅ What's Already Done
- [x] Mixpanel SDK integrated (via SPM or CocoaPods)
- [x] MixpanelService.swift implemented with comprehensive event tracking
- [x] Analytics events defined (135+ event types)
- [x] Service registered in DI container
- [x] Console fallback for testing without token

### ⚠️ What's Missing
- [ ] Production Mixpanel token
- [ ] Development Mixpanel token (optional)
- [ ] Token configuration in Config.xcconfig
- [ ] Code update to read from Config.xcconfig

---

## Step 1: Get Mixpanel Tokens

### Create Mixpanel Projects

1. **Go to Mixpanel**: https://mixpanel.com
2. **Sign up or log in**
3. **Create TWO projects** (recommended):
   - **Heirloom Production** - for App Store releases
   - **Heirloom Development** - for testing (optional)

4. **Get Project Tokens**:
   - Click on project name
   - Go to "Project Settings"
   - Copy "Project Token" (looks like: `1234567890abcdef1234567890abcdef`)

---

## Step 2: Add Tokens to Config.xcconfig

**File**: `/Users/matthanson/Heirloom/Config.xcconfig`

Add these lines:

```
// Mixpanel Analytics Configuration
// Get tokens from: https://mixpanel.com/settings/project
MIXPANEL_PRODUCTION_TOKEN = YOUR_PRODUCTION_TOKEN_HERE
MIXPANEL_DEVELOPMENT_TOKEN = YOUR_DEV_TOKEN_HERE
```

**Example**:
```
MIXPANEL_PRODUCTION_TOKEN = 1234567890abcdef1234567890abcdef
MIXPANEL_DEVELOPMENT_TOKEN = fedcba0987654321fedcba0987654321
```

**Important**:
- ✅ Config.xcconfig is already in .gitignore (safe from commits)
- ⚠️ DO NOT commit tokens to git
- ✅ Tokens are safe to use (they're project identifiers, not API keys)

---

## Step 3: Update MixpanelService.swift

**Current Code** (Line 23):
```swift
let token = isProduction ? "YOUR_PRODUCTION_TOKEN" : "YOUR_DEV_TOKEN"
```

**Updated Code**:
```swift
// Read tokens from Info.plist (populated from Config.xcconfig)
let token: String
if isProduction {
    token = Bundle.main.object(forInfoDictionaryKey: "MIXPANEL_PRODUCTION_TOKEN") as? String ?? ""
} else {
    token = Bundle.main.object(forInfoDictionaryKey: "MIXPANEL_DEVELOPMENT_TOKEN") as? String ?? ""
}

// Fallback to console analytics if token not configured
guard !token.isEmpty else {
    Log.warning("Mixpanel token not configured, falling back to console analytics", category: .general)
    return
}
```

---

## Step 4: Add Tokens to Info.plist

Xcode needs to know about these keys to populate them from Config.xcconfig.

### Option A: Xcode UI (Recommended)

1. Open `Heirloom.xcodeproj` in Xcode
2. Select **Heirloom target** → **Build Settings**
3. Search for "Info.plist"
4. Find "Info.plist Values" section
5. Add two custom keys:
   - Key: `MIXPANEL_PRODUCTION_TOKEN`, Value: `$(MIXPANEL_PRODUCTION_TOKEN)`
   - Key: `MIXPANEL_DEVELOPMENT_TOKEN`, Value: `$(MIXPANEL_DEVELOPMENT_TOKEN)`

### Option B: Edit Info.plist Directly

Add to `Heirloom/Info.plist`:

```xml
<key>MIXPANEL_PRODUCTION_TOKEN</key>
<string>$(MIXPANEL_PRODUCTION_TOKEN)</string>
<key>MIXPANEL_DEVELOPMENT_TOKEN</key>
<string>$(MIXPANEL_DEVELOPMENT_TOKEN)</string>
```

---

## Step 5: Verify Configuration

### Test in Debug Build

1. **Add debug logging** to MixpanelService initialize():
   ```swift
   print("🔍 Mixpanel token: \(token.prefix(8))...")  // First 8 chars only
   ```

2. **Run app in simulator**
3. **Check console output**:
   - Should NOT see "YOUR_PRODUCTION_TOKEN"
   - Should see actual token prefix
   - Should see "Mixpanel analytics initialized"

### Test Event Tracking

1. **Create a recipe** in the app
2. **Go to Mixpanel dashboard**: https://mixpanel.com
3. **Navigate to**: Events → Live View
4. **Verify**: Should see "Recipe Created" event appear within 30 seconds

---

## 📊 Mixpanel Dashboard Setup

### Create Key Reports

#### 1. Retention Cohort
- **Go to**: Reports → Retention
- **Event**: "App Launched"
- **Return Event**: "App Launched"
- **Date Range**: Last 30 days
- **Cohort by**: Daily
- **Save as**: "Daily Retention (D1, D7, D30)"

#### 2. Onboarding Funnel
- **Go to**: Reports → Funnels
- **Steps**:
  1. App Launched
  2. Recipe Created (or Recipe Imported)
  3. Recipe Viewed
  4. Purchase Success
- **Save as**: "Onboarding → Premium Conversion"

#### 3. Feature Usage
- **Go to**: Reports → Insights
- **Event**: Any (segment by event name)
- **Breakdown**: Event Name
- **Date Range**: Last 7 days
- **Chart Type**: Bar chart
- **Save as**: "Top Features (7 days)"

#### 4. Recipe Sources
- **Go to**: Reports → Insights
- **Event**: Recipe Created
- **Breakdown**: Source Type
- **Chart Type**: Pie chart
- **Save as**: "Recipe Import Sources"

---

## 🎯 Key Metrics to Track

### User Engagement
- **DAU** (Daily Active Users): Users who launch app daily
- **MAU** (Monthly Active Users): Users who launch app monthly
- **DAU/MAU Ratio**: Engagement quality (> 20% is good)

### Retention
- **D1 Retention**: % of users who return next day (target: > 40%)
- **D7 Retention**: % of users who return after 7 days (target: > 20%)
- **D30 Retention**: % of users who return after 30 days (target: > 10%)

### Conversion
- **Trial → Premium**: % of trial users who convert (target: > 5%)
- **Recipe Created → Premium**: Users who create recipe then convert
- **Time to Conversion**: Days from install to purchase

### Feature Adoption
- **% Using Import**: Users who import (not just manual create)
- **% Using Share**: Users who share recipes
- **% Using Shopping**: Users who add to shopping list
- **% Using Video Import**: Users who import from video

---

## 🔍 Events Currently Tracked

The app already tracks **135+ event types** including:

### App Lifecycle
- App Launched, App Backgrounded, App Foregrounded

### Recipe Actions
- Recipe Viewed, Created, Edited, Deleted, Favorited
- Recipe Imported, Scanned, Shared, Exported

### Import Sources
- PDF Import (started, completed, failed)
- Video Import (with phase tracking)
- URL Import
- Image OCR Import

### Shopping & Cooking
- Added to Shopping List, Removed from Shopping List
- Cooking Started, Completed
- Timer Started, Completed

### Collections
- Collection Viewed, Created, Edited, Deleted
- Recipes Added to Collection

### Store & Subscriptions
- Purchase Started, Success, Failed, Cancelled
- Paywall Shown, Dismissed
- Trial Started, Adjusted
- Subscription Status Changed

### AI Usage
- AI Tokens Used
- AI Ingredient Parse (success/failure)
- AI Spell Check, Category Detection, Enhancement

See `AnalyticsService.swift` (lines 19-135) for full list.

---

## 🚨 Privacy & Compliance

### What We Track
- ✅ Usage data (events, features used)
- ✅ Device info (model, iOS version, app version)
- ✅ Performance data (crashes, errors)
- ✅ Anonymous device identifier (not IDFA)

### What We DON'T Track
- ❌ Personal information (name, email) - unless user opts in
- ❌ Recipe content (ingredient details, instructions)
- ❌ User-generated content
- ❌ Advertising identifiers (IDFA) - unless ATT authorized

### GDPR Compliance
- ✅ Anonymous by default
- ✅ Can delete user data via Mixpanel API
- ✅ Users can opt-out (would need to add setting)

### App Store Privacy
When submitting to App Store, declare:
- **Data Type**: Usage Data
- **Purpose**: Analytics
- **Linked to User**: No (if using anonymous identifier)
- **Used for Tracking**: No (not used for advertising)

---

## 🧪 Testing Checklist

### Before Production
- [ ] Production token added to Config.xcconfig
- [ ] Code updated to read from config
- [ ] Build and run in simulator
- [ ] Create a test recipe
- [ ] Verify event appears in Mixpanel dashboard
- [ ] Check all 6 key events fire:
  - [ ] App Launched
  - [ ] Recipe Created
  - [ ] Recipe Viewed
  - [ ] Added to Shopping List
  - [ ] Recipe Shared
  - [ ] Purchase Started (test sandbox)

### TestFlight
- [ ] Build with production token
- [ ] Upload to TestFlight
- [ ] Install on device
- [ ] Use app normally for 5 minutes
- [ ] Check Mixpanel dashboard for events from TestFlight build

---

## 🔧 Troubleshooting

### "No events appearing in dashboard"

**Check**:
1. ✅ Token is correct (check for typos)
2. ✅ Token is not empty string
3. ✅ App has internet connection
4. ✅ Events are being tracked (check console logs)
5. ✅ Wait 5 minutes (events batch upload)

**Debug**:
```swift
// Add to HeirloomApp.swift after analytics.initialize()
Task { @MainActor in
    let analytics = serviceContainer.resolve(AnalyticsService.self)
    analytics.track(event: .appLaunched)
    print("🔍 Mixpanel event sent: App Launched")
}
```

### "Wrong token being used"

**Check**:
1. ✅ Build configuration (Debug vs Release)
2. ✅ `isProduction` flag in MixpanelService
3. ✅ Config.xcconfig tokens are correct
4. ✅ Info.plist has keys defined

### "Events tracked but no user properties"

**Fix**: Call `updateUserProperties` after user data changes:
```swift
let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
analytics.updateUserProperties(
    totalRecipes: recipeCount,
    favoriteRecipes: favoriteCount
)
```

---

## 📋 Completion Checklist

### Configuration
- [ ] Get Mixpanel production token
- [ ] Get Mixpanel development token (optional)
- [ ] Add tokens to Config.xcconfig
- [ ] Update MixpanelService.swift to read from config
- [ ] Add keys to Info.plist
- [ ] Verify tokens not committed to git

### Testing
- [ ] Test in Debug build (simulator)
- [ ] Test in Release build (device)
- [ ] Verify events in Mixpanel dashboard
- [ ] Test all critical events fire

### Dashboard Setup
- [ ] Create retention cohort report
- [ ] Create onboarding funnel
- [ ] Create feature usage report
- [ ] Set up email alerts for key metrics

### Documentation
- [ ] Update PRE_LAUNCH_CHECKLIST.md with Mixpanel status
- [ ] Document baseline metrics
- [ ] Add Mixpanel to monitoring runbook

---

## 🎯 Success Criteria

**Mixpanel is properly configured when**:
- ✅ Events appear in dashboard within 5 minutes
- ✅ User properties are set correctly
- ✅ Retention cohort shows data
- ✅ Funnel tracks conversions
- ✅ No console errors about missing token

---

**Last Updated**: 2026-01-23
**Status**: Code ready, tokens needed
**Next Step**: Get tokens from mixpanel.com and add to Config.xcconfig
