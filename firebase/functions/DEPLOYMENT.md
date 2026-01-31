# Cloud Functions Deployment Guide

## Phase 11: Public Recipe Discovery Functions

### Functions Overview

1. **incrementPublicRecipeView** (HTTP Callable)
   - Atomically increments view count for public recipes
   - Called when user views PublicRecipeDetailView
   - No authentication required (public recipes)

2. **incrementPublicRecipeSave** (HTTP Callable)
   - Atomically increments save count when recipe saved
   - Requires authentication (prevents spam)
   - Called from DiscoveryService.saveToMyRecipes()

3. **calculateTrendingScores** (Scheduled)
   - Runs daily at 2:00 AM UTC
   - Recalculates trending scores for all public recipes
   - Uses weights: views (0.3), saves (5.0), recency boost (0-20)

### Deployment Steps

#### 1. Install Dependencies
```bash
cd firebase/functions
npm install
```

#### 2. Deploy Functions
```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:incrementPublicRecipeView
firebase deploy --only functions:incrementPublicRecipeSave
firebase deploy --only functions:calculateTrendingScores
```

#### 3. Verify Deployment
```bash
# List deployed functions
firebase functions:list

# View function logs
firebase functions:log --only incrementPublicRecipeView
```

### Testing

#### Local Testing (Emulator)
```bash
# Start emulators
firebase emulators:start

# Test callable function
curl -X POST http://localhost:5001/heirloom-ios-prod/us-central1/incrementPublicRecipeView \
  -H "Content-Type: application/json" \
  -d '{"data": {"recipeId": "test-recipe-id"}}'
```

#### Production Testing
```javascript
// From iOS app (Swift)
let functions = Functions.functions()
let incrementView = functions.httpsCallable("incrementPublicRecipeView")

do {
    let result = try await incrementView.call(["recipeId": recipeId])
    let data = result.data as? [String: Any]
    let viewCount = data?["viewCount"] as? Int
    print("New view count: \(viewCount)")
} catch {
    print("Error: \(error)")
}
```

### Monitoring

#### View Logs
```bash
# Real-time logs
firebase functions:log --only incrementPublicRecipeView

# View specific time range
firebase functions:log --only calculateTrendingScores --since 2h
```

#### Set Up Alerts
1. Go to Firebase Console → Functions
2. Click on function name
3. Navigate to "Logs" tab
4. Set up alerting for errors

### Cost Estimation

**incrementPublicRecipeView:**
- Invocations: ~1,000/day (moderate traffic)
- Cost: ~$0.40/month (first 2M free)

**incrementPublicRecipeSave:**
- Invocations: ~200/day (10% save rate)
- Cost: ~$0.08/month

**calculateTrendingScores:**
- Invocations: 1/day
- Processing: ~1,000 recipes × 365 days
- Cost: ~$2/month (batch operations)

**Total estimated: ~$2.50/month for 1,000 public recipes**

### Troubleshooting

#### Function timeout
If trending score calculation times out:
1. Increase timeout in function config (max 540s for scheduled)
2. Batch process in smaller chunks

#### Permission errors
Ensure Firestore rules allow:
- Public read on publicRecipes collection
- Owner-only write on publicRecipes collection

#### Rate limiting
If view counts spike:
- Consider client-side debouncing (track per session)
- Implement rate limiting in function (max 1 view per user per minute)

### Next Steps

After deployment:
1. Update `ServiceContainer` to register callable functions
2. Implement `FirebasePublicRecipeService` with function calls
3. Add analytics tracking for function invocations
4. Monitor error rates in first 48 hours
