# Recipe Sharing Implementation - Quick Reference

**Project:** Multi-Version Recipe Sharing System
**Status:** Ready to Start
**Main Document:** [RECIPE_SHARING_IMPLEMENTATION_PLAN.md](./RECIPE_SHARING_IMPLEMENTATION_PLAN.md)

---

## 🚀 Quick Start (Fresh Session)

```bash
# Navigate to project
cd /Users/matthanson/Heirloom

# Open main implementation plan
open RECIPE_SHARING_IMPLEMENTATION_PLAN.md
# (Check Progress Tracker section at top for current status)

# Open project in Xcode
open Heirloom.xcodeproj
```

---

## 📁 Key Documents

| Document | Location | Purpose |
|----------|----------|---------|
| **Implementation Plan** | `RECIPE_SHARING_IMPLEMENTATION_PLAN.md` | Main plan with progress tracker |
| **Architecture Guide** | `ARCHITECTURE_QUICK_REFERENCE.md` | Current app architecture |
| **File Paths** | `KEY_FILE_PATHS.md` | Where to find models/services/views |
| **Demo Code** | `/Users/matthanson/Downloads/heirdemo/app/` | Reference implementation |
| **Test Assets** | `AnalogRecipes/Cards/` | 12 sample recipe cards for testing |

---

## 🎯 What We're Building

**Goal:** Enable multiple people to edit the same recipe while preserving all versions with attribution.

**Example Flow:**
1. You scan Grandma's lasagna recipe (1987)
2. Toggle "Lineage Sharing" ON
3. Share with Mom
4. Mom creates her version, edits 2 ingredients (2015)
5. Mom shares with you
6. You create your version, change the title (2025)
7. **Result:** All 3 versions visible, you can pick which to cook

**Key Features:**
- Multi-version editing with attribution
- Version selector for cooking
- Inline badges ("Mom '15") on changed fields
- Version-specific notes on card back
- Heirloom vs Regular sharing permissions

---

## 📋 Implementation Phases

| Phase | Duration | Status | Tasks |
|-------|----------|--------|-------|
| **Phase 1: Foundation** | Week 1-2 | ⬜ Not Started | Data models + service |
| **Phase 2: Version Selection** | Week 2-3 | ⬜ Not Started | UI for switching versions |
| **Phase 3: Change Tracking** | Week 3-4 | ⬜ Not Started | Attribution badges |
| **Phase 4: Sharing Permissions** | Week 4-5 | ⬜ Not Started | Heirloom vs Regular |
| **Phase 5: Card Back Integration** | Week 5-6 | ⬜ Not Started | Version notes |
| **Phase 6: UI Polish** | Week 6-7 | ⬜ Not Started | Animations, empty states |
| **Phase 7: Testing** | Week 7-8 | ⬜ Not Started | Beta testing |

**Current Phase:** Phase 1 (see main plan for detailed tasks)

---

## 🔨 Current Work (Phase 1 Tasks)

When starting Phase 1, you'll create:

1. **RecipeVersion Model** (`Core/Models/RecipeVersion.swift`)
   - Stores user-specific edits
   - Tracks changes with attribution
   - Relates to Recipe via `@Relationship`

2. **Update Recipe Model** (`Core/Models/Recipe.swift`)
   - Add `versions: [RecipeVersion]?` relationship
   - Add `selectedVersionID: UUID?` field
   - Add `sharingPermission` enum

3. **RecipeVersionService** (`Core/Services/RecipeVersionService.swift`)
   - CRUD operations for versions
   - Change tracking logic
   - Version selection

4. **Schema Migration**
   - Update `SchemaV1.swift` or create `SchemaV2.swift`
   - Add migration code for existing recipes

5. **Unit Tests**
   - `RecipeVersionServiceTests.swift`
   - `RecipeVersionModelTests.swift`

See **Section 6.1** in main plan for complete Phase 1 checklist.

---

## 🧪 Testing Strategy

**Sample Assets:** 12 recipe cards in `AnalogRecipes/Cards/`
- Use for OCR testing
- Test multi-generation sharing
- Verify version attribution

**Manual Test Scenario:**
1. Scan `RecipeCard_01.jpg`
2. Toggle lineage ON
3. Simulate sharing (use separate CloudKit user if available)
4. Create version, edit ingredients
5. Verify changes tracked
6. Test version switching

---

## 📝 Progress Tracking

**The main plan tracks progress in the "Progress Tracker" section.**

Each session should:
1. Update "Current Status" and "Active Tasks"
2. Add entry to "Session Log" table
3. Update quick stats (✅ completed, ⬜ pending)
4. Note any blockers or decisions

**Example Session Log Entry:**
```markdown
| 2025-12-19 | Phase 1 | Created RecipeVersion model | RecipeVersion.swift | Model compiles, tests pass |
```

---

## 🤝 How to Resume After Break

1. **Open this file** (`SHARING_PROJECT_README.md`)
2. **Check Progress Tracker** in main plan
3. **Review "Active Tasks"** section
4. **Read last "Session Log" entry** to see what was completed
5. **Continue with next unchecked task** in current phase

---

## 💡 Tips for Implementation

- **Reference the demo:** `/Users/matthanson/Downloads/heirdemo/app/heirloom-demo-v4.jsx`
  - Lines 122-214: Change attribution pattern
  - Lines 435-445: Generation tracking
  - Lines 4-116: Inline editing pattern

- **Follow existing patterns:**
  - Look at `RecipeComment.swift` for model structure
  - Look at `CommentService.swift` for service patterns
  - Look at `ProvenanceMetadata.swift` for lineage tracking

- **Use test assets:**
  - `AnalogRecipes/Cards/RecipeCard_01.jpg` through `RecipeCard_12.jpg`
  - Test OCR → share → edit flow

---

## 🐛 Common Issues & Solutions

**Issue:** Schema migration fails
- **Solution:** See Section 7.4 in main plan for migration code

**Issue:** CloudKit sync conflicts
- **Solution:** See Section 7.1 for conflict resolution strategy

**Issue:** Version performance slow
- **Solution:** See Section 7.2 for lazy loading approach

---

## 📞 Key Files to Modify

| Task | File | Location |
|------|------|----------|
| Create version model | `RecipeVersion.swift` | `Core/Models/` |
| Update recipe | `Recipe.swift` | `Core/Models/` (line 85+) |
| Create version service | `RecipeVersionService.swift` | `Core/Services/` |
| Update schema | `SchemaV1.swift` | `Core/Models/` |
| Add UI selector | `VersionSelectorView.swift` | `Features/Recipes/CookingMode/` |
| Update sharing | `CloudKitShareService.swift` | `Core/Services/` (line 385+) |

See **KEY_FILE_PATHS.md** for complete file inventory.

---

## ✅ Definition of Done

**Phase 1 Complete When:**
- [ ] RecipeVersion model created and compiling
- [ ] Recipe relationships added
- [ ] RecipeVersionService implemented
- [ ] Unit tests pass (80%+ coverage)
- [ ] Schema migration tested
- [ ] Existing recipes migrated successfully

---

**Ready to start? Open the main plan and begin Phase 1! 🚀**

[📖 Open RECIPE_SHARING_IMPLEMENTATION_PLAN.md](./RECIPE_SHARING_IMPLEMENTATION_PLAN.md)
