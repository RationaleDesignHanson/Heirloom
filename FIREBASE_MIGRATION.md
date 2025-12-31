# Firebase Migration Documentation

## Overview
Migrating Heirloom from CloudKit to Firebase Firestore to resolve hierarchical sharing limitations discovered in Build 20.

**Start Date**: December 30, 2025
**Current Phase**: Phase 2 (FirebaseSyncService Implementation)
**Status**: Phase 2 Complete - Ready for Phase 3

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

## Phase 3: Authentication Integration (Pending)

Estimated: 4 hours

### Planned Implementation
- Integrate Firebase Auth with Sign in with Apple
- Map CloudKit user IDs to Firebase UIDs
- Update security rules for user-scoped data access

## Migration Timeline

| Phase | Name | Status | Est. Hours |
|-------|------|--------|------------|
| 0 | Pre-Migration Backup | ✅ Complete | 1 |
| 1 | Firebase Infrastructure | ✅ Complete | 3 |
| 2 | FirebaseSyncService | ✅ Complete | 8 |
| 3 | Authentication | Pending | 4 |
| 4 | Recipe CRUD | Pending | 6 |
| 5 | Image Storage | Pending | 4 |
| 6 | Sharing Implementation | Pending | 8 |
| 7 | Data Migration Script | Pending | 6 |
| 8 | Testing & Validation | Pending | 8 |
| 9 | Dual-Write Period | Pending | 16 + 2-4 weeks |
| 10 | CloudKit Deprecation | Pending | 4 |
| **Total** | | | **67 hours + monitoring** |

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
