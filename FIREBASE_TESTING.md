# Firebase Migration Testing & Validation Plan

**Version**: 1.0.0
**Date**: December 30, 2025
**Phase**: 8 - Testing & Validation

## Overview

This document outlines the testing and validation plan for the Firebase migration. All core services have been implemented in Phases 1-7. Phase 8 validates that everything works correctly before enabling the dual-write period.

## Testing Status Summary

| Service | Implementation | Build Status | Manual Test | Status |
|---------|----------------|--------------|-------------|--------|
| Firebase Auth | ✅ Complete | ✅ Passing | ⏳ Pending | Ready |
| Recipe CRUD | ✅ Complete | ✅ Passing | ⏳ Pending | Ready |
| Image Storage | ✅ Complete | ✅ Passing | ⏳ Pending | Ready |
| Sharing | ✅ Complete | ✅ Passing | ⏳ Pending | Ready |
| Data Migration | ✅ Complete | ✅ Passing | ⏳ Pending | Ready |
| Sync Service | ✅ Complete | ✅ Passing | ⏳ Pending | Ready |

## Testing Phases

### Phase 8.1: Pre-Deployment Testing ✅ COMPLETE

**Status**: All services implemented and building successfully

- ✅ Firebase SDK integration (Phase 1)
- ✅ FirebaseSyncService implementation (Phase 2)
- ✅ Firebase Authentication (Phase 3)
- ✅ Recipe CRUD operations (Phase 4)
- ✅ Firebase Storage (Phase 5)
- ✅ Sharing system (Phase 6)
- ✅ Data migration script (Phase 7)
- ✅ All builds succeeded with zero errors

### Phase 8.2: Manual Testing Procedures

#### 8.2.1 Backend Switching Test

**Objective**: Verify backend can be switched safely

**Prerequisites**:
- Clean build installed on device
- iCloud signed in (for CloudKit baseline)
- Test recipes in CloudKit

**Test Steps**:
1. Launch app (default: CloudKit backend)
2. Verify recipes load from CloudKit
3. In code, set `BackendConfig.shared.setBackend(.firebase)`
4. Sign in with Apple
5. Verify Firebase authentication succeeds
6. Create a test recipe
7. Verify recipe appears in Firebase Console
8. Restart app
9. Verify recipe loads from Firebase

**Expected Results**:
- ✅ CloudKit recipes visible before switch
- ✅ Sign in with Apple prompts on first Firebase use
- ✅ Firebase recipes visible after switch
- ✅ No data loss during switch

#### 8.2.2 Authentication Test

**Objective**: Verify Sign in with Apple works correctly

**Test Steps**:
1. Enable Firebase backend: `BackendConfig.shared.setBackend(.firebase)`
2. Launch app
3. Observe FirebaseSignInView appears
4. Tap "Sign in with Apple" button
5. Complete Apple authentication
6. Verify app loads main interface
7. Check Firebase Console > Authentication > Users
8. Force quit app
9. Relaunch app
10. Verify user remains authenticated (no sign-in prompt)

**Expected Results**:
- ✅ Sign-in prompt appears on first launch
- ✅ Apple authentication completes
- ✅ User created in Firebase Authentication
- ✅ User remains authenticated across app restarts
- ✅ User ID matches in Firestore paths

#### 8.2.3 Recipe CRUD Test

**Objective**: Verify recipes sync to Firebase correctly

**Test Steps**:
1. Ensure Firebase backend active and authenticated
2. Create new recipe "Test Recipe"
3. Add ingredients: "2 cups flour", "1 tsp salt"
4. Add instructions: "Mix ingredients", "Bake at 350°F"
5. Add photo from Photos library
6. Save recipe
7. Check Firebase Console:
   - Firestore > users/{userId}/recipes/{recipeId}
   - Storage > users/{userId}/recipes/{recipeId}/image.jpg
8. Edit recipe title to "Test Recipe - Updated"
9. Save changes
10. Verify Firestore document updated
11. Delete recipe
12. Verify Firestore document deleted
13. Verify Storage image deleted

**Expected Results**:
- ✅ Recipe document created in Firestore
- ✅ Ingredients in subcollection
- ✅ Image uploaded to Storage
- ✅ Updates sync to Firestore
- ✅ Deletion removes document and image

#### 8.2.4 Image Storage Test

**Objective**: Verify images upload and download correctly

**Test Steps**:
1. Create recipe with high-resolution image (5MB+)
2. Save recipe
3. Check Firebase Storage console
4. Verify image compressed to <1MB
5. Delete recipe from app
6. Create recipe without image
7. Edit recipe and add image
8. Verify image uploads successfully
9. Force quit app
10. Relaunch and open recipe
11. Verify image displays correctly

**Expected Results**:
- ✅ Large images compressed before upload
- ✅ Image file size ≤ 1MB in Storage
- ✅ Images can be added after creation
- ✅ Images cached locally for offline viewing
- ✅ Images deleted when recipe deleted

#### 8.2.5 Sharing Test

**Objective**: Verify recipe sharing works end-to-end

**Prerequisites**: Two test devices or accounts

**Test Steps (Device A - Sender)**:
1. Create recipe "Shared Test Recipe"
2. Call `FirebaseShareService.shared.createShare(for:options:context:)`
3. Copy share URL: `heirloom://share/{shareId}`
4. Check Firestore Console > shares/{shareId}
5. Verify share document created

**Test Steps (Device B - Receiver)**:
1. Call `FirebaseShareService.shared.acceptShare(shareId:context:)`
2. Verify recipe imported with ingredients
3. Check recipe provenance (generation incremented)
4. Verify recipe appears in recipe list
5. Open recipe and verify all data present

**Expected Results**:
- ✅ Share document created in Firestore
- ✅ Share URL generated
- ✅ Recipe downloaded with all child records
- ✅ Generation count incremented
- ✅ acceptedBy array updated
- ✅ Cannot accept own share

#### 8.2.6 Data Migration Test

**Objective**: Verify CloudKit data migrates to Firebase

**Prerequisites**:
- Test CloudKit data (create 5-10 recipes in CloudKit backend)
- Firebase backend enabled
- Authenticated to Firebase

**Test Steps**:
1. Check migration status:
   ```swift
   let status = try await DataMigrationService.shared.checkMigrationStatus(context: modelContext)
   print(status.summary)
   ```
2. Run dry run:
   ```swift
   try await DataMigrationService.shared.migrateAllData(context: modelContext, dryRun: true)
   ```
3. Verify count matches CloudKit recipes
4. Run actual migration:
   ```swift
   try await DataMigrationService.shared.migrateAllData(context: modelContext, dryRun: false)
   ```
5. Monitor progress via `@Published` properties
6. Check Firebase Console
7. Verify all recipes present in Firestore
8. Verify images uploaded to Storage
9. Open recipes in app
10. Verify all data intact (ingredients, images, etc.)

**Expected Results**:
- ✅ Status check shows CloudKit count
- ✅ Dry run reports correct count without migrating
- ✅ Migration completes without errors
- ✅ All recipes present in Firebase
- ✅ Child records (ingredients, comments) migrated
- ✅ Images uploaded to Storage
- ✅ Progress tracking works
- ✅ Failed recipes tracked separately

### Phase 8.3: Integration Testing

#### Recipe Lifecycle Test

**Objective**: Test complete recipe lifecycle

**Steps**:
1. Create recipe → Save → Verify Firestore
2. Add image → Verify Storage
3. Edit recipe → Verify Firestore updated
4. Share recipe → Verify share created
5. Accept share (different user) → Verify import
6. Delete original recipe → Verify cleanup

**Expected**: All operations complete without errors

#### Offline Behavior Test

**Objective**: Verify offline mode works

**Steps**:
1. Create recipe while online
2. Enable airplane mode
3. Create second recipe
4. Edit first recipe
5. Disable airplane mode
6. Verify Firestore syncs pending changes

**Expected**: Firestore persistent cache handles offline mode

#### Error Recovery Test

**Objective**: Verify error handling

**Steps**:
1. Create recipe with invalid data
2. Attempt to share while offline
3. Attempt to migrate with network error
4. Verify errors logged
5. Verify operations can retry

**Expected**: Graceful error handling, no data loss

### Phase 8.4: Performance Testing

#### Sync Performance

**Metrics to Monitor**:
- Recipe upload time (target: <2s)
- Image upload time (target: <5s for 1MB)
- Share creation time (target: <3s)
- Migration speed (target: >10 recipes/second)

#### Memory & Battery

**Observations**:
- Monitor memory usage during sync
- Monitor battery drain during migration
- Verify image compression reduces memory

### Phase 8.5: Security Validation

#### Firestore Security Rules Test

**Test Cases**:
1. ✅ User can read own recipes
2. ✅ User cannot read other users' recipes
3. ✅ Authenticated users required
4. ✅ Share documents accessible cross-user
5. ❌ Unauthenticated access denied

**Validation**:
```javascript
// Current rules (set in Phase 3)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Shares collection accessible to all authenticated users
    match /shares/{shareId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && resource.data.ownerId == request.auth.uid;
    }
  }
}
```

#### Storage Security Rules Test

**Test Cases**:
1. ✅ User can upload to own path
2. ✅ User can read own images
3. ❌ User cannot access other users' images
4. ❌ Unauthenticated access denied

**Validation**:
```javascript
// Storage rules (to be set)
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Validation Checklist

### ✅ Phase 1: Firebase Infrastructure
- [x] Firebase SDK installed
- [x] GoogleService-Info.plist added
- [x] Firebase initialized in HeirloomApp
- [x] BackendConfig feature flag system
- [x] Build succeeds

### ✅ Phase 2: FirebaseSyncService
- [x] Recipe upload/download
- [x] Ingredient sync (subcollection)
- [x] Comment sync (subcollection)
- [x] Card back sync (subcollection)
- [x] Conflict resolution
- [x] Offline support
- [x] Build succeeds

### ✅ Phase 3: Authentication
- [x] Sign in with Apple capability enabled
- [x] Firebase Auth provider configured
- [x] FirebaseAuthService implemented
- [x] FirebaseSignInView created
- [x] Auth gating in HeirloomApp
- [x] Firestore security rules set
- [x] Build succeeds

### ✅ Phase 4: Recipe CRUD
- [x] Recipe creation syncs to Firebase
- [x] Recipe updates sync to Firebase
- [x] Recipe deletion removes from Firebase
- [x] Conditional sync (BackendConfig)
- [x] Error handling (no local failures)
- [x] Build succeeds

### ✅ Phase 5: Image Storage
- [x] Image upload to Firebase Storage
- [x] Image download and caching
- [x] Image deletion on recipe delete
- [x] Compression (max 1MB)
- [x] firebaseImageURL field added
- [x] Build succeeds

### ✅ Phase 6: Sharing
- [x] Share creation with ShareOptions
- [x] Share acceptance flow
- [x] Hierarchical sharing (ingredients + images)
- [x] Expiration and permissions
- [x] Share tracking (views, accepts)
- [x] Deep link format defined
- [x] Build succeeds

### ✅ Phase 7: Data Migration
- [x] CloudKit record fetching
- [x] CKRecord → SwiftData conversion
- [x] Child record migration
- [x] Progress tracking
- [x] Dry run mode
- [x] Error handling
- [x] Build succeeds

### ⏳ Phase 8: Testing & Validation
- [ ] Manual testing completed
- [ ] Integration tests passed
- [ ] Security rules validated
- [ ] Performance acceptable
- [ ] Documentation complete

## Backend Switching Guide

### How to Enable Firebase Backend

**Option 1: Code Change (Development)**
```swift
// In HeirloomApp.swift or a test view
BackendConfig.shared.setBackend(.firebase)
```

**Option 2: Settings UI (Future - Phase 9)**
```
Settings > Advanced > Backend > Firebase
```

### Switching Modes

**CloudKit Only** (Current Default):
```swift
BackendConfig.shared.setBackend(.cloudKit)
```

**Firebase Only** (Testing):
```swift
BackendConfig.shared.setBackend(.firebase)
```

**Dual Write** (Phase 9):
```swift
BackendConfig.shared.setBackend(.dualWrite)
```

### Verification

Check current backend:
```swift
print("Active Backend: \(BackendConfig.shared.activeBackend.rawValue)")
print("Firebase Active: \(BackendConfig.shared.isFirebaseActive)")
```

## Rollback Procedures

### Immediate Rollback (If Critical Issue)

1. **Code Rollback**:
   ```bash
   git checkout pre-firebase-migration-20251230
   ```

2. **Backend Switch**:
   ```swift
   BackendConfig.shared.setBackend(.cloudKit)
   ```

3. **App Store Rollback**:
   - Submit previous build via App Store Connect
   - Expedite review if critical

### Partial Rollback (Switch Backend Only)

1. Switch to CloudKit:
   ```swift
   BackendConfig.shared.setBackend(.cloudKit)
   ```

2. Restart app

3. Verify CloudKit recipes load

4. No data lost (CloudKit data intact)

### Data Recovery

**If Firebase data needed**:
1. Export from Firebase Console
2. Use DataMigrationService in reverse (future enhancement)

**If CloudKit data needed**:
- CloudKit data never deleted
- Always available as backup

## Known Limitations

### Current Implementation
- ❌ UI integration for sharing deferred (manual testing via code)
- ❌ Deep link handler for share acceptance not integrated
- ❌ Migration UI not in Settings
- ❌ Dual-write mode not tested
- ❌ CloudKit → Firebase reverse migration not implemented

### Firebase Limitations
- Storage files max 5GB per file
- Firestore max 1MB per document
- Offline cache limited to device storage
- Security rules cannot query across users

### CloudKit Limitations (Why We're Migrating)
- ❌ Cannot query child records in shared database
- ❌ Hierarchical sharing broken
- ❌ More complex sharing model (CKShare)

## Success Criteria

Phase 8 is complete when:

✅ All manual tests pass
✅ Security rules validated
✅ Performance acceptable
✅ Documentation complete
✅ Rollback procedures documented
✅ Known limitations documented
✅ Ready for Phase 9 (Dual-Write Period)

## Next Steps (Phase 9)

1. Enable dual-write mode
2. Monitor for 2-4 weeks
3. Compare CloudKit vs Firebase data
4. Gradually migrate users
5. Monitor error rates
6. Validate data consistency

---

**Document Version**: 1.0.0
**Last Updated**: December 30, 2025
**Phase Status**: Testing & Validation In Progress
