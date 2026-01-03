# Heirloom iOS Codebase Refactor

## Context
This is a SwiftUI recipe app with Firebase backend, CRDT sync, AI-powered parsing, and lineage tracking. The app works and is approaching beta, but has accumulated inconsistencies that will slow down future UI/UX work. We need to clean this up before adding more features.

---

## Known Issues to Fix

### 1. Duplicate Files (Delete or Consolidate)
```
./Heirloom/Core/UndoService.swift          ← DUPLICATE
./Heirloom/Core/Services/UndoService.swift ← Keep this one

./Heirloom/ShareExtension/ShareViewController.swift    ← Which is active?
./HeirloomShareExtension/ShareViewController.swift     ← Consolidate these

./Heirloom/Debug/DebugTestView.swift                   ← Move to Features/Debug
./Heirloom/Features/Debug/DebugVersionTestView.swift   ← Keep here
```

### 2. Inconsistent Feature Structure
Some features have proper organization, others don't. Standardize to:
```
Features/
├── FeatureName/
│   ├── Models/           # Feature-specific models (if any)
│   ├── ViewModels/       # @Observable or ObservableObject classes
│   ├── Views/            # SwiftUI views
│   ├── Services/         # Feature-specific services (if any)
│   └── Components/       # Feature-specific reusable components
```

**Features needing restructure:**
- `Features/Recipes/` - has good subfolder structure but no ViewModels visible
- `Features/DinnerParty/` - all views at root, no ViewModel separation
- `Features/Shopping/` - single file, needs ViewModel extraction
- `Features/Settings/` - flat structure, Privacy is nested but others aren't
- `Features/Sharing/` - has Views/ subfolder but also files at root level

### 3. Services Organization is Messy
Current `Core/Services/` has inconsistent nesting:
```
Services/
├── AI/                    # Deeply nested (AI/Clients/, AI/Utils/, etc.)
├── Analytics/             # Good
├── Firebase/              # Good  
├── Storage/               # Good
├── CRDT/                  # Good
├── DeepLink/              # Single file, doesn't need folder
├── Privacy/               # Single file, doesn't need folder
├── [12 loose .swift files] ← Should be grouped or moved
```

**Proposed restructure:**
```
Services/
├── AI/                    # Keep as-is, well organized
├── Analytics/             # Keep
├── Firebase/              # Keep
├── Storage/               # Keep
├── CRDT/                  # Keep
├── Import/                # Group: RecipeImportService, CloudRecipeImportService, RecipeMigrationService
├── Export/                # RecipeExportService
├── Parsing/               # IngredientParser, RecipeStructureParser, ImagePreprocessor, EnhancedOCRService
├── Sharing/               # QRCodeService, ShortURLService
├── Recipe/                # RecipeLineageService, RecipeVersionService
├── System/                # NetworkMonitor, RemindersService, AccessibilityAnnouncementService
├── DeepLinkHandler.swift  # Flatten - doesn't need folder
├── PrivacyConsentService.swift
├── UndoService.swift
├── CardStyleUndoManager.swift
└── UnitsConfiguration.swift
```

---

## Phase 1: Audit (No Code Changes)

Before making any changes, create `REFACTOR_AUDIT.md` with:

1. **Duplicate code scan**: Find any copy-pasted logic between files
2. **Unused file detection**: Files that aren't imported anywhere
3. **Import graph**: Which files have the most dependents (change carefully)
4. **View complexity audit**: Views over 300 lines that need ViewModel extraction
5. **Design token usage**: Grep for hardcoded colors (`#`, `Color(`, `.red`, `.blue`) and spacing values

---

## Phase 2: Design System Completion

### 2.1 Current State
You have:
- `Core/Design/Colors.swift` ✓
- `Core/Design/Typography.swift` ✓
- `Core/Design/Components/` with 8 components ✓

### 2.2 What's Missing
Create these files:
```swift
// Core/Design/Spacing.swift
enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// Core/Design/Radius.swift
enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let full: CGFloat = 9999
}

// Core/Design/Shadows.swift
enum Elevation {
    static let none: Shadow = ...
    static let sm: Shadow = ...
    static let md: Shadow = ...
    static let lg: Shadow = ...
}

// Core/Design/Animation.swift
enum Animation {
    static let quick: SwiftUI.Animation = .easeOut(duration: 0.15)
    static let standard: SwiftUI.Animation = .easeInOut(duration: 0.25)
    static let slow: SwiftUI.Animation = .easeInOut(duration: 0.4)
    static let spring: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.7)
}
```

### 2.3 Component Audit
Scan all Views for repeated UI patterns that should become components:
- Section headers
- List row styles  
- Card containers
- Icon + text rows
- Form field wrappers
- Bottom sheets
- Navigation bars (if custom)

Add missing primitives to `Core/Design/Components/`:
- `HText.swift` - Typography-aware Text wrapper
- `HButton.swift` - Standard button with loading state
- `HCard.swift` - Consistent card container
- `HTextField.swift` - Styled input field
- `HSpacer.swift` - Semantic spacing component
- `HIcon.swift` - Consistent icon sizing/coloring

---

## Phase 3: ViewModel Extraction

### Pattern to Follow
```swift
// Before: Fat View with inline logic
struct RecipeDetailView: View {
    @State private var recipe: Recipe
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        // 400 lines of view code mixed with business logic
    }
    
    private func loadRecipe() { ... }
    private func saveRecipe() { ... }
    private func shareRecipe() { ... }
}

// After: Thin View + ViewModel
@Observable
class RecipeDetailViewModel {
    var recipe: Recipe
    var isLoading = false
    var error: Error?
    
    private let recipeService: RecipeVersionService
    private let shareService: FirebaseShareService
    
    func loadRecipe() { ... }
    func saveRecipe() { ... }
    func shareRecipe() { ... }
}

struct RecipeDetailView: View {
    @State private var viewModel: RecipeDetailViewModel
    
    var body: some View {
        // Pure view code, no business logic
    }
}
```

### Views That Likely Need ViewModel Extraction
(Check line counts - anything over 200 lines is a candidate)
- `RecipeDetailView.swift`
- `RecipeEditorView.swift`
- `RecipeListView.swift`
- `ShoppingListView.swift`
- `DinnerPartyDetailView.swift`
- `CookingModeView.swift`
- `BulkImportView.swift`
- `CardPersonalizationView.swift`

---

## Phase 4: File Cleanup

### 4.1 Files to Delete (After Confirming Unused)
- [ ] `./Heirloom/Core/UndoService.swift` (duplicate)
- [ ] `.migration-progress.json` (if migration complete)
- [ ] Any `.swift` files with no imports

### 4.2 Folders to Flatten
If a folder contains only one file, flatten it:
```
Services/DeepLink/DeepLinkHandler.swift → Services/DeepLinkHandler.swift
Services/Privacy/PrivacyConsentService.swift → Services/PrivacyConsentService.swift
```

### 4.3 Build Artifacts to Gitignore
Add to `.gitignore` if not already:
```
/build/
*.xcuserstate
xcuserdata/
DerivedData/
.swiftpm/
*.ipa
*.dSYM.zip
*.dSYM
```

### 4.4 Separate Concerns
Consider moving out of main repo:
- `heirloom-deliverables/` → Separate repo or delete if obsolete
- `stickergenerator/` → Separate tool repo

---

## Phase 5: Git Branch Strategy

```
main                           # Production
├── develop                    # Integration
│
├── refactor/design-system     # Spacing, Radius, Shadows, Animation tokens
├── refactor/components        # New primitive components
├── refactor/file-cleanup      # Delete duplicates, reorganize folders
├── refactor/viewmodels        # Extract ViewModels from fat views
└── refactor/services          # Reorganize Services folder
```

### Merge Order
1. `refactor/file-cleanup` → `develop` (remove dead code first)
2. `refactor/design-system` → `develop` (foundation)
3. `refactor/components` → `develop` (new primitives)
4. `refactor/services` → `develop` (reorganize)
5. `refactor/viewmodels` → `develop` (biggest change, do last)
6. `develop` → `main`

---

## Constraints

- **Zero functional regression** - run full test suite after each phase
- **Preserve git history** - use `git mv` for moves
- **Atomic commits** - one logical change per commit
- **No new features** - refactor only
- **Update imports** - when moving files, fix all import statements
- **Run `swiftlint`** after changes if configured

---

## Output Checkpoints

After each phase, provide:
1. Files added/modified/deleted
2. Any decisions needing input
3. Test results
4. Suggested next steps

---

## Start Here

Begin with **Phase 1: Audit**. 

Run these commands and include results in `REFACTOR_AUDIT.md`:

```bash
# Find potential duplicates by filename
find . -name "*.swift" | xargs basename -a | sort | uniq -d

# Find large views (likely need ViewModel extraction)  
find . -path "*/Views/*.swift" -o -path "*/Features/*.swift" | xargs wc -l | sort -rn | head -20

# Find hardcoded colors
grep -rn "Color(" --include="*.swift" | grep -v "Core/Design" | head -30

# Find hardcoded spacing
grep -rn "padding(" --include="*.swift" | grep -E "\([0-9]+" | head -30
```

Do not modify any code until I approve the audit.