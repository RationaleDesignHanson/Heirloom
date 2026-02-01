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

**If Testing Finds Bugs:**
1. Fix critical bugs immediately
2. Fix medium bugs if time allows
3. Defer low-priority bugs to backlog

**If Testing Passes Cleanly:**
1. **Task #5** - Redesign sheets (3-4 hours) - Good UX polish
2. **Task #6** - Reorganize collections (4-6 hours) - Improves organization
3. **Task #10** - Firestore index (30 min) - Only if using connections feature

### Estimated Time to 100% Completion

- Manual testing: 1-2 hours
- Bug fixes (if any): 0-2 hours
- Task #5 (sheets): 3-4 hours
- Task #6 (collections): 4-6 hours
- Task #10 (index): 0.5 hours

**Total: 9-15 hours** remaining to complete all work

---

## Next Steps

1. ✅ **Run Manual Test Plan** (Test Suites 1-11)
2. **Document Test Results** in `MANUAL_TEST_PLAN.md`
3. **Fix Any Critical Bugs** discovered during testing
4. **Decide Priority** for remaining tasks based on test outcomes
5. **Execute Remaining Tasks** (#5, #6, #10) in priority order

---

**Document Created:** 2026-02-01
**Last Updated:** 2026-02-01
**Status:** Ready for manual testing phase
