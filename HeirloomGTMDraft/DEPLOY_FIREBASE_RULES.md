# Deploy Firebase Rules

## Overview
The Firebase Security Rules have been updated to support:
1. Recipe sharing with images (fixes "missing or insufficient permissions" error)
2. Heirloom recipe lineage tracking (family tree and modification history)

## What Changed

### Storage Rules (`backend/storage.rules`)
- **Added**: User recipe images path `/users/{userId}/recipes/{recipeId}/{imageFile}`
  - Authenticated users can read (for sharing)
  - Only owner can write/delete

### Firestore Rules (`firestore.rules`)
- **Added**: User lineages collection `/users/{userId}/lineages/{lineageId}`
  - User can read/write their own lineage records
- **Added**: Global lineages index `/lineages/{lineageId}`
  - Authenticated users can read (for ancestor tracking)
  - Only owner can create/update/delete their records
- **Added**: User notifications collection `/users/{userId}/notifications/{notificationId}`
  - User can read/update/delete their own notifications

## Deployment Instructions

### Option 1: Firebase Console (Recommended)

**Firestore Rules:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `heirloom-app`
3. Navigate to **Firestore Database** → **Rules** tab
4. Copy the entire contents of `/Users/matthanson/Heirloom/firestore.rules`
5. Paste into the editor
6. Click **Publish**

**Storage Rules:**
1. In Firebase Console, navigate to **Storage** → **Rules** tab
2. Copy the entire contents of `/Users/matthanson/Heirloom/backend/storage.rules`
3. Paste into the editor
4. Click **Publish**

### Option 2: Firebase CLI

```bash
# From project root
cd /Users/matthanson/Heirloom

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage

# Or deploy both at once
firebase deploy --only firestore:rules,storage
```

## Testing After Deployment

1. **Share a recipe with an image** from Device A
2. **Accept the share** on Device B
3. **Verify**:
   - ✅ Recipe appears with image
   - ✅ No permission errors in console
   - ✅ Preview shows correctly before accepting

## Rollback (if needed)

If something goes wrong, you can rollback in the Firebase Console:
1. Go to **Firestore/Storage** → **Rules** tab
2. Click the **History** button at the top
3. Select a previous version
4. Click **Restore**

## Critical Paths Fixed

### Before (Broken):
- `users/{userId}/recipes/{recipeId}/image.jpg` → **NO RULE** → Default DENY ❌

### After (Fixed):
- `users/{userId}/recipes/{recipeId}/image.jpg` → **Matches new rule** → Authenticated users can read, owner can write ✅

## Notes

- Rules take effect immediately after deployment
- No app rebuild required
- Users may need to restart the app to clear any cached permission errors
- Test in development environment first if available
