# Heirloom Collections Overhaul
## Phase Index

**Repository:** https://github.com/RationaleDesignHanson/Heirloom
**Date:** January 26, 2026

---

## Overview

This overhaul transforms Heirloom's collections from empty containers into a curated discovery experience. Users choose themes during onboarding, receive recipes progressively over 14 days, and are encouraged to add their own.

---

## Phase Execution Order

| Phase | Name | Est. Time | Dependencies |
|-------|------|-----------|--------------|
| **A1** | Theme Model & Types | 30-45 min | None |
| **A2** | Rename Heritage → Theme | 20-30 min | A1 |
| **A3** | Theme Unlock Tracker | 45-60 min | A1, A2 |
| **B1** | Theme Selection UI | 60-90 min | A1, A2, A3 |
| **B2** | Onboarding Integration | 30-45 min | B1 |
| **C1** | Collection Routing | 45-60 min | A1 |
| **D1** | Collections List Updates | 45-60 min | A1, C1 |
| **D2** | UX Nudges | 30-45 min | D1 |

**Total Estimated Time:** 5-7 hours

---

## Phase Files

### Foundation (Phase A)

1. **[phase-A1-theme-model.md](./phase-A1-theme-model.md)**
   - Create `RecipeTheme` model
   - Create `CollectionType` enum
   - Update `RecipeCollection` model
   - Update `Recipe` model

2. **[phase-A2-rename-services.md](./phase-A2-rename-services.md)**
   - Rename Heritage → Theme services
   - Update imports throughout codebase
   - Migrate UserDefaults keys

3. **[phase-A3-unlock-tracker.md](./phase-A3-unlock-tracker.md)**
   - Rewrite `ThemeUnlockTracker`
   - Add theme selection persistence
   - Create `TrialStateViewModel`

### Onboarding (Phase B)

4. **[phase-B1-theme-selection-ui.md](./phase-B1-theme-selection-ui.md)**
   - Create `ThemeCard` component
   - Create `ThemeCategorySection`
   - Create `ThemeSelectionScreen`
   - Create `ThemeLoader` service

5. **[phase-B2-onboarding-integration.md](./phase-B2-onboarding-integration.md)**
   - Update onboarding flow
   - Create theme collections
   - Download initial recipes
   - Add re-selection in Settings

### Routing (Phase C)

6. **[phase-C1-collection-routing.md](./phase-C1-collection-routing.md)**
   - Create `CollectionRouter` service
   - Route shared recipes → From Friends
   - Route URL imports → My Imports
   - Route cookbook → Named collection

### UI Updates (Phase D)

7. **[phase-D1-collections-list.md](./phase-D1-collections-list.md)**
   - Filter collections (hide empty/system)
   - Create `ThemeCollectionCard`
   - Create `StandardCollectionCard`
   - Add section headers

8. **[phase-D2-ux-nudges.md](./phase-D2-ux-nudges.md)**
   - Add "Make it yours" nudge
   - Create unlock celebration
   - Add contextual empty states
   - Create trial progress banner

### Firebase

9. **[firebase-schema.md](./firebase-schema.md)**
   - Theme document schema
   - Recipe document schema
   - Initial theme data (10 themes)
   - Security rules
   - Seeding script

---

## Recommended Execution Strategy

### Day 1: Foundation
```bash
git checkout -b feature/collections-overhaul

# Phase A1 (30-45 min)
# Phase A2 (20-30 min)
# Phase A3 (45-60 min)

git commit -m "feat: Collections overhaul foundation (A1-A3)"
```

### Day 2: Onboarding + Routing
```bash
# Phase B1 (60-90 min)
# Phase B2 (30-45 min)
# Phase C1 (45-60 min)

git commit -m "feat: Theme selection and collection routing (B1-C1)"
```

### Day 3: UI + Polish
```bash
# Phase D1 (45-60 min)
# Phase D2 (30-45 min)

git commit -m "feat: Collections UI updates and UX nudges (D1-D2)"
```

### Day 4: Firebase + Testing
```bash
# Set up Firebase schema
# Seed initial themes
# End-to-end testing
# Bug fixes

git commit -m "feat: Firebase schema and initial theme data"
```

---

## Agent Deployment

### Agent 1: Content Pipeline
**Purpose:** Seed Firebase with curated recipes

**Tasks:**
1. Parse MSU Feeding America XML for public domain recipes
2. Research and enter Horn & Hardart recipes
3. Research and enter Harvey House/Railroad recipes
4. Generate AI cover images for themes
5. Upload assets to Firebase Storage

**Input:** Research document, Firebase credentials
**Output:** Populated Firebase with 10 themes, 130+ recipes

### Agent 2: Recipe Curation
**Purpose:** Quality control and historical accuracy

**Tasks:**
1. Verify recipe accuracy and attribution
2. Write historical context/stories for each recipe
3. Test and adjust recipes for home cooking
4. Categorize by difficulty and tags

**Input:** Raw recipe data
**Output:** Polished recipe documents with stories

### Agent 3: Testing
**Purpose:** End-to-end flow validation

**Tasks:**
1. Fresh install onboarding test
2. Theme selection variations (2, 3, 5 themes)
3. 14-day simulation (advance trial day)
4. Collection routing scenarios
5. Edge cases (no themes, trial expired, etc.)

**Input:** Built app
**Output:** Test report with issues

---

## Key Files Changed

```
Heirloom/
├── Core/
│   ├── Models/
│   │   ├── RecipeTheme.swift         [NEW]
│   │   ├── CollectionType.swift      [NEW]
│   │   ├── RecipeCollection.swift    [MODIFIED]
│   │   └── Recipe.swift              [MODIFIED]
│   ├── Services/
│   │   ├── Themes/                   [RENAMED from Heritage/]
│   │   │   ├── ThemeRecipeService.swift
│   │   │   ├── ThemeRecipeCache.swift
│   │   │   ├── ThemeUnlockTracker.swift
│   │   │   └── ThemeLoader.swift     [NEW]
│   │   └── Collections/
│   │       └── CollectionRouter.swift [NEW]
│   ├── ViewModels/
│   │   └── TrialStateViewModel.swift  [NEW]
│   └── Constants/
│       └── UXCopy.swift               [NEW]
├── Features/
│   ├── Onboarding/
│   │   ├── ThemeSelectionScreen.swift [NEW]
│   │   ├── OnboardingContainerView.swift [MODIFIED]
│   │   └── Components/
│   │       ├── ThemeCard.swift        [NEW]
│   │       └── ThemeCategorySection.swift [NEW]
│   ├── Collections/
│   │   ├── CollectionsListView.swift  [MODIFIED]
│   │   ├── CollectionDetailView.swift [MODIFIED]
│   │   └── Components/
│   │       ├── ThemeCollectionCard.swift [NEW]
│   │       └── StandardCollectionCard.swift [NEW]
│   └── Themes/                        [RENAMED from Heritage/]
│       ├── ThemeUnlockView.swift
│       ├── DailyUnlockView.swift
│       ├── UnlockCelebrationView.swift [NEW]
│       └── TrialProgressBanner.swift   [NEW]
```

---

## Success Metrics

After implementation, validate:

- [ ] Users select 2-5 themes during onboarding
- [ ] Selected themes create collections with Day 1 recipes
- [ ] Collections page shows only relevant content (no empty)
- [ ] New recipes unlock on correct days
- [ ] Shared recipes route to "From Friends"
- [ ] URL imports route to "My Imports"
- [ ] Cookbook imports create named collections
- [ ] "Make it yours" nudge appears appropriately
- [ ] Unlock celebration shows for new recipes
- [ ] Trial progress visible throughout

---

## Quick Start

```bash
# Clone repo
git clone https://github.com/RationaleDesignHanson/Heirloom.git
cd Heirloom

# Create branch
git checkout -b feature/collections-overhaul

# Start with Phase A1
# Open phase-A1-theme-model.md and follow instructions
```

Good luck! 🚀
