# Heirloom - Feature Backlog

**Last Updated**: 2026-01-10
**Current Version**: 1.3.1 (Build 4)

---

## Overview

This document tracks feature enhancements, improvements, and larger-scoped work items. For bugs, see `BUGS.md`. For launch planning, see `USER_MILESTONE_ROADMAP.md`.

**Priority Levels:**
- **P0**: Critical for next release
- **P1**: High priority, should do soon
- **P2**: Medium priority, nice to have
- **P3**: Low priority, future consideration

**Status:**
- 🔴 Not Started
- 🟡 In Progress
- 🟢 Completed
- 🔵 Blocked
- ⚪ Deferred

---

## Active Features

### Feature #1: Video-to-Recipe Robustness Improvements
**Status**: 🔴 Not Started
**Priority**: P1
**Added**: 2026-01-10
**Est. Duration**: 12-17 days (2.5-3.5 weeks full scope) OR 5-7 days (MVP)
**Owner**: TBD

**Current State:**
- ✅ Basic video import working (WhisperKit + Claude + augmentation)
- ✅ Watermark detection for creator attribution
- ✅ Recipe cards show clickable creator links
- ⚠️ Needs robustness improvements for production quality

**Proposed Improvements:**

#### 1. Transcription Phase (2-3 days)
- [ ] Audio quality detection + early failure warning
- [ ] Better noise/music handling (WhisperKit tuning)
- [ ] Multi-speaker detection (chef + guest)
- [ ] Multi-language support
- [ ] Testing with various audio conditions

**Impact**: Prevents bad audio from wasting API costs, improves accuracy

#### 2. Recipe Structuring (3-4 days)
- [ ] Improved ingredient parsing (handle "some", "a bit", "to taste")
- [ ] Smarter step extraction (implicit steps like "mix well")
- [ ] Substitution handling ("you can also use...")
- [ ] Non-recipe video detection (fail early, save costs)
- [ ] Enhanced Claude prompts + comprehensive testing

**Impact**: Core accuracy improvements users will notice most

#### 3. Augmentation & Validation (3-4 days)
- [ ] Better similarity matching algorithm (beyond basic keyword matching)
- [ ] Improved confidence scoring (more granular than 4 levels)
- [ ] Cross-validation of quantities across multiple sources
- [ ] Safety/danger detection (raw chicken handling, allergen warnings)
- [ ] Testing + refinement with real user recipes

**Impact**: Increases trust in AI-generated quantities, prevents dangerous recipes

#### 4. Error Handling (2-3 days)
- [ ] Better error messages (user-friendly, actionable)
- [ ] Graceful degradation (if augmentation fails, still show base recipe)
- [ ] Retry mechanisms with exponential backoff
- [ ] Intermediate result caching (transcript, frames) to avoid re-processing
- [ ] Error recovery UI (retry individual steps, not full pipeline)

**Impact**: Better UX, lower costs, faster iterations

#### 5. Edge Cases (2-3 days)
- [ ] Short video handling (< 1 min) - detect and warn
- [ ] Long video handling (> 30 min) - chunking or limits
- [ ] Silent/music-only detection - fail early
- [ ] Non-recipe detection (overlap with structuring)
- [ ] Multiple recipes in one video - extract all or prompt user

**Impact**: Prevents edge cases from breaking or confusing users

**Phased Approach:**

**Phase 1: Foundation (Week 1)** - 5-6 days
- Error handling improvements (#4)
- Audio quality detection (#1 - early failure)
- Non-recipe detection (#2)
- Edge case: short/long video handling (#5)

**Phase 2: Accuracy (Week 2)** - 4-5 days
- Improved recipe structuring (#2)
- Better confidence scoring (#3)
- Transcription improvements (#1)

**Phase 3: Intelligence (Week 3)** - 3-4 days
- Advanced augmentation & validation (#3)
- Multi-language support (#1)
- Multiple recipes detection (#5)

**MVP Alternative (1 week)** - High-impact subset:
1. Better error messages (1 day)
2. Non-recipe detection (1 day)
3. Improved ingredient parsing (2 days)
4. Edge case handling (1 day)
5. Intermediate caching (1 day)
6. Testing suite (1 day)

**Success Criteria:**
- [ ] 90%+ success rate for recipe videos (currently ~75%)
- [ ] < 5% false positives (non-recipe videos processed)
- [ ] Average processing cost < $0.05 per video (currently $0.027)
- [ ] User can understand and correct AI mistakes easily
- [ ] No crashes or hangs on edge case videos

**Dependencies:**
- WhisperKit SDK updates (if needed)
- Claude API budget allocation
- Test video corpus (collect 50+ diverse videos)

**Open Questions:**
1. Timeline pressure? Need for specific launch date?
2. Budget considerations? OK with API cost increases?
3. Priority ranking - which improvements are must-haves vs nice-to-haves?

**Testing Plan:**
- [ ] Create test suite of 50+ videos (recipe + non-recipe)
- [ ] Test across audio qualities (clean studio, noisy kitchen, music)
- [ ] Test across video lengths (30s, 5min, 15min, 30min+)
- [ ] Test across languages (English, Spanish, etc.)
- [ ] Performance testing (processing time, memory usage)

**Cost Analysis:**
- Current: $0.027 per 15-min video
- With improvements: Est. $0.03-0.05 per video (more API calls for validation)
- Potential savings: Better detection = fewer failed processing attempts

---

## Backlog (Not Prioritized)

### Feature #2: [Future feature]
**Status**: 🔴 Not Started
**Priority**: P3
**Added**: TBD

[Template for future features]

---

## Completed Features

### Example: Watermark Detection (v1.3.1)
**Status**: 🟢 Completed
**Completed**: 2026-01-09
**Duration**: 2 days

- ✅ Claude vision API integration
- ✅ Creator name extraction (@username)
- ✅ Platform detection (TikTok, YouTube, Instagram)
- ✅ Recipe card hyperlinks to creator profiles

---

## Feature Request Process

1. **Add to Backlog**: Create new section with template
2. **Estimate & Scope**: Break down into sub-tasks with time estimates
3. **Prioritize**: Assign P0-P3 based on impact and urgency
4. **Plan**: Create phased approach if large scope
5. **Execute**: Update status as work progresses
6. **Complete**: Move to "Completed Features" section

---

## Notes

- Keep this document focused on **features and improvements**
- Use **BUGS.md** for bug tracking
- Use **USER_MILESTONE_ROADMAP.md** for launch planning
- Link to detailed implementation plans in separate files if needed
