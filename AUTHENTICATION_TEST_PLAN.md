# Authentication Test Plan - Option A (Hybrid Auth UX)

## Overview
Testing the complete authentication flow with:
- Non-blocking heritage recipe exploration
- Settings tab sign-in
- Contextual auth prompts for sharing
- Automatic Firebase sync on login

## Test Environment
- **Simulator**: iPhone 16 Pro (iOS 18.2)
- **Firebase**: Email/Password, Apple Sign-In, Google Sign-In enabled
- **Backend**: Firebase (active)

---

## Test Cases

### 1. First Launch Experience ✅ CRITICAL

**Scenario**: New user opens app for first time (not authenticated)

**Expected Behavior**:
- ✅ App launches successfully (no Firebase crash)
- ✅ User sees Recipes tab with heritage recipes (8-12 personalized recipes)
- ✅ User can browse heritage recipes WITHOUT being forced to sign in
- ✅ Heritage collections visible in Collections tab
- ✅ Shopping cart and meal planning accessible

**Test Steps**:
1. Delete app from simulator
2. Reinstall and launch
3. Verify heritage recipes are visible
4. Navigate through all tabs
5. Try to view recipe details

**Log Check**: Look for:
```
✅ [Heritage] Seeded X personalized heritage recipes
🔧 [Heirloom] Active backend: Firebase
```

---

### 2. Settings Tab Sign-In ✅ CRITICAL

**Scenario**: User navigates to Settings and signs in

**Expected Behavior**:
- ✅ Settings tab shows "Sign In" button when not authenticated
- ✅ Button text: "Sign In" with person.circle.fill icon
- ✅ Footer text explains benefits: "Sign in to sync your recipes across devices and share with friends"
- ✅ Tapping opens FirebaseSignInView sheet

**Test Steps**:
1. Go to Settings tab (tab 4)
2. Scroll to Account section
3. Verify "Sign In" button is visible
4. Tap "Sign In" button
5. Verify sign-in sheet appears

---

### 3. Email/Password Sign-In ✅ CRITICAL

**Scenario**: User signs in with email/password

**Expected Behavior**:
- ✅ FirebaseSignInView shows Apple, Google, and Email options
- ✅ Tapping "Sign in with Email" shows email form
- ✅ Email form has: email field, password field, submit button
- ✅ Toggle between "Sign In" and "Create Account"
- ✅ "Forgot password?" link visible when signing in
- ✅ Password must be 6+ characters (validation)
- ✅ Submit button disabled if invalid

**Test Steps**:
1. Tap "Sign in with Email"
2. Verify form layout
3. Try submitting with empty fields (should be disabled)
4. Try password < 6 chars (should be disabled)
5. Toggle "Create Account" / "Sign In"
6. Create test account: test@example.com / password123
7. Verify successful authentication

**Log Check**: Look for:
```
✅ [Auth] Successfully created account: <user-id>
✅ [Auth] User authenticated - starting automatic sync
🔄 [Firebase] Starting automatic sync...
🔄 [Firebase] Performing initial sync on startup...
```

---

### 4. Automatic Firebase Sync After Login ✅ CRITICAL

**Scenario**: After successful sign-in, heritage recipes sync to Firebase

**Expected Behavior**:
- ✅ `startAutomaticSync()` called automatically
- ✅ Initial sync uploads local heritage recipes to Firebase
- ✅ Periodic sync enabled (every 5 minutes)
- ✅ Foreground sync enabled (when app returns from background)
- ✅ No data loss - all heritage recipes preserved

**Test Steps**:
1. Sign in with email/password
2. Wait 2-3 seconds for initial sync
3. Check logs for sync activity
4. Go to Firebase Console → Firestore
5. Verify recipes collection exists under users/<user-id>/recipes
6. Count recipes - should match local count

**Log Check**: Look for:
```
✅ [Auth] User authenticated - starting automatic sync
🔄 [Firebase] Starting automatic sync...
🔄 [Firebase] Performing initial sync on startup...
📤 [Firebase] Uploading local changes...
✅ [Firebase] Uploaded recipe: <recipe-title>
```

---

### 5. Contextual Auth Prompt for Sharing ✅ CRITICAL

**Scenario**: Unauthenticated user tries to share a recipe

**Expected Behavior**:
- ✅ Share menu item visible in recipe detail (3-dot menu)
- ✅ Tapping "Share Recipe" checks auth state
- ✅ If not authenticated: shows sign-in prompt sheet
- ✅ Prompt shows: icon, "Sign in to share" title, explanation
- ✅ "Continue to Sign In" button navigates to Settings
- ✅ "Maybe Later" dismisses prompt

**Test Steps**:
1. Sign out if authenticated
2. Open any heritage recipe
3. Tap 3-dot menu (top right)
4. Tap "Share Recipe"
5. Verify contextual sign-in prompt appears
6. Test "Maybe Later" (dismisses)
7. Test again, tap "Continue to Sign In"
8. Verify navigates to Settings sign-in

**Code Location**: RecipeDetailView.swift:~1150-1200

---

### 6. Already Authenticated on Launch ✅ IMPORTANT

**Scenario**: User closes app, reopens while still authenticated

**Expected Behavior**:
- ✅ FirebaseAuthService restores session from Firebase Auth
- ✅ `isAuthenticated = true` on app launch
- ✅ RootView.onAppear() detects authenticated state
- ✅ `startAutomaticSync()` called immediately
- ✅ Initial sync performed on launch

**Test Steps**:
1. Sign in with test account
2. Force quit app (swipe up in app switcher)
3. Relaunch app
4. Verify no sign-in screen shown
5. Check logs for automatic sync

**Log Check**: Look for:
```
🔥 [Heirloom] Restored auth session: <user-id>
✅ [Auth] User already authenticated - starting automatic sync
🔄 [Firebase] Starting automatic sync...
```

---

### 7. Sign Out Flow ✅ IMPORTANT

**Scenario**: User signs out from Settings

**Expected Behavior**:
- ✅ Settings shows "Sign Out" button when authenticated
- ✅ Confirmation dialog: "You'll need to sign in again to access your recipes"
- ✅ After sign out: local data cleared
- ✅ After sign out: sync timestamps cleared
- ✅ Success toast: "Signed out successfully"
- ✅ User returns to browsing heritage recipes (no force to sign in)

**Test Steps**:
1. Sign in
2. Go to Settings → Account section
3. Tap "Sign Out"
4. Confirm in dialog
5. Verify toast appears
6. Verify can still browse heritage recipes
7. Verify Settings shows "Sign In" button again

**Code Location**: SettingsView.swift:459-481

---

### 8. Password Reset Flow ✅ IMPORTANT

**Scenario**: User forgot password and requests reset

**Expected Behavior**:
- ✅ "Forgot password?" link visible in email sign-in form
- ✅ Tapping opens password reset sheet
- ✅ Sheet has email field and "Send Reset Link" button
- ✅ Button disabled if email empty
- ✅ After sending: "Reset Email Sent" alert
- ✅ Alert message: "Check your email for a link to reset your password"

**Test Steps**:
1. Go to sign-in
2. Tap "Sign in with Email"
3. Tap "Forgot password?"
4. Enter test@example.com
5. Tap "Send Reset Link"
6. Verify success alert
7. Check email for reset link (if real email used)

**Code Location**: FirebaseSignInView.swift:328-391

---

### 9. Apple Sign-In Flow ⚠️ REQUIRES DEVICE

**Scenario**: User signs in with Apple

**Expected Behavior**:
- ✅ "Sign in with Apple" button visible
- ✅ Apple auth sheet appears
- ✅ After auth: Firebase credential created
- ✅ Automatic sync triggered
- ✅ Display name updated if provided

**Test Steps**:
1. Tap "Sign in with Apple"
2. Complete Apple authentication
3. Verify sync starts
4. Check Settings for user email

**Note**: Requires actual device or configured simulator with Apple ID

---

### 10. Google Sign-In Flow ⚠️ REQUIRES DEVICE

**Scenario**: User signs in with Google

**Expected Behavior**:
- ✅ "Sign in with Google" button visible
- ✅ Google auth sheet appears
- ✅ After auth: Firebase credential created
- ✅ Automatic sync triggered

**Test Steps**:
1. Tap "Sign in with Google"
2. Complete Google authentication
3. Verify sync starts
4. Check Settings for user email

**Note**: Requires actual device with Google account

---

### 11. Error Handling - Invalid Credentials ✅ IMPORTANT

**Scenario**: User enters wrong email/password

**Expected Behavior**:
- ✅ Firebase returns error
- ✅ Alert shown: "Sign In Error"
- ✅ Error message displayed
- ✅ User can try again

**Test Steps**:
1. Try signing in with wrong password
2. Verify error alert appears
3. Verify can retry

---

### 12. Error Handling - Network Offline ⚠️ EDGE CASE

**Scenario**: User tries to sign in with no network

**Expected Behavior**:
- ✅ Firebase returns network error
- ✅ Error alert shown
- ✅ User can browse heritage recipes offline
- ✅ Sync retries when network returns

**Test Steps**:
1. Disable network on simulator
2. Try signing in
3. Verify error message
4. Enable network
5. Try again

---

### 13. Heritage Recipes Visible Before Auth ✅ CRITICAL

**Scenario**: User explores app without signing in

**Expected Behavior**:
- ✅ 8-12 heritage recipes visible immediately
- ✅ Can view recipe details
- ✅ Can cook recipes (check off ingredients)
- ✅ Can add to shopping cart
- ✅ Can add to meal planning
- ✅ CANNOT share until authenticated

**Test Steps**:
1. Launch app (not authenticated)
2. Browse heritage recipes
3. Open recipe detail
4. Try all features except sharing
5. Verify sharing prompts for auth

---

### 14. Blurhash Progressive Loading ✅ VISUAL

**Scenario**: Recipe images load with blurhash placeholders

**Expected Behavior**:
- ✅ Blurhash placeholder shows immediately (blurred preview)
- ✅ Full image fades in smoothly when loaded
- ✅ No jarring loading states
- ✅ Fallback gradient if no blurhash

**Test Steps**:
1. Browse heritage recipes
2. Observe image loading
3. Verify smooth transitions
4. Check placeholder quality

---

### 15. Account Section UI States ✅ VISUAL

**Scenario**: Settings Account section shows correct state

**Not Authenticated**:
- ✅ Descriptive text: "Sign in to sync your recipes across devices and share with friends"
- ✅ "Sign In" button with icon
- ✅ Footer: "Your recipes are stored locally. Sign in to enable cloud sync and sharing."

**Authenticated**:
- ✅ "Signed in as": user@example.com
- ✅ "User ID": first 8 chars + "..."
- ✅ "Sign Out" button (destructive style)
- ✅ Footer: "Signing out will clear local data. Your recipes are safely stored in Firebase..."

---

## Success Criteria

### Must Pass (Critical)
- [ ] App launches without Firebase crash
- [ ] Heritage recipes visible before auth
- [ ] Sign-in button in Settings works
- [ ] Email/password authentication works
- [ ] Firebase sync starts automatically after login
- [ ] Contextual share prompt works
- [ ] Already-authenticated state detected on launch
- [ ] Sign out clears local data

### Should Pass (Important)
- [ ] Password reset flow works
- [ ] Sign out confirmation dialog works
- [ ] Error messages displayed correctly
- [ ] Blurhash progressive loading works
- [ ] Account section UI states correct

### Nice to Have
- [ ] Apple Sign-In works (device only)
- [ ] Google Sign-In works (device only)
- [ ] Offline error handling graceful

---

## Known Limitations

1. **Simulator**: Apple/Google Sign-In requires actual device with accounts configured
2. **Email Verification**: Firebase email verification not implemented (future enhancement)
3. **Password Strength**: 6-character minimum (Firebase requirement)
4. **Rate Limiting**: Firebase has rate limits on auth attempts

---

## Debug Tools

### Check Logs
```bash
# Real-time app logs
tail -f /tmp/heirloom_debug.log

# Filter for auth events
grep -i "auth\|sync\|firebase" /tmp/heirloom_debug.log

# Check for errors
grep -i "error\|failed\|❌" /tmp/heirloom_debug.log
```

### Firebase Console
- Firestore: https://console.firebase.google.com/project/YOUR_PROJECT/firestore
- Authentication: https://console.firebase.google.com/project/YOUR_PROJECT/authentication
- Storage: https://console.firebase.google.com/project/YOUR_PROJECT/storage

### Simulator Commands
```bash
# Boot simulator
xcrun simctl boot 0BD7A8D6-46BB-41EA-9F64-364DDB9BDD73

# Install app
xcrun simctl install 0BD7A8D6-46BB-41EA-9F64-364DDB9BDD73 /path/to/Heirloom.app

# Launch app
xcrun simctl launch 0BD7A8D6-46BB-41EA-9F64-364DDB9BDD73 com.matthanson.heirloom

# Reset simulator (fresh install)
xcrun simctl erase 0BD7A8D6-46BB-41EA-9F64-364DDB9BDD73
```

---

## Test Execution Log

**Date**: 2026-01-05
**Tester**:
**Build**: Debug-iphonesimulator

| Test Case | Status | Notes |
|-----------|--------|-------|
| 1. First Launch | ⏳ | |
| 2. Settings Sign-In | ⏳ | |
| 3. Email/Password | ⏳ | |
| 4. Firebase Sync | ⏳ | |
| 5. Share Prompt | ⏳ | |
| 6. Auth on Launch | ⏳ | |
| 7. Sign Out | ⏳ | |
| 8. Password Reset | ⏳ | |
| 13. Heritage Recipes | ⏳ | |
| 14. Blurhash Loading | ⏳ | |
| 15. Account UI States | ⏳ | |

---

## Issues Found

*Document any bugs, unexpected behavior, or improvements needed here*

---

## Next Steps After Testing

1. Fix any critical bugs found
2. Create Task 4 plan: Heritage recipe content (67-92 more recipes)
3. Test on actual device (Apple/Google Sign-In)
4. Performance testing with full recipe set
5. Prepare for shipping
