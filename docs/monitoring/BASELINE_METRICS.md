# Baseline Metrics - Pre-Production

**Date**: 2026-01-23
**Purpose**: Establish baseline metrics before making production changes

## App Health (To Be Measured)

### Crash Metrics
**Status**: Crashlytics not yet configured

**Post-Configuration Targets**:
- Crash-Free Users %: > 99.5%
- Crashes per 1000 Sessions: < 1
- ANRs (App Not Responding): < 0.01%

**How to Measure**: Firebase Crashlytics dashboard after configuration

---

### Performance Metrics
**Status**: Performance Monitoring not yet configured

**Current Test Results** (from development testing):
| Metric | Device | Current | Target | Status |
|--------|--------|---------|--------|---------|
| App Launch Time | iPhone 15 | ~2-3s | < 2s | ⚠️ Needs optimization |
| Recipe Import (1-page PDF) | iPhone 15 | ~5-10s | < 5s | ⚠️ Depends on AI API |
| Video Processing (1-min) | iPhone 15 | ~30-60s | < 45s | ⚠️ Transcription heavy |
| Firebase Query (recipes list) | - | < 500ms | < 1s | ✅ Good |
| Image Load Time | - | < 2s | < 3s | ✅ Good |

**Note**: These are estimates from development. Actual user metrics will be captured via Firebase Performance Monitoring after configuration.

---

## User Engagement (Mixpanel)

### Current Status
**Analytics**: Mixpanel SDK integrated but needs token configuration

**Events Being Tracked**:
- ✅ App lifecycle (launch, background, foreground)
- ✅ Recipe CRUD operations
- ✅ Collection management
- ✅ Shopping list usage
- ✅ Import/export operations
- ✅ Store & subscriptions
- ✅ AI service usage

**Post-Launch Metrics to Track**:
- Daily Active Users (DAU)
- Monthly Active Users (MAU)
- Retention (D1, D7, D30)
- Recipes created per user
- Recipes imported per user
- Feature adoption rates
- Conversion rate (trial → premium)

---

## Firebase Usage

### Firestore Operations
**Current Usage**: Development/testing only

**Expected Production Load**:
- Read operations: ~100-500 per DAU (recipes, collections, shares)
- Write operations: ~10-50 per DAU (create/update recipes, sync)
- Rule denials: Target < 1% after security fix

**Cost Monitoring**:
- Free tier: 50k reads, 20k writes, 20k deletes per day
- Expected to exceed free tier quickly in production
- Need to monitor costs daily

### Cloud Storage
**Current Usage**: Minimal (development images)

**Expected Production**:
- Recipe images: ~1-3 MB per image
- Video uploads: ~50-200 MB per video
- Storage costs: Monitor monthly

### Authentication
**Current**: Firebase Auth configured and working

**Metrics to Track**:
- Sign-up success rate (target > 95%)
- Sign-in success rate (target > 99%)
- Auth failures (target < 1%)

---

## Security (Firestore Rules)

### Current State
**Status**: ❌ **VULNERABLE** - See `/docs/security/FIRESTORE_RULES_BASELINE.md`

**Critical Issue**: Shares collection allows ANY authenticated user to read/update ANY share

**After Fix (Task #8)**:
- Rule denials baseline: Expect 0-1% (only malicious users)
- Monitor for spike after deployment
- Target: < 1% sustained

---

## Testing

### Test Suite Status
**To Be Established**: Task #5

**Expected Baseline**:
- Total tests: To be counted
- Passing tests: To be measured
- Failing tests: To be documented
- Test coverage: To be measured
- Execution time: To be recorded

**Run**:
```bash
xcodebuild test \
  -project Heirloom.xcodeproj \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## CI/CD

### GitHub Actions
**Current Status**: Tests run on pull requests

**Workflows**:
- `tests.yml`: Runs unit tests on PR
- `videolab-tests.yml`: Video lab specific tests

**Issues**:
- ❌ Deprecated artifact actions (v3 → v4 needed)
- ❌ Manual workflow dispatch not enabled for tests.yml

**Metrics**:
- Build success rate: Target > 95%
- Build time: Target < 10 minutes
- Flaky test rate: Target < 1%

---

## Post-Production Monitoring Checklist

After launch, establish these baselines within:

### Week 1
- [ ] Record DAU/MAU from Mixpanel
- [ ] Measure crash-free users % from Crashlytics
- [ ] Document Firebase read/write costs
- [ ] Record authentication success rate
- [ ] Measure app performance metrics

### Week 2
- [ ] Calculate D1, D7 retention rates
- [ ] Analyze feature adoption rates
- [ ] Document user support request volume
- [ ] Measure conversion rate (trial → premium)

### Month 1
- [ ] Establish D30 retention baseline
- [ ] Document seasonal usage patterns
- [ ] Create performance regression test suite
- [ ] Set up automated cost alerts

---

## Comparison Points

To assess impact of changes, compare against these baselines:

### Deployment Success Criteria
Changes should NOT:
- ❌ Increase crash rate by > 10%
- ❌ Increase Firestore denials by > 2%
- ❌ Decrease DAU by > 5%
- ❌ Increase app launch time by > 20%
- ❌ Decrease authentication success rate by > 1%

### Regression Detection
If any metric degrades significantly:
1. Investigate immediately
2. Correlate with recent deployment
3. Consider rollback if critical
4. Fix and redeploy

---

## Next Steps

1. **Configure Crashlytics** (Task #3 recommendation)
   - Add to project
   - Deploy to TestFlight
   - Verify crash reporting works

2. **Configure Mixpanel** (Task #5.4 recommendation)
   - Add production token
   - Verify events are tracked
   - Create retention funnel

3. **Run Test Suite** (Task #5)
   - Execute full test suite
   - Document passing/failing tests
   - Establish test baseline

4. **Deploy with Monitoring** (Task #8)
   - Fix Firestore rules
   - Monitor rule denials closely
   - Watch for user complaints

---

**Last Updated**: 2026-01-23
**Next Review**: After first production deployment
**Owner**: Matt Hanson
