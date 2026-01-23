# Heirloom Pre-Launch Checklist

**Version**: 1.1.4 (Build 20)
**Target Launch Date**: TBD
**Last Updated**: 2026-01-23

Use this checklist to ensure all critical items are completed before App Store submission.

---

## 🔐 Phase 0: Critical Infrastructure (MUST DO FIRST)

### Backups & Safety ✅ COMPLETED
- [x] Full repository backup created (`~/Desktop/heirloom-backup-20260123-090227.tar.gz`)
- [x] Firestore rules backed up (`~/Desktop/firestore.rules.backup-20260123`)
- [x] Xcode project backed up (`~/Desktop/project.pbxproj.backup-20260123`)
- [x] Safety branch created and pushed (`backup/pre-production-changes-20260123`)

### Firebase Safety Infrastructure ✅ COMPLETED
- [x] Firebase emulator configured (`firebase.json`)
- [x] Firestore rules test script created (`/scripts/test-firestore-rules.sh`)
- [x] Rollback procedure documented (`/docs/security/FIRESTORE_ROLLBACK.md`)
- [x] Security baseline documented (`/docs/security/FIRESTORE_RULES_BASELINE.md`)

### Monitoring & Observability ✅ COMPLETED
- [x] Monitoring documentation created (`/docs/monitoring/MONITORING_SETUP.md`)
- [x] Baseline metrics documented (`/docs/monitoring/BASELINE_METRICS.md`)
- [x] Firebase Crashlytics integrated and configured (2026-01-23)
- [x] Mixpanel production token configured (2026-01-23)
- [x] Crashlytics dSYM generation enabled (Debug + Release)
- [x] Crashlytics upload script configured (Release + Device only)
- [ ] **TODO**: Set up Slack alerting channels
- [ ] **TODO**: Test Crashlytics in TestFlight build

---

## 🔥 Phase 1: Critical Security Fixes

### Firestore Security Rules ✅ COMPLETED
- [x] Identified shares collection vulnerability
- [x] Updated firestore.rules with secure access controls
- [x] Documented security fix (`/docs/security/SECURITY_FIX_2026-01-23.md`)
- [ ] **TODO**: Test rules in Firebase emulator
- [ ] **TODO**: Deploy rules to production
- [ ] **TODO**: Monitor rule denial rate for 24 hours

**Test Command**:
```bash
# Start emulator and test
./scripts/test-firestore-rules.sh
```

**Deployment Command**:
```bash
firebase login
firebase deploy --only firestore:rules --project heirloom-ios-prod
```

---

## ⚙️ Phase 2: CI/CD & Build Infrastructure

### GitHub Actions ✅ COMPLETED
- [x] Updated `tests.yml` to use `actions/upload-artifact@v4`
- [x] Updated `tests.yml` to use `actions/download-artifact@v4`
- [x] Added `workflow_dispatch` trigger to `tests.yml`
- [x] Verified `videolab-tests.yml` consistency

### Build Status & Documentation ✅ COMPLETED
- [x] Added build badges to README.md
- [x] Created CONTRIBUTING.md with contribution guidelines
- [x] Verified GitHub Actions workflows run successfully

**Next Steps**:
- [ ] Trigger manual workflow run to verify `workflow_dispatch` works
- [ ] Review CI test results for any failures

---

## 🧪 Phase 3: Testing & Quality Assurance

### Test Suite Baseline ⏳ TODO
- [ ] Run full test suite and document results
- [ ] Document passing test count
- [ ] Document failing test count (known issues)
- [ ] Document flaky tests
- [ ] Record test execution time

**Run Tests**:
```bash
xcodebuild test \
  -project Heirloom.xcodeproj \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  | tee test-results-baseline.txt
```

### Code Quality Tools ⏳ TODO
- [ ] Install SwiftLint (if not installed)
- [ ] Create `.swiftlint.yml` configuration
- [ ] Run initial SwiftLint audit
- [ ] Document violation count by severity
- [ ] Fix critical violations (if any)
- [ ] Integrate SwiftLint into Xcode build phase (optional)

**SwiftLint Audit**:
```bash
swiftlint lint --reporter markdown > swiftlint-report.md
```

---

## 🎯 Phase 4: App Store Compliance

### App Metadata (App Store Connect)
- [ ] App name finalized (30 char limit)
- [ ] Subtitle finalized (30 char limit)
- [ ] Description written (4000 char limit)
- [ ] Keywords researched and set (100 char limit)
- [ ] Promotional text (170 chars)
- [ ] Privacy policy URL (must be live and accessible)
- [ ] Support URL (must be live and accessible)
- [ ] App category selected
- [ ] Age rating completed

### Screenshots & Assets
- [ ] iPhone 6.7" screenshots (iPhone 15 Pro Max, 14 Pro Max)
- [ ] iPhone 6.5" screenshots (iPhone 11 Pro Max, XS Max)
- [ ] iPhone 5.5" screenshots (iPhone 8 Plus) - if supporting older devices
- [ ] iPad 12.9" screenshots (if iPad supported)
- [ ] App icon 1024x1024 (no transparency, no alpha channel)
- [ ] Optional: App preview video (30 seconds max)

**Screenshot Guidelines**:
- Show key features: Import, Collections, Shopping, Sharing
- Use real content (no Lorem Ipsum)
- Hide personal information
- Show app in use (not just static UI)

### Legal Documents
- [x] Terms of Service exists (`TERMS_OF_SERVICE.txt`)
- [x] Privacy Policy exists (`PRIVACY_POLICY.txt`)
- [x] EULA exists (`EULA.txt`)
- [ ] **TODO**: Host privacy policy at public URL
- [ ] **TODO**: Host terms of service at public URL
- [ ] **TODO**: Host support page at public URL
- [ ] **TODO**: Verify all legal docs are current and accurate

**Hosting Options**:
- GitHub Pages: `https://[username].github.io/heirloom/privacy`
- Firebase Hosting: Deploy with Firebase
- Custom domain: `https://heirloom.app/privacy`

### Technical Compliance
- [ ] App Transport Security (ATS) configured correctly
- [ ] IPv6 compatibility verified
- [ ] No private API usage
- [ ] All third-party SDKs are App Store compliant
- [ ] Crashlytics/analytics configured and tested
- [ ] App launch time < 5 seconds (ideally < 2 seconds)
- [ ] No memory leaks (tested with Instruments)
- [ ] App works on all supported iOS versions (iOS 17+)
- [ ] App works on all screen sizes (iPhone, iPad if supported)

### IDFA & Privacy
- [ ] Determine if using advertising identifier (IDFA)
- [ ] Complete App Store privacy questionnaire
- [ ] Declare data collection practices:
  - [ ] Email (authentication)
  - [ ] Name (user profile)
  - [ ] User-generated content (recipes)
  - [ ] Usage data (analytics via Mixpanel)
  - [ ] Crash data (Crashlytics)
- [ ] Implement App Tracking Transparency (ATT) if using IDFA
- [ ] Privacy manifest file included (if required)

---

## 📱 Phase 5: Build & Distribution

### Xcode Configuration
- [ ] Version number updated (e.g., 1.2.0)
- [ ] Build number incremented (e.g., 21)
- [ ] Bundle identifier correct: `com.matthanson.heirloom`
- [ ] Team provisioning profile selected
- [ ] Code signing configured (automatic or manual)
- [ ] Release build configuration optimized
- [ ] Bitcode disabled (deprecated in Xcode 14+)
- [ ] Debug symbols generated for Crashlytics

### TestFlight (Beta Testing)
- [ ] Create App Store Connect app record
- [ ] Upload build to TestFlight
- [ ] Add internal testers (up to 100)
- [ ] Add external testers (up to 10,000)
- [ ] Export compliance information completed
- [ ] Beta app review passed (for external testing)
- [ ] Collect beta tester feedback
- [ ] Fix critical bugs found in beta

**TestFlight Notes**:
- Internal testing: Available immediately after upload
- External testing: Requires beta app review (~24 hours)
- Max 90 days per build

### Production Release
- [ ] All TestFlight feedback addressed
- [ ] Crash-free rate > 99% in TestFlight
- [ ] No critical bugs reported
- [ ] Final smoke test on physical device
- [ ] Submit for App Store Review
- [ ] Respond to review feedback (if rejected)
- [ ] Release date selected (manual or automatic)

---

## 🔧 Phase 6: Firebase & Backend

### Firebase Configuration
- [x] Firebase project created (`heirloom-ios-prod`)
- [x] `GoogleService-Info.plist` configured
- [x] Firebase Authentication enabled (Apple, Google)
- [x] Firestore Database created
- [x] Cloud Storage enabled
- [x] Firestore security rules fixed and ready for deployment (2026-01-23)
- [ ] **TODO**: Firestore security rules DEPLOYED to production
- [ ] **TODO**: Storage security rules reviewed
- [x] Firebase Crashlytics enabled (2026-01-23)
- [ ] **TODO**: Firebase Performance Monitoring enabled (optional)
- [ ] **TODO**: Firebase Cloud Functions deployed (if any)

### Firebase Costs & Limits
- [ ] Review Firebase pricing: https://firebase.google.com/pricing
- [ ] Estimate monthly costs based on expected usage
- [ ] Set up billing alerts ($10, $50, $100 thresholds)
- [ ] Configure budget alerts in Google Cloud Console
- [ ] Monitor Firestore read/write operations
- [ ] Monitor Storage bandwidth usage
- [ ] Monitor Authentication usage

**Expected Costs** (estimate):
- Firestore: ~$0.06 per 100K reads, $0.18 per 100K writes
- Storage: ~$0.026 per GB stored, $0.12 per GB downloaded
- Authentication: Free tier very generous

---

## 🤖 Phase 7: AI Services & API Keys

### Anthropic API (Claude)
- [ ] Production API key obtained
- [ ] Added to `Config.xcconfig` (NOT committed to git)
- [ ] Cost monitoring enabled
- [ ] Rate limiting implemented in app
- [ ] Error handling for API failures
- [ ] Fallback behavior for offline mode

### Google Sign-In
- [x] Client ID configured in `GoogleService-Info.plist`
- [x] Reversed client ID in `Config.xcconfig`
- [ ] OAuth consent screen configured
- [ ] Scopes minimal (email, profile only)
- [ ] Testing on physical device completed

### Other APIs
- [ ] Verify all API keys are in `Config.xcconfig`
- [ ] Verify `Config.xcconfig` is in `.gitignore`
- [ ] Document API key rotation procedure
- [ ] Set up API usage monitoring

---

## 📊 Phase 8: Analytics & Monitoring

### Mixpanel (Analytics)
- [x] Mixpanel SDK integrated
- [x] Production Mixpanel token configured (2026-01-23)
- [x] Development Mixpanel token configured (2026-01-23)
- [ ] Analytics events verified in Mixpanel dashboard
- [ ] User properties tracked (recipes count, premium status)
- [ ] Key funnels created:
  - [ ] Onboarding → First Recipe → Premium
  - [ ] Recipe Import funnel
  - [ ] Share funnel
- [ ] Retention cohorts configured (D1, D7, D30)

### Firebase Analytics (Alternative/Additional)
- [ ] Firebase Analytics enabled (optional)
- [ ] Custom events tracked
- [ ] User properties set
- [ ] Audience segmentation configured

### Crashlytics
- [x] Firebase Crashlytics SDK added (2026-01-23)
- [x] Crash reporting tested in debug build (2026-01-23)
- [x] Fatal error handler configured (via FirebaseCrashlytics.Crashlytics)
- [x] dSYM generation enabled for Debug and Release builds
- [x] dSYM upload script configured (Release + Device only)
- [x] Test crash button added to Settings (DEBUG only)
- [ ] Non-fatal error logging implemented
- [ ] Breadcrumbs for crash context
- [ ] Test crash verified in TestFlight build

---

## 📝 Phase 9: Documentation

### User-Facing Documentation
- [x] README.md updated with current features
- [x] CONTRIBUTING.md created
- [ ] User guide created (optional)
- [ ] FAQ document created (optional)
- [ ] Help center content written (optional)
- [ ] In-app onboarding flow complete

### Developer Documentation
- [ ] Architecture documentation in `/docs/architecture/` (optional)
- [ ] API documentation for services (optional)
- [ ] Firebase schema documented (optional)
- [x] Security documentation created
- [x] Monitoring documentation created

### Release Notes
- [ ] Changelog maintained
- [ ] Version 1.0 release notes drafted
- [ ] App Store "What's New" text written (560 char limit)

---

## 🚨 Phase 10: Emergency Preparedness

### Incident Response
- [x] Firestore rollback procedure documented
- [ ] Contact list for emergencies:
  - [ ] Firebase support
  - [ ] Apple Developer support
  - [ ] Team members contact info
- [ ] On-call schedule (if team exists)
- [ ] Incident runbook created (`/docs/monitoring/INCIDENT_RUNBOOK.md`)

### Monitoring Alerts
- [ ] Slack channel for critical alerts
- [ ] Email distribution list for incidents
- [ ] Alert escalation policy defined
- [ ] Alert thresholds configured:
  - [ ] Crash rate > 2%
  - [ ] Rule denials > 5%
  - [ ] Auth failures > 2%
  - [ ] API errors > 10%

---

## ✅ Phase 11: Final Pre-Submission Checks

### Functionality Testing
- [ ] Test on physical iPhone (not just simulator)
- [ ] Test on oldest supported iOS version (iOS 17.0)
- [ ] Test on newest iOS version
- [ ] Test all critical user flows:
  - [ ] Sign up / Sign in (Apple, Google)
  - [ ] Create recipe manually
  - [ ] Import recipe from URL
  - [ ] Import recipe from PDF
  - [ ] Import recipe from video
  - [ ] Add to shopping list
  - [ ] Share recipe
  - [ ] Accept shared recipe
  - [ ] Customize recipe card
  - [ ] Sync across devices
  - [ ] Subscribe to premium (test sandbox purchase)
- [ ] Test offline mode (airplane mode)
- [ ] Test low battery mode
- [ ] Test low memory scenario
- [ ] Test network interruption during critical operations
- [ ] Test app backgrounding and resuming
- [ ] Test force quit and relaunch
- [ ] Verify data persistence after app restart

### Accessibility Testing
- [ ] VoiceOver support tested
- [ ] Dynamic Type tested (small to largest text)
- [ ] Color contrast verified (WCAG AA)
- [ ] Tap target sizes adequate (44x44 pt minimum)
- [ ] Keyboard navigation works (iPad)
- [ ] Reduce Motion respected
- [ ] Assistive touch tested

### Performance Testing
- [ ] App launch time < 2 seconds
- [ ] Smooth scrolling (60fps in recipe list)
- [ ] Image loading optimized
- [ ] No memory leaks (Instruments → Leaks)
- [ ] Low memory warning handled gracefully
- [ ] Battery usage acceptable (test with Battery instrument)

### Localization (if applicable)
- [ ] All user-facing strings in Localizable.strings
- [ ] Date/time formatted correctly for locale
- [ ] Currency formatted correctly
- [ ] Right-to-left (RTL) support if needed

---

## 📦 Phase 12: Deployment Preparation

### Pre-Deployment
- [ ] Final code review completed
- [ ] All merge conflicts resolved
- [ ] All tests passing in CI
- [ ] SwiftLint violations addressed (if configured)
- [ ] No console warnings
- [ ] No TODO or FIXME in critical code
- [ ] Version numbers updated
- [ ] Release notes written

### Deployment Day
1. **Morning Checks**
   - [ ] All systems operational (Firebase, GitHub, App Store Connect)
   - [ ] Team available for monitoring
   - [ ] Rollback procedures reviewed

2. **Deploy Firestore Rules**
   ```bash
   firebase deploy --only firestore:rules --project heirloom-ios-prod
   ```
   - [ ] Rules deployed successfully
   - [ ] Monitor rule denials for 1 hour
   - [ ] No user complaints

3. **Submit to App Store**
   - [ ] Build uploaded to App Store Connect
   - [ ] Screenshots and metadata verified
   - [ ] Pricing and availability set
   - [ ] Submit for review
   - [ ] Wait for App Store Review (1-3 days typical)

4. **Post-Submission**
   - [ ] Monitor App Store Connect for review status
   - [ ] Respond to review feedback within 24 hours
   - [ ] If approved: Set release date or release immediately
   - [ ] If rejected: Fix issues and resubmit

### Post-Launch Monitoring (First 48 Hours)
- [ ] Monitor Crashlytics for crash spikes
- [ ] Monitor Firebase rule denials
- [ ] Monitor authentication success rate
- [ ] Monitor Mixpanel for user activity
- [ ] Monitor App Store reviews (reply to negative reviews)
- [ ] Monitor support emails
- [ ] Check Firebase costs daily
- [ ] Verify analytics events are tracked
- [ ] Document any issues for hotfix

---

## 🎉 Launch Success Criteria

**App is ready for production when**:
- ✅ All critical and high-priority items completed
- ✅ Crash-free rate > 99% in TestFlight
- ✅ No critical bugs in issue tracker
- ✅ Firebase security rules deployed and tested
- ✅ All legal documents hosted and accessible
- ✅ App Store metadata complete
- ✅ TestFlight beta testing completed with positive feedback
- ✅ Monitoring and alerting configured
- ✅ Rollback procedures tested and ready

---

## 📋 Summary Status

### Completed ✅
- Backups and safety infrastructure
- CI/CD pipeline fixes (GitHub Actions v4, workflow_dispatch)
- Critical security vulnerability fixed (Firestore rules - needs deployment)
- Monitoring documentation
- Build status badges
- Contributing guidelines
- **Firebase Crashlytics integration (2026-01-23)**
- **Mixpanel token configuration (2026-01-23)**
- **dSYM generation and upload automation (2026-01-23)**
- **Test crash functionality verified (2026-01-23)**

### In Progress 🔨
- Firestore rules deployment to production
- Testing infrastructure baseline
- TestFlight beta testing

### Not Started ⏳
- App Store metadata and screenshots
- TestFlight beta testing
- Legal document hosting
- Final compliance checks
- SwiftLint configuration

---

## 📞 Contact & Support

**Project Owner**: Matt Hanson
**Repository**: https://github.com/RationaleDesignHanson/Heirloom
**Firebase Project**: heirloom-ios-prod

**Support Resources**:
- Firebase Status: https://status.firebase.google.com
- Apple Developer Support: https://developer.apple.com/support/
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

---

**Last Updated**: 2026-01-23
**Next Review**: Before App Store submission
**Version**: 1.1.4 (Build 20)
