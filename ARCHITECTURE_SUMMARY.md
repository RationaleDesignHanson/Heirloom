# HEIRLOOM APP - ARCHITECTURE SUMMARY
## Executive Overview for 35 Bug Fixes

---

## KEY FINDINGS

### Project Scale
- **128 Swift files** across Core + Features
- **17 Data models** with complex relationships
- **38 Services** for business logic
- **59 Feature views** across 16+ features
- **iOS 17+ only** (SwiftData requirement)

### Architecture Quality
- Well-organized MVVM + Services pattern
- Strong separation of concerns
- Comprehensive CloudKit integration
- Multiple personalization layers

### Known Weaknesses
1. **No partial updates** - SwiftData limitation
2. **Complex relationships** - 1-to-many threading needs careful handling
3. **Async operations** - Easy to miss context.save() calls
4. **Image management** - File system + cache coordination
5. **Testing coverage** - Only 9 test files for 128 source files

---

## CRITICAL ARCHITECTURE DECISIONS

### 1. Data Persistence
- **Primary**: SwiftData (iOS 17+ requirement)
- **Fallback**: Local-only if CloudKit fails
- **Strategy**: Automatic sync with CloudKitSyncCoordinator
- **Risk**: Schema migrations not well supported

### 2. Image Storage
- **Decision**: Store in FileSystem, not database
- **Rationale**: Recommended by Systems Architect
- **Implementation**: ImageStorageService (Actor for thread safety)
- **Challenge**: Path consistency across operations

### 3. Recipe Versioning
- **Model**: RecipeVersion with complete copies
- **Tracking**: Field-level change log
- **Use Case**: Multi-user recipe editing with attribution
- **Challenge**: Relationship bidirectionality

### 4. Comments & Threading
- **Structure**: Self-referential RecipeComment
- **Scope**: Private | Lineage | Public
- **Analysis**: Sentiment via AI (async)
- **Risk**: Cascade delete edge cases

### 5. Sharing & Lineage
- **Method**: CKShare for CloudKit
- **Tracking**: rootProvenanceHash for lineage
- **Generation**: Tracked for attribution
- **Challenge**: Hash propagation across shares

### 6. Card Personalization
- **Elements**: Stickers + Annotations + CardBack
- **Rendering**: FlipCard animation
- **Data**: Positional coordinates (0-1 normalized)
- **Challenge**: Rotation/responsive layout

---

## FILE ORGANIZATION SUMMARY

```
Project Root
├── Heirloom/ (Main target - 128 files)
│   ├── App/ - Entry point & main navigation
│   ├── Core/ - Shared models, services, design
│   └── Features/ - 16+ feature modules
├── HeirloomTests/ - 9 test files (low coverage)
├── HeirloomShareExtension/ - Share sheet
└── Config files (XCConfig, project.yml, etc.)
```

### Core Models (17 files)
```
Recipe (root) → Ingredients
              → RecipeVersions
              → RecipeComments
              → RecipeCardBack
              → RecipeStickers
              → RecipeAnnotations
              → Tags
              → Collections
              → DinnerPartyRecipes
              → ProvenanceMetadata (embedded)
```

### Services (38 files)
```
AI Services (8 files)
  - AnthropicAIService (Claude API)
  - AIRecipeExtractor
  - AIIngredientParser
  - CommentAnalysisService (sentiment)

CloudKit Services (8 files)
  - CloudKitSyncCoordinator (main)
  - RecipeShareService
  - SharedCommentService
  - ShareAcceptanceService

Image/Storage Services (4 files)
  - ImageStorageService (file system)
  - ImageCache
  - ImagePreprocessor
  - EnhancedOCRService

Recipe Processing (7 files)
  - RecipeImportService
  - RecipeVersionService
  - RecipeLineageService
  - IngredientParser
  - RecipeStructureParser

Other Services (11 files)
  - CommentService
  - AnalyticsService
  - RemindersService
  - DeepLinkHandler
  - etc.
```

### Features (59 files across 16 modules)
```
Recipes (21) - Core feature
Shopping (1) - Shopping list
DinnerParty (5) - Party planning
CardPersonalization (3) - Card editor
Comments (5) - Comment system
CloudKitSharing (various) - Recipe sharing
Settings, Discovery, Collections, Tags, etc.
```

---

## DATA FLOW PATTERNS

### Pattern 1: Recipe Creation
```
RecipeEditorView
  ↓ AIRecipeExtractor (if importing)
  ↓ IngredientParser (parses ingredients)
  ↓ SwiftData insert Recipe + Ingredients
  ↓ context.save()
  ↓ CloudKitSyncCoordinator (async)
```

### Pattern 2: Recipe Sharing
```
RecipeDetailView (share button)
  ↓ RecipeShareService.createShare()
  ↓ CloudKitSyncCoordinator (public DB)
  ↓ Share link generated
  ↓ DeepLinkHandler.handleURL()
  ↓ SharePreviewView
  ↓ ShareAcceptanceService (creates RecipeVersion)
  ↓ Sync to local + increment generation
```

### Pattern 3: Comment System
```
RecipeCommentView (new comment)
  ↓ CommentService.addComment()
  ↓ RecipeComment created, inserted
  ↓ Recipe.comments[] updated
  ↓ context.save()
  ↓ CommentAnalysisService (async sentiment)
  ↓ Update comment with sentimentScore
```

### Pattern 4: Shopping List
```
ShoppingListView @Query (filtered by ShoppingCartRecipe)
  ↓ Group Ingredients by GroceryCategory
  ↓ Show recipes per ingredient
  ↓ Check off Ingredient.isCheckedOff
  ↓ context.save()
  ↓ RemindersService.createList() (export)
```

---

## POTENTIAL BUG CATEGORIES

### Model Issues (5-8 bugs expected)
- Relationship bidirectional sync
- Cascade delete edge cases
- Encoding/decoding errors
- Provenance initialization
- Scaling calculations

### Service Issues (10-12 bugs expected)
- CloudKit sync conflicts
- Image path inconsistencies
- API error handling
- Cache invalidation
- Thread safety

### UI Issues (8-10 bugs expected)
- State management
- Navigation consistency
- Performance (large lists)
- Animation smoothness
- Deep linking

### Feature Issues (5-7 bugs expected)
- Timeline calculations
- Ingredient scaling
- Lineage graph building
- Comment threading
- Import progress

---

## CRITICAL PATHS TO FIX FIRST

### 1. Recipe Persistence
- Recipe.swift model integrity
- Image file system coordination
- SwiftData relationship setup

### 2. CloudKit Sync
- CloudKitSyncCoordinator
- Conflict resolution
- Error recovery

### 3. Recipe Sharing
- RecipeShareService
- ShareAcceptanceService
- Provenance propagation

### 4. Comments
- Threading (self-referential)
- Sentiment analysis
- Vote counting

### 5. Shopping List
- Ingredient aggregation
- Category grouping
- Check-off persistence

---

## TESTING STRATEGY

### Current State
- 9 test files (~100 tests)
- Low coverage for services
- No UI tests
- No integration tests

### Recommended
1. Add service layer tests (mocking CloudKit)
2. Add model tests for relationships
3. Add integration tests for key flows
4. Add UI snapshot tests for views

### Per Bug Fix
- [ ] Write failing test first
- [ ] Implement fix
- [ ] Verify test passes
- [ ] Check for side effects
- [ ] Manual device testing

---

## TOOLS & DEBUGGING

### SwiftData Debugging
```swift
// Print schema
print(SchemaV1.schema)

// Monitor sync
CloudKitSyncCoordinator.shared.syncStatus
```

### CloudKit Debugging
```swift
// CloudKitMonitoringService shows sync state
// Check iCloud sync status in Settings
```

### Image Debugging
```swift
// Verify paths consistent
ImageStorageService.shared.imagesDirectory

// Check cache
ImageCache.shared.cachedImages
```

---

## RISKS & MITIGATION

### Risk: Schema Migration
- **Issue**: No migration path for field changes
- **Mitigation**: Consider versioning strategy
- **File**: HeirloomApp.swift (SchemaV1)

### Risk: CloudKit Conflicts
- **Issue**: Concurrent edits might not merge
- **Mitigation**: Implement proper conflict resolution
- **File**: CloudKitSyncCoordinator.swift

### Risk: Image Orphans
- **Issue**: Images not deleted when recipe deleted
- **Mitigation**: Implement cleanup on delete
- **File**: ImageStorageService.swift

### Risk: Comment Cascade Delete
- **Issue**: Self-referential deletes might break
- **Mitigation**: Test thoroughly
- **File**: RecipeComment.swift

### Risk: Relationship Bidirectionality
- **Issue**: Updates to one side don't update other
- **Mitigation**: Always verify inverse relationships
- **Files**: Recipe.swift, RecipeVersion.swift

---

## NEXT STEPS

1. **Review Architecture Map**
   - Read: HEIRLOOM_ARCHITECTURE_MAP.md
   - Understand project structure
   - Identify critical files

2. **Review Bug Fix Guide**
   - Read: BUG_FIX_IMPLEMENTATION_GUIDE.md
   - Categorize bugs by phase
   - Prioritize critical issues

3. **Start with Phase 1 Bugs**
   - Data model integrity
   - Relationship verification
   - Test coverage gaps

4. **Proceed to Phase 2-4**
   - Service integration
   - UI/UX issues
   - Feature-specific bugs

5. **Maintain Quality**
   - Write tests first
   - Verify no side effects
   - Monitor technical debt

---

## SUCCESS METRICS

- [ ] All 35 bugs fixed
- [ ] No new regressions
- [ ] Test coverage > 60%
- [ ] App launches cleanly
- [ ] CloudKit sync works end-to-end
- [ ] No data corruption
- [ ] Performance acceptable

