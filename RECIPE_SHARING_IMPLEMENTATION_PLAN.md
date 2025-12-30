# Recipe Sharing System - Implementation Plan
*Generated: 2025-12-19*
*Last Updated: 2025-12-19*

---

## 📊 PROGRESS TRACKER

**Current Status:** ✅ Phase 1 Complete | ✅ Phase 2 Complete
**Current Phase:** Ready for Phase 3 - Change Tracking & Attribution
**Completed:** 2/7 phases (29% complete)
**Last Session:** 2025-12-19 (Phase 1-2 complete, 1800+ lines, builds successfully)

### Quick Stats
- ✅ Planning: Complete
- ✅ Data Models: Complete (6/6 tasks) ✅✅✅✅✅✅
- ✅ Services: Complete (2/2 tasks) ✅✅
- ✅ UI Components: Phase 2 Complete (1/6 total) ✅ (VersionSelectorView)
- ✅ Integration: Phase 2 Complete (3/6 total) ✅✅✅ (CookingMode + activeVersion + RecipeDetailView)
- ✅ Testing: Complete for Phase 1 (1/5 test suites) ✅

### Active Tasks
- ✅ TEST_VERSION_FEATURE.md created with test plan
- ⬜ Run manual tests in simulator
- ⬜ Phase 3: Build AttributionBadge component
- ⬜ Phase 3: Add inline badges to ingredient/instruction lists

### Recently Completed (Phase 1)
- ✅ Created RecipeVersion.swift model (287 lines)
- ✅ Updated Recipe.swift with versions relationship + sharingPermission (60 new lines)
- ✅ Updated SchemaV1.swift to include RecipeVersion
- ✅ Created RecipeVersionService.swift (432 lines, 15 methods)
- ✅ Created RecipeVersionTests.swift (34 test cases, all passing)
- ✅ Created RecipeMigrationService.swift (217 lines)
- ✅ Project builds successfully ✓

### Next Session Quick Start
```bash
# To resume work in a new session:
cd /Users/matthanson/Heirloom

# Reference documents:
# 1. This file: RECIPE_SHARING_IMPLEMENTATION_PLAN.md (main plan)
# 2. Current architecture: ARCHITECTURE_QUICK_REFERENCE.md
# 3. Key file paths: KEY_FILE_PATHS.md
# 4. Demo code: /Users/matthanson/Downloads/heirdemo/app/
# 5. Test assets: /Users/matthanson/Heirloom/AnalogRecipes/Cards/

# Start Phase 1: Create RecipeVersion model
# See Section 6.1 below for detailed tasks
```

### Session Log
| Date | Phase | Work Completed | Files Modified | Notes |
|------|-------|----------------|----------------|-------|
| 2025-12-19 | Planning | Initial analysis & plan creation | RECIPE_SHARING_IMPLEMENTATION_PLAN.md | Plan ready for execution |
| 2025-12-19 | Phase 1 | Data models, services, tests, migration created | RecipeVersion.swift, Recipe.swift, SchemaV1.swift, RecipeVersionService.swift, RecipeMigrationService.swift, RecipeVersionTests.swift | ✅ Phase 1 COMPLETE - 6/6 tasks, builds successfully |
| 2025-12-19 | Phase 2 | Version selector UI + cooking/detail integration | VersionSelectorView.swift, CookingModeView.swift, RecipeDetailView.swift (modified) | ✅ Phase 2 COMPLETE - 5/5 tasks, builds successfully, TEST_VERSION_FEATURE.md created |

---

## Executive Summary

This document outlines the implementation plan for Heirloom's multi-version recipe sharing system, based on the working demo at `/Users/matthanson/Downloads/heirdemo/app`. The goal is to support multiple user versions of the same recipe while preserving attribution, lineage, and enabling collaborative evolution of recipes across generations.

**Core Innovation:** When a recipe is shared and edited by different people, all versions remain accessible on the same card, with clear attribution and the ability to select whose version to follow when cooking.

---

## 1. Feature Comparison: Demo vs Current App

### 1.1 Features in Demo NOT in Current App

| Feature | Demo Implementation | Priority | Estimated Effort |
|---------|-------------------|----------|-----------------|
| **Multi-version editing** | Each user's edits create a new version; all versions visible | **HIGH** | Large (new data model) |
| **Version selector** | UI to switch between contributor versions when cooking | **HIGH** | Medium |
| **Inline field attribution** | Badges showing who changed each field ("Mom '15") | **HIGH** | Medium |
| **Change history tooltips** | Hover to see original value before edit | **MEDIUM** | Small |
| **Generation badge** | Visual indicator ("3 Generations") | **MEDIUM** | Small |
| **Collapsible instructions** | Section-level collapse with step count | **LOW** | Small |
| **Confidence scores** | OCR confidence per field (title/ingredients/instructions) | **MEDIUM** | Medium |
| **Sticker reactions** | Visual emotional markers with attribution | **LOW** | Medium |

### 1.2 Features in Current App NOT in Demo

| Feature | Current Implementation | Keep? | Notes |
|---------|----------------------|-------|-------|
| **Comment threading** | Full nested comment system with replies | **YES** | Complements versions |
| **AI sentiment analysis** | Automatic comment sentiment scoring | **YES** | Keep for comments |
| **Card back customization** | Rich customization with notes, styles | **YES** | Core differentiation |
| **Shopping list integration** | Link recipes to shopping cart | **YES** | Separate concern |
| **Dinner party feature** | Event-based recipe grouping | **YES** | Separate concern |
| **CloudKit sync** | Full iCloud synchronization | **YES** | Essential |
| **Provenance tracking** | rootProvenanceHash, generation tracking | **YES** | Foundational |

### 1.3 Feature Convergence Opportunities

| Feature | Demo Approach | Current App Approach | Proposed Integration |
|---------|--------------|---------------------|---------------------|
| **Notes on back** | Simple textarea per person | Rich CardBackEditor with pins | **Enhance:** Add version-specific notes section |
| **Attribution** | Inline badges on changed fields | Provenance metadata + generation | **Merge:** Use provenance for inline badges |
| **Lineage visualization** | Vertical timeline with 3 nodes | Existing LineageTimelineView | **Enhance:** Add version branches |
| **Sharing mechanics** | Implicit (just edit) | CloudKitShareService + permissions | **Design:** Add "Heirloom Share" vs "Regular Share" |

---

## 2. Data Model Changes

### 2.1 New Model: RecipeVersion

**Purpose:** Store different users' modifications to the same recipe.

```swift
@Model
final class RecipeVersion {
    // MARK: - Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var lastModified: Date = Date()

    // MARK: - Ownership
    /// CloudKit user record ID of version creator
    var creatorUserID: String

    /// Display name at time of creation
    var creatorDisplayName: String

    /// Year label for UI (e.g., "2015", "2025")
    var creationYear: String

    // MARK: - Relationship
    /// Parent recipe this version belongs to
    @Relationship(inverse: \Recipe.versions)
    var recipe: Recipe?

    // MARK: - Version Content
    /// Title (if changed from base)
    var title: String?

    /// Complete ingredient list for this version
    /// Stored as JSON to preserve order and allow field-level tracking
    var ingredientsData: Data?

    /// Complete instruction list for this version
    var instructionsData: Data?

    /// Servings modification
    var servings: String?

    /// Timing modifications
    var prepTime: String?
    var cookTime: String?

    // MARK: - Change Tracking
    /// Field-level change log for attribution
    /// Format: [fieldKey: [Change]]
    /// Example: ["ingredient-2": [Change(from: "butter", to: "olive oil", at: Date())]]
    var changeLogData: Data?

    // MARK: - Metadata
    /// Personal notes specific to this version
    var personalNotes: String?

    /// Stickers added by this user
    var stickerIDs: [String] = []

    /// Whether this is the canonical/base version
    var isBaseVersion: Bool = false

    /// Whether this version is actively maintained
    var isActive: Bool = true

    // MARK: - Computed
    var ingredients: [String]? {
        get {
            guard let data = ingredientsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            ingredientsData = try? JSONEncoder().encode(newValue)
        }
    }

    var instructions: [String]? {
        get {
            guard let data = instructionsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            instructionsData = try? JSONEncoder().encode(newValue)
        }
    }

    var changeLog: [String: [FieldChange]]? {
        get {
            guard let data = changeLogData else { return nil }
            return try? JSONDecoder().decode([String: [FieldChange]].self, from: data)
        }
        set {
            changeLogData = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - Supporting Types
struct FieldChange: Codable, Hashable {
    var from: String
    var to: String
    var changedAt: Date
}
```

### 2.2 Modifications to Recipe Model

**Add to Recipe.swift:**

```swift
// MARK: - Multi-Version Support (Phase 2B)

/// All versions of this recipe (base + contributor versions)
@Relationship(deleteRule: .cascade, inverse: \RecipeVersion.recipe)
var versions: [RecipeVersion]?

/// Currently selected version for cooking
var selectedVersionID: UUID?

/// Sharing permission level for this recipe
var sharingPermission: SharingPermissionLevel = .regular

enum SharingPermissionLevel: String, Codable {
    case regular = "regular"       // View-only sharing
    case heirloom = "heirloom"     // Edit + lineage tracking
}

// MARK: - Computed Properties

/// The base version (original recipe data)
var baseVersion: RecipeVersion? {
    versions?.first(where: { $0.isBaseVersion })
}

/// Active contributor versions (excluding base)
var contributorVersions: [RecipeVersion] {
    versions?.filter { !$0.isBaseVersion && $0.isActive } ?? []
}

/// Currently selected version, or base if none selected
var activeVersion: RecipeVersion? {
    if let selectedID = selectedVersionID {
        return versions?.first(where: { $0.id == selectedID })
    }
    return baseVersion
}

/// Total count of active contributors
var contributorCount: Int {
    contributorVersions.count
}

/// Whether this recipe has multiple versions
var hasMultipleVersions: Bool {
    contributorVersions.count > 0
}
```

### 2.3 Modifications to RecipeCardBack Model

**Add version-specific notes:**

```swift
// MARK: - Version-Specific Content

/// Notes organized by version creator
/// Format: [versionID: note]
var versionNotesData: Data?

var versionNotes: [UUID: String]? {
    get {
        guard let data = versionNotesData else { return nil }
        return try? JSONDecoder().decode([UUID: String].self, from: data)
    }
    set {
        versionNotesData = try? JSONEncoder().encode(newValue)
    }
}
```

### 2.4 Schema Migration

**Add to SchemaV1 (or create SchemaV2):**

```swift
static var models: [any PersistentModel.Type] {
    [
        Recipe.self,
        RecipeVersion.self,  // NEW
        Ingredient.self,
        RecipeComment.self,
        RecipeCardBack.self,
        // ... existing models
    ]
}
```

---

## 3. Sharing Permission Model

### 3.1 Two Sharing Types

| Type | Can View | Can Edit | Can Add Version | Lineage Tracking | Use Case |
|------|----------|----------|----------------|------------------|----------|
| **Regular Share** | ✓ | ✗ | ✗ | ✗ | "Here's a recipe you might like" |
| **Heirloom Share** | ✓ | ✓ | ✓ | ✓ | "Let's pass this down/collaborate" |

### 3.2 Permission Flow

```
┌─────────────────────────────────────────────────────────┐
│  Recipe Creator                                         │
├─────────────────────────────────────────────────────────┤
│  1. Scans Grandma's recipe                             │
│  2. Toggle: "🔗 Lineage Sharing" ON                    │
│  3. Shares with Mom                                     │
└────────────────┬────────────────────────────────────────┘
                 │
                 ├─[Heirloom Share]→ Mom receives
                 │
┌────────────────▼────────────────────────────────────────┐
│  Mom (Recipient)                                        │
├─────────────────────────────────────────────────────────┤
│  • Can view recipe                                      │
│  • Can create her own version                           │
│  • Changes tracked under "Mom '15"                      │
│  • Can share onward with same permissions               │
└────────────────┬────────────────────────────────────────┘
                 │
                 ├─[Heirloom Share]→ You receive
                 │
┌────────────────▼────────────────────────────────────────┐
│  You (Second-level Recipient)                           │
├─────────────────────────────────────────────────────────┤
│  • Can view all versions (Grandma, Mom, Yours)         │
│  • Can select which version to cook                     │
│  • Can create your own version ("You '25")             │
│  • Full lineage visible: Grandma → Mom → You           │
└─────────────────────────────────────────────────────────┘
```

### 3.3 Request-to-Edit Flow (Future Enhancement)

**For Regular Share recipients who want edit access:**

```
1. Recipient views recipe (received as Regular Share)
2. UI shows: "From [Person]" with "Request Edit Access" button
3. Tap → Send notification to original sharer
4. Original sharer approves → permission upgraded to Heirloom
5. Recipient can now create their own version
```

**Implementation:** Phase 3 (requires push notifications + approval UI)

---

## 4. Service Architecture

### 4.1 New Service: RecipeVersionService

**Location:** `Core/Services/RecipeVersionService.swift`

```swift
@MainActor
final class RecipeVersionService {
    static let shared = RecipeVersionService()
    private init() {}

    // MARK: - Version Creation

    /// Create a new version for the current user
    func createVersion(
        for recipe: Recipe,
        context: ModelContext
    ) throws -> RecipeVersion {
        let userID = getCurrentUserID()
        let displayName = getCurrentUserDisplayName()

        let version = RecipeVersion(
            creatorUserID: userID,
            creatorDisplayName: displayName,
            creationYear: Calendar.current.component(.year, from: Date()).description
        )

        // Initialize with current recipe state
        version.title = recipe.title
        version.ingredients = recipe.ingredients?.map { $0.originalText }
        version.instructions = recipe.instructions
        version.servings = recipe.servings
        version.prepTime = recipe.prepTime
        version.cookTime = recipe.cookTime

        recipe.versions?.append(version)

        try context.save()
        return version
    }

    // MARK: - Version Selection

    /// Set which version to use when cooking
    func selectVersion(_ version: RecipeVersion, for recipe: Recipe, context: ModelContext) throws {
        recipe.selectedVersionID = version.id
        try context.save()
    }

    /// Get the version to display/cook (selected or base)
    func getActiveVersion(for recipe: Recipe) -> RecipeVersion? {
        return recipe.activeVersion
    }

    // MARK: - Change Tracking

    /// Record a field change in the active version
    func recordChange(
        version: RecipeVersion,
        field: String,
        from oldValue: String,
        to newValue: String,
        context: ModelContext
    ) throws {
        var changeLog = version.changeLog ?? [:]

        var fieldChanges = changeLog[field] ?? []
        fieldChanges.append(FieldChange(
            from: oldValue,
            to: newValue,
            changedAt: Date()
        ))

        changeLog[field] = fieldChanges
        version.changeLog = changeLog

        try context.save()
    }

    // MARK: - User Info (CloudKit Integration)

    private func getCurrentUserID() -> String {
        // TODO: Fetch from CloudKit CKCurrentUserDefaultName
        return "user-\(UUID().uuidString)"
    }

    private func getCurrentUserDisplayName() -> String {
        // TODO: Fetch from CloudKit user record
        return "Current User"
    }

    // MARK: - Queries

    /// Get all versions for a recipe, sorted by creation date
    func getVersions(for recipe: Recipe) -> [RecipeVersion] {
        return recipe.versions?.sorted { $0.createdAt < $1.createdAt } ?? []
    }

    /// Get a specific user's version
    func getVersion(for recipe: Recipe, userID: String) -> RecipeVersion? {
        return recipe.versions?.first { $0.creatorUserID == userID }
    }
}
```

### 4.2 Modifications to CloudKitShareService

**Add Heirloom sharing method:**

```swift
/// Share recipe with lineage tracking enabled
func shareRecipeAsHeirloom(
    _ recipe: Recipe,
    message: String?,
    completion: @escaping (Result<URL, Error>) -> Void
) async {
    // Set permission level
    recipe.sharingPermission = .heirloom

    // Create base version if doesn't exist
    if recipe.baseVersion == nil {
        let baseVersion = RecipeVersion(
            creatorUserID: getCurrentUserID(),
            creatorDisplayName: "Original",
            creationYear: Calendar.current.component(.year, from: recipe.dateAdded).description,
            isBaseVersion: true
        )
        // Copy recipe content to base version
        baseVersion.title = recipe.title
        baseVersion.ingredients = recipe.ingredients?.map { $0.originalText }
        baseVersion.instructions = recipe.instructions
        recipe.versions?.append(baseVersion)
    }

    // Share using existing CloudKit logic
    await shareRecipe(recipe, message: message, completion: completion)
}
```

---

## 5. UI/UX Design

### 5.1 Version Selector (Cooking Mode)

**Location:** New component in `Features/Recipes/CookingMode/`

**Design:**
```
┌─────────────────────────────────────────┐
│  Recipe Version                         │
├─────────────────────────────────────────┤
│  ○ Grandma Kay (Original, 1987)         │
│  ○ Mom (2015) — 2 changes               │
│  ● You (2025) — 5 changes               │
│                                         │
│  [Switch to this version]               │
└─────────────────────────────────────────┘
```

**Implementation:**
```swift
struct VersionSelectorView: View {
    let recipe: Recipe
    @Binding var selectedVersionID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe Version")
                .font(.headline)

            ForEach(recipe.versions ?? [], id: \.id) { version in
                Button {
                    selectedVersionID = version.id
                } label: {
                    HStack {
                        Image(systemName: selectedVersionID == version.id ? "checkmark.circle.fill" : "circle")

                        VStack(alignment: .leading) {
                            Text(version.creatorDisplayName)
                                .font(.body)

                            if version.isBaseVersion {
                                Text("Original, \(version.creationYear)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(version.creationYear) — \(version.changeLog?.count ?? 0) changes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding()
    }
}
```

### 5.2 Inline Attribution Badges

**Location:** Modify `RecipeDetailView.swift`

**Design:**
```
Ingredients:
• 2 cups butter [Mom '15]  ← badge appears on modified fields
• 3 eggs
• 1 cup sugar [You '25]
```

**Implementation:**
```swift
struct AttributionBadge: View {
    let change: FieldChange?
    let version: RecipeVersion?

    var body: some View {
        if let change = change, let version = version {
            Text("\(version.creatorDisplayName) '\(version.creationYear.suffix(2))")
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    var badgeColor: Color {
        // Different colors per contributor
        // Hash userID to consistent color
    }
}
```

### 5.3 Lineage Toggle on Card

**Location:** Modify `RecipeDetailView.swift` or create `RecipeShareConfigView.swift`

**Design (on card front):**
```
┌─────────────────────────────────┐
│  Grandma's Lasagna             │
│  ─────────────────              │
│                                 │
│  [Recipe content...]            │
│                                 │
│  ┌───────────────────────────┐ │
│  │ 🔗 Lineage Sharing  [ON]  │ │
│  └───────────────────────────┘ │
└─────────────────────────────────┘
```

**Behavior:**
- Default ON for scanned recipes
- Default OFF for web import / manual entry
- First-time: subtle pulse to draw attention
- Affects sharing behavior when user shares

### 5.4 Card Back Version Notes

**Location:** Modify `CardBackEditorView.swift`

**Design:**
```
┌─────────────────────────────────────┐
│  FAMILY NOTES                       │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Grandma Kay (1987)          │   │
│  │ "Always use real butter!"   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Mom (2015)                  │   │
│  │ "I double the honey — our   │   │
│  │  family likes it sweeter"   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ You (2025)                  │   │
│  │ [Add your note...]          │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## 6. Implementation Phases

### Phase 1: Foundation (Week 1-2)
**Goal:** Data models and basic version creation

- [ ] Create RecipeVersion model
- [ ] Add versions relationship to Recipe
- [ ] Add sharingPermission field to Recipe
- [ ] Create RecipeVersionService
- [ ] Write unit tests for version CRUD
- [ ] Schema migration (if needed)

### Phase 2: Version Selection (Week 2-3)
**Goal:** Users can select which version to cook

- [ ] Build VersionSelectorView component
- [ ] Add version selection to CookingModeView
- [ ] Update recipe rendering to use activeVersion
- [ ] Add version indicator to RecipeDetailView
- [ ] Test version switching

### Phase 3: Change Tracking (Week 3-4)
**Goal:** Track field-level changes with attribution

- [ ] Implement change logging in RecipeVersionService
- [ ] Build AttributionBadge component
- [ ] Add inline badges to ingredient/instruction lists
- [ ] Add hover/long-press for change history
- [ ] Test change attribution across versions

### Phase 4: Sharing Permissions (Week 4-5)
**Goal:** Heirloom vs Regular sharing

- [ ] Add lineage toggle to recipe cards
- [ ] Modify CloudKitShareService for Heirloom shares
- [ ] Handle share acceptance with permission check
- [ ] Create version for new Heirloom recipients
- [ ] Test end-to-end sharing flow

### Phase 5: Card Back Integration (Week 5-6)
**Goal:** Version-specific notes on card back

- [ ] Add versionNotes to RecipeCardBack
- [ ] Update CardBackEditorView for version notes
- [ ] Render version-specific notes on card back
- [ ] Add sticker attribution by version
- [ ] Test card back with multiple contributors

### Phase 6: UI Polish (Week 6-7)
**Goal:** Animations, empty states, error handling

- [ ] Generation badge ("3 Generations")
- [ ] Timeline view showing version branches
- [ ] Empty states (no versions yet)
- [ ] Error handling (version conflicts)
- [ ] Accessibility labels
- [ ] Dark mode support

### Phase 7: Testing & Refinement (Week 7-8)
**Goal:** Beta testing with real users

- [ ] Integration tests for sharing flow
- [ ] UI tests for version selection
- [ ] Manual testing with AnalogRecipes samples
- [ ] Beta tester feedback collection
- [ ] Bug fixes and UX refinements

---

## 7. Technical Considerations

### 7.1 CloudKit Sync

**Challenge:** Syncing versions across devices without conflicts

**Approach:**
- Each RecipeVersion has unique UUID
- CloudKit handles record sync automatically
- Last-write-wins for version selection
- Conflict resolution: merge versions, don't overwrite

### 7.2 Performance

**Concern:** Loading many versions could slow down recipe list

**Optimization:**
- Lazy load versions (fetch only when viewing detail)
- Cache activeVersion computed property
- Index on recipe.selectedVersionID
- Paginate version history if > 10 versions

### 7.3 Storage

**Data size estimation:**
- Base recipe: ~5 KB
- Each version: ~3 KB (stores diff data)
- 10 versions: ~35 KB total per recipe
- Acceptable for CloudKit (max 5 MB per record)

### 7.4 Migration Strategy

**For existing recipes:**
1. Create base version with isBaseVersion = true
2. Copy recipe content to base version
3. Set recipe.selectedVersionID to base version ID
4. Preserve existing sharing metadata in provenance

**Migration code:**
```swift
func migrateRecipesToVersions(context: ModelContext) throws {
    let descriptor = FetchDescriptor<Recipe>(
        predicate: #Predicate { $0.baseVersion == nil }
    )
    let recipes = try context.fetch(descriptor)

    for recipe in recipes {
        let baseVersion = RecipeVersion(
            creatorUserID: "legacy",
            creatorDisplayName: "Original",
            creationYear: Calendar.current.component(.year, from: recipe.dateAdded).description,
            isBaseVersion: true
        )

        baseVersion.title = recipe.title
        baseVersion.ingredients = recipe.ingredients?.map { $0.originalText }
        baseVersion.instructions = recipe.instructions

        recipe.versions = [baseVersion]
        recipe.selectedVersionID = baseVersion.id
    }

    try context.save()
}
```

---

## 8. Open Questions

### 8.1 UX Questions

**Q1:** Should users see all versions by default, or only their own + original?
- **Option A:** Show all (transparency, full history)
- **Option B:** Show connected only (reduce noise)
- **Recommendation:** Option B, with "See all versions" toggle

**Q2:** What happens if two people edit the same field differently?
- **Option A:** Show both changes, let user pick
- **Option B:** Merge into single field with multi-attribution
- **Recommendation:** Option A (cleaner, less ambiguous)

**Q3:** Can users delete their version?
- **Yes**, but soft-delete (isActive = false)
- Keep for lineage history, just hide from UI

### 8.2 Technical Questions

**Q4:** How to handle offline edits that conflict?
- Use CloudKit's built-in conflict resolution
- Last-write-wins for version metadata
- Merge strategy: create new version if conflict detected

**Q5:** Should web-imported recipes support versions?
- Yes, but default sharingPermission = .regular
- User can toggle to .heirloom if desired

---

## 9. Success Metrics

### 9.1 Adoption Metrics
- % of recipes with sharingPermission = .heirloom
- % of shared recipes that receive edits/versions
- Average # of versions per shared recipe
- % of users who create at least one version

### 9.2 Engagement Metrics
- Version switch rate (how often users change versions)
- Version note creation rate
- Time spent on card back (version notes engagement)
- Sharing rate (heirloom vs regular)

### 9.3 Quality Metrics
- Version conflict rate (technical issues)
- User-reported confusion (UX issues)
- Support ticket volume (implementation issues)
- Crash rate around version operations

---

## 10. Future Enhancements (Phase 3+)

### 10.1 Request-to-Edit Flow
- Recipients of Regular Share can request Heirloom access
- Notification system for approval
- Permission upgrade flow

### 10.2 Version Branching
- Fork a specific version as starting point
- Visual tree showing version relationships
- Merge versions (combine two users' changes)

### 10.3 Version Comparison
- Side-by-side diff view
- Highlight specific field changes
- Cherry-pick changes from other versions

### 10.4 Collaborative Features
- Real-time co-editing (Operational Transform)
- Version comments (comment on specific version)
- Version ratings (community votes best version)

---

## 11. Test Plan

### 11.1 Unit Tests
```
RecipeVersionServiceTests
├── testCreateVersion
├── testSelectVersion
├── testRecordChange
├── testGetActiveVersion
└── testVersionQueries

RecipeVersionModelTests
├── testVersionCreation
├── testChangeLogEncoding
├── testVersionRelationships
└── testComputedProperties
```

### 11.2 Integration Tests
```
VersionSharingIntegrationTests
├── testHeirloomShareCreatesVersion
├── testRegularShareDoesNotAllowVersions
├── testVersionSyncAcrossDevices
└── testVersionConflictResolution
```

### 11.3 UI Tests
```
VersionSelectorUITests
├── testSwitchVersion
├── testVersionBadgesAppear
├── testLineageToggle
└── testCardBackVersionNotes
```

### 11.4 Manual Test Scenarios

**Scenario 1: Three-Generation Recipe**
1. Device A: Scan recipe card (Grandma's recipe)
2. Device A: Toggle lineage ON, share with Device B
3. Device B: Accept share, create version, edit 2 ingredients
4. Device B: Share with Device C
5. Device C: Accept share, create version, edit title
6. **Verify:** All 3 versions visible on all devices
7. **Verify:** Lineage shows Grandma → Mom → You

**Scenario 2: Version Selection**
1. Open recipe with 3 versions
2. Tap version selector in cooking mode
3. Select Mom's version
4. **Verify:** Ingredients show Mom's changes
5. Switch to Grandma's version
6. **Verify:** Ingredients revert to original

**Scenario 3: Card Back Notes**
1. Open recipe with 2 versions
2. Flip to card back
3. **Verify:** Two note sections (Grandma, Mom)
4. Add your own note
5. **Verify:** Three note sections now visible

---

## 12. Resources & References

### 12.1 Code References
- **Demo:** `/Users/matthanson/Downloads/heirdemo/app/heirloom-demo-v4.jsx`
- **Feature Breakdown:** `/Users/matthanson/Downloads/heirdemo/app/heirloom-feature-breakdown.md`
- **Test Assets:** `/Users/matthanson/Heirloom/AnalogRecipes/Cards/` (12 sample recipe cards)
- **Current Architecture:** `/Users/matthanson/Heirloom/ARCHITECTURE_QUICK_REFERENCE.md`

### 12.2 Existing Models to Reference
- `Recipe.swift` - Core recipe model (413 lines)
- `ProvenanceMetadata.swift` - Lineage tracking (270 lines)
- `RecipeComment.swift` - Comment structure (219 lines)
- `RecipeCardBack.swift` - Card back customization (221 lines)

### 12.3 Existing Services to Extend
- `CloudKitShareService.swift` - Sharing logic (385 lines)
- `CommentService.swift` - CRUD patterns (328 lines)
- `ImageStorageService.swift` - File handling (100+ lines)

---

## 13. Implementation Checklist

Copy this checklist to track progress:

### Data Model
- [ ] Create RecipeVersion.swift
- [ ] Add versions relationship to Recipe
- [ ] Add sharingPermission to Recipe
- [ ] Add versionNotes to RecipeCardBack
- [ ] Update SchemaV1 or create SchemaV2
- [ ] Write migration for existing recipes

### Services
- [ ] Create RecipeVersionService
- [ ] Add heirloom sharing to CloudKitShareService
- [ ] Add version creation on share acceptance
- [ ] Implement change tracking
- [ ] Add CloudKit user info fetching

### UI Components
- [ ] VersionSelectorView
- [ ] AttributionBadge
- [ ] LineageToggle
- [ ] Version notes in CardBackEditorView
- [ ] Generation badge component
- [ ] Version indicator in RecipeDetailView

### Integration
- [ ] Add version selection to CookingModeView
- [ ] Update recipe rendering to use activeVersion
- [ ] Add lineage toggle to share flow
- [ ] Update CardBackEditorView for version notes
- [ ] Add version branches to LineageTimelineView

### Testing
- [ ] Unit tests for RecipeVersionService
- [ ] Unit tests for RecipeVersion model
- [ ] Integration tests for sharing flow
- [ ] UI tests for version selection
- [ ] Manual testing with AnalogRecipes samples

### Documentation
- [ ] Update user documentation
- [ ] Create developer guide for versions
- [ ] Update ARCHITECTURE_ANALYSIS.md
- [ ] Add inline code comments
- [ ] Create demo video

---

## Appendix A: Demo Feature Analysis

**Key Insights from Demo Code:**

1. **Change Attribution Pattern (lines 122-214):**
   - Tracks `{ field, from, to, by, year }` for each edit
   - Same editor updating = updates their last change (not stacking)
   - Different editor = new change entry
   - **Lesson:** Keep change log per field, not global

2. **Version Handoff Pattern (lines 435-445):**
   - Generation count tracks recipe passes
   - Each "fork" step represents new contributor
   - Timeline shows visual progression
   - **Lesson:** Use provenance.generation + RecipeVersion model

3. **Inline Edit Pattern (lines 4-116):**
   - EditableText component extracted to prevent remounts
   - Editing field tracked in state
   - Change attribution shown immediately
   - **Lesson:** Need similar inline edit for iOS (UITextField in SwiftUI)

4. **Card Flip Pattern (lines 1006-1577):**
   - CSS 3D transform for flip animation
   - Front: recipe, Back: notes + changes
   - **Lesson:** Use .rotation3DEffect in SwiftUI

---

## Appendix B: Comparison Matrix

| Dimension | Demo | Current App | Gap |
|-----------|------|-------------|-----|
| **Data Model** | Versions implicit in changes object | ProvenanceMetadata tracks lineage | Need explicit RecipeVersion model |
| **Editing** | Inline click-to-edit | Separate edit screen | Add inline editing option |
| **Attribution** | Inline badges per field | Comments with sentiment | Merge: badges + comments |
| **Versioning** | User-level, all visible | Generation counter only | Add multi-version support |
| **Sharing** | Implicit (just edit) | CloudKit with permissions | Add Heirloom vs Regular |
| **Card Back** | Simple notes per person | Rich customization | Add version-specific notes |
| **UI Pattern** | Web (React) | Native iOS (SwiftUI) | Adapt patterns to iOS HIG |

---

**Document Status:** Ready for Review
**Next Steps:**
1. Review with team
2. Prioritize phases
3. Begin Phase 1 implementation
4. Set up test environment with AnalogRecipes samples
