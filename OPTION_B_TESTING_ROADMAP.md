# Option B: Full Validation Testing Roadmap

**Purpose:** Comprehensive pre-merge testing for Share Extension flagship feature
**Total Time:** 4-5 hours
**Status:** 🟡 Ready to Begin

---

## Overview

This roadmap guides you through thorough testing before merging to main. Each phase builds on the previous one.

**Why Option B?**
> "Social sharing is a dealbreaker. We need to be confident this works flawlessly before shipping to production."

---

## Phases Overview

| Phase | Time | Document | Status |
|-------|------|----------|--------|
| **1. Xcode Integration** | 30 min | PHASE_1_XCODE_INTEGRATION.md | ⬜ Not Started |
| **2. Device Setup** | 15 min | PHASE_2_DEVICE_SETUP.md | ⬜ Not Started |
| **3. Platform Testing** | 60 min | PHASE_3_PLATFORM_TESTING.md | ⬜ Not Started |
| **4. Three-Tier Cascade** | 30 min | PHASE_4_CASCADE_TESTING.md | ⬜ Not Started |
| **5. Error Handling** | 45 min | PHASE_5_ERROR_TESTING.md | ⬜ Not Started |
| **6. Deep Link Handoff** | 20 min | PHASE_6_HANDOFF_TESTING.md | ⬜ Not Started |
| **7. Performance & UX** | 30 min | PHASE_7_PERFORMANCE_TESTING.md | ⬜ Not Started |
| **8. Paywall** | 15 min | PHASE_8_PAYWALL_TESTING.md | ⬜ Not Started |
| **9. Regression** | 20 min | PHASE_9_REGRESSION_TESTING.md | ⬜ Not Started |
| **10. Final Checklist** | 10 min | PHASE_10_FINAL_CHECKLIST.md | ⬜ Not Started |
| **TOTAL** | **4-5 hours** | | **⬜** |

---

## Phase Details

### Phase 1: Xcode Integration (30 min)
**Goal:** Get everything building and running
**Document:** `PHASE_1_XCODE_INTEGRATION.md`

**What you'll do:**
- Add files to correct Xcode targets
- Configure App Groups
- Set up URL scheme for deep links
- Verify corporate Anthropic API key
- Build main app, Share Extension, and tests
- Run app on physical iPhone

**Success Criteria:**
- ✅ Clean builds (no errors)
- ✅ All 55 unit tests pass
- ✅ App runs on device
- ✅ Share Extension appears in share sheet

**Start Here →** Open `PHASE_1_XCODE_INTEGRATION.md`

---

### Phase 2: Device Testing Setup (15 min)
**Goal:** Prepare iPhone for comprehensive testing
**Document:** `PHASE_2_DEVICE_SETUP.md`

**What you'll do:**
- Verify iOS 17+ on device
- Install TikTok, Instagram, YouTube apps
- Enable Developer Mode
- Configure Share Extension permissions
- Find sample recipe videos for testing
- Run basic smoke test

**Success Criteria:**
- ✅ Apps installed
- ✅ Share Extension enabled
- ✅ Sample videos ready
- ✅ Basic share flow works

---

### Phase 3: Platform-Specific Testing (60 min)
**Goal:** Test all supported platforms
**Document:** `PHASE_3_PLATFORM_TESTING.md`

**What you'll test:**
- TikTok full URLs, short URLs (vm.tiktok.com)
- Instagram Reels
- YouTube Shorts and regular videos
- YouTube short links (youtu.be)
- Facebook Watch videos
- URL detection from text

**Success Criteria:**
- ✅ All platforms detected correctly
- ✅ Video IDs extracted
- ✅ Creator attribution shown
- ✅ Recipes created successfully

---

### Phase 4: Three-Tier Cascade Testing (30 min)
**Goal:** Verify extraction mode selection
**Document:** `PHASE_4_CASCADE_TESTING.md`

**What you'll test:**
- Tier 1: Good audio → Audio Transcript mode (free)
- Tier 2: Poor audio → OCR mode (free)
- Tier 3: Visual mode (premium only)
- Mode recommendations and reasoning

**Success Criteria:**
- ✅ Correct mode selected automatically
- ✅ Reasoning displayed to user
- ✅ Free tiers work without paywall
- ✅ Premium tier blocked for free users

---

### Phase 5: Error Handling & Edge Cases (45 min)
**Goal:** Ensure robustness
**Document:** `PHASE_5_ERROR_TESTING.md`

**What you'll test:**
- Malformed URLs
- Non-video URLs
- Network failures
- Extremely long URLs
- Unicode/emoji in URLs
- Silent videos
- Very short/long videos

**Success Criteria:**
- ✅ No crashes in any scenario
- ✅ Clear error messages
- ✅ Graceful degradation

---

### Phase 6: Deep Link Handoff Testing (20 min)
**Goal:** Verify Share Extension → Main App flow
**Document:** `PHASE_6_HANDOFF_TESTING.md`

**What you'll test:**
- Share Extension saves to shared container
- Deep link opens main app
- Video import sheet appears
- Pending import processed correctly
- Cleanup after import

**Success Criteria:**
- ✅ Handoff smooth (<2 seconds)
- ✅ No data loss
- ✅ Files cleaned up properly

---

### Phase 7: Performance & UX Testing (30 min)
**Goal:** Measure speed and user experience
**Document:** `PHASE_7_PERFORMANCE_TESTING.md`

**What you'll test:**
- Share Extension load time
- Audio analysis time
- Full end-to-end import time
- Progress indicators
- Attribution display
- Cancel/dismiss behavior

**Success Criteria:**
- ✅ Share Extension loads <3s
- ✅ Full import completes <30s
- ✅ Clear feedback at every step
- ✅ Attribution shows correctly

---

### Phase 8: Subscription/Paywall Integration (15 min)
**Goal:** Verify premium features gated correctly
**Document:** `PHASE_8_PAYWALL_TESTING.md`

**What you'll test:**
- Free user can't access Visual mode
- Premium user can access Visual mode
- Paywall displays correctly
- Usage tracking works

**Success Criteria:**
- ✅ Paywall blocks free users
- ✅ Premium users bypass paywall
- ✅ Can downgrade to free modes

---

### Phase 9: Regression Testing (20 min)
**Goal:** Ensure existing features still work
**Document:** `PHASE_9_REGRESSION_TESTING.md`

**What you'll test:**
- Manual video import (non-share)
- Other recipe import methods
- Existing deep links
- Core app functionality

**Success Criteria:**
- ✅ No regressions
- ✅ Existing features unaffected

---

### Phase 10: Final Checklist & Sign-Off (10 min)
**Goal:** Verify merge readiness
**Document:** `PHASE_10_FINAL_CHECKLIST.md`

**What you'll do:**
- Review all test results
- Check code quality
- Verify documentation
- Get stakeholder approval
- Prepare for merge

**Success Criteria:**
- ✅ All phases complete
- ✅ All tests passed
- ✅ Team sign-off obtained
- ✅ Ready to merge to main

---

## How to Use This Roadmap

### Step-by-Step Approach:

1. **Start with Phase 1**
   - Open `PHASE_1_XCODE_INTEGRATION.md`
   - Follow every step in order
   - Check off items as you complete them
   - Don't skip to Phase 2 until Phase 1 is 100% complete

2. **Complete Each Phase Sequentially**
   - Each phase builds on the previous
   - If a phase fails, stop and fix before continuing
   - Mark phase status in table above

3. **Track Your Progress**
   - Use checkboxes in each phase document
   - Note actual time taken vs. estimated
   - Document any issues encountered

4. **Take Breaks**
   - After Phase 2, 4, 6, 8 - good stopping points
   - You can resume later
   - Phases are self-contained

---

## Quick Start

**Right now:**

```bash
# 1. You're on the right branch
git branch
# Should show: feature/share-extension-unified-import

# 2. Open Xcode
open Heirloom.xcodeproj

# 3. Open Phase 1 document
open PHASE_1_XCODE_INTEGRATION.md

# 4. Start following Phase 1 steps
```

**Work through phases in order:**
1. Phase 1 (Xcode) → Get builds working
2. Phase 2 (Setup) → Prepare device
3. Phase 3-9 (Testing) → Comprehensive validation
4. Phase 10 (Final) → Merge preparation

---

## Success Metrics

**Before merge, you must have:**

- ✅ All 10 phases complete (100% of checkboxes)
- ✅ Zero crashes during testing
- ✅ Zero critical bugs found
- ✅ Performance within targets (<30s E2E)
- ✅ All supported platforms working
- ✅ Paywall functioning correctly
- ✅ Stakeholder approval

**Critical Test Cases (Must Pass):**
1. TikTok recipe video → Recipe card (flawless)
2. Instagram Reel → Recipe card (flawless)
3. YouTube Shorts → Recipe card (flawless)
4. Attribution displays correctly
5. Paywall blocks free users from premium features
6. No crashes in any error scenario

**If ANY critical test fails:** Do NOT merge. Fix and re-test.

---

## Emergency Contacts

**If you encounter blocking issues:**

1. **Build Errors:** Check Phase 1, Step 1.10-1.11 common issues
2. **Share Extension not appearing:** Phase 2, Step 2.4
3. **Deep link not working:** Phase 1, Step 1.7 (URL scheme)
4. **API errors:** Phase 1, Step 1.8 (verify API key)
5. **Other issues:** Check individual phase troubleshooting sections

---

## Estimated Schedule

**Option A: Full-Day Testing (Recommended)**
- Morning (2 hours): Phases 1-4
- Lunch break
- Afternoon (2 hours): Phases 5-8
- End of day (30 min): Phases 9-10
- **Total:** 4.5 hours + breaks

**Option B: Two-Day Testing**
- Day 1: Phases 1-5 (2.5 hours)
- Day 2: Phases 6-10 (2 hours)
- **Total:** 4.5 hours over 2 days

**Option C: One Week (Casual)**
- Day 1: Phases 1-2 (45 min)
- Day 2: Phase 3 (60 min)
- Day 3: Phases 4-5 (75 min)
- Day 4: Phases 6-7 (50 min)
- Day 5: Phases 8-10 (45 min)
- **Total:** ~4.5 hours over 5 days

Choose the schedule that works for you. Just ensure you complete all phases before merge.

---

## After Testing Complete

### When All Phases Pass:

```bash
# 1. Create pull request or merge directly
git checkout main
git merge feature/share-extension-unified-import

# 2. Push to remote
git push origin main

# 3. Monitor post-merge
# - Watch crash reports
# - Track Share Extension usage analytics
# - Monitor Claude API costs
# - Collect user feedback
```

### If Critical Issues Found:

```bash
# DO NOT MERGE
# 1. Document issues in GitHub Issues
# 2. Fix on feature branch
# 3. Re-test affected phases
# 4. Repeat until all pass
```

---

## Phase Status Tracker

| Phase | Started | Completed | Time | Issues | Status |
|-------|---------|-----------|------|--------|--------|
| 1. Xcode | ___ | ___ | ___ min | ___ | ⬜ |
| 2. Setup | ___ | ___ | ___ min | ___ | ⬜ |
| 3. Platforms | ___ | ___ | ___ min | ___ | ⬜ |
| 4. Cascade | ___ | ___ | ___ min | ___ | ⬜ |
| 5. Errors | ___ | ___ | ___ min | ___ | ⬜ |
| 6. Handoff | ___ | ___ | ___ min | ___ | ⬜ |
| 7. Performance | ___ | ___ | ___ min | ___ | ⬜ |
| 8. Paywall | ___ | ___ | ___ min | ___ | ⬜ |
| 9. Regression | ___ | ___ | ___ min | ___ | ⬜ |
| 10. Final | ___ | ___ | ___ min | ___ | ⬜ |

---

**Current Status:** 🟡 Ready to Begin
**Next Step:** Open `PHASE_1_XCODE_INTEGRATION.md` and start!
**Goal:** Merge-ready flagship feature with zero critical bugs

**Let's build something amazing! 🚀**
