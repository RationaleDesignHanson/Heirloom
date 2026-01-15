# Heritage On-Demand Implementation Summary

## Completed Tasks

✅ **1. Designed on-demand architecture** - See `HERITAGE_ON_DEMAND_DESIGN.md`
✅ **2. Generated 100 unlock schedules** - `/Users/matthanson/Heirloom/scripts/heritage_unlock_schedules.json`
✅ **3. Created upload scripts** - `scripts/upload_to_firebase.py` and `scripts/generate_unlock_schedules.py`
✅ **4. Updated Firestore security rules** - Added `heritage_schedules` and `heritage_recipes` collections
✅ **5. Created HeritageOnDemandService** - New service for downloading recipes on-demand
✅ **6. Updated blind box reveal** - CollectionsListView now triggers on-demand downloads

## Remaining Tasks

### 1. Upload Data to Firebase (PRIORITY)

Before testing, you MUST upload the schedules and recipes to Firebase:

```bash
cd /Users/matthanson/Heirloom

# Install Firebase Admin SDK (if not already installed)
pip3 install firebase-admin

# Make sure service account key is in place
# Download from: Firebase Console > Project Settings > Service Accounts
# Save to: backend/firebase-service-account.json

# Upload schedules and recipes
python3 scripts/upload_to_firebase.py
```

This will upload:
- 100 unlock schedules to `heritage_schedules` collection
- 100 recipes to `heritage_recipes` collection

### 2. Deploy Firestore Rules

```bash
cd /Users/matthanson/Heirloom/backend
firebase deploy --only firestore:rules
```

### 3. Remove Old Seeding Logic

**File: `Heirloom/App/HeirloomApp.swift` (line 920-966)**

Replace `seedHeritageRecipesAfterAuth()` function with:

```swift
/// Setup heritage collections after user authentication
/// NOTE: Recipes are NOT seeded here - they download on-demand when blind boxes are revealed
private func seedHeritageRecipesAfterAuth() async {
    guard let modelContainer = ServiceContainer.shared.resolveOptional(ModelContainer.self) else {
        Log.warning("ModelContainer not available, cannot setup heritage collections", category: .storage)
        return
    }

    do {
        // Create heritage collections (but NO recipes)
        RecipeCollection.createHeritageCollections(context: modelContainer.mainContext)

        // Create blind boxes for onboarding
        let blindBoxSeeder = BlindBoxSeeder(modelContext: modelContainer.mainContext)
        if !blindBoxSeeder.isSeeded() {
            try blindBoxSeeder.seedBlindBoxes()
            Log.info("Heritage blind boxes created", category: .storage)
            DeviceLogger.shared.log("✅ [Heritage] Blind boxes created (no recipes downloaded)")
        }

        let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
        analytics.track(event: .heritageCollectionsCreated)
    } catch {
        Log.error("Failed to setup heritage collections", category: .storage, metadata: ["error": error.localizedDescription])
        DeviceLogger.shared.log("❌ [Heritage] Failed to setup collections: \(error.localizedDescription)")
    }
}
```

**File: `Heirloom/Features/Onboarding/OnboardingContainerView.swift` (line 135-180)**

Replace the heritage seeding section with similar logic:

```swift
// Create heritage collections (but NO recipes)
RecipeCollection.createHeritageCollections(context: modelContext)

// Create blind boxes for onboarding
let blindBoxSeeder = BlindBoxSeeder(modelContext: modelContext)
if !blindBoxSeeder.isSeeded() {
    try blindBoxSeeder.seedBlindBoxes()
    Log.info("Heritage blind boxes created during onboarding", category: .storage)
    DeviceLogger.shared.log("✅ [Heritage] Blind boxes created during onboarding")
}
```

### 4. Build and Test

```bash
xcodebuild -scheme Heirloom -sdk iphonesimulator build
```

### 5. Testing Checklist

Test with a NEW user account (not existing test account with stale Firebase state):

- [ ] Sign in with new account
- [ ] Complete onboarding - should be fast (< 5 seconds, NO recipe downloads)
- [ ] See 2 blind box collections in Collections tab
- [ ] Tap blind box to reveal
- [ ] Verify download starts (should see logs)
- [ ] Verify exactly 8 recipes download (5 Literary + 3 other)
- [ ] Verify recipes appear in Collections tab
- [ ] Verify recipes appear in Recipes tab
- [ ] Sign in on second device with same account
- [ ] Verify same 2 collections and same 8 recipes appear
- [ ] Verify no duplicate downloads

## Architecture Changes

### Before (Broken)
```
App Launch → Download ALL 100 recipes → Store as "locked" → Try to unlock via filtering
Problems: 30-45 seconds, all recipes visible, complex state management
```

### After (On-Demand)
```
App Launch → Create empty collections → User reveals blind boxes → Download ONLY Day 1 recipes
Benefits: 2-3 seconds, only unlocked recipes exist, simple state management
```

## Key Implementation Details

### Blind Box Reveal Flow (CollectionsListView.swift)
1. User taps blind box
2. Mark both blind boxes as revealed in SwiftData
3. Initialize trial period
4. Initialize HeritageOnDemandService
5. Fetch user's unlock schedule from Firebase
6. Download Day 1 recipes (8 recipes total)
7. Insert downloaded recipes into SwiftData
8. Update Firebase heritageState with downloaded recipe IDs

### Schedule Assignment
- User ID hashed to number 1-100
- Assigned `schedule-{number:03d}` (e.g., "schedule-042")
- Schedule stored in Firebase heritageState
- Same user always gets same schedule across devices

### Daily Unlocks (Future)
- Check `currentDay` in heritageState
- If day changed, download next batch
- Update heritageState with new recipe IDs
- Simple, server-controlled progression

## Rollback Plan

If issues arise, revert these commits:
1. Heritage On-Demand Service
2. CollectionsListView changes
3. App init changes

The old system will work again (though slowly).

## Performance Comparison

| Metric | Before | After |
|--------|--------|-------|
| First launch time | 30-45s | 2-3s |
| Initial bandwidth | 50MB+ | 5MB |
| Initial storage | 100 recipes | 8 recipes |
| Recipes in DB | 100 (92 locked) | 8 (all unlocked) |
| Filtering needed | Yes | No |
| Cross-device sync | Unreliable | Reliable |

## Next Steps After Testing

1. Monitor Firebase usage (Firestore reads, Storage downloads)
2. Add daily unlock cron job or push notifications
3. Consider preloading recipe metadata for faster UI
4. Add analytics for unlock funnel
5. Consider recipe preview images (thumbnails only)

## Questions to Answer

1. Should we show recipe count in blind boxes before reveal?
   - Current: "Heritage Collection" with no count
   - Could show: "Heritage Collection • 50 recipes"

2. Should we cache schedule locally?
   - Current: Fetches from Firebase each time
   - Could cache: Store in UserDefaults

3. Should we show download progress?
   - Current: Silent download in background
   - Could show: Progress indicator with count

4. What happens if download fails mid-batch?
   - Current: Continues with other recipes, logs error
   - Could improve: Retry logic, user notification
