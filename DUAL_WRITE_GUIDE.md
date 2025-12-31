# Dual-Write Period Guide

**Version**: 1.0.0
**Date**: December 30, 2025
**Phase**: 9 - Dual-Write Period

## Overview

The dual-write period is a critical safety phase where the app writes data to both CloudKit and Firebase simultaneously while reading from CloudKit. This allows us to:

1. Validate Firebase implementation with real production data
2. Ensure zero data loss during migration
3. Monitor for any Firebase-specific issues
4. Maintain CloudKit as a fallback

## Duration

**Recommended**: 2-4 weeks minimum

**Factors affecting duration**:
- User base size
- Data complexity
- Error rates observed
- Confidence in Firebase stability

## How Dual-Write Works

### Current Implementation

The app already supports dual-write mode via `BackendConfig`:

```swift
BackendConfig.shared.setBackend(.dualWrite)
```

**Behavior in Dual-Write Mode**:
- ✅ Writes go to **both** CloudKit and Firebase
- ✅ Reads come from **CloudKit** (existing production data)
- ✅ Firebase sync failures don't break CloudKit operations
- ✅ CloudKit remains source of truth

### Code Flow

**Recipe Creation/Update** (RecipeEditorView.swift:346-358):
```swift
try modelContext.save() // Local save

// Sync to Firebase if active (includes dual-write)
if BackendConfig.shared.isFirebaseActive {
    try await FirebaseSyncService.shared.uploadRecipe(recipe)
}

// CloudKit sync happens automatically via CloudKitSyncService
// (if configured and active)
```

**Current Status**:
- ✅ Firebase sync: Conditional on `isFirebaseActive`
- ✅ Dual-write mode: Included in `isFirebaseActive`
- ⚠️ CloudKit sync: Needs verification

## Enabling Dual-Write Mode

### Step 1: Backend Switch

**Option A: Code Change (Recommended for initial testing)**
```swift
// In HeirloomApp.swift init or Settings
BackendConfig.shared.setBackend(.dualWrite)
```

**Option B: Settings UI (Phase 9 enhancement)**
```
Settings > Developer > Backend > Dual-Write
```

### Step 2: Verify Mode Active

```swift
print("Backend: \(BackendConfig.shared.activeBackend.rawValue)")
print("CloudKit Active: \(BackendConfig.shared.isCloudKitActive)") // Should be true
print("Firebase Active: \(BackendConfig.shared.isFirebaseActive)") // Should be true
print("Dual-Write: \(BackendConfig.shared.isDualWriteMode)") // Should be true
```

### Step 3: Run Data Migration

**Purpose**: Migrate existing CloudKit data to Firebase

```swift
let context = modelContext

// Check status
let status = try await DataMigrationService.shared.checkMigrationStatus(context: context)
print(status.summary)

// Run migration
try await DataMigrationService.shared.migrateAllData(context: context, dryRun: false)
```

**Expected Output**:
```
CloudKit: 150 recipes
Firebase: 0 recipes
Migration needed: Yes

📊 Found 150 recipes in CloudKit
✅ [1/150] Grandma's Cookies
✅ [2/150] Chocolate Cake
...
✅ Migration Complete!
   Total: 150 recipes
   Migrated: 148
   Failed: 2
   Time: 45.3s
```

### Step 4: Monitor

See "Monitoring" section below.

## Monitoring During Dual-Write

### Daily Checks

**1. Error Rates**
```
Firebase Console > Firestore > Usage
- Monitor write operations
- Check for errors
```

**2. Data Consistency**
```
Firebase Console > Firestore > Data
- Verify recipe count matches CloudKit
- Spot-check random recipes
```

**3. Storage Usage**
```
Firebase Console > Storage > Usage
- Monitor image uploads
- Check storage costs
```

**4. Authentication**
```
Firebase Console > Authentication > Users
- Verify user count growing
- Check for auth errors
```

### Weekly Analysis

**1. Recipe Count Comparison**
```swift
// CloudKit count
let cloudKitCount = try await countCloudKitRecipes()

// Firebase count
let firebaseCount = try await countFirebaseRecipes()

print("CloudKit: \(cloudKitCount), Firebase: \(firebaseCount)")
assert(firebaseCount >= cloudKitCount, "Firebase missing recipes!")
```

**2. Sample Recipe Comparison**
- Pick 10 random recipes
- Compare CloudKit vs Firebase data
- Verify ingredients, images, metadata match

**3. Error Log Review**
- Check DeviceLogger for Firebase errors
- Identify patterns
- Fix issues if needed

### Metrics to Track

| Metric | Target | Action if Missed |
|--------|--------|------------------|
| Firebase Sync Success Rate | >99% | Investigate errors |
| Recipe Count Parity | 100% | Re-run migration |
| Image Upload Success | >95% | Check compression |
| Auth Success Rate | >99.5% | Review auth flow |
| Firebase Write Latency | <2s | Optimize sync |

## Troubleshooting

### Issue: Firebase Sync Failing

**Symptoms**:
- Console logs: "⚠️ Failed to sync recipe to Firebase"
- Firestore count lower than CloudKit

**Diagnosis**:
```swift
// Check authentication
print("Authenticated: \(Auth.auth().currentUser != nil)")
print("User ID: \(Auth.auth().currentUser?.uid ?? "none")")

// Check network
print("Firebase reachable: \(/* check network */)")
```

**Solutions**:
1. Verify user authenticated to Firebase
2. Check network connectivity
3. Review Firestore security rules
4. Check Firebase quota limits
5. Re-run migration for failed recipes

### Issue: Duplicate Recipes in Firebase

**Symptoms**:
- Firebase count > CloudKit count
- Recipes appear multiple times

**Diagnosis**:
```swift
// Check for duplicate IDs
let snapshot = try await db.collection("users/\(userId)/recipes").getDocuments()
let ids = snapshot.documents.map { $0.documentID }
let uniqueIds = Set(ids)
print("Total: \(ids.count), Unique: \(uniqueIds.count)")
```

**Solutions**:
1. Migration ran multiple times
2. Deduplicate via script
3. Clear Firebase and re-migrate

### Issue: Images Missing in Firebase

**Symptoms**:
- Recipes in Firestore but no images in Storage
- Console logs: "⚠️ Image upload failed"

**Diagnosis**:
```swift
// Check Storage rules
// Check image file paths
// Verify firebaseImageURL field populated
```

**Solutions**:
1. Re-upload images: `FirebaseSyncService.shared.uploadImage(for: recipe)`
2. Check Storage security rules
3. Verify image compression working

### Issue: CloudKit Sync Not Working

**Symptoms**:
- CloudKit count not increasing
- CloudKit errors in logs

**Diagnosis**:
- Verify CloudKitSyncService configured
- Check iCloud account status
- Review CloudKit zone creation

**Solutions**:
1. Dual-write mode still works (Firebase receiving data)
2. CloudKit failures don't break Firebase
3. Users can continue using app

## Safety Mechanisms

### 1. Graceful Degradation

```swift
// Firebase failures don't break CloudKit operations
if BackendConfig.shared.isFirebaseActive {
    do {
        try await FirebaseSyncService.shared.uploadRecipe(recipe)
    } catch {
        print("⚠️ Firebase failed, but local save succeeded")
        // User not affected, CloudKit still works
    }
}
```

### 2. Data Recovery

**CloudKit remains source of truth**:
- All existing data in CloudKit
- Can read from CloudKit at any time
- Can disable Firebase and continue with CloudKit

**Firebase as backup**:
- All new data also in Firebase
- Can switch to Firebase-only when confident
- Can export Firebase data if needed

### 3. Instant Rollback

**If critical issue detected**:
```swift
// Disable Firebase immediately
BackendConfig.shared.setBackend(.cloudKit)

// OR rollback to previous version
git checkout pre-firebase-migration-20251230
```

## Data Validation

### Automated Validation Script

```swift
// Run weekly
func validateDataParity() async throws {
    let context = modelContext

    // 1. Count comparison
    let cloudKitCount = try await countCloudKitRecipes()
    let firebaseCount = try await countFirebaseRecipes()

    guard firebaseCount >= cloudKitCount else {
        throw ValidationError.missingRecipes(
            cloudKit: cloudKitCount,
            firebase: firebaseCount
        )
    }

    // 2. Sample recipes
    let cloudKitRecipes = try await fetchCloudKitRecipes(limit: 10)

    for cloudKitRecipe in cloudKitRecipes {
        let firebaseRecipe = try await fetchFirebaseRecipe(id: cloudKitRecipe.id)

        // Compare fields
        assert(firebaseRecipe.title == cloudKitRecipe.title)
        assert(firebaseRecipe.ingredients?.count == cloudKitRecipe.ingredients?.count)
        // ... more comparisons
    }

    print("✅ Validation passed: Data parity confirmed")
}
```

### Manual Validation Checklist

**Weekly:**
- [ ] Recipe counts match (Firebase ≥ CloudKit)
- [ ] Sample 10 recipes - data matches
- [ ] Images present in Firebase Storage
- [ ] No auth errors in Firebase Console
- [ ] Error rate <1%

**Before Switching to Firebase-Only:**
- [ ] 2-4 weeks of dual-write complete
- [ ] All validation checks passing
- [ ] Zero critical errors
- [ ] 100% user authentication working
- [ ] Performance acceptable
- [ ] Team confident in Firebase stability

## Switching to Firebase-Only

### Prerequisites

✅ Dual-write ran for 2-4+ weeks
✅ All validation checks passing
✅ Error rate <0.1%
✅ Data parity 100%
✅ Team confident
✅ Rollback plan ready

### Step 1: Final Validation

```swift
// Run complete validation
let status = try await DataMigrationService.shared.checkMigrationStatus(context: modelContext)
print(status.summary)

// Verify counts match
assert(status.firebaseRecipes >= status.cloudKitRecipes)
```

### Step 2: Switch Backend

```swift
BackendConfig.shared.setBackend(.firebase)
```

### Step 3: Monitor Closely

**First 24 hours**:
- Monitor Firebase Console continuously
- Check error logs frequently
- Verify users can read data
- Confirm writes working

**First Week**:
- Daily monitoring
- User feedback review
- Performance checks
- Be ready to rollback

### Step 4: Announce Success

After 1 week of Firebase-only with no issues:
- Migration successful!
- CloudKit deprecation can proceed (Phase 10)

## Timeline

**Week 0**: Enable dual-write mode
**Week 1**: Run data migration, monitor daily
**Week 2-4**: Continue monitoring, validate data
**Week 4+**: Switch to Firebase-only (if validation passes)
**Week 5**: CloudKit deprecation (Phase 10)

## Success Criteria

Dual-write period is successful when:

✅ Ran for minimum 2 weeks
✅ Firebase recipe count ≥ CloudKit count
✅ Error rate < 0.1%
✅ All manual validations passing
✅ Zero critical issues
✅ Performance acceptable
✅ Team confident to switch

## Next Steps (Phase 10)

After successful Firebase-only switch:

1. Remove CloudKit dependencies
2. Clean up CloudKitSyncService code
3. Remove backend switching UI
4. Remove dual-write logic
5. Simplify codebase to Firebase-only

---

**Document Version**: 1.0.0
**Last Updated**: December 30, 2025
**Status**: Ready for dual-write period
