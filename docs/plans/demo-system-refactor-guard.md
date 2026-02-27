# Demo System Refactor Guard Plan

## Purpose

The demo social system (7 fake users, 6 behavioral flows, ~2,600 lines) bypasses normal service layers and writes directly to Firestore. Any refactor of social features, data models, or security rules risks silently breaking it. This plan defines what must happen in each refactoring phase to keep the demo system intact.

## Problem: The Service Bypass

`DemoSocialBehaviorService` does NOT use `ConnectionService`, `FirebaseShareService`, or any notification abstraction. It constructs raw Firestore documents with hardcoded field names and writes them directly. This means service-layer refactors are invisible to the demo system — it will keep writing the old schema until someone notices the demo is broken.

## Refactor Phases and Demo Impact

### Phase: ConnectionService Refactor

**Risk: HIGH** — Demo creates connection documents directly (lines 517-543)

**Required work:**
1. Extract the connection document schema into a shared factory or DTO
2. Update `DemoSocialBehaviorService` to use the factory instead of inline dictionaries
3. OR: Route demo connection creation through `ConnectionService` itself (preferred — eliminates the bypass)
4. Verify: auto-accept flow still updates `status` to `"connected"` with correct field name
5. Verify: `isDemoConnection: true` flag is preserved in any new schema

**Test:** Accept a demo friend request → connection appears with correct display name and photo

### Phase: FirebaseShareService Refactor

**Risk: HIGH** — Demo creates share documents with 30+ fields (lines 564-623)

**Required work:**
1. Extract share document schema into a shared DTO
2. Update ALL demo share creation (welcome shares + recipe shares) to use it
3. OR: Add a `createDemoShare()` method on `FirebaseShareService` that accepts demo-specific params
4. Verify: `isDemoShare`, `isWelcomeShare`, `isDirectShare` flags preserved
5. Verify: Heritage chain fields (`heritageChain`, `heritageChainNames`) still written correctly
6. Verify: Recipe preview fields (servings, prepTime, cookTime, etc.) still included

**Test:** Complete onboarding → 2 welcome shares appear within 60s with correct recipe previews

### Phase: Notification System Refactor

**Risk: HIGH** — Demo creates 6 different notification types directly

**Notification types created by demo system:**
- `connectionRequestReceived` (proactive request)
- `connectionRequestAccepted` (auto-accept)
- `connectionSharedRecipe` (recipe share after connection)
- `welcomeRecipeShare` (welcome shares)
- `shareAccepted` (demo accepts user's share)
- `lineage_modification` (demo modifies accepted recipe)

**Required work:**
1. If centralizing notification creation, add demo-aware factory methods
2. Preserve `isDemoNotification` and `isWelcomeNotification` markers
3. Ensure deep link URLs (`heirloom://share/{shareId}`, `heirloom://connections/requests`) are still generated

**Test:** Full flow → all 6 notification types appear with correct titles and tap targets

### Phase: Lineage/Heritage Refactor

**Risk: MEDIUM** — Demo creates lineage records for share acceptance (Flow 5)

**Required work:**
1. Verify lineage document schema matches what demo writes
2. The Traveling Bolognese recipe has a specific 5-user heritage chain — verify chain order is preserved
3. If adding lineage validation rules, exempt demo user lineages

**Test:** Share recipe to `demo_grillmaster` → wait 45s → lineage modification notification appears

### Phase: Recipe/Collection Model Refactor

**Risk: MEDIUM** — `isDemoSeed: Bool` flag on Recipe and RecipeCollection

**Required work:**
1. Preserve `isDemoSeed` field in any schema migration
2. `ScreenRecordingResetService` queries for this field to preserve demo data during reset
3. If changing Recipe model fields that demo references (title, servings, prepTime, etc.), update the hardcoded welcome recipe details

**Test:** Screen recording reset → demo seed recipes survive, all other data cleared

### Phase: Firestore Security Rules Refactor

**Risk: HIGH** — 5 `isDemoUser()` exceptions are load-bearing

**Required work:**
1. Maintain `isDemoUser(userId)` function: `userId.matches('demo_.*')`
2. Keep all 5 demo exceptions:
   - `users/{userId}/recipes` + subcollections — any auth user CAN write if userId is demo
   - `shares/{shareId}` — any auth user CAN create if ownerId is demo
   - `shares/{shareId}` — recipients CAN delete if ownerId is demo
   - `users/{userId}/connections` — any auth user CAN create/update if either party is demo
   - `lineages/{lineageId}` — any auth user CAN CRUD if ownerId is demo
3. If adding new required fields to rules (`request.resource.data.keys().hasAll([...])`) — the demo system's document creation must include those fields

**Test:** Deploy rules → open TestFlight build → demo friend request arrives → no permission errors in Functions logs

### Phase: Firebase Storage Refactor

**Risk: LOW** — Demo avatars at `seed/demo/{userId}-avatar.webp`, recipe images at `seed/demo/{userId}_{recipe}-image.webp`

**Required work:**
1. Don't delete or restructure the `seed/demo/` Storage folder
2. If changing image URL resolution logic, verify demo photo URLs still resolve

### Phase: Algolia/Search Refactor

**Risk: LOW** — Demo users indexed with `isDemoSeed` field

**Required work:**
1. Preserve `isDemoSeed` field in Algolia user index
2. `UserSearchResult.shouldShowDemoBadge` reads this field
3. If removing Algolia, demo badge logic needs an alternative data source

## The Nuclear Option: Route Everything Through Services

The cleanest refactor would eliminate the Firestore bypass entirely:

1. Add `DemoSocialBehaviorService` methods that call through `ConnectionService`, `FirebaseShareService`, and a notification service instead of writing raw documents
2. Those services already handle schema details, validation, and Firestore writes
3. Demo-specific fields (`isDemoConnection`, `isDemoShare`, etc.) would be passed as parameters
4. This eliminates ALL schema drift risk at the cost of coupling demo behavior to service internals

**Estimated scope:** Rewrite ~400 lines of direct Firestore calls in `DemoSocialBehaviorService` to use service methods instead. Requires each service to accept demo-specific flags.

**Trade-off:** The current bypass exists because the demo system was written before the services were stable. Now that services are mature, routing through them is safer. But it adds demo-awareness to services that are otherwise clean of demo concerns.

## ScreenRecordingResetService Maintenance

Every time you add a new Firestore collection to user data, add it to the reset service's batch delete list. Current collections cleared:

- `users/{userId}/recipes`
- `users/{userId}/collections`
- `users/{userId}/connections`
- `users/{userId}/notifications`
- `users/{userId}/lineages`
- `users/{userId}/recipeShares`
- `users/{userId}/recipeVersions`
- `users/{userId}/restyleJobs`
- `users/{userId}/credits`
- `users/{userId}/themeState`
- `users/{userId}/settings`
- `users/{userId}/tags`
- `users/{userId}/shoppingCart`
- `users/{userId}/dinnerParties`
- Top-level `shares` where user is owner or recipient
- Top-level `lineages` where user is owner

If you add `users/{userId}/kitchenTables` or similar, add it to the reset.

## Cleanup Script Gap

`scripts/seed/src/cleanup-demo-social.ts` only lists 6 demo users — it's missing `demo_bigshare`. Fix this if running the cleanup script.

## Pre-Merge Checklist

Before merging ANY PR that touches social features:

- [ ] 40 `DemoSocialBehaviorServiceTests` pass
- [ ] 14 `DemoSocialGateTests` pass
- [ ] `isDemoUser()` exists in `firestore.rules` with `demo_.*` pattern
- [ ] All 5 demo security rule exceptions present
- [ ] `DemoSocialBehaviorService.demoUserIds` still has 7 users
- [ ] Connection doc fields match `ConnectionService` expectations
- [ ] Share doc fields match `FirebaseShareService` expectations
- [ ] `ScreenRecordingResetService` covers all user data collections
- [ ] Manual TestFlight test: install → onboarding → friend request within 5s → accept → recipe shared within 15s → welcome shares arrive within 60s
