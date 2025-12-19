# Heirloom - Key File Paths Reference

## Models (Core/Models/)

| File | Path | Purpose |
|------|------|---------|
| **Recipe.swift** | `Core/Models/Recipe.swift` | Primary recipe entity, ~413 lines |
| **RecipeComment.swift** | `Core/Models/RecipeComment.swift` | Comments with threading & analysis, ~219 lines |
| **RecipeCardBack.swift** | `Core/Models/RecipeCardBack.swift` | Card back customization, ~221 lines |
| **Ingredient.swift** | `Core/Models/Ingredient.swift` | Parsed ingredients with units, ~160+ lines |
| **RecipeCollection.swift** | `Core/Models/RecipeCollection.swift` | Organization collections |
| **Tag.swift** | `Core/Models/Tag.swift` | Recipe tags |
| **DinnerParty.swift** | `Core/Models/DinnerParty.swift` | Dinner party events |
| **CardStyle.swift** | `Core/Models/CardStyle.swift` | Front side customization |
| **Sticker.swift** | `Core/Models/Sticker.swift` | Decorative stickers |
| **Annotation.swift** | `Core/Models/Annotation.swift` | User annotations |
| **ShoppingCartRecipe.swift** | `Core/Models/ShoppingCartRecipe.swift` | Shopping list items |
| **SchemaV1.swift** | `Core/Models/SchemaV1.swift` | Schema definition, ~49 lines |

## Services (Core/Services/)

### Comment & Analysis
| File | Path | Purpose | Lines |
|------|------|---------|-------|
| **CommentService.swift** | `Core/Services/CommentService.swift` | CRUD operations for comments | 328 |
| **CommentAnalysisService.swift** | `Core/Services/AI/CommentAnalysisService.swift` | AI sentiment/topic analysis | 348 |

### Sharing
| File | Path | Purpose | Lines |
|------|------|---------|-------|
| **CloudKitShareService.swift** | `Core/Services/CloudKitShareService.swift` | Network sharing via CloudKit | 385 |
| **RecipeShareService.swift** | `Core/Services/RecipeShareService.swift` | Local sharing (text/PDF) | 364 |

### Storage & Data
| File | Path | Purpose | Lines |
|------|------|---------|-------|
| **ImageStorageService.swift** | `Core/Services/Storage/ImageStorageService.swift` | File-safe image handling | 100+ |
| **ImageCache.swift** | `Core/Services/Storage/ImageCache.swift` | Memory image caching | ~70 |
| **IngredientParser.swift** | `Core/Services/IngredientParser.swift` | Parse ingredient strings | ~260 |
| **RecipeImportService.swift** | `Core/Services/RecipeImportService.swift` | Import recipes | 500+ |

### Other Services
| File | Path | Purpose |
|------|------|---------|
| **RemindersService.swift** | `Core/Services/RemindersService.swift` | Cooking reminders |
| **CloudKitMonitoringService.swift** | `Core/Services/CloudKitMonitoringService.swift` | CloudKit health monitoring |

### AI Services
| File | Path | Purpose |
|------|------|---------|
| **AnthropicAIService.swift** | `Core/Services/AI/Clients/AnthropicAIService.swift` | Claude API client |
| **AIRecipeExtractor.swift** | `Core/Services/AI/AIRecipeExtractor.swift` | Extract recipes from images |
| **AIIngredientParser.swift** | `Core/Services/AI/AIIngredientParser.swift` | AI-powered ingredient parsing |
| **AIConfiguration.swift** | `Core/Services/AI/Configuration/AIConfiguration.swift` | API configuration |
| **AIError.swift** | `Core/Services/AI/Utils/AIError.swift` | AI error types |

## Views (Features/)

### Comments Feature (NEW)
| File | Path | Purpose | Lines |
|------|------|---------|-------|
| **RecipeCommentListView.swift** | `Features/Comments/Views/RecipeCommentListView.swift` | Comment list with filters | 250+ |
| **RecipeCommentView.swift** | `Features/Comments/Views/RecipeCommentView.swift` | Individual comment component | 339 |
| **CardBackEditorView.swift** | `Features/Comments/Views/CardBackEditorView.swift` | Card back customization | 250+ |

### Recipe Detail
| File | Path | Purpose | Lines |
|------|------|---------|-------|
| **RecipeDetailView.swift** | `Features/Recipes/RecipeDetail/RecipeDetailView.swift` | Main recipe detail screen | 800+ |

### Recipe List
| File | Path | Purpose |
|------|------|---------|
| **RecipeListView.swift** | `Features/Recipes/RecipeList/` | Recipe list screen |

### Recipe Edit/Create
| File | Path | Purpose |
|------|------|---------|
| **RecipeEditorView.swift** | `Features/Recipes/RecipeEditor/` | Recipe editor |
| **RecipeEditView.swift** | `Features/Recipes/RecipeEdit/` | Recipe edit detail |

### Cooking & Import
| File | Path | Purpose |
|------|------|---------|
| **CookingModeView.swift** | `Features/Recipes/CookingMode/` | Active cooking UI |
| **RecipeImportView.swift** | `Features/Recipes/RecipeImport/` | Recipe import from URL |
| **CookbookScannerView.swift** | `Features/Recipes/CookbookScanner/` | OCR cookbook scanning |
| **BulkImportView.swift** | `Features/Recipes/BulkImport/` | Batch recipe import |

### Other Features
| File | Path | Purpose |
|------|------|---------|
| **CardPersonalizationView.swift** | `Features/CardPersonalization/` | Card front customization |
| **CloudKitSharingView.swift** | `Features/CloudKitSharing/` | Share setup UI |
| **CollectionsView.swift** | `Features/Collections/` | Collection management |
| **DinnerPartyView.swift** | `Features/DinnerParty/` | Dinner party feature |
| **ScalingView.swift** | `Features/Scaling/` | Recipe scaling/servings |
| **ShoppingListView.swift** | `Features/Shopping/` | Shopping list |
| **TagManagementView.swift** | `Features/Tags/` | Tag organization |
| **SettingsView.swift** | `Features/Settings/` | App settings |
| **OnboardingView.swift** | `Features/Onboarding/` | First-run experience |

## Design System (Core/Design/)

| File | Path | Purpose |
|------|------|---------|
| **Colors.swift** | `Core/Design/Colors.swift` | HeirloomColors constants |
| **Typography.swift** | `Core/Design/Typography.swift` | HeirloomFonts & HeirloomSpacing |
| **ButtonStyles.swift** | `Core/Design/Components/ButtonStyles.swift` | Custom button styles |
| **ToastView.swift** | `Core/Design/Components/ToastView.swift` | Toast notification component |
| **LoadingViews.swift** | `Core/Design/Components/LoadingViews.swift` | Loading indicators |
| **EmptyStateView.swift** | `Core/Design/Components/EmptyStateView.swift` | Empty state placeholders |
| **DataErrorView.swift** | `Core/Design/Components/DataErrorView.swift` | Error display |

## App & Configuration

| File | Path | Purpose | Lines |
|------|------|---------|-------|
| **HeirloomApp.swift** | `App/HeirloomApp.swift` | App entry point, CloudKit init | 230 |

## Extensions (Core/Extensions/)

| File | Path | Purpose |
|------|------|---------|
| **UIImage+Helpers.swift** | `Core/Extensions/UIImage+Helpers.swift` | Image processing helpers |

## Data (Core/Data/)

| File | Path | Purpose |
|------|------|---------|
| **SampleRecipeLibrary.swift** | `Core/Data/SampleRecipeLibrary.swift` | Sample recipe data |

## Testing & Fixtures

| Location | Purpose |
|----------|---------|
| `HeirloomTests/` | Test directory |
| `HeirloomTests/Fixtures/` | Test data fixtures |
| `HeirloomTests/Services/Mocks/` | Mock services |
| `HeirloomTests/Models/` | Model tests |
| `HeirloomTests/Integration/` | Integration tests |

---

## File Size Summary

### Largest Files (by lines)
1. **RecipeDetailView.swift** (~800 lines) - Main detail screen, all actions
2. **RecipeImportService.swift** (500+ lines) - Complex import logic
3. **RecipeShareService.swift** (364 lines) - PDF generation
4. **CloudKitShareService.swift** (385 lines) - Network sharing
5. **CommentAnalysisService.swift** (348 lines) - AI integration
6. **CommentService.swift** (328 lines) - Comment CRUD

### Core Services (Most Important for Social Features)
1. CommentService.swift (328 lines)
2. CommentAnalysisService.swift (348 lines)
3. CloudKitShareService.swift (385 lines)
4. RecipeShareService.swift (364 lines)

---

## Quick Navigation

### To understand Comments feature:
1. Start: `Core/Models/RecipeComment.swift` (model structure)
2. Logic: `Core/Services/CommentService.swift` (CRUD operations)
3. Analysis: `Core/Services/AI/CommentAnalysisService.swift` (AI analysis)
4. UI: `Features/Comments/Views/RecipeCommentView.swift` (component)
5. List: `Features/Comments/Views/RecipeCommentListView.swift` (full screen)

### To understand Social Sharing:
1. Start: `App/HeirloomApp.swift` (CloudKit setup)
2. Network: `Core/Services/CloudKitShareService.swift` (sharing logic)
3. Local: `Core/Services/RecipeShareService.swift` (text/PDF)
4. UI: `Features/Recipes/RecipeDetail/RecipeDetailView.swift` (share menu)

### To understand Card Back:
1. Model: `Core/Models/RecipeCardBack.swift` (data structure)
2. Editor: `Features/Comments/Views/CardBackEditorView.swift` (customization UI)
3. Integration: `Features/Comments/Views/RecipeCommentView.swift` (display logic)

### To understand Data Persistence:
1. Schema: `Core/Models/SchemaV1.swift` (data model definition)
2. Images: `Core/Services/Storage/ImageStorageService.swift` (file storage)
3. Sync: `App/HeirloomApp.swift` (CloudKit configuration)

---

## Import Statements Reference

### For Comments Feature:
```swift
import SwiftUI
import SwiftData
// CommentService - @MainActor singleton
// RecipeComment model
// RecipeCardBack model
// CommentAnalysisService for AI
```

### For Sharing:
```swift
import CloudKit
import UIKit  // For share sheet
// CloudKitShareService
// RecipeShareService
// ImageStorageService for images
```

### For Models:
```swift
import Foundation
import SwiftData
import UIKit
```

---

## Total Code Statistics

- **Swift Files:** ~82 total
  - Core: 41 files
  - Features: 41 files
- **Total Lines:** ~10,000+ lines of Swift code
- **Models:** 12 SwiftData entities
- **Services:** 10+ services
- **Views:** 15+ view components
- **Tests:** 50+ test files

---

## Recommended Reading Order for New Developers

1. **Architecture**: Read `ARCHITECTURE_ANALYSIS.md`
2. **Quick Ref**: Read `ARCHITECTURE_QUICK_REFERENCE.md`
3. **Models**:
   - `Core/Models/Recipe.swift` - Main entity
   - `Core/Models/RecipeComment.swift` - Comment structure
   - `Core/Models/RecipeCardBack.swift` - Card customization
4. **Services**:
   - `Core/Services/CommentService.swift` - Comment management
   - `Core/Services/CloudKitShareService.swift` - Sharing
5. **Views**:
   - `Features/Recipes/RecipeDetail/RecipeDetailView.swift` - Main detail
   - `Features/Comments/Views/RecipeCommentListView.swift` - Comment list
   - `Features/Comments/Views/CardBackEditorView.swift` - Card editor
6. **App Setup**: `App/HeirloomApp.swift` - Entry point

