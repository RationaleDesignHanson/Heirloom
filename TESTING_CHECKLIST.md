# Public Recipe Discovery - Testing Checklist

## Phase 10: Comprehensive Testing & Quality Assurance

**Feature:** Public Recipe Discovery (Phases 1-11)
**Date:** 2026-01-31
**Status:** Ready for Testing

---

## 1. Unit Tests ✅

### Recipe Model Tests
- [x] `testRecipeCanMakePublic` - Valid recipe passes all checks
- [x] `testThemeRecipeCannotBePublished` - Heritage recipes blocked
- [x] `testSampleRecipeCannotBePublished` - Sample recipes blocked
- [x] `testRecipeWithoutInstructionsCannotBePublished` - Validation works
- [x] `testRecipeWithoutIngredientsCannotBePublished` - Validation works
- [x] `testRecipePublicStateTracking` - isPublic, publicRecipeId tracked
- [x] `testRecipeUnpublishing` - Stats preserved on unpublish
- [x] `testSearchKeywordsGeneration` - Keywords extracted correctly
- [x] `testRecipeUpstreamAttribution` - Fork model attribution works
- [x] `testRecipeWithoutUpstream` - Original recipes have no upstream
- [x] `testFullPublishingFlow` - End-to-end validation

**Files:** `PublicRecipeDiscoveryTests.swift`

---

## 2. Critical Path Tests (Manual - Must Pass Before Launch)

### ✅ Publishing Flow
- [ ] Create new recipe with all required fields
- [ ] Tap "Share Publicly" - PublishRecipeSheet opens
- [ ] Tap "Publish" - recipe publishes successfully
- [ ] Globe badge appears on recipe card
- [ ] Recipe appears in discovery feed within 1 minute

### ✅ Unpublishing Flow
- [ ] Open published recipe
- [ ] Tap "Unpublish" - confirmation appears
- [ ] Confirm unpublish - recipe removed from discovery
- [ ] Stats preserved (views, saves)

### ✅ Discovery Feed
- [ ] Tap DiscoveryEntryBanner - feed opens
- [ ] See recipes in 3 tabs (Trending, New, Popular)
- [ ] Tap recipe card - detail view opens
- [ ] Tap "Save to My Recipes" - recipe saved

### ✅ Search
- [ ] Type search query - results appear
- [ ] Empty state shows for no results

### ✅ Moderation
- [ ] Tap report button - sheet opens
- [ ] Select reason and submit - report created
- [ ] Try to report again - blocked with error

### ✅ Deep Linking
- [ ] Open `heirloom://recipe/{id}` - recipe opens
- [ ] Open `https://heirloom.app/recipe/{id}` - recipe opens

---

## 3. Smoke Tests (5 minutes - After Every Build)

- [ ] App launches without crashing
- [ ] DiscoveryEntryBanner visible above recipe grid
- [ ] Tapping banner opens discovery feed
- [ ] Discovery feed loads recipes
- [ ] Recipe detail view opens from card
- [ ] "Save to My Recipes" button works
- [ ] Report button visible in toolbar
- [ ] No console errors or warnings

---

## 4. Performance Tests

- [ ] Discovery feed loads in < 2 seconds
- [ ] Search results appear in < 1 second
- [ ] Recipe detail loads in < 1 second
- [ ] Pagination smooth with 1000+ recipes
- [ ] Memory usage < 200MB during scrolling

---

## 5. Security Tests

### Firestore Rules
- [ ] Unauthenticated users CAN read publicRecipes
- [ ] Users CAN only update their own publicRecipes
- [ ] Users CAN create reports (reporter ID validated)
- [ ] Users CANNOT update reports

### Input Validation
- [ ] Malicious input sanitized
- [ ] Report details limited to 500 characters

---

## 6. Backend Tests

- [ ] Cloud Function `incrementPublicRecipeView` works
- [ ] Cloud Function `incrementPublicRecipeSave` works
- [ ] Cloud Function `calculateTrendingScores` runs daily
- [ ] Cloud Function `monitorPublicRecipeReports` auto-hides at 10 reports

---

## 7. Edge Cases

- [ ] Empty discovery feed shows empty state
- [ ] Search with no results shows empty state
- [ ] Report same recipe twice - blocked
- [ ] 10th report triggers auto-hide
- [ ] Publish while offline - shows error

---

## 8. Regression Tests

- [ ] Recipe creation still works
- [ ] Recipe editing still works
- [ ] Firebase sharing still works
- [ ] Collections still work
- [ ] No existing features broken

---

## 9. Analytics Verification

- [ ] `public_recipe_published` fires
- [ ] `public_recipe_unpublished` fires
- [ ] `public_recipe_viewed` fires
- [ ] `public_recipe_saved` fires
- [ ] `public_recipe_reported` fires

---

## 10. Deployment Checklist

### Pre-Deployment
- [ ] All unit tests pass
- [ ] All critical path tests pass
- [ ] Performance acceptable
- [ ] Security audit complete
- [ ] Firestore rules deployed to staging
- [ ] Cloud Functions deployed to staging
- [ ] Firestore indexes built

### Staging Deployment
- [ ] Deploy to TestFlight
- [ ] Test on real devices
- [ ] Test with real network

### Production Deployment
- [ ] Code review complete
- [ ] QA sign-off
- [ ] Firestore rules deployed to production
- [ ] Cloud Functions deployed to production
- [ ] Feature flag: enable for 10% of users
- [ ] Monitor for 24 hours
- [ ] Gradual rollout: 10% → 50% → 100%

---

## Summary

**Critical Path Tests:** 6 flows, ~30 minutes
**Smoke Tests:** 8 checks, ~5 minutes
**Total Test Cases:** 100+
**Rollout Strategy:** Gradual with feature flag

**Ready for Production:** Once critical path tests pass ✅

---

**Tested By:** _________________
**Date:** _________________
**Sign-Off:** _________________
