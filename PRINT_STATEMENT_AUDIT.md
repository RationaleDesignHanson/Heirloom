# Print Statement Audit - Phase 4
**Generated**: 2026-01-03
**Total print statements**: 703

---

## Summary by Category

| Category | Count | Priority |
|----------|-------|----------|
| Firebase Services | 220 | HIGH |
| Features/Views | 202 | MEDIUM |
| Other Services | 26+ | HIGH |
| Models | 18 | LOW |
| Utilities | 1 | LOW |

---

## Top 10 Files (High Priority)

1. **FirebaseSyncService.swift** - 70 prints
   - Category: Firebase/Sync
   - Suggested log categories: `.firebase`, `.sync`, `.crdt`

2. **RecipeListView.swift** - 39 prints
   - Category: UI
   - Suggested log category: `.ui`

3. **DeepLinkHandler.swift** - 38 prints
   - Category: Navigation
   - Suggested log category: `.general`, `.ui`

4. **FirebaseRecipeSync.swift** - 34 prints
   - Category: Firebase/Sync
   - Suggested log categories: `.firebase`, `.sync`

5. **RecipeImportService.swift** - 32 prints
   - Category: Services
   - Suggested log category: `.network`, `.general`

6. **FirebaseSyncService+CRDT.swift** - 31 prints
   - Category: CRDT/Sync
   - Suggested log categories: `.crdt`, `.sync`

7. **AIAPITest.swift** - 31 prints
   - Category: Testing/AI
   - Suggested log category: `.general`
   - Note: Test file, low priority

8. **CookbookScannerView.swift** - 18 prints
   - Category: UI/OCR
   - Suggested log categories: `.ui`, `.ocr`

9. **RecipeImportView.swift** - 17 prints
   - Category: UI
   - Suggested log category: `.ui`, `.network`

10. **FirebaseNotificationService.swift** - 17 prints
    - Category: Firebase/Notifications
    - Suggested log category: `.firebase`

---

## Replacement Strategy

### Phase 1: High-Value Files (Days 1-3)
Target the top 5 files which contain 213 print statements (~30% of total)

1. FirebaseSyncService.swift (70 prints)
2. RecipeListView.swift (39 prints)
3. DeepLinkHandler.swift (38 prints)
4. FirebaseRecipeSync.swift (34 prints)
5. RecipeImportService.swift (32 prints)

### Phase 2: Firebase Services (Days 4-5)
Replace all remaining Firebase service prints (~150 prints)

- FirebaseSyncService+CRDT.swift
- FirebaseNotificationService.swift
- FirebaseAuthService.swift
- FirebaseShareService.swift
- FirebaseConfiguration.swift
- FirebaseImageService.swift
- FirebaseCollectionSync.swift

### Phase 3: UI/Features (Days 6-8)
Replace prints in view layer (~200 prints)

- RecipeListView and related views
- RecipeImportView
- CookbookScannerView
- RecipeEditorView
- Other feature views

### Phase 4: Cleanup (Days 9-10)
- Models and utilities (~20 prints)
- Test files (optional, low priority)
- Final verification

---

## Log Category Mapping

### Firebase Operations
- Firestore reads/writes → `.firebase`
- Auth operations → `.auth`
- Storage operations → `.storage`
- Sync coordination → `.sync`

### CRDT Operations
- Operation logs → `.crdt`
- Conflict resolution → `.crdt`
- Merge operations → `.sync`, `.crdt`

### User Interface
- View lifecycle → `.ui`
- User interactions → `.ui`
- Navigation → `.ui`

### Data Operations
- Recipe import → `.network`
- OCR processing → `.ocr`
- Database queries → `.database`

### Performance
- Timing measurements → `.performance`
- Resource usage → `.performance`

---

## Notes

- 69 more prints than original 634 count (possibly from new code or better counting)
- HeirloomLogger.swift contains 1 debug print (acceptable for logging infrastructure)
- AIAPITest.swift has many prints but is a test file (low priority)
- Focus on production code first, tests second

---

## Progress Tracking

### Completed
- ✅ Logging service infrastructure created
- ✅ Comprehensive audit completed (703 prints)
- ✅ FirebaseSyncService.swift - 34/70 replaced (36 remaining)
  - ✅ Configuration & conversion methods
  - ✅ Upload recipe method (all subcollections)
  - ✅ Image upload/download/delete methods
  - ✅ Automatic sync initialization
  - 🔄 36 prints remaining (CRDT, batch operations, error handling)

### In Progress
- 🔄 Phase 1: Top 5 files (213 prints)
  - FirebaseSyncService.swift: 36/70 remaining (49% complete)
  - RecipeListView.swift: 39 remaining
  - DeepLinkHandler.swift: 38 remaining
  - FirebaseRecipeSync.swift: 34 remaining
  - RecipeImportService.swift: 32 remaining

### Pending
- [ ] Phase 2: Firebase services (~150 prints)
- [ ] Phase 3: UI/Features (~200 prints)
- [ ] Phase 4: Cleanup (~140 prints)

**Current Status**: 669/703 prints remaining (34 replaced)
**Completion**: 4.8%
**Target**: 0 print statements in production code (except HeirloomLogger debug output)
