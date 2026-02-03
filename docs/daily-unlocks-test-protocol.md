# Daily Unlocks Pre-Deployment Test Protocol

> **Purpose**: Ensure daily unlock system works correctly before deploying to production users

**Last Updated**: 2026-02-02
**Version**: 1.0

---

## Overview

This document outlines the comprehensive testing protocol that must be completed before deploying any changes that affect the daily unlock system. The protocol includes manual testing, automated testing, and verification steps.

## Pre-Deployment Checklist Summary

Before deploying, verify ALL of the following:

- ✅ New integration tests pass (8 test methods)
- ✅ Manual testing checklist complete (6 sections)
- ✅ Verification script shows "healthy" status
- ✅ Logs show correct unlock behavior
- ✅ No crashes in 10 unlock cycles
- ✅ Performance benchmarks met

**If any fail**: Do NOT deploy. Fix issues first.

---

## Part 1: Manual Testing Checklist

### 1.1 Fresh Install Test

**Goal**: Verify new users see Day 1 recipes immediately

**Steps**:
1. Delete Heirloom app from device/simulator
2. Install fresh build from Xcode
3. Complete onboarding flow
4. Select 3 different themes
5. Navigate to Discover tab

**Expected Results**:
- [ ] Initial recipes appear immediately
- [ ] Recipe count is approximately 7-10 recipes (Day 1)
- [ ] Recipes show theme attribution
- [ ] No locked recipe indicators
- [ ] Trial tracker shows "Day 1 / 14"

**How to Verify**:
```
Open Settings > Trial Debug
Check "Current Day" shows 1
Check "Days Remaining" shows 14
```

---

### 1.2 Day Progression Test

**Goal**: Verify new recipes unlock each day

**Steps**:
1. Start from fresh install (Day 1)
2. Open Settings → Trial Debug
3. Tap "Skip Ahead 1 Day"
4. Force quit app (swipe up from multitasking)
5. Reopen app
6. Navigate to Discover tab
7. Count new recipes
8. Repeat for days 2-7

**Expected Results** (per day):
- [ ] Day 2: Count increases by ~7 recipes
- [ ] Day 3: Count increases by ~7 recipes
- [ ] Day 4: Count increases by ~7 recipes
- [ ] Day 5: Count increases by ~7 recipes
- [ ] Day 6: Count increases by ~7 recipes
- [ ] Day 7: Count increases by ~7 recipes
- [ ] Total by Day 7: ~49 recipes

**How to Track**:
```
Day 1: ___ recipes
Day 2: ___ recipes (+___ new)
Day 3: ___ recipes (+___ new)
Day 4: ___ recipes (+___ new)
Day 5: ___ recipes (+___ new)
Day 6: ___ recipes (+___ new)
Day 7: ___ recipes (+___ new)
```

---

### 1.3 Edge Case Testing

**Goal**: Verify system handles unusual scenarios gracefully

#### Test 3A: Trial Expiry (Day 15)
**Steps**:
1. Open Settings → Trial Debug
2. Tap "Skip to Day 15 (Expired)"
3. Navigate to Discover tab

**Expected**:
- [ ] All recipes remain accessible
- [ ] No crashes or errors
- [ ] Trial tracker shows "Trial Complete"
- [ ] Days remaining shows "0"

#### Test 3B: App Backgrounding During Unlock
**Steps**:
1. Set to Day 6 evening
2. Skip ahead 1 day (now Day 7)
3. While on Discover tab, background app (home button)
4. Wait 5 seconds
5. Foreground app

**Expected**:
- [ ] New recipes appear when foregrounding
- [ ] Toast notification shows "New recipes unlocked!"
- [ ] No crashes or visual glitches

#### Test 3C: Force Quit During Unlock Check
**Steps**:
1. Skip ahead 1 day
2. Immediately force quit (before seeing new recipes)
3. Reopen app

**Expected**:
- [ ] New recipes still appear on reopen
- [ ] Unlock state persists correctly
- [ ] No duplicate unlock notifications

#### Test 3D: Offline Mode
**Steps**:
1. Enable Airplane Mode
2. Skip ahead 1 day
3. Trigger unlock check

**Expected**:
- [ ] Unlock still works (uses local UserDefaults)
- [ ] No network error messages related to unlocks
- [ ] Recipes appear normally

#### Test 3E: No Themes Selected
**Steps**:
1. Reset trial
2. Skip onboarding theme selection (if possible)
3. Check unlock behavior

**Expected**:
- [ ] No crashes
- [ ] Trial tracker shows warning in debug view
- [ ] Graceful handling of empty theme list

---

### 1.4 Integration Testing

**Goal**: Run automated test suite

**Command**:
```bash
cd /Users/matthanson/Heirloom
xcodebuild test \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:HeirloomTestsV2/DailyUnlockIntegrationTest
```

**Expected Results**:
- [ ] ✅ `testFreshInstallUnlocksDayOne` - PASSED
- [ ] ✅ `testDayProgressionUnlocksNewRecipes` - PASSED
- [ ] ✅ `testFullUnlockCycle` - PASSED
- [ ] ✅ `testExpiredTrialShowsAllRecipes` - PASSED
- [ ] ✅ `testCatchUpUnlock` - PASSED
- [ ] ✅ `testRecipeWithoutUnlockDayAlwaysUnlocked` - PASSED
- [ ] ✅ `testInvalidUnlockDayHandling` - PASSED
- [ ] ✅ `testNewUnlockDetection` - PASSED

**If any tests fail**:
1. Review test output logs
2. Check Console.app for diagnostic logs
3. Fix issues before proceeding
4. Re-run tests until all pass

---

### 1.5 Verification Script

**Goal**: Validate unlock system health via debug UI

**Steps**:
1. Open Settings → Trial Debug
2. Scroll to "Unlock Verification" section
3. Tap "🔍 Verify Unlock System"
4. Review toast message and console output

**Expected Results**:
- [ ] Toast shows "✅ Verification Passed"
- [ ] No errors in console output
- [ ] Warnings (if any) are documented and acceptable

**Sample Healthy Output**:
```
=== Unlock System Verification ===
✅ Unlock system is healthy
=================================
```

**If Verification Fails**:
```
=== Unlock System Verification ===
❌ Unlock system has errors

Errors:
  • Recipe 'Test Recipe' has invalid unlockDay: 99

Warnings:
  • 3 theme recipes missing unlockDay property
=================================
```

Document any warnings and confirm they're expected.

---

### 1.6 Log Review

**Goal**: Verify unlock events are logged correctly

**Steps**:
1. Delete and reinstall app
2. Enable Settings → Debug Logging (if available)
3. Complete onboarding, select themes
4. Skip ahead 3 days (Day 1 → 2 → 3 → 4)
5. Open Settings → Trial Debug
6. Tap "📊 Export Debug Log"
7. Review copied log

**Expected Log Entries** (sample):
```
=== Daily Unlock Debug Log ===
Generated: 2026-02-02 15:30:00

Trial Status:
  Current Day: 4 / 14
  Days Remaining: 11
  Trial Start: 2026-01-30 15:30:00
  Is In Trial: true
  Is Complete: false

Selected Themes:
  • automat
  • presidential
  • retro-tech

Recipe Status:
  Total Theme Recipes: 98
  Unlocked: 28
  Locked: 70

Unlock Timeline:
  ✅ Day 1: 7 recipes
  ✅ Day 2: 7 recipes
  ✅ Day 3: 7 recipes
  ✅ Day 4: 7 recipes
  🔒 Day 5: 7 recipes
  ...

Verification:
✅ Unlock system is healthy
```

**Checklist**:
- [ ] Trial day matches expected (Day 4)
- [ ] Unlocked count matches (4 days × 7 = 28 recipes)
- [ ] Unlock timeline shows correct icons (✅/🔒)
- [ ] Verification shows healthy
- [ ] No errors in log

**View Console Logs** (optional):
```bash
# Filter for trial category logs
log stream --predicate 'subsystem == "com.heirloom.app" AND category == "Trial"' --level debug
```

Expected log entries:
```
INFO: Trial day updated [currentDay: 2, daysElapsed: 1]
INFO: Checking for new unlocks [hasNewUnlocks: true]
INFO: New unlocks available [unlockedDay: 2]
```

---

## Part 2: Performance Testing

### 2.1 Unlock Check Performance

**Goal**: Ensure unlock checks are fast

**Steps**:
1. Seed database with 100+ theme recipes
2. Measure time to check all recipes for unlock status
3. Repeat 10 times and average

**Benchmark**: < 100ms per full unlock check

**How to Test**:
```swift
// In TrialDebugView or test
let start = Date()
for recipe in allRecipes {
    _ = tracker.isUnlocked(recipe)
}
let duration = Date().timeIntervalSince(start)
print("Unlock check took: \(duration * 1000)ms")
```

**Expected**:
- [ ] Average time: ___ms (must be < 100ms)
- [ ] No visible lag in UI
- [ ] Smooth scrolling in recipe list

---

### 2.2 Memory Usage

**Goal**: Ensure unlock checks don't leak memory

**Steps**:
1. Open Xcode → Debug Navigator → Memory
2. Reset trial to Day 1
3. Skip ahead 14 days (one at a time)
4. Monitor memory graph

**Expected**:
- [ ] Memory increase < 5MB during unlock checks
- [ ] No memory leaks (Instruments confirms)
- [ ] Memory returns to baseline after check completes

---

### 2.3 Stability Test

**Goal**: Verify no crashes during repeated unlock cycles

**Steps**:
1. Write simple script to cycle through days 1-14, 100 times
2. Run overnight
3. Check crash logs

**Expected**:
- [ ] No crashes in 100 cycles
- [ ] App remains responsive
- [ ] No zombie objects or leaks

---

## Part 3: Deployment Criteria

### All Criteria Must Pass

Before deploying to production, verify:

#### ✅ Automated Tests
- [ ] All 8 integration tests pass
- [ ] No test failures or timeouts
- [ ] Test coverage report generated

#### ✅ Manual Tests
- [ ] Fresh install test completed
- [ ] Day progression test (Days 1-7) completed
- [ ] Edge cases tested (5 scenarios)
- [ ] All checklist items marked complete

#### ✅ Verification
- [ ] Verification script shows "healthy"
- [ ] No errors reported
- [ ] Warnings documented and acceptable

#### ✅ Logging
- [ ] Unlock events logged correctly
- [ ] Debug log export works
- [ ] Console logs show expected entries

#### ✅ Performance
- [ ] Unlock check time < 100ms
- [ ] Memory increase < 5MB
- [ ] No memory leaks detected

#### ✅ Stability
- [ ] No crashes in 10+ unlock cycles
- [ ] Force quit/reopen works correctly
- [ ] App remains responsive

---

## Part 4: If Tests Fail

### Failure Response Protocol

**If ANY test fails**:

1. **STOP** - Do not deploy
2. **Document** - Record which test failed and error details
3. **Fix** - Address the root cause
4. **Re-test** - Run FULL protocol again (not just failed test)
5. **Review** - Have another developer review the fix
6. **Deploy** - Only after all tests pass

### Common Issues & Solutions

#### Issue: Integration tests fail to compile
**Solution**: Verify test target has correct dependencies and build settings

#### Issue: Unlock count doesn't match expected
**Solution**: Check theme recipe data in Firebase, verify unlockDay values

#### Issue: Verification shows warnings
**Solution**: Review warnings, confirm they're expected (e.g., legacy recipes without unlockDay)

#### Issue: Performance benchmark fails
**Solution**: Profile with Instruments, optimize unlock logic if needed

#### Issue: Memory leak detected
**Solution**: Check for retain cycles, verify proper cleanup in tracker

---

## Part 5: Rollback Plan

If critical issues are discovered after deployment:

### Option A: Feature Flag Disable
```swift
// In FeatureFlags
var enableDailyUnlocks: Bool = false // Set via remote config
```

**Effect**: Disables progressive unlocks, shows all recipes immediately

### Option B: Hotfix Deployment
1. Revert problematic commit
2. Run abbreviated test protocol (automated tests + verification)
3. Deploy emergency build
4. Monitor crash reports and user feedback

### Option C: Emergency Unlock All
```swift
// In ThemeUnlockTracker
func emergencyUnlockAll() {
    // Override unlock logic to return true for all recipes
}
```

**Effect**: Temporarily unlocks everything until proper fix deployed

---

## Part 6: Post-Deployment Monitoring

After deploying, monitor for 48 hours:

### Metrics to Watch

#### Analytics
- [ ] Track unlock success rate (target: > 95%)
- [ ] Monitor daily active users receiving unlocks
- [ ] Track time-to-first-unlock after install

#### Crash Reports
- [ ] Check Crashlytics for unlock-related crashes
- [ ] Filter by `ThemeUnlockTracker` stack traces
- [ ] Alert if crash rate > 0.1%

#### User Feedback
- [ ] Monitor support tickets for unlock issues
- [ ] Search App Store reviews for "unlock" or "locked"
- [ ] Check in-app feedback for complaints

#### Server Logs (if applicable)
- [ ] Review Firebase logs for unlock sync errors
- [ ] Check for unusual patterns in unlock timing
- [ ] Monitor database query performance

### Success Indicators

After 48 hours, verify:
- [ ] No critical unlock-related bugs reported
- [ ] Crash rate remains stable (< 0.1%)
- [ ] User feedback is positive or neutral
- [ ] Analytics show expected unlock patterns

### Failure Indicators

Alert if ANY of these occur:
- ❌ Crash rate increases > 0.5%
- ❌ Multiple users report "recipes not unlocking"
- ❌ Analytics show < 80% unlock success rate
- ❌ Server errors spike (if syncing unlocks)

**Response**: Implement rollback plan immediately

---

## Part 7: Test Maintenance

### Update Protocol When:

- New unlock logic is added
- Edge cases are discovered
- Performance requirements change
- User feedback identifies gaps

### Quarterly Review

Every 3 months:
- [ ] Review test protocol for completeness
- [ ] Update benchmarks based on device performance
- [ ] Add new test cases for discovered issues
- [ ] Archive test results for compliance

---

## Appendix A: Test Commands Reference

### Run All Integration Tests
```bash
xcodebuild test \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:HeirloomTestsV2/DailyUnlockIntegrationTest
```

### Run Specific Test
```bash
xcodebuild test \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:HeirloomTestsV2/DailyUnlockIntegrationTest/testFreshInstallUnlocksDayOne
```

### Generate Test Coverage Report
```bash
xcodebuild test \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult
```

### View Console Logs (Live)
```bash
log stream --predicate 'subsystem == "com.heirloom.app" AND category == "Trial"' --level debug
```

### Export Console Logs (Last Hour)
```bash
log show --predicate 'subsystem == "com.heirloom.app" AND category == "Trial"' \
  --last 1h \
  --info \
  > unlock_logs_$(date +%Y%m%d_%H%M%S).txt
```

---

## Appendix B: Test Result Template

Copy this template for each pre-deployment test run:

```markdown
# Daily Unlocks Test Results

**Date**: ___________
**Tester**: ___________
**Build**: ___________
**Device**: ___________

## Manual Testing
- [ ] Fresh Install Test - PASS/FAIL
- [ ] Day Progression Test - PASS/FAIL
- [ ] Edge Case Tests (3A-3E) - PASS/FAIL
- [ ] Integration Tests (8 tests) - PASS/FAIL
- [ ] Verification Script - PASS/FAIL
- [ ] Log Review - PASS/FAIL

## Performance Testing
- [ ] Unlock Check Time: ___ms (< 100ms)
- [ ] Memory Usage: ___MB (< 5MB)
- [ ] Stability: ___/10 cycles passed

## Issues Found
1.
2.
3.

## Deployment Decision
- [ ] ✅ APPROVED FOR DEPLOYMENT
- [ ] ❌ BLOCKED - Issues must be fixed

**Notes**:
```

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-02-02 | Initial protocol created | Claude Code |

---

## Questions?

If you have questions about this protocol, contact:
- Engineering team for technical issues
- QA team for testing procedures
- Product team for acceptance criteria
