# Test Account Fixes - TODO Checklist

## Root Cause Understanding

**Key Insight:** Sandbox subscriptions are tied to the **Apple ID** (sandbox tester account in Settings > App Store), NOT the Firebase email used to sign into Heirloom. This means:
- If you purchase a subscription while signed into demo@, it persists for ALL Firebase accounts
- RevenueCat returns the same subscription status for demo@, deletetest@, and tester01@ because they share the sandbox Apple ID
- We must handle this at the app level by overriding subscription status per Firebase account

---

## Fixes Completed

### 1. Typography Refinement - Subscription Warning
- [x] Refine subscription cancellation warning in AccountDeletionView.swift
- [x] "NOT" is bold orange for emphasis
- [x] Secondary instruction in smaller text
- [x] Warning wrapped in styled container with orange background/border

### 2. Profile Seeding
- [x] demo@: Display name set to "ApplePurchaseDemo" on sign-in
- [x] deletetest@: Display name set to "AppleDeleteDemo01" (increments on respawn)
- [x] Uses UserDefaults to track respawn count across account deletions

### 3. Subscription Upgrade Options
- [x] Added `canUpgradeToLifetime` and `canUpgradeToAnnual` in SubscriptionManager
- [x] Annual users see "Upgrade to Lifetime" instead of "Downgrade to Monthly"
- [x] PaywallView shows appropriate plans based on current subscription
- [x] PaywallView header updates based on upgrade type (Lifetime vs Annual)

### 4. CreditsStoreView Info
- [x] Added info about cookbook page scans (5 credits each)
- [x] Added info about video transcription (5 credits)

### 5. tester01@ Fresh User Experience
- [x] Added `isTesterAccount(email:)` function to SubscriptionManager
- [x] Added `isTesterAccountConfigured` flag
- [x] Added `configureForTesterAccount()` - forces trial status, ignores sandbox subscription
- [x] On tester01@ sign-in: Force trial status (ignore RevenueCat sandbox data)
- [x] tester01@ can still make purchases (they become premium after purchase)
- [x] Clear demo/tester account flags on sign-out
- [x] Updated `refreshStatus()` to check for tester account and force trial status

### 6. deletetest@ Sync Issues
- [x] Added `themeContentReady` notification after collections + recipes setup (packaged together)
- [x] CollectionsListView listens for this notification and refreshes theme relationships
- [x] Added cleanup for orphaned recipes (recipes synced without local collections)
- [x] Orphaned recipes from previous test sessions are now deleted
- [x] Same notification posted for demo@ account for consistency

### 7. "See All Plans" / Upgrade Paths
- [x] "Manage Subscription" opens Apple sheet (for cancellation/renewal)
- [x] "Upgrade to Lifetime" (for Annual users) opens PaywallView with Lifetime option
- [x] "Upgrade to Annual" (for Monthly users) opens PaywallView

---

## Test Matrix

After all fixes, verify:

| Account | Expected Behavior |
|---------|-------------------|
| **demo@** | Skip onboarding, day 3 trial, expired status, 0 credits, profile "ApplePurchaseDemo", can purchase and see status update |
| **deletetest@** | Skip onboarding, day 3 trial, themes configured, profile "AppleDeleteDemo01", self-heals on respawn with incremented name, orphaned recipes cleaned up |
| **tester01@** | Full onboarding, day 1 trial (forced), starts as FREE/trial (not premium despite sandbox), can purchase to become premium |

---

## Files Modified

- `AccountDeletionView.swift` - Typography refinement for subscription warning
- `HeirloomApp.swift` - Profile seeding, tester account config, orphaned recipe cleanup
- `SubscriptionManager.swift` - canUpgradeToLifetime, canUpgradeToAnnual, tester account handling, refreshStatus checks
- `SettingsView.swift` - Upgrade to Lifetime for Annual users, removed Downgrade option
- `PaywallView.swift` - Header and plan selection based on upgrade type
- `CreditsStoreView.swift` - Added video transcription and cookbook info

---

## Verification Steps

### demo@
1. Sign in with demo@heirloomrecipebox.app
2. Verify: No onboarding shown
3. Verify: Profile shows "ApplePurchaseDemo"
4. Verify: Collections show German-American + Scandinavian themes
5. Verify: Subscription shows "Expired" or "Free"
6. Verify: Credits balance is 0
7. Test: Purchase a subscription → status updates correctly
8. Test: Can upgrade from Annual to Lifetime

### deletetest@
1. Sign in with deletetest@heirloomrecipebox.app
2. Verify: No onboarding shown
3. Verify: Profile shows "AppleDeleteDemo01"
4. Verify: Day 3 trial state
5. Verify: No orphaned recipes (only theme recipes in theme collections)
6. Delete account
7. Re-create with same email
8. Verify: Profile shows "AppleDeleteDemo02" (incremented)
9. Verify: Self-heals to day 3 with themes

### tester01@
1. Sign in with tester01@heirloomrecipebox.app
2. Verify: Full onboarding flow shown
3. Verify: Status shows "Trial" (not Premium, despite sandbox)
4. Select 2 themes during onboarding
5. Skip subscription ("Continue Free")
6. Verify: Still shows Trial, NOT Premium
7. Test: Can purchase subscription → becomes Premium

---

## Notes

- RevenueCat sandbox auto-renews subscriptions every 5 minutes for monthly, every hour for annual
- Sandbox subscriptions persist across app reinstalls until they naturally expire or are cancelled
- The only way to get a truly "fresh" user on sandbox without our app-level handling is to use a new sandbox Apple ID
- Our app-level handling overrides sandbox status for specific test accounts
