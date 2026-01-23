# Firestore Security Rules Baseline

**Date**: 2026-01-23
**Project**: heirloom-ios-prod
**Rules File**: `/Users/matthanson/Heirloom/firestore.rules`

## Current Rule Status

### ✅ SECURE Collections

1. **User Recipes** (`/users/{userId}/recipes/{recipeId}`)
   - ✅ Properly scoped to user ID
   - ✅ Only owner can create/update/delete
   - ✅ Read access for authenticated users (needed for shares)

2. **Recipe Versions** (`/users/{userId}/recipeVersions/{versionId}`)
   - ✅ Properly scoped to user ID
   - ✅ Only owner can read/write

3. **User Lineages** (`/users/{userId}/lineages/{lineageId}`)
   - ✅ Properly scoped to user ID
   - ✅ Only owner can read/write

4. **User Notifications** (`/users/{userId}/notifications/{notificationId}`)
   - ✅ Properly scoped to user ID
   - ✅ Only owner can read/update/delete
   - ✅ Any authenticated user can create (for lineage tracking notifications)

5. **User Profiles** (`/userProfiles/{userId}`)
   - ✅ Properly scoped to user ID
   - ✅ Only owner can create/update/delete
   - ✅ Read access for authenticated users (for display names)

6. **Lineages Index** (`/lineages/{lineageId}`)
   - ✅ Owner validation on create/update/delete
   - ✅ Read access for authenticated users (for family tree queries)

### 🔴 VULNERABLE Collection

**Shares** (`/shares/{shareId}`) - **CRITICAL SECURITY ISSUE**

**Current Rules** (lines 70-85):
```firestore
match /shares/{shareId} {
  allow read: if isAuthenticated();    // ⚠️ ANY user can read ANY share
  allow update: if isAuthenticated();  // ⚠️ ANY user can update ANY share
  allow delete: if isAuthenticated() && request.auth.uid == resource.data.ownerId;
}
```

**Vulnerabilities**:
1. ❌ **ANY authenticated user can read ANY share** - No restriction to owner or recipients
2. ❌ **ANY authenticated user can update ANY share** - No field-level restrictions
3. ⚠️ Delete is properly restricted (owner only)

**Impact**:
- Malicious user could enumerate all shares in the system
- Malicious user could modify share data (change recipients, ownership, etc.)
- Privacy breach: User A can see all of User B's shares
- Data integrity: User A can corrupt User B's share data

**Expected Behavior**:
- Only owner and allowedRecipients should read shares
- Only owner should update share metadata
- Only recipients should add themselves to acceptedBy
- Only owner should delete shares

## Test Results

### Manual Testing Needed

Current rules have NOT been tested with Firebase emulator yet. To test:

```bash
# Start emulator
firebase emulators:start

# Run test script
./scripts/test-firestore-rules.sh

# Test scenarios documented in script
```

### Known Issues

1. **Share privacy**: No test coverage for share access control
2. **Share updates**: No validation of which fields can be updated by recipients
3. **Share enumeration**: No protection against listing all shares

## Backup Information

**Backup Location**: `~/Desktop/firestore.rules.backup-20260123`
**Backup Size**: 5.1K
**Git Branch**: `backup/pre-production-changes-20260123`

## Deployment History

- **Last Deployment**: Unknown (no deployment tracking in place)
- **Current Version**: As of 2026-01-23 backup
- **Firebase Console**: https://console.firebase.google.com/project/heirloom-ios-prod/firestore/rules

## Recommended Changes

See Task #8: Fix critical Firestore security vulnerability

Required changes to shares collection:
1. Restrict read to owner or allowedRecipients
2. Restrict update to:
   - Owner can update all fields
   - Recipients can only add themselves to acceptedBy array
3. Add validation for required fields
4. Add field-level security for sensitive data

## Monitoring

After rule changes, monitor:
- Firebase Console > Firestore > Rules > Denials
- Crashlytics for permission errors
- User reports of access issues

## References

- Firestore Security Rules Docs: https://firebase.google.com/docs/firestore/security/get-started
- Testing Rules: https://firebase.google.com/docs/rules/unit-tests
- Rollback Procedure: `/docs/security/FIRESTORE_ROLLBACK.md`

---

**Next Steps**: Fix shares collection security before production deployment
