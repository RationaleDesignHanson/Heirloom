# Inter-Heirloom Sharing - End-to-End Test Plan

**Test Date:** 2026-01-30
**Feature:** Direct recipe sharing to connections + Share Analytics Dashboard
**Status:** Ready for testing

---

## Pre-Test Checklist

- [ ] Two test accounts with at least one connected relationship
- [ ] At least one recipe in each account
- [ ] Both accounts have push notifications enabled
- [ ] Firebase console access to verify data writes

---

## Test Flow 1: Direct Share to Single Connection

### Setup
- **Account A:** Sender (has recipe "Chocolate Chip Cookies")
- **Account B:** Recipient (connected to Account A)

### Steps

1. **Account A: Initiate Share**
   - [ ] Open recipe "Chocolate Chip Cookies"
   - [ ] Tap share button
   - [ ] RecipeShareSheet opens
   - [ ] Verify default tab is "Via Link"

2. **Account A: Switch to Direct Share**
   - [ ] Tap "To Connections" tab
   - [ ] ConnectionPickerView appears
   - [ ] Verify Account B appears in list with:
     - [ ] Profile photo
     - [ ] Display name
     - [ ] "X recipes shared" subtitle
   - [ ] Tap Account B to select (checkbox appears)
   - [ ] Verify button text changes to "Share with 1 Friend"

3. **Account A: Complete Share**
   - [ ] Tap "Share with 1 Friend" button
   - [ ] Verify success message appears
   - [ ] Sheet dismisses

4. **Account B: Receive Notification**
   - [ ] Verify push notification received:
     - Title: "[Account A Name] shared a recipe"
     - Body: "Chocolate Chip Cookies"
   - [ ] Tap notification
   - [ ] App opens (if closed) OR navigates to Kitchen Table

5. **Account B: View in Inbox**
   - [ ] Open Kitchen Table
   - [ ] Verify green banner: "Recipes Shared With You - 1 pending"
   - [ ] Tap banner
   - [ ] SharedWithMeView opens
   - [ ] Verify share appears:
     - [ ] Sender photo
     - [ ] Recipe title: "Chocolate Chip Cookies"
     - [ ] "From [Account A Name]"
     - [ ] Time ago (e.g., "Just now")

6. **Account B: Accept Share**
   - [ ] Tap the share row
   - [ ] RecipeReceiveSheet opens
   - [ ] Verify recipe preview displays correctly:
     - [ ] Recipe title
     - [ ] Ingredients list
     - [ ] Instructions
     - [ ] "Shared by [Account A Name]"
   - [ ] Tap "Accept Recipe" button
   - [ ] Verify success message
   - [ ] Sheet dismisses

7. **Account B: Verify Recipe Imported**
   - [ ] Navigate to Collections
   - [ ] Verify "From Friends" collection exists
   - [ ] Open "From Friends" collection
   - [ ] Verify "Chocolate Chip Cookies" appears
   - [ ] Open recipe
   - [ ] Verify all content matches original:
     - [ ] Title
     - [ ] Ingredients
     - [ ] Instructions
     - [ ] Photos (if any)
   - [ ] Verify lineage metadata preserved (check recipe.provenance)

8. **Account B: Verify Inbox Updated**
   - [ ] Return to Kitchen Table
   - [ ] Verify green banner no longer appears (count = 0)
   - [ ] Open SharedWithMeView
   - [ ] Verify empty state: "No Pending Shares"

---

## Test Flow 2: Direct Share to Multiple Connections

### Setup
- **Account A:** Sender
- **Accounts B, C, D:** Recipients (all connected to Account A)

### Steps

1. **Account A: Select Multiple Recipients**
   - [ ] Open recipe
   - [ ] Tap share → "To Connections"
   - [ ] Select Account B (checked)
   - [ ] Select Account C (checked)
   - [ ] Select Account D (checked)
   - [ ] Verify button text: "Share with 3 Friends"

2. **Account A: Complete Share**
   - [ ] Tap "Share with 3 Friends"
   - [ ] Verify success message

3. **All Recipients: Receive Notifications**
   - [ ] Account B receives notification
   - [ ] Account C receives notification
   - [ ] Account D receives notification

4. **Account B: Accept First**
   - [ ] Accept share (follow Flow 1 steps 5-7)
   - [ ] Verify recipe imported

5. **Account C: Accept Second**
   - [ ] Accept share
   - [ ] Verify recipe imported independently

6. **Account D: Ignore (Don't Accept)**
   - [ ] Leave share in inbox unaccepted

---

## Test Flow 3: Share Analytics Dashboard

### Setup
- **Account A:** Has sent 3 shares:
  - Share 1: To Account B (accepted)
  - Share 2: To Account B + Account C (both accepted)
  - Share 3: To Account D (not accepted)

### Steps

1. **Account A: Open Analytics Dashboard**
   - [ ] Open Kitchen Table
   - [ ] Tap chart icon in toolbar (top-right)
   - [ ] ShareAnalyticsDashboard opens

2. **Account A: Verify Overview Cards**
   - [ ] "Sent" card shows: 3
   - [ ] "Received" card shows: [actual count]
   - [ ] "Accepted" card shows: 3 (from 2 accepted shares)
   - [ ] Colors match design (tomato, green, periwinkle)

3. **Account A: Verify Acceptance Rate**
   - [ ] Large percentage displays correctly
   - [ ] Calculation: 2 shares with acceptances / 3 total shares = 67%
   - [ ] Progress bar fills to 67%
   - [ ] Color is yellow (50-75% range)
   - [ ] Text: "3 of 4 recipients accepted"

4. **Account A: Verify Most Shared Recipe**
   - [ ] Section displays if multiple shares of same recipe
   - [ ] Shows recipe title
   - [ ] Shows count "Shared X times"

5. **Account A: Verify Share History**
   - [ ] "Recent Shares" section displays
   - [ ] All 3 shares appear in reverse chronological order
   - [ ] Each share row shows:
     - [ ] Recipe title
     - [ ] Acceptance rate badge (color-coded)
     - [ ] "X of Y accepted"
     - [ ] Recipient names (or "X recipients")
     - [ ] Time ago

6. **Account A: Pull to Refresh**
   - [ ] Pull down to refresh
   - [ ] Data reloads
   - [ ] Stats update correctly

---

## Test Flow 4: Edge Cases

### Empty State Analytics
1. **New Account:** No shares sent or received
   - [ ] Open analytics dashboard
   - [ ] Verify empty state displays:
     - [ ] Chart icon
     - [ ] "No Analytics Yet"
     - [ ] "Start sharing recipes to see your analytics"

### Expired Share
1. **Create expired share:**
   - [ ] Manually set share expiration in Firebase (for testing)
   - [ ] Verify expired share doesn't appear in inbox
   - [ ] Verify expired share doesn't count in analytics

### Search in Connection Picker
1. **Account A: Test Search**
   - [ ] Open share sheet → "To Connections"
   - [ ] Type connection name in search bar
   - [ ] Verify filtered results appear
   - [ ] Clear search
   - [ ] Verify all connections return

### No Connections Yet
1. **New Account:** No connections
   - [ ] Open share sheet → "To Connections"
   - [ ] Verify empty state:
     - [ ] "No Connections Yet"
     - [ ] "Invite friends to share recipes with them"
     - [ ] "Invite Someone" button

---

## Firebase Verification

### Share Document Structure
After creating a direct share, verify Firestore document at `shares/{shareId}`:

```javascript
{
  // Existing fields
  shareId: "...",
  ownerId: "account-a-id",
  recipeId: "...",
  recipeTitle: "Chocolate Chip Cookies",
  shareType: "heirloom",
  generationCount: 2,
  rootRecipeId: "...",
  rootOwnerId: "...",
  provenance: {...},
  isDirectShare: true,
  createdAt: Timestamp,
  expiresAt: Timestamp,

  // NEW fields
  recipientUserIds: ["account-b-id", "account-c-id"],
  recipientDisplayNames: {
    "account-b-id": "Bob",
    "account-c-id": "Carol"
  },
  sharedWithCount: 2,

  // Acceptance tracking
  acceptedBy: ["account-b-id"],  // Updates as users accept
  acceptCount: 1
}
```

### Analytics Queries
Verify queries work efficiently:
1. **Fetch shares for user:** `recipientUserIds array-contains userId`
2. **Fetch share history:** `ownerId == userId AND isDirectShare == true`

---

## Performance Tests

### Connection Picker Load Time
- [ ] Open connection picker with 50+ connections
- [ ] Verify loads < 1 second
- [ ] Search filters instantly

### Analytics Dashboard Load
- [ ] Open analytics with 100+ shares
- [ ] Verify loads < 2 seconds
- [ ] Calculations complete correctly

### Notification Delivery
- [ ] Direct share to 10 connections
- [ ] Verify all notifications delivered within 5 seconds

---

## Regression Tests

### Existing Share Features Still Work
- [ ] "Via Link" tab still creates generic link shares
- [ ] External share sheet still works
- [ ] Recipe acceptance from link shares works
- [ ] CollectionRouter still routes to correct collections

### Lineage Preservation
- [ ] Accept direct share
- [ ] Verify generation count incremented
- [ ] Verify rootRecipeId maintained
- [ ] Verify provenance chain intact

---

## Success Criteria

✅ **All test flows pass without errors**
✅ **Firebase data structure correct**
✅ **Notifications delivered reliably**
✅ **Analytics calculations accurate**
✅ **UI responsive and intuitive**
✅ **No breaking changes to existing features**
✅ **Lineage tracking maintained**

---

## Known Issues / Blockers

_Document any issues discovered during testing:_

1.
2.
3.

---

## Test Results

**Tested By:** ___________
**Date:** ___________
**Build:** ___________
**Result:** PASS / FAIL / PARTIAL

**Notes:**


