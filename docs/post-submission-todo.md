# Post-Submission To-Do

Issues identified during v2.6.3/v2.6.4 testing that are deferred until after App Store submission.

**Created:** 2026-02-24
**Source:** v2.6.3-manual-testing-checklist.md Issues Found section

---

## UI Polish

| # | Description | Severity | Notes |
|---|-------------|----------|-------|
| 3 | Share acceptance buttons should be side-by-side, not stacked | Low | RecipeReceiveSheet.swift |
| 4 | Share acceptance buttons should be at top after sender's message | Low | RecipeReceiveSheet.swift |
| 11 | Credits display has confusing ">" chevron (remove, keep functionality) | Low | SettingsView |
| 12 | Profile pic update is slow to propagate across touchpoints | Low | Caching issue |
| 13 | Profile edit sheet needs Done button moved to top right | Low | ProfileEditSheet |
| 20 | Collection tag flickers "complete" then "day 1" on load | Low | Theme collections |
| 23 | Pending recipe shares banner doesn't refresh while in Kitchen Table | Low | KitchenTableView |
| 24 | Toast text cropped - "Demo recipes can't be shared" message too long | Low | Toast system |
| 29 | Cooking mode step numbers in circles could be smaller/better centered | Low | CookingModeView |
| 39 | Developer settings password sheet takes multiple taps to open | Low | DeveloperSettingsView |

---

## Bugs

| # | Description | Severity | Notes |
|---|-------------|----------|-------|
| 9 | Connection profile doesn't show public recipes (only shared-with-me) | Medium | ConnectionProfileView |
| 14 | Connection invite fails after previous decline (tester01↔tester02 broken) | Medium | Connection state issue |
| 15 | Download button not showing — heritageChain/sharedBy condition may not populate | Medium | Verify condition logic |
| 18 | Website field missing from profile setup | Low | OnboardingProfileView |
| 22 | Profile picture in-app edit: not saving or round-trip so slow it appears broken | Medium | Investigate Firebase Storage |

---

## UX Improvements

| # | Description | Severity | Notes |
|---|-------------|----------|-------|
| 6 | No affordance for outbound pending requests (sender can't see sent invites) | Medium | Add pending requests tab |
| 7 | No notification when connection request is declined | Low | Privacy vs UX tradeoff |
| 8 | Connection profile missing: location, bio, interests, web link | Medium | PublicProfile expansion |
| 16 | Email sign-up UI hard to reach — needs split button login/signup | Medium | AuthenticationView |
| 17 | Duplicate password confirmation field never implemented | Low | EmailSignUpView |
| 21 | Profile sync on sign-in should only sync display name, not overwrite state | Medium | ProfileService |
| 33 | "Save locally" explainer insufficient on first trigger | Low | Education modal |

---

## Enhancements

| # | Description | Severity | Notes |
|---|-------------|----------|-------|
| 30 | Cooking mode "+X more ingredients" should be tappable to expand | Low | CookingModeView |
| 31 | Cooking mode: highlight ingredients used in current step (green bullets) | Low | Already partially implemented |
| 32 | Version selector not visible during cooking mode | Low | CookingModeView toolbar |
| 35 | Move Intelligence (AI feature) section inside Developer settings | Low | SettingsView reorganization |
| 37 | Add Discord server link to Help Center / Support section | Low | HelpCenterView |

---

## Content

| # | Description | Severity | Notes |
|---|-------------|----------|-------|
| 36 | Help Center articles are empty — need content | Medium | HelpCenterView |
| 38 | Review Gestures Guide and FAQ for thoroughness and accuracy | Low | Documentation review |

---

## Data Issues

| # | Description | Severity | Notes |
|---|-------------|----------|-------|
| 10 | tester01 has 3 Favorites collections (should be 1) — stale data | Low | Run reset script |
| 25 | Demo recipe lineage polluted with stale test data (Test User 02) | Low | Sanitize demo accounts |
| 26 | Lineage shows duplicate Gen 2 entries from stale test data | Low | Data cleanup |

---

## Performance

| # | Description | Severity | Notes |
|---|-------------|----------|-------|
| 34 | Saving edited recipes takes 12+ seconds with multiple network operations | High | Investigate sync chain |
| 1 | Recipes don't download until hard quit | Low | Background sync timing |

---

## Recently Fixed (v2.6.4)

| # | Description | Fix |
|---|-------------|-----|
| 5 | Generation numbering jumps (Gen 0 → Gen 2) | Sequential display generation in LineageTimelineView |
| 19 | Sign out/in forced full onboarding again | Profile sync preserves onboarding state |
| 27 | "0 shares" line break issue in lineage view | Text wrapping fix |
| 28 | Cooking mode "0 done" counter always shows 0 | Auto-increment on Next button |
| 40 | Demo recipe share scheduled but never executed | Task cancellation fix |
| 41 | Offline mode hides entire lineage | heritageChainNames fallback display |

---

## Priority Order (Post-Submission)

### High Priority
1. **#34** - Recipe save performance (12+ seconds)
2. **#22** - Profile picture edit broken
3. **#36** - Help Center content

### Medium Priority
4. **#9** - Connection profile public recipes
5. **#14** - Connection invite after decline
6. **#21** - Profile sync overwrites state
7. **#8** - Connection profile fields
8. **#6** - Outbound pending requests UI
9. **#16** - Email sign-up accessibility

### Low Priority (Polish Pass)
10. All UI Polish items (3, 4, 11, 12, 13, 20, 23, 24, 29, 39)
11. All Enhancement items (30, 31, 32, 35, 37)
12. Content items (38)
13. Data cleanup (10, 25, 26)
