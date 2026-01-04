# Phase 5: Architecture Modernization - Dependency Injection Migration

**Start Date**: 2026-01-03
**Status**: In Progress
**Goal**: Convert 52 singletons to dependency injection pattern

---

## Overview

Replace singleton pattern (`.shared`) with proper dependency injection to enable:
- Testability with mock dependencies
- Lifecycle management
- Thread safety improvements
- Reduced coupling
- Better architecture

---

## Singleton Audit Results

### Total Singletons Found: 52

#### Firebase Services (9)
- FirebaseSyncService
- FirebaseAuthService
- FirebaseRecipeSync
- FirebaseCollectionSync
- FirebaseImageService
- FirebaseShareService
- FirebaseLineageService
- FirebaseNotificationService
- FirebaseConfiguration

#### AI Services (11)
- AIRecipeExtractor
- AIIngredientParser
- AIRecipeDetector
- AIIngredientSpellChecker
- AnthropicAIService
- AIConfiguration
- CommentAnalysisService
- DinnerPartySummaryService
- RecipeTimelineCalculator
- ShoppingListSummaryService
- AIUsageTracker

#### Recipe Services (8)
- RecipeImportService
- RecipeExportService
- RecipeVersionService
- RecipeMigrationService
- RecipeLineageService
- RecipeStructureParser
- CloudRecipeImportService
- CategoryDetectionService

#### Storage Services (3)
- ImageStorageService
- ImageCache
- Keychain

#### Analytics Services (3)
- AnalyticsService
- MixpanelService
- ConsoleAnalyticsService

#### Core Services (9)
- DeepLinkHandler
- NetworkMonitor
- EnhancedOCRService
- RemindersService
- CommentService
- UndoService
- CRDTMergeEngine
- ScalingEngine
- ImagePreprocessor

#### UI/Utilities (9)
- ToastManager
- HeirloomLogger
- DeviceLogger
- BackendConfig
- UnitsConfiguration
- ImportJobManager
- GestureGuide
- HelpContent
- PrivacyConsentService
- MilestoneManager
- ShortURLService

---

## Implementation Strategy

### Week 9: DI Infrastructure Setup

**Goal**: Create dependency injection framework and container

#### Tasks
1. **Create DI Container**
   - ServiceContainer class with registration and resolution
   - Support for lazy initialization
   - Thread-safe singleton creation
   - Lifecycle management (shared, transient, scoped)

2. **Create Service Protocols** (if not existing)
   - Many already exist from Phase 2
   - Fill in gaps for remaining services

3. **SwiftUI Environment Integration**
   - Create environment keys for all services
   - Create convenient view extensions
   - Update app initialization

4. **Create Mock Infrastructure**
   - Expand existing mocks from Phase 1
   - Create mocks for remaining services

### Week 10: Service Migration

**Goal**: Convert all singletons to DI pattern

#### Priority 1: Firebase Services (Days 1-2)
Already have protocols from Phase 2. Just need to:
- Remove `.shared` static properties
- Add initializer injection where needed
- Register in DI container
- Update callsites

**Files:**
- FirebaseSyncService.swift
- FirebaseAuthService.swift
- FirebaseRecipeSync.swift
- FirebaseCollectionSync.swift
- FirebaseImageService.swift
- FirebaseShareService.swift
- FirebaseLineageService.swift
- FirebaseNotificationService.swift
- FirebaseConfiguration.swift

#### Priority 2: Core Services (Days 3-4)
Services used across multiple layers
- RecipeImportService
- ImageStorageService
- EnhancedOCRService
- NetworkMonitor
- DeepLinkHandler
- AnalyticsService
- HeirloomLogger

#### Priority 3: AI Services (Days 5-6)
- AIRecipeExtractor
- AIIngredientParser
- AIRecipeDetector
- AnthropicAIService
- AIConfiguration
- CommentAnalysisService

#### Priority 4: Remaining Services (Days 7-8)
- All recipe services
- Storage services
- Analytics services
- UI utilities

### Week 10 (Continued): View Layer Updates

**Goal**: Update all views to use injected dependencies

#### Approach
1. Add `@Environment` properties for service dependencies
2. Replace `.shared` calls with environment services
3. Update previews to provide mock services
4. Ensure compilation at each step

### Week 10 (Final): Test Updates

**Goal**: Enable mock testing with DI

#### Tasks
1. Update all test files to use DI container
2. Register mocks in test setup
3. Remove hardcoded `.shared` from tests
4. Verify all 235 tests still pass

---

## Technical Design

### ServiceContainer Design

```swift
class ServiceContainer {
    static let shared = ServiceContainer()

    enum Lifecycle {
        case singleton  // One instance for app lifetime
        case transient  // New instance each time
        case scoped     // One instance per scope (e.g., per view)
    }

    private var factories: [String: (ServiceContainer) -> Any] = [:]
    private var singletons: [String: Any] = [:]

    func register<T>(_ type: T.Type, lifecycle: Lifecycle, factory: @escaping (ServiceContainer) -> T)
    func resolve<T>(_ type: T.Type) -> T
}
```

### SwiftUI Integration

```swift
// Environment keys
private struct FirebaseSyncServiceKey: EnvironmentKey {
    static let defaultValue: FirebaseSyncServiceProtocol = ServiceContainer.shared.resolve(FirebaseSyncServiceProtocol.self)
}

// Extensions
extension EnvironmentValues {
    var firebaseSync: FirebaseSyncServiceProtocol {
        get { self[FirebaseSyncServiceKey.self] }
        set { self[FirebaseSyncServiceKey.self] = newValue }
    }
}

// Usage in views
struct RecipeListView: View {
    @Environment(\.firebaseSync) private var firebaseSync

    var body: some View {
        // Use firebaseSync instead of FirebaseSyncService.shared
    }
}
```

### Migration Pattern

**Before:**
```swift
class RecipeImportService {
    static let shared = RecipeImportService()
    private init() {}
}

// Usage
RecipeImportService.shared.importRecipe(url)
```

**After:**
```swift
class RecipeImportService {
    init(
        networkMonitor: NetworkMonitorProtocol,
        logger: LoggingService
    ) {
        self.networkMonitor = networkMonitor
        self.logger = logger
    }
}

// Registration
container.register(RecipeImportServiceProtocol.self, lifecycle: .singleton) { container in
    RecipeImportService(
        networkMonitor: container.resolve(NetworkMonitorProtocol.self),
        logger: container.resolve(LoggingService.self)
    )
}

// Usage in SwiftUI
@Environment(\.recipeImport) private var recipeImport
recipeImport.importRecipe(url)
```

---

## Success Criteria

- [ ] All 52 singletons converted to DI
- [ ] Zero usages of `.shared` in production code (except ServiceContainer)
- [ ] All 235 tests pass with mock dependencies
- [ ] Build succeeds with zero errors
- [ ] SwiftUI previews work with mock data
- [ ] App runs successfully with DI

---

## Benefits

### Testability
- Tests can inject mocks instead of using real services
- Isolated unit testing without side effects
- Faster test execution

### Maintainability
- Clear dependency graphs
- Easier to refactor
- Explicit dependencies in initializers

### Flexibility
- Easy to swap implementations
- Support for feature flags
- A/B testing capabilities

### Thread Safety
- No more race conditions on singleton initialization
- Proper actor isolation support
- Better concurrency control

---

## Risks & Mitigations

### Risk: Breaking existing tests
**Mitigation**: Update tests incrementally, one service at a time

### Risk: SwiftUI preview failures
**Mitigation**: Provide mock services in all previews

### Risk: Performance regression
**Mitigation**: Use singleton lifecycle for services that need it

### Risk: Circular dependencies
**Mitigation**: Design clear dependency hierarchy, use protocols

---

## Progress Tracking

### Week 9: Infrastructure
- [ ] Create ServiceContainer
- [ ] Create service protocols (fill gaps)
- [ ] Create SwiftUI environment integration
- [ ] Expand mock infrastructure

### Week 10: Migration
- [ ] Firebase services (9 services)
- [ ] Core services (7 services)
- [ ] AI services (11 services)
- [ ] Remaining services (25 services)
- [ ] Update all views
- [ ] Update all tests

---

## Notes

- Some services already have protocols from Phase 2
- Many mocks already exist from Phase 1
- Build must succeed after each batch of conversions
- All tests must continue passing throughout migration
