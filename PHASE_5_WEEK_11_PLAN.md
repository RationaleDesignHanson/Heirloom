# Phase 5 Week 11 - Core Services DI Conversion Plan

**Goal:** Convert 7 Core Services from singleton to dependency injection
**Timeline:** This session
**Prerequisites:** Build succeeds after protocol visibility fix

---

## Services to Convert (Priority 2)

### 1. RecipeImportService ⭐ HIGH PRIORITY
**File:** `Heirloom/Core/Services/RecipeImportService.swift`
**Current:** Singleton pattern
**Dependencies (estimated):**
- AIRecipeExtractor
- EnhancedOCRService
- NetworkMonitor
- LoggingService

**Usage:** Import flow, URL handling, photo processing
**Impact:** Medium - used in import views

---

### 2. ImageStorageService ⭐ HIGH PRIORITY
**File:** `Heirloom/Core/Services/ImageStorageService.swift`
**Current:** Actor with singleton
**Dependencies (estimated):**
- FirebaseImageService
- LoggingService

**Usage:** Local image caching, Firebase sync
**Impact:** High - used throughout app for recipe images

---

### 3. EnhancedOCRService
**File:** `Heirloom/Core/Services/OCR/EnhancedOCRService.swift`
**Current:** Singleton pattern
**Dependencies (estimated):**
- AIRecipeExtractor
- LoggingService

**Usage:** Photo OCR for recipe import
**Impact:** Medium - used in photo import flow

---

### 4. NetworkMonitor
**File:** `Heirloom/Core/Services/NetworkMonitor.swift`
**Current:** Singleton pattern
**Dependencies:**
- None (uses NWPathMonitor)

**Usage:** Network connectivity detection
**Impact:** Low - utility service
**Note:** Already has protocol in ServiceProtocols.swift

---

### 5. DeepLinkHandler
**File:** `Heirloom/Core/Services/DeepLink/DeepLinkHandler.swift`
**Current:** Singleton with DI support (partially done)
**Dependencies:**
- ✅ FirebaseShareService (already injected)
- ✅ LoggingService (already injected)

**Usage:** URL routing, share acceptance
**Impact:** High - critical for sharing feature
**Status:** Already has DI init, just needs .shared removal

---

### 6. AnalyticsService
**File:** `Heirloom/Core/Services/AnalyticsService.swift`
**Current:** Singleton pattern
**Dependencies (estimated):**
- LoggingService

**Usage:** Event tracking
**Impact:** Low - analytics only
**Note:** Already has protocol in ServiceProtocols.swift

---

### 7. HeirloomLogger
**File:** `Heirloom/Core/Services/Logging/HeirloomLogger.swift`
**Current:** Singleton (acceptable)
**Dependencies:** None

**Usage:** Logging throughout app
**Impact:** Critical - used everywhere
**Status:** Already registered in ServiceContainer
**Action:** Can keep as singleton (cross-cutting concern)

---

## Conversion Order

**Recommended order (dependencies first):**

1. **NetworkMonitor** (no dependencies, quick win)
2. **AnalyticsService** (only LoggingService dependency)
3. **EnhancedOCRService** (depends on AI services)
4. **RecipeImportService** (depends on OCR, AI, NetworkMonitor)
5. **ImageStorageService** (depends on FirebaseImageService)
6. **DeepLinkHandler** (finish what we started)
7. **HeirloomLogger** (leave as singleton)

---

## Conversion Checklist (Per Service)

### For Each Service:

1. ☐ **Read current implementation**
   - Identify all `.shared` calls
   - List dependencies
   - Check if ObservableObject

2. ☐ **Remove singleton pattern**
   - Remove `static let shared = ...`
   - Remove `private init()`
   - Add `init(dependencies...)`

3. ☐ **Add dependencies**
   - Add private properties for dependencies
   - Initialize in init()
   - Replace `.shared` calls with injected dependencies

4. ☐ **Update logging calls**
   - Replace `Log.*` with `logger.*`
   - Add `metadata: nil` where needed

5. ☐ **Update ServiceRegistration.swift**
   - Add registration with dependencies
   - Set lifecycle (usually .singleton)

6. ☐ **Add protocol if missing**
   - Check ServiceProtocols.swift
   - Add protocol if not exists
   - Register both concrete and protocol types

7. ☐ **Update usages**
   - Find all `.shared` usages
   - Update to inject or use DI container
   - Add backward-compatible .shared if needed

8. ☐ **Test build**
   - Verify no compilation errors
   - Check service resolves correctly

---

## Expected Outcomes

**After completing all 7 services:**

- **Progress:** 16/52 services (31% complete)
- **Singletons removed:** 16 total
- **Services with DI:** 16 total
- **Build:** Should succeed with all services DI-ready

**Time Estimate:**
- NetworkMonitor: 15 min
- AnalyticsService: 15 min
- EnhancedOCRService: 20 min
- RecipeImportService: 30 min
- ImageStorageService: 25 min (Actor handling)
- DeepLinkHandler: 10 min (cleanup)
- Total: ~2 hours

---

## Notes

### Actor Services (ImageStorageService)

Actors can still use DI! Pattern:
```swift
actor ImageStorageService {
    private let firebaseImage: FirebaseImageServiceProtocol
    private let logger: LoggingService

    init(firebaseImage: FirebaseImageServiceProtocol, logger: LoggingService) {
        self.firebaseImage = firebaseImage
        self.logger = logger
    }

    // Temporary backward compatibility
    static let shared: ImageStorageService = {
        ServiceContainer.shared.resolve(ImageStorageService.self)
    }()
}
```

### Cross-Cutting Concerns

Services like HeirloomLogger that are used everywhere and need to be available immediately (even before DI initialization) can remain singletons. This is acceptable for:
- Logging
- Configuration (read-only)
- Device info utilities

---

## Success Criteria

Week 11 complete when:
- ☐ All 7 Core Services converted
- ☐ All usages updated
- ☐ Build succeeds
- ☐ Services resolve from DI container
- ☐ No new .shared singletons added

---

**Ready to start as soon as build succeeds!**
