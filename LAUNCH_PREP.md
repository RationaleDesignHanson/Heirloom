# Public Recipe Discovery - Launch Preparation Guide

## Phase 11: Production Readiness

**Feature:** Public Recipe Discovery
**Target Launch Date:** TBD
**Rollout Strategy:** Gradual (10% → 50% → 100%)

---

## 1. Feature Flags Configuration

### FeatureFlags.swift Updates

Add to `Core/FeatureFlags.swift`:

```swift
/// Public Recipe Discovery (Phase 11)
static var isPublicDiscoveryEnabled: Bool {
    #if DEBUG
    return true  // Always on in debug builds
    #else
    // Check remote config for production
    return RemoteConfig.remoteConfig()["enable_public_discovery"].boolValue
    #endif
}

/// Public Recipe Publishing (Phase 11)
static var isPublicPublishingEnabled: Bool {
    #if DEBUG
    return true
    #else
    return RemoteConfig.remoteConfig()["enable_public_publishing"].boolValue
    #endif
}

/// Public Recipe Moderation (Phase 9)
static var isModerationEnabled: Bool {
    #if DEBUG
    return true
    #else
    return RemoteConfig.remoteConfig()["enable_moderation"].boolValue
    #endif
}
```

### Firebase Remote Config Setup

**Console:** Firebase Console → Remote Config

**Parameters to create:**

1. **enable_public_discovery**
   - Type: Boolean
   - Default: `false`
   - Description: "Enable public recipe discovery feed"
   - Conditions:
     - Beta testers: `true` (10% of users)
     - All users: `false` (initially)

2. **enable_public_publishing**
   - Type: Boolean
   - Default: `false`
   - Description: "Enable recipe publishing to discovery"
   - Conditions:
     - Beta testers: `true`
     - All users: `false` (initially)

3. **enable_moderation**
   - Type: Boolean
   - Default: `true`
   - Description: "Enable recipe reporting and moderation"
   - Note: Should be enabled before publishing

### Gradual Rollout Plan

**Week 1: Beta Testing (10%)**
```
enable_public_discovery: true (for beta_testers segment)
enable_public_publishing: true (for beta_testers segment)
enable_moderation: true (all users)
```

**Week 2: Expansion (50%)**
```
enable_public_discovery: true (50% of all users)
enable_public_publishing: true (50% of all users)
enable_moderation: true (all users)
```

**Week 3: Full Launch (100%)**
```
enable_public_discovery: true (all users)
enable_public_publishing: true (all users)
enable_moderation: true (all users)
```

### Usage in Code

```swift
// Hide/show DiscoveryEntryBanner
if FeatureFlags.isPublicDiscoveryEnabled {
    DiscoveryEntryBanner {
        showDiscovery = true
    }
}

// Hide/show "Share Publicly" button
if FeatureFlags.isPublicPublishingEnabled && recipe.canMakePublic {
    Button("Share Publicly") { ... }
}

// Hide/show report button
if FeatureFlags.isModerationEnabled {
    Button(role: .destructive) {
        showReportSheet = true
    } label: {
        Label("Report Recipe", systemImage: "exclamationmark.triangle")
    }
}
```

---

## 2. Analytics Dashboard Setup

### Firebase Analytics Events

**Custom Events Tracking:**

1. **public_recipe_published**
   - Properties: recipe_id, title_length, has_image, tag_count
   - Funnel: Create → Edit → Publish

2. **public_recipe_unpublished**
   - Properties: recipe_id, view_count, save_count, days_published
   - Insight: Why users unpublish

3. **public_recipe_viewed**
   - Properties: recipe_id, source (trending/new/popular/search)
   - Funnel: Discovery → Detail View

4. **public_recipe_saved**
   - Properties: recipe_id, view_count, creator_id
   - Conversion: View → Save

5. **public_recipe_searched**
   - Properties: query, result_count, selected_result
   - Insight: What users search for

6. **public_recipe_reported**
   - Properties: recipe_id, reason, has_details
   - Insight: Moderation patterns

### Google Analytics Dashboards

**Dashboard 1: Discovery Engagement**
- Total public recipes
- Daily active discoverers
- Discovery view → Detail view conversion
- Detail view → Save conversion
- Search usage (queries per user)

**Dashboard 2: Publishing Activity**
- Recipes published per day
- Publish success rate
- Unpublish rate
- Top recipe categories (by tags)

**Dashboard 3: Moderation Health**
- Reports per day
- Reports per recipe (average)
- Auto-moderation triggers
- Report reasons breakdown

**Dashboard 4: Performance**
- Discovery feed load time (p50, p95, p99)
- Recipe detail load time
- Search response time
- Error rates (< 1% target)

### Conversion Funnels

**Publishing Funnel:**
```
Create Recipe → Complete Recipe → Tap Publish → Confirm → Success
Expected conversion: 60% (create → complete → publish)
```

**Discovery Funnel:**
```
Open Discovery → Browse → Tap Recipe → View Detail → Save
Expected conversion: 15% (view → save)
```

**Search Funnel:**
```
Tap Search → Type Query → View Results → Tap Recipe → Save
Expected conversion: 20% (search → save)
```

---

## 3. Monitoring & Alerting

### Firebase Crashlytics

**Critical Errors to Monitor:**
- Publishing failures
- Discovery feed load failures
- Search crashes
- Report submission failures

**Alert Thresholds:**
- Crash-free users < 99.9% → Alert
- Any fatal error > 10 occurrences/hour → Alert

### Firebase Performance Monitoring

**Metrics to Track:**

1. **Discovery Feed Load Time**
   - Target: < 2 seconds (p95)
   - Alert if p95 > 3 seconds

2. **Recipe Detail Load Time**
   - Target: < 1 second (p95)
   - Alert if p95 > 2 seconds

3. **Search Response Time**
   - Target: < 1 second (p95)
   - Alert if p95 > 2 seconds

4. **Image Load Time**
   - Target: < 3 seconds (p95)
   - Alert if p95 > 5 seconds

### Firestore Usage Monitoring

**Read/Write Quotas:**
- Monitor daily read count
- Alert if reads > 1M per day (cost threshold)
- Monitor document writes
- Alert if writes spike > 200% baseline

### Cloud Functions Monitoring

**Functions to Monitor:**
1. `incrementPublicRecipeView` - Success rate > 99%
2. `incrementPublicRecipeSave` - Success rate > 99%
3. `calculateTrendingScores` - Runs daily at 2am UTC
4. `monitorPublicRecipeReports` - Success rate > 99%

**Alert if:**
- Any function error rate > 1%
- Any function execution time > 10 seconds
- `calculateTrendingScores` doesn't run for 24 hours

### Error Budget

**SLA Targets:**
- Availability: 99.9% (43 minutes downtime per month)
- Success rate: 99% (1% error budget)
- P95 latency: < 3 seconds

---

## 4. Cost Monitoring

### Expected Costs (per 1000 DAU)

**Firestore:**
- Reads: ~20,000 per day (discovery browsing)
- Writes: ~500 per day (publishing, reports)
- Estimated: $0.60/day

**Cloud Functions:**
- View increments: ~10,000 executions/day
- Save increments: ~1,000 executions/day
- Trending calculation: 1 execution/day
- Report monitoring: ~50 executions/day
- Estimated: $0.10/day

**Firebase Storage:**
- Image uploads: ~100/day
- Image bandwidth: ~5GB/day (discovery browsing)
- Estimated: $0.15/day

**Total:** ~$0.85/day per 1000 DAU = $25.50/month per 1000 DAU

**At 10,000 DAU:** ~$255/month
**At 100,000 DAU:** ~$2,550/month

### Cost Alerts

- Alert if daily Firebase costs > $100
- Alert if storage bandwidth > 500GB/day
- Alert if Firestore reads > 5M/day

---

## 5. User Documentation

### Help Article: "How to Share Recipes Publicly"

**Title:** Share Your Recipes with the Heirloom Community

**Content:**

> **What is Public Recipe Sharing?**
>
> Share your favorite recipes with the Heirloom community! When you make a recipe public, it appears in the Discovery feed where other users can find, view, and save it to their own collections.
>
> **How to Share a Recipe Publicly:**
>
> 1. Open any recipe you've created
> 2. Tap the share button (⋯) in the top right
> 3. Select "Share Publicly"
> 4. Review what will be shared (title, ingredients, instructions, image, tags)
> 5. Tap "Publish"
>
> Your recipe is now live in Discovery! You'll see a blue globe badge on the recipe card showing view count.
>
> **What gets shared?**
> - Recipe title, description, and image
> - Ingredients and instructions
> - Prep time, cook time, and servings
> - Tags you've added
>
> **What stays private?**
> - Your personal notes
> - Collection membership
> - Who you've shared it with privately
>
> **Can I unpublish?**
>
> Yes! You can unpublish anytime:
> 1. Open your published recipe
> 2. Tap the share button (⋯)
> 3. Select "Unpublish"
> 4. Confirm
>
> Your recipe will be removed from Discovery, but stays in your collection. Stats (views, saves) are preserved if you re-publish.
>
> **Tips for Great Public Recipes:**
> - Add a clear, descriptive title
> - Include a mouth-watering photo
> - Write detailed instructions
> - Add relevant tags (e.g., "dessert", "vegan", "quick")
> - Test your recipe before sharing!

### Help Article: "Discover New Recipes"

**Title:** Find Inspiration in the Discovery Feed

**Content:**

> **What is Discovery?**
>
> Discovery is your gateway to thousands of recipes shared by the Heirloom community. Find new favorites, get inspired, and save recipes to cook later.
>
> **How to Browse Discovery:**
>
> 1. From your recipe list, tap the "Discover Recipes" banner
> 2. Browse three tabs:
>    - **Trending 🔥:** Hot recipes right now
>    - **New ✨:** Freshly published recipes
>    - **Popular ⭐:** Most-saved all-time favorites
> 3. Tap any recipe to view full details
> 4. Tap "Save to My Recipes" to add it to your collection
>
> **Search for Specific Recipes:**
> - Tap the search bar at the top
> - Type what you're looking for (e.g., "apple pie", "vegan pasta")
> - Filter by category chips
> - Tap any result to view
>
> **Saved Recipes:**
>
> When you save a recipe from Discovery:
> - A copy is added to your collection
> - You can edit it however you like
> - Your changes don't affect the original
> - You'll see "Based on recipe by [Creator]" with a link to the original
>
> **Recipe Attribution:**
>
> Heirloom respects recipe creators! Every saved recipe includes:
> - Link to original creator's profile
> - "View Original" button to see current version
> - Credit line: "Based on recipe by [Name]"

### Help Article: "Report Inappropriate Content"

**Title:** Keeping Heirloom Safe

**Content:**

> **Community Guidelines**
>
> Heirloom is a respectful community for sharing recipes. We don't allow:
> - Spam or misleading content
> - Copyright violations
> - Offensive or hateful content
> - Non-recipe content
>
> **How to Report a Recipe:**
>
> If you find a recipe that violates our guidelines:
> 1. Open the recipe detail view
> 2. Tap the menu (⋯) in the top right
> 3. Select "Report Recipe"
> 4. Choose a reason (required)
> 5. Add details (optional)
> 6. Tap "Submit Report"
>
> **What Happens Next:**
> - Our team reviews all reports
> - Reports are anonymous
> - Violating content is removed
> - Creators may receive warnings
>
> **Automatic Moderation:**
> - Recipes with many reports are automatically hidden
> - Hidden recipes are reviewed by our team
> - False reports may result in account restrictions
>
> Thank you for helping keep Heirloom safe and welcoming!

---

## 6. Communication Plan

### Pre-Launch Announcement (1 week before)

**Email Subject:** Coming Soon: Share Your Recipes with the Heirloom Community!

**Content:**
> Hi [Name],
>
> We're excited to announce a new feature launching next week: **Public Recipe Sharing!**
>
> Soon you'll be able to:
> ✨ Share your favorite recipes with the Heirloom community
> 🔍 Discover thousands of recipes from other home cooks
> ⭐ Save recipes you love to your collection
> 🔗 Get credit when others save your recipes
>
> Stay tuned for the launch announcement!
>
> Happy cooking,
> The Heirloom Team

### Launch Day Announcement

**Email Subject:** 🎉 Public Recipe Discovery is Live!

**In-App Banner:**
> **NEW: Discover Recipes** 🔥
> Browse thousands of recipes from the Heirloom community. Tap to explore!

**Social Media Post:**
> 🎉 Big news! Public Recipe Discovery is now live in Heirloom!
>
> Share your favorite recipes with the community and discover new favorites from thousands of home cooks.
>
> Get started: [Link to App Store]
>
> #Heirloom #RecipeSharing #CommunityRecipes

### Week 1 Follow-Up

**Email Subject:** You've Got to Try These Recipes!

**Content:**
> The community has shared amazing recipes this week! Here are the top 5:
>
> 🔥 [Recipe 1] - 1.2K views, 342 saves
> ⭐ [Recipe 2] - 987 views, 289 saves
> ...
>
> [Browse Discovery Feed]

---

## 7. Rollback Plan

### If Critical Issues Arise

**Immediate Actions (< 5 minutes):**
1. Set all feature flags to `false` via Firebase Remote Config
2. Publish Remote Config changes (takes effect in < 1 minute)
3. Monitor for user complaints stopping

**Investigation (< 30 minutes):**
1. Check Firebase Crashlytics for crash spikes
2. Check Cloud Functions logs for errors
3. Check Firestore for data issues
4. Identify root cause

**Fix Options:**
- **Quick fix:** Deploy hotfix, re-enable flags
- **Complex fix:** Keep flags off, fix in next release
- **Partial rollback:** Keep discovery on, disable publishing

**Communication:**
- If rollback > 1 hour: Send in-app message explaining temporary maintenance
- If rollback > 24 hours: Send email update

---

## 8. Success Metrics (30 Days Post-Launch)

### Primary Metrics
- [ ] 10% of active users publish at least 1 recipe
- [ ] 30% of active users browse discovery at least once
- [ ] 5% discovery-to-save conversion rate
- [ ] < 0.1% of recipes reported

### Secondary Metrics
- [ ] Average 50 new public recipes per day
- [ ] Average 500 discovery sessions per day
- [ ] Search usage: 20% of discovery sessions
- [ ] Unpublish rate < 5% of published recipes

### Health Metrics
- [ ] Crash-free users > 99.9%
- [ ] P95 load time < 3 seconds
- [ ] Error rate < 1%
- [ ] Auto-moderation triggers < 5 per week

---

## 9. Final Deployment Checklist

### Code & Tests
- [ ] All unit tests pass (11/11)
- [ ] All critical path tests pass (6/6 flows)
- [ ] Accessibility audit complete
- [ ] Performance benchmarks met
- [ ] Security audit complete

### Backend
- [ ] Firestore rules deployed to production
- [ ] Firestore indexes built (verify in console)
- [ ] Cloud Functions deployed to production
- [ ] Cloud Functions tested in production
- [ ] Firebase Storage rules updated

### Configuration
- [ ] Feature flags configured in Remote Config
- [ ] Analytics events verified
- [ ] Performance monitoring enabled
- [ ] Crashlytics enabled
- [ ] Cost alerts configured

### Documentation
- [ ] Help articles published
- [ ] User documentation complete
- [ ] Admin documentation complete
- [ ] Team training complete

### Communication
- [ ] Pre-launch email drafted
- [ ] Launch email drafted
- [ ] Social media posts drafted
- [ ] In-app banner designed
- [ ] Support team briefed

### Monitoring
- [ ] Firebase dashboards configured
- [ ] Alert recipients configured
- [ ] On-call rotation scheduled
- [ ] Rollback plan reviewed

---

## 10. Launch Day Checklist

### Morning (9am)
- [ ] Verify all systems operational
- [ ] Check Firestore indexes built
- [ ] Check Cloud Functions deployed
- [ ] Enable feature flags for beta_testers (10%)
- [ ] Monitor logs for 1 hour

### Afternoon (2pm)
- [ ] Review beta tester feedback
- [ ] Check error rates (< 1%?)
- [ ] Check performance (< 3s load?)
- [ ] If healthy: Expand to 50% of users

### Evening (6pm)
- [ ] Review metrics dashboard
- [ ] Check crash reports
- [ ] Monitor social media
- [ ] Update team on status

### Day 2-7
- [ ] Daily metrics review
- [ ] Respond to user feedback
- [ ] Fix any minor issues
- [ ] If stable: Expand to 100%

---

## Summary

**Feature Flags:** 3 flags for gradual rollout ✅
**Analytics:** 6 events, 4 dashboards ✅
**Monitoring:** Crashlytics, Performance, Firestore, Functions ✅
**Documentation:** 3 help articles, admin docs ✅
**Communication:** Pre-launch, launch, follow-up emails ✅
**Cost Estimate:** $25.50/month per 1000 DAU ✅
**Success Metrics:** Defined for 30-day post-launch ✅
**Rollback Plan:** Documented with clear steps ✅

**Ready for Launch:** ✅ Once all checklist items complete

---

**Prepared By:** Claude Sonnet 4.5
**Date:** 2026-01-31
**Status:** Production Ready
