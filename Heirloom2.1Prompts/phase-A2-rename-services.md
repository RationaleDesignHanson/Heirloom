# Heirloom Collections Overhaul
## Phase A2: Rename Heritage → Theme Services

**Branch:** `feature/collections-A2-rename-services`
**Estimated Time:** 20-30 minutes
**Dependencies:** Phase A1 complete

---

## Objective

Rename all "Heritage" references to "Theme" throughout the codebase. This is a terminology change that aligns with the new theme-based discovery model.

---

## Task A2.1: Rename Service Files

**Rename these files:**

| Old Path | New Path |
|----------|----------|
| `Heirloom/Core/Services/Heritage/HeritageOnDemandService.swift` | `Heirloom/Core/Services/Themes/ThemeRecipeService.swift` |
| `Heirloom/Core/Services/Heritage/HeritageRecipeCache.swift` | `Heirloom/Core/Services/Themes/ThemeRecipeCache.swift` |
| `Heirloom/Core/Services/Heritage/HeritageUnlockTracker.swift` | `Heirloom/Core/Services/Themes/ThemeUnlockTracker.swift` |

**Rename the folder:**

```bash
# From project root
mv Heirloom/Core/Services/Heritage Heirloom/Core/Services/Themes
```

**Update Xcode project file** if not using folder references.

---

## Task A2.2: Rename Classes Within Files

**In `ThemeRecipeService.swift` (formerly HeritageOnDemandService):**

```swift
// Find and replace:
// HeritageOnDemandService → ThemeRecipeService
// heritage → theme (case-sensitive where appropriate)
// Heritage → Theme

// Example class declaration:
class ThemeRecipeService: ObservableObject {
    // ... existing implementation with renamed references
}
```

**In `ThemeRecipeCache.swift` (formerly HeritageRecipeCache):**

```swift
// Find and replace:
// HeritageRecipeCache → ThemeRecipeCache
// heritage → theme
// Heritage → Theme

class ThemeRecipeCache {
    // ... existing implementation
}
```

**In `ThemeUnlockTracker.swift` (formerly HeritageUnlockTracker):**

```swift
// Find and replace:
// HeritageUnlockTracker → ThemeUnlockTracker
// heritage → theme
// Heritage → Theme

class ThemeUnlockTracker: ObservableObject {
    // ... existing implementation
}
```

---

## Task A2.3: Rename Feature Views

**Rename files in Features/Heritage:**

| Old Path | New Path |
|----------|----------|
| `Heirloom/Features/Heritage/DailyUnlockView.swift` | `Heirloom/Features/Themes/DailyUnlockView.swift` |
| `Heirloom/Features/Heritage/HeritageUnlockView.swift` | `Heirloom/Features/Themes/ThemeUnlockView.swift` |

**Rename folder:**

```bash
mv Heirloom/Features/Heritage Heirloom/Features/Themes
```

**Update class/struct names within files:**

```swift
// HeritageUnlockView → ThemeUnlockView
struct ThemeUnlockView: View {
    // ...
}
```

---

## Task A2.4: Update All Import Statements

**Search entire project for Heritage imports and update:**

```swift
// OLD
import HeritageOnDemandService
// or references like:
@StateObject private var heritageTracker: HeritageUnlockTracker

// NEW
import ThemeRecipeService
// or:
@StateObject private var themeTracker: ThemeUnlockTracker
```

**Files likely to need updates:**
- `App.swift` or `HeirloomApp.swift`
- `ServiceContainer.swift` or DI setup
- `OnboardingContainerView.swift`
- Any view that shows heritage/unlock content
- `CollectionsListView.swift`

---

## Task A2.5: Update UserDefaults Keys

**In ThemeUnlockTracker (and anywhere else):**

```swift
// OLD keys
private let heritageStartKey = "heritage_start_date"
private let heritageUnlockedKey = "heritage_unlocked_recipes"

// NEW keys - BUT maintain backward compatibility
private let legacyHeritageStartKey = "heritage_start_date"
private let trialStartKey = "theme_trial_start_date"

var trialStartDate: Date {
    get {
        // Check new key first, fall back to legacy
        if let date = userDefaults.object(forKey: trialStartKey) as? Date {
            return date
        }
        // Migrate from legacy key
        if let legacyDate = userDefaults.object(forKey: legacyHeritageStartKey) as? Date {
            userDefaults.set(legacyDate, forKey: trialStartKey)
            return legacyDate
        }
        return Date()
    }
    set {
        userDefaults.set(newValue, forKey: trialStartKey)
    }
}
```

---

## Task A2.6: Update Analytics Events

**Search for analytics calls with "heritage" and update:**

```swift
// OLD
Analytics.log("heritage_recipe_unlocked", parameters: [...])

// NEW
Analytics.log("theme_recipe_unlocked", parameters: [...])
```

---

## Task A2.7: Update String Literals in UI

**Search for user-facing strings:**

```swift
// OLD
Text("Heritage Recipes")
Text("Your heritage collection")

// NEW  
Text("Discovery Recipes")
Text("Your curated collection")
// Or simply use the theme name dynamically
Text(theme.name)
```

---

## Verification Checklist

- [ ] All Heritage folders renamed to Themes
- [ ] All HeritageX classes renamed to ThemeX
- [ ] All import statements updated
- [ ] All @StateObject/@ObservedObject references updated
- [ ] UserDefaults keys migrated with backward compatibility
- [ ] Analytics events renamed
- [ ] UI strings updated
- [ ] `xcodebuild` succeeds with no errors
- [ ] App launches without crashes

---

## Search Commands

Use these to find remaining references:

```bash
# From project root
grep -r "Heritage" --include="*.swift" Heirloom/
grep -r "heritage" --include="*.swift" Heirloom/
```

---

## Commit Message

```
refactor: Rename Heritage system to Themes

- Rename HeritageOnDemandService → ThemeRecipeService
- Rename HeritageRecipeCache → ThemeRecipeCache  
- Rename HeritageUnlockTracker → ThemeUnlockTracker
- Move Services/Heritage/ → Services/Themes/
- Move Features/Heritage/ → Features/Themes/
- Update all imports and references
- Migrate UserDefaults keys with backward compatibility
- Update analytics events

Part of collections overhaul Phase A2
```

---

## Next Phase

→ **Phase A3:** Update ThemeUnlockTracker for theme selection
