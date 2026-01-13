# Firebase Remote Config Setup for Feature Flags

This guide explains how to configure Firebase Remote Config to control feature flags in the Heirloom app.

## Overview

Heirloom uses Firebase Remote Config to enable/disable features remotely without requiring app updates. This allows for:
- Gradual feature rollout (10% → 50% → 100% of users)
- Kill switch for problematic features
- A/B testing different features
- Platform-specific feature control

## Feature Flag Naming Convention

All feature flags use the snake_case format matching the `Feature` enum rawValue:

```
recipe_management
collections
tags
scaling
premium_subscription
video_import
asmr_processing
recipe_sharing
cloud_sync
cookbook_scan
blind_box_collections
daily_heritage_drop
heritage_provenance
discovery
dinner_party
shopping_lists
stats
onboarding
debug_menu
```

## Firebase Console Setup

### 1. Access Remote Config

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your Heirloom project
3. Navigate to: **Engage** → **Remote Config**

### 2. Create Feature Flag Parameters

For each feature flag, create a new parameter:

**Parameter Name**: Use the exact feature rawValue (e.g., `video_import`)

**Data type**: Boolean

**Default value**: `true` (features enabled by default)

**Description**: Brief description of the feature (e.g., "Import recipes from YouTube videos")

### 3. Set Initial Values (Conservative Approach)

For new or risky features, start with conservative default values:

| Feature | Initial Value | Rationale |
|---------|--------------|-----------|
| `video_import` | `true` | Stable feature, tested in Phase 1 |
| `asmr_processing` | `false` | Start disabled, enable for 10% first |
| `cookbook_scan` | `false` | Not yet implemented |
| `cloud_sync` | `true` | Stable feature |
| `recipe_sharing` | `true` | Stable feature |
| All others | `true` | Core features, keep enabled |

### 4. Configure Conditions (Optional)

Create conditions for gradual rollout or A/B testing:

#### Example: Gradual Rollout (10% of users)

1. Click "Add condition"
2. **Condition name**: `asmr_10_percent_rollout`
3. **Applies if**:
   - Select "Percent of users"
   - Set to `10%`
4. **Value**: `true`
5. **Default**: `false`

#### Example: Platform-Specific

1. **Condition name**: `ios_only`
2. **Applies if**:
   - Select "Platform / OS"
   - Choose "iOS"
3. **Value**: `true`

#### Example: App Version

1. **Condition name**: `version_2_0_or_higher`
2. **Applies if**:
   - Select "App version"
   - Operator: `>=`
   - Value: `2.0.0`
3. **Value**: `true`

### 5. Publish Changes

1. Review all parameters
2. Click **Publish changes** button
3. Add a description (e.g., "Initial feature flags setup for v2.0")
4. Confirm publication

## App Integration

The app automatically fetches Remote Config values:

### Fetch Behavior

- **On app launch**: Background fetch
- **Cache duration**: 12 hours
- **Fallback**: Local overrides > Remote values > Default (true)

### Fetch Lifecycle

```swift
// FeatureFlagManager automatically fetches on init
let flagManager = FeatureFlagManager.shared

// Manual fetch (usually not needed)
await flagManager.fetchRemoteFlags()
```

### Checking Feature Status

```swift
// Check if feature is enabled (considers remote flags)
if flagManager.isEnabled(.videoImport) {
    // Show video import UI
}

// Check if feature is available for user (considers subscription)
if flagManager.isAvailable(.asmrProcessing, subscriptionManager: subManager) {
    // Show ASMR processing option
}
```

## Gradual Rollout Strategy

### Week 1: 10% Rollout

1. Create condition: `asmr_10_percent_rollout`
2. Set `asmr_processing`:
   - Condition: `asmr_10_percent_rollout` → `true`
   - Default: `false`
3. Publish changes
4. Monitor metrics:
   - Crash rate (Crashlytics)
   - Feature engagement (Analytics)
   - Support tickets

### Week 2: 50% Rollout

1. Update condition to `50%`
2. Publish changes
3. Continue monitoring

### Week 3: 100% Rollout

1. Remove condition, set default to `true`
2. Publish changes
3. Feature now enabled for all users

## Emergency Kill Switch

To immediately disable a problematic feature:

1. Navigate to Remote Config in Firebase Console
2. Find the feature parameter (e.g., `video_import`)
3. Set default value to `false`
4. Click **Publish changes**
5. **Effect**: Within 12 hours (next fetch), feature will be disabled for all users

For immediate effect (no cache wait):
1. Disable feature as above
2. Reduce "Minimum fetch interval" to `0` hours (temporary)
3. Publish changes
4. Restore "Minimum fetch interval" to `12` hours after incident resolved

## Monitoring and Analytics

### Key Metrics to Track

Use Firebase Analytics to monitor feature flag effectiveness:

```swift
analytics.track(event: .featureFlagChanged, properties: [
    "feature": feature.rawValue,
    "enabled": isEnabled,
    "source": "remote" // or "local" or "default"
])
```

### Dashboard Queries

Create custom queries in Firebase Analytics:

1. **Feature Adoption**:
   - Event: `feature_used`
   - Filter by: `feature` parameter
   - Group by: `enabled` status

2. **Flag Override Rate**:
   - Event: `feature_flag_changed`
   - Count distinct users with `source=local`

3. **Crash Correlation**:
   - Compare crash rate before/after enabling feature
   - Group crashes by `feature_enabled` user property

## Testing

### Local Testing (Debug Menu)

1. Open Heirloom app
2. Navigate to: **Settings** → **Developer Testing** → **Feature Flags**
3. Toggle any feature on/off (local override)
4. Local overrides take precedence over remote flags

### Remote Config Testing

1. In Firebase Console, use the "User targeting" feature
2. Create condition for specific user ID or test device
3. Test flag changes without affecting production users

### Verification

Check Remote Config status in debug log:

```
FeatureFlagManager: Remote Config fetch completed with status: 0 (success)
FeatureFlagManager: Remote Config activated: true
FeatureFlagManager: Feature 'video_import' resolved to true (source: remote)
```

## Best Practices

### DO ✅

- **Start conservative**: Disable risky features, enable gradually
- **Monitor metrics**: Track crash rate, engagement, support tickets for 48 hours after enabling
- **Document changes**: Add clear descriptions when publishing Remote Config changes
- **Test thoroughly**: Use conditions to test with internal users before full rollout
- **Version gate**: Use app version conditions for features requiring code changes

### DON'T ❌

- **Don't rely solely on flags**: Features should degrade gracefully when disabled
- **Don't fetch too often**: Respect 12-hour cache (avoid rate limiting)
- **Don't remove flags**: Deprecate features by keeping flag but documenting it's unused
- **Don't ignore errors**: Log and monitor Remote Config fetch failures
- **Don't skip rollback testing**: Test disabling features before production incidents

## Environments

### Development

- Use Firebase project: `heirloom-dev`
- Fetch interval: 0 hours (no cache for fast testing)
- All flags default to `true` for development

### Staging

- Use Firebase project: `heirloom-staging`
- Fetch interval: 1 hour
- Mirrors production flag configuration

### Production

- Use Firebase project: `heirloom-prod`
- Fetch interval: 12 hours
- Conservative flag defaults for new features

## Troubleshooting

### Feature Not Updating

**Problem**: Changed remote flag but app still shows old value

**Solutions**:
1. Check cache: Remote Config caches for 12 hours
2. Force app restart (kill and relaunch)
3. Check local override: Settings → Feature Flags → Clear All Overrides
4. Verify publish: Ensure changes were published in Firebase Console

### Fetch Failing

**Problem**: Remote Config fetch errors in logs

**Solutions**:
1. Check network connectivity
2. Verify Firebase configuration (GoogleService-Info.plist)
3. Check Firebase Console for quota limits
4. Review error logs in Crashlytics

### Inconsistent Behavior

**Problem**: Different users see different feature states unexpectedly

**Causes**:
1. Gradual rollout conditions active (expected)
2. Local overrides set on some devices
3. Different app versions with different defaults
4. Remote Config propagation delay (up to 5 minutes)

## Support

For issues with Firebase Remote Config setup:
- Firebase Documentation: https://firebase.google.com/docs/remote-config
- Firebase Support: https://firebase.google.com/support
- Heirloom Internal: Ask in #engineering Slack channel
