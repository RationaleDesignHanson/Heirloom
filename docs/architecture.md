# Heirloom Technical Architecture

> A technical architecture overview for investors performing due diligence and engineers onboarding to the codebase.

---

## 1. System Overview

Heirloom is a native iOS application built with Swift and SwiftUI, backed by a Firebase cloud infrastructure and a multi-provider AI pipeline. The system is designed around three core principles: **offline-first data ownership**, **intelligent recipe understanding**, and **multi-generational recipe provenance**.

### Technology Stack

| Layer | Technology |
|-------|-----------|
| Client | Swift 5.9+, SwiftUI, SwiftData |
| Backend | Firebase (Firestore, Auth, Storage, Cloud Functions) |
| AI | Anthropic Claude, OpenAI GPT (via Firebase gateway) |
| On-device ML | WhisperKit (OpenAI Whisper, runs locally) |
| Search | Algolia |
| Subscriptions | RevenueCat |
| Image Generation | Replicate (Flux 1.1 Pro) |
| Analytics | Plausible (privacy-friendly, marketing site) |

### Architecture Diagram

```
iOS App (Swift/SwiftUI)
  |
  +-- SwiftData (local persistence, offline-first)
  |
  +-- Firebase Auth (identity)
  |
  +-- Firestore (sync, real-time collaboration)
  |     |
  |     +-- CRDT Merge Engine (conflict resolution)
  |     +-- Recipe Lineage (multi-generational tracking)
  |
  +-- Firebase Cloud Functions (AI gateway)
  |     |
  |     +-- Anthropic API (Claude models)
  |     +-- OpenAI API (GPT models)
  |     +-- Google Vision API (handwriting OCR)
  |     +-- Brave Search API (web recipe search)
  |
  +-- WhisperKit (on-device transcription, no network)
```

All AI requests are proxied through Firebase Cloud Functions. No third-party API keys are stored on the client device.

---

## 2. AI Pipeline Architecture

The AI system uses a task-based model selection strategy that optimizes for cost, latency, and quality. Each AI task is routed to the appropriate model based on its complexity requirements.

### Model Selection

Model routing is defined in `AIConfiguration.model(for:)`:

**Source:** `Heirloom/Core/Services/AI/Configuration/AIConfiguration.swift`, lines 262-288

| Task | Anthropic (Primary) | OpenAI (Fallback) |
|------|--------------------|--------------------|
| Parsing / Categorization | Claude 3 Haiku (`claude-3-haiku-20240307`) | GPT-4o Mini (`gpt-4o-mini`) |
| PDF Vision / Enhancement | Claude Sonnet 4.5 (`claude-sonnet-4-5-20250929`) | GPT-4o (`gpt-4o`) |
| Video Vision / Enhancement | Claude Sonnet 4 (`claude-sonnet-4-20250514`) | GPT-4o (`gpt-4o`) |
| General Vision / Enhancement | Claude Sonnet 4.5 (`claude-sonnet-4-5-20250929`) | GPT-4o (`gpt-4o`) |

This tiered approach routes cheap, high-volume tasks (parsing, categorization) to faster and less expensive models, while reserving more capable models for vision-heavy and creative work.

### Task Types

The `AITask` enum defines eight distinct task types, enabling independent model control per input source:

**Source:** `Heirloom/Core/Services/AI/Configuration/AIConfiguration.swift`, lines 358-369

- `parsing` -- ingredient text parsing
- `categorization` -- recipe category detection
- `enhancement` -- text-based recipe enhancement
- `vision` -- general image analysis and OCR
- `pdfVision` / `pdfEnhancement` -- PDF-specific pipelines
- `videoVision` / `videoEnhancement` -- video-specific pipelines

### Structured Output

All AI service interactions go through `AIServiceProtocol`, which provides type-safe structured output via generic methods.

**Source:** `Heirloom/Core/Services/AI/Protocols/AIServiceProtocol.swift`

- `completeStructured<T: Decodable>(prompt:schema:options:)` returns typed JSON decoded to any `Decodable` struct
- `completeWithVisionStructured<T: Decodable>(image:prompt:schema:options:useCase:)` handles image compression before sending to the AI gateway
- The `ImageUseCase` enum optimizes image preparation: `.ocr` (2048px max, 0.95 JPEG quality) for text recognition vs `.display` (1600px max, 0.85 quality) for general analysis

Image compression is iterative: JPEG quality starts at 0.9 and decreases by 0.1 per iteration until the payload is under 2MB, as implemented in `FirebaseAIGatewayService.compressImage(_:maxBytes:)`.

### ASMR Video Pipeline (5-Pass Vision Analysis)

For silent cooking videos (TikTok, Instagram reels) where there is no narration to transcribe, the system uses a multi-pass vision analysis pipeline orchestrated by `ASMRRecipeStructurer`.

**Source:** `Heirloom/Core/Services/Video/ASMR/Structuring/ASMRRecipeStructurer.swift`

| Pass | Stage | Weight | Purpose |
|------|-------|--------|---------|
| 1 | IDENTIFYING | 15% | Detect dish type from final frames |
| 2 | DETECTING | 25% | Extract visible ingredient mentions from all frames |
| 3 | INFERRING | 25% | Infer missing ingredients from visual context and dish type |
| 4 | ANALYZING | 20% | Recognize cooking techniques from cooking frames |
| 5 | VALIDATING | 15% | Cross-validate recipe consistency and synthesize final output |

Each pass feeds its results into the next, progressively building a complete recipe. The pipeline also integrates with `RecipeAugmentationService` for improving accuracy using similar recipes from the user's local library.

### Voice-to-Recipe Pipeline (3-Pass)

Voice recipe creation uses a multi-pass architecture that separates on-device transcription from cloud-based understanding:

**Pass 1 -- On-device transcription (WhisperKit):** Raw audio is transcribed entirely on-device. No audio data leaves the phone. Model selection is adaptive based on device RAM (tiny.en for < 4GB, base.en for 4-6GB, small.en for 6GB+).

**Source:** `Heirloom/Core/Services/Video/Transcription/WhisperKitTranscriptionService.swift`

**Pass 2 -- Transcript parsing (Claude Haiku, low temperature):** The raw transcript is sent to a cheap, fast model that extracts structured context into `VoiceTranscriptContext`:

**Source:** `Heirloom/Core/AI/RecipeGeneration/VoiceTranscriptContext.swift`

Fields extracted: `dishName`, `ingredients`, `cuisineHints`, `descriptions`, `techniquePreferences`, `servingSize`, `confidence`.

**Pass 3 -- Recipe generation (Claude Sonnet, higher temperature):** The structured context is sent to a more capable model that generates a complete recipe with ingredients, instructions, timing, and serving information.

This multi-pass design follows the principle established across the codebase: separate parsing (low temperature, cheap model) from creative generation (higher temperature, more capable model).

### Cost Optimization

**Source:** `Heirloom/Core/Services/AI/Configuration/AIConfiguration.swift`, lines 436-513

- **Rate limiting:** 1,000 requests/day for the shared API key; unlimited for users who provide their own key
- **Usage tracking:** `AIUsageTracker` records tokens, cost (calculated per-provider with exact pricing), and request count per session
- **Automatic key fallback:** If a personal API key fails authentication, the system automatically removes it and falls back to the shared key with a user notification
- **Daily reset:** Request counters reset automatically at the start of each calendar day

---

## 3. CRDT Merge Engine

The sync system uses Conflict-free Replicated Data Types (CRDTs) with vector clocks to enable offline editing with deterministic conflict resolution across devices.

### Vector Clock

**Source:** `Heirloom/Core/Models/CRDT/VectorClock.swift`

The `VectorClock` is a SwiftData `@Model` with `Codable` conformance. It maintains a `clocks: [String: Int64]` dictionary mapping device IDs to logical timestamps.

Core operations:
- `increment(deviceId:)` -- advances the local device's clock
- `merge(with:)` -- takes the element-wise maximum across all device entries
- `compare(with:)` -- returns `.before`, `.after`, `.concurrent`, or `.equal`

Firestore serialization handles Int-to-Int64 conversion (Firestore returns `Int`, SwiftData stores `Int64`) and Timestamp-to-Date coercion.

### Operation Log

**Source:** `Heirloom/Core/Models/CRDT/RecipeOperation.swift`

Each edit produces an immutable `RecipeOperation` record containing: `id`, `recipeId`, `deviceId`, `vectorClock`, `timestamp`, `operationType`, `fieldPath`, `oldValue`, `newValue`, and `metadata`.

Operation types cover both simple edits and array-level modifications:

```
create, update, delete,
addIngredient, addInstruction,
addCustomization, modifyCustomization, deleteCustomization, reorderCustomizations
```

Values are represented by the `OperationValue` enum: `.string`, `.int`, `.double`, `.bool`, `.stringArray`, `.jsonData`, `.null`. Each variant serializes to Firestore with explicit type tags for safe round-tripping.

### Merge Algorithm

**Source:** `Heirloom/Core/Services/CRDT/CRDTMergeEngine.swift` (515 lines)

The merge proceeds in stages:

1. **Sync check:** Compare vector clocks. If already in sync, return immediately.
2. **Log merge:** Combine operation logs from local and remote CRDTs.
3. **Conflict detection:** Identify concurrent operations on the same field path (same `fieldPath`, concurrent vector clocks).
4. **Auto-merge strategy:**
   - Both additive (e.g., two `addIngredient` operations with different values) -- keep both
   - One operation is a delete -- delete wins
   - Same value with different timestamps -- use the latest timestamp
5. **User resolution:** If auto-merge fails, present a `DetailedConflict` to the user with local vs. remote values, device names, user names, timestamps, and four resolution choices: `keepLocal`, `keepRemote`, `keepBoth`, `custom(value)`.

### Field Path Validation (SEC-8)

To prevent injection attacks through CRDT operations synced from other devices, the engine validates all field paths against a whitelist before applying any operation:

**Allowed paths:** `title`, `notes`, `prepTime`, `cookTime`, `servings`, `ingredients`, `instructions`

**Array access:** `ingredients[N]`, `instructions[N]` -- validates that `N` is a non-negative integer.

All other patterns are rejected with a security warning log. This prevents malicious field paths like `$.backdoor` from being applied to recipe objects.

---

## 4. Recipe Provenance and Lineage

### ProvenanceMetadata

**Source:** `Heirloom/Core/Models/ProvenanceMetadata.swift`

Every recipe carries an embedded `ProvenanceMetadata` struct (Codable) that tracks its origin and sharing history:

- `sourceType`: `.userCreated`, `.imported`, `.shared`, `.scanned`, `.ai`, `.video`
- `rootProvenanceHash`: SHA-256 hash (via CryptoKit) of timestamp + UUID, unique to the original recipe
- `generation`: 0 for originals, incremented on each share
- `parentShareID`, `sharedByName`: attribution chain linking back to the sharer
- `cachedMetrics`: aggregated `totalShares`, `totalCooks`, `averageRating`, `ratingCount`, `trendingScore`

### RecipeLineage

**Source:** `Heirloom/Core/Models/RecipeLineage.swift`

`RecipeLineage` is a SwiftData `@Model` that tracks the family tree of shared recipes:

- `rootRecipeId`, `parentRecipeId`, `currentRecipeId` -- the tree structure
- `rootOwnerId`, `ownerId` -- Firebase UIDs linking recipes to their creators
- `generation` -- depth in the share tree (0 = original, 1 = first share, etc.)
- `modifications` -- array of `ModificationRecord` entries tracking every change

This enables multi-generational tracking: when user A shares a recipe to B, and B shares to C, and C shares to D, the original creator (A) can see the entire descendant tree and all modifications made at every level.

### Lineage Tree Service

**Source:** `Heirloom/Core/Services/RecipeLineageService.swift`

`fetchLineageTree(for:context:maxDepth:)` queries the Firebase `lineages` collection to build a complete tree with nodes and edges, fetching contributor information (display name, avatar, connection status) for each participant in the tree.

**Source:** `Heirloom/Core/Services/Firebase/FirebaseLineageService.swift`

`FirebaseLineageService` handles lineage creation, modification tracking, and ancestor notification. When a descendant modifies a shared recipe, the service notifies all members of the heritage network -- not just direct ancestors -- so everyone sees everyone's changes.

---

## 5. Privacy Architecture

### No API Keys on Client

**Source:** `Heirloom/Core/Services/AI/Clients/FirebaseAIGatewayService.swift`

All AI requests flow through `FirebaseAIGatewayService`, which calls Firebase Cloud Functions (`aiComplete`, `aiCompleteStructured`, `aiCompleteWithVision`). The client sends only a Firebase auth token; the Cloud Functions hold all third-party API keys server-side.

The legacy `AnthropicAIService` (direct API calls) is retained in the DI container for emergency rollback but is not wired as the active `AIServiceProtocol` implementation. The swap between gateway and direct service is a single-line DI registration change.

**Source:** `Heirloom/Core/DI/ServiceRegistration.swift`, lines 493-503

Keychain storage uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, ensuring stored keys are only accessible after first device unlock and never migrate to other devices.

### On-Device Processing

**Source:** `Heirloom/Core/Services/Video/Transcription/WhisperKitTranscriptionService.swift`

WhisperKit runs OpenAI's Whisper speech recognition model entirely on-device. Audio data never leaves the phone.

- Model selection adapts to device capability: tiny.en (39MB), base.en (74MB), small.en (244MB)
- Memory check: requires minimum 2GB available RAM
- Model is preloaded at app launch in the background with shared-instance pattern to prevent duplicate downloads

### Privacy Consent

**Source:** `Heirloom/Core/Services/Privacy/PrivacyConsentService.swift`

The consent model is two-tier with independent controls:

1. **Sharing consent** -- controls whether the user can access sharing features
2. **Analytics consent** -- controls whether anonymous analytics are collected

Additional properties:
- Policy versioning: the service tracks `currentPolicyVersion` and re-prompts users when the policy updates
- Consent date tracking: records the exact date consent was granted
- GDPR/CCPA readiness: all consents are independently revocable, and `resetAllConsents()` provides a complete data rights mechanism

Custom SwiftUI property wrappers (`@SharingConsentRequired`, `@AnalyticsConsentRequired`) provide declarative consent checks in views.

---

## 6. Dependency Injection

### ServiceContainer

**Source:** `Heirloom/Core/DI/ServiceContainer.swift`

The DI system is a custom protocol-based container with the following characteristics:

- **Protocol-oriented:** Services are registered as `(any ProtocolName).self`, resolved by protocol type
- **Lifecycle management:** `.singleton` (one instance for app lifetime), `.transient` (new instance per resolution), `.scoped` (reserved for future per-session use)
- **Thread safety:** The container is `@MainActor`-isolated, with a `nonisolated` `resolveUnsafe()` escape hatch for logging infrastructure that must run from any context
- **Testing support:** `replace(_:with:)` swaps implementations at runtime; `reset()` clears all registrations

### Service Registration

**Source:** `Heirloom/Core/DI/ServiceRegistration.swift`

All production services are registered in `registerProductionServices()`. The registration file is approximately 850 lines covering 100+ services across these categories:

- Firebase services (Auth, Firestore sync, image storage, notifications, lineage, share)
- AI services (gateway, recipe extraction, ingredient parsing, spell checking, recipe generation, image generation)
- Social services (profiles, connections, badges, search)
- Recipe services (import, export, migration, versioning, scaling, duplicate detection)
- Video processing (audio extraction, transcription, frame analysis, ASMR structuring)
- Infrastructure (analytics, networking, deep linking, privacy, subscriptions)

The container supports mock registration for testing via `registerMockServices()` and preview registration for SwiftUI previews via `registerPreviewServices()`.

---

## 7. Infrastructure

### Firebase

| Service | Purpose |
|---------|---------|
| Firestore | Primary data store, real-time sync, CRDT operation logs, lineage tracking |
| Auth | User identity, anonymous-to-authenticated migration |
| Storage | Recipe images, user avatars |
| Cloud Functions | AI gateway (holds API keys), Google Vision OCR proxy, Brave Search proxy, image generation proxy, server-side rate limiting |

### Third-Party Services

| Service | Purpose |
|---------|---------|
| RevenueCat | Subscription management and entitlement verification |
| Replicate | AI image generation (Flux 1.1 Pro) for recipe photos and collection thumbnails |
| Algolia | Full-text search indexing for recipe discovery |
| Plausible | Privacy-friendly analytics for the marketing site (no cookies, no personal data) |
| Brave Search | Web recipe search (proxied through Cloud Functions) |

### Security Posture

- All third-party API keys are server-side only (Cloud Functions)
- Client authenticates via Firebase Auth tokens
- Keychain storage with device-only accessibility
- CRDT field path validation prevents injection through synced operations
- Rate limiting enforced both client-side (daily counter) and server-side (Cloud Functions)
- Privacy consent is granular, versioned, and independently revocable

---

## Appendix: Key File Reference

| System | File Path |
|--------|-----------|
| DI Container | `Heirloom/Core/DI/ServiceContainer.swift` |
| Service Registration | `Heirloom/Core/DI/ServiceRegistration.swift` |
| Service Protocols | `Heirloom/Core/DI/ServiceProtocols.swift` |
| AI Configuration | `Heirloom/Core/Services/AI/Configuration/AIConfiguration.swift` |
| AI Service Protocol | `Heirloom/Core/Services/AI/Protocols/AIServiceProtocol.swift` |
| Firebase AI Gateway | `Heirloom/Core/Services/AI/Clients/FirebaseAIGatewayService.swift` |
| Vector Clock | `Heirloom/Core/Models/CRDT/VectorClock.swift` |
| Recipe Operation | `Heirloom/Core/Models/CRDT/RecipeOperation.swift` |
| CRDT Merge Engine | `Heirloom/Core/Services/CRDT/CRDTMergeEngine.swift` |
| Provenance Metadata | `Heirloom/Core/Models/ProvenanceMetadata.swift` |
| Recipe Lineage | `Heirloom/Core/Models/RecipeLineage.swift` |
| Lineage Tree Service | `Heirloom/Core/Services/RecipeLineageService.swift` |
| Firebase Lineage Service | `Heirloom/Core/Services/Firebase/FirebaseLineageService.swift` |
| Voice Transcript Context | `Heirloom/Core/AI/RecipeGeneration/VoiceTranscriptContext.swift` |
| Recipe Generation Service | `Heirloom/Core/Services/AI/RecipeGenerationService.swift` |
| WhisperKit Transcription | `Heirloom/Core/Services/Video/Transcription/WhisperKitTranscriptionService.swift` |
| ASMR Recipe Structurer | `Heirloom/Core/Services/Video/ASMR/Structuring/ASMRRecipeStructurer.swift` |
| Video Processing Protocols | `Heirloom/Core/Services/Video/Protocols/VideoProcessingProtocols.swift` |
| Privacy Consent Service | `Heirloom/Core/Services/Privacy/PrivacyConsentService.swift` |
