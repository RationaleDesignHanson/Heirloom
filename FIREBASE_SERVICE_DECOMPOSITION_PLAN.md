# Firebase Service Decomposition Plan
**Phase 2 Week 3: Service Layer Refactoring**

## Current State Analysis

### FirebaseSyncService.swift (1,237 lines) - GOD CLASS
Current responsibilities (violates Single Responsibility Principle):
1. Configuration & initialization
2. User authentication helpers
3. Record conversion (Recipe, Ingredient, Comment, CardBack) ↔ Firestore
4. Upload operations
5. Download operations
6. Full sync orchestration
7. Conflict resolution
8. Automatic sync
9. Firebase Storage (Images)
10. Image compression
11. Deletion operations
12. Collections & Tags sync
13. Shopping Cart sync
14. Dinner Parties sync

### FirebaseSyncService+CRDT.swift (456 lines)
CRDT-specific functionality (already separated):
- CRDT upload/download operations
- CRDT conflict resolution
- Transactional sync with vector clocks

### FirebaseAuthService.swift (367 lines)
Authentication responsibilities:
- Sign in with Apple
- Sign in with Google
- Session management
- Auth state observation

### FirebaseShareService.swift (485 lines)
Recipe sharing responsibilities:
- Create/accept/revoke shares
- Share metadata management
- Expiration handling
- Lineage tracking

## Decomposition Strategy

### 🎯 Goal: Break 1,237-line god class into 4 focused services (~300 lines each)

### Proposed Structure:

```
Heirloom/Core/Services/Firebase/
├── Core/
│   ├── FirebaseConfiguration.swift          [NEW] ~100 lines
│   └── FirebaseRecordConverter.swift         [NEW] ~400 lines
├── Sync/
│   ├── FirebaseRecipeSync.swift              [NEW] ~350 lines
│   ├── FirebaseSyncService+CRDT.swift        [KEEP] 456 lines
│   └── FirebaseCollectionSync.swift          [NEW] ~250 lines
├── Storage/
│   └── FirebaseImageService.swift            [NEW] ~200 lines
├── Auth/
│   └── FirebaseAuthService.swift             [REFACTOR] 367 lines
└── Sharing/
    └── FirebaseShareService.swift            [REFACTOR] 485 lines
```

## Detailed Decomposition Plan

### 1. FirebaseConfiguration.swift (~100 lines)
**Purpose:** Centralized Firebase initialization and configuration

**Responsibilities:**
- Firestore instance management
- Auth instance management
- Storage instance management
- User authentication helpers (currentUserId, etc.)
- Collection/document reference helpers

**Extracted from FirebaseSyncService.swift:**
- Lines 26-30: Singleton pattern
- Lines 38-46: Dependencies (db, auth)
- Lines 52-63: Configuration method
- Lines 65-83: User authentication helpers

**API:**
```swift
@MainActor
class FirebaseConfiguration {
    static let shared = FirebaseConfiguration()

    var db: Firestore { get }
    var auth: Auth { get }
    var storage: Storage { get }

    var currentUserId: String? { get }

    func configure(modelContext: ModelContext)
    func recipesCollection() throws -> CollectionReference
    func recipeDocument(id: String) throws -> DocumentReference
}
```

### 2. FirebaseRecordConverter.swift (~400 lines)
**Purpose:** Pure data transformation logic (no I/O, no side effects)

**Responsibilities:**
- Convert Recipe ↔ Firestore
- Convert Ingredient ↔ Firestore
- Convert Comment ↔ Firestore
- Convert CardBack ↔ Firestore

**Extracted from FirebaseSyncService.swift:**
- Lines 85-208: Recipe conversion
- Lines 210-259: Ingredient conversion
- Lines 261-292: Comment conversion
- Lines 294-352: Card Back conversion

**API:**
```swift
struct FirebaseRecordConverter {
    // Recipe conversion
    static func convertToFirestoreData(_ recipe: Recipe) -> [String: Any]
    static func convertFromFirestoreData(_ data: [String: Any], id: String, context: ModelContext) -> Recipe

    // Ingredient conversion
    static func convertIngredientToFirestoreData(_ ingredient: Ingredient) -> [String: Any]
    static func convertIngredientFromFirestoreData(_ data: [String: Any], id: String) -> Ingredient

    // Comment conversion
    static func convertCommentToFirestoreData(_ comment: RecipeComment) -> [String: Any]
    static func convertCommentFromFirestoreData(_ data: [String: Any], id: String) -> RecipeComment

    // CardBack conversion
    static func convertCardBackToFirestoreData(_ cardBack: RecipeCardBack) -> [String: Any]
    static func convertCardBackFromFirestoreData(_ data: [String: Any]) -> RecipeCardBack
}
```

### 3. FirebaseRecipeSync.swift (~350 lines)
**Purpose:** Recipe-level sync operations and orchestration

**Responsibilities:**
- Upload single recipe
- Download single recipe
- Full sync orchestration
- Automatic sync scheduling
- Conflict resolution (non-CRDT)
- Deletion operations

**Extracted from FirebaseSyncService.swift:**
- Lines 32-36: Published state (@Published properties)
- Lines 354-509: Upload operations
- Lines 511-536: Download operations
- Lines 538-606: Full sync
- Lines 608-766: Conflict resolution
- Lines 768-790: Helpers
- Lines 792-843: Automatic sync
- Lines 980-1070: Deletion operations

**API:**
```swift
@MainActor
class FirebaseRecipeSync: ObservableObject {
    static let shared = FirebaseRecipeSync()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published private(set) var syncError: Error?

    func uploadRecipe(_ recipe: Recipe) async throws
    func downloadRecipe(id: String) async throws -> Recipe
    func syncChanges() async throws
    func deleteRecipe(_ recipe: Recipe) async throws

    func startAutoSync()
    func stopAutoSync()
}
```

### 4. FirebaseCollectionSync.swift (~250 lines)
**Purpose:** Sync related entities and collections

**Responsibilities:**
- Ingredients subcollection sync
- Comments subcollection sync
- Collections & Tags sync
- Shopping Cart sync
- Dinner Parties sync

**Extracted from FirebaseSyncService.swift:**
- Lines 383-509: Ingredient upload/download (within uploadRecipe/downloadRecipe)
- Lines 1072-1133: Collections & Tags
- Lines 1135-1165: Shopping Cart
- Lines 1167-1201: Dinner Parties

**API:**
```swift
@MainActor
class FirebaseCollectionSync {
    static let shared = FirebaseCollectionSync()

    // Ingredients
    func syncIngredients(for recipeId: String) async throws

    // Comments
    func syncComments(for recipeId: String) async throws

    // Collections & Tags
    func syncCollections() async throws
    func syncTags() async throws

    // Shopping Cart
    func syncShoppingCart() async throws

    // Dinner Parties
    func syncDinnerParties() async throws
}
```

### 5. FirebaseImageService.swift (~200 lines)
**Purpose:** Firebase Storage operations for images

**Responsibilities:**
- Image upload to Firebase Storage
- Image download from Firebase Storage
- Image compression
- Image URL management
- Image deletion

**Extracted from FirebaseSyncService.swift:**
- Lines 845-944: Firebase Storage (Images)
- Lines 946-978: Image Compression

**API:**
```swift
@MainActor
class FirebaseImageService {
    static let shared = FirebaseImageService()

    func uploadImage(_ image: UIImage, recipeId: String) async throws -> String
    func downloadImage(from url: String) async throws -> UIImage
    func deleteImage(at url: String) async throws

    // Private helpers
    private func compressImage(_ image: UIImage, maxSizeKB: Int) -> Data?
}
```

### 6. FirebaseSyncService+CRDT.swift (456 lines) - KEEP AS IS
**Purpose:** CRDT-aware sync operations

This file is already well-separated and focused on CRDT functionality. No changes needed.

## Refactoring Sequence

### Step 1: Create Core Services
1. Create `FirebaseConfiguration.swift` - Extract configuration and authentication helpers
2. Create `FirebaseRecordConverter.swift` - Extract pure conversion functions

### Step 2: Create Specialized Services
3. Create `FirebaseImageService.swift` - Extract image operations
4. Create `FirebaseCollectionSync.swift` - Extract collection sync operations

### Step 3: Refactor Main Sync Service
5. Create `FirebaseRecipeSync.swift` - Extract recipe sync operations from FirebaseSyncService
6. Update `FirebaseSyncService.swift` to orchestrate all services (become thin coordinator)

### Step 4: Update References
7. Update all call sites to use new services
8. Update imports throughout codebase

### Step 5: Test & Validate
9. Build and verify no compilation errors
10. Run existing test suite (should pass with placeholders)
11. Update test mocks if needed

## Dependencies Between Services

```
FirebaseConfiguration (foundation)
    ↓
FirebaseRecordConverter (pure functions, no dependencies)
    ↓
FirebaseImageService → FirebaseConfiguration
    ↓
FirebaseRecipeSync → FirebaseConfiguration, FirebaseRecordConverter, FirebaseImageService
    ↓
FirebaseCollectionSync → FirebaseConfiguration, FirebaseRecordConverter
    ↓
FirebaseSyncService+CRDT → FirebaseRecipeSync, FirebaseConfiguration
```

## Benefits

### Code Quality
- ✅ Single Responsibility Principle
- ✅ Files under 400 lines (target: <400)
- ✅ Clear separation of concerns
- ✅ Easier to understand and maintain

### Testability
- ✅ Pure functions in FirebaseRecordConverter (easy to test)
- ✅ Smaller surface area per service
- ✅ Easier to mock dependencies

### Team Collaboration
- ✅ Multiple developers can work on different services
- ✅ Reduced merge conflicts
- ✅ Clear ownership boundaries

### Future Extensibility
- ✅ Easy to add new sync operations
- ✅ Easy to add new record types
- ✅ Easy to swap backend (protocol-based, Phase 2 Week 4)

## Migration Strategy

### Backwards Compatibility
During refactoring, maintain a thin `FirebaseSyncService` facade that delegates to new services. This allows gradual migration of call sites.

```swift
// Temporary facade during migration
@MainActor
class FirebaseSyncService: ObservableObject {
    static let shared = FirebaseSyncService()

    // Delegate to new services
    var isSyncing: Bool { FirebaseRecipeSync.shared.isSyncing }

    func uploadRecipe(_ recipe: Recipe) async throws {
        try await FirebaseRecipeSync.shared.uploadRecipe(recipe)
    }

    // ... other delegations
}
```

### Post-Migration
After all call sites are updated:
1. Remove facade
2. Update all imports to use specific services
3. Remove old FirebaseSyncService.swift file

## Success Criteria

✅ All services under 400 lines
✅ No compilation errors
✅ All existing tests pass (with DI placeholders)
✅ Clear separation of concerns
✅ No duplicate code
✅ Clean dependency graph

## Timeline

**Phase 2 Week 3: Service Decomposition**
- Day 1: Create core services (Configuration, Converter)
- Day 2: Create specialized services (Image, Collection)
- Day 3: Refactor main sync service (RecipeSync)
- Day 4: Update references and test
- Day 5: Commit and move to Auth/Share decomposition

---

**Status:** READY TO EXECUTE
**Next Action:** Create FirebaseConfiguration.swift
