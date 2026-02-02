# Remaining Tasks - Post Manual Testing

**Date:** 2026-02-01
**Status:** Deferred until after manual testing (Option A)
**Purpose:** Document polish and architectural improvements to complete after validating core functionality

---

## Overview

After completing 16 of 19 tasks, the following 3 tasks remain. These are primarily polish (UI consistency) and architectural improvements (organization) rather than critical functionality.

**Completed Core Functionality:**
- ✅ Multi-recipe extraction from single images
- ✅ Duplicate detection and prevention
- ✅ Collection routing consolidation
- ✅ Share extension → app handoff reliability
- ✅ Import status badges and notifications
- ✅ Quality validation pipeline

**Remaining Work:**
- Task #5: Redesign import bottom sheets for consistency and elegance
- Task #6: Reorganize collection structure and shareability rules
- Task #10: Create missing Firestore composite index for connections
- Task #27: Improve multi-recipe bounding box accuracy for side-by-side layouts

---

## Task #5: Redesign Import Bottom Sheets

**Priority:** Medium (Polish/UX)
**Effort:** 3-4 hours
**Type:** UI/UX Consistency

### Current State

Multiple import flows use different sheet designs with inconsistent:
- Button styles and sizes
- Header layouts
- Spacing and padding
- Corner radius values
- Color schemes
- Loading states
- Error handling presentation

**Affected Files:**
1. `CookbookScannerView.swift` - Camera/photo import sheet
2. `BulkImportView.swift` - Bulk import sheet
3. `ImportProgressView.swift` - Progress display sheet
4. `VideoImportView.swift` - Video import sheet (if applicable)

### Problems to Solve

**Inconsistency Examples:**

1. **Button Styles:**
   - CookbookScannerView: Custom green buttons with specific padding
   - BulkImportView: Standard SwiftUI buttons
   - No unified button component

2. **Headers:**
   - Some sheets have custom headers with dismiss buttons
   - Others rely on default navigation bar
   - Inconsistent title sizes and positions

3. **Spacing:**
   - Different padding values (12pt, 16pt, 20pt, 24pt)
   - Inconsistent use of HeirloomSpacing design tokens
   - Ad-hoc spacing instead of standardized grid

4. **Corner Radius:**
   - Mix of hardcoded values (10, 12, 16)
   - Should use HeirloomSpacing.cardCornerRadius consistently

5. **Loading States:**
   - Different spinner styles
   - Inconsistent loading text
   - Some sheets block interaction, others don't

### Implementation Plan

#### Step 1: Create Unified Sheet Components

**File:** `Heirloom/Core/Design/Components/HeirloomSheet.swift`

```swift
// New reusable sheet header component
struct HeirloomSheetHeader: View {
    let title: String
    let subtitle: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            HStack {
                Text(title)
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.charcoal)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(.secondary)
                }
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.sm)
    }
}

// Unified primary action button
struct HeirloomPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(title)
                        .font(HeirloomFonts.bodyBold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HeirloomSpacing.md)
            .background(HeirloomColors.tomato)
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .cornerRadius(HeirloomSpacing.buttonCornerRadius)
        }
        .disabled(isLoading)
    }
}

// Unified sheet container
struct HeirloomSheetContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeirloomSheetHeader(title: title, subtitle: subtitle)

                Divider()

                ScrollView {
                    content
                        .padding(HeirloomSpacing.md)
                }
            }
            .background(HeirloomColors.appBackground)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
```

#### Step 2: Standardize Design Tokens

**File:** `Heirloom/Core/Design/HeirloomSpacing.swift`

Add missing tokens if not already present:
```swift
extension HeirloomSpacing {
    static let buttonCornerRadius: CGFloat = 12
    static let sheetPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
}
```

#### Step 3: Update CookbookScannerView

**File:** `CookbookScannerView.swift`

Replace custom header with `HeirloomSheetHeader`:
```swift
// Before:
VStack {
    HStack {
        Text("Scan Cookbook")
            .font(.title2.bold())
        // ... custom dismiss button
    }
    // ... custom layout
}

// After:
HeirloomSheetContainer(
    title: "Scan Cookbook",
    subtitle: cookbookName.isEmpty ? nil : "Adding to \(cookbookName)"
) {
    // Content here
}
```

Replace custom buttons with `HeirloomPrimaryButton`:
```swift
// Before:
Button {
    processImage()
} label: {
    Text("Extract Recipe")
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.green)
        .cornerRadius(10)
}

// After:
HeirloomPrimaryButton(
    title: "Extract Recipe",
    isLoading: isProcessing,
    action: processImage
)
```

#### Step 4: Update BulkImportView

**File:** `BulkImportView.swift`

Apply same pattern:
- Replace header with `HeirloomSheetHeader`
- Use `HeirloomPrimaryButton` for actions
- Standardize spacing with HeirloomSpacing tokens
- Use consistent corner radius values

#### Step 5: Update ImportProgressView

**File:** `ImportProgressView.swift`

Ensure consistency with:
- Standard header layout
- Unified loading spinner styles
- Consistent error state presentation
- Standard "Done" button styling

### Acceptance Criteria

- ✅ All import sheets use `HeirloomSheetHeader` component
- ✅ All action buttons use `HeirloomPrimaryButton` or standard button styles
- ✅ All spacing uses HeirloomSpacing tokens (no hardcoded values)
- ✅ All corner radius uses design tokens (no magic numbers)
- ✅ All sheets have consistent presentation detents
- ✅ Loading states are visually consistent across all sheets
- ✅ Error states use same styling and positioning
- ✅ Sheets have same background color (HeirloomColors.appBackground)

### Testing Checklist

- [ ] CookbookScannerView header matches design
- [ ] BulkImportView uses consistent buttons
- [ ] ImportProgressView loading state is consistent
- [ ] All sheets have same corner radius
- [ ] Spacing is uniform across all sheets
- [ ] Buttons are same height and style
- [ ] Error messages use same color/font
- [ ] Dark mode looks consistent

---

## Task #6: Reorganize Collection Structure and Shareability Rules

**Priority:** Medium (Architecture)
**Effort:** 4-6 hours
**Type:** Data Organization

### Current State

Collections are created and managed in multiple places:
- `CollectionRouter.swift` - Routes recipes to collections
- `RecipeCollection.swift` - Model definition
- Various views create collections directly
- No clear shareability rules
- No collection hierarchy or grouping

**Affected Files:**
1. `RecipeCollection.swift` - Model definition
2. `CollectionRouter.swift` - Routing logic
3. `CollectionListView.swift` - Display logic
4. `RecipeDetailView.swift` - Collection membership UI

### Problems to Solve

**1. Collection Type Confusion:**
```swift
enum CollectionType: String, Codable {
    case fromFriends
    case webImports
    case videoImports
    case photoImports
    case cookbook
    case theme
    case custom
}
```

**Issues:**
- Not clear which are system-managed vs user-created
- No distinction between import sources vs organizational collections
- "theme" is special but not clearly differentiated
- Missing "default" or "all recipes" concept

**2. Shareability Rules Are Unclear:**

Current questions without clear answers:
- Can users share "From Friends" collection? (Probably not)
- Can users share "From Web" collection? (Maybe?)
- Can users share custom collections? (Probably yes)
- Can users share theme collections? (Probably not - licensing issues)
- Can users share cookbook collections? (Maybe - depends on cookbook source)

**3. No Collection Hierarchy:**

Current flat structure:
```
- From Friends (system)
- From Web (system)
- From Videos (system)
- From Photos (system)
- Cookbook Pages (auto-created)
- Italian Cookbook (auto-created)
- My Favorites (user-created)
- Dinner Ideas (user-created)
```

Could be organized:
```
📥 Imported
  - From Friends
  - From Web
  - From Videos
  - From Photos

📚 Cookbooks
  - Cookbook Pages
  - Italian Cookbook
  - French Classics

✨ Themes (if Phase A3 enabled)
  - Heritage Recipes
  - Regional Classics

📁 My Collections
  - My Favorites
  - Dinner Ideas
```

**4. Query Performance:**

Current queries fetch all collections:
```swift
@Query(sort: \RecipeCollection.createdDate)
private var allCollections: [RecipeCollection]
```

Better approach:
```swift
// Separate queries for better performance
@Query(
    filter: #Predicate { $0.collectionType == "custom" },
    sort: \RecipeCollection.name
)
private var userCollections: [RecipeCollection]

@Query(
    filter: #Predicate { $0.collectionType.isSystemType },
    sort: \RecipeCollection.displayOrder
)
private var systemCollections: [RecipeCollection]
```

### Implementation Plan

#### Step 1: Refine Collection Type Hierarchy

**File:** `RecipeCollection.swift`

```swift
// Add to RecipeCollection model

/// Collection category for organizational grouping
enum CollectionCategory: String, Codable {
    case imported      // System-managed import collections
    case cookbooks     // Auto-created from cookbook scans
    case themes        // Curated theme collections (Phase A3)
    case user          // User-created custom collections
}

/// Computed property for category
var category: CollectionCategory {
    switch collectionType {
    case .fromFriends, .webImports, .videoImports, .photoImports:
        return .imported
    case .cookbook:
        return .cookbooks
    case .theme:
        return .themes
    case .custom:
        return .user
    }
}

/// Whether this collection type can be shared
var canShare: Bool {
    switch collectionType {
    case .fromFriends:
        // Don't allow resharing recipes from friends
        return false
    case .webImports, .videoImports, .photoImports:
        // Import sources can be shared (user's own curation)
        return true
    case .cookbook:
        // TODO: Check copyright status of cookbook
        // For now, allow sharing (assume user owns cookbook)
        return true
    case .theme:
        // Don't allow sharing theme collections (licensing)
        return false
    case .custom:
        // User collections can be shared
        return true
    }
}

/// Whether this collection is system-managed (not deletable)
var isSystemManaged: Bool {
    switch collectionType {
    case .fromFriends, .webImports, .videoImports, .photoImports, .theme:
        return true
    case .cookbook, .custom:
        return false
    }
}

/// Display order for system collections
var displayOrder: Int {
    switch collectionType {
    case .fromFriends: return 10
    case .webImports: return 20
    case .videoImports: return 30
    case .photoImports: return 40
    case .cookbook: return 100  // Cookbooks after import sources
    case .theme: return 200      // Themes after cookbooks
    case .custom: return 300     // User collections last
    }
}
```

#### Step 2: Add Collection Grouping to CollectionListView

**File:** `CollectionListView.swift`

```swift
struct CollectionListView: View {
    @Query private var allCollections: [RecipeCollection]

    // Group collections by category
    private var groupedCollections: [CollectionCategory: [RecipeCollection]] {
        Dictionary(grouping: allCollections) { $0.category }
    }

    var body: some View {
        List {
            // Imported section
            if let imported = groupedCollections[.imported], !imported.isEmpty {
                Section("Imported") {
                    ForEach(imported.sorted(by: { $0.displayOrder < $1.displayOrder })) { collection in
                        CollectionRow(collection: collection)
                    }
                }
            }

            // Cookbooks section
            if let cookbooks = groupedCollections[.cookbooks], !cookbooks.isEmpty {
                Section("Cookbooks") {
                    ForEach(cookbooks.sorted(by: { $0.name < $1.name })) { collection in
                        CollectionRow(collection: collection)
                            .swipeActions {
                                if !collection.isSystemManaged {
                                    Button(role: .destructive) {
                                        deleteCollection(collection)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }

            // User collections section
            if let userCollections = groupedCollections[.user], !userCollections.isEmpty {
                Section("My Collections") {
                    ForEach(userCollections.sorted(by: { $0.name < $1.name })) { collection in
                        CollectionRow(collection: collection)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteCollection(collection)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            // Add collection button
            Section {
                Button {
                    showCreateCollection = true
                } label: {
                    Label("New Collection", systemImage: "folder.badge.plus")
                }
            }
        }
        .navigationTitle("Collections")
    }
}
```

#### Step 3: Enforce Shareability Rules

**File:** `RecipeDetailView.swift` or `CollectionDetailView.swift`

```swift
// In share menu/button
Button {
    if collection.canShare {
        shareCollection(collection)
    } else {
        showCannotShareAlert = true
    }
} label: {
    Label("Share Collection", systemImage: "square.and.arrow.up")
}
.disabled(!collection.canShare)

// Alert explanation
.alert("Cannot Share Collection", isPresented: $showCannotShareAlert) {
    Button("OK") { }
} message: {
    Text(shareabilityExplanation(for: collection))
}

private func shareabilityExplanation(for collection: RecipeCollection) -> String {
    switch collection.collectionType {
    case .fromFriends:
        return "Collections of recipes from friends cannot be reshared to prevent unauthorized distribution."
    case .theme:
        return "Theme collections are curated content and cannot be shared individually."
    default:
        return "This collection cannot be shared."
    }
}
```

#### Step 4: Optimize Collection Queries

**File:** `CollectionListView.swift` or wherever collections are queried

```swift
// Instead of single query for all collections
@Query(sort: \RecipeCollection.createdDate)
private var allCollections: [RecipeCollection]

// Use category-specific queries for better performance
@Query(
    filter: #Predicate { $0.collectionType == "custom" },
    sort: \RecipeCollection.name
)
private var userCollections: [RecipeCollection]

@Query(
    filter: #Predicate {
        $0.collectionType == "webImports" ||
        $0.collectionType == "videoImports" ||
        $0.collectionType == "photoImports" ||
        $0.collectionType == "fromFriends"
    },
    sort: \RecipeCollection.displayOrder
)
private var importCollections: [RecipeCollection]

@Query(
    filter: #Predicate { $0.collectionType == "cookbook" },
    sort: \RecipeCollection.name
)
private var cookbookCollections: [RecipeCollection]
```

#### Step 5: Add Collection Icons

**File:** `RecipeCollection.swift`

```swift
// Better icon selection based on category
var categoryIcon: String {
    switch category {
    case .imported:
        return "square.and.arrow.down"  // Import arrow
    case .cookbooks:
        return "book.closed"             // Book
    case .themes:
        return "sparkles"                // Sparkles
    case .user:
        return "folder"                  // Folder
    }
}

// Collection-specific icons remain for individual display
var displayIcon: String {
    // Use iconName if set, otherwise use category default
    if !iconName.isEmpty {
        return iconName
    }
    return categoryIcon
}
```

### Acceptance Criteria

- ✅ Collections are grouped by category in UI
- ✅ System-managed collections cannot be deleted
- ✅ Shareability rules are enforced (cannot share theme/friend collections)
- ✅ User sees explanation when trying to share restricted collection
- ✅ Collection queries are optimized by category
- ✅ Collections have consistent icons based on category
- ✅ Display order is logical (imported → cookbooks → themes → user)
- ✅ Swipe-to-delete only available for deletable collections

### Testing Checklist

- [ ] Collections are visually grouped in CollectionListView
- [ ] Cannot delete "From Friends" collection
- [ ] Cannot delete "From Web" collection
- [ ] CAN delete "My Italian Cookbook" collection
- [ ] CAN delete user-created collections
- [ ] Share button disabled for theme collections
- [ ] Share button disabled for "From Friends" collection
- [ ] Share button enabled for custom collections
- [ ] Alert shows when trying to share restricted collection
- [ ] Collection list loads quickly (check with 50+ collections)

---

## Task #27: Improve Multi-Recipe Bounding Box Accuracy

**Priority:** Medium (Quality Improvement)
**Effort:** 3-4 hours (Phase 1: overlap detection + fallback)
**Type:** Detection Accuracy

### Current State

Test Suite 6 (Test 6.1) revealed that multi-recipe detection struggles with side-by-side cookbook layouts. The Claude API vision model detects the correct number of recipes and titles, but returns incorrect bounding boxes.

**Test Case Evidence:**
- **Page:** "Hearty Mid-Week Supper" with 2 recipes side-by-side
- **Expected:** Pork and Lentil Soup (left) + Easy Biscuit Swirls (right)
- **Actual Result:**
  - Recipe 1 bbox captured Recipe 2's text instead ("Easy Biscuit Swirls")
  - Recipe 2 bbox captured only partial text (failed quality validation)
- **Outcome:** 1 recipe inserted (wrong one), 1 recipe rejected (correct)

**Impact:**
- Multi-recipe detection works (finds correct count and titles)
- Quality validation works (rejects incomplete recipes)
- **Problem:** Bounding box coordinates misalign for side-by-side layouts
- Users get wrong recipes or incomplete extractions

### Problem Analysis

**Root Cause:** Bounding boxes are percentage-based (0-100 scale) and appear to overlap or misalign when recipes are positioned horizontally next to each other on the same page.

**Current Architecture:**
1. `AIRecipeExtractor.detectRecipes()` calls Claude API with vision
2. Claude returns: `[{title, confidence, boundingBox: {x, y, width, height}}]`
3. `extractRecipesFromImage()` crops image using bounding boxes
4. Extracts each cropped region separately

**Why It Fails:**
- Side-by-side recipes have horizontal adjacency
- Bounding boxes overlap or capture wrong spatial regions
- Percentage-based coordinates don't account for layout complexity
- Claude vision model optimized for vertical recipe layouts

### Implementation Options

#### **Option 1: Bounding Box Overlap Detection** (Recommended for Phase 1)

Add validation to detect overlapping bounding boxes and fall back to alternative extraction.

**Pros:**
- Simple to implement
- No additional API costs
- Low risk

**Cons:**
- Doesn't fix root cause
- Falls back to less optimal extraction

**Implementation:**
```swift
// In AIRecipeExtractor.swift

/// Validates bounding boxes don't overlap excessively
private func validateBoundingBoxes(_ boxes: [BoundingBox]) -> Bool {
    for (i, box1) in boxes.enumerated() {
        for (j, box2) in boxes.enumerated() where i < j {
            let overlapArea = calculateOverlap(box1, box2)
            if overlapArea > 0.3 { // 30% overlap threshold
                Log.warning("⚠️ Bounding boxes overlap excessively", category: .import, metadata: [
                    "recipe1": i,
                    "recipe2": j,
                    "overlap": overlapArea
                ])
                return false
            }
        }
    }
    return true
}

/// Calculates overlap percentage between two bounding boxes
private func calculateOverlap(_ box1: BoundingBox, _ box2: BoundingBox) -> Double {
    let x1 = max(box1.x, box2.x)
    let y1 = max(box1.y, box2.y)
    let x2 = min(box1.x + box1.width, box2.x + box2.width)
    let y2 = min(box1.y + box1.height, box2.y + box2.height)

    if x2 < x1 || y2 < y1 {
        return 0.0 // No overlap
    }

    let overlapWidth = x2 - x1
    let overlapHeight = y2 - y1
    let overlapArea = overlapWidth * overlapHeight

    let box1Area = box1.width * box1.height
    let box2Area = box2.width * box2.height
    let minArea = min(box1Area, box2Area)

    return overlapArea / minArea
}

/// Modified extractRecipesFromImage to use validation
func extractRecipesFromImage(...) async throws -> [ExtractedRecipe] {
    // ... existing detection code ...

    let detectedRecipes = try await detectRecipes(image: image)
    let boundingBoxes = detectedRecipes.map { $0.boundingBox }

    // Validate bounding boxes
    if !validateBoundingBoxes(boundingBoxes) {
        Log.warning("⚠️ Invalid bounding boxes detected - using fallback extraction", category: .import)
        return try await fallbackExtraction(image: image, recipeCount: detectedRecipes.count)
    }

    // ... continue with normal extraction ...
}

/// Fallback extraction without bounding boxes
private func fallbackExtraction(image: UIImage, recipeCount: Int) async throws -> [ExtractedRecipe] {
    // Option A: Extract full page and ask Claude to separate recipes
    let fullPageText = try await performOCR(on: image)

    let separationPrompt = """
    This image contains \(recipeCount) recipes. Please extract each recipe separately.

    Full OCR text:
    \(fullPageText)

    Return array of \(recipeCount) recipes in JSON format.
    """

    return try await sendClaudeRequest(
        prompt: separationPrompt,
        image: image,
        responseFormat: .jsonArray
    )
}
```

#### **Option 2: Improved Prompt Engineering**

Update detection prompt to request more precise bounding boxes for side-by-side layouts.

**Implementation:**
```swift
let detectionPrompt = """
Analyze this image and detect ALL recipes present.

IMPORTANT: If recipes are positioned SIDE-BY-SIDE (horizontally adjacent), ensure bounding boxes:
1. Do NOT overlap
2. Capture only the text for that specific recipe
3. Use precise percentage coordinates
4. Account for horizontal adjacency (left recipe vs right recipe)

For each recipe, return:
{
  "title": "Recipe Title",
  "confidence": "high" | "medium" | "low",
  "boundingBox": {
    "x": <percentage from left>,
    "y": <percentage from top>,
    "width": <percentage of image width>,
    "height": <percentage of image height>
  },
  "layoutPosition": "left" | "right" | "center" | "full-width"
}
"""
```

**Pros:** No code changes needed
**Cons:** May not solve Claude API limitations

#### **Option 3: Two-Pass Extraction Strategy**

1. First pass: Detect recipes and get titles
2. Second pass: For each title, ask Claude to extract just that specific recipe by name

**Implementation:**
```swift
func extractWithTwoPassStrategy(image: UIImage) async throws -> [ExtractedRecipe] {
    // Pass 1: Detect recipe titles only
    let titles = try await detectRecipeTitles(image: image)

    // Pass 2: Extract each recipe by title
    var recipes: [ExtractedRecipe] = []
    for title in titles {
        let prompt = """
        Extract ONLY the recipe titled "\(title)" from this image.
        Ignore any other recipes present.
        """

        let recipe = try await sendClaudeRequest(
            prompt: prompt,
            image: image,
            responseFormat: .json
        )

        recipes.append(recipe)
    }

    return recipes
}
```

**Pros:** More accurate per-recipe extraction
**Cons:** 2x API calls (cost + latency)

### Recommended Approach

**Phase 1 (Immediate):** Implement Option 1 - Bounding Box Overlap Detection
- Add validation for overlapping boxes
- Implement fallback extraction strategy
- Log bbox validation failures for monitoring
- **Effort:** 3-4 hours

**Phase 2 (If needed):** Combine Option 1 + Option 2
- Keep overlap detection as safety net
- Improve prompt to request better boxes
- **Effort:** 1-2 hours

**Phase 3 (Future):** Implement Option 3 if accuracy still poor
- Two-pass extraction for complex layouts
- Only use for side-by-side detection
- **Effort:** 2-3 hours

### Acceptance Criteria

- ✅ Side-by-side recipes extracted correctly 80%+ of time
- ✅ Bounding box overlap detection implemented
- ✅ Fallback extraction strategy for invalid boxes
- ✅ Test with 5+ different cookbook layouts
- ✅ Log bbox validation failures for monitoring
- ✅ Quality validation continues to work correctly

### Files to Modify

- `AIRecipeExtractor.swift` - Add bbox validation logic
- Add `validateBoundingBoxes()` helper
- Add `calculateOverlap()` helper
- Implement `fallbackExtraction()` method
- Update `extractRecipesFromImage()` to use validation

### Testing Plan

**Test Cases:**
1. Side-by-side 2-recipe layout (like "Hearty Mid-Week Supper")
2. Vertical stacked 2-recipe layout
3. 3-column recipe layout
4. Full-page single recipe (no bbox issues expected)
5. 4-recipe grid layout

**Success Metrics:**
- 80%+ accuracy for side-by-side layouts
- No regression on vertical layouts
- Fallback triggered <20% of time
- Quality validation rejection rate unchanged

---

## Task #10: Create Missing Firestore Composite Index

**Priority:** Low (Backend)
**Effort:** 30 minutes
**Type:** Database Configuration

### Current State

Missing Firestore composite index for connections feature. This may be causing slow queries or query failures when:
- Fetching user connections
- Querying recipes shared between connections
- Looking up connection status

**Required When:**
- Using Firebase backend (`backendConfig.isFirebaseActive = true`)
- Connections feature is enabled
- Users have multiple connections

**Files Affected:**
1. `backend/firestore.indexes.json` - Index definitions
2. Firebase Console - Manual index creation (alternative)

### Problem to Solve

**Error Symptoms:**
```
Error: The query requires an index. You can create it here:
https://console.firebase.google.com/project/.../firestore/indexes?create_composite=...
```

**Missing Index:**
```javascript
// Likely for connections collection
{
  collectionGroup: "connections",
  queryScope: "COLLECTION",
  fields: [
    { fieldPath: "userId", order: "ASCENDING" },
    { fieldPath: "status", order: "ASCENDING" },
    { fieldPath: "createdAt", order: "DESCENDING" }
  ]
}
```

### Implementation Plan

#### Option A: Automated via firestore.indexes.json (Recommended)

**File:** `backend/firestore.indexes.json`

1. **Locate or create** `firestore.indexes.json`:
```bash
cd /path/to/heirloom/backend
# Create if doesn't exist
touch firestore.indexes.json
```

2. **Add index definition:**
```json
{
  "indexes": [
    {
      "collectionGroup": "connections",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "status",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "sharedRecipes",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "recipientId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "isAccepted",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "sharedAt",
          "order": "DESCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
```

3. **Deploy indexes:**
```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy indexes
firebase deploy --only firestore:indexes
```

4. **Wait for index build** (10-60 minutes depending on data size):
```bash
# Check index status
firebase firestore:indexes

# Or check in Firebase Console:
# https://console.firebase.google.com/project/YOUR_PROJECT/firestore/indexes
```

#### Option B: Manual via Firebase Console (Quick Alternative)

1. **Navigate to Firebase Console:**
   - Go to https://console.firebase.google.com
   - Select your Heirloom project
   - Click "Firestore Database" in left sidebar
   - Click "Indexes" tab

2. **Click "Create Index"**

3. **Configure index:**
   - Collection ID: `connections`
   - Add fields:
     - Field 1: `userId` (Ascending)
     - Field 2: `status` (Ascending)
     - Field 3: `createdAt` (Descending)
   - Query scope: Collection

4. **Click "Create"**

5. **Repeat for sharedRecipes:**
   - Collection ID: `sharedRecipes`
   - Fields:
     - `recipientId` (Ascending)
     - `isAccepted` (Ascending)
     - `sharedAt` (Descending)

6. **Wait for build to complete** (shows in Indexes tab)

### Verification

**Test Query Performance:**
```swift
// Before index (slow or fails):
let query = db.collection("connections")
    .whereField("userId", isEqualTo: currentUserId)
    .whereField("status", isEqualTo: "active")
    .order(by: "createdAt", descending: true)

let connections = try await query.getDocuments()
// ❌ Error: Missing index

// After index (fast):
let connections = try await query.getDocuments()
// ✅ Returns in < 100ms
```

**Check Firestore Logs:**
```
# Before index:
⚠️ Query requires index: connections (userId ASC, status ASC, createdAt DESC)

# After index:
✅ Query completed in 45ms (3 documents)
```

### Acceptance Criteria

- ✅ `firestore.indexes.json` contains connections index definition
- ✅ `firestore.indexes.json` contains sharedRecipes index definition
- ✅ Indexes deployed to Firebase
- ✅ Index status shows "Enabled" in Firebase Console
- ✅ Connection queries execute without index warnings
- ✅ Shared recipe queries execute without index warnings

### Testing Checklist

- [ ] `firestore.indexes.json` file exists in backend directory
- [ ] Firebase CLI is installed and authenticated
- [ ] Indexes deployed successfully (`firebase deploy --only firestore:indexes`)
- [ ] Firebase Console shows indexes as "Enabled"
- [ ] Connection query performance is < 100ms
- [ ] No "missing index" errors in Firestore logs
- [ ] Queries return correct results

---

## Summary

### Task Priorities After Manual Testing

**✅ Testing Complete - Results:**
- 16/17 tests passed (94% pass rate)
- 1 edge case bug found (Task #26 - share extension crash recovery)
- 1 quality improvement found (Task #27 - bbox accuracy for side-by-side layouts)

**Recommended Priority Order:**
1. **Task #10** - Firestore index (30 min) - Quick backend fix
2. **Task #27** - Bounding box accuracy (3-4 hours) - Improves multi-recipe extraction
3. **Task #5** - Redesign sheets (3-4 hours) - UX polish and consistency
4. **Task #6** - Reorganize collections (4-6 hours) - Architecture improvement
5. **Task #26** - Share extension crash recovery (deferred) - Rare edge case

### Estimated Time to 100% Completion

- ✅ Manual testing: Complete
- ✅ Bug fixes: 5 issues resolved during testing
- Task #10 (index): 0.5 hours
- Task #27 (bbox accuracy): 3-4 hours
- Task #5 (sheets): 3-4 hours
- Task #6 (collections): 4-6 hours

**Total: 11-15 hours** remaining to complete all polish work

---

## Next Steps

1. ✅ **Run Manual Test Plan** - COMPLETE (16/17 tests passed)
2. ✅ **Document Test Results** - COMPLETE (MANUAL_TEST_RESULTS.md updated)
3. ✅ **Fix Critical Bugs** - COMPLETE (5 issues resolved)
4. ✅ **Prioritize Remaining Tasks** - COMPLETE (see priority order above)
5. **Execute Remaining Tasks** in order:
   - Task #10: Firestore index (quick backend fix)
   - Task #27: Bounding box accuracy (quality improvement)
   - Task #5: Redesign sheets (UX polish)
   - Task #6: Reorganize collections (architecture)

---

**Document Created:** 2026-02-01
**Last Updated:** 2026-02-01 (Post-testing)
**Status:** ✅ Testing complete - Ready for remaining polish work
