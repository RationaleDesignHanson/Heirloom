# Demo Recipe Safeguards Plan

## Final Decisions

1. **Strict Isolation**: Demo recipes (`isDemoRecipe = true`) can NEVER be shared - no adoption path
2. **Sanitize Prompt**: When sharing a recipe that was edited by a demo user, prompt user: "Remove demo friends from lineage?"
3. **No Adoption**: Demo recipes stay demo forever - user creates their own if they want to share something similar
4. **Developer Cleanup**: Settings → Developer → "Remove demo data" (connections + recipes)

---

## Current State Analysis

### What Exists
- **Demo users**: 7 hardcoded demo accounts (demo_grandmazing, demo_phillipfry, demo_bigshare, etc.)
- **Demo connections**: `isDemoConnection: true` flag on connection documents
- **Demo shares**: `isDemoShare: true` flag on share documents in Firebase
- **Demo notifications**: `isDemoNotification: true` flag on notifications
- **Demo behaviors**: Auto-accept, recipe sharing, recipe modification (DemoSocialBehaviorService)

### What's Missing
- **No `isDemoRecipe` flag** on Recipe model - once accepted, demo recipes are indistinguishable
- **No sharing restrictions** on demo-received recipes
- **Demo users appear in heritageChain** - pollutes real lineage data if re-shared
- **No cleanup path** for demo data when user has real connections

---

## Scenarios to Address

### Scenario 1: User Accepts Demo Recipe, Wants to Share
```
Big Share → shares Traveling Bolognese (with deep lineage) → User accepts
User → wants to share with Mom (real connection)
```

**Current behavior**: User CAN share it. Big Share and other demo users appear in lineage.

**Concerns**:
- Mom sees "Big Share", "demo_grandmazing" in heritage chain
- Demo users pollute real family lineage forever
- If user shares to community (Discover), demo lineage goes public

### Scenario 2: User Shares Recipe With Demo User, Demo Edits
```
User → shares "My Pasta" with demo_grandmazing
demo_grandmazing → auto-accepts, auto-modifies (adds jalapeño, renames to "Spicy My Pasta")
User sees diff view in lineage
User → shares "My Pasta" with Mom
```

**Current behavior**: Demo user's edit creates lineage record. If shared to Mom:
- Does Mom see demo user in lineage? (Currently: YES)
- Demo user's modification is part of the tree

### Scenario 3: User Connects With Real Person After Demo
```
User → completes onboarding, demo_grandmazing auto-friends
User → connects with real Mom
User → has both demo and real connections
```

**Questions**:
- Should demo connections persist forever?
- Should there be a "clean up demo data" option?
- What happens to recipes received from demo users?

---

## Design Options

### Option A: Strict Isolation (Recommended)

**Recipe model addition:**
```swift
/// Whether this recipe originated from a demo user and has sharing restrictions
var isDemoRecipe: Bool = false
```

**Rules:**
1. Recipes received from demo users are marked `isDemoRecipe = true`
2. Demo recipes CANNOT be shared (button disabled with tooltip)
3. Demo users DO appear in lineage (educational value) but marked as "Demo Friend"
4. Demo recipes can be "adopted" (one-time action that clears isDemoRecipe, resets lineage to user as root)

**Share UI behavior:**
```
User taps Share on demo recipe:
→ Sheet appears with message:
  "This is a demo recipe. To share your own version, tap 'Make It Mine' to adopt it as your own first."
  [Make It Mine] [Cancel]
```

**Adoption flow:**
- Clears `isDemoRecipe`
- Sets user as root of lineage (`heritageChain = [userId]`, `heritageChainNames = [userName]`)
- Clears `sharedBy`, `sharedByUserId`
- Recipe becomes fully shareable

**Pros:**
- Clean separation between demo and real
- User understands what's demo vs real
- No demo pollution in real lineage trees
- Demo recipes still work for learning the app

**Cons:**
- Extra adoption step if user wants to share demo recipe
- Demo recipes feel "second class"

---

### Option B: Sanitized Sharing

**Rules:**
1. NO isDemoRecipe flag - all recipes are equal
2. When sharing a recipe, STRIP demo users from heritageChain before creating share
3. If heritageChain would become empty after stripping, user becomes root

**Implementation:**
```swift
// In createShare():
let sanitizedChain = heritageChain?.filter { !DemoSocialBehaviorService.isDemoUser($0) }
let sanitizedNames = // corresponding names

if sanitizedChain?.isEmpty == true {
    // User becomes root
    shareData["heritageChain"] = [userId]
    shareData["heritageChainNames"] = [userName]
    shareData["generation"] = 0
} else {
    shareData["heritageChain"] = sanitizedChain
    shareData["heritageChainNames"] = sanitizedNames
}
```

**Pros:**
- No extra adoption step
- Seamless user experience
- Demo data automatically filtered

**Cons:**
- Implicit behavior (user doesn't know filtering happened)
- Recipe "jumps generations" unexpectedly
- Shared recipe has different lineage than local copy

---

### Option C: Demo Data Expiration

**Rules:**
1. Demo connections auto-expire after 7 days or when user adds first real connection
2. Demo recipes auto-expire (flagged for deletion) after expiration
3. User gets notification: "Your demo friends have left - add real friends to keep sharing!"

**Pros:**
- Clean slate for real usage
- No persistent demo pollution
- Encourages real connections

**Cons:**
- User loses demo recipes they may have liked
- Jarring experience
- May confuse users ("where did my recipes go?")

---

### Option D: Hybrid (Demo Recipes as "Samples")

**Rules:**
1. Demo recipes are marked `isSampleRecipe = true` (existing flag)
2. Sample recipes can be viewed, cooked, but not shared
3. User can "duplicate" to their own collection (like theme recipes)
4. Duplication creates a fresh copy with no lineage

**Pros:**
- Uses existing `isSampleRecipe` infrastructure
- Familiar pattern (theme recipes work similarly)
- Clean separation

**Cons:**
- Sample recipes already have specific behavior
- May create confusion with theme recipes

---

## Recommendation: Option A (Strict Isolation) + Grace Period

**Implementation:**

1. **Add `isDemoRecipe: Bool` to Recipe model**
2. **Mark recipes on acceptance** when `isDemoShare == true`
3. **Block sharing** with clear UI explaining why
4. **Provide adoption flow** to make recipe fully yours
5. **Demo connections persist** (no auto-cleanup - user can unfriend manually)
6. **Demo users in lineage** shown with "(Demo)" badge when viewing

**Future enhancement:**
- Settings option: "Reset demo data" that removes demo connections and demo recipes
- After first real connection, offer to clean up demo data

---

## Implementation Tasks

### Phase 1: Recipe Model Update
- [ ] Add `isDemoRecipe: Bool = false` to Recipe.swift
- [ ] Add to `RecipeExportDataV2` and export/import
- [ ] Add to `FirebaseRecordConverter` (upload/download)
- [ ] Add to `UndoService` recipe state

### Phase 2: Share Acceptance
- [ ] In `FirebaseShareService.acceptShare()`, check `isDemoShare` and set `isDemoRecipe = true`
- [ ] Verify demo recipe flag persists through sync

### Phase 3: Share Creation Blocking
- [ ] In share UI, check `recipe.isDemoRecipe`
- [ ] Show explanatory modal: "This is a demo recipe for learning. Create your own recipe to share with friends!"
- [ ] No adoption CTA - demo recipes stay demo forever

### Phase 4: Sanitize Prompt (User's Own Recipes Edited by Demo)
- [ ] Detect if recipe's heritageChain contains demo user IDs
- [ ] When sharing, show prompt: "This recipe was edited by demo friends. Remove them from the family tree before sharing?"
- [ ] If yes: filter demo users from heritageChain/heritageChainNames before creating share
- [ ] If no: include demo users (user's choice)

### Phase 5: Lineage View
- [ ] In lineage tree view, badge demo users as "(Demo)" or similar indicator
- [ ] Visual distinction for demo contributors

### Phase 6: Developer Settings Cleanup
- [ ] Add "Remove demo data" button in Developer Settings
- [ ] Removes all demo connections
- [ ] Removes all recipes where `isDemoRecipe == true`
- [ ] Confirmation dialog before deletion

### Phase 7: Testing
- [ ] Test demo user sends recipe → user accepts → `isDemoRecipe = true` → cannot share
- [ ] Test user shares to demo user → demo edits → user sees diff → user can share with sanitize prompt
- [ ] Test sanitize flow removes demo users from lineage
- [ ] Test developer cleanup removes demo data
- [ ] Test demo recipe flag syncs via Firebase

---

## Heritage Chain Handling Details

### When user accepts demo recipe:
```swift
// In acceptShare():
let isDemoShare = shareData["isDemoShare"] as? Bool ?? false
sharedRecipe.isDemoRecipe = isDemoShare  // Mark as demo - cannot be shared

// Heritage chain still populated for local display:
sharedRecipe.heritageChain = inheritedChain + [userId]
sharedRecipe.heritageChainNames = inheritedChainNames + [currentUserName]
```

### When user shares own recipe TO demo user:
```swift
// Recipe stays user's own (NOT demo - they created it)
// Demo user creates their copy with modifications
// User sees diff view (educational)

// When user later shares to REAL person:
// Check if heritageChain contains demo users
let hasDemoInLineage = recipe.heritageChain?.contains(where: { DemoSocialBehaviorService.isDemoUser($0) }) ?? false

if hasDemoInLineage {
    // Show sanitize prompt before creating share
    // "Remove demo friends from family tree?"
}
```

### Sanitizing lineage before share:
```swift
func sanitizeDemoUsersFromLineage(_ recipe: Recipe) -> ([String], [String]) {
    guard let chain = recipe.heritageChain,
          let names = recipe.heritageChainNames else {
        return ([], [])
    }

    var sanitizedChain: [String] = []
    var sanitizedNames: [String] = []

    for (index, userId) in chain.enumerated() {
        if !DemoSocialBehaviorService.isDemoUser(userId) {
            sanitizedChain.append(userId)
            if index < names.count {
                sanitizedNames.append(names[index])
            }
        }
    }

    return (sanitizedChain, sanitizedNames)
}
```

---

## Appendix: Demo User Identification

```swift
// DemoSocialBehaviorService.swift
static let demoUserIds: Set<String> = [
    "demo_grandmazing",
    "demo_phillipfry",
    "demo_chef_maria",
    "demo_fitfoodie",
    "demo_bakingbelle",
    "demo_grillmaster",
    "demo_bigshare"
]

static func isDemoUser(_ userId: String) -> Bool {
    demoUserIds.contains(userId)
}
```

Easy to check anywhere in the codebase.
