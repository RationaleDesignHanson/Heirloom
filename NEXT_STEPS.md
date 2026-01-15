# Next Steps: Complete Heritage On-Demand Implementation

## Critical: Manual Steps Required

I've implemented the on-demand heritage unlock system, but there are a few manual steps you need to complete:

---

## Step 1: Add HeritageOnDemandService.swift to Xcode Project

The file exists but isn't in the Xcode project yet:

**File location**: `/Users/matthanson/Heirloom/Heirloom/Core/Services/Heritage/HeritageOnDemandService.swift`

**How to add**:
1. Open Heirloom.xcodeproj in Xcode
2. Right-click on `Core/Services/Heritage` folder in project navigator
3. Select "Add Files to 'Heirloom'..."
4. Navigate to the file and add it
5. Make sure "Add to targets: Heirloom" is checked

---

## Step 2: Upload Schedules and Recipes to Firebase

**Install Firebase Admin SDK** (if not installed):
```bash
pip3 install firebase-admin
```

**Get Firebase Service Account Key**:
1. Go to Firebase Console
2. Project Settings > Service Accounts
3. Click "Generate New Private Key"
4. Save as: `/Users/matthanson/Heirloom/backend/firebase-service-account.json`

**Run Upload Script**:
```bash
cd /Users/matthanson/Heirloom
python3 scripts/upload_to_firebase.py
```

This uploads:
- 100 unlock schedules (heritage_schedules collection)
- 100 recipes (heritage_recipes collection)

---

## Step 3: Deploy Firestore Rules

```bash
cd /Users/matthanson/Heirloom/backend
firebase deploy --only firestore:rules
```

This adds permissions for:
- `heritage_schedules` (read-only)
- `heritage_recipes` (read-only)

---

## Step 4: Remove Old Seeding Logic

Two files need manual editing:

### File 1: `Heirloom/App/HeirloomApp.swift`

**Find** the function `seedHeritageRecipesAfterAuth()` (around line 920)

**Replace entire function** with:

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

### File 2: `Heirloom/Features/Onboarding/OnboardingContainerView.swift`

**Find** the heritage recipe seeding section (around line 135-180)

**Replace** the entire `do { ... } catch` block that calls `seeder.seedHeritageRecipes()` with:

```swift
do {
    // Create heritage collections (but NO recipes)
    RecipeCollection.createHeritageCollections(context: modelContext)

    // Create blind boxes for onboarding
    let blindBoxSeeder = BlindBoxSeeder(modelContext: modelContext)
    if !blindBoxSeeder.isSeeded() {
        try blindBoxSeeder.seedBlindBoxes()
        Log.info("Heritage blind boxes created during onboarding", category: .storage)
        DeviceLogger.shared.log("✅ [Heritage] Blind boxes created during onboarding")
    }

    let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
    analytics.track(event: .heritageCollectionsCreated)
} catch {
    Log.error("Failed to setup heritage collections", category: .storage, metadata: ["error": error.localizedDescription])
    DeviceLogger.shared.log("❌ [Heritage] Failed to setup collections: \(error.localizedDescription)")
}
```

---

## Step 5: Build and Test

```bash
xcodebuild -scheme Heirloom -sdk iphonesimulator build
```

Should see: `** BUILD SUCCEEDED **`

---

## Step 6: Test with Fresh Account

**IMPORTANT**: Test with a NEW Firebase account (not your existing test account)

### Expected Behavior:

1. **Sign in** - Fast, no waiting
2. **Complete onboarding** - 2-3 seconds (NOT 30-45 seconds)
3. **Go to Collections tab** - See 2 blind boxes
4. **Tap blind box** - Both boxes reveal, download starts
5. **Wait 3-5 seconds** - 8 recipes download
6. **Verify**:
   - 2 collections visible (Literary Kitchen + one other)
   - 8 recipes total
   - 5 recipes in Literary Kitchen
   - 3 recipes in other collection
   - Recipes appear in Recipes tab
   - No locked/hidden recipes

7. **Sign in on second device** with same account
8. **Verify**:
   - Same 2 collections
   - Same 8 recipes
   - No duplicate downloads

---

## Troubleshooting

### Build fails with "cannot find 'HeritageOnDemandService'"
- Make sure you added the file to Xcode project (Step 1)

### Blind box tap does nothing
- Check logs for errors
- Verify Firebase rules deployed (Step 3)
- Verify schedules uploaded (Step 2)

### Wrong number of recipes
- Check Firebase heritageState: `users/{userId}/heritageState/current`
- Check downloaded recipe IDs
- Verify schedule assignment

### Recipes don't sync across devices
- Verify same user ID on both devices
- Check Firebase heritageState matches
- Check network connectivity

---

## What Changed

### Before
- Downloaded all 100 recipes on app launch (30-45 seconds)
- Stored as "locked" in local database
- Complex filtering to hide locked recipes
- Firebase state could desync

### After
- Download only 8 recipes on blind box reveal (3-5 seconds)
- Recipes don't exist until unlocked
- No filtering needed (if it exists, it's unlocked)
- Firebase state is source of truth

---

## Files Created/Modified

### Created:
- `Heirloom/Core/Services/Heritage/HeritageOnDemandService.swift`
- `scripts/generate_unlock_schedules.py`
- `scripts/upload_to_firebase.py`
- `scripts/heritage_unlock_schedules.json`
- `HERITAGE_ON_DEMAND_DESIGN.md`
- `IMPLEMENTATION_SUMMARY.md`
- `NEXT_STEPS.md` (this file)

### Modified:
- `backend/firestore.rules` - Added heritage_schedules and heritage_recipes rules
- `Heirloom/Features/Collections/CollectionsListView.swift` - Blind box reveal triggers downloads
- `Heirloom/Core/Services/HeritageRecipeSeeder.swift` - Added heritageRecipeId field
- `Heirloom/Core/Models/Recipe.swift` - Added heritageRecipeId field
- `Heirloom/Core/DI/ServiceRegistration.swift` - Registered new service
- (Need to modify): `Heirloom/App/HeirloomApp.swift` - Remove old seeding
- (Need to modify): `Heirloom/Features/Onboarding/OnboardingContainerView.swift` - Remove old seeding

---

## Questions?

Refer to:
- `HERITAGE_ON_DEMAND_DESIGN.md` for architecture details
- `IMPLEMENTATION_SUMMARY.md` for technical details
- Console logs for debugging

Good luck! 🚀
