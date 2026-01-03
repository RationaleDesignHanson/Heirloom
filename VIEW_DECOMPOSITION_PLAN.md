# RecipeDetailView Decomposition Plan
**Phase 3: View Layer Decomposition**
**Target**: RecipeDetailView.swift (1,544 lines → 6 focused view components)

---

## Current State Analysis

### File Structure
- **Location**: `Heirloom/Features/Recipes/RecipeDetail/RecipeDetailView.swift`
- **Line Count**: 1,544 lines
- **Status**: Monolithic view with 14 distinct sections
- **Issue**: Single file violates Single Responsibility Principle

### Section Breakdown (by line range)
| Section | Lines | Responsibility |
|---------|-------|----------------|
| Computed Display Properties | 35-370 | Version display logic |
| Image Section | 371-378 | Hero image |
| Header Section | 379-424 | Title, favorite, badges |
| Tags and Collections | 425-523 | Organization UI |
| Metadata Section | 524-652 | Serving, times, dates |
| Start Cooking Button | 653-675 | CTA button |
| Ingredients Section | 676-825 | 150 lines - Ingredients list with scaling |
| Instructions Section | 826-872 | Step-by-step instructions |
| Notes Section | 873-889 | User notes |
| Source Section | 890-942 | Attribution |
| Comments Section | 943-1084 | 142 lines - Comments display |
| Helper Views | 1085-1104 | Utility views |
| Actions | 1105-1406 | 302 lines - Delete, duplicate, share |
| Preview | 1537-1544 | SwiftUI previews |

### Problems with Current Structure
1. **Cognitive Overload**: 1,544 lines too large to comprehend
2. **Testing Difficulty**: Cannot test individual sections in isolation
3. **Code Reuse**: Sections can't be reused in other views
4. **Merge Conflicts**: Multiple developers can't work on different sections
5. **SwiftUI Performance**: Large view bodies can impact compilation and runtime

---

## Proposed Decomposition Strategy

### Goal
Break RecipeDetailView into **6 focused, reusable SwiftUI components** (average ~250 lines each)

### Component Architecture

```
RecipeDetailView (main orchestrator, ~200 lines)
├── RecipeDetailHeader (~150 lines)
│   ├── Title, favorite button
│   ├── Version badge
│   └── Provenance info
├── RecipeMetadataSection (~200 lines)
│   ├── Tags and Collections display
│   ├── Serving selector with scaling
│   ├── Prep/cook times
│   └── Start cooking button
├── RecipeIngredientsSection (~250 lines)
│   ├── Ingredients list
│   ├── Scaling calculations
│   ├── Checkboxes
│   └── Add to shopping cart
├── RecipeInstructionsSection (~150 lines)
│   ├── Step-by-step instructions
│   ├── Step numbering
│   └── Completion checkboxes
├── RecipeNotesAndSourceSection (~150 lines)
│   ├── User notes display
│   └── Source attribution
└── RecipeCommentsSection (~200 lines)
    ├── Comments list
    ├── Add comment
    └── Comment actions
```

---

## Component Specifications

### 1. RecipeDetailHeader
**File**: `RecipeDetailHeader.swift`
**Lines**: ~150
**Purpose**: Display recipe title, favorite toggle, badges

**Props**:
```swift
struct RecipeDetailHeader: View {
    let recipe: Recipe
    let displayTitle: String
    let versionBadgeText: String?
    @Binding var showHeirloomExplanation: Bool

    var body: some View { ... }
}
```

**Responsibilities**:
- Display recipe title (with version override)
- Favorite button with persistence
- Version/generation badge
- Provenance heirloom badge
- Tap to show heirloom explanation

**Dependencies**: Recipe model, modelContext

---

### 2. RecipeMetadataSection
**File**: `RecipeMetadataSection.swift`
**Lines**: ~200
**Purpose**: Display and control recipe metadata

**Props**:
```swift
struct RecipeMetadataSection: View {
    let recipe: Recipe
    @Binding var targetServings: Int
    @Binding var servingMultiplier: Double
    @Binding var showScalingExplanation: Bool
    @Binding var showTagCollectionPicker: Bool
    @Binding var showCookingMode: Bool

    var body: some View { ... }
}
```

**Responsibilities**:
- Tags and collections display with edit button
- Serving selector dropdown with scaling
- Prep time, cook time display
- Dates (created, modified)
- Start cooking button

**Dependencies**: Recipe model, binding state

---

### 3. RecipeIngredientsSection
**File**: `RecipeIngredientsSection.swift`
**Lines**: ~250
**Purpose**: Display ingredients with scaling

**Props**:
```swift
struct RecipeIngredientsSection: View {
    let ingredients: [Ingredient]
    let servingMultiplier: Double
    let targetServings: Int
    @Environment(\.modelContext) private var modelContext

    var body: some View { ... }
}
```

**Responsibilities**:
- Display ingredients list
- Apply serving multiplier to quantities
- Show checkboxes for ingredient tracking
- Add to shopping cart functionality
- Category grouping (if implemented)

**Dependencies**: Ingredient model, ScalingEngine, modelContext

---

### 4. RecipeInstructionsSection
**File**: `RecipeInstructionsSection.swift`
**Lines**: ~150
**Purpose**: Display step-by-step cooking instructions

**Props**:
```swift
struct RecipeInstructionsSection: View {
    let instructions: [String]

    var body: some View { ... }
}
```

**Responsibilities**:
- Display numbered instruction steps
- Format instruction text
- Optional step completion checkboxes (if implemented)

**Dependencies**: None (pure view)

---

### 5. RecipeNotesAndSourceSection
**File**: `RecipeNotesAndSourceSection.swift`
**Lines**: ~150
**Purpose**: Display notes and source attribution

**Props**:
```swift
struct RecipeNotesAndSourceSection: View {
    let recipe: Recipe

    var body: some View { ... }
}
```

**Responsibilities**:
- Display user notes
- Show recipe source (URL, type)
- Attribution display
- Source icon selection

**Dependencies**: Recipe model

---

### 6. RecipeCommentsSection
**File**: `RecipeCommentsSection.swift`
**Lines**: ~200
**Purpose**: Display and manage recipe comments

**Props**:
```swift
struct RecipeCommentsSection: View {
    let recipe: Recipe
    @Binding var showComments: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View { ... }
}
```

**Responsibilities**:
- Display comments count
- "View comments" button
- Comments sheet presentation
- Add/edit/delete comments

**Dependencies**: RecipeComment model, modelContext

---

## Migration Strategy

### Phase 1: Create Component Files (4 components)
1. ✅ Create `RecipeDetailHeader.swift` with header logic
2. ✅ Create `RecipeMetadataSection.swift` with metadata UI
3. ✅ Create `RecipeIngredientsSection.swift` with ingredients list
4. ✅ Create `RecipeInstructionsSection.swift` with instructions

### Phase 2: Update RecipeDetailView
1. ✅ Import new components
2. ✅ Replace sections with component calls
3. ✅ Pass required props and bindings
4. ✅ Verify build succeeds

### Phase 3: Verify & Test
1. ✅ Manual testing in simulator
2. ✅ Verify all interactions work
3. ✅ Check performance (ScrollView smoothness)
4. ✅ Validate SwiftUI previews

### Phase 4: Additional Components (Optional)
1. Consider extracting `RecipeCommentsSection` (142 lines)
2. Consider extracting `RecipeNotesAndSourceSection` (100 lines)

---

## Success Criteria

### Code Quality
- ✅ RecipeDetailView reduced from 1,544 → <400 lines
- ✅ Each component focused on single responsibility
- ✅ Average component size ~200 lines
- ✅ No code duplication
- ✅ Clear component boundaries

### Functionality
- ✅ All existing features work identically
- ✅ No regression in user experience
- ✅ Smooth scrolling performance
- ✅ Proper state management with bindings

### Maintainability
- ✅ Components can be tested in isolation
- ✅ Components are reusable in other views
- ✅ Clear prop interfaces
- ✅ Reduced cognitive load for developers

---

## Benefits

### For Development
- **Parallel Work**: Multiple developers can work on different components
- **Faster Compilation**: Smaller files compile faster in Xcode
- **Better Testing**: Components can be tested with SwiftUI previews
- **Code Reuse**: Components can be used in RecipeCardView, RecipeListView, etc.

### For Users
- **Better Performance**: Smaller view bodies optimize SwiftUI rendering
- **Faster Iterations**: Easier to add/modify features
- **Fewer Bugs**: Isolated components reduce side effects

---

## Next Steps After Phase 3

1. **Phase 4: Code Quality & Cleanup**
   - Remove 634 print statements
   - Replace with proper logging (os.log)
   - Standardize error handling

2. **Phase 5: Architecture Modernization**
   - Convert 89 singletons to dependency injection
   - Use protocols from Phase 2 for Firebase services
   - Enable full testability

3. **Phase 6: Performance Optimization**
   - Profile RecipeDetailView performance
   - Optimize image loading
   - Lazy loading for large ingredient lists

---

## Notes

- **SwiftUI Best Practice**: Keep view bodies under 300 lines for optimal compilation
- **State Management**: Use @Binding for parent-controlled state, @State for local state
- **Environment**: Prefer @Environment over passing contexts as props
- **Preview**: Each component should have SwiftUI preview for development

---

**Status**: Ready for implementation
**Estimated Time**: 2-3 hours
**Risk Level**: Low (well-defined boundaries, no architectural changes)
