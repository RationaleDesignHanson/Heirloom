# Quick Start: Heirloom Bug Fix Preparation
## Get Started in 5 Minutes

---

## READ THESE FIRST (In Order)

### 1. Executive Summary (5 min)
**File**: `ARCHITECTURE_SUMMARY.md`
- What: Project overview
- Why: Understand the big picture
- Action: Identify critical paths

### 2. Architecture Map (15 min)
**File**: `HEIRLOOM_ARCHITECTURE_MAP.md`
- What: Detailed file organization
- Why: Know where everything is
- Action: Bookmark key files

### 3. Bug Fix Guide (15 min)
**File**: `BUG_FIX_IMPLEMENTATION_GUIDE.md`
- What: Specific bugs with line numbers
- Why: Know what to fix
- Action: Start with Phase 1 bugs

---

## CRITICAL FILES TO UNDERSTAND (10 min)

### Core Models (Data Layer)
```swift
// These determine what breaks:
/Heirloom/Core/Models/Recipe.swift (599 lines)
/Heirloom/Core/Models/RecipeVersion.swift (277 lines)
/Heirloom/Core/Models/Ingredient.swift (299 lines)
/Heirloom/Core/Models/RecipeComment.swift (287 lines)
```

### Core Services (Business Logic)
```swift
// These execute the logic:
/Heirloom/Core/Services/CloudKit/CloudKitSyncCoordinator.swift
/Heirloom/Core/Services/CommentService.swift
/Heirloom/Core/Services/AI/Clients/AnthropicAIService.swift
/Heirloom/Core/Services/RecipeImportService.swift
```

### Main Views (UI)
```swift
// These show the problems:
/Heirloom/Features/Recipes/RecipeDetail/RecipeDetailView.swift
/Heirloom/Features/Shopping/ShoppingListView.swift
/Heirloom/Features/DinnerParty/DinnerPartyActiveView.swift
```

---

## THE 5 BIG PICTURE RISKS

### 1. SwiftData Relationships
**Issue**: Inverse relationships might not sync bidirectionally
**Files**: Recipe.swift, RecipeVersion.swift
**Action**: Test relationship updates both ways

### 2. CloudKit Sync
**Issue**: Conflicts not merged properly, sync failures
**Files**: CloudKitSyncCoordinator.swift
**Action**: Implement proper error recovery

### 3. Image File System
**Issue**: Path inconsistencies cause missing images
**Files**: ImageStorageService.swift, Recipe.swift
**Action**: Verify path format consistency

### 4. Cascade Deletes
**Issue**: Deleting parent might break children
**Files**: RecipeComment.swift (self-referential)
**Action**: Test deletion thoroughly

### 5. Async Operations
**Issue**: Missing context.save() after model changes
**Files**: CommentService.swift, everywhere
**Action**: Audit all service methods

---

## QUICK FIX CHECKLIST

### Before You Start
- [ ] Read ARCHITECTURE_SUMMARY.md
- [ ] Read HEIRLOOM_ARCHITECTURE_MAP.md (sections 2, 5, 6)
- [ ] Read BUG_FIX_IMPLEMENTATION_GUIDE.md (Phase 1)
- [ ] Open Recipe.swift in Xcode
- [ ] Open CloudKitSyncCoordinator.swift

### For Each Bug
- [ ] Read the specific bug description
- [ ] Locate exact line numbers
- [ ] Understand what should happen
- [ ] Write a test case first
- [ ] Implement the fix
- [ ] Verify no regressions

### Quality Assurance
- [ ] Run tests: `cmd + U`
- [ ] Check warnings: Clean build
- [ ] Test on device: Shopping + Cooking
- [ ] Test sync: CloudKit
- [ ] Check memory: Instruments

---

## DOCUMENTATION MAP

```
/Heirloom/ (Project Root)
├── ARCHITECTURE_SUMMARY.md (START HERE - 8KB)
├── HEIRLOOM_ARCHITECTURE_MAP.md (Detailed - 23KB)
├── BUG_FIX_IMPLEMENTATION_GUIDE.md (Specific bugs - 17KB)
├── QUICK_BUG_FIX_START.md (This file - 3KB)
│
├── Existing Documentation:
├── ARCHITECTURE_ANALYSIS.md (41KB)
├── ARCHITECTURE_QUICK_REFERENCE.md (11KB)
├── PHASE_2_MASTER_PLAN.md (16KB)
└── ...10+ other docs
```

---

## KEY STATISTICS

| Metric | Value |
|--------|-------|
| Total Swift Files | 128 |
| Core Models | 17 |
| Core Services | 38 |
| Feature Modules | 16+ |
| Feature Views | 59 |
| Test Files | 9 |
| **Known Bugs** | **35** |

---

## PROJECT STRUCTURE AT A GLANCE

```
Heirloom/
├── App/
│   └── HeirloomApp.swift (entry point, SwiftData setup)
│
├── Core/ (Shared infrastructure)
│   ├── Models/ (17 files) ← Data layer
│   ├── Services/ (38 files) ← Business logic
│   └── Design/ (Components + colors)
│
└── Features/ (59 files across 16+ modules)
    ├── Recipes/ (21) ← Core feature
    ├── Shopping/ (1)
    ├── DinnerParty/ (5)
    ├── CardPersonalization/ (3)
    ├── Comments/ (5)
    └── ...10+ more
```

---

## PHASE 1 BUGS TO FIX (Critical)

1. Recipe.provenance initialization (Recipe.swift:131)
2. RecipeVersion relationship sync (RecipeVersion.swift:28)
3. Ingredient quantity parsing (Ingredient.swift:90)
4. RecipeComment cascade delete (RecipeComment.swift:21)
5. Image file path mismatch (Recipe.swift:26, 402)
6. CloudKit sync conflicts (CloudKitSyncCoordinator)
7. Comment threading integrity (CommentService.swift:39)
8. Sticker position on rotation (CardPersonalizationView)

---

## TEST BEFORE YOU START

Run these to establish baseline:
```bash
# Run tests
cmd + U

# Check build
cmd + B

# Test on simulator
cmd + R

# Launch Shopping List
- Tap Shopping tab
- Verify no crash
- Check ingredients load
```

---

## WHEN YOU GET STUCK

### Where to Look
1. **Data not updating?** → Check context.save()
2. **Image missing?** → Check imageFileName path
3. **Sync not working?** → Check CloudKitSyncCoordinator logs
4. **Comments broken?** → Check CommentService
5. **View crashes?** → Check @State initialization

### What to Search
- `TODO` - marked issues
- `FIXME` - known problems
- `MARK: -` - section headers
- `print(` - debug output already there

### Who to Ask
- Code comments in files
- Related test files
- Sample data in extensions
- Existing error types

---

## FINAL CHECKLIST BEFORE FIRST FIX

- [ ] Cloned repo
- [ ] Opened in Xcode 15+
- [ ] iOS 17 simulator running
- [ ] Read ARCHITECTURE_SUMMARY.md
- [ ] Understand Recipe model
- [ ] Know Recipe.swift line numbers
- [ ] Test suite builds
- [ ] App launches
- [ ] Ready to start Phase 1

---

## NEXT: START READING

1. Open: `/Heirloom/ARCHITECTURE_SUMMARY.md`
2. Then: `/Heirloom/HEIRLOOM_ARCHITECTURE_MAP.md`
3. Then: `/Heirloom/BUG_FIX_IMPLEMENTATION_GUIDE.md`
4. Start: Phase 1 bugs in guide

**Estimated time**: 40 minutes total
**Result**: Ready to fix bugs systematically

