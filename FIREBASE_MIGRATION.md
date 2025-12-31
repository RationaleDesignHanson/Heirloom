# Firebase Migration Documentation

## Overview
Migrating Heirloom from CloudKit to Firebase Firestore to resolve hierarchical sharing limitations discovered in Build 20.

**Start Date**: December 30, 2025
**Current Phase**: Phase 3 (Authentication Integration)
**Status**: Phase 3 Complete - Ready for Phase 4

## Why Firebase?
After 4 days debugging CloudKit sharing issues, discovered architectural limitation: "You cannot query all child records using the parent property" in shared database. Participants cannot query child records (ingredients) when accepting recipe shares.

### CloudKit vs Firebase Decision
- **Firebase chosen** for simpler hierarchical data model, better iOS SDK, offline support
- **Supabase alternative** considered but Firebase better for hierarchical recipe data
- **Migration strategy**: Zero data loss via dual-write period

## Progress Tracking

Use the migration tracker script:
```bash
# Show current status
./scripts/migration-tracker.sh status

# Start a phase
./scripts/migration-tracker.sh start <phase>

# Complete a step
./scripts/migration-tracker.sh step <phase> <step-index>

# Add notes
./scripts/migration-tracker.sh note <phase> "your note"

# Add log entry
./scripts/migration-tracker.sh log "your message"
```

## Phase 0: Pre-Migration Backup ✅ COMPLETED

### Completed Steps
- ✅ Full project backup: `/Users/matthanson/Heirloom_Backups/20251230_185856_pre_firebase_migration/`
- ✅ 15,452 files (302MB) backed up
- ✅ Git rollback tag: `pre-firebase-migration-20251230`
- ✅ Feature branch: `feature/firebase-migration`
- ✅ Progress tracking system initialized

### Rollback Instructions
```bash
git checkout pre-firebase-migration-20251230
```

### Pending
- ⏳ Manual CloudKit data export (optional backup)

## Phase 1: Firebase Infrastructure Setup ✅ COMPLETED

### Completed Steps
- ✅ Firebase project created: `heirloom-ios-prod`
- ✅ iOS app registered in Firebase Console
- ✅ Bundle ID: `com.matthanson.heirloom`
- ✅ `GoogleService-Info.plist` downloaded and added to Xcode
- ✅ Firebase SDK installed via SPM (v12.7.0)
  - FirebaseCore
  - FirebaseAuth
  - FirebaseFirestore
  - FirebaseStorage
- ✅ `BackendConfig.swift` created for feature flag system
- ✅ Firebase initialized in `HeirloomApp.swift`

### Changes Made

#### Files Created
- `Heirloom/Core/Config/BackendConfig.swift` - Backend switching system
- `Heirloom/Resources/GoogleService-Info.plist` - Firebase configuration
- `.migration-progress.json` - Progress tracking
- `scripts/migration-tracker.sh` - Progress management script
- `.migration-log.txt` - Timestamped migration log

#### Files Modified
- `Heirloom/App/HeirloomApp.swift`:
  - Added `import FirebaseCore`
  - Added Firebase initialization: `FirebaseApp.configure()`
  - Added backend logging

### Current Backend Status
- **Active Backend**: CloudKit (default)
- **Firebase Status**: Initialized but not used for data ops yet
- **Next**: Implement FirebaseSyncService in Phase 2

### Testing
✅ Build succeeded - Firebase initializes without errors

## Phase 2: FirebaseSyncService Implementation ✅ COMPLETED

Completed: ~8 hours

### Completed Implementation
- ✅ Created `FirebaseSyncService.swift` with full API parity to CloudKitSyncService
- ✅ Implemented Recipe CRUD operations (upload/download)
- ✅ Implemented Ingredient sync (subcollection)
- ✅ Implemented Comment sync (subcollection)
- ✅ Implemented Card Back sync (subcollection)
- ✅ Conflict resolution (last-write-wins based on modifiedAt)
- ✅ Automatic periodic sync (every 5 minutes + foreground)
- ✅ Offline support with Firestore persistent cache
- ✅ Build succeeded with zero warnings

### Firestore Structure Implemented
```
users/{userId}/recipes/{recipeId}
  - metadata fields (title, instructions, timestamps, etc.)
  - subcollection: ingredients/{ingredientId}
  - subcollection: comments/{commentId}
  - subcollection: cardBack/metadata
```

### Files Created
- `Heirloom/Core/Services/Firebase/FirebaseSyncService.swift` - Complete sync service
- `FIRESTORE_SCHEMA.md` - Detailed schema documentation with examples

### Key Features
- User-scoped data (users/{userId}/recipes)
- Subcollections for child records (no CloudKit CKReference issues!)
- Batch operations for efficiency
- Error handling with detailed logging
- ObservableObject with @Published state (isSyncing, lastSyncDate, syncError)

## Phase 3: Authentication Integration ✅ COMPLETED

Completed: ~4 hours

### Completed Implementation
- ✅ Enabled Sign in with Apple capability in Xcode
- ✅ Configured Sign in with Apple in Apple Developer Portal
  - Created Sign in with Apple Key (.p8)
  - Created Services ID: `com.matthanson.heirloom.firebaseauth`
  - Configured Firebase callback URLs
- ✅ Set up Firebase Auth with Apple provider in Firebase Console
- ✅ Created `FirebaseAuthService.swift` with Sign in with Apple integration
- ✅ Created `FirebaseSignInView.swift` for authentication UI
- ✅ Integrated auth gating with app startup (RootView)
- ✅ Set up Firestore security rules (user-scoped access)
- ✅ Build succeeded with zero errors

### Files Created
- `Heirloom/Core/Services/Firebase/FirebaseAuthService.swift` - Auth service with Sign in with Apple
- `Heirloom/Features/Auth/FirebaseSignInView.swift` - Sign-in UI

### Files Modified
- `Heirloom/App/HeirloomApp.swift`:
  - Added RootView for auth gating
  - Integrated FirebaseSyncService configuration
  - Auth-gated based on BackendConfig
- `Heirloom/Heirloom.entitlements`:
  - Added Sign in with Apple capability

### Key Features
- Sign in with Apple native integration
- Secure nonce generation for auth security
- Firebase Auth state listener for automatic UI updates
- Conditional auth gating (only when Firebase backend is active)
- User profile updates on first sign-in
- Error handling with user-friendly messages

### Firestore Security Rules
```javascript
// Users can only access their own data under users/{userId}/
// All subcollections inherit permissions
```

### Testing Note
**Current Status**: Backend is still CloudKit (default), so Firebase auth won't trigger yet.
**To test Firebase auth**: Switch backend in Phase 9 (Dual-Write Period) or manually via `BackendConfig.shared.setBackend(.firebase)`

## Phase 4: Recipe CRUD Operations ✅ COMPLETED

Completed: ~2 hours (faster than estimated 6 hours due to existing infrastructure)

### Completed Implementation
- ✅ Integrated Firebase sync with recipe creation/update flow
- ✅ Integrated Firebase sync with recipe deletion flow
- ✅ Conditional sync based on `BackendConfig.isFirebaseActive`
- ✅ Error handling (Firebase sync failures don't break local save)
- ✅ Build succeeded with zero errors

### Files Modified
- `Heirloom/Features/Recipes/RecipeEditor/RecipeEditorView.swift`:
  - Added Firebase sync after successful recipe save
  - Calls `FirebaseSyncService.shared.uploadRecipe()` when Firebase active
- `Heirloom/Features/Recipes/RecipeDetail/RecipeDetailView.swift`:
  - Added Firebase imports (FirebaseFirestore, FirebaseAuth)
  - Added Firebase deletion after successful local delete
  - Deletes Firestore document: `users/{userId}/recipes/{recipeId}`

### How It Works
1. **Create/Update**: After `modelContext.save()` succeeds, upload recipe to Firebase if backend active
2. **Delete**: After `modelContext.delete()` and save, delete Firestore document if backend active
3. **Resilience**: Firebase sync errors logged but don't fail local operations
4. **Conditional**: Only syncs when `BackendConfig.shared.isFirebaseActive` is true

### Testing Note
**Current Status**: Backend is still CloudKit (default), so Firebase CRUD operations won't execute yet.
**To test**: Switch to Firebase backend in Phase 9 or manually via settings.

## Phase 5: Image Storage Migration ✅ COMPLETED

Completed: ~2 hours (faster than estimated 4 hours)

### Completed Implementation
- ✅ Added `firebaseImageURL` field to Recipe model
- ✅ Added Firebase Storage imports to FirebaseSyncService
- ✅ Implemented image upload to Firebase Storage (max 1MB compression)
- ✅ Implemented image download from Firebase Storage with local caching
- ✅ Implemented image deletion from Firebase Storage
- ✅ Integrated image upload with recipe save flow
- ✅ Integrated image deletion with recipe delete flow
- ✅ Build succeeded with zero errors

### Files Modified
- `Heirloom/Core/Models/Recipe.swift`:
  - Added `firebaseImageURL: String?` field for Firebase Storage URL
- `Heirloom/Core/Services/Firebase/FirebaseSyncService.swift`:
  - Added `import FirebaseStorage`
  - Added `firebaseImageURL` to Firestore data conversion methods
  - Implemented `uploadImage(for:) -> String?` - uploads image and returns download URL
  - Implemented `downloadImage(for:)` - downloads and caches image locally
  - Implemented `deleteImage(for:)` - deletes image from Firebase Storage
  - Integrated image upload in `uploadRecipe()` (Step 5)
- `Heirloom/Features/Recipes/RecipeDetail/RecipeDetailView.swift`:
  - Added Firebase Storage image deletion to `deleteRecipe()`

### Firebase Storage Structure
```
gs://heirloom-ios-prod.appspot.com/
  users/{userId}/
    recipes/{recipeId}/
      image.jpg (max 1MB, JPEG compressed)
```

### How It Works
1. **Upload**: When recipe is saved with image, Firebase Storage uploads image and stores download URL in Firestore
2. **Download**: When recipe is downloaded, image is fetched from Firebase Storage and cached locally
3. **Delete**: When recipe is deleted, both Firestore document and Storage image are removed
4. **Hybrid Storage**: Local cache (ImageStorageService) + Firebase Storage (cloud backup)
5. **Conditional**: Only syncs when `BackendConfig.shared.isFirebaseActive` is `true`

### Key Features
- **Compression**: Images compressed to max 1MB (1200px max dimension)
- **Caching**: Downloaded images cached locally for offline access
- **Resilient**: Image upload failures don't fail recipe save
- **Graceful**: Missing images handled gracefully (skipped, not errors)

## Migration Timeline

| Phase | Name | Status | Est. Hours | Actual Hours |
|-------|------|--------|------------|--------------|
| 0 | Pre-Migration Backup | ✅ Complete | 1 | 1 |
| 1 | Firebase Infrastructure | ✅ Complete | 3 | 3 |
| 2 | FirebaseSyncService | ✅ Complete | 8 | 8 |
| 3 | Authentication | ✅ Complete | 4 | 4 |
| 4 | Recipe CRUD | ✅ Complete | 6 | 2 |
| 5 | Image Storage | ✅ Complete | 4 | 2 |
| 6 | Sharing Implementation | Pending | 8 | - |
| 7 | Data Migration Script | Pending | 6 | - |
| 8 | Testing & Validation | Pending | 8 | - |
| 9 | Dual-Write Period | Pending | 16 + 2-4 weeks | - |
| 10 | CloudKit Deprecation | Pending | 4 | - |
| **Total** | | | **67 hours + monitoring** | **20/67** |

## Key Architecture Decisions

### Backend Switching
- `BackendConfig.shared.activeBackend` controls which backend is used
- Three modes:
  1. **CloudKit**: Current production (default)
  2. **DualWrite**: Write to both, read from CloudKit (migration period)
  3. **Firebase**: Firebase only (post-migration)

### Data Persistence
- SwiftData remains as local storage layer
- Only replacing CloudKit sync with Firebase sync
- No changes to Recipe/Ingredient models initially

### Zero Data Loss Strategy
1. Phase 1-6: Build Firebase infrastructure (CloudKit still active)
2. Phase 7: Migrate existing data to Firebase
3. Phase 9: Enable dual-write mode (2-4 weeks)
4. Phase 10: Switch to Firebase-only after validation

## Important Notes

- **Separate Firebase Projects**: `heirloom-ios-prod` (new) separate from `heriloom-dev` (website demo)
- **Current Build**: Build 20, Version 1.1.4
- **No User Disruption**: CloudKit remains active until Phase 9 dual-write period
- **Rollback Available**: Git tag `pre-firebase-migration-20251230` for instant rollback

## Next Steps

1. ✅ Complete Phase 1: Firebase Infrastructure
2. ✅ Complete Phase 2: FirebaseSyncService Implementation
3. Begin Phase 3: Authentication Integration
4. Implement Sign in with Apple for Firebase
5. Test Firebase sync with authenticated user

---

**Last Updated**: December 30, 2025
**Migration Version**: 1.0.0
