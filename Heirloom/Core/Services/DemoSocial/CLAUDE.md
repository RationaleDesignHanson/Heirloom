# Demo Social System — Claude Code Reference

## What This Is

A TestFlight demo experience that simulates social features (connections, recipe sharing, lineage, notifications) using 7 fake users. The system makes a new user's first 2 minutes feel alive — friend requests appear, recipes get shared, heritage chains are demonstrated — without requiring real users.

## File Inventory

| File | Lines | Role |
|------|-------|------|
| `DemoSocialBehaviorService.swift` | 1,667 | Main orchestrator — all behaviors, scheduling, Firestore writes |
| `ScreenRecordingResetService.swift` | 963 | App-state reset for recordings, demo seed preservation |
| `DemoSocialGate.swift` | 92 | 3-layer feature gate (Remote Config > expiration > local toggle) |
| `DemoSocialConfig.swift` | 101 | Firebase Remote Config wrapper (`demo_social_enabled`, `demo_social_expiration`) |
| `Features/Social/Components/DemoBadge.swift` | 38 | Green "DEMO" capsule badge for search results |

Tests:
- `HeirloomTestsV2/Unit/DemoSocial/DemoSocialBehaviorServiceTests.swift` (715 lines, 40 tests)
- `HeirloomTestsV2/Unit/DemoSocial/DemoSocialGateTests.swift` (218 lines, 14 tests)

## The 7 Demo Users

All UIDs follow the `demo_` prefix pattern. This prefix is the ONLY thing that identifies a demo user — there are no Firebase Auth accounts for them.

| UID | Display Name | Welcome Recipe | Avatar |
|-----|-------------|----------------|--------|
| `demo_grandmazing` | Grandmazing | Brown Butter Chocolate Chip Cookies | `seed/demo/demo_grandmazing-avatar.webp` |
| `demo_phillipfry` | Phillip Fry | Creamy One-Pot Pasta | `seed/demo/demo_phillipfry-avatar.webp` |
| `demo_chef_maria` | Maria Santos | Camarones al Ajillo (Garlic Shrimp) | `seed/demo/demo_chef_maria-avatar.webp` |
| `demo_fitfoodie` | Alex Chen | Ultimate Protein Power Bowl | `seed/demo/demo_fitfoodie-avatar.webp` |
| `demo_bakingbelle` | Belle Thompson | Molten Chocolate Lava Cakes | `seed/demo/demo_bakingbelle-avatar.webp` |
| `demo_grillmaster` | Marcus Johnson | Ultimate Smash Burgers | `seed/demo/demo_grillmaster-avatar.webp` |
| `demo_bigshare` | Big Share | The Traveling Bolognese (multi-gen lineage) | `seed/demo/demo_bigshare-avatar.webp` |

The canonical list is `DemoSocialBehaviorService.demoUserIds` (lines 67-75). Display names, photo URLs, and welcome recipe details are all hardcoded in the same file (lines 78-237).

## Behavioral Flows (6 total)

All flows are timer-driven via `Task.sleep` stored in a `[String: Task]` dictionary with string keys for cancellation.

### Flow 1: Proactive Friend Request
- **Trigger:** `onOnboardingComplete()` called from `OnboardingContainerView` and `HeirloomApp`
- **Delay:** 0 seconds (immediate)
- **Action:** Random demo user sends connection request to the real user
- **Writes:** Connection doc in `users/{userId}/connections/{connectionId}` with `isDemoConnection: true`, notification doc with type `connectionRequestReceived`
- **Dedup:** `hasSentProactiveRequestThisSession` flag + Firestore query for existing demo connections
- **UserDefaults key:** `demo_social_proactive_request_sent`

### Flow 2: Auto-Accept Connection Request
- **Trigger:** `onConnectionRequestSent(to:connectionId:)` called from `ConnectionService`
- **Delay:** 5-30 seconds (random)
- **Action:** Demo user "accepts" the real user's friend request
- **Writes:** Updates connection status to `connected`, sets `acceptedAt`, creates `connectionRequestAccepted` notification
- **Then:** Triggers Flow 3

### Flow 3: Recipe Share After Connection
- **Trigger:** Follows Flow 2 acceptance, or `onDemoConnectionAccepted()` from `ConnectionService`
- **Delay:** 5-15 seconds after acceptance
- **Action:** Demo user shares their welcome recipe with full preview metadata
- **Writes:** Share doc in `shares/{shareId}` with `isDemoShare: true`, notification with type `connectionSharedRecipe`
- **Dedup:** Firestore query checking if demo user already shared this recipe to this user

### Flow 4: Welcome Shares
- **Trigger:** `onOnboardingComplete()` (same as Flow 1)
- **Delay:** 30 seconds after onboarding
- **Action:** 2 random demo users each send a welcome share (0.5s gap between them)
- **Writes:** Share docs with `isDemoShare: true` + `isWelcomeShare: true`, notifications with type `welcomeRecipeShare` + `isWelcomeNotification: true`
- **Dedup:** Firestore query for existing `isWelcomeShare` shares
- **UserDefaults key:** `demo_social_welcome_shares_sent`

### Flow 5: Share Acceptance (User Shares to Demo)
- **Trigger:** `onRecipeSharedWithDemoUser()` called from `FirebaseShareService`
- **Delay:** 5-30 seconds
- **Action:** Demo user "accepts" the real user's shared recipe
- **Writes:** Adds demo UID to share's `acceptedBy` array, increments `acceptCount`, copies recipe to demo user's Firestore collection, creates lineage record, creates `shareAccepted` notification
- **Then:** Triggers Flow 6

### Flow 6: Recipe Modification
- **Trigger:** Follows Flow 5 acceptance
- **Delay:** 15-45 seconds after acceptance
- **Action:** Demo user "modifies" the accepted recipe (renames + adds ingredient)
- **Writes:** Updates recipe title in demo user's copy, adds ingredient, records modification in lineage, creates `lineage_modification` notification
- **8 modification themes:** Spicy (jalapeno), Garlic Lover's (garlic), Cheesy (parmesan), Herb-Infused (rosemary), Smoky (smoked paprika), Zesty (lemon zest), Honey-Glazed (honey), Crispy (panko)

## Integration Points

### 3 Service Hooks (the only entry points into this system)

```
ConnectionService.swift
  → onConnectionRequestSent(to:connectionId:)   // when user friends a demo user
  → onDemoConnectionAccepted(demoUserId:connectionId:)  // when user accepts demo request

FirebaseShareService.swift
  → onRecipeSharedWithDemoUser(shareId:recipeId:recipeTitle:demoUserId:)

OnboardingContainerView.swift + HeirloomApp.swift
  → onOnboardingComplete()
  → start() / stop()
```

### Gate Check Pattern

Every flow checks the gate before executing:
```swift
guard gate.isEnabled else { return }
```

Gate is a 3-layer check:
1. `RemoteConfig.demo_social_enabled` (boolean, defaults true)
2. `RemoteConfig.demo_social_expiration` (ISO8601 date, optional kill-switch)
3. `UserDefaults.demoSocialModeDisabled` (local toggle in Developer Settings)

## Security Rules (5 demo exceptions in `firestore.rules`)

The function `isDemoUser(userId)` checks `userId.matches('demo_.*')` and grants broader write access:

1. **Recipe CRUD** (`users/{userId}/recipes`) — any auth user can create/update/delete demo user recipes + all subcollections (ingredients, instructions, comments, cardBack, operations)
2. **Share creation** (`shares/{shareId}`) — any auth user when `ownerId` is demo
3. **Share deletion** — recipients can delete shares where `ownerId` is demo (reset cleanup)
4. **Connection CRUD** (`users/{userId}/connections`) — any auth user when either party is demo
5. **Lineage CRUD** (`lineages/{lineageId}`) — any auth user for demo-owned lineages

## Data Model Markers

These boolean flags distinguish demo data from real user data:

| Field | Collection | Purpose |
|-------|-----------|---------|
| `isDemoConnection` | `users/{uid}/connections/{id}` | Marks connections with demo users |
| `isDemoShare` | `shares/{shareId}` | Marks shares originating from demo system |
| `isWelcomeShare` | `shares/{shareId}` | Marks the 2 welcome shares sent after onboarding |
| `isDemoNotification` | `users/{uid}/notifications/{id}` | Marks all demo-generated notifications |
| `isWelcomeNotification` | `users/{uid}/notifications/{id}` | Marks welcome share notifications |
| `isDemoSeed` | `users/{uid}/recipes/{id}`, `users/{uid}/collections/{id}` | Marks seed data preserved during reset |
| `isDemoUser` / `isDemoSeed` | Algolia `users` index | Used by `UserSearchResult.shouldShowDemoBadge` |

## Screen Recording Reset (`ScreenRecordingResetService`)

`resetToFirstTimeUser()` does a comprehensive wipe:

1. Clears local SwiftData (recipes, collections, jobs) — **except** items marked `isDemoSeed: true`
2. Clears all Firebase user data (recipes, collections, connections, notifications, shares, lineages) in batch operations (400 docs per batch)
3. Removes the real user from every demo user's connection list
4. Resets onboarding state, job queues, user credits
5. Signs user out to prevent sync race
6. Returns `ResetVerification` struct with counts for validation

**Demo seed preservation logic:** Queries BOTH SwiftData AND Firestore for `isDemoSeed: true` items, uses case-insensitive UUID comparison, also preserves collections that CONTAIN demo seed recipes even if the collection itself isn't marked.

## UserDefaults Keys

| Key | Type | Purpose |
|-----|------|---------|
| `demoSocialModeDisabled` | Bool | Local toggle (false = demo ON) |
| `demo_social_welcome_shares_sent` | Bool | Prevents duplicate welcome shares |
| `demo_social_proactive_request_sent` | Bool | Prevents duplicate proactive requests |
| `hideThemeCollections` | Bool | Screen recording: hide heritage theme collections |
| `hideDemoSeedCollections` | Bool | Screen recording: hide demo seed collections |

## Seeding & Cleanup Scripts

- `scripts/seed/src/cleanup-demo-social.ts` — Deletes all demo shares, connections, lineages across all users
- `scripts/seed/src/seed-appstore-demo.ts` — Creates `demo@heirloomrecipebox.app` App Store review account (separate from social demo users, password: `HeirloomDemo2026!`)

Note: The cleanup script only references 6 demo users (missing `demo_bigshare`).

---

## Refactor Safety Rules

### Critical: DemoSocialBehaviorService writes raw Firestore documents

The service does NOT use `ConnectionService`, `FirebaseShareService`, or any notification service to create data. It writes directly to Firestore with hardcoded document schemas. This means:

- **If you change the Connection document schema**, update `DemoSocialBehaviorService` lines 517-543 (connection doc creation) AND lines 350-375 (auto-accept status update)
- **If you change the Share document schema**, update lines 564-623 (welcome shares) AND the recipe share creation flow
- **If you change the Notification document schema**, update ALL notification creation calls (6 different notification types created across the service)
- **If you change the Lineage document schema**, update the share acceptance flow (Flow 5)
- **If you add new Firestore collections to user data**, update `ScreenRecordingResetService` to include them in the reset batch operations

### Critical: Security rule exceptions

The 5 `isDemoUser()` exceptions in `firestore.rules` are load-bearing. If you:
- Rename collections → demo writes will be denied
- Add new required fields in security rules → demo document creation will fail
- Remove the `isDemoUser()` function → all demo social features break silently

### Critical: Hardcoded data

- 7 demo user IDs in `DemoSocialBehaviorService.demoUserIds`
- 7 welcome recipe UUIDs, titles, metadata, image URLs (lines 151-237)
- 7 avatar URLs following pattern `seed/demo/{userId}-avatar.webp`
- Heritage chain for Traveling Bolognese with specific user ordering
- 8 recipe modification themes with specific ingredients

### Task scheduling fragility

All delays use `Task.sleep(nanoseconds:)` on `@MainActor`. Tasks are stored in `scheduledTasks: [String: Task]` with keys like `"autoAccept_{connectionId}"`. If the app is backgrounded or the view hierarchy changes, these tasks may be cancelled or fail to execute. The service does not persist pending operations.

### Testing the demo system

Run these tests before any refactor touching social features:
```
HeirloomTestsV2/Unit/DemoSocial/DemoSocialBehaviorServiceTests.swift  (40 tests)
HeirloomTestsV2/Unit/DemoSocial/DemoSocialGateTests.swift             (14 tests)
```

### Checklist: Before merging any social feature refactor

- [ ] All 54 demo tests pass
- [ ] `isDemoUser()` function still exists in `firestore.rules`
- [ ] All 5 demo rule exceptions still present
- [ ] `DemoSocialBehaviorService.demoUserIds` still has all 7 users
- [ ] Connection document fields match what `ConnectionService` expects
- [ ] Share document fields match what `FirebaseShareService` expects
- [ ] `ScreenRecordingResetService` covers all user data collections
- [ ] Demo avatars still accessible at `seed/demo/` Storage path
- [ ] Manual test: fresh TestFlight install → friend request appears within 5s → accept → recipe shared within 15s
