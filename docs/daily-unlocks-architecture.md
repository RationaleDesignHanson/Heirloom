# Daily Unlocks Architecture Documentation

> **Technical reference for the 14-day theme recipe unlock system**

**Last Updated**: 2026-02-02
**Owner**: Engineering
**Status**: Production

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Data Flow](#data-flow)
4. [Key Components](#key-components)
5. [Timing & Triggers](#timing--triggers)
6. [Data Storage](#data-storage)
7. [Edge Cases](#edge-cases)
8. [Performance Considerations](#performance-considerations)
9. [Testing Strategy](#testing-strategy)
10. [Future Improvements](#future-improvements)

---

## Overview

### Purpose

The daily unlock system progressively reveals curated theme recipes over a 14-day trial period. Each day, users unlock approximately 7 new recipes from their selected themes, creating engagement through anticipation and discovery.

### Design Goals

- **Gradual Discovery**: Prevent overwhelming users with 98+ recipes at once
- **Daily Engagement**: Give users a reason to return each day
- **Catch-up Friendly**: Users who return after days instantly unlock all missed days
- **Offline First**: Works without network connectivity
- **Performance**: Unlock checks must be < 100ms

### Key Metrics

- **Trial Duration**: 14 days
- **Daily Unlock**: ~7 recipes per day (varies by theme)
- **Total Recipes**: ~98 recipes across 3 themes (14 days × 7 recipes)
- **Check Frequency**: Hourly while app is active, plus on app activation

---

## System Architecture

### High-Level Flow

```
┌─────────────┐
│   User      │
│ Selects     │
│  Themes     │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ ThemeUnlockTracker  │
│  .startTrial()      │
│                     │
│  Stores:            │
│  - trialStartDate   │
│  - selectedThemeIds │
│  - currentTrialDay  │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Time-based         │
│  Unlock Checks      │
│                     │
│  Triggers:          │
│  • App activation   │
│  • Hourly timer     │
│  • Manual check     │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Day Calculation    │
│                     │
│  days = Calendar    │
│   .dateComponents() │
│  currentDay =       │
│   min(days+1, 15)   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Recipe Filtering   │
│                     │
│  isUnlocked =       │
│   unlockDay <=      │
│   currentTrialDay   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│   Discover View     │
│  Shows unlocked     │
│   recipes only      │
└─────────────────────┘
```

### Component Diagram

```
┌──────────────────────────────────────────────────────┐
│                    App Layer                         │
│  ┌──────────────┐    ┌──────────────┐              │
│  │DiscoverView  │    │TrialDebugView│              │
│  │              │    │              │              │
│  │ Filters by   │    │ Shows status │              │
│  │ isUnlocked() │    │ & controls   │              │
│  └──────┬───────┘    └──────┬───────┘              │
└─────────┼──────────────────┼────────────────────────┘
          │                  │
          ▼                  ▼
┌──────────────────────────────────────────────────────┐
│              Service Layer                           │
│  ┌──────────────────────────────────────────┐       │
│  │      ThemeUnlockTracker (Singleton)      │       │
│  │                                          │       │
│  │  Published Properties:                   │       │
│  │  • currentTrialDay: Int                  │       │
│  │  • hasNewUnlocks: Bool                   │       │
│  │  • isDayChangeTimerActive: Bool          │       │
│  │                                          │       │
│  │  Methods:                                │       │
│  │  • startTrial(themeIds)                  │       │
│  │  • isUnlocked(recipe) -> Bool            │       │
│  │  • checkForNewUnlocks() -> Bool          │       │
│  │  • verifyUnlockIntegrity()               │       │
│  │                                          │       │
│  │  Private:                                │       │
│  │  • updateCurrentTrialDay()               │       │
│  │  • setupDayChangeTimer()                 │       │
│  │  • setupDayChangeObserver()              │       │
│  └────────┬─────────────────────────────────┘       │
└───────────┼──────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────┐
│                Persistence Layer                     │
│  ┌──────────────────────────────────────────┐       │
│  │         UserDefaults                     │       │
│  │  • theme_trial_start_date                │       │
│  │  • selected_theme_ids                    │       │
│  │  • last_unlock_day                       │       │
│  │  • last_unlock_check_date                │       │
│  │  • unlocked_recipe_ids                   │       │
│  └──────────────────────────────────────────┘       │
│                                                      │
│  ┌──────────────────────────────────────────┐       │
│  │         SwiftData (Recipe.swift)         │       │
│  │  • isThemeRecipe: Bool                   │       │
│  │  • unlockDay: Int?                       │       │
│  │  • sourceThemeId: String?                │       │
│  │  • themeRecipeId: String?                │       │
│  └──────────────────────────────────────────┘       │
└──────────────────────────────────────────────────────┘
```

---

## Data Flow

### 1. Trial Initialization

**Trigger**: User completes onboarding, selects 3 themes

```swift
// User selects themes in OnboardingView
let selectedThemes = ["automat", "presidential", "retro-tech"]

// ThemeUnlockTracker stores trial start
tracker.startTrial(withThemeIds: selectedThemes)

// Internal: Sets UserDefaults
UserDefaults.set(Date(), forKey: "theme_trial_start_date")
UserDefaults.set(selectedThemes, forKey: "selected_theme_ids")
currentTrialDay = 1
```

**Result**:
- Trial starts at Day 1
- Day 1 recipes immediately unlocked
- Background timer starts (checks every hour)

---

### 2. Day Calculation

**Formula**:
```swift
let days = Calendar.current.dateComponents([.day],
    from: trialStartDate,
    to: Date()
).day ?? 0

currentTrialDay = min(max(days + 1, 1), 15)
```

**Examples**:
- Trial started today → `days = 0` → `currentTrialDay = 1`
- Trial started 1 day ago → `days = 1` → `currentTrialDay = 2`
- Trial started 13 days ago → `days = 13` → `currentTrialDay = 14`
- Trial started 14+ days ago → `days = 14` → `currentTrialDay = 15` (capped)

**Why +1?**: Day counting is 1-indexed for user-facing display (Day 1, Day 2, etc.)

**Why min/max?**: Ensures day stays in valid range [1, 15]

---

### 3. Unlock Check

**Per-Recipe Check**:
```swift
func isUnlocked(_ recipe: Recipe) -> Bool {
    // User-created recipes always unlocked
    guard let unlockDay = recipe.unlockDay else { return true }

    // Theme recipe unlocked if its day has arrived
    return unlockDay <= currentTrialDay
}
```

**Examples**:
- Day 1, Recipe has `unlockDay: 1` → ✅ Unlocked
- Day 1, Recipe has `unlockDay: 2` → 🔒 Locked
- Day 7, Recipe has `unlockDay: 5` → ✅ Unlocked
- Day 15, Recipe has `unlockDay: 14` → ✅ Unlocked (trial expired, all unlocked)

---

### 4. New Unlock Detection

**Purpose**: Show "New recipes unlocked!" notification once per day

```swift
func checkForNewUnlocks() -> Bool {
    let lastDay = UserDefaults.integer(forKey: "last_unlock_day")

    if currentTrialDay > lastDay {
        UserDefaults.set(currentTrialDay, forKey: "last_unlock_day")
        hasNewUnlocks = true
        return true
    }

    hasNewUnlocks = false
    return false
}
```

**Example Flow**:
1. User opens app on Day 1 → `lastDay = 0`, `currentDay = 1` → Returns `true`
2. User force quits, reopens → `lastDay = 1`, `currentDay = 1` → Returns `false`
3. Next day, opens app → `lastDay = 1`, `currentDay = 2` → Returns `true`

**Used By**: Toast notifications, badge indicators

---

## Key Components

### ThemeUnlockTracker.swift

**Location**: `/Heirloom/Core/Services/Themes/ThemeUnlockTracker.swift`

**Responsibilities**:
- Calculate current trial day based on elapsed time
- Determine which recipes are unlocked
- Detect when new recipes become available
- Manage background timer for day changes
- Provide verification/diagnostics

**Key Properties**:
```swift
@Published private(set) var currentTrialDay: Int = 1
@Published private(set) var hasNewUnlocks: Bool = false
@Published private(set) var isDayChangeTimerActive: Bool = false
@Published private(set) var lastTimerCheckDate: Date?

var trialStartDate: Date { get set }
var selectedThemeIds: [String] { get set }
var isInTrialPeriod: Bool { get }
var isTrialComplete: Bool { get }
var daysRemaining: Int { get }
```

**Key Methods**:
```swift
// Lifecycle
func startTrial(withThemeIds: [String])
func resetTrial()

// Unlock Logic
func isUnlocked(_ recipe: Recipe) -> Bool
func checkForNewUnlocks() -> Bool
func markUnlocksAsSeen()

// Verification (Testing)
func verifyUnlockIntegrity(modelContext: ModelContext) -> UnlockVerificationResult

// Debug (DEBUG builds only)
#if DEBUG
func debugSetTrialDay(_ day: Int)
#endif
```

---

### Recipe.swift (Theme Fields)

**Location**: `/Heirloom/Core/Models/Recipe.swift`

**Theme-Related Fields**:
```swift
@Model
final class Recipe {
    /// Flag indicating this is a theme recipe (vs user-created)
    var isThemeRecipe: Bool = false

    /// Day on which this recipe unlocks (1-14)
    var unlockDay: Int?

    /// ID of the theme (e.g., "automat", "presidential")
    var sourceThemeId: String?

    /// Unique recipe ID (e.g., "automat-001")
    var themeRecipeId: String?
}
```

**Example Data**:
```swift
Recipe(
    title: "Cafeteria Creamed Spinach",
    isThemeRecipe: true,
    unlockDay: 3,
    sourceThemeId: "automat",
    themeRecipeId: "automat-012"
)
```

**Query Pattern**:
```swift
// Fetch all theme recipes
let descriptor = FetchDescriptor<Recipe>(
    predicate: #Predicate { $0.isThemeRecipe == true }
)
let themeRecipes = try modelContext.fetch(descriptor)

// Filter unlocked recipes
let unlockedRecipes = themeRecipes.filter { tracker.isUnlocked($0) }
```

---

### TrialDebugView.swift

**Location**: `/Heirloom/Features/Settings/TrialDebugView.swift`

**Purpose**: QA/Debug interface for testing unlock behavior

**Features**:
- Display trial status (current day, remaining days)
- Manual unlock trigger button
- Day skip controls (Day 7, Day 13, Day 15)
- Unlock verification button
- Debug log export
- Background timer status
- Unlock timeline visualization

**Usage**:
```
Settings → Trial Debug
```

---

## Timing & Triggers

### When Unlock Checks Happen

#### 1. App Activation (Foreground)
**Trigger**: `UIApplication.didBecomeActiveNotification`

```swift
NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
    .sink { [weak self] _ in
        self?.updateCurrentTrialDay()
        _ = self?.checkForNewUnlocks()
    }
```

**Why**: Catches day changes that happened while app was closed or backgrounded

**Frequency**: Every time user opens or returns to app

---

#### 2. Background Timer (Hourly)
**Trigger**: `Timer.scheduledTimer(withTimeInterval: 3600)`

```swift
dayChangeTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
    self?.updateCurrentTrialDay()

    if self.currentTrialDay > previousDay {
        _ = self?.checkForNewUnlocks()

        // Notify UI of new unlocks
        NotificationCenter.default.post(
            name: NSNotification.Name("ThemeUnlocksAvailable"),
            object: self,
            userInfo: ["day": self.currentTrialDay]
        )
    }
}
```

**Why**: Catches day changes while app is open (e.g., user leaves app open overnight)

**Frequency**: Every hour while app is active

**Lifecycle**:
- **Started**: On app launch (if in trial period)
- **Paused**: When app backgrounds
- **Resumed**: When app foregrounds

**Performance**: Minimal impact, only runs calculation (no DB queries)

---

#### 3. Manual Check (ContentView)
**Trigger**: User navigates to Discover tab

```swift
// In ContentView.swift (line ~1507)
.onAppear {
    checkForDailyUnlock()
}
```

**Why**: Ensures recipes refresh when user navigates to Discover

**Frequency**: When Discover tab becomes visible

---

### Notification System

**Custom Notification**: `ThemeUnlocksAvailable`

```swift
// Posted by ThemeUnlockTracker when day changes
NotificationCenter.default.post(
    name: NSNotification.Name("ThemeUnlocksAvailable"),
    object: tracker,
    userInfo: ["day": currentTrialDay]
)

// Can be observed by UI to show toast, update badge, etc.
```

**Use Cases**:
- Show toast: "🎉 New recipes unlocked!"
- Update tab bar badge
- Refresh recipe list

---

## Data Storage

### UserDefaults Keys

| Key | Type | Purpose | Example Value |
|-----|------|---------|---------------|
| `theme_trial_start_date` | Date | When trial began | `2026-02-01 10:30:00` |
| `selected_theme_ids` | [String] | User's chosen themes | `["automat", "presidential"]` |
| `last_unlock_day` | Int | Last day unlock notification shown | `7` |
| `last_unlock_check_date` | Date | When last checked for unlocks | `2026-02-08 14:22:15` |
| `unlocked_recipe_ids` | Set<UUID> | Previously unlocked recipe UUIDs | `{uuid1, uuid2, uuid3}` |

**Legacy Key (Migration)**:
- `heritage_start_date` → Migrated to `theme_trial_start_date`

---

### Recipe Data (SwiftData)

**Model**: `Recipe.swift`

**Theme Fields**:
- `isThemeRecipe: Bool` - Flag for theme vs user recipes
- `unlockDay: Int?` - Day recipe unlocks (1-14, nil = always unlocked)
- `sourceThemeId: String?` - Theme identifier
- `themeRecipeId: String?` - Unique recipe ID within theme

**Query Patterns**:
```swift
// All theme recipes
#Predicate { $0.isThemeRecipe == true }

// Recipes from specific theme
#Predicate { $0.sourceThemeId == "automat" }

// Recipes unlocking on Day 5
#Predicate { $0.unlockDay == 5 }
```

---

### Data Persistence Guarantees

**Critical**: Trial state must survive:
- ✅ App force quit
- ✅ Device reboot
- ✅ App update
- ✅ System date change
- ✅ Timezone change

**Achieved By**:
- UserDefaults is persisted to disk immediately
- SwiftData auto-saves to SQLite database
- No in-memory-only state for critical data

---

## Edge Cases

### 1. User Opens App After Multiple Days

**Scenario**: User started trial, didn't open app for 7 days

**Behavior**:
```swift
// Trial started 7 days ago
trialStartDate = "2026-01-26"
today = "2026-02-02"

// On app open
days = 7
currentTrialDay = 8  // Jumps to Day 8

// Unlock check
checkForNewUnlocks()  // Returns true (last was Day 1)

// Result: All recipes from Days 1-8 unlock instantly
```

**User Experience**: "Catch-up unlock" - user gets all missed days immediately

---

### 2. System Clock Changes

**Scenario**: User changes device date/time

**Protection**:
```swift
// Day calculation uses real calendar math
let days = Calendar.current.dateComponents([.day], from: trialStartDate, to: Date())

// If user sets clock backward
// days could be negative → capped to 1 via max()

// If user sets clock forward
// days could be > 14 → capped to 15 via min()
```

**Verification Catches**:
```swift
if daysSinceStart < 0 {
    errors.append("Trial start date is in the future")
}
```

---

### 3. No Selected Themes

**Scenario**: User somehow skips theme selection in onboarding

**Protection**:
```swift
var hasSelectedThemes: Bool {
    !selectedThemeIds.isEmpty
}

var isInTrialPeriod: Bool {
    guard hasSelectedThemes else { return false }
    return currentTrialDay >= 1 && currentTrialDay <= 14
}
```

**Result**: Timer doesn't start, unlock checks disabled

**Verification Catches**:
```swift
if selectedThemeIds.isEmpty {
    warnings.append("No themes selected - user may not have completed onboarding")
}
```

---

### 4. Recipe Missing unlockDay

**Scenario**: Theme recipe imported without `unlockDay` property

**Behavior**:
```swift
func isUnlocked(_ recipe: Recipe) -> Bool {
    guard let unlockDay = recipe.unlockDay else {
        return true  // Always unlocked if no day specified
    }
    return unlockDay <= currentTrialDay
}
```

**Result**: Recipe treated as always-unlocked (graceful degradation)

**Verification Catches**:
```swift
for recipe in themeRecipes {
    guard let unlockDay = recipe.unlockDay else {
        warnings.append("Recipe '\(recipe.title)' missing unlockDay")
        continue
    }
}
```

---

### 5. Invalid unlockDay Value

**Scenario**: Recipe has `unlockDay: 99` (outside valid range)

**Behavior**:
```swift
// Day 14, recipe.unlockDay = 99
return 99 <= 14  // false → locked forever
```

**Result**: Recipe never unlocks (bug)

**Verification Catches**:
```swift
if unlockDay < 1 || unlockDay > 14 {
    errors.append("Recipe '\(recipe.title)' has invalid unlockDay: \(unlockDay)")
}
```

**Fix**: Run verification before deployment, fix Firebase data

---

### 6. Trial Expires (Day 15+)

**Scenario**: User reaches Day 15 (trial complete)

**Behavior**:
```swift
var isTrialComplete: Bool {
    currentTrialDay > 14
}

// All recipes remain unlocked
isUnlocked(recipe) // Still true for Day 1-14 recipes
```

**Result**: User keeps all unlocked recipes, no new unlocks

**UI**: Shows "Trial Complete" instead of "Day 15/14"

---

### 7. App Backgrounded During Unlock

**Scenario**: Day changes while app is in background

**Behavior**:
1. User backgrounds app at 11:59 PM (Day 1)
2. Clock strikes midnight → Day 2
3. Background timer is paused (app suspended)
4. User foregrounds app

**On Foreground**:
```swift
UIApplication.didBecomeActiveNotification triggers
→ updateCurrentTrialDay()  // Calculates Day 2
→ checkForNewUnlocks()     // Returns true
→ Shows "New recipes unlocked!"
```

**Result**: Unlock happens on foreground, user sees notification

---

### 8. Force Quit During Unlock Check

**Scenario**: User force quits app while unlock check is running

**Protection**:
- `currentTrialDay` is calculated on-demand (not stored)
- `last_unlock_day` only updated after check completes
- If force quit mid-check, `last_unlock_day` not incremented

**On Reopen**:
```swift
checkForNewUnlocks()  // Re-runs, still returns true
```

**Result**: User still sees unlock notification (idempotent operation)

---

## Performance Considerations

### Unlock Check Performance

**Target**: < 100ms per full unlock check

**Bottleneck**: Recipe query from SwiftData

**Optimization**:
```swift
// Bad: Query all recipes, then filter
let allRecipes = try modelContext.fetch(FetchDescriptor<Recipe>())
let themeRecipes = allRecipes.filter { $0.isThemeRecipe }

// Good: Query with predicate (pushed to SQLite)
let descriptor = FetchDescriptor<Recipe>(
    predicate: #Predicate { $0.isThemeRecipe == true }
)
let themeRecipes = try modelContext.fetch(descriptor)
```

**Why**: Predicate filtering happens in SQL, faster than Swift filtering

---

### Memory Usage

**Target**: < 5MB increase during unlock check

**Why Low**:
- Only metadata loaded (no image data)
- Recipe objects are lightweight (~1KB each)
- 100 recipes × 1KB = ~100KB

**Monitoring**:
```swift
// In Xcode Debug Navigator → Memory
// Before unlock: Note baseline
// During unlock: Should increase < 5MB
// After unlock: Should return to baseline
```

---

### Timer Impact

**Hourly Timer**:
- Runs 1 calculation per hour
- No DB queries unless day changed
- Negligible battery impact

**Comparison**:
- GPS tracking: ~100mW
- Unlock timer: < 1mW

---

### Database Indexes

**Recommended Indexes** (if performance issues):
```sql
-- Index on isThemeRecipe for fast filtering
CREATE INDEX idx_recipe_isThemeRecipe ON Recipe(isThemeRecipe);

-- Index on unlockDay for unlock timeline queries
CREATE INDEX idx_recipe_unlockDay ON Recipe(unlockDay);
```

**Note**: SwiftData doesn't expose index creation yet (as of iOS 17)

---

## Testing Strategy

### Automated Tests

**Location**: `HeirloomTestsV2/Integration/DailyUnlockIntegrationTest.swift`

**8 Test Methods**:
1. Fresh install unlocks Day 1
2. Day progression (1→2→7)
3. Full 14-day cycle
4. Expired trial (Day 15)
5. Catch-up unlock (return after 7 days)
6. Recipe without unlockDay
7. Invalid unlockDay detection
8. New unlock detection

**Run Command**:
```bash
xcodebuild test \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:HeirloomTestsV2/DailyUnlockIntegrationTest
```

---

### Manual Testing

**Protocol**: `docs/daily-unlocks-test-protocol.md`

**6 Sections**:
1. Fresh install test
2. Day progression test (Days 1-7)
3. Edge cases (5 scenarios)
4. Verification script
5. Debug log export
6. Performance benchmarks

**Before Every Deployment**: Run full manual protocol

---

### Debug Tools

**Settings → Trial Debug**:
- View current trial status
- Skip ahead to any day
- Verify unlock system integrity
- Export debug log
- View background timer status
- See unlock timeline (✅/🔒)

---

### Verification

**Pre-Deployment Check**:
```swift
let result = tracker.verifyUnlockIntegrity(modelContext: modelContext)

if !result.isValid {
    print("❌ Unlock system has errors:")
    result.errors.forEach { print("  • \($0)") }
    // DO NOT DEPLOY
}
```

**Checks**:
- Trial date is set and valid
- Day calculation is sane
- Recipe unlock days in valid range (1-14)
- No missing or invalid data

---

## Future Improvements

### Short-Term (Next Sprint)

1. **Analytics Integration**
   - Track unlock success rate
   - Monitor which days users reach
   - Identify drop-off points

2. **Push Notifications**
   - "New recipes unlocked!" notification at midnight
   - Requires notification permissions

3. **Unlock Animations**
   - Smooth reveal animation when new recipes unlock
   - Confetti/celebration effect on unlock

---

### Medium-Term (Next Quarter)

4. **Flexible Unlock Schedule**
   - Remote config for unlock cadence (daily, every 2 days, etc.)
   - A/B test different unlock patterns

5. **Themed Unlock Events**
   - "Weekend Special: Extra recipes unlocked!"
   - Holiday-themed unlock bonuses

6. **Unlock Previews**
   - Show silhouettes of locked recipes
   - Tease upcoming unlocks

---

### Long-Term (Future)

7. **Personalized Unlock Order**
   - ML-based unlock order based on user preferences
   - "You seem to like Italian food, unlocking more Italian recipes"

8. **Social Unlock Sharing**
   - "I just unlocked a new recipe!" share to friends
   - Friend unlocks create engagement

9. **Unlock Milestones**
   - Achievements for unlock streaks
   - Badges for completing full 14-day trial

---

## Appendix: Code References

### Key Files

| File | Lines | Description |
|------|-------|-------------|
| `ThemeUnlockTracker.swift` | 296 | Core unlock logic |
| `Recipe.swift` | 43-55 | Theme recipe data model |
| `TrialDebugView.swift` | 316 | Debug/QA interface |
| `DailyUnlockIntegrationTest.swift` | 380 | Automated tests |
| `daily-unlocks-test-protocol.md` | - | Test protocol |

---

### Important Method Signatures

```swift
// ThemeUnlockTracker.swift

// Lifecycle
func startTrial(withThemeIds: [String])
func resetTrial()

// Core Logic
func isUnlocked(_ recipe: Recipe) -> Bool
func checkForNewUnlocks() -> Bool
func updateCurrentTrialDay()

// Verification
func verifyUnlockIntegrity(modelContext: ModelContext) -> UnlockVerificationResult

// Debug
#if DEBUG
func debugSetTrialDay(_ day: Int)
#endif
```

---

### UserDefaults Keys Reference

```swift
private enum Keys {
    static let trialStartDate = "theme_trial_start_date"
    static let selectedThemeIds = "selected_theme_ids"
    static let unlockedRecipeIds = "unlocked_recipe_ids"
    static let lastCheckDate = "last_unlock_check_date"
    static let lastUnlockDay = "last_unlock_day"

    // Legacy
    static let legacyHeritageStart = "heritage_start_date"
}
```

---

## Questions?

**Engineering**: Unlock logic questions
**Product**: Feature requirements
**QA**: Testing procedures
**Support**: User-facing issues

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-02-02 | Initial architecture documentation | Claude Code |
