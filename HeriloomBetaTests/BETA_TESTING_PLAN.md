# Heirloom Beta Testing Plan
## TestFlight Release Strategy

**Version:** 1.0.0 (Beta 1)
**Target Release Date:** [Insert Date]
**Testing Duration:** 3-4 weeks
**Target Beta Testers:** 20-30 users

---

## Executive Summary

Heirloom is a native iOS recipe management app focused on capturing, organizing, and sharing family recipes across generations. This beta test aims to validate core functionality, identify bugs, gather UX feedback, and ensure CloudKit sync reliability before public launch.

**Tagline:** "Recipes Worth Passing Down"

---

## Beta Testing Objectives

### Primary Goals
1. **Functionality Validation:** Ensure all core features work reliably across different iOS versions and devices
2. **CloudKit Sync Testing:** Validate iCloud sync across multiple devices and edge cases
3. **User Experience Feedback:** Gather insights on usability, discoverability, and user satisfaction
4. **Performance Testing:** Identify crashes, memory issues, and performance bottlenecks
5. **Recipe Import Accuracy:** Test web scraping across various recipe sites
6. **Shopping List Integration:** Validate Reminders app integration and permissions flow

### Secondary Goals
1. Gather feature prioritization feedback
2. Test onboarding effectiveness
3. Validate scaling algorithm accuracy
4. Test dinner party planning workflow
5. Gather feedback on card personalization features
6. Identify missing or desired recipe sources

---

## Beta Tester Profile

### Ideal Tester Characteristics
- **Device:** iPhone running iOS 17.0 or later
- **iCloud Status:** Active iCloud account (for CloudKit testing)
- **Cooking Frequency:** Cooks 2-3+ times per week
- **Tech Savvy:** Comfortable with TestFlight and providing feedback
- **Recipe Usage:** Currently uses recipes from web, cookbooks, or family
- **Motivation:** Interested in organizing personal recipe collection

### Tester Segments (Aim for Diversity)
1. **Heavy Recipe Users** (10 testers): Multiple recipes per week, large collections
2. **Family Recipe Keepers** (5 testers): Focus on family recipes and sharing
3. **Casual Cooks** (5 testers): Occasional cooking, smaller recipe needs
4. **Tech Enthusiasts** (5 testers): Early adopters, detailed bug reporters
5. **Multi-Device Users** (5 testers): iPhone + iPad for sync testing

### Device Coverage Target
- iPhone 15/15 Pro (iOS 18)
- iPhone 14/14 Pro (iOS 17-18)
- iPhone 13 (iOS 17-18)
- iPhone 12 (iOS 17)
- iPhone SE (3rd gen, iOS 17)
- iPad (if time permits)

---

## Pre-Launch Checklist

### Development Tasks
- [ ] Finalize app bundle identifier: `com.matthanson.heirloom`
- [ ] Set version number to 1.0.0 (Build 1)
- [ ] Configure release build settings (optimizations enabled)
- [ ] Add TestFlight beta entitlements
- [ ] Verify CloudKit container configuration
- [ ] Set up crash reporting (Crashlytics or Sentry - optional but recommended)
- [ ] Implement analytics tracking confirmation (currently console-only)
- [ ] Test build on physical devices (not just simulator)
- [ ] Verify all permissions requests have proper descriptions
- [ ] Review and finalize onboarding copy
- [ ] Ensure app icon is finalized (1024x1024 required)

### App Store Connect Setup
- [ ] Create app record in App Store Connect
- [ ] Configure TestFlight beta information
- [ ] Add beta app description and instructions
- [ ] Set up TestFlight public link (optional) or internal testing group
- [ ] Configure automatic build distribution
- [ ] Set up email notifications for testers
- [ ] Prepare privacy policy (required for TestFlight)
- [ ] Upload beta screenshots (optional but helpful)

### Legal & Compliance
- [ ] Privacy policy published (even basic version)
- [ ] Terms of service (if applicable)
- [ ] Data collection disclosure in TestFlight description
- [ ] Export compliance information completed

### Communication Materials
- [ ] Beta tester invitation email written
- [ ] TestFlight instructions document
- [ ] Feedback collection system setup (form, email, or in-app)
- [ ] Bug reporting template created
- [ ] Beta tester Slack/Discord channel (optional)

---

## Testing Phases

### Phase 1: Internal Testing (3-5 days)
**Testers:** Developer + 2-3 trusted friends/colleagues

**Focus Areas:**
- Installation and first launch
- Critical path testing (add recipe → cook → shopping list)
- CloudKit sync between devices
- Crash identification
- Major blocker bugs

**Success Criteria:**
- No crashes during core workflows
- CloudKit sync working reliably
- All permissions granted properly
- Onboarding completable

### Phase 2: Closed Beta (Week 1-2)
**Testers:** 10-15 early adopters

**Focus Areas:**
- Recipe import from popular sites (AllRecipes, Serious Eats, King Arthur)
- Manual recipe entry workflow
- Shopping list creation and Reminders export
- Cooking mode usability
- Recipe scaling accuracy
- Search and filter functionality

**Testing Scenarios:**
1. Import 5-10 recipes from various sources
2. Create a shopping list with 3+ recipes
3. Export shopping list to Reminders
4. Use cooking mode for 2+ recipes
5. Scale a recipe up and down
6. Add tags and create collections
7. Mark recipes as favorites
8. Test search functionality

**Success Criteria:**
- 80%+ recipe import success rate
- No data loss incidents
- Shopping list exports successfully
- Cooking mode usable without major issues
- Average session length > 5 minutes

### Phase 3: Expanded Beta (Week 2-4)
**Testers:** Full 20-30 beta group

**Focus Areas:**
- Dinner party planning workflow
- Multi-device CloudKit sync
- Card personalization features
- Advanced filtering and sorting
- Recipe sharing (CloudKit)
- Edge cases and stress testing
- Performance with 50+ recipes

**Testing Scenarios:**
1. Create a dinner party with 3-4 recipes
2. Test shopping list aggregation for party
3. Share a recipe with another tester
4. Accept a shared recipe
5. Customize recipe cards with stickers/annotations
6. Test with 50+ recipes in library
7. Use app offline and sync when online
8. Test across iPhone and iPad (if available)

**Success Criteria:**
- Dinner party timeline calculations accurate
- CloudKit sharing works reliably
- No sync conflicts or data loss
- App performs well with 50+ recipes
- < 5 critical bugs reported
- 70%+ tester satisfaction score

---

## Critical Test Scenarios

### Priority 1 (Must Work Flawlessly)
1. **Recipe Import from URL**
   - Test AllRecipes, Serious Eats, King Arthur Baking
   - Verify ingredients parsed correctly
   - Verify instructions imported
   - Check image downloads

2. **Manual Recipe Entry**
   - Create recipe from scratch
   - Add ingredients with quantities
   - Add instructions as steps
   - Upload or skip image

3. **Cooking Mode**
   - Start cooking mode
   - Navigate through steps
   - Mark recipe as cooked
   - Times cooked counter increments

4. **Shopping List**
   - Add multiple recipes
   - Verify ingredient aggregation
   - Check off items
   - Export to Reminders

5. **CloudKit Sync**
   - Add recipe on Device A
   - Verify appears on Device B
   - Edit recipe on Device B
   - Verify changes sync to Device A

### Priority 2 (Important but Not Blocking)
1. **Recipe Scaling**
   - Scale recipe up (2x, 3x)
   - Scale recipe down (0.5x)
   - Verify fractions formatted correctly
   - Check spice scaling adjustments

2. **Search and Filters**
   - Search by recipe title
   - Filter by favorites
   - Filter by source type
   - Sort by date, title, times cooked

3. **Dinner Party Planning**
   - Create party with date and guest count
   - Add 3+ recipes
   - View timeline
   - Generate shopping list

4. **Card Personalization**
   - Change card background color
   - Add stickers
   - View auto-generated love marks

5. **Recipe Sharing**
   - Share recipe via CloudKit
   - Accept shared recipe
   - Verify generation counter

### Priority 3 (Nice to Have Tested)
1. Tags and collections management
2. Cookbook scanning (if OCR implemented)
3. Advanced sort options
4. Recipe deletion and undo
5. Settings configuration

---

## Bug Reporting Guidelines

### For Testers

**Required Information:**
1. Device model (e.g., iPhone 14 Pro)
2. iOS version (e.g., iOS 17.5)
3. App version and build number (found in Settings)
4. Steps to reproduce the issue
5. Expected behavior
6. Actual behavior
7. Screenshots or screen recording (if possible)
8. Frequency (always, sometimes, once)

**Bug Severity Levels:**
- **Critical:** App crashes, data loss, core feature broken
- **High:** Feature doesn't work as expected, major UX issue
- **Medium:** Minor bug, workaround available
- **Low:** Cosmetic issue, typo, small UX improvement

**Reporting Channels:**
- Email: [your email]
- TestFlight feedback button (built-in)
- Bug report form: [link to Google Form]
- Beta tester group chat (if created)

---

## Feedback Collection

### Structured Feedback (Survey After 1 Week)

**Usability Questions:**
1. How easy was it to import your first recipe? (1-5)
2. How intuitive is the cooking mode? (1-5)
3. How useful is the shopping list feature? (1-5)
4. How satisfied are you with recipe scaling? (1-5)
5. How likely are you to use dinner party planning? (1-5)
6. Overall satisfaction with the app (1-5)

**Open-Ended Questions:**
1. What's your favorite feature?
2. What's the most frustrating part of using Heirloom?
3. What feature is missing that you expected to have?
4. Which recipe sources would you like to see supported?
5. Would you recommend Heirloom to friends/family? Why or why not?

**Feature Prioritization:**
Rank these potential features by importance:
- [ ] Meal planning calendar
- [ ] Nutrition information
- [ ] Recipe PDF export
- [ ] Voice commands in cooking mode
- [ ] More recipe site support
- [ ] Recipe notes and variations
- [ ] Grocery delivery integration
- [ ] Social feed of shared recipes

---

## Success Metrics

### Quantitative Metrics
- **Crash-free rate:** > 99%
- **Recipe import success rate:** > 85%
- **Average recipes per user:** > 10
- **Shopping list export success:** > 95%
- **CloudKit sync success:** > 98%
- **Cooking mode completion rate:** > 70%
- **Daily active users:** 40%+ of beta testers
- **Retention after week 1:** > 60%

### Qualitative Metrics
- Average satisfaction score: > 4.0/5.0
- Net Promoter Score: > 30
- Feature satisfaction: > 80% positive
- Critical bugs reported: < 5
- "Would recommend" rate: > 70%

---

## Beta Build Distribution Strategy

### Build Cadence
- **Beta 1:** Initial release (Week 1, Day 1)
- **Beta 2:** Bug fixes and critical improvements (Week 1, Day 5)
- **Beta 3:** Feature refinements (Week 2, Day 7)
- **Beta 4:** Final polish and edge case fixes (Week 3, Day 14)
- **Release Candidate:** If all metrics met (Week 4)

### Build Notes Template
```
Heirloom Beta [Build Number] - [Date]

What's New:
- [Feature additions]
- [Improvements]

Bug Fixes:
- [Fixed issues from previous build]

Known Issues:
- [Issues still being worked on]

Testing Focus This Build:
- [Specific areas to test]

Thank you for testing!
```

---

## Risk Assessment & Mitigation

### Critical Risks

**1. CloudKit Sync Failures**
- **Risk:** Data loss or sync conflicts
- **Mitigation:** Extensive multi-device testing, backup to local storage, version conflict resolution
- **Contingency:** Disable CloudKit sync if critical issues found, ship with local-only mode

**2. Recipe Import Failures**
- **Risk:** Low success rate frustrates users
- **Mitigation:** Test against 50+ recipe sites, graceful fallback to manual entry
- **Contingency:** Clearly communicate supported sites, improve manual entry UX

**3. Reminders Integration Bugs**
- **Risk:** Shopping list export fails or duplicates items
- **Mitigation:** Test permission flows, verify EventKit API usage
- **Contingency:** Offer copy-to-clipboard alternative

**4. Low Beta Tester Engagement**
- **Risk:** Insufficient feedback to validate product
- **Mitigation:** Clear onboarding, mid-beta check-ins, incentives for feedback
- **Contingency:** Extend beta period, recruit additional testers

**5. Performance Issues with Large Recipe Libraries**
- **Risk:** App slows down with 100+ recipes
- **Mitigation:** Test with synthetic large datasets, implement pagination
- **Contingency:** Add performance optimizations in future update

---

## Post-Beta Launch Criteria

### Go/No-Go Decision Criteria

**Required (Must Meet All):**
- [ ] Crash-free rate > 98%
- [ ] No critical bugs outstanding
- [ ] CloudKit sync working reliably (>95% success)
- [ ] Recipe import success rate > 80%
- [ ] Shopping list export functional
- [ ] Cooking mode usable without major issues
- [ ] Privacy policy published
- [ ] App Store screenshots and metadata ready

**Desired (Meet 4/6):**
- [ ] Average satisfaction > 4.0/5.0
- [ ] 60%+ retention after week 1
- [ ] Net Promoter Score > 30
- [ ] 10+ recipes per user average
- [ ] All priority 1 test scenarios passing
- [ ] Positive feedback on unique features (scaling, dinner party)

---

## Timeline

### Week 0: Pre-Launch
- Finalize beta build
- Set up App Store Connect
- Prepare communication materials
- Recruit beta testers

### Week 1: Internal + Early Beta
- Monday: Internal testing begins
- Friday: Invite first 10 beta testers (Closed Beta Phase)
- Monitor crashes and critical bugs daily

### Week 2: Expanded Beta
- Monday: Invite full beta group (20-30 testers)
- Wednesday: Send check-in email with tips
- Friday: Release Beta 2 with bug fixes

### Week 3: Feedback Collection
- Monday: Send mid-beta survey
- Wednesday: Release Beta 3 with refinements
- Friday: Analyze feedback and prioritize changes

### Week 4: Final Testing
- Monday: Release Beta 4 (Release Candidate)
- Wednesday: Final bug triage
- Friday: Go/No-Go decision for public launch

---

## Beta Tester Incentives (Optional)

### Suggested Incentives
1. **Free lifetime Pro features** (if freemium model planned)
2. **Credit in app** ("Special thanks to our beta testers")
3. **Early access** to future features
4. **Exclusive beta tester badge** in app (if social features added)
5. **Amazon gift card raffle** ($25-50 for most active testers)

---

## Support & Communication Plan

### Tester Communication Cadence
- **Day 1:** Welcome email with TestFlight instructions
- **Day 3:** Check-in email: "How's it going?"
- **Day 7:** Mid-beta survey
- **Day 14:** Feature spotlight: "Did you know Heirloom can...?"
- **Day 21:** Final feedback request
- **Day 28:** Thank you email + next steps

### Support Channels
- Email support: [your email]
- Response time goal: < 24 hours
- FAQ document for common issues
- TestFlight feedback review daily

---

## Privacy & Data Handling

### Beta Tester Data Collection
- **Analytics:** Basic usage events (screen views, feature usage)
- **Crash reports:** Automatic via TestFlight
- **CloudKit data:** Recipes stored in tester's personal iCloud
- **No PII collection** beyond Apple-provided tester emails

### Data Retention
- Beta tester data retained for 90 days post-beta
- CloudKit data remains in user's iCloud indefinitely
- Analytics data anonymized

### Transparency
- Privacy policy clearly states beta data collection
- Testers can opt out of analytics (if implemented)
- All data handling complies with Apple's guidelines

---

## Appendix: Known Limitations

### Current Beta 1 Limitations
1. **Cookbook scanning:** UI exists but OCR not yet implemented
2. **Analytics:** Console logging only (Mixpanel not active)
3. **Limited recipe sites:** AllRecipes, Serious Eats, King Arthur Baking confirmed; others may work but not tested
4. **No push notifications:** Cooking timers are local only
5. **No iPad optimization:** Works on iPad but not optimized layout
6. **CloudKit monitoring dashboard:** Visible but not fully tested under load
7. **Card personalization:** Some features may need refinement

### Out of Scope for Beta 1
- Meal planning calendar
- Nutrition information
- PDF export
- Voice commands
- AirDrop sharing
- Social feed
- Grocery delivery integration

---

## Contact Information

**Beta Program Manager:** [Your Name]
**Email:** [Your Email]
**Emergency Contact:** [Your Phone - for critical issues only]

**TestFlight Link:** [Will be provided after App Store Connect setup]

---

## Version History

- **v1.0 (2025-12-09):** Initial beta testing plan created

---

**Next Steps:**
1. Review and approve this beta testing plan
2. Complete pre-launch checklist
3. Build and upload to TestFlight
4. Send beta tester invitations
5. Begin Phase 1 internal testing
