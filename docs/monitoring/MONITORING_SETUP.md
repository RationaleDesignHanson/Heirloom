# Monitoring & Observability Setup

**Last Updated**: 2026-01-23
**Project**: Heirloom iOS App

## Current Monitoring Status

### ✅ Already Implemented

#### 1. Analytics - Mixpanel
**Status**: ✅ **CONFIGURED**

**Location**: `Heirloom/Core/Services/Analytics/`
- `AnalyticsService.swift` - Facade pattern
- `MixpanelService.swift` - Mixpanel integration
- `ConsoleAnalyticsService.swift` - Fallback for testing

**Events Tracked**:
- App lifecycle (launch, background, foreground)
- Recipe actions (view, create, edit, delete, favorite)
- Collection management
- Shopping list interactions
- Recipe scaling (Smallify feature)
- Search & discovery
- Import/export operations
- PDF import with multi-page detection
- AI service usage (tokens, success/failure rates)
- Store & subscriptions (purchases, trials, paywalls)
- Help & support interactions
- Card personalization
- Cooking sessions and timers

**Configuration Required**:
- [ ] Add Mixpanel token to production build
- [ ] Verify Mixpanel dashboard access
- [ ] Set up custom properties for user segmentation

**Usage**:
```swift
let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
analytics.initialize()
analytics.track(event: .appLaunched)
analytics.trackRecipeViewed(recipe: recipe)
```

---

### ❌ Not Implemented

#### 2. Crash Reporting - Firebase Crashlytics
**Status**: ❌ **NOT CONFIGURED**

**Recommendation**: **HIGH PRIORITY** - Add before production launch

**Why Needed**:
- Real-time crash detection and alerting
- Symbolicated stack traces for debugging
- Crash-free users % metric
- Automatic grouping of similar crashes
- Breadcrumbs for crash context

**Setup Steps**:
1. Add Firebase Crashlytics to Package.swift dependencies
2. Import `FirebaseCrashlytics` in `HeirloomApp.swift`
3. Initialize after `FirebaseApp.configure()`:
   ```swift
   import FirebaseCrashlytics

   // In HeirloomApp.init()
   if !isRunningTests {
       FirebaseApp.configure()
       Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
   }
   ```
4. Enable debug symbols upload in Xcode build phases
5. Test crash reporting in TestFlight build

**Alert Configuration**:
- Set up Slack/email alerts for new crashes
- Alert on crash-free users % < 98%
- Alert on crashes affecting > 1% of users

---

#### 3. Performance Monitoring - Firebase Performance
**Status**: ❌ **NOT CONFIGURED**

**Recommendation**: **MEDIUM PRIORITY** - Add after launch

**Why Needed**:
- App startup time tracking
- Network request monitoring
- Custom trace performance
- Screen rendering time
- Automatic performance collection

**Setup Steps**:
1. Add Firebase Performance to Package.swift
2. Import `FirebasePerformance` in `HeirloomApp.swift`
3. Enable automatic monitoring:
   ```swift
   import FirebasePerformance

   // Automatic monitoring enabled by default after Firebase.configure()
   ```
4. Add custom traces for critical flows:
   ```swift
   let trace = Performance.startTrace(name: "recipe_import")
   // ... perform operation
   trace?.stop()
   ```

**Key Metrics to Track**:
- App startup time (< 2 seconds goal)
- Recipe import duration
- PDF processing time
- Video transcription time
- Firebase query response time
- Image upload/download time

---

#### 4. Custom Logging - Device Logger
**Status**: ✅ **ALREADY IMPLEMENTED** (DeviceLogger.shared)

**Enhancement Needed**:
- Add log aggregation (send logs to remote service)
- Add log retention policy (delete old logs)
- Add user-accessible debug log viewer in Settings

---

## Baseline Metrics

**Before making changes**, document current state:

### App Health Metrics (To Be Established)
- **Crash-Free Users %**: Target > 99.5%
- **Crashes per Session**: Target < 0.1%
- **ANRs (App Not Responding)**: Target < 0.01%

### Performance Metrics (To Be Baselined)
- **App Launch Time**: Measure on iPhone 13, 14, 15
- **Recipe Import Time**: Average time for 1-page PDF
- **Video Processing Time**: Average for 1-minute video
- **Firebase Query Time**: p50, p90, p99 latency
- **Image Load Time**: Time to display recipe card image

### Usage Metrics (Already Tracked via Mixpanel)
- **Daily Active Users (DAU)**
- **Monthly Active Users (MAU)**
- **Recipes Created per User**
- **Recipes Imported per User**
- **Feature Usage**: Which features are most used?
- **Conversion Rate**: Trial → Premium
- **Retention**: D1, D7, D30 retention rates

### Firebase-Specific Metrics
- **Firestore Read/Write Operations**: Cost optimization
- **Firestore Rule Denials**: Should be < 1% after security fix
- **Cloud Storage Usage**: Image/video storage costs
- **Authentication Success Rate**: > 99%

---

## Monitoring Dashboards

### 1. Firebase Console
**URL**: https://console.firebase.google.com/project/heirloom-ios-prod

**Key Pages**:
- **Firestore > Usage**: Monitor read/write operations
- **Firestore > Rules**: Check denial rate (CRITICAL after Task #8)
- **Authentication**: User sign-up/sign-in metrics
- **Crashlytics**: Crash reports and trends (once configured)
- **Performance**: App performance metrics (once configured)

**Access**:
- Requires Firebase authentication: `firebase login`
- Project owner: Matt Hanson

---

### 2. Mixpanel Dashboard
**Status**: Needs configuration

**Access**:
- URL: To be configured
- Token: Needs to be added to Config.xcconfig

**Key Reports to Create**:
- **Funnel**: Onboarding → First Recipe → Premium Conversion
- **Retention**: Cohort analysis (D1, D7, D30)
- **Feature Usage**: Which features drive retention?
- **Recipe Sources**: PDF vs Video vs Manual vs Shared
- **AI Usage**: Token consumption, success rates

---

### 3. App Store Connect
**URL**: https://appstoreconnect.apple.com

**Key Metrics**:
- **Crashes**: Crash reports from users
- **App Store ratings**: Monitor for negative feedback
- **Install/Uninstall rates**: User acquisition health
- **Version adoption**: How quickly users update

---

## Alerting Strategy

### Critical Alerts (Immediate Response)
**Slack Channel**: #heirloom-alerts (to be created)
**Email**: matt@example.com (replace with actual)

**Triggers**:
- ❌ Crash-free users % drops below 98%
- ❌ Firestore rule denial rate > 5% (indicates security issue)
- ❌ Authentication failure rate > 2%
- ❌ App Store rating drops below 4.0
- ❌ Production deployment fails

---

### Warning Alerts (Monitor & Investigate)
**Slack Channel**: #heirloom-monitoring

**Triggers**:
- ⚠️ Crash rate increases by > 50% week-over-week
- ⚠️ Slow performance: p90 latency > 5 seconds
- ⚠️ DAU drops by > 20% day-over-day
- ⚠️ Firebase costs spike unexpectedly

---

### Info Alerts (Daily Summary)
**Email**: Daily digest

**Include**:
- ℹ️ DAU, MAU, new sign-ups
- ℹ️ Recipes created/imported count
- ℹ️ Feature usage summary
- ℹ️ Firebase costs (yesterday)
- ℹ️ App Store reviews summary

---

## Monitoring Runbook

### After Each Deployment

**Within 1 Hour**:
- [ ] Check Firebase Console > Firestore > Rules for denial spikes
- [ ] Check Crashlytics for new crashes (once configured)
- [ ] Check Mixpanel for DAU anomalies
- [ ] Check App Store Connect for crash reports
- [ ] Verify authentication success rate

**Within 24 Hours**:
- [ ] Review performance metrics (if degraded)
- [ ] Check user feedback/support requests
- [ ] Monitor Firebase costs for spikes
- [ ] Review analytics events for anomalies

**Within 1 Week**:
- [ ] Analyze retention impact (did deployment affect retention?)
- [ ] Review crash-free users % trend
- [ ] Check feature usage changes
- [ ] Analyze conversion rate changes

---

### When Issues Detected

#### High Crash Rate
1. **Investigate**: Open Crashlytics, identify crash signature
2. **Assess Impact**: How many users affected? Which iOS versions?
3. **Triage**: Critical (> 5% users) or non-critical?
4. **Fix**: Hotfix release if critical, otherwise next release
5. **Communicate**: Notify affected users if major issue

#### Firestore Rule Denials Spike
1. **Check**: Firebase Console > Firestore > Rules
2. **Identify**: Which collection? Which operation?
3. **Analyze**: Are old app versions making invalid queries?
4. **Decision**: Rollback rules or fix app code?
5. **Monitor**: Watch denial rate after fix

#### Performance Degradation
1. **Measure**: Which operation is slow? (use Performance Monitoring)
2. **Profile**: Use Xcode Instruments to identify bottleneck
3. **Optimize**: Database queries? Network requests? Image processing?
4. **Test**: Verify improvement in staging
5. **Deploy**: Release optimized version

#### User Drop-Off
1. **Correlate**: Did deployment cause this? Or seasonal?
2. **Analyze**: Which user cohorts are leaving? (use Mixpanel)
3. **Investigate**: Support requests? App Store reviews?
4. **Hypothesis**: What feature change might have caused this?
5. **A/B Test**: Test hypothesis with feature flag

---

## Next Steps

### Immediate (Before Production Launch)
1. ✅ Document current monitoring setup (this file)
2. ❌ **ADD CRASHLYTICS** - Critical for production
3. ❌ Configure Mixpanel token in production
4. ❌ Set up Slack alerting channels
5. ❌ Create Firebase Console monitoring checklist
6. ❌ Test Crashlytics in TestFlight build

### Short-Term (Within 1 Month After Launch)
7. ❌ Add Firebase Performance Monitoring
8. ❌ Create Mixpanel retention funnel
9. ❌ Set up weekly metrics review meeting
10. ❌ Document baseline performance metrics
11. ❌ Add custom traces for slow operations
12. ❌ Create incident response playbook

### Long-Term (3-6 Months)
13. ❌ Add custom log aggregation service (e.g., Sentry, Datadog)
14. ❌ Implement error budgets (SLOs/SLIs)
15. ❌ Add real-user monitoring (RUM)
16. ❌ Create automated performance regression tests
17. ❌ Add cost monitoring dashboard for Firebase

---

## Resources

### Documentation
- [Firebase Crashlytics Setup](https://firebase.google.com/docs/crashlytics/get-started?platform=ios)
- [Firebase Performance Setup](https://firebase.google.com/docs/perf-mon/get-started-ios)
- [Mixpanel iOS SDK](https://docs.mixpanel.com/docs/tracking-methods/sdks/swift)

### Tools
- Xcode Instruments (built-in profiling)
- Firebase Console (monitoring dashboards)
- Mixpanel Dashboard (user analytics)
- App Store Connect (crash reports)

### Internal Docs
- `/docs/security/FIRESTORE_ROLLBACK.md` - Rollback procedures
- `/docs/security/FIRESTORE_RULES_BASELINE.md` - Current security state

---

**Document Owner**: Matt Hanson
**Review Frequency**: Monthly or after incidents
