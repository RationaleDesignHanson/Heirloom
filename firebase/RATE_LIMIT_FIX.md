# Rate Limiting Fix - Firestore Permissions for Gen 2 Functions

## Problem
Gen 2 Cloud Functions cannot write to Firestore due to missing IAM permissions.
Error: `7 PERMISSION_DENIED: Missing or insufficient permissions`

## Root Cause
Gen 2 Functions run under the **Compute Engine default service account**, which doesn't have Firestore write permissions by default.

**IMPORTANT**: The service account is `PROJECT_NUMBER-compute@developer.gserviceaccount.com`, NOT the App Engine service account.

## Solution: Grant IAM Permissions

### Option 1: gcloud CLI (Recommended - Fastest)

Run this command (requires gcloud auth):

```bash
# Get your project ID and number
PROJECT_ID="heirloom-ios-prod"
PROJECT_NUMBER="7832275522"

# Grant Firestore permissions to Compute Engine default service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/datastore.user"
```

To find your project number, run: `gcloud projects describe $PROJECT_ID --format="value(projectNumber)"`

### Option 2: Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/project/heirloom-ios-prod/overview)
2. Click **Settings** (gear icon) → **Project settings**
3. Note your **Project number** (e.g., 7832275522)
4. Go to [Google Cloud IAM Console](https://console.cloud.google.com/iam-admin/iam?project=heirloom-ios-prod)
5. Click **+ GRANT ACCESS**
6. Add the service account email: `PROJECT_NUMBER-compute@developer.gserviceaccount.com`
   - For this project: `7832275522-compute@developer.gserviceaccount.com`
7. Assign role: **Cloud Datastore User** (`roles/datastore.user`)
8. Click **Save**

### Option 3: Firestore Security Rules (Alternative)

If IAM approach doesn't work, allow server-side writes in Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Rate limiting collections (server-side only)
    match /rateLimits/{document=**} {
      allow read, write: if request.auth != null;
    }

    match /aiUsage/{document=**} {
      allow read, write: if request.auth != null;
    }

    match /userCosts/{document=**} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow write: if request.auth != null;
    }

    // Your other rules...
  }
}
```

## Verification

After applying the fix, test that rate limiting works:

1. **Re-enable rate limiting** in `ai-gateway.ts` (uncommenting the imports and calls)
2. **Deploy functions**: `firebase deploy --only functions`
3. **Test with multiple AI requests** from the app
4. **Check Firestore** → `rateLimits` collection should have documents
5. **Verify logs**: Firebase Console → Functions → Logs (should see "Rate limit checked" logs)

## Testing Rate Limits

```bash
# Check your current rate limit status
curl -X POST https://checkuserratelimit-PROJECT_ID.cloudfunctions.net/checkUserRateLimit \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"operation":"ai_complete"}'
```

## Rate Limit Configuration

Current limits (in `rate-limiter.ts`):
- **ai_complete**: 100 per day
- **ai_vision**: 50 per day (more expensive)
- **google_vision**: 100 OCR per day
- **brave_search**: 200 searches per day

Adjust these in `rate-limiter.ts` as needed.

## Next Steps

1. ✅ Grant IAM permissions (Option 1 or 2 above)
2. ✅ Uncomment rate limiting code in `ai-gateway.ts`
3. ✅ Deploy functions: `firebase deploy --only functions`
4. ✅ Test with app to verify rate limiting works
5. ✅ Monitor Firestore → `rateLimits` collection for data
