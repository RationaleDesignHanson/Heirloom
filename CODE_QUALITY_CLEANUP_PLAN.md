# Phase 4: Code Quality & Cleanup Plan

**Goal**: Remove all 634 print statements and replace with proper structured logging

**Duration**: 2 weeks (Week 7-8)
**Status**: In Progress
**Priority**: CRITICAL

---

## Current State Analysis

### Print Statement Audit
- **Total print statements**: 634 across codebase
- **Issue**: Print statements are:
  - Not structured or queryable
  - No log levels (debug, info, warning, error)
  - Can't be filtered or disabled
  - Clutter production builds
  - Performance impact (string interpolation always executed)

### Categories to Address
1. **Debug Logging** - Development debugging traces
2. **Error Logging** - Error conditions and exceptions
3. **Info Logging** - Significant events (user actions, sync events)
4. **Network Logging** - API calls, Firebase operations
5. **Performance Logging** - Timing and performance metrics
6. **Sync Logging** - CRDT operations, conflict resolution

---

## Solution: Structured Logging Service

### Design Principles
1. **Structured**: Category-based, filterable logs
2. **Levels**: Debug, Info, Warning, Error, Critical
3. **Performance**: Conditional compilation for debug logs
4. **Production-ready**: Configurable for release builds
5. **Crash reporting**: Integration point for Sentry/Crashlytics
6. **Privacy**: Sensitive data redaction

### Logging Service Architecture

```swift
enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
}

enum LogCategory: String {
    case firebase = "🔥 Firebase"
    case sync = "🔄 Sync"
    case crdt = "📝 CRDT"
    case network = "🌐 Network"
    case ui = "🎨 UI"
    case auth = "🔐 Auth"
    case storage = "💾 Storage"
    case ocr = "📸 OCR"
    case performance = "⚡️ Performance"
    case general = "ℹ️  General"
}

protocol LoggingService {
    func debug(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    func info(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    func warning(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    func error(_ message: String, category: LogCategory, error: Error?, file: String, function: String, line: Int)
}
```

---

## Implementation Strategy

### Week 7: Logging Infrastructure (Days 1-3)

#### Day 1: Create Logging Service
- [ ] Create `LoggingService.swift` protocol
- [ ] Create `HeirloomLogger.swift` implementation
- [ ] Add log level filtering
- [ ] Add category filtering
- [ ] Add file/line/function metadata
- [ ] Add timestamp formatting
- [ ] ~150 lines of code

#### Day 2: Advanced Features
- [ ] Add sensitive data redaction (emails, tokens)
- [ ] Add structured metadata support (key-value pairs)
- [ ] Add crash reporting integration points
- [ ] Add performance logging helpers (timing blocks)
- [ ] Create global logger instance
- [ ] ~200 lines of code

#### Day 3: Testing & Documentation
- [ ] Create `LoggingServiceTests.swift`
- [ ] Test all log levels
- [ ] Test filtering
- [ ] Test metadata
- [ ] Document usage patterns
- [ ] ~150 lines test code

### Week 7-8: Print Statement Replacement (Days 4-10)

#### Systematic Replacement Approach
1. **Audit by file** - Group print statements by file
2. **Categorize** - Assign log level and category
3. **Replace** - Convert to structured logging
4. **Remove dead code** - Delete unnecessary debug prints
5. **Test** - Verify functionality unchanged

#### Priority Order
1. **Firebase Services** (~150 prints)
   - FirebaseSyncService decomposed files
   - FirebaseAuthService
   - FirebaseShareService

2. **CRDT & Sync** (~100 prints)
   - OperationLog
   - ConflictResolver
   - SyncCoordinator

3. **Services** (~100 prints)
   - OCRService
   - ImageStorageService
   - RecipeImportService

4. **Views & ViewModels** (~200 prints)
   - RecipeDetailView
   - RecipeEditorView
   - Other UI components

5. **Models & Utilities** (~84 prints)
   - Recipe model
   - Extensions
   - Helpers

#### Replacement Patterns

**Before:**
```swift
print("Syncing recipe: \(recipe.title)")
print("ERROR: Failed to sync - \(error)")
```

**After:**
```swift
Log.info("Syncing recipe", category: .sync, metadata: ["title": recipe.title])
Log.error("Failed to sync recipe", category: .sync, error: error)
```

---

## Week 8: SwiftLint & Quality Gates

### SwiftLint Configuration
- [ ] Add `.swiftlint.yml` configuration
- [ ] Enable rules:
  - `no_print` - Ban print statements
  - `line_length` - Max 120 characters
  - `function_body_length` - Max 40 lines
  - `file_length` - Max 400 lines
  - `cyclomatic_complexity` - Max 10
  - `force_unwrapping` - Warning on `!`
- [ ] Run SwiftLint on entire codebase
- [ ] Fix critical violations
- [ ] Document remaining warnings

### Quality Checks
- [ ] Verify zero print statements remain
- [ ] Build succeeds with no warnings
- [ ] All tests pass
- [ ] Logging service fully integrated
- [ ] Performance unchanged

---

## Success Criteria

### Must Have
- ✅ Zero print statements in codebase
- ✅ Structured logging service implemented
- ✅ All critical paths use proper logging
- ✅ SwiftLint configured and passing
- ✅ All builds succeed
- ✅ All tests pass

### Nice to Have
- Crash reporting integration (Sentry/Crashlytics)
- Log viewing UI in debug builds
- Network request logging middleware
- Performance profiling helpers

---

## Migration Examples

### Firebase Sync Logging
```swift
// Before
print("📤 Syncing recipe to Firebase: \(recipe.title)")
print("✅ Recipe synced successfully")
print("❌ ERROR: Sync failed - \(error.localizedDescription)")

// After
Log.info("Syncing recipe to Firebase",
         category: .firebase,
         metadata: ["recipeID": recipe.id.uuidString, "title": recipe.title])

Log.info("Recipe synced successfully",
         category: .firebase,
         metadata: ["recipeID": recipe.id.uuidString])

Log.error("Recipe sync failed",
          category: .firebase,
          error: error,
          metadata: ["recipeID": recipe.id.uuidString])
```

### CRDT Operation Logging
```swift
// Before
print("🔄 Applying operation: \(operation.type)")
print("⚠️  Conflict detected between operations")

// After
Log.debug("Applying CRDT operation",
          category: .crdt,
          metadata: ["operationType": operation.type.rawValue,
                    "timestamp": operation.timestamp])

Log.warning("CRDT conflict detected",
            category: .crdt,
            metadata: ["localOp": localOp.id, "remoteOp": remoteOp.id])
```

### UI Event Logging
```swift
// Before
print("User tapped favorite on recipe: \(recipe.title)")

// After
Log.info("User toggled favorite",
         category: .ui,
         metadata: ["recipeID": recipe.id.uuidString,
                   "isFavorite": recipe.isFavorite])
```

---

## Files to Create

1. `Heirloom/Core/Services/Logging/LoggingService.swift` - Protocol
2. `Heirloom/Core/Services/Logging/HeirloomLogger.swift` - Implementation
3. `Heirloom/Core/Services/Logging/LogRedactor.swift` - Sensitive data redaction
4. `HeirloomTests/Services/LoggingServiceTests.swift` - Tests
5. `.swiftlint.yml` - Linting configuration

---

## Risk Mitigation

### Risks
1. **Breaking changes** - Removing prints might break debugging workflows
2. **Performance** - Logging overhead in hot paths
3. **Scope creep** - 634 prints is a lot to replace

### Mitigations
1. **Incremental approach** - Replace file by file, test continuously
2. **Conditional compilation** - Debug logs compile out in release
3. **Time boxing** - Focus on high-value replacements first
4. **Parallel work** - Can replace prints in multiple files simultaneously

---

## Next Steps

1. Create logging service infrastructure (Days 1-3)
2. Audit print statements by file and category (Day 4)
3. Begin systematic replacement (Days 5-10)
4. Add SwiftLint configuration (Day 11)
5. Final quality checks and commit (Day 12)

**Let's start with Day 1: Create the logging service foundation.**
