# Firestore Security Rules Deployment

## Quick Deploy (Firebase Console)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your Heirloom project
3. Navigate to **Firestore Database** → **Rules** tab
4. Copy the contents of `/Users/matthanson/Heirloom/firestore.rules`
5. Paste into the rules editor
6. Click **Publish**

## Or Deploy via Firebase CLI

```bash
cd /Users/matthanson/Heirloom
firebase deploy --only firestore:rules
```

## What These Rules Do

### ✅ Shares Collection (Public Read, Authenticated Write)
- **Anyone** can read shares (needed for share link acceptance)
- **Authenticated users** can create shares
- **Only owners** can update/delete their shares

### ✅ User Recipes (Authenticated Access)
- All authenticated users can read recipes (for importing shared recipes)
- Only the owner can write to their own recipes
- Includes subcollections: ingredients, comments, cardBack

### ✅ User Collections, Tags, Shopping Cart, Dinner Parties
- Only the owner can read/write their own data

### ❌ Everything Else
- Denied by default (secure by default)

## Testing After Deployment

1. **Verify Rules Active**:
   - Open Firestore Console → Rules tab
   - Check "Last updated" timestamp

2. **Test Share Creation**:
   ```
   Open app → Scan/Import recipe → Share button
   Should succeed without "insufficient permissions" error
   ```

3. **Test Share Acceptance**:
   ```
   Device A: Create share link
   Device B: Accept share link
   Should import recipe successfully
   ```

## Troubleshooting

### "Missing or insufficient permissions" Error

**Cause**: Rules not deployed or Firebase Auth not working

**Fix**:
1. Check Firestore Rules are deployed (last updated timestamp)
2. Verify user is authenticated: Check console for "🔐 [Firebase] User signed in: {uid}"
3. Check Firebase Auth is configured in Firebase Console

### "Permission denied" for Shares

**Cause**: User not authenticated

**Fix**:
- Firebase Auth should auto-sign in anonymously
- Check `FirebaseAuthService` is initialized
- Verify `Auth.auth().signInAnonymously()` is called

## Security Notes

- Shares are **public read** by design (needed for share links to work)
- All write operations require authentication
- Users can only modify their own data
- Share acceptance requires authentication (prevents anonymous abuse)
