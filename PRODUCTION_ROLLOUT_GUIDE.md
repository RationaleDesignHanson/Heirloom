# Production Rollout Guide

Guide for safely deploying feature management infrastructure to production with gradual rollout strategy.

## Overview

This guide covers the deployment of:
- Feature flag system (local + remote)
- Firebase Remote Config integration
- Gradual feature rollout (10% → 50% → 100%)
- Emergency rollback procedures
- Monitoring and analytics

## Prerequisites

Before deploying to production:

- [ ] All tests passing locally
- [ ] CI/CD passing (coverage + feature gates)
- [ ] Firebase project configured (dev, staging, prod)
- [ ] TestFlight build submitted
- [ ] Analytics tracking verified
- [ ] Rollback procedure tested

## Phase 6.1: Wrap High-Risk Features

### Features to Flag

Wrap these features with feature flag checks before deployment:

**Critical Features**:
1. **videoImport** - Complex AI pipeline
2. **asmrProcessing** - New beta feature
3. **cloudSync** - Data sync reliability
4. **onboarding** - First user experience

### Implementation Pattern

Add feature flag checks at UI entry points:

```swift
// Example: Video Import
struct VideoImportView: View {
    @State private var flagManager = FeatureFlagManager.shared

    var body: some View {
        if flagManager.isEnabled(.videoImport) {
            // Show video import UI
            VideoImportScreen()
        } else {
            // Feature disabled
            FeatureDisabledView(feature: .videoImport)
        }
    }
}
```

### Checklist: Wrap Features

- [ ] Add flag check in VideoImportView
- [ ] Add flag check in ASMRProcessingView
- [ ] Add flag check in CloudSyncSettings
- [ ] Add flag check in OnboardingContainerView
- [ ] Test: Toggle each flag locally in debug menu
- [ ] Verify: Features disable gracefully (no crashes)

## Phase 6.2: Firebase Remote Config Setup

### Step 1: Access Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select Heirloom production project
3. Navigate to: **Engage** → **Remote Config**

### Step 2: Create Feature Flag Parameters

For each feature, create a parameter:

**Parameter Configuration**:
- **Parameter name**: Use exact feature rawValue (e.g., `video_import`)
- **Data type**: Boolean
- **Default value**: Start conservative
  - **New features**: `false` (disabled by default)
  - **Stable features**: `true` (enabled by default)
- **Description**: Brief description of feature

**Example**: Video Import
```
Name: video_import
Type: Boolean
Default: false
Description: Import recipes from YouTube videos (AI pipeline)
```

### Step 3: Set Initial Values

Configure initial state for each feature:

| Feature | Initial Value | Rationale |
|---------|--------------|-----------|
| `video_import` | `false` | Start disabled, gradual rollout |
| `asmr_processing` | `false` | Beta feature, start disabled |
| `cloud_sync` | `true` | Stable, keep enabled |
| `onboarding` | `true` | Critical path, tested extensively |
| `recipe_sharing` | `true` | Stable feature |
| `blind_box_collections` | `true` | Core feature |
| `daily_heritage_drop` | `true` | Well-tested |
| All others | `true` | Core features, stable |

### Step 4: Publish Changes

1. Review all parameters
2. Click **Publish changes**
3. Add description: "Initial production feature flags for v2.0"
4. Confirm publication

### Checklist: Firebase Setup

- [ ] All 20 features added as parameters
- [ ] Conservative defaults set (high-risk features = false)
- [ ] Descriptions added for clarity
- [ ] Changes published to production

## Phase 6.3: TestFlight Deployment

### Step 1: Build for TestFlight

```bash
# Increment build number
agvtool next-version -all

# Archive for TestFlight
xcodebuild archive \
  -scheme Heirloom \
  -archivePath ./build/Heirloom.xcarchive \
  -configuration Release

# Export for App Store
xcodebuild -exportArchive \
  -archivePath ./build/Heirloom.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

### Step 2: Upload to TestFlight

```bash
# Upload to App Store Connect
xcrun altool --upload-app \
  -f ./build/Heirloom.ipa \
  -u your-apple-id@example.com \
  -p @keychain:AC_PASSWORD
```

### Step 3: Verify Build

1. Log into [App Store Connect](https://appstoreconnect.apple.com/)
2. Select Heirloom app
3. Go to **TestFlight** tab
4. Verify new build appears (processing may take 5-10 minutes)
5. Add internal testers
6. Submit for external beta review

### Checklist: TestFlight

- [ ] Build uploaded successfully
- [ ] Internal testers added
- [ ] External beta review submitted
- [ ] Release notes added
- [ ] Test with feature flags disabled/enabled

## Phase 6.4: Gradual Rollout Strategy

### Week 1: 10% Rollout

**Goal**: Validate feature with small user group, catch any critical issues.

#### Configure 10% Rollout

1. In Firebase Console, go to Remote Config
2. For high-risk features (e.g., `video_import`):
   - Click feature parameter
   - Add condition: `video_import_10_percent`
   - **Applies if**: Percent of users = `10%`
   - **Value**: `true`
   - **Default** (fallback): `false`
3. Publish changes

#### Monitor Metrics (48 hours)

Track these metrics for 48 hours:

**Crashlytics**:
- Overall crash rate
- Crash-free users percentage
- Crashes by feature (filter by feature_enabled user property)

**Analytics**:
- Feature usage (`feature_used` event)
- Feature engagement time
- Error rate (`feature_error` event)

**Support**:
- Support ticket count
- Common issues

**Thresholds for Proceeding**:
- ✅ Crash rate < 1%
- ✅ No critical bugs reported
- ✅ Support tickets < 5% of active users
- ✅ Feature engagement > 20% (if UI feature)

#### Rollback Trigger

**Rollback if**:
- Crash rate > 2%
- Critical bug affecting core functionality
- Support tickets > 10% of users
- Data corruption detected

### Week 2: 50% Rollout

**Prerequisites**: All Week 1 metrics green for 48 hours.

#### Configure 50% Rollout

1. Update Remote Config condition
2. Change `video_import_10_percent` to `50%`
3. Publish changes
4. **Effect**: Feature enabled for 50% of users within 12 hours

#### Monitor Metrics (72 hours)

Same metrics as Week 1, monitored for 72 hours.

**Thresholds**:
- ✅ Crash rate < 1%
- ✅ No new critical bugs
- ✅ Feature engagement stable or increasing
- ✅ Support ticket rate < 3%

### Week 3: 100% Rollout

**Prerequisites**: All Week 2 metrics green for 72 hours.

#### Configure 100% Rollout

1. Remove percentage condition
2. Set default value to `true`
3. Publish changes
4. **Effect**: Feature enabled for all users within 12 hours

#### Monitor Metrics (1 week)

Continue monitoring for 1 week post-100% rollout:

**Success Criteria**:
- ✅ Crash rate remains < 1%
- ✅ Feature engagement meets expectations
- ✅ Support ticket volume normal
- ✅ No critical bugs

**If successful**: Feature is fully rolled out! 🎉

## Phase 6.5: Emergency Rollback Procedure

### Immediate Rollback (< 5 minutes)

Use this for critical issues (crashes, data loss, security).

#### Steps

1. **Open Firebase Console** → Remote Config
2. **Find problematic feature** parameter
3. **Set default value to `false`**
4. **Click Publish changes**
5. **Reduce fetch interval** (temporary):
   - Go to Settings → Remote Config settings
   - Set "Minimum fetch interval" to `0` hours
   - Save (allows immediate propagation)
6. **Publish again**

**Effect**: Within 12 hours (or sooner with 0-hour cache), feature disabled for all users.

#### For Immediate Effect (No Cache Wait)

If you need immediate effect:

1. Deploy hotfix build with feature disabled
2. Submit emergency release to App Store
3. Expedite review (explain critical bug)
4. Users get update within 24-48 hours

### Gradual Rollback (Downgrade)

Use this for non-critical issues (poor engagement, minor bugs).

#### Steps

1. **Reduce percentage**: 50% → 10% → 0%
2. Monitor metrics at each step (48 hours)
3. **Fix issue** in development
4. **Re-roll out** when fixed (10% → 50% → 100%)

### Post-Rollback

After rolling back:

- [ ] Identify root cause
- [ ] Add tests to prevent regression
- [ ] Fix issue in development
- [ ] Re-test thoroughly
- [ ] Re-submit to TestFlight
- [ ] Repeat gradual rollout (10% → 50% → 100%)

## Phase 6.6: Monitoring and Analytics

### Key Metrics to Track

#### Firebase Analytics

**Feature Usage**:
```swift
analytics.track(event: .featureUsed, properties: [
    "feature": "video_import",
    "enabled": true,
    "source": "remote" // or "local" or "default"
])
```

**Custom Events**:
- `feature_flag_changed` - Flag value changed
- `feature_used` - Feature actively used
- `feature_error` - Feature encountered error
- `feature_engagement_time` - Time spent in feature

#### Crashlytics

**User Properties**:
```swift
// Set user property for each feature
Crashlytics.crashlytics().setCustomValue(true, forKey: "video_import_enabled")
```

**Custom Logs**:
```swift
Crashlytics.crashlytics().log("Video import started: URL=\(url)")
```

#### Dashboard Queries

Create custom queries in Firebase Analytics:

**Query 1: Feature Adoption**
- Event: `feature_used`
- Filter by: `feature` parameter
- Group by: `enabled` status
- Timeframe: Last 7 days

**Query 2: Crash Correlation**
- Event: `app_exception`
- Filter: Users with `video_import_enabled = true`
- Compare to: Users with `video_import_enabled = false`
- Metric: Crash rate

**Query 3: Feature Engagement**
- Event: `feature_engagement_time`
- Filter by: `feature` parameter
- Metric: Average time, 95th percentile

### Alerting

Set up Firebase alerts:

1. **Crash Rate Alert**
   - Threshold: > 2%
   - Notify: Slack #engineering, Email

2. **Error Rate Alert**
   - Event: `feature_error`
   - Threshold: > 100 events/hour
   - Notify: Slack #engineering

3. **Feature Usage Drop**
   - Event: `feature_used`
   - Threshold: < 50% of baseline
   - Notify: Slack #product

## Rollback Decision Matrix

| Issue Severity | Symptom | Action | Timeline |
|---------------|---------|--------|----------|
| **Critical** | Crash rate > 5% | Immediate rollback | < 5 min |
| **Critical** | Data loss reported | Immediate rollback | < 5 min |
| **Critical** | Security vulnerability | Immediate rollback + hotfix | < 1 hour |
| **High** | Crash rate 2-5% | Reduce to 10%, investigate | < 1 hour |
| **High** | Major bug affecting > 10% users | Reduce to 10%, fix + redeploy | < 24 hours |
| **Medium** | Minor bug affecting < 10% users | Continue monitoring, fix in next release | 1-2 days |
| **Low** | Poor engagement | Gradual rollback, improve feature | 1 week |

## Success Criteria (End of Phase 6)

### Technical Success

- [ ] 4-5 high-risk features behind feature flags
- [ ] Firebase Remote Config configured (20 features)
- [ ] Gradual rollout completed (10% → 50% → 100%)
- [ ] Zero production incidents from flagged features
- [ ] Rollback procedure tested and documented

### Metrics Success

- [ ] Crash rate < 1%
- [ ] Support tickets < 1% of active users
- [ ] Feature engagement meets expectations
- [ ] All analytics tracking verified
- [ ] Monitoring dashboards created

### Operational Success

- [ ] Team trained on rollback procedure
- [ ] Monitoring alerts configured
- [ ] Incident response playbook created
- [ ] Post-rollout retrospective completed

## Next Steps After Phase 6

Once Phase 6 is complete:

1. **Feature Development**: Use feature flags for all new features
2. **A/B Testing**: Leverage Remote Config for experiments
3. **Gradual Deprecation**: Use flags to safely remove old features
4. **Emergency Response**: Rely on rollback procedure for incidents

## Troubleshooting

### Issue: Remote Config not fetching

**Symptom**: App always uses default values

**Solutions**:
1. Check network connectivity
2. Verify Firebase configuration (GoogleService-Info.plist)
3. Check console for fetch errors
4. Verify API keys are valid

### Issue: Feature toggle not taking effect

**Symptom**: Changed flag in Firebase, but app behavior unchanged

**Solutions**:
1. Wait 12 hours (cache TTL)
2. Check local overrides (Settings → Feature Flags → Clear All)
3. Force app restart (kill + relaunch)
4. Verify flag name matches exactly (case-sensitive)

### Issue: Inconsistent behavior across users

**Symptom**: Some users see feature, others don't

**Possible Causes**:
1. Gradual rollout active (expected)
2. Local overrides set
3. Different app versions
4. Remote Config propagation delay (up to 5 minutes)

### Issue: High crash rate after rollout

**Action**:
1. Execute immediate rollback (see Phase 6.5)
2. Check Crashlytics for crash logs
3. Filter by affected feature
4. Identify root cause
5. Fix + re-test before re-deploying

## Support Resources

- **Firebase Documentation**: https://firebase.google.com/docs/remote-config
- **Firebase Support**: https://firebase.google.com/support
- **Crashlytics**: https://firebase.google.com/docs/crashlytics
- **App Store Connect**: https://appstoreconnect.apple.com/
- **Slack**: #engineering channel

## Appendix: Feature Flag Reference

| Feature | Premium | State | Rollout Strategy |
|---------|---------|-------|------------------|
| `video_import` | ✅ | Released | 10% → 50% → 100% over 3 weeks |
| `asmr_processing` | ✅ | Beta | Start disabled, enable for beta testers |
| `cloud_sync` | ✅ | Released | Enabled by default (stable) |
| `cookbook_scan` | ✅ | Development | Disabled (not implemented) |
| `recipe_sharing` | ✅ | Released | Enabled by default (stable) |
| `blind_box_collections` | ❌ | Released | Enabled by default (core) |
| `daily_heritage_drop` | ❌ | Released | Enabled by default (core) |
| `discovery` | ❌ | Alpha | Start disabled, enable for alpha testers |
| `onboarding` | ❌ | Released | Enabled by default (critical path) |
| All others | ❌ | Released | Enabled by default (core features) |
