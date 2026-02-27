# Heirloom — Claude Code Project Rules

## What This Is

Heirloom is an iOS recipe app (Swift/SwiftUI) with a Firebase backend. Users import recipes from photos, PDFs, URLs, and cooking videos. The app features CRDT-based sync, heritage recipe sharing (lineage tracking), AI-powered extraction, and an ASMR silent-video pipeline.

## Architecture at a Glance

```
Heirloom/                    # Main iOS app target
  App/                       # HeirloomApp entry point, RootView
  Core/
    Models/                  # SwiftData @Model classes (SchemaV3 registers 27; 6 more @Model classes exist but are NOT in schema)
    Models/CRDT/             # VectorClock, RecipeOperation, OperationLog, RecipeCRDT (all unregistered in SchemaV3)
    DI/                      # ServiceContainer, ServiceRegistration
    FeatureManagement/       # Feature flags, Firebase Remote Config
    Services/
      AI/                    # AI pipeline (Claude/OpenAI via Firebase gateway)
      Analytics/             # Mixpanel analytics
      CRDT/                  # CRDTMergeEngine
      DeepLink/              # URL routing, universal links
      Discovery/             # Public recipe feed
      Firebase/              # Auth, sync, Firestore, Storage
      Social/                # Sharing, lineage, notifications, badges
      Store/                 # IAP, subscriptions, credits (RevenueCat + StoreKit direct)
                               # ⚠️ CreditStoreManager.purchaseViaRevenueCat() is a STUB — returns .failed(.notImplemented)
                               # Credit packs use StoreKit direct (intentional). Subscriptions use RevenueCat.
      Storage/               # ImageStorageService, ImageCache
      Themes/                # Heritage theme system, daily unlocks
      Video/                 # Standard + ASMR video pipelines
  Features/                  # Feature modules (Auth, Recipes, Onboarding, Settings, etc.)
HeirloomTestsV2/             # Unit/integration tests
HeirloomVideoLab/            # Standalone video pipeline dev/test app
HeirloomShareExtension/      # Share extension target
functions/                   # Firebase Cloud Functions (TypeScript)
```

## Critical Rules (Things Claude Code Gets Wrong)

### Large File Warning
- `ImportJobManager.swift` (3,497 lines) at `Features/Recipes/BulkImport/Services/` is the largest file in the codebase. It combines queue management, batch processing, retry logic, error handling, and UI state. Read it completely before extracting or refactoring any job queue logic.

### Data Model Gotchas
- `Recipe.servings` is `String?`, NOT `Int`
- `Recipe.linkedProcessingJobId` — NOT `importJobId`
- `Recipe.createVideoProcessingPlaceholder(jobId:)` — NOT `createVideoPlaceholder()`
- `ImportJob` init: `ImportJob(jobName:continueOnError:)` — NOT `init(jobType:cookbookName:)`
- `ImportItem` init: `ImportItem(urlString:)` or `ImportItem(source:imageData:...)`
- `ImportJob` status: `.pending`, `.processing`, `.paused`, `.completed`, `.failed`
- `ImportItem` status: `.pending`, `.processing`, `.success`, `.failed`, `.skipped`

### Unregistered @Model Classes (Crash Risk)
- 6 `@Model` classes are NOT registered in `SchemaV3.models`: `VectorClock`, `RecipeOperation`, `OperationLog`, `RecipeCRDT`, `Customization`, `StickerAsset`
- Accessing these via `ModelContext` will crash unless the schema is configured to include them
- They must be added to `SchemaV3` OR given explicit test exclusions

### SwiftData & Module Boundaries
- `@Model` macro-generated conformances are NOT visible across module boundaries
- This is the single biggest SPM modularization risk — affects every package that uses `@Model` types from another package
- **Strategy:** ALL `@Model` types must live in `HeirloomModels` package. Never split `@Model` types across packages. Every package that needs models imports `HeirloomModels`.
- Test targets cannot see synthesized protocol conformances from the main app target
- Solution: exclude problematic models from test schema OR use mock/wrapper types
- Example: `RecipeGenerationJob` is excluded from `TestEnvironment` schema

### Swift 6 Concurrency
- Mock `ObservableObject` classes need: `nonisolated(unsafe) let objectWillChange = ObservableObjectPublisher()`
- `FirebaseAuthService` is `@MainActor` isolated
- `ImageStorageService` is an `actor`

### ServiceContainer
- `ServiceContainer.shared` is the global DI singleton
- Many services internally call `ServiceContainer.shared.resolve()` — register dependencies in test setup
- Known chains: `JobCleanupService` → `ImageStorageService` → `ImageCache`

### TestEnvironment
- Use `env.modelContext` — NOT `env.context`
- Helpers: `createTestRecipe()`, `createVideoProcessingJob()`, `createImportJob()`, etc.
- Always `ServiceContainer.shared.reset()` in `tearDown`

## Persistence Stack

- **Local:** SwiftData (SQLite), SchemaV3, no CloudKit (`cloudKitDatabase: .none`)
- **Migration plan is DISABLED** — `ModelContainer` is created without `migrationPlan:` (HeirloomApp.swift:281-283). SchemaV3 + migration chain exist in code but are not wired up. Do not assume migrations run. Needs re-enablement with testing on a device that has a V1/V2 database.
- **Remote:** Firestore (document DB) + Firebase Storage (images)
- **Sync:** Manual bidirectional via `FirebaseSyncService` (5-min timer + foreground trigger)
- **Conflict resolution:** Last-write-wins (basic) or CRDT operation-log merge (`usesCRDT = true`)
- **Caching:** 50MB in-memory `NSCache` for images, 100MB Firestore persistent disk cache

## Auth

Firebase Auth only. Three providers: Sign in with Apple (primary), Google, Email/Password. No anonymous auth. Mandatory sign-in.

## AI Pipeline

All AI calls route through Firebase Cloud Functions (`FirebaseAIGatewayService`). API keys server-side only. Primary: Anthropic Claude. Fallback: OpenAI. On-device: WhisperKit (transcription only).
- `dalleGenerateImage` and `replicateGenerateImage` exist in `functions/src/image-generation.ts` and are exported from `index.ts`. They use auth, App Check, rate limiting, and structured error handling. Ensure `OPENAI_KEY` and `REPLICATE_API_TOKEN` env vars are set in the Cloud Functions runtime.

## Bundle IDs

- Main target: `com.rationaledesign.heirloom`
- Share extension: `com.rationaledesign.heirloom.HeirloomShareExtension`
- App Group: `group.com.rationaledesign.heirloom`
- ⚠️ No CloudKit entitlement (removed)
- ⚠️ Legacy docs reference `com.matthanson.heirloom` and `com.rationalestudio.heirloom` — both are WRONG. Trust entitlements files, not docs.

## Build & Test

- Xcode project: `Heirloom.xcodeproj`
- Test target: `HeirloomTestsV2`
- Config: `Config.xcconfig` (copy from `Config.xcconfig.example`)
- ⚠️ `REVENUECAT_API_KEY` in xcconfig is DEAD — `HeirloomApp.swift:233,242` hardcodes different keys via `#if DEBUG`. The xcconfig value is never read. Consolidate in Phase 14.
- `isRunningTests` flag in `HeirloomApp.init` skips Firebase in test environment
- GitHub: `https://github.com/RationaleDesignHanson/Heirloom`
- Firebase project: `heirloom-ios-prod`

## Module CLAUDE.md Files

⚠️ **None of the module-specific CLAUDE.md files listed below exist yet.** They will be written fresh during their respective refactoring phases. These are planned locations:

### Core (planned)
- `Heirloom/Core/Models/CLAUDE.md` — Data models, schema, CRDT types
- `Heirloom/Core/Services/AI/CLAUDE.md` — AI service layer, prompts, model selection
- `Heirloom/Core/Services/Firebase/CLAUDE.md` — Auth, sync, Firestore structure
- `Heirloom/Core/Services/Video/CLAUDE.md` — Video pipelines (standard + ASMR 5-pass)
- `Heirloom/Core/Services/Store/CLAUDE.md` — Subscriptions, IAP, RevenueCat, credits
- `Heirloom/Core/Services/Themes/CLAUDE.md` — Heritage theme system, daily unlocks
- `Heirloom/Core/Services/Analytics/CLAUDE.md` — Mixpanel analytics events
- `Heirloom/Core/Services/DeepLink/CLAUDE.md` — URL routing, universal links
- `Heirloom/Core/Services/Discovery/CLAUDE.md` — Public recipe feed
- `Heirloom/Core/Services/Social/CLAUDE.md` — Sharing, lineage, notifications
- `Heirloom/Core/FeatureManagement/CLAUDE.md` — Feature flags, Remote Config

### Features & Extensions (planned)
- `Heirloom/Features/Onboarding/CLAUDE.md` — 6-screen onboarding flow
- `HeirloomShareExtension/CLAUDE.md` — Share extension architecture
- `HeirloomTestsV2/CLAUDE.md` — Test infrastructure, mocks, patterns

### Appendix
- `~/Desktop/heirloom-appendix.md` — Known bugs, design system, privacy/GDPR, performance, deployment, Firestore collections
