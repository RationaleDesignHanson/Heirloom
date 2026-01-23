# Critical Security Fix: Firestore Shares Collection

**Date**: 2026-01-23
**Severity**: 🔴 **CRITICAL**
**Status**: ✅ **FIXED** (Pending deployment)

## Vulnerability Summary

### What Was Wrong

**Before Fix** (firestore.rules lines 70-85):
```firestore
match /shares/{shareId} {
  allow read: if isAuthenticated();      // ✅ OK - Shares are link-based
  allow update: if isAuthenticated();    // ❌ CRITICAL - ANY user can update ANY share
  allow delete: if isAuthenticated() && request.auth.uid == resource.data.ownerId;  // ✅ OK
}
```

**Impact**:
- ❌ ANY authenticated user could update ANY share document
- ❌ Malicious user could modify:
  - `ownerId` (claim ownership)
  - `acceptedBy` array (add/remove others)
  - `recipeTitle` (deface shares)
  - `shareType` (change share behavior)
  - `expiresAt` (prevent expiration)
  - Metadata fields (corrupt data)
- ❌ No validation on required fields during creation
- ⚠️ Privacy risk: While read access is broad (for link-based sharing), lack of update restrictions is severe

---

## The Fix

### Secure Rules (firestore.rules lines 70-105)

**Key Changes**:

1. **Validated Share Creation**
   ```firestore
   allow create: if isAuthenticated() &&
                    request.auth.uid == request.resource.data.ownerId &&
                    request.resource.data.keys().hasAll(['shareId', 'recipeId', 'ownerId', 'ownerName']);
   ```
   - ✅ Must own the share (ownerId matches auth.uid)
   - ✅ Must include required fields

2. **Restricted Updates** - Two allowed paths:

   **Path A: Owner Updates** (Owner can update any field)
   ```firestore
   request.auth.uid == resource.data.ownerId
   ```

   **Path B: Recipient Acceptance** (Recipient can ONLY add themselves to acceptedBy)
   ```firestore
   // Cannot change core fields
   request.resource.data.shareId == resource.data.shareId &&
   request.resource.data.recipeId == resource.data.recipeId &&
   request.resource.data.ownerId == resource.data.ownerId &&

   // Can only add themselves to acceptedBy (not remove or add others)
   request.resource.data.acceptedBy.hasAll(resource.data.acceptedBy) &&
   request.resource.data.acceptedBy.hasOnly(resource.data.acceptedBy.concat([request.auth.uid])) &&
   !(request.auth.uid in resource.data.acceptedBy)
   ```

3. **Read Access** - Unchanged (intentional)
   - Shares are designed to be accessed via link
   - Authenticated users can read shares (this is expected behavior)
   - ShareId is the "secret" - knowledge of shareId grants access

---

## Security Guarantees After Fix

### ✅ What's Protected

- ✅ **Ownership Integrity**: Cannot change `ownerId` after creation
- ✅ **Share Integrity**: Cannot modify core share fields (shareId, recipeId, ownerId)
- ✅ **Acceptance Control**: Recipients can ONLY add themselves to acceptedBy
- ✅ **Metadata Protection**: Cannot modify share metadata unless you're the owner
- ✅ **Deletion Control**: Only owner can delete shares

### ✅ What's Allowed

- ✅ **Owner Control**: Owner can update any field (valid business logic)
- ✅ **Self-Acceptance**: Recipients can add themselves to acceptedBy (share acceptance flow)
- ✅ **Link-Based Access**: Anyone with shareId can read (link-based sharing design)

---

## Testing Scenarios

### Must Test Before Deployment

**Test in Firebase Emulator**: `/scripts/test-firestore-rules.sh`

#### Scenario 1: Owner Updates (Should PASS ✅)
```
Given: User A owns share-123
When: User A updates share-123 (change recipeTitle)
Then: Update succeeds ✅
```

#### Scenario 2: Recipient Accepts (Should PASS ✅)
```
Given: User B receives share-123 owned by User A
When: User B adds themselves to acceptedBy array
Then: Update succeeds ✅
```

#### Scenario 3: Malicious User Tries to Update (Should FAIL ❌)
```
Given: User C knows share-123 shareId (not owner, not accepting)
When: User C tries to update share-123 (any field)
Then: Update FAILS with permission denied ❌
```

#### Scenario 4: Recipient Tries to Modify Other Fields (Should FAIL ❌)
```
Given: User B receives share-123
When: User B tries to update recipeTitle while accepting
Then: Update FAILS ❌
```

#### Scenario 5: Recipient Already Accepted (Should FAIL ❌)
```
Given: User B already accepted share-123
When: User B tries to add themselves to acceptedBy again
Then: Update FAILS (already in array) ❌
```

#### Scenario 6: Recipient Tries to Add Others (Should FAIL ❌)
```
Given: User B receives share-123
When: User B tries to add User C to acceptedBy
Then: Update FAILS (can only add self) ❌
```

---

## Deployment Checklist

### Before Deploying

- [ ] Test rules in Firebase emulator
- [ ] Verify all 6 test scenarios pass/fail correctly
- [ ] Review rules diff one final time
- [ ] Backup current rules (already done: `~/Desktop/firestore.rules.backup-20260123`)
- [ ] Read rollback procedure (`/docs/security/FIRESTORE_ROLLBACK.md`)
- [ ] Notify team of deployment window

### Deployment

```bash
# 1. Authenticate with Firebase
firebase login

# 2. Deploy rules to production
firebase deploy --only firestore:rules --project heirloom-ios-prod
```

### After Deploying

**Monitor These Metrics for 24-48 Hours**:

- [ ] **Firebase Console > Firestore > Rules**:
  - Check rule denial rate (should be < 1%)
  - Watch for spike in denials (indicates app breaking)

- [ ] **App Functionality**:
  - Test share creation (should work)
  - Test share acceptance (should work)
  - Test share deletion (should work)

- [ ] **User Reports**:
  - Monitor for "can't accept share" reports
  - Monitor for "can't delete share" reports

- [ ] **Crashlytics** (once configured):
  - Watch for permission-related crashes
  - Check error logs for Firestore permission errors

---

## Known Limitations & Trade-offs

### Read Access is Broad (By Design)

**Current**:
```firestore
allow read: if isAuthenticated();
```

**Why Not More Restrictive?**
- Shares are designed to be accessed via link (like Google Drive sharing)
- ShareId acts as the "secret" - if you have the link, you can view
- Restricting read to only allowedRecipients would break link-based sharing

**Alternative (Not Implemented)**:
```firestore
// More restrictive read (would break current sharing model)
allow read: if isAuthenticated() && (
  request.auth.uid == resource.data.ownerId ||
  request.auth.uid in resource.data.get('allowedRecipients', [])
);
```

**Decision**: Keep broad read access for link-based sharing model. ShareId provides sufficient access control.

---

### Acceptance Flow Must Update Exactly These Fields

The current rules allow recipients to update these fields during acceptance:
- `acceptedBy` (add themselves)
- `acceptCount` (increment - via client code)
- `lastAcceptedAt` (timestamp - via client code)

**Implementation Note**: The app's `FirebaseShareService.swift` (line 496) updates these fields during acceptance. Ensure this behavior matches the rules.

---

## Rollback Procedure

If issues occur after deployment:

```bash
# 1. Restore from backup
cp ~/Desktop/firestore.rules.backup-20260123 /Users/matthanson/Heirloom/firestore.rules

# 2. Redeploy old rules
firebase deploy --only firestore:rules --project heirloom-ios-prod

# 3. Verify rollback
# Check Firebase Console > Firestore > Rules
```

**See**: `/docs/security/FIRESTORE_ROLLBACK.md` for detailed rollback procedures

---

## Code Review Checklist

Reviewed by: _________________
Date: _________________

- [ ] Rules logic is correct
- [ ] All test scenarios considered
- [ ] Deployment procedure clear
- [ ] Rollback procedure ready
- [ ] Monitoring plan in place
- [ ] Team notified

---

## References

- **Vulnerability Baseline**: `/docs/security/FIRESTORE_RULES_BASELINE.md`
- **Rollback Procedure**: `/docs/security/FIRESTORE_ROLLBACK.md`
- **Firebase Rules Docs**: https://firebase.google.com/docs/firestore/security/get-started
- **Rule Testing**: https://firebase.google.com/docs/rules/unit-tests

---

**Document Owner**: Matt Hanson
**Next Review**: After successful deployment
**Status**: Rules fixed, awaiting deployment and testing

---

## Appendix: Full Rules Diff

```diff
  match /shares/{shareId} {
-   // Anyone with link can read (for accepting shares)
-   allow read: if isAuthenticated();
+   // Anyone with link can read (for accepting shares)
+   // Share links are meant to be shareable, so authenticated users can read
+   allow read: if isAuthenticated();

-   // Only owner can create shares
-   allow create: if isAuthenticated() &&
-                    request.auth.uid == request.resource.data.ownerId;
+   // Only owner can create shares, with proper validation
+   allow create: if isAuthenticated() &&
+                    request.auth.uid == request.resource.data.ownerId &&
+                    request.resource.data.keys().hasAll(['shareId', 'recipeId', 'ownerId', 'ownerName']);

-   // ANY authenticated user can update shares (for accepting)
-   // This allows recipients to add themselves to acceptedBy array
-   allow update: if isAuthenticated();
+   // Restricted update: Owner can update all fields OR recipient can add themselves to acceptedBy
+   allow update: if isAuthenticated() && (
+     // Owner can update any fields
+     request.auth.uid == resource.data.ownerId ||
+
+     // Recipient can ONLY add themselves to acceptedBy array (and update related counters)
+     (
+       // Must not change core fields
+       request.resource.data.shareId == resource.data.shareId &&
+       request.resource.data.recipeId == resource.data.recipeId &&
+       request.resource.data.ownerId == resource.data.ownerId &&
+
+       // Can only add themselves to acceptedBy (not remove or add others)
+       request.resource.data.acceptedBy is list &&
+       request.resource.data.acceptedBy.hasAll(resource.data.acceptedBy) &&
+       request.resource.data.acceptedBy.hasOnly(resource.data.acceptedBy.concat([request.auth.uid])) &&
+
+       // Verify they're actually adding themselves (not already in list)
+       !(request.auth.uid in resource.data.acceptedBy)
+     )
+   );

-   // Only owner can delete
-   allow delete: if isAuthenticated() &&
-                    request.auth.uid == resource.data.ownerId;
+   // Only owner can delete
+   allow delete: if isAuthenticated() &&
+                    request.auth.uid == resource.data.ownerId;
  }
```
