# Heirloom: Technical Moat Analysis

**Purpose:** This document answers the question "What stops someone from copying this?" for technical due diligence. Every claim below references auditable source files in the codebase. Line counts and implementation details are verified against the current build.

---

## 1. CRDT-Based Recipe Sync Engine

**What it is:** A full conflict-free replicated data type (CRDT) implementation enabling offline-first, multi-device recipe editing with automatic and user-assisted conflict resolution. The system uses vector clocks for causal ordering, append-only operation logs, a 3-stage merge strategy (auto-merge, auto-resolve, user resolution), and field-path security validation (SEC-8 allowlist preventing injection attacks through CRDT operations).

**Why it is hard to build:** CRDTs are a distributed systems primitive typically found in databases (Riak, Redis CRDT, Automerge) -- not consumer mobile apps. A correct implementation requires:

- Vector clock comparison across all four causal states (before, after, concurrent, equal)
- Concurrent edit detection and merge across heterogeneous operation types (additive operations like `addIngredient` vs. destructive operations like `delete`)
- Auto-merge rules: both-add-to-array merges both values, delete-vs-noop uses delete, same-value-different-timestamp uses latest
- User-facing conflict resolution UI with device names, user names, timestamps, and per-field keep-local/keep-remote/keep-both/custom-value choices
- Firestore serialization handling type mismatches (Firestore returns `Int`, Swift expects `Int64`; Firestore returns `Timestamp`, model expects `Date`)
- Field-path validation preventing untrusted CRDT operations from writing to arbitrary model fields

**Implementation size:** 1,802 lines across 5 files:

| File | Lines | Role |
|------|-------|------|
| `VectorClock.swift` | 196 | Causal ordering, clock comparison, Firestore serialization |
| `CRDTMergeEngine.swift` | 514 | 3-stage merge, conflict detection, auto-resolution strategies |
| `RecipeOperation.swift` | 467 | Operation model with types, field paths, values, metadata |
| `RecipeCRDT.swift` | 348 | CRDT wrapper linking recipe model to operation log |
| `OperationLog.swift` | 277 | Append-only log with vector clock integration |

**Estimated replication time:** 4-6 months for a senior distributed systems engineer, including edge case handling and Firestore integration.

**Competitive position:** Paprika uses local-only storage with manual iCloud sync (no multi-device editing). ReciMe uses cloud-first last-write-wins (silent data loss on conflict). Neither has offline-first editing with conflict resolution.

---

## 2. SHA256 Provenance Hashing and Recipe Lineage

**What it is:** Every recipe receives a cryptographic root hash generated via SHA256 (CryptoKit). The hash is computed from a timestamp and UUID, making it unforgeable. When a recipe is shared, the recipient's copy inherits the same `rootProvenanceHash` with an incremented generation counter (0 = original, 1 = first share, 2+ = re-shares). This creates an immutable attribution chain. Aggregated metrics (total shares, total cooks, average rating, rating count, trending score) are computed across the entire family tree via CloudKit.

**Why it is hard to build:** The provenance system must work without a central authority, across offline devices, with correct generation tracking through re-shares. Specific challenges:

- Hash generation must be deterministic per-recipe but unpredictable (SHA256 of timestamp + UUID)
- The lineage tree must be efficiently queryable from Firebase/CloudKit (all recipes sharing a `rootProvenanceHash`)
- Aggregated metrics must be computed across the full tree, not just direct children
- Trending score calculation (`trendingScore > 10.0 && totalShares > 5`) requires cross-user aggregation
- Six distinct source types (userCreated, imported, shared, scanned, ai, video) each with different attribution display logic

**Implementation size:** 314 lines in `ProvenanceMetadata.swift`, plus 248 lines in `RecipeLineage.swift` and 340 lines in `RecipeLineageService.swift` (902 lines total).

**Estimated replication time:** 2-3 months.

**Competitive position:** No recipe app tracks provenance. ReciMe has basic social sharing but no attribution chain. Paprika has no sharing functionality.

---

## 3. On-Device Audio Transcription (WhisperKit)

**What it is:** OpenAI's Whisper model runs entirely on-device via Apple's WhisperKit framework. No audio data ever leaves the phone. The service implements adaptive model selection based on device physical memory:

| Memory | Model | Size | Quality |
|--------|-------|------|---------|
| >= 6 GB | small.en | 244 MB | High accuracy |
| >= 4 GB | base.en | 74 MB | Balanced |
| < 4 GB | tiny.en | 39 MB | Fast, lower accuracy |

The model is lazy-loaded as a singleton with a shared-instance pattern that prevents duplicate downloads even under concurrent initialization. A pre-load hook at app launch downloads the model before the user needs it.

**Why it is hard to build:** On-device ML inference requires careful memory management (the service checks for a minimum of 2 GB available memory before transcription), model selection based on runtime device capabilities, graceful degradation when resources are insufficient, and integration with a downstream 2-pass recipe generation pipeline (transcription feeds into context extraction, which feeds into structured recipe generation). The service also includes forward-looking architecture for iOS 26 SpeechAnalyzer as a future drop-in replacement with automatic fallback.

**Implementation size:** 350 lines in `WhisperKitTranscriptionService.swift` (includes `WhisperKitTranscriptionService`, `SpeechAnalyzerTranscriptionService`, `AdaptiveTranscriptionService`, and `ProgressiveTranscriptionService`).

**Estimated replication time:** 2-3 months including model optimization and pipeline integration.

**Competitive position:** ReciMe uses server-side transcription (audio uploaded to cloud -- privacy concern). Paprika has no voice features. No consumer recipe app offers fully on-device voice-to-recipe capture.

---

## 4. Multi-Pass AI Pipeline with Cost Tiering

**What it is:** Task-specific model selection across 8 AI task types (`parsing`, `categorization`, `enhancement`, `vision`, `pdfVision`, `pdfEnhancement`, `videoVision`, `videoEnhancement`). Low-cost tasks (ingredient parsing, categorization) route to Claude Haiku ($0.25/1M tokens) or GPT-4o-mini ($0.15/1M tokens). Vision and enhancement tasks route to Claude Sonnet 4.5 ($3/1M tokens) or GPT-4o ($2.50/1M tokens). The ASMR video pipeline runs a 5-pass extraction with dedicated processing phases:

| Pass | Name | Function | Progress Weight |
|------|------|----------|----------------|
| 0 | Identifying | Dish identification from final frames | 15% |
| 1 | Detecting | Visible ingredient detection | 25% |
| 2 | Inferring | Culinary inference (seasonings, techniques) | 25% |
| 3 | Analyzing | Cooking action recognition | 20% |
| 4 | Validating | Synthesis and validation | 15% |

The system includes dual-provider fallback (Anthropic primary, OpenAI secondary), structured JSON output with Decodable schema validation, iterative image compression for API size limits, progress interpolation across multi-pass pipelines, per-request cost tracking, and daily rate limiting for shared API keys.

**Why it is hard to build:** Each pass requires distinct prompt engineering. The ASMR pipeline alone (2,549 lines across 7 files) handles frame extraction, sound analysis, ingredient deduplication, and multi-pass recipe structuring with 1,052 lines in `ASMRRecipeStructurer.swift`. The voice pipeline adds a 2-pass flow (transcribe on-device, then generate via AI). Error recovery must handle partial failures mid-pipeline. Cost tracking must work across both providers with different pricing models.

**Implementation size:**

| Component | Lines | Files |
|-----------|-------|-------|
| AI Configuration + Cost Tracking | 513 | `AIConfiguration.swift` |
| AI Service Protocol | 152 | `AIServiceProtocol.swift` |
| Firebase AI Gateway | 271 | `FirebaseAIGatewayService.swift` |
| ASMR Pipeline | 2,549 | 7 files in `ASMR/` |
| Voice Pipeline | 36 | `VoiceTranscriptContext.swift` |

**Estimated replication time:** 3-4 months for the full pipeline. The ASMR video processing alone is roughly 2 months of work.

**Competitive position:** ReciMe has basic AI-assisted import but no multi-pass extraction, no cost tiering, no provider fallback. Paprika has no AI capabilities.

---

## 5. Privacy-First Architecture (Firebase Gateway)

**What it is:** Zero API keys are stored in the client binary. All AI requests are proxied through Firebase Cloud Functions (`aiComplete`, `aiCompleteStructured`, `aiCompleteWithVision`). The client authenticates with a Firebase Auth token; the Cloud Function holds Claude, OpenAI, and Google Vision keys server-side. Users can optionally provide personal API keys, which are stored in iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (the most restrictive accessibility level that still allows background use). If a personal key returns an unauthorized error, the system automatically removes it, falls back to the shared key, and notifies the user via toast. Privacy consent is two-tier: sharing consent and analytics consent are independently grantable and revocable, with consent versioning for policy updates.

**Why it is hard to build:** This architecture requires Firebase Cloud Function implementations mirroring every AI service endpoint, an authentication flow that distinguishes auth failures from API failures at the Cloud Function error code level (`FunctionsErrorCode.unauthenticated`, `.resourceExhausted`, `.invalidArgument`), Keychain integration with proper Security framework attributes, iterative image compression before upload (resize to 2048px max dimension, then JPEG quality reduction from 0.9 down to 0.1 until under 2 MB), consent versioning that triggers re-consent dialogs on policy updates, and the engineering discipline to never embed keys in `Info.plist` placeholders.

**Implementation size:** 271 lines in `FirebaseAIGatewayService.swift`, 513 lines in `AIConfiguration.swift` (includes `Keychain` class), 320 lines in `PrivacyConsentService.swift` (1,104 lines total).

**Estimated replication time:** 1-2 months.

**Competitive position:** Most recipe apps embed API keys in the client binary or require cloud-based processing with no privacy controls. Heirloom's architecture routes AI through a secure proxy while keeping transcription on-device and consent granular -- this is privacy-by-architecture, not privacy-as-marketing.

---

## 6. Intelligent Cost Analysis (Pre-Processing Estimation)

**What it is:** Before processing any video import, the system estimates the credit cost and displays it to the user. The `VideoCostAnalyzer` runs a 3-tier analysis:

1. **Tier 1 -- Audio Analysis:** Checks if the video has usable speech audio. If yes, regular mode (1 credit).
2. **Tier 2 -- On-Screen Text Detection:** If audio is insufficient, checks for on-screen recipe text via OCR. If found, regular mode (1 credit).
3. **Tier 3 -- ASMR Fallback:** If neither audio nor OCR yields recipe content, the system requires full ASMR vision analysis (5 credits).

The user sees the cost estimate, the reasoning behind it, and the extraction mode before any credits are spent. If processing fails, credits are automatically refunded.

**Why it is hard to build:** The analyzer must run audio signal analysis and frame-based text detection efficiently before the actual import begins -- these are non-trivial operations that must complete quickly enough to feel like a loading screen, not a separate processing step. The UX must present the cost estimate clearly, let the user decide, and handle edge cases like analysis failure (returns 0 credits, blocks processing). PDF imports calculate cost based on page count and content type through a separate 480-line processor.

**Implementation size:** 175 lines in `VideoCostAnalyzer.swift`, plus `AudioAnalyzer` and `OnScreenTextDetector` dependencies. PDF cost analysis handled in 480 lines in `PDFProcessor.swift`.

**Estimated replication time:** 1-2 months.

**Competitive position:** ReciMe charges a flat subscription ($6.99/month) with no per-operation visibility. No competitor shows cost-per-import before processing begins. This transparency model builds user trust in the credit system.

---

## Cumulative Moat Assessment

### Total codebase investment in defensible systems

| Innovation | Lines of Code | Estimated Replication |
|------------|--------------|----------------------|
| CRDT Sync Engine | 1,802 | 4-6 months |
| Provenance Hashing + Lineage | 902 | 2-3 months |
| On-Device Transcription | 350 | 2-3 months |
| Multi-Pass AI Pipeline | ~3,521 | 3-4 months |
| Privacy-First Architecture | 1,104 | 1-2 months |
| Pre-Processing Cost Analysis | 655+ | 1-2 months |
| **Total** | **~8,334** | **13-20 months** |

### System-level integration effects

These innovations are not independent features. They compose into architectural constraints that are harder to replicate than any individual component:

- **CRDT enables offline-first editing**, which eliminates the need for an always-on connection, which reinforces the privacy architecture.
- **On-device transcription enables voice capture** without sending audio to the cloud, which is only meaningful because the privacy architecture actually enforces no-data-in-transit as a system property, not just a feature toggle.
- **Multi-pass AI enables cost tiering**, routing cheap tasks to cheap models and expensive tasks to expensive models, which makes per-operation pricing viable, which enables the pre-processing cost estimation UX.
- **Provenance hashing enables attribution** across the share chain, which makes trending scores and aggregated metrics trustworthy, which makes the social features meaningful rather than gameable.
- **Pre-processing estimation creates transparency** in the credit system, which requires the 3-tier analysis pipeline to exist, which in turn depends on the on-device audio analysis and OCR capabilities.

### The architectural gap

A competitor building a recipe app today would likely start with a cloud-first architecture, server-side AI processing, and last-write-wins sync. Bolting on any one of these innovations after the fact requires architectural changes that cascade through the system. Adding CRDTs to a cloud-first app means rethinking the data model. Adding on-device transcription to a server-side pipeline means rethinking the privacy model. Adding cost tiering to a flat-subscription model means rethinking the business model.

The defensibility is not in any single feature -- it is in the fact that these six systems were designed together from the start, creating a product architecture that is fundamentally different from "recipe app + AI bolt-on."
