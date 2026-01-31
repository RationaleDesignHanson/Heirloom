# Phase 8: Lineage Integration - Verification Guide

**Status:** ✅ PRODUCTION ACTIVE (No stub blocking execution)

**Date:** 2026-01-30

---

## How to Verify Phase 8 is Working

### Test Scenario 1: View Lineage with Connected User

**Setup:**
1. Have 2 test accounts (User A and User B)
2. User A and User B are connected
3. User A has shared a recipe to User B
4. User B has accepted the recipe

**Test Steps:**
1. **Open User B's account**
2. Navigate to the shared recipe
3. Tap **"Lineage"** button
4. **Expected Result:**
   - Timeline view shows recipe nodes
   - Each node shows contributor row below title:
     ```
     [Avatar] User A's Name [✓]
     ```
   - Avatar: 20x20 circle (initials fallback if no photo)
   - Name: Displayed in tomato color
   - Green checkmark: Appears because users are connected

5. **Tap on contributor row**
6. **Expected Result:**
   - `LineageContributorSheet` opens
   - Shows User A's name
   - Shows "Connected" badge (green)
   - Shows "Recipe Lineage Contributor" context badge

---

### Test Scenario 2: View Lineage with Non-Connected User

**Setup:**
1. Have 3 test accounts (User A, User B, User C)
2. User A and User B are connected
3. User B and User C are connected
4. User A is NOT connected to User C
5. User A shared recipe to User B
6. User B shared it to User C

**Test Steps:**
1. **Open User C's account**
2. Navigate to the recipe (2nd generation)
3. Tap **"Lineage"** button
4. **Expected Result:**
   - Timeline shows 2 nodes:
     - Generation 0: User A's original (no checkmark)
     - Generation 1: User B's version (checkmark ✓)
   - User A's row: `[Avatar] User A ` (no checkmark)
   - User B's row: `[Avatar] User B [✓]`

5. **Tap User A's contributor row**
6. **Expected Result:**
   - Sheet opens showing User A
   - NO "Connected" badge (they're not connected)
   - Still shows "Recipe Lineage Contributor" badge

---

### Test Scenario 3: Legacy Recipe (No Lineage)

**Setup:**
1. Have a recipe with `sharedBy` field = "Grandma Smith"
2. No lineage document in Firestore

**Test Steps:**
1. Open the recipe
2. Tap **"Lineage"** button
3. **Expected Result:**
   - Timeline shows single node (Generation 0: Original)
   - Contributor row shows: `Grandma Smith` in gray
   - No avatar, no checkmark
   - Row is NOT tappable

4. **Try tapping contributor row**
5. **Expected Result:**
   - Nothing happens (disabled)

---

## Verification via Console Logs

When viewing lineage, watch Console for these logs:

### Success Path:
```
🔍 Fetching contributor info for lineage node [ownerId: abc123, generation: 1]
✅ Phase 8: Contributor loaded [userId: abc123, displayName: "John Chef", isConnected: true]
```

### Partial Success (No connection):
```
🔍 Fetching contributor info for lineage node [ownerId: def456, generation: 0]
✅ Phase 8: Contributor loaded [userId: def456, displayName: "Jane Smith", isConnected: false]
```

### Warning (Profile not found):
```
🔍 Fetching contributor info for lineage node [ownerId: xyz789, generation: 1]
⚠️  No display name found for user [userId: xyz789]
```

---

## Known Limitations

### 1. Avatar URLs Not Shown
**Status:** Expected behavior
**Reason:** `FirebaseUserProfileService` only returns display names, not photo URLs
**Workaround:** Avatar shows initials instead
**Fix:** Upgrade to full `ProfileService` API in future (requires Phase 9+)

### 2. Connection Check Performance
**Status:** Works but not optimal
**Reason:** Fetches ALL connections and filters client-side
**Impact:** Slow with 100+ connections
**Workaround:** Results are cached after first fetch
**Fix:** Add `checkConnectionStatus(userId:)` method to `ConnectionService`

### 3. No Avatar Loading Indicators
**Status:** Expected behavior
**Reason:** Using basic `AsyncImage` without loading states
**Impact:** Brief flash before initials appear
**Fix:** Add loading shimmer in future enhancement

---

## Troubleshooting

### Problem: "No contributor shown"
**Causes:**
1. Recipe has no lineage in Firestore
2. Recipe `ownerId` field is empty
3. User profile doesn't exist

**Debug:**
```swift
// Check Recipe.provenance field
print(recipe.provenance?.sharedByUserId)  // Should have user ID

// Check Firestore lineages collection
// Query: rootRecipeId == <recipe's root ID>
```

### Problem: "Connected checkmark not showing"
**Causes:**
1. Users aren't actually connected (check Firestore connections collection)
2. Connection status is `.pending` not `.connected`
3. ConnectionService cache is stale

**Debug:**
```swift
// Force refresh connections
let connections = try await connectionService.fetchConnections(status: .connected, forceRefresh: true)
print("Connected users:", connections.map { $0.connectedUserId })
```

### Problem: "Contributor tap does nothing"
**Causes:**
1. Contributor is legacy (has no account)
2. `contributorInfo.hasAccount == false`

**Expected:** Legacy contributors (from `sharedBy` string field) should not be tappable

---

## Data Requirements

For Phase 8 to work, recipes must have:

### Firestore Lineage Documents
```javascript
lineages/{lineageId} {
    rootRecipeId: "abc123",
    currentRecipeId: "def456",
    ownerId: "user-123",  // ← Required for contributor lookup
    generation: 1,
    parentRecipeId: "abc123",
    lastModified: timestamp
}
```

### User Profile Documents
```javascript
userProfiles/{userId} {
    displayName: "John Chef",  // ← Required
    photoURL: "https://...",   // ← Optional (not used yet)
    email: "john@example.com"
}
```

### Connection Documents
```javascript
users/{userId}/connections/{connectionId} {
    connectedUserId: "user-456",
    status: "connected",  // ← Must be "connected" to show checkmark
    ...
}
```

---

## Success Criteria

Phase 8 is working correctly when:

✅ **Display**
- [x] Contributor row appears below recipe title in lineage timeline
- [x] Avatar or initials shown (20x20 circle)
- [x] Display name shown in tomato color (if has account) or gray (legacy)
- [x] Green checkmark appears for connected users

✅ **Interaction**
- [x] Contributors with accounts are tappable
- [x] Legacy contributors (no account) are not tappable
- [x] Tapping opens `LineageContributorSheet`

✅ **Profile Sheet**
- [x] Shows contributor name and avatar
- [x] Shows "Connected" badge for connected users
- [x] Shows "Recipe Lineage Contributor" context badge
- [x] Gracefully handles legacy contributors

✅ **Performance**
- [x] Lineage loads within 3 seconds for trees with < 10 nodes
- [x] No blocking on contributor fetches (async)
- [x] Graceful degradation if profiles fail to load

---

**Phase 8 Status:** ACTIVE and READY FOR TESTING

Test with your existing user accounts and recipes to verify all features work correctly!
