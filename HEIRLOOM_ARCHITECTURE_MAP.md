# Heirloom App - Comprehensive Architecture Map

## Project Overview
- **Total Swift Files**: 128 (organized in Core + Features structure)
- **Codebase Pattern**: MVVM with Service-based architecture
- **Data Persistence**: SwiftData with CloudKit integration
- **Minimum Requirements**: iOS 17+ (SwiftData requirement)
- **Architecture Phases**: Phase 1 (Core), Phase 2 (AI Services + Sharing)

---

## 1. PROJECT STRUCTURE OVERVIEW

```
Heirloom/
├── Heirloom/ (Main App - 128 Swift files)
│   ├── App/                          (1 file - Entry point)
│   ├── Core/                         (Core framework)
│   │   ├── Models/                   (17 files - Data models)
│   │   ├── Services/                 (38 files - Business logic)
│   │   ├── Design/                   (Design system components)
│   │   ├── Data/                     (Sample data)
│   │   ├── Extensions/               (Utility extensions)
│   │   └── Utilities/                (Helpers)
│   └── Features/                     (Feature modules - 59 files)
│       ├── Recipes/                  (Core recipe feature)
│       ├── Shopping/                 (Shopping list)
│       ├── DinnerParty/             (Party planning)
│       ├── CardPersonalization/     (Card customization)
│       ├── Comments/                (Comment system)
│       ├── CloudKitSharing/         (Recipe sharing)
│       ├── Settings/
│       ├── Discovery/
│       └── [10+ other features]
├── HeirloomTests/                    (9 test files)
├── HeirloomShareExtension/           (Share sheet extension)
└── [Project config files]
```

---

## 2. DATA MODELS (Core/Models/ - 17 Files)

### Primary Models

| Model | File | Purpose | Key Relationships |
|-------|------|---------|-------------------|
| **Recipe** | Recipe.swift | Main recipe entity | ↔ Ingredients, Versions, Comments, CardBack, Stickers, Annotations |
| **Ingredient** | Ingredient.swift | Recipe ingredient with parsing | → Recipe, Substitutions |
| **RecipeVersion** | RecipeVersion.swift | Multi-version recipe support | → Recipe (parent) |
| **RecipeComment** | RecipeComment.swift | Comments with threading | → Recipe, Parent/Child comments |
| **RecipeCardBack** | RecipeCardBack.swift | Card back personalization | → Recipe, Stickers, Comments |
| **RecipeAnnotation** | Annotation.swift | Text annotations on cards | → Recipe |
| **RecipeSticker** | Sticker.swift | Visual stickers on cards | → Recipe |
| **DinnerParty** | DinnerParty.swift | Party planning event | ↔ DinnerPartyRecipe |
| **DinnerPartyRecipe** | DinnerParty.swift | Recipe in a party context | → DinnerParty, Recipe |
| **ProvenanceMetadata** | ProvenanceMetadata.swift | Lineage tracking (embedded) | Recipe.provenance |
| **RecipeCollection** | RecipeCollection.swift | Recipe organization | ↔ Recipes |
| **Tag** | Tag.swift | Recipe tagging | ↔ Recipes |
| **ShoppingCartRecipe** | ShoppingCartRecipe.swift | Shopping list items | → Recipe, Ingredients |
| **LineageTree** | LineageTree.swift | Lineage visualization | Nodes + Edges |
| **CardStyle** | Ingredient.swift | Card styling (stub) | → Stickers, Annotations |
| **ImportAttempt** | ImportAttempt.swift | Import history tracking | Metadata |
| **ShareOptions** | ShareOptions.swift | Sharing configuration | Settings |

### Model Relationships Map

```
Recipe (Primary Root)
├── 1-to-Many: Ingredients (cascade delete)
├── 1-to-Many: RecipeVersions (cascade delete)
│   └── Contains: title, ingredients[], instructions[], changes log
├── 1-to-Many: RecipeComments (cascade delete, self-referential threading)
├── 1-to-1: RecipeCardBack (cascade delete)
│   ├── Contains: pinnedCommentIDs[], personalTips[], rating
│   └── 1-to-Many: RecipeStickerPositions
├── 1-to-Many: RecipeStickers (cascade delete)
├── 1-to-Many: RecipeAnnotations (cascade delete)
├── 1-to-Many: RecipeCollections
├── 1-to-Many: Tags
├── 1-to-Many: ShoppingCartRecipes
├── 1-to-Many: DinnerPartyRecipes
└── 1-to-1: ProvenanceMetadata (embedded struct, not cascade)
    ├── generation: Int (lineage depth)
    ├── rootProvenanceHash: String (shared recipe identifier)
    └── cachedMetrics: AggregatedMetrics
```

---

## 3. SERVICE LAYER (Core/Services/ - 38 Files)

### Service Organization

#### AI Services (Core/Services/AI/)
- **AIServiceProtocol.swift** - Service interface
- **AnthropicAIService.swift** - Claude API client (Anthropic)
- **AIRecipeExtractor.swift** - Extract structured recipe from text
- **AIIngredientParser.swift** - Parse ingredient strings
- **CommentAnalysisService.swift** - Sentiment analysis on comments
- **AIConfiguration.swift** - API key management
- **AIError.swift** - Error types
- **AIAPITest.swift** - Testing utilities

#### CloudKit Services (Core/Services/CloudKit/)
- **CloudKitSyncCoordinator.swift** - Main sync orchestrator
- **RecipeShareService.swift** - Recipe sharing logic
- **SharedCommentService.swift** - Comment synchronization
- **PublicShareService.swift** - Public recipe sharing
- **ShareAcceptanceService.swift** - Receive shared recipes
- **SyncOperation.swift** - Sync queue operation
- **CloudKitError.swift** - Error definitions
- **CloudKitMonitoringService.swift** - Sync status monitoring

#### Image & Storage Services (Core/Services/Storage/)
- **ImageStorageService.swift** - File system image management (Actor)
- **ImageCache.swift** - In-memory image caching
- **ImagePreprocessor.swift** - Image optimization before save
- **EnhancedOCRService.swift** - OCR for recipe scanning

#### Recipe Processing Services
- **RecipeImportService.swift** - Import from URLs/text
- **RecipeStructureParser.swift** - Parse recipe structure
- **IngredientParser.swift** - Parse ingredient text
- **RecipeMigrationService.swift** - Data migration utilities
- **RecipeExportService.swift** - Export recipes (PDF/text)
- **RecipeVersionService.swift** - Version management
- **RecipeLineageService.swift** - Lineage tree building

#### Analytics & Monitoring
- **AnalyticsService.swift** - Event tracking interface
- **MixpanelService.swift** - Mixpanel integration
- **RecipeEngagementTracker.swift** - User engagement metrics
- **TrendingService.swift** - Trending recipe calculations
- **CloudRecipeImportService.swift** - Cloud-based imports

#### Other Services
- **CommentService.swift** - Comment CRUD operations
- **RemindersService.swift** - Apple Reminders integration
- **QRCodeService.swift** - QR code generation/scanning
- **DeepLinkHandler.swift** - URL scheme handling
- **PrivacyConsentService.swift** - Privacy/GDPR consent

### Service Architecture Pattern

```
Service Pattern (Singleton + @MainActor):
┌─────────────────────────────────────┐
│ @MainActor final class Service      │
│ - static let shared = Service()     │
│ - private init() {}                 │
│ - async/throws methods              │
│ - SwiftData integration             │
└─────────────────────────────────────┘

Data Flow:
View → ViewModel/State → Service → SwiftData/CloudKit
       (handles UI state)     (business logic & persistence)
```

---

## 4. CORE DESIGN SYSTEM (Core/Design/)

### Design Components (Core/Design/Components/)
- **ButtonStyles.swift** - Custom button styles
- **ToastView.swift** - Toast notifications
- **FlipCard.swift** - Animated recipe card flip
- **LoadingViews.swift** - Loading indicators
- **EmptyStateView.swift** - Empty state screens
- **DataErrorView.swift** - Error display
- **AttributionBadge.swift** - Attribution display

### Design Constants
- **Colors.swift** - HeirloomColors palette (tomato, sage, cream, etc.)
- **Typography.swift** - Font definitions (HeirloomFonts)
- **Spacing.swift** - Padding/spacing constants (HeirloomSpacing)

---

## 5. FEATURE MODULES (Features/ - 59 Files)

### Feature: Recipes (Core Functionality)
**Location**: `Features/Recipes/`
**Files**: 21 Swift files

#### Submodules:
1. **RecipeList/** - Main recipe browsing
   - RecipeListView.swift - Master list with search/filter
   - RecipeFiltersView.swift - Filter controls

2. **RecipeDetail/** - Recipe viewing
   - RecipeDetailView.swift (38KB) - Full recipe display + actions

3. **RecipeEditor/** - Recipe creation/editing
   - RecipeEditorView.swift - Form-based editor

4. **RecipeImport/** - Recipe import from URLs/OCR
   - RecipeImportView.swift - Import workflow
   - EnhancedScannerView.swift - Camera-based scanner
   - OCRReviewView.swift - OCR result review
   - RecipeSelectionView.swift - Multi-recipe selection

5. **CookingMode/** - Active cooking interface
   - CookingModeView.swift - Step-by-step cooking
   - VersionSelectorView.swift - Select recipe variant

6. **BulkImport/** - Batch recipe import
   - BulkImportView.swift
   - ImportPreviewView.swift
   - ImportProgressView.swift
   - ImportReviewView.swift

7. **Lineage/** - Recipe lineage visualization
   - LineageGraphView.swift - Graph visualization
   - LineageTimelineView.swift - Timeline display

8. **CookbookScanner/** - Scan entire cookbooks
   - CookbookScannerView.swift

### Feature: Shopping List
**Location**: `Features/Shopping/`
**Files**: 1 primary file + embedded views

- **ShoppingListView.swift** - Shopping list UI
  - Aggregates ingredients from selected recipes
  - Groups by GroceryCategory (Produce, Dairy, etc.)
  - Export to Apple Reminders
  - Check-off tracking per ingredient
  - IngredientRecipeListView - Show which recipes need each ingredient

### Feature: Dinner Party (Party Planning)
**Location**: `Features/DinnerParty/`
**Files**: 5 Swift files

- **DinnerPartyListView.swift** - List of planned parties
- **DinnerPartyDetailView.swift** - Party details
- **DinnerPartyEditorView.swift** - Create/edit party
- **DinnerPartyActiveView.swift** - During-party view (cooking timeline)
- **DinnerPartyShoppingListView.swift** - Shopping list for party
- **Key Logic**: 
  - startTimeOffset: Minutes before meal to start each recipe
  - scalingFactor: Multiply recipe for guest count
  - Timeline display based on meal time

### Feature: Card Personalization
**Location**: `Features/CardPersonalization/`
**Files**: 3 Swift files

- **CardPersonalizationView.swift** - Main editor
  - 5 Tabs: Background, Stickers, Annotations, Love Marks, Card Back
  - Preview card with flip animation
  - Save personalization changes
  
- **StickerPickerView.swift** - Sticker selection
  - Categories: Food, Badge, Emotional, Seasonal
  - Position/rotate/scale stickers
  
- **AnnotationEditorView.swift** - Text annotations
  - Styles: Handwritten, Sticky Note, Marker
  - Color picker, font size, rotation

### Feature: Comments
**Location**: `Features/Comments/`
**Files**: 5 Swift files

- **RecipeCommentListView.swift** - Comments list UI
  - Filters: Type, Source, Sentiment
  - Sort: Top Rated, Recent, Sentiment
  - Statistics display
  
- **RecipeCommentView.swift** - Individual comment + replies
  - Threading support
  - Vote/pin controls
  - Sentiment badge
  
- **CommentAttributionView.swift** - Author attribution
  
- **CommentScopePicker.swift** - Privacy selector
  - Private, Lineage (share family), Public
  
- **CardBackEditorView.swift** - Edit card back content
  - Pin comments
  - Add notes to friends
  - Layout/privacy settings

### Feature: CloudKit Sharing
**Location**: `Features/CloudKitSharing/`

- **SharePreviewView** - Preview before accepting share
- **RecipeShareService** - Share orchestration
- **Sharing workflow**: Generate link → Preview → Accept → Sync

### Feature: Discovery
**Location**: `Features/Discovery/`
- Public recipe browsing (future feature)

### Feature: Collections
**Location**: `Features/Collections/`
- Recipe organization into categories
- System collections (Favorites, Recently Cooked)

### Feature: Tags
**Location**: `Features/Tags/`
- Recipe tagging system

### Feature: Settings
**Location**: `Features/Settings/`
- App configuration
- CloudKit sync toggle
- Privacy controls

### Feature: Scaling
**Location**: `Features/Scaling/`
- Recipe ingredient scaling
- Smallify feature (scale to different serving sizes)

### Other Features
- **Stats/** - Usage statistics
- **Onboarding/** - First-launch experience
- **Debug/** - Debug utilities
- **CloudKitMonitoring/** - Sync status UI

---

## 6. VIEW HIERARCHY & NAVIGATION

### Tab Structure (ContentView)
```
App Root (HeirloomApp)
└── ContentView (TabView with 5 tabs)
    ├── Tab 0: RecipeListView (Recipes)
    │   └── NavigationStack → RecipeDetailView
    │       ├── Sheet: RecipeEditorView
    │       ├── Sheet: CookingModeView
    │       ├── Sheet: CardPersonalizationView
    │       └── Sheet: CommentsListView
    │
    ├── Tab 1: Add Recipe (Modal)
    │   └── Sheet: RecipeEditorView
    │       └── Child: RecipeImportView or Scanner
    │
    ├── Tab 2: ShoppingListView
    │   └── Sheet: IngredientRecipeListView
    │
    ├── Tab 3: DinnerPartyListView
    │   └── DinnerPartyDetailView
    │       └── DinnerPartyActiveView (during party)
    │
    └── Tab 4: SettingsView
        └── Various setting screens
```

### Deep Links & URL Schemes
- **Handled by**: DeepLinkHandler (singleton)
- **Scheme**: `heirloom://`
- **Handlers**:
  - `recipe/:recipeId` - Open recipe detail
  - `share/:shareToken` - Accept recipe share
  - `import?url=` - Import from URL

---

## 7. DATA FLOW PATTERNS

### Recipe Creation Flow
```
RecipeEditorView
  ↓ (user enters data)
RecipeImportService (if importing)
  ↓ (parse with AI)
AIRecipeExtractor / IngredientParser
  ↓ (structured data)
Recipe + Ingredients created
  ↓
SwiftData ModelContext.insert()
  ↓
context.save()
  ↓
CloudKitSyncCoordinator (async push to CloudKit)
```

### Recipe Sharing Flow
```
RecipeDetailView → Share button
  ↓
RecipeShareService.createShare()
  ↓
CloudKitSyncCoordinator (sync to public database)
  ↓
Generate share link
  ↓
DeepLinkHandler (user receives link)
  ↓
SharePreviewView (preview before accept)
  ↓
ShareAcceptanceService.acceptShare()
  ↓
RecipeVersion created with provenance
  ↓
Recipe synced locally with generation metadata
```

### Comment Flow
```
RecipeCommentView → User comment
  ↓
CommentService.addComment()
  ↓
RecipeComment created + inserted
  ↓
Recipe.comments[] updated
  ↓
context.save()
  ↓
If shared: SharedCommentService syncs to lineage
  ↓
CommentAnalysisService (AI sentiment analysis async)
```

### Shopping List Flow
```
RecipeDetailView → Add to Shopping
  ↓
ShoppingCartRecipe created
  ↓
ShoppingListView (reads @Query filtered by recipes)
  ↓
Group by GroceryCategory
  ↓
Display with recipes per ingredient
  ↓
Check off → Ingredient.isCheckedOff updated
  ↓
Export to Reminders → RemindersService.createList()
```

---

## 8. KEY ARCHITECTURAL PATTERNS

### 1. SwiftData with CloudKit
```swift
// Configuration in HeirloomApp.swift
ModelContainer initialization:
- Primary: CloudKit enabled (.automatic)
- Fallback: Local storage only if CloudKit fails
- Schema: SchemaV1 (versioned for migrations)

Sync Strategy:
- Automatic local CloudKit sync
- CloudKitSyncCoordinator for complex operations
- Async operations don't block UI
```

### 2. Service-Based Architecture
- **Singleton Services**: `@MainActor final class`
- **Thread Safety**: All services @MainActor for UI state
- **Testability**: Protocol-based for mocking
- **Error Handling**: Custom error types per service

### 3. View State Management
- **MVVM Pattern**: Views use @State, @StateObject
- **Environment**: Services passed via @Environment
- **Bindings**: Two-way data binding with @Bindable
- **Query**: @Query for SwiftData fetching in views

### 4. Image Storage
- **Policy**: Images stored in FileSystem, not database
- **Rationale**: Recommended by Systems Architect (reduce DB bloat)
- **Service**: ImageStorageService (Actor for thread-safe access)
- **Caching**: ImageCache for in-memory layer

### 5. Versioning Strategy
- **Recipe Versions**: Complete ingredient/instruction overrides
- **Change Tracking**: Field-level change log in versions
- **Attribution**: creatorDisplayName + creationYear
- **BaseVersion**: Original recipe (isBaseVersion = true)

### 6. Provenance & Lineage
- **Embedded in Recipe**: ProvenanceMetadata (struct)
- **Lineage Tracking**: rootProvenanceHash + generation
- **Metrics**: Cached aggregated data from CloudKit
- **Sharing Context**: Visible to lineage (shares) not globally

### 7. Comment Threading & Scoping
- **Threading**: Self-referential (parentComment, replies[])
- **Scoping**: Private | Lineage | Public (default = private)
- **Sentiment**: -1.0 (negative) to 1.0 (positive)
- **Topics**: Extracted by AI for categorization

### 8. Card Personalization
- **Stickers**: Position, scale, rotation, opacity
- **Annotations**: Text + style (handwritten/sticky/marker)
- **Card Back**: Full customization with sections
- **Export**: FlipCard animation for preview

---

## 9. CRITICAL FILES FOR BUG FIXES

### High-Impact Files (Fix These First)
1. **/Heirloom/App/HeirloomApp.swift** (170 lines)
   - App initialization
   - SwiftData setup
   - Service initialization
   - Deep link setup

2. **/Heirloom/Core/Models/Recipe.swift** (599 lines)
   - Primary model with heavy computed properties
   - Provenance helpers
   - Scaling calculations

3. **/Heirloom/Features/Recipes/RecipeDetail/RecipeDetailView.swift** (38KB)
   - Main recipe display
   - All recipe interactions

4. **/Heirloom/Features/Shopping/ShoppingListView.swift** 
   - Shopping list logic
   - Ingredient grouping
   - Export functionality

5. **/Heirloom/Core/Services/CloudKit/CloudKitSyncCoordinator.swift**
   - Sync orchestration
   - Error recovery

6. **/Heirloom/Core/Services/AI/Clients/AnthropicAIService.swift**
   - AI API integration
   - Error handling for API

7. **/Heirloom/Core/Services/RecipeImportService.swift**
   - URL/text recipe import
   - Data parsing

### Model Files (Data Integrity Issues)
- Recipe.swift - Primary model
- RecipeVersion.swift - Multi-version support
- RecipeComment.swift - Threading/sentiment
- Ingredient.swift - Ingredient parsing
- ProvenanceMetadata.swift - Lineage tracking

### Service Files (Business Logic Issues)
- CloudKitSyncCoordinator.swift - Sync failures
- RecipeShareService.swift - Sharing issues
- CommentService.swift - Comment operations
- AIRecipeExtractor.swift - AI extraction failures
- ImageStorageService.swift - Image handling

---

## 10. TESTING INFRASTRUCTURE

### Test Files (9 total)
- **DiagnosticTest.swift** - Diagnostic utilities
- **RecipeVersionTests.swift** - Version functionality
- **RecipeTests.swift** - Recipe model tests
- **AIRecipeExtractorTests.swift** - AI service tests
- **IngredientParserTests.swift** - Parser tests
- **RecipeMigrationServiceTests.swift** - Migration tests
- **MultiRecipeImportFlowTests.swift** - Import flow tests
- **ShareExtensionTests.swift** - Share extension tests

### Test Helpers
- **TestFixtures.swift** - Sample data for testing

---

## 11. TECHNICAL CONSTRAINTS & CONSIDERATIONS

### SwiftData Constraints
- ✅ Requires iOS 17+
- ✅ Automatic CloudKit sync when enabled
- ❌ No partial updates (full model save)
- ❌ Limited migration support

### CloudKit Constraints
- ✅ Public/Private database separation
- ✅ Automatic conflict resolution
- ❌ No real-time sync (eventual consistency)
- ❌ 1MB record size limit

### Performance Considerations
- 📊 Use RecipeListItem DTO for list views (avoid loading all ingredients)
- 📊 Image caching to avoid repeated FileSystem access
- 📊 Lazy evaluation for expensive computations
- 📊 Batch operations for CloudKit sync

### Architecture Debts & Maintenance
1. **Stub Models**: CardStyle, Sticker (redundant with RecipeSticker/Annotation)
2. **Legacy Fields**: sharedBy, passedDownBy (replaced by provenance)
3. **Data Migration**: Manual migration path needed for schema upgrades
4. **Error Handling**: Inconsistent error types across services

---

## 12. FEATURE PRIORITY FOR BUG FIXES

### Tier 1 (Core Features - Fix First)
1. Recipe CRUD operations
2. Cooking Mode interface
3. Shopping List functionality
4. Image handling

### Tier 2 (Advanced Features - Fix Second)
1. Recipe Sharing (CloudKit)
2. Comments & Threading
3. Recipe Versions
4. Card Personalization

### Tier 3 (Enhancement Features - Fix Last)
1. Dinner Party planning
2. Discovery/Trending
3. Analytics tracking
4. Deep linking

---

## 13. DEPENDENCY GRAPH SUMMARY

```
┌─────────────────────────────────────────────────────────┐
│                      HeirloomApp                        │
│              (App Initialization & Entry)               │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
      SwiftData   Services    Views
         │           │           │
         ├─Recipe    ├─AI         ├─RecipeListView
         ├─Ingredient├─CloudKit   ├─RecipeDetailView
         ├─Version  ├─Image       ├─CookingModeView
         └─Comment  ├─Analytics   ├─ShoppingListView
                    └─...         └─...
```

**Critical Path**: Recipe → SwiftData → CloudKitSyncCoordinator → Remote DB

---

## 14. IMPLEMENTATION ROADMAP FOR 35 BUG FIXES

### Phase 1: Core Data Model Bugs (5-8 bugs)
- Recipe serialization
- Ingredient parsing consistency
- Version relationship integrity
- Provenance hash generation

### Phase 2: Service Integration Bugs (10-12 bugs)
- CloudKit sync failures
- Image storage/retrieval
- AI API error handling
- Comment persistence

### Phase 3: UI/UX Bugs (8-10 bugs)
- View state management
- Navigation issues
- Animation/transition problems
- List performance

### Phase 4: Feature-Specific Bugs (5-7 bugs)
- Shopping list aggregation
- Dinner party timing calculations
- Card personalization rendering
- Deep link handling

---

## Summary Statistics

| Category | Count | Status |
|----------|-------|--------|
| Total Swift Files | 128 | ✓ Complete |
| Core Models | 17 | ✓ Complete |
| Services | 38 | ✓ Complete |
| Feature Views | 59 | ✓ Complete |
| Test Files | 9 | ⚠ Needs coverage |
| Known Bugs | 35 | 🔴 To fix |

