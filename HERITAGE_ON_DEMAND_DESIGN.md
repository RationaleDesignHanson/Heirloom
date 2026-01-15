# Heritage Recipe On-Demand Unlock System - Design Document

## Problem Statement

**Current System Issues:**
1. Downloads all 100 heritage recipes + images on first launch (30-45 seconds)
2. Stores all recipes as "locked" in local database
3. Complex unlock logic that's hard to debug
4. Firebase state can get out of sync
5. Blind boxes disappear when tapped but recipes don't unlock correctly
6. Recipes show in main recipes list even when locked

**Root Causes:**
- Trying to manage "locked" vs "unlocked" state for recipes that already exist locally
- Progressive unlock implemented as filtering, not true on-demand delivery
- Collection-based tracking instead of individual recipe tracking
- No server-side control over unlock schedules

## Proposed Solution: On-Demand Heritage Delivery

### Core Concept

**Don't seed recipes until they're unlocked**

- Server maintains 100 different unlock schedules (pre-computed arrays of recipe IDs)
- Each user gets assigned one schedule based on their Firebase user ID
- Day 1: Download only 5-7 recipes (Literary: 5, Other: 2-3)
- Day 2+: Download next 5-7 recipes each day
- Recipes don't exist in local database until downloaded

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       Firebase (Source of Truth)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  /heritage_schedules/{scheduleId}                                │
│    - scheduleId: "schedule-001" to "schedule-100"                │
│    - recipes: [array of recipe IDs in unlock order]              │
│    - metadata: {collections, distribution}                       │
│                                                                   │
│  /users/{userId}/heritageState                                   │
│    - assignedScheduleId: "schedule-042"                          │
│    - downloadedRecipeIds: ["literary-001", "literary-002", ...]  │
│    - currentDay: 3                                               │
│    - lastUnlockDate: "2026-01-14"                                │
│    - trialEndsAt: "2026-01-28"                                   │
│                                                                   │
│  /heritage_recipes/{recipeId}                                    │
│    - Full recipe data (ingredients, instructions, etc.)          │
│    - imageURL: Firebase Storage URL                              │
│    - collectionId: "literary-kitchen"                            │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                              ↓ Download on demand
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                          iOS App (SwiftData)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Local Database (only downloaded recipes)                        │
│    - Recipe models with isHeritageRecipe = true                  │
│    - Images stored locally                                       │
│    - NO "locked" recipes in database                             │
│                                                                   │
│  HeritageUnlockService                                           │
│    - getUserSchedule() → fetches assigned schedule               │
│    - unlockDailyBatch() → downloads next N recipes               │
│    - downloadRecipe(recipeId) → fetches from Firestore           │
│                                                                   │
│  UI Layer                                                         │
│    - Blind boxes: only shown if NOT revealed                     │
│    - Collections: only shown if has recipes                      │
│    - Recipes list: only shows downloaded recipes                 │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Unlock Schedule Structure

Each schedule defines:
1. **Initial Unlock (Day 1)**: Exactly 8 recipes
   - 5 from Literary Kitchen
   - 3 from one other collection (Presidential/Ancient/American)
2. **Daily Unlocks (Days 2-14)**: 7 recipes per day
   - Distributed across revealed collections
3. **Total**: 8 + (13 × 7) = 99 recipes over 14 days

**Example Schedule:**
```json
{
  "scheduleId": "schedule-042",
  "version": "1.0",
  "revealedCollections": ["literary-kitchen", "american-foundation"],
  "unlockPlan": [
    {
      "day": 1,
      "recipes": [
        "literary-001",
        "literary-005",
        "literary-012",
        "literary-018",
        "literary-023",
        "american-003",
        "american-008",
        "american-014"
      ]
    },
    {
      "day": 2,
      "recipes": [
        "literary-007",
        "literary-011",
        "literary-019",
        "literary-024",
        "american-001",
        "american-006",
        "american-015"
      ]
    }
    // ... days 3-14
  ]
}
```

### Implementation Steps

#### Phase 1: Firebase Backend Setup
1. **Create heritage_recipes collection**
   - Migrate all 100 recipes from JSON to Firestore
   - Store images in Firebase Storage
   - Add indexes for efficient querying

2. **Generate 100 unlock schedules**
   - Script to create diverse schedules
   - Ensure even distribution across collections
   - Upload to heritage_schedules collection

3. **Update Firestore rules**
   - Allow authenticated users to read heritage_recipes
   - Allow authenticated users to read heritage_schedules
   - Update heritageState rules

#### Phase 2: iOS App Changes
1. **Remove local heritage seeding**
   - Delete HeritageRecipeSeeder.seedHeritageRecipes()
   - Remove heritage-recipes.json from bundle
   - Keep blind box creation (collections only, no recipes)

2. **Rewrite HeritageUnlockService**
   - getUserSchedule() fetches assigned schedule from Firebase
   - unlockDailyBatch() downloads recipes from Firestore
   - downloadRecipe() inserts into SwiftData after download

3. **Update UI**
   - BlindBoxCollectionRow: reveal both boxes, trigger first unlock
   - CollectionRow: only show collections with recipes
   - RecipeListView: no filtering needed (only unlocked recipes exist)

4. **Update CollectionsListView**
   - Remove recipes count from blind boxes (they're empty until revealed)
   - On reveal: call unlockDailyBatch() to download initial 8 recipes

#### Phase 3: Migration Strategy
1. **For new users**: Works immediately
2. **For existing users**:
   - Detect if they have locally seeded recipes
   - Keep them (grandfather existing users)
   - Set their downloadedRecipeIds to match local recipes
   - Future unlocks use on-demand system

### Benefits

✅ **Fast first launch**: 2-3 seconds (only download 8 recipes)
✅ **No locked recipes confusion**: Recipes don't exist until unlocked
✅ **Server-side control**: Change schedules without app update
✅ **Bandwidth efficient**: Only download what's needed
✅ **Storage efficient**: Only store unlocked recipes
✅ **Simpler logic**: No need for isLocked filtering
✅ **Easy to debug**: State matches reality (if recipe exists, it's unlocked)

### Rollout Plan

1. **Week 1**: Backend setup (schedules + recipes in Firestore)
2. **Week 2**: iOS implementation + testing
3. **Week 3**: Soft launch to internal testers
4. **Week 4**: Production release with migration support

### Open Questions

1. Should we keep a local cache of recipe metadata (titles only) for preview?
2. How do we handle offline unlocks? (Queue for later sync?)
3. Should schedules be updateable or fixed per user?
4. Do we need a "catchup" mechanism if user misses days?

### Success Metrics

- First launch time < 5 seconds (vs 30-45 seconds)
- Bandwidth usage < 5MB day 1 (vs 50MB+ currently)
- Zero "locked recipe" bugs reported
- 100% cross-device consistency
