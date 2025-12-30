# Heirloom App - Bug Fix Implementation Guide
## Roadmap for 35 Bugs (With Specific File Locations)

---

## QUICK REFERENCE: Critical File Paths

```
Core Models (Data Integrity):
  /Heirloom/Core/Models/Recipe.swift (599 lines)
  /Heirloom/Core/Models/RecipeVersion.swift (277 lines)
  /Heirloom/Core/Models/Ingredient.swift (299 lines)
  /Heirloom/Core/Models/RecipeComment.swift (287 lines)
  /Heirloom/Core/Models/ProvenanceMetadata.swift (270 lines)

Core Services (Business Logic):
  /Heirloom/Core/Services/CloudKit/CloudKitSyncCoordinator.swift
  /Heirloom/Core/Services/CommentService.swift
  /Heirloom/Core/Services/AI/Clients/AnthropicAIService.swift
  /Heirloom/Core/Services/RecipeImportService.swift
  /Heirloom/Core/Services/RecipeLineageService.swift

Feature Views (UI/UX):
  /Heirloom/Features/Recipes/RecipeDetail/RecipeDetailView.swift (38KB)
  /Heirloom/Features/Shopping/ShoppingListView.swift
  /Heirloom/Features/DinnerParty/DinnerPartyActiveView.swift
  /Heirloom/Features/CardPersonalization/CardPersonalizationView.swift
  /Heirloom/Features/Comments/Views/RecipeCommentListView.swift

App Entry Point:
  /Heirloom/App/HeirloomApp.swift (170 lines)
```

---

## PHASE 1: CORE DATA MODEL BUGS (5-8 bugs)

### Bug Category 1.1: Recipe Model Issues
**File**: `/Heirloom/Core/Models/Recipe.swift`

**Potential Issues**:
1. **Provenance Initialization** (Line 131-146)
   - Issue: Provenance might not initialize on existing recipes
   - Fix: Ensure ensureProvenance() called before accessing provenance
   - Related: Lines 428-461

2. **Scaling Calculations** (Line 250-339)
   - Issue: allowedServingRange might exclude valid sizes
   - Fix: Verify filterServingSizes() includes original and all valid presets
   - Lines: 270-274, 318-339

3. **Image File Reference** (Line 402-416)
   - Issue: imageFileName mismatch between file system and database
   - Fix: Ensure loadImage() uses correct path, saveImage() validates path
   - Related: Core/Services/Storage/ImageStorageService.swift

### Bug Category 1.2: Ingredient Parsing Issues
**File**: `/Heirloom/Core/Models/Ingredient.swift`

**Potential Issues**:
1. **Quantity Parsing** (Line 90-125)
   - Issue: Fraction conversion may not match all formats
   - Fix: Test formatQuantity() with edge cases (0.125, decimals, ranges)
   - Related: Core/Services/IngredientParser.swift

2. **Category Categorization** (Line 191-243)
   - Issue: Order of checks affects categorization accuracy
   - Fix: Review check order, ensure specific terms before generic ones
   - Example: "egg" should match before "eggplant"

### Bug Category 1.3: RecipeVersion Relationships
**File**: `/Heirloom/Core/Models/RecipeVersion.swift`

**Potential Issues**:
1. **Inverse Relationship** (Line 28)
   - Issue: Inverse relationship on Recipe might not sync bidirectionally
   - Fix: Verify Recipe.versions updates when version.recipe set
   - Related: Recipe.swift lines 96-97

2. **ChangeLog Encoding** (Line 125-134)
   - Issue: JSON encoding/decoding might fail for complex changes
   - Fix: Test recordChange() with special characters, dates
   - Lines: 181-206

### Bug Category 1.4: RecipeComment Threading
**File**: `/Heirloom/Core/Models/RecipeComment.swift`

**Potential Issues**:
1. **Self-Referential Relationship** (Line 21-22)
   - Issue: Self-referential model might have cascade delete issues
   - Fix: Test reply creation/deletion cascade behavior
   - Lines: 17-22

2. **Sentiment Score** (Line 43-44)
   - Issue: Sentiment might be nil when needed for sorting
   - Fix: Ensure CommentAnalysisService sets before display
   - Related: Core/Services/AI/CommentAnalysisService.swift

### Bug Category 1.5: ProvenanceMetadata
**File**: `/Heirloom/Core/Models/ProvenanceMetadata.swift`

**Potential Issues**:
1. **Hash Generation** (Line 82-88)
   - Issue: generateProvenanceHash() might not be unique
   - Fix: Use stronger hash with recipe identifiers
   - Note: Currently uses timestamp + UUID (should be SHA256)

2. **Root Hash Propagation** (Line 23)
   - Issue: rootProvenanceHash not preserved when sharing
   - Fix: Ensure ShareAcceptanceService copies rootProvenanceHash
   - Related: Core/Services/CloudKit/ShareAcceptanceService.swift

---

## PHASE 2: SERVICE INTEGRATION BUGS (10-12 bugs)

### Bug Category 2.1: CloudKit Synchronization
**File**: `/Heirloom/Core/Services/CloudKit/CloudKitSyncCoordinator.swift`

**Potential Issues**:
1. **Conflict Resolution**
   - Issue: Concurrent edits might not merge properly
   - Fix: Implement proper conflict handling for:
     - Recipe + Comment edits
     - Multiple version updates
   - Priority: HIGH

2. **Sync Queue Management**
   - Issue: Sync operations might get stuck or duplicate
   - Fix: Ensure SyncOperation.swift has proper cancellation
   - Verify: Queue doesn't accumulate failed operations

3. **Error Recovery**
   - Issue: Network errors might not retry correctly
   - Fix: Implement exponential backoff in sync coordinator
   - Test: Offline → Online transition

### Bug Category 2.2: Recipe Sharing
**File**: `/Heirloom/Core/Services/CloudKit/RecipeShareService.swift`
**Related**: `/Heirloom/Core/Services/CloudKit/ShareAcceptanceService.swift`

**Potential Issues**:
1. **Share Link Generation**
   - Issue: Links might expire or not work reliably
   - Fix: Verify CKShare initialization and link creation
   - Test: Deep link acceptance via browser

2. **Version Creation on Accept**
   - Issue: RecipeVersion not created with proper metadata
   - Fix: Ensure generation incremented, provenance updated
   - Check: Recipe.selectedVersionID set correctly

### Bug Category 2.3: Image Storage
**File**: `/Heirloom/Core/Services/Storage/ImageStorageService.swift`
**Also**: `/Heirloom/Core/Services/Storage/ImageCache.swift`

**Potential Issues**:
1. **File Path Management**
   - Issue: imageFileName inconsistencies cause missing images
   - Fix: Ensure consistent path format across all operations
   - Check: Recipe.saveImage() path matches loadImage()

2. **Cache Invalidation**
   - Issue: ImageCache returns stale images after update
   - Fix: Implement proper cache key invalidation
   - Verify: ImageCache.swift cache clear on recipe image change

3. **Storage Cleanup**
   - Issue: Old images not cleaned up, accumulate
   - Fix: Implement ImageStorageService.performCleanup()
   - Called in: HeirloomApp.swift line 76

### Bug Category 2.4: AI Service Integration
**File**: `/Heirloom/Core/Services/AI/Clients/AnthropicAIService.swift`

**Potential Issues**:
1. **API Key Management**
   - Issue: API key not loaded or expired
   - Fix: Verify AIConfiguration.swift loads key correctly
   - Related: Core/Services/AI/Configuration/AIConfiguration.swift

2. **Error Handling**
   - Issue: API errors not caught/reported
   - Fix: Ensure AIError.swift covers all error cases
   - Related: Core/Services/AI/Utils/AIError.swift

3. **Request/Response Format**
   - Issue: Message format might not match Claude API
   - Fix: Verify AnthropicAIService prompt formatting
   - Test: Sample extraction call with debug output

### Bug Category 2.5: Comment Operations
**File**: `/Heirloom/Core/Services/CommentService.swift`

**Potential Issues**:
1. **Threading Integrity** (Line 39-44)
   - Issue: Parent/child relationships might break on delete
   - Fix: Test deletion cascade: parent → replies
   - Verify: All replies deleted when parent deleted

2. **Vote Counting** (Line 150+)
   - Issue: Duplicate votes might be stored
   - Fix: Implement idempotent vote operations
   - Check: CommentService has tracking for user votes

3. **Sentiment Analysis** (Related: CommentAnalysisService)
   - Issue: AI sentiment not calculated for all comments
   - Fix: Ensure async operation completes before display
   - Test: New comment sentiment is nil initially, updates after

---

## PHASE 3: UI/UX BUGS (8-10 bugs)

### Bug Category 3.1: RecipeDetailView
**File**: `/Heirloom/Features/Recipes/RecipeDetail/RecipeDetailView.swift` (38KB)

**Potential Issues**:
1. **Image Loading State**
   - Issue: Image might load after view renders, causing layout shift
   - Fix: Use placeholder while loading
   - Implementation: Add @State var recipeImage tracking

2. **Comments List Performance**
   - Issue: Large comment lists might scroll slowly
   - Fix: Implement pagination or limit initial load
   - Verify: RecipeCommentListView uses @Query efficiently

3. **Navigation Consistency**
   - Issue: Back button state or deep links not working
   - Fix: Verify NavigationStack setup
   - Test: Close then reopen recipes multiple times

4. **Version Selector State**
   - Issue: selectedVersionID not persisted
   - Fix: Sync selectedVersionID to Recipe model on change
   - Related: CookingModeView.swift line 42-48

### Bug Category 3.2: CookingModeView
**File**: `/Heirloom/Features/Recipes/CookingMode/CookingModeView.swift`

**Potential Issues**:
1. **Timer Functionality**
   - Issue: Timer might not fire notifications
   - Fix: Verify UNUserNotificationCenter setup in HeirloomApp
   - Related: HeirloomApp.swift line 101-113

2. **Step Progress**
   - Issue: currentStep state might desync from UI
   - Fix: Ensure currentStep stays within bounds
   - Add: Validation in navigationControls

3. **Version Switching During Cooking**
   - Issue: Switching versions might not update instructions
   - Fix: Observe selectedVersionID changes, recompute activeInstructions
   - Related: activeInstructions computed property line 28-35

### Bug Category 3.3: ShoppingListView
**File**: `/Heirloom/Features/Shopping/ShoppingListView.swift`

**Potential Issues**:
1. **Ingredient Grouping**
   - Issue: Same ingredient in different recipes not consolidated
   - Fix: Implement proper ingredient deduplication
   - Check: GroceryCategory sorting (line 99)

2. **Check-off Persistence**
   - Issue: Check-offs not saved to database
   - Fix: Ensure Ingredient.isCheckedOff updated and saved
   - Verify: ModelContext.save() called after toggle

3. **Recipe Removal**
   - Issue: Removing recipe doesn't update shopping list
   - Fix: Observe ShoppingCartRecipe deletion, rebuild list
   - Related: @Query cartRecipes (line 14)

### Bug Category 3.4: CardPersonalizationView
**File**: `/Heirloom/Features/CardPersonalization/CardPersonalizationView.swift`

**Potential Issues**:
1. **Preview Animation**
   - Issue: FlipCard animation might stutter or not show updates
   - Fix: Verify animation timing in FlipCard.swift
   - Related: Core/Design/Components/FlipCard.swift

2. **Sticker Positioning**
   - Issue: Sticker positions might shift on device rotation
   - Fix: Use normalized coordinates (0-1) consistently
   - Check: RecipeSticker.swift positionX/positionY (lines 12-13)

3. **Save State**
   - Issue: Changes not saved or @Bindable not working
   - Fix: Ensure saveChanges() calls context.save()
   - Verify: @Bindable recipe binding is bidirectional

### Bug Category 3.5: RecipeCommentListView
**File**: `/Heirloom/Features/Comments/Views/RecipeCommentListView.swift`

**Potential Issues**:
1. **Filter Persistence**
   - Issue: Filters reset on view refresh
   - Fix: Consider saving filter state to UserDefaults
   - Or: Pass as Environment value

2. **Sort Order Bug**
   - Issue: mostReplies sort doesn't work (line 77-80)
   - Fix: Implement proper reply count traversal
   - Check: replies array loaded when sorting

3. **Search Performance**
   - Issue: Search lags with many comments
   - Fix: Debounce search input
   - Consider: Limiting search scope to top-level comments

---

## PHASE 4: FEATURE-SPECIFIC BUGS (5-7 bugs)

### Bug Category 4.1: DinnerParty Feature
**File**: `/Heirloom/Features/DinnerParty/DinnerPartyActiveView.swift`

**Potential Issues**:
1. **Timeline Calculation**
   - Issue: startTimeOffset calculation might be wrong
   - Fix: Verify time arithmetic (line 54-56 in DinnerParty.swift)
   - Test: Create party 2 hours from now with 1-hour recipe

2. **Scaling Factors**
   - Issue: Ingredients not scaled correctly for guest count
   - Fix: Implement ingredient quantity multiplication
   - Related: ShoppingCartRecipe scaling

### Bug Category 4.2: Recipe Import
**File**: `/Heirloom/Core/Services/RecipeImportService.swift`

**Potential Issues**:
1. **URL Parsing**
   - Issue: Some recipe websites not recognized
   - Fix: Add more website parsers or use AI extraction
   - Related: AIRecipeExtractor.swift

2. **Import Progress**
   - Issue: Progress not updated accurately
   - Fix: Implement proper progress tracking
   - Related: Features/Recipes/BulkImport/Views/ImportProgressView.swift

### Bug Category 4.3: Recipe Lineage
**File**: `/Heirloom/Core/Services/RecipeLineageService.swift`

**Potential Issues**:
1. **Ancestor/Descendant Fetch**
   - Issue: Lineage graph might be incomplete
   - Fix: Verify recursive fetch logic (lines 75-100+)
   - Test: 3+ generation share chain

2. **Provenance Hash Matching**
   - Issue: rootProvenanceHash not matching shared copies
   - Fix: Ensure hash copied correctly in ShareAcceptanceService
   - Related: ProvenanceMetadata.swift line 23

### Bug Category 4.4: Deep Linking
**File**: `/Heirloom/Core/Services/DeepLinkHandler.swift`

**Potential Issues**:
1. **URL Parsing**
   - Issue: Some URLs not recognized
   - Fix: Add debug logging, test with various formats
   - Check: heirloom:// scheme registered

2. **Sheet Presentation**
   - Issue: Deep link sheets might not show
   - Fix: Verify showReceiveSheet/showImportSheet binding
   - Related: HeirloomApp.swift lines 223-232

---

## BUG PRIORITIZATION MATRIX

### Critical (Fix First - 10 bugs)
- Recipe.provenance initialization
- RecipeVersion relationship sync
- CloudKitSyncCoordinator conflict resolution
- Image file path consistency
- Comment threading integrity
- RecipeDetailView image loading
- ShoppingListView ingredient deduplication
- CookingMode timer notifications
- Recipe sharing acceptance
- Deep link handling

### High (Fix Second - 12 bugs)
- Ingredient parsing edge cases
- Recipe scaling calculations
- AI API error handling
- Comment sentiment analysis
- CardPersonalization save state
- RecipeCommentListView filtering
- DinnerParty timeline calculation
- Recipe import progress
- Lineage graph completeness
- Vote counting logic
- Cache invalidation
- Search performance

### Medium (Fix Third - 8 bugs)
- ShoppingList check-off persistence
- StoryCard animation smoothing
- Cooking step progression
- Annotation editor state
- RecipeCollection creation
- Tag filtering
- Stats calculation
- Onboarding flow

### Low (Fix Last - 5 bugs)
- Discovery feature polish
- CloudKitMonitoring display
- Debug utilities
- Settings UI polish
- Empty state messaging

---

## TESTING CHECKLIST FOR EACH BUG

### Before Starting Fix
- [ ] Reproduce bug in app
- [ ] Check related test file
- [ ] Review git history for similar issues
- [ ] Document expected behavior

### During Fix
- [ ] Write test case first
- [ ] Implement fix
- [ ] Verify test passes
- [ ] Check for side effects

### After Fix
- [ ] Manual testing on device
- [ ] Test offline/online scenarios
- [ ] Verify CloudKit sync
- [ ] Check memory leaks
- [ ] Run full test suite

---

## COMMON PATTERNS TO CHECK

### Pattern 1: Missing context.save()
Check after any model changes:
```swift
// After Recipe/Ingredient/Comment modification
try context.save()
```
Files to audit: CommentService, RecipeImportService, etc.

### Pattern 2: Cascade Delete Verification
When deleting parent model:
```swift
// @Relationship(deleteRule: .cascade)
// Verify child is deleted too
```
Check: All @Relationship annotations for cascade rules

### Pattern 3: @Query Efficiency
Avoid N+1 queries:
```swift
// DON'T: Query all recipes, then load ingredients per recipe
// DO: Use @Query with predicate to fetch minimal data
```

### Pattern 4: Async/Await Proper Handling
All async service calls should:
```swift
@MainActor  // Services should be MainActor
async throws // Return proper errors
```

### Pattern 5: Image Path Normalization
Always validate image paths:
```swift
let fileName = try await ImageStorageService.shared.saveImage(...)
recipe.imageFileName = fileName  // Consistent format
```

---

## USEFUL DEBUG COMMANDS

### Check SwiftData Schema
```swift
print(SchemaV1.schema)
```
In: HeirloomApp.swift

### Inspect CloudKit Sync Status
```swift
// Monitor CloudKit sync in CloudKitMonitoringService
```

### Validate Ingredient Parsing
```swift
let parsed = IngredientParser.parse("2 cups flour")
print(parsed) // Check quantity, unit, name
```

### Check Recipe Relationships
```swift
let recipe = /* fetch recipe */
print("Ingredients: \(recipe.ingredients?.count ?? 0)")
print("Comments: \(recipe.comments?.count ?? 0)")
print("Versions: \(recipe.versions?.count ?? 0)")
```

---

## SUCCESS CRITERIA

### Per Bug Fix
1. Test case passes
2. No compiler warnings
3. No new runtime errors
4. Related features still work
5. Memory usage stable

### Overall (35 Bugs)
1. All tests pass
2. App launches cleanly
3. Full CloudKit sync cycle works
4. No data corruption
5. No accumulated technical debt

