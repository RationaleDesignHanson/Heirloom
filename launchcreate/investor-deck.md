# Heirloom Recipe Box — Investor Pitch Deck
### Rationale Studio | Seed Round | 2026

---

## Slide 1: Cover

**Content:**

> **Heirloom**
> Your family's recipe box, finally.
>
> *The AI-powered recipe platform that captures, preserves, and shares family food culture — from any source, on any device, with immutable provenance.*
>
> Rationale Studio | Seed Round | 2026

**Speaker Notes:**

Thank you for your time today. I am the founder of Rationale Studio, and I built Heirloom — an iOS app that solves a problem almost every family has experienced but no one has built a real product around: the permanent loss of family recipes. Not bookmarks from the internet. The handwritten cards, the verbal instructions at Thanksgiving, the TikTok video your daughter texted you at 11pm. The recipes that actually matter.

Heirloom is in production on the App Store today. I designed, engineered, and shipped the entire product — native Swift app, CRDT sync engine, multi-pass AI pipeline, on-device transcription, marketing site — as a solo founder. What I am raising for is not to prove the product works. It works. I am raising to reach the people who need it.

**Visual Direction:**

- Full-bleed hero image: warm kitchen scene with a grandmother and grandchild cooking together, overlaid with a translucent Heirloom app screenshot showing a recipe card
- Heirloom wordmark in serif font, centered
- Tagline below in lighter weight
- Minimal, warm color palette (cream, terracotta, sage green)
- Small Rationale Studio logo bottom-left

**Key Data Points:**

- Production app: live on App Store
- Solo founder: entire stack shipped by one person
- Seed round: 2026

---

## Slide 2: The Problem

**Content:**

> ### 73% of family recipes are lost within one generation.
>
> **The recipe landscape is fractured:**
> - Handwritten cards fade, get lost in moves, destroyed in disasters
> - Verbal traditions die with their keepers — no recording, no transcription
> - Digital recipes scattered across 8+ apps: screenshots, bookmarks, Pinterest boards, TikTok saves, iMessage threads, email forwards
> - Cooking videos (TikTok, Instagram Reels, YouTube Shorts) contain recipes with zero text — no way to extract and save
> - No single product captures from *all* sources into one organized, searchable, shareable collection
>
> **The cost is permanent.**
> When a recipe is lost, it is lost forever. There is no backup. There is no search engine for your grandmother's handwriting.

**Speaker Notes:**

Let me frame the scale of this problem. A 2019 study found that 73% of family recipes are lost within a single generation. Not because people do not care — because the tools do not exist. Your grandmother's lasagna recipe is on an index card in a drawer. Your mom's soup is in her head. Your daughter's favorite pasta is in a TikTok she saved six months ago and cannot find.

Today, the average home cook has recipes scattered across eight or more surfaces: screenshots, browser bookmarks, Pinterest boards, Instagram saves, iMessage threads, email, handwritten cards, and their own memory. No product unifies these. The apps that exist handle one or two sources — Paprika does URLs, ReciMe does social video — but nothing handles the full spectrum from a grandmother dictating a recipe over the phone to a silent ASMR cooking video on TikTok.

The critical insight is that the cost of failure here is not inconvenience. It is permanent cultural loss. When a recipe keeper passes away, those recipes are gone. There is no undo button. This is the problem Heirloom solves.

**Visual Direction:**

- Split layout: left side shows the "73%" statistic in large, bold typography
- Right side shows a visual grid of fragmented recipe sources: a faded handwritten card, a screenshot of a TikTok, a browser bookmark folder, a text message with a recipe, a Pinterest board — all slightly faded/torn to convey fragmentation
- Bottom: timeline graphic showing "Recipe Created" → "Recipe Keeper Ages" → "Recipe Lost" with a stark red X at the end
- Muted, slightly desaturated palette to convey loss

**Key Data Points:**

- 73% of family recipes lost within one generation
- 8+ surfaces where recipes are scattered for the average home cook
- 1 billion+ cooking videos posted to TikTok/Instagram/YouTube annually
- Zero products that capture from all sources

---

## Slide 3: The Insight

**Content:**

> ### Recipes are cultural heritage treated as disposable bookmarks.
>
> Every other form of family heritage has dedicated preservation infrastructure:
>
> | Heritage Type | Preservation Tools |
> |---|---|
> | Photos | iCloud Photos, Google Photos, physical albums |
> | Documents | Scanners, cloud storage, notarization |
> | Genealogy | Ancestry.com, 23andMe, family trees |
> | Music | Spotify playlists, vinyl collections |
> | **Recipes** | **...a Notes app? A screenshot?** |
>
> Recipes are the most practiced form of cultural heritage — cooked daily, shared at every gathering, central to identity — yet they have the least dedicated tooling of any family artifact.
>
> **The opportunity is a "system of record" for family food culture.**

**Speaker Notes:**

Here is the insight that unlocked Heirloom. Look at how every other form of family heritage has purpose-built preservation infrastructure. Photos have iCloud, Google Photos, entire industries around physical albums. Genealogy has Ancestry.com, a $6 billion company. Even music playlists have dedicated tools. But recipes — the most *practiced* form of cultural heritage, the thing families actually do together every single day — have nothing. The best tool most families have is a Notes app or a screenshot folder.

This is not a feature gap. This is a category gap. The recipe management apps that exist today treat recipes as content to be bookmarked from the internet. They are content aggregators. Heirloom treats recipes as heritage to be preserved — with provenance tracking, attribution chains, generation counting, and immutable lineage. The same way a museum treats an artifact. That is a fundamentally different product philosophy, and it produces fundamentally different technical architecture.

The opportunity is to become the system of record for family food culture. Not a recipe website. Not a social cooking app. A preservation platform.

**Visual Direction:**

- Clean comparison table taking up the top two-thirds of the slide
- Each heritage type has an icon and its preservation tools listed
- The "Recipes" row is highlighted in red/orange with a conspicuous gap
- Below the table: a single line in larger type — "The opportunity is a system of record for family food culture."
- Subtle background texture of aged paper or linen

**Key Data Points:**

- Ancestry.com: $6B+ company for genealogy preservation
- iCloud Photos: 1B+ users for photo preservation
- Recipe preservation: no dedicated infrastructure at scale
- Recipes are practiced daily (vs. genealogy researched occasionally)

---

## Slide 4: The Solution

**Content:**

> ### Heirloom: Any source. Clean recipe card. Private by default.
>
> **6 ways to capture a recipe:**
>
> 1. **URL Import** — Paste any recipe link, AI extracts clean recipe (free, always)
> 2. **Video Import** — TikTok, Instagram, YouTube — audio transcription + visual extraction
> 3. **Cookbook Scan** — Point camera at a page or import a PDF, OCR + AI structuring
> 4. **Voice Dictation** — Record someone telling you a recipe, live transcription to structured card
> 5. **AI Generation** — Describe a dish, AI creates a complete recipe with ingredients and steps
> 6. **Manual Entry** — Type it yourself, always free
>
> **Every recipe becomes a structured, searchable, shareable card — with full provenance tracking.**
>
> Private by default. Share intentionally through Kitchen Table (peer-to-peer connections) or optionally through the Discover feed (public, with attribution).

**Speaker Notes:**

Heirloom captures recipes from every source a family actually uses. Six import methods, each purpose-built for a different scenario. URL import for the recipe blog your spouse texted you. Video import for the TikTok your daughter saved — including silent cooking videos where there is no speech at all, just visual cooking. Cookbook scan for the physical cookbook on your shelf or the PDF your aunt emailed. Voice dictation for when your grandmother is telling you her recipe over the phone and you need to capture it in real time. AI generation for when you know what you want but need help with proportions and technique. And manual entry for everything else.

The critical design decision is privacy. Heirloom is private by default. Your recipes are yours. Sharing is intentional and opt-in through two channels: Kitchen Table, which is our peer-to-peer connection system for family and friends, and the Discover feed, which is optional public sharing with full attribution. This is the opposite of social-first apps like ReciMe, where everything is public and the feed is the product. In Heirloom, *your collection* is the product.

Every recipe, regardless of source, gets full provenance metadata: where it came from, who shared it, what generation copy it is, and a SHA256 hash linking it back to the original. This is immutable recipe lineage — the same concept as provenance tracking in art or version control in software.

**Visual Direction:**

- Six-panel grid, each panel showing one import method with an icon, label, and a small screenshot/mockup
- Panel 1: URL link icon with a recipe card emerging from a web page
- Panel 2: Video play button with TikTok/Instagram logos and a recipe card emerging
- Panel 3: Camera viewfinder over a cookbook page
- Panel 4: Microphone with sound waves transforming into text
- Panel 5: Sparkle/AI icon with a dish description becoming a recipe
- Panel 6: Pencil/keyboard icon for manual entry
- Below: a simple flow diagram showing "Any Source → AI Pipeline → Structured Card → Your Private Collection"
- Warm, inviting color palette

**Key Data Points:**

- 6 import methods (most competitors offer 1-2)
- Private by default (vs. social-first competitors)
- SHA256 provenance hashing on every recipe
- Kitchen Table for peer-to-peer sharing
- Discover feed for optional public sharing with attribution

---

## Slide 5: Product Demo — Feature Showcase

**Content:**

> ### The Product
>
> **Panel 1: Recipe Collection**
> Clean, visual recipe library. Filter by source, category, cookbook. Search across all fields. Offline-first — works without internet.
>
> **Panel 2: Video Import**
> Paste a TikTok or Instagram link. On-device audio transcription via WhisperKit. For silent/ASMR cooking videos: 5-pass visual extraction pipeline analyzes frames to reconstruct the recipe from what it *sees*.
>
> **Panel 3: Cookbook Scan**
> Point your camera at a cookbook page or import a PDF. Google Cloud Vision OCR for handwritten text. AI structures the result into a clean recipe card. Handles everything from typed pages to grandmother's cursive.
>
> **Panel 4: Voice Capture**
> Tap record. Speak a recipe — or hold the phone while someone tells you one. Live transcription via SFSpeechRecognizer. AI structures the transcript into ingredients, steps, and metadata. No other recipe app has this.
>
> **Panel 5: Kitchen Table**
> Your private sharing space. Connect with family and friends by username. Share recipes directly, peer-to-peer. See what they have shared with you. Generation tracking shows the lineage of every shared recipe.
>
> **Panel 6: Discover Feed**
> Opt-in public sharing. Browse trending, new, and popular recipes from other Heirloom users. Save to your collection with full attribution. Every save tracks provenance back to the original creator.

**Speaker Notes:**

Let me walk through the product. Panel one is the core collection view — your recipe library, organized by source, category, or cookbook. This is offline-first. The CRDT merge engine means you can edit recipes on your phone in airplane mode, your spouse can edit the same recipe on their iPad, and when both devices come online, the changes merge automatically without data loss. No other consumer recipe app has this.

Panel two is video import, which is where significant technical differentiation lives. When a user pastes a TikTok link with someone narrating a recipe, we extract the audio, transcribe it on-device using WhisperKit — that is OpenAI's Whisper model compiled for Apple Silicon — and then pass the transcript to our AI pipeline for structuring. The audio never leaves the device. Zero API cost for transcription. But the harder problem is the estimated 40% of cooking videos on TikTok and Instagram that have no speech — just music or ASMR sounds. For those, we built a 5-pass visual extraction pipeline that analyzes video frames to identify the dish, detect visible ingredients, infer hidden ingredients using culinary knowledge, recognize cooking actions, and synthesize a complete recipe. This is technically novel and extremely difficult to replicate.

Panels three through six show cookbook scanning with handwriting OCR, voice dictation — which no competitor offers — Kitchen Table peer-to-peer sharing, and the optional Discover feed for public recipe sharing with attribution tracking.

**Visual Direction:**

- 2x3 grid of iPhone mockups, each showing a different feature screen
- Each mockup has a clean label above it and a one-line description below
- Mockups should show actual app UI (or high-fidelity recreations)
- Subtle drop shadows on the phone mockups
- Background: light gradient, warm tones

**Key Data Points:**

- Offline-first with CRDT sync (unique in category)
- On-device transcription (zero API cost, audio never leaves device)
- 5-pass ASMR pipeline (technically novel)
- Voice dictation (unique in category — no competitor offers this)
- Handwriting OCR via Google Cloud Vision
- Generation tracking on shared recipes

---

## Slide 6: How It Works — AI Pipeline

**Content:**

> ### Multi-Pass AI Architecture with Cost Tiering
>
> ```
> ┌─────────────────────────────────────────────────────────┐
> │                    INPUT SOURCES                        │
> │  URL │ Video │ Cookbook Scan │ Voice │ AI Gen │ Manual   │
> └──────┬──────┬──────────────┬───────┬────────┬──────────┘
>        │      │              │       │        │
>        ▼      ▼              ▼       ▼        ▼
> ┌──────────────────────────────────────────────────────┐
> │              TIER 1: PARSING (Low Cost)              │
> │  Claude Haiku — $0.25/1M tokens — Low temperature    │
> │  Tasks: ingredient parsing, categorization, OCR      │
> │  structuring, transcript-to-recipe conversion        │
> └──────────────────────┬───────────────────────────────┘
>                        │
>           ┌────────────┼────────────┐
>           ▼            ▼            ▼
> ┌──────────────┐ ┌──────────┐ ┌────────────────────┐
> │  TIER 2:     │ │ WHISPER  │ │ TIER 2: ASMR       │
> │  VISION      │ │ ON-DEVICE│ │ 5-PASS PIPELINE     │
> │  Claude      │ │ $0 cost  │ │ Claude Sonnet 4     │
> │  Sonnet 4.5  │ │ WhisperKit│ │ 5 sequential passes│
> │  $3/1M tokens│ │ Audio    │ │ ~$0.25/extraction   │
> │              │ │ never    │ │                     │
> │  PDF vision, │ │ leaves   │ │ Identifying →       │
> │  enhancement │ │ device   │ │ Detecting →         │
> │              │ │          │ │ Inferring →         │
> │              │ │          │ │ Analyzing →         │
> │              │ │          │ │ Validating          │
> └──────────────┘ └──────────┘ └────────────────────┘
>                        │
>                        ▼
> ┌──────────────────────────────────────────────────────┐
> │              FALLBACK: OpenAI GPT-4o                 │
> │  Automatic failover if Anthropic unavailable         │
> └──────────────────────────────────────────────────────┘
>                        │
>                        ▼
> ┌──────────────────────────────────────────────────────┐
> │           FIREBASE CLOUD FUNCTIONS GATEWAY           │
> │  No API keys stored in client binary                 │
> │  Server-side rate limiting and key management        │
> └──────────────────────────────────────────────────────┘
> ```

**Speaker Notes:**

This is the AI architecture that powers every import in Heirloom. The core principle is cost tiering: use the cheapest model that can do the job, and only escalate to expensive models when the task requires it. Tier 1 is Claude Haiku at $0.25 per million tokens. This handles 80% of operations — ingredient parsing, categorization, structuring OCR output, converting voice transcripts to recipes. These are deterministic tasks that do not require creativity. Low temperature, cheap model, fast response.

Tier 2 is where it gets interesting. For PDF vision and recipe enhancement, we use Claude Sonnet 4.5 — the latest, highest-quality model — because these tasks require genuine reasoning about images and text. For video, we use Claude Sonnet 4 for frame analysis. And for audio transcription, we use WhisperKit running entirely on-device — that is OpenAI's Whisper model compiled to run on the Apple Neural Engine. Zero API cost. The audio literally never leaves the user's phone. This is a significant privacy and cost advantage.

The ASMR pipeline is the most technically complex piece. When we detect a video with no speech — just music or cooking sounds — we run five sequential AI passes over extracted video frames. Pass 1 identifies the dish from the final frames. Pass 2 detects visible ingredients across the timeline. Pass 3 infers hidden ingredients using culinary knowledge. Pass 4 recognizes cooking actions and techniques. Pass 5 synthesizes everything into a validated recipe. Each pass builds on the previous pass's findings. The entire pipeline costs approximately $0.25 per extraction. The fallback is GPT-4o if Anthropic is unavailable. And critically, no API keys are stored in the client binary — everything routes through Firebase Cloud Functions acting as a secure gateway.

**Visual Direction:**

- Architecture diagram as shown in the content, but rendered as a professional technical diagram with color-coded tiers
- Tier 1 in green (cheap/fast), Tier 2 in blue (powerful/accurate), Fallback in gray
- WhisperKit box highlighted with a "shield" icon indicating on-device privacy
- ASMR pipeline shown as a vertical sequence of 5 connected steps
- Firebase gateway shown at the bottom with a lock icon
- Clean, engineering-style diagram — not marketing fluff

**Key Data Points:**

- Tier 1: $0.25/1M tokens (Claude Haiku) — 80% of operations
- Tier 2: $3/1M tokens (Claude Sonnet 4.5/4) — vision/generation
- On-device transcription: $0 cost (WhisperKit)
- ASMR extraction: ~$0.25/extraction (5 passes)
- Fallback: GPT-4o (automatic failover)
- Zero API keys in client binary

---

## Slide 7: Technical Moat

**Content:**

> ### 4 Defensible Technical Innovations
>
> **1. CRDT Merge Engine with Vector Clocks**
> Full conflict-free replicated data type implementation for recipe sync. Offline editing on multiple devices merges automatically. Field-level conflict detection with auto-resolution rules (additive changes merge, deletions win, same-value deduplicates). User resolution UI for genuine conflicts. SEC-8 field path validation prevents injection attacks on CRDT operations. No consumer recipe app has this.
>
> **2. SHA256 Provenance Hashing (CryptoKit)**
> Every recipe carries an immutable provenance chain: source type, root hash, generation counter, parent share ID, attribution. When a recipe is shared, the recipient gets generation N+1 with a cryptographic link back to the original. This creates an auditable lineage for every recipe in the system — the "git log" of family cooking.
>
> **3. 5-Pass ASMR Visual Extraction**
> Purpose-built pipeline for extracting recipes from videos with no speech. Identifying (dish recognition) → Detecting (visible ingredients) → Inferring (culinary knowledge graph) → Analyzing (action/technique recognition) → Validating (synthesis with confidence scoring). Each pass builds on prior findings. Sound analysis pre-filter rejects unsuitable videos. Frame extraction selects keyframes across the video timeline.
>
> **4. On-Device Audio Transcription (WhisperKit)**
> OpenAI Whisper compiled for Apple Neural Engine via WhisperKit. Adaptive model selection based on device RAM (tiny.en / base.en / small.en). Audio never leaves the device. Zero API cost for transcription. Combined with cloud AI for recipe structuring.

**Speaker Notes:**

Let me talk about defensibility. There are four technical innovations in Heirloom that are individually significant and collectively form a moat that would take a well-funded competitor 12-18 months to replicate.

First, the CRDT merge engine. CRDT stands for Conflict-free Replicated Data Type. This is the same technology that powers Google Docs' real-time collaboration and Figma's multiplayer editing. I built a full CRDT implementation with vector clocks for recipe sync. What this means practically: you can edit a recipe on your phone in airplane mode, your spouse can edit the same recipe on their iPad at the same time, and when both devices reconnect, the changes merge automatically at the field level. Additive changes — like both of you adding different ingredients — merge without conflict. Genuine conflicts surface to the user with a resolution UI. And critically, I implemented SEC-8 field path validation, which prevents injection attacks on CRDT operations. This is production-grade distributed systems engineering in a consumer app.

Second, provenance hashing. Every recipe in Heirloom has a SHA256 hash generated by CryptoKit that links it to its origin. When you share a recipe, the recipient gets a generation-incremented copy with a cryptographic link back to yours. Share chains are fully auditable. This is the recipe equivalent of version control.

Third, the ASMR pipeline. An estimated 40% of cooking videos on social media have no speech. Existing apps cannot extract recipes from these videos. Heirloom can, through five sequential AI passes that identify the dish, detect and infer ingredients, recognize cooking actions, and synthesize a validated recipe. This is technically novel — I am not aware of any other consumer product doing multi-pass visual recipe extraction.

Fourth, on-device transcription. WhisperKit runs OpenAI's Whisper model directly on the Apple Neural Engine. The audio never leaves the device. This is a meaningful privacy feature and a cost structure advantage — transcription is our highest-volume AI operation, and it costs us zero.

**Visual Direction:**

- Four quadrants, each with a numbered header, icon, and brief description
- Quadrant 1 (CRDT): branching tree diagram showing two devices editing simultaneously, then merging
- Quadrant 2 (Provenance): chain of connected recipe cards with hash links, showing generation 0 → 1 → 2
- Quadrant 3 (ASMR): five-step pipeline diagram with sample frame thumbnails
- Quadrant 4 (WhisperKit): device icon with a shield, showing audio processing on-device
- Each quadrant has a "time to replicate" estimate in small text: "12-18 months combined"

**Key Data Points:**

- CRDT: field-level merge, vector clocks, SEC-8 injection prevention
- Provenance: SHA256 hashing, generation counting, attribution chains
- ASMR: 5-pass pipeline, ~$0.25/extraction, handles 40% of cooking videos competitors cannot
- WhisperKit: on-device, zero API cost, adaptive model selection by device RAM
- Estimated replication time: 12-18 months for a funded competitor

---

## Slide 8: Privacy as Product

**Content:**

> ### Architecture-Level Privacy, Not Just a Toggle
>
> | Privacy Feature | Implementation | Competitor Approach |
> |---|---|---|
> | Audio transcription | On-device via WhisperKit. Audio never leaves phone. | Cloud API (audio sent to servers) |
> | API key security | Firebase Cloud Functions gateway. Zero keys in client binary. Keychain for user-provided keys only. | Keys bundled in app binary or sent to third-party servers |
> | Recipe collection | Private by default. No public profile. No follower count. | Social-first, public by default |
> | Sharing model | Opt-in: Kitchen Table (P2P) or Discover (public). Both require explicit action. | Feed-driven, algorithmic distribution |
> | Data sync | CRDT merge — your data, your devices. No central "cloud version" that platform controls. | Server-authoritative sync (platform owns your data) |
> | Field validation | SEC-8 field path validation on CRDT operations prevents injection attacks | No CRDT, no field validation needed |
>
> **Privacy is not a feature. It is the architecture.**

**Speaker Notes:**

Privacy in Heirloom is not a settings toggle or a marketing claim. It is baked into the architecture at every layer. Let me walk through the specifics, because this matters both as a product differentiator and as a defensible technical decision.

Audio transcription runs entirely on-device through WhisperKit. When a user imports a video of their grandmother cooking, the audio from that video is processed by the Apple Neural Engine on their phone. It never touches our servers. It never touches Anthropic's servers. It never touches any server. Compare this to competitors who send audio to cloud transcription APIs — the user's private family content passes through third-party infrastructure. Heirloom's approach is fundamentally different.

API key management is handled through Firebase Cloud Functions acting as a secure gateway. The client app contains zero API keys. When a user triggers an AI operation, the request goes to our Cloud Function, which authenticates the user, applies rate limiting, and makes the API call with server-side keys. The only keys stored on-device are user-provided personal API keys, stored in iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — the most restrictive accessibility level that still allows background sync.

The sharing model is the inverse of social-first apps. ReciMe, our primary competitor, is built around a public feed. In Heirloom, your collection is private by default. There is no public profile unless you create one. No follower count. No algorithmic feed pushing your recipes to strangers. Sharing happens through Kitchen Table — direct peer-to-peer connections you explicitly establish — or through the Discover feed, which is fully opt-in. This is a deliberate product decision that resonates with our target demographic: families who want to preserve recipes privately, not perform for an audience.

**Visual Direction:**

- Comparison table as shown in content, with Heirloom column in green and Competitor column in red/gray
- Below the table: a simple architectural diagram showing data flow in Heirloom (device → Cloud Functions → AI API, with audio staying on device) vs. competitor (device → their servers → AI API, with everything flowing through their infrastructure)
- Shield icon next to "Privacy is not a feature. It is the architecture."
- Clean, professional layout — not fear-mongering, just factual comparison

**Key Data Points:**

- On-device transcription: audio never leaves phone
- Zero API keys in client binary
- Keychain storage: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- Private by default: no public profile, no follower count
- SEC-8 field path validation on all CRDT operations

---

## Slide 9: Market Opportunity

**Content:**

> ### $2.4B TAM in Recipe Management & Food Content
>
> **Total Addressable Market: $2.4B**
> 120M US households that cook at home regularly x $20/yr average digital recipe tool spend
>
> **Serviceable Addressable Market: $480M**
> 24M US households actively seeking recipe organization tools (20% of cooking households)
>
> **Serviceable Obtainable Market: $24M (Year 5)**
> 1% of SAM = 240K subscribers at $100/yr blended ARPU (mix of monthly, annual, lifetime, credits)
>
> ---
>
> **Competitive Positioning Matrix**
>
> ```
>                    HIGH Technical Depth
>                          │
>                          │  ★ HEIRLOOM
>                          │  (CRDT, AI pipeline,
>                          │   on-device ML, provenance)
>                          │
>   Private/       ────────┼──────── Social/
>   Collection-first       │        Feed-first
>                          │
>              Paprika ●   │   ● ReciMe
>              (robust     │   (social, AI video,
>               but dated) │    4.8★, ~200K ratings)
>                          │
>                    LOW Technical Depth
> ```
>
> **Heirloom occupies the only empty quadrant: private, technically deep.**

**Speaker Notes:**

The recipe management market is larger than it appears because it has been underserved by underfunded products. The total addressable market is 120 million US households that cook at home regularly, multiplied by a conservative $20 per year average spend on digital recipe tools — that gives us a $2.4 billion TAM. The serviceable addressable market narrows to 24 million households actively seeking recipe organization tools, which is $480 million. Our five-year serviceable obtainable market target is 1% of that SAM — 240,000 subscribers at a blended $100 ARPU, giving us $24 million in annual revenue.

Now look at the competitive positioning. There are two axes that matter: technical depth and privacy orientation. Paprika is the incumbent in the private/collection-first space — 4.7 stars, $4.99 one-time purchase, robust but aging UI, no AI, no video import, no sharing features. It has loyal users who want a private recipe box but are increasingly frustrated by the lack of modern features. ReciMe is the incumbent in the social/feed-first space — 4.8 stars, roughly 200,000 ratings, $6.99 per month, AI video import, strong social features. But it is fundamentally a social app, not a preservation tool.

Heirloom occupies the only empty quadrant: private and collection-first like Paprika, but with deep technical infrastructure — CRDT sync, multi-pass AI, on-device ML, provenance hashing — that neither competitor has. This is not a marginal improvement. It is a different product category.

**Visual Direction:**

- Top half: TAM/SAM/SOM funnel with concentric circles and dollar amounts
- Bottom half: 2x2 competitive matrix as shown in content, rendered as a professional quadrant chart
- Heirloom positioned in the top-left (private + technically deep) with a star marker
- Paprika in bottom-left (private + low tech depth)
- ReciMe in bottom-right (social + low tech depth)
- Top-right quadrant empty but labeled "Heirloom's territory"
- Clean arrows and labels, professional chart styling

**Key Data Points:**

- TAM: $2.4B (120M US cooking households x $20/yr)
- SAM: $480M (24M households actively seeking tools)
- SOM Year 5: $24M (240K subscribers x $100 ARPU)
- ReciMe: 4.8 stars, ~200K ratings, $6.99/mo
- Paprika: 4.7 stars, $4.99 one-time, no AI, no sharing
- Heirloom: only product in private + technically deep quadrant

---

## Slide 10: Business Model

**Content:**

> ### Freemium + Credits: Generous Free Tier, Clear Upgrade Path
>
> **Free Tier (Forever)**
> - URL import: always free, unlimited
> - Manual entry: always free, unlimited
> - Voice dictation: always free (on-device processing)
> - AI recipe generation: always free
> - 50 trial credits for premium imports
>
> **Premium Subscription**
> | Plan | Price | Trial | Annual Value |
> |---|---|---|---|
> | Monthly | $4.99/mo | 7-day free trial | $59.88/yr |
> | Annual | $29.99/yr | 14-day free trial | $29.99/yr |
> | Lifetime | $99 one-time | — | — |
>
> **Credit Packs (a la carte)**
> | Pack | Price | Per Credit |
> |---|---|---|
> | 25 credits | $5 | $0.20 |
> | 100 credits | $15 | $0.15 |
>
> **Credit Costs by Operation**
> | Operation | Credits | Our Cost |
> |---|---|---|
> | Video (with audio) | 1 | ~$0.05 |
> | ASMR video (visual-only) | 5 | ~$0.25 |
> | PDF (text-rich) | 1 | ~$0.05 |
> | PDF (mixed/scanned) | 3-5 | ~$0.15-0.25 |

**Speaker Notes:**

The business model is designed around a principle: the free tier should be genuinely useful, and the upgrade should feel like unlocking power, not removing restrictions. URL import, manual entry, voice dictation, and AI generation are free forever. These are the features that get users invested in the product — building a collection they care about. The 50 trial credits let free users experience premium imports — video extraction, cookbook scanning — so they understand the value before we ask them to pay.

Premium subscriptions are priced competitively. Monthly at $4.99 — below ReciMe's $6.99 — with a 7-day free trial. Annual at $29.99, which is a 50% savings over monthly and comes with a 14-day trial. And a lifetime option at $99 for users who want to pay once. We manage subscriptions through RevenueCat, which handles receipt validation, trial management, and cross-platform entitlements.

The credit system is the second revenue stream, designed for power users who do heavy importing but may not want a subscription. 25 credits for $5 or 100 credits for $15. Credit costs are calibrated to our actual AI costs with healthy margins: a standard video import costs 1 credit (our cost: ~$0.05), while an ASMR visual extraction costs 5 credits (our cost: ~$0.25). This means a $5 credit pack covers 25 standard imports or 5 ASMR extractions, giving users a clear mental model for what their money buys.

**Visual Direction:**

- Three-column layout: Free tier (gray), Premium (gold/amber), Credits (blue)
- Free column lists always-free features with checkmarks
- Premium column shows pricing table with the annual plan highlighted as "Best Value"
- Credits column shows credit packs and a cost-per-operation breakdown
- Bottom: simple diagram showing the user journey: "Free tier → Build collection → Hit credit limit → Subscribe or buy credits"
- RevenueCat logo in small text as infrastructure partner

**Key Data Points:**

- Free: URL import, manual entry, voice dictation, AI generation (always free)
- 50 trial credits for new users
- $4.99/mo, $29.99/yr, $99 lifetime
- Credit packs: $5/25 credits, $15/100 credits
- Margin on credits: 75-96% (cost $0.05-$0.25, charge $0.15-$1.00)

---

## Slide 11: Go-to-Market Strategy

**Content:**

> ### Organic → Community → Paid
>
> **Phase 1: Organic Foundation (Now)**
> - App Store Optimization: targeting "recipe manager," "recipe organizer," "recipe box," "cookbook scanner"
> - Content marketing: SEO-optimized marketing site (built and live)
> - Social proof: App Store reviews and ratings
> - Organic sharing: Kitchen Table invites create natural word-of-mouth
>
> **Phase 2: Community Growth (Months 1-6)**
> - Food blogger partnerships: free premium for recipe creators who bring audiences
> - Family-oriented positioning: Mother's Day, Thanksgiving, holiday gifting campaigns
> - Heritage angle: multicultural food preservation — "your family's recipes deserve better than a screenshot"
> - Reddit/food community engagement: r/cooking, r/MealPrepSunday, r/recipes (2.5M+ combined subscribers)
>
> **Phase 3: Paid Acquisition (Months 6-12)**
> - 12 ad creative variants ready for production
> - Channels: Instagram (food content), TikTok (cooking community), Facebook (family demographic), Apple Search Ads (high-intent)
> - Target CAC: $8-12/install, $25-35/subscriber
> - Heritage narrative ads: "What recipe would you lose if your phone died tomorrow?"
>
> **Built-in Virality: Every Kitchen Table share is a product invitation.**

**Speaker Notes:**

Go-to-market is three phases. Phase one is organic, and it is already underway. The marketing site is built and live. App Store Optimization targets high-intent keywords — "recipe manager," "recipe organizer," "cookbook scanner" — where users are actively looking for a solution. The critical organic growth mechanism is Kitchen Table: every time a user shares a recipe with a family member, that family member needs Heirloom to receive it. Every share is a product invitation. This is the same mechanic that drove WhatsApp and Venmo's early growth.

Phase two is community growth, targeted at the first six months post-launch. The heritage angle is the key differentiator in marketing. "Your family's recipes deserve better than a screenshot" is a message that resonates across demographics. We will partner with food bloggers and recipe creators by offering free premium access in exchange for bringing their audiences. Holiday campaigns — Mother's Day, Thanksgiving, Christmas — are natural moments when families think about preserving recipes. And the multicultural angle is significant: every food culture has recipes worth preserving, and framing Heirloom as cultural preservation broadens the addressable audience beyond "people who want a recipe app."

Phase three is paid acquisition starting at month six, once we have conversion data and retention metrics to inform spend. Twelve ad creative variants are ready for production. Target channels are Instagram and TikTok for the cooking content audience, Facebook for the family demographic, and Apple Search Ads for high-intent installs. Target CAC is $8-12 per install and $25-35 per subscriber, based on category benchmarks.

**Visual Direction:**

- Three horizontal phases shown as a timeline arrow from left to right
- Phase 1 (green): organic icons — App Store, SEO, word-of-mouth
- Phase 2 (blue): community icons — food bloggers, holidays, Reddit
- Phase 3 (gold): paid icons — Instagram, TikTok, Facebook, Apple Search Ads
- Below the timeline: "Built-in Virality" callout with a diagram showing User A → shares recipe → User B downloads Heirloom → User B shares → User C downloads
- Small callout: "12 ad creative variants ready"

**Key Data Points:**

- Kitchen Table: every share is a product invitation (built-in virality)
- 12 ad creative variants ready for production
- Target CAC: $8-12/install, $25-35/subscriber
- r/cooking + r/MealPrepSunday + r/recipes: 2.5M+ combined subscribers
- Heritage narrative: resonates across demographics and cultures

---

## Slide 12: Traction & Milestones

**Content:**

> ### Shipped. Not Planned. Shipped.
>
> **Completed (Production)**
> - [x] Native iOS app: Swift/SwiftUI, production on App Store
> - [x] 6 import methods: URL, video, cookbook scan, voice, AI generation, manual
> - [x] CRDT merge engine with vector clocks and conflict resolution UI
> - [x] Multi-pass AI pipeline: Haiku (parsing) + Sonnet (vision/generation) + GPT-4o (fallback)
> - [x] 5-pass ASMR visual extraction pipeline
> - [x] On-device audio transcription via WhisperKit
> - [x] SHA256 provenance hashing with generation tracking
> - [x] Kitchen Table peer-to-peer sharing with connection management
> - [x] Discover feed with trending, new, popular, and search
> - [x] Firebase backend: Firestore, Auth, Storage, Cloud Functions
> - [x] RevenueCat subscription management: monthly, annual, lifetime
> - [x] Credit system with a la carte purchasing
> - [x] Paywall system with soft walls, hard walls, cooldowns, 3-strike rule
> - [x] Marketing website: built and live
> - [x] Google Cloud Vision integration for handwriting OCR
> - [x] SEC-8 field path validation on CRDT operations
>
> **Next Milestones**
> - [ ] Launch marketing campaign (12 ad variants ready)
> - [ ] Food blogger partnership program
> - [ ] iPad app (shared codebase, SwiftUI adaptive layouts)
> - [ ] macOS app (Catalyst or native SwiftUI)
> - [ ] Recipe collections and meal planning
> - [ ] iOS 26 SpeechAnalyzer integration (replacing WhisperKit with native on-device transcription)

**Speaker Notes:**

I want to be direct about where we are. This is not a pitch for a prototype. This is not a mockup. Heirloom is a production app on the App Store today. Every feature I have described in this deck is shipped, tested, and working. The CRDT merge engine handles real offline-to-online sync conflicts. The ASMR pipeline extracts recipes from real silent cooking videos. The provenance hashing is generating real SHA256 chains on real shared recipes.

Let me emphasize what "shipped" means in concrete terms. The app has six fully functional import methods. The AI pipeline routes through three model tiers with automatic failover. The subscription system handles trials, renewals, and lifetime purchases through RevenueCat. The paywall system has soft walls with cooldown timers, hard walls for premium features, and a 3-strike rule that stops showing paywalls to users who have dismissed them three times — because annoying users who are not going to convert is worse than not showing the paywall at all.

The marketing website is built and live. Twelve ad creative variants are ready for production. The next milestones are distribution, not development. I am raising to reach users, not to build the product.

**Visual Direction:**

- Checklist format with green checkmarks for completed items, open circles for next milestones
- Completed section takes up ~75% of the slide, emphasizing depth of what is shipped
- Each completed item has a small icon indicating its category (AI, sync, monetization, etc.)
- Next milestones section is shorter, indicating the product is mature
- Subtle progress bar at the top showing "Product: 95% → Marketing: 20% → Growth: 5%"

**Key Data Points:**

- 16+ major features shipped to production
- Solo founder: entire stack built by one person
- 6 import methods, all functional
- 3-tier AI pipeline with automatic failover
- Revenue infrastructure: subscriptions + credits, fully implemented
- Next phase: distribution, not development

---

## Slide 13: Unit Economics

**Content:**

> ### The Economics Work at Every Scale
>
> **Cost Per User Per Month: ~$0.18**
>
> | Cost Component | Monthly/User | Notes |
> |---|---|---|
> | Firebase (Firestore, Auth, Storage) | ~$0.08 | Scales with usage |
> | AI API costs (Anthropic/OpenAI) | ~$0.05 | Blended across all operations |
> | Cloud Functions compute | ~$0.03 | Gateway + background processing |
> | RevenueCat | ~$0.01 | Free tier up to $2.5M revenue |
> | Google Cloud Vision | ~$0.01 | Only for cookbook scan/handwriting |
> | **Total** | **~$0.18** | |
>
> **Revenue Per Subscriber Per Month**
>
> | Plan | Monthly Revenue | After App Store Cut (70%) |
> |---|---|---|
> | Monthly ($4.99) | $4.99 | $3.49 |
> | Annual ($29.99/yr) | $2.50 | $1.75 |
> | Lifetime ($99) | ~$2.75* | ~$1.93* |
>
> *Lifetime amortized over 36-month expected lifetime
>
> **Gross Margin: 90%+ (monthly), 80%+ (annual)**
>
> **LTV:CAC Targets**
>
> | Metric | Conservative | Target |
> |---|---|---|
> | Average subscriber lifetime | 12 months | 24 months |
> | LTV (annual plan) | $21.00 | $42.00 |
> | Target CAC | $25-35 | $25-35 |
> | LTV:CAC ratio | 0.6-0.8x | 1.2-1.7x |
>
> **Path to positive LTV:CAC: retain subscribers past 18 months, or convert free-to-paid above 4%.**

**Speaker Notes:**

Let me walk through the unit economics because they are the foundation of the business. Our all-in cost per user per month is approximately $0.18. That breaks down to $0.08 for Firebase infrastructure, $0.05 for AI API costs blended across all operations, $0.03 for Cloud Functions compute, and small amounts for RevenueCat and Google Cloud Vision. The key driver is the AI cost tiering I described earlier — by routing 80% of operations through Claude Haiku at $0.25 per million tokens and using on-device transcription for audio, we keep the blended AI cost per user extremely low.

On the revenue side, after Apple's 30% cut — which drops to 15% after the first year of a subscription — a monthly subscriber generates $3.49, an annual subscriber generates $1.75 per month, and a lifetime purchase generates approximately $1.93 per month amortized over a 36-month expected lifetime. This gives us gross margins above 90% on monthly plans and above 80% on annual plans.

The LTV:CAC math requires honest assessment. At a conservative 12-month average subscriber lifetime with the annual plan, LTV is $21. Against a $25-35 CAC target, that is below 1x — which means we need to either retain subscribers past 18 months or convert free-to-paid above 4% to make paid acquisition economics work. The path to positive LTV:CAC is retention-driven: if families build their recipe collection in Heirloom, switching costs are high because their provenance chains, CRDT history, and sharing connections do not export. We are building for long-term retention, not quick conversion.

**Visual Direction:**

- Three sections stacked vertically: Cost breakdown, Revenue breakdown, LTV:CAC analysis
- Cost breakdown: horizontal stacked bar chart showing each component
- Revenue breakdown: three columns for monthly/annual/lifetime with margin percentages
- LTV:CAC: simple table with conservative and target scenarios, with the "path to positive" callout highlighted
- Color coding: costs in red/orange, revenue in green, target metrics in blue
- Clean financial presentation style — no marketing embellishment

**Key Data Points:**

- Cost per user: ~$0.18/month
- Gross margin: 90%+ (monthly), 80%+ (annual)
- AI cost driver: Haiku at $0.25/1M tokens handles 80% of operations
- On-device transcription: $0 cost for highest-volume operation
- LTV:CAC target: 1.2-1.7x at 24-month retention
- Path to positive: retain past 18 months or convert above 4%

---

## Slide 14: Team

**Content:**

> ### Solo Founder. Full-Stack Capability.
>
> **[Founder Name] — Founder & CEO, Rationale Studio**
>
> Built the entire Heirloom stack solo:
>
> - **iOS Engineering**: Native Swift/SwiftUI app with SwiftData persistence
> - **Distributed Systems**: CRDT merge engine with vector clocks and conflict resolution
> - **AI/ML Engineering**: Multi-pass AI pipeline, cost-tiered model routing, WhisperKit integration
> - **Backend Engineering**: Firebase (Firestore, Auth, Storage, Cloud Functions), server-side key management
> - **Security Engineering**: SEC-8 field validation, Keychain management, Cloud Functions gateway
> - **Product Design**: Full UI/UX, paywall system with behavioral triggers and cooldowns
> - **Cryptography**: SHA256 provenance hashing with CryptoKit
> - **Computer Vision**: 5-pass ASMR extraction, Google Cloud Vision OCR integration
> - **Growth**: Marketing website, App Store listing, 12 ad creative variants
>
> **Rationale Studio** — Product studio model. Heirloom is the flagship product.
>
> **Hiring Plan (Post-Raise)**
> 1. Growth Marketing Lead — paid acquisition, content marketing, community
> 2. iOS Engineer — feature velocity, iPad/macOS expansion
> 3. Part-time Designer — brand refinement, ad creative production

**Speaker Notes:**

I am a solo founder, and I want to address that directly because it is both a strength and a risk. The strength is clear: one person designed, engineered, and shipped a production app with a CRDT sync engine, a multi-pass AI pipeline, on-device ML transcription, SHA256 provenance hashing, a three-tier subscription system, and a marketing website. That is not a prototype or a hackathon project. That is production infrastructure spanning distributed systems, machine learning, security engineering, and product design.

The breadth of what has been shipped is the strongest signal of execution capability. CRDT implementations are hard — most teams assign a senior distributed systems engineer to that problem alone. Multi-pass AI pipelines with cost tiering require understanding both the AI models and the economics of running them at scale. On-device ML integration with WhisperKit requires understanding Apple's ML stack. I shipped all of these as one person.

The risk is obvious: a single point of failure. The hiring plan post-raise addresses this directly. Priority one is a growth marketing lead, because the product is built and the bottleneck is now distribution. Priority two is a second iOS engineer to increase feature velocity and expand to iPad and macOS. Priority three is a part-time designer for brand refinement and ad creative production. The goal is a small, focused team — not a headcount expansion.

**Visual Direction:**

- Left side: founder photo and brief bio
- Right side: skill matrix showing the nine domains listed, each with a small icon and a "shipped" indicator
- Below: hiring plan shown as three sequential cards with role, focus area, and timing
- Subtle "Product Studio" badge for Rationale Studio
- Professional, confident layout — not apologetic about being solo, presenting it as a strength

**Key Data Points:**

- Solo founder: 9 distinct engineering/design/marketing domains shipped
- CRDT engine: typically a dedicated senior engineer role
- AI pipeline: 3 model tiers, 2 providers, automatic failover
- Post-raise team: 3 hires (growth lead, iOS engineer, part-time designer)
- Product studio model: focused execution, low burn rate

---

## Slide 15: The Ask

**Content:**

> ### Seed Round: $750K
>
> **Use of Funds (18-Month Runway)**
>
> | Category | Allocation | Amount | Purpose |
> |---|---|---|---|
> | Growth Marketing | 40% | $300K | Paid acquisition, content marketing, partnerships, 12 ad variant testing |
> | Engineering | 25% | $187.5K | iOS engineer hire, iPad/macOS expansion, feature velocity |
> | Infrastructure | 15% | $112.5K | Firebase scaling, AI API costs at growth, CDN, monitoring |
> | Design & Brand | 10% | $75K | Part-time designer, brand refinement, ad creative production |
> | Operations | 10% | $75K | Legal, accounting, App Store fees, RevenueCat scaling tier |
>
> **Milestones This Capital Achieves:**
> - 50,000+ downloads
> - 5,000+ active subscribers
> - LTV:CAC > 1.0x on at least one acquisition channel
> - iPad and macOS apps shipped
> - 4.7+ App Store rating
>
> **Why Now:**
> 1. AI costs dropped 10x in 18 months — ASMR pipeline that cost $2.50/extraction in 2024 costs $0.25 today
> 2. On-device ML is fast enough — WhisperKit on A15+ chips transcribes faster than real-time
> 3. TikTok/Instagram recipe content explosion — 1B+ cooking videos annually, 40%+ with no speech
> 4. No incumbent has combined AI + privacy + CRDT sync — the window is open

**Speaker Notes:**

We are raising a $750,000 seed round to fund 18 months of growth. The product is built. This capital is for distribution.

Forty percent — $300,000 — goes to growth marketing. This is the primary use of funds because it is the primary bottleneck. The product works. People need to find it. We have 12 ad creative variants ready for testing, and the paid acquisition strategy targets Instagram, TikTok, Facebook, and Apple Search Ads. Twenty-five percent goes to hiring an iOS engineer to increase feature velocity and ship iPad and macOS apps. Fifteen percent covers infrastructure scaling — Firebase costs increase linearly with users, and AI API costs at growth volumes require budget. Ten percent for design and brand refinement, and ten percent for operational overhead.

The milestones this capital achieves: 50,000 downloads, 5,000 active subscribers, LTV:CAC above 1.0x on at least one acquisition channel, iPad and macOS apps shipped, and a 4.7-plus App Store rating. These are concrete, measurable targets.

The "why now" is critical. Three things converged to make this the right moment. First, AI costs dropped roughly 10x in 18 months — the ASMR visual extraction pipeline that would have cost $2.50 per extraction in early 2024 costs $0.25 today, making it economically viable at scale. Second, on-device ML is finally fast enough — WhisperKit on A15 and newer chips transcribes faster than real-time, making on-device transcription a genuine consumer-grade experience. Third, the explosion of cooking content on TikTok and Instagram created massive demand for extracting recipes from video — and an estimated 40% of those videos have no speech, which only Heirloom can handle. The window is open. No incumbent has combined AI, privacy, and CRDT sync into one product. We have.

**Visual Direction:**

- Pie chart showing use of funds with percentages and dollar amounts
- Below: milestone targets in a horizontal tracker with progress indicators
- Right side or bottom: "Why Now" section with three converging trend arrows pointing to the current moment
- Arrow 1: "AI costs" trending down (10x drop)
- Arrow 2: "On-device ML speed" trending up (real-time transcription)
- Arrow 3: "Recipe video content" trending up (1B+ annually)
- Convergence point: "2026 — The Window"
- Professional financial presentation style

**Key Data Points:**

- Raise: $750K seed round
- Runway: 18 months
- Growth marketing: 40% of funds ($300K)
- Milestone: 50K downloads, 5K subscribers
- AI cost drop: ~10x in 18 months
- ASMR cost: $2.50 (2024) → $0.25 (2026)
- WhisperKit: faster than real-time on A15+ chips

---

## Slide 16: Vision

**Content:**

> ### The System of Record for Family Food Culture
>
> **Today:** Heirloom is the best way to save, organize, and share recipes on iOS.
>
> **Tomorrow:**
>
> **Platform Expansion**
> iPhone → iPad → Mac → Web → Android
> One recipe collection, synced everywhere via CRDT engine
>
> **The Recipe Graph**
> Provenance hashing creates a global graph of recipe lineage. Every recipe in Heirloom is a node. Every share is an edge. Over time, this becomes the world's most comprehensive map of how recipes travel through families and communities. This data is proprietary and compounds with every user.
>
> **Preservation Partnerships**
> Libraries, cultural institutions, food heritage organizations. Heirloom's structured data format and provenance tracking make it the natural digital repository for recipe preservation efforts.
>
> **Commerce**
> Ingredient delivery partnerships (recipe → shopping list → delivery). Cookware recommendations. Cookbook publishing from user collections. Revenue streams that emerge naturally from a trusted recipe platform.
>
> **The Endgame**
> Every recipe your family has ever made — captured, structured, attributed, preserved, and shareable — in one place, forever. Not a bookmark. Not a screenshot. A living record.

**Speaker Notes:**

The vision for Heirloom extends far beyond a recipe management app. Let me paint the picture of where this goes.

In the near term, platform expansion. The CRDT merge engine I built is not platform-specific — the sync logic works across any device that can speak to Firebase. Expanding to iPad, Mac, web, and eventually Android means a family's recipe collection lives everywhere, syncs automatically, and never depends on a single device. This is the offline-first promise fulfilled.

In the medium term, the recipe graph. This is where provenance hashing becomes a strategic asset. Every recipe in Heirloom has a root hash. Every share creates a generation-incremented copy linked to that hash. Over time, with hundreds of thousands of users, this creates a global graph of recipe lineage — a map of how recipes travel through families and communities. Who originated a recipe. How many times it has been shared. What modifications were made at each generation. This data does not exist anywhere else, and it compounds with every user who joins the platform. It is a proprietary network effect.

In the long term, Heirloom becomes infrastructure. Cultural institutions and food heritage organizations need digital repositories for recipe preservation — Heirloom's structured format and provenance tracking make it the natural partner. Commerce opportunities emerge naturally: ingredient delivery from recipe shopping lists, cookware recommendations, cookbook publishing from user collections. These are revenue streams that grow from trust, not advertising.

The endgame is simple: every recipe your family has ever made — captured, structured, attributed, preserved, and shareable — in one place, forever. Not a bookmark. Not a screenshot. A living record of your family's food culture.

**Visual Direction:**

- Concentric circles radiating outward from center
- Center: "Recipe Collection" (today)
- Ring 1: "Platform Expansion" (iPhone, iPad, Mac, Web, Android icons)
- Ring 2: "Recipe Graph" (network visualization showing interconnected recipe nodes)
- Ring 3: "Preservation Partnerships" (library/institution icons)
- Ring 4: "Commerce" (shopping cart, cookbook, cookware icons)
- Outer ring: "System of Record for Family Food Culture"
- Warm, aspirational color gradient from center outward
- Not a roadmap with dates — a vision of expanding scope

**Key Data Points:**

- Platform expansion: iOS → iPad → Mac → Web → Android
- Recipe Graph: proprietary network effect from provenance hashing
- Compounding data: every user adds to the graph
- Commerce: ingredient delivery, cookware, cookbook publishing
- Preservation: cultural institutions, food heritage organizations
- Endgame: system of record for family food culture

---

## Slide 17: Appendix — Technical Architecture

**Content:**

> ### Full System Architecture
>
> ```
> ┌─────────────────────────────────────────────────────────────┐
> │                    HEIRLOOM iOS APP                         │
> │                  Swift / SwiftUI / SwiftData                │
> ├─────────────────────────────────────────────────────────────┤
> │                                                             │
> │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
> │  │   UI Layer   │  │  Features    │  │   Navigation     │  │
> │  │  SwiftUI     │  │  Recipes     │  │   NavigationStack│  │
> │  │  @Observable │  │  Social      │  │   Sheet/Modal    │  │
> │  │  Environment │  │  Discovery   │  │   Deep Links     │  │
> │  │              │  │  Settings    │  │                  │  │
> │  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
> │         │                 │                    │            │
> │  ┌──────▼─────────────────▼────────────────────▼─────────┐  │
> │  │              SERVICE CONTAINER (DI)                    │  │
> │  │         ServiceContainer.shared.resolve()              │  │
> │  │         Singleton lifecycle registration               │  │
> │  └──────┬─────────────────┬────────────────────┬─────────┘  │
> │         │                 │                    │            │
> │  ┌──────▼───────┐  ┌──────▼───────┐  ┌────────▼─────────┐  │
> │  │  AI Services │  │  Sync/Data   │  │  Store/Auth      │  │
> │  │              │  │              │  │                  │  │
> │  │ AIService    │  │ CRDT Merge   │  │ RevenueCat       │  │
> │  │  Protocol    │  │  Engine      │  │ SubscriptionMgr  │  │
> │  │ AIConfig     │  │ Vector       │  │ PaywallManager   │  │
> │  │ Multi-pass   │  │  Clocks      │  │ CreditStoreMgr   │  │
> │  │  pipeline    │  │ Conflict     │  │ Firebase Auth    │  │
> │  │ ASMR         │  │  Resolution  │  │ Keychain         │  │
> │  │  Processor   │  │ Firestore    │  │                  │  │
> │  │ WhisperKit   │  │  Sync        │  │                  │  │
> │  │ AIUsage      │  │              │  │                  │  │
> │  │  Tracker     │  │              │  │                  │  │
> │  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
> │         │                 │                    │            │
> │  ┌──────▼───────┐  ┌──────▼───────┐  ┌────────▼─────────┐  │
> │  │  On-Device   │  │  SwiftData   │  │  iOS Keychain    │  │
> │  │  ML          │  │  Persistence │  │  Secure Storage  │  │
> │  │  WhisperKit  │  │  Recipe      │  │  API Keys        │  │
> │  │  Apple       │  │  Ingredient  │  │  Access:         │  │
> │  │  Neural      │  │  Provenance  │  │  AfterFirst      │  │
> │  │  Engine      │  │  Metadata    │  │  UnlockThis      │  │
> │  │              │  │  CRDT Ops    │  │  DeviceOnly      │  │
> │  └──────────────┘  └──────────────┘  └──────────────────┘  │
> │                                                             │
> └──────────────────────────┬───────────────────────────────────┘
>                            │
>                   HTTPS / Firebase SDK
>                            │
> ┌──────────────────────────▼───────────────────────────────────┐
> │                   FIREBASE BACKEND                           │
> ├─────────────────────────────────────────────────────────────┤
> │                                                             │
> │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
> │  │  Firestore   │  │  Cloud       │  │  Firebase Auth   │  │
> │  │  Database    │  │  Functions   │  │                  │  │
> │  │              │  │              │  │  Anonymous Auth  │  │
> │  │  Recipes     │  │  AI Gateway  │  │  Email/Password  │  │
> │  │  Users       │  │  (no client  │  │  Apple Sign-In   │  │
> │  │  Connections │  │   API keys)  │  │  Google Sign-In  │  │
> │  │  Public      │  │  Rate        │  │                  │  │
> │  │  Recipes     │  │  Limiting    │  │                  │  │
> │  │  Credits     │  │  Usage       │  │                  │  │
> │  │              │  │  Tracking    │  │                  │  │
> │  └──────────────┘  └──────────────┘  └──────────────────┘  │
> │                                                             │
> │  ┌──────────────┐  ┌──────────────────────────────────────┐ │
> │  │  Cloud       │  │  Security Rules                      │ │
> │  │  Storage     │  │  Per-user document access             │ │
> │  │              │  │  Connection-based sharing              │ │
> │  │  Recipe      │  │  Public recipe read access             │ │
> │  │  Images      │  │  Credit validation                    │ │
> │  │  Thumbnails  │  │  Rate limiting per UID                │ │
> │  └──────────────┘  └──────────────────────────────────────┘ │
> │                                                             │
> └──────────────────────────┬───────────────────────────────────┘
>                            │
>                   Cloud Functions Gateway
>                            │
> ┌──────────────────────────▼───────────────────────────────────┐
> │                   EXTERNAL AI SERVICES                       │
> ├─────────────────────────────────────────────────────────────┤
> │                                                             │
> │  ┌──────────────────┐  ┌──────────────────┐                │
> │  │  Anthropic API   │  │  OpenAI API      │                │
> │  │                  │  │                  │                │
> │  │  Claude Haiku    │  │  GPT-4o-mini     │                │
> │  │  (Tier 1:       │  │  (Tier 1         │                │
> │  │   parsing)       │  │   fallback)      │                │
> │  │                  │  │                  │                │
> │  │  Claude Sonnet   │  │  GPT-4o          │                │
> │  │  4.5 (Tier 2:   │  │  (Tier 2         │                │
> │  │   PDF vision)    │  │   fallback)      │                │
> │  │                  │  │                  │                │
> │  │  Claude Sonnet   │  │                  │                │
> │  │  4 (Tier 2:     │  │                  │                │
> │  │   video vision)  │  │                  │                │
> │  └──────────────────┘  └──────────────────┘                │
> │                                                             │
> │  ┌──────────────────┐                                      │
> │  │  Google Cloud    │                                      │
> │  │  Vision API      │                                      │
> │  │  Handwriting OCR │                                      │
> │  └──────────────────┘                                      │
> │                                                             │
> └─────────────────────────────────────────────────────────────┘
> ```
>
> **Key Architecture Decisions:**
> - **DI Container**: `ServiceContainer` with singleton lifecycle — all services resolved via protocol, enabling testing and swapping
> - **Offline-First**: SwiftData local persistence + CRDT merge on reconnect — app is fully functional without network
> - **Security**: Zero API keys in client binary. Cloud Functions gateway. Keychain for user keys only. SEC-8 field validation.
> - **Cost Optimization**: Three AI model tiers. On-device transcription for highest-volume operation. Aggressive caching.
> - **Privacy**: Audio on-device. No tracking SDK. Private by default. Opt-in sharing.

**Speaker Notes:**

This slide is for the technical diligence conversation. The architecture has three layers: the iOS client, the Firebase backend, and external AI services. Let me highlight the key decisions.

The iOS client uses SwiftUI with SwiftData for local persistence. All services are registered through a dependency injection container with singleton lifecycle — this means every service can be resolved via its protocol, which enables comprehensive unit testing with mock implementations. The CRDT merge engine, AI services, subscription management, and paywall system are all independent services wired through DI.

The Firebase backend handles four concerns: Firestore for structured data, Cloud Functions as an AI gateway, Firebase Auth for identity, and Cloud Storage for images. The critical security decision is that Cloud Functions act as the only gateway to AI APIs — the client never calls Anthropic or OpenAI directly. This means API keys are server-side only, rate limiting is enforced per UID, and usage tracking is centralized.

External AI services use three Anthropic models (Haiku for parsing, Sonnet 4.5 for PDF vision, Sonnet 4 for video vision) with GPT-4o as automatic fallback for both tiers. Google Cloud Vision handles handwriting OCR for cookbook scanning. The on-device tier — WhisperKit on Apple Neural Engine — handles audio transcription with zero API cost and complete privacy.

**Visual Direction:**

- Full-page technical architecture diagram as shown in content, but rendered as a professional system diagram
- Color-coded layers: blue for iOS client, orange for Firebase, green for AI services
- Connection lines showing data flow between components
- Security indicators (lock icons) on Cloud Functions gateway and Keychain
- Privacy indicator (shield icon) on WhisperKit / on-device ML section
- Suitable for a technical appendix or deep-dive meeting

**Key Data Points:**

- DI Container: singleton lifecycle, protocol-based resolution
- Persistence: SwiftData (local) + Firestore (cloud) + CRDT (merge)
- AI Models: Claude Haiku, Claude Sonnet 4.5, Claude Sonnet 4, GPT-4o, GPT-4o-mini
- Security: Cloud Functions gateway, Keychain, SEC-8 validation
- Privacy: on-device transcription, no tracking SDK

---

## Slide 18: Appendix — Competitive Feature Matrix

**Content:**

> ### Feature-by-Feature Comparison
>
> | Feature | Heirloom | ReciMe | Paprika |
> |---|---|---|---|
> | **Import Methods** | | | |
> | URL import | Yes (free) | Yes | Yes |
> | Video import (with audio) | Yes | Yes | No |
> | Video import (silent/ASMR) | Yes (5-pass pipeline) | No | No |
> | Cookbook/PDF scan | Yes (camera + PDF) | Limited | No |
> | Handwriting OCR | Yes (Google Cloud Vision) | No | No |
> | Voice dictation | Yes (SFSpeechRecognizer) | No | No |
> | AI recipe generation | Yes | No | No |
> | Manual entry | Yes (free) | Yes | Yes |
> | **AI Architecture** | | | |
> | Multi-model AI pipeline | Yes (3 tiers) | Single model | No AI |
> | On-device transcription | Yes (WhisperKit) | No (cloud API) | No |
> | Cost-tiered model routing | Yes (Haiku/Sonnet/GPT-4o) | No | No |
> | Automatic AI failover | Yes (Anthropic → OpenAI) | No | No |
> | **Sync & Data** | | | |
> | Offline-first editing | Yes (CRDT) | No | Yes (local only) |
> | Multi-device sync | Yes (CRDT + Firestore) | Cloud sync | No native sync |
> | Conflict resolution | Yes (auto + manual UI) | Last-write-wins | N/A |
> | Provenance tracking | Yes (SHA256 hashing) | No | No |
> | Generation counting | Yes | No | No |
> | Attribution chains | Yes | Partial | No |
> | **Sharing & Social** | | | |
> | Private by default | Yes | No (social-first) | Yes (no sharing) |
> | Peer-to-peer sharing | Yes (Kitchen Table) | Feed-based | No |
> | Public discovery feed | Yes (opt-in) | Yes (default) | No |
> | Connection management | Yes | Follower model | No |
> | **Privacy & Security** | | | |
> | On-device audio processing | Yes | No | N/A |
> | API keys server-side only | Yes (Cloud Functions) | Unknown | N/A |
> | Keychain secure storage | Yes | Unknown | Unknown |
> | Field path injection prevention | Yes (SEC-8) | No CRDT | No CRDT |
> | **Monetization** | | | |
> | Pricing model | Freemium + credits | Subscription | One-time purchase |
> | Monthly price | $4.99 | $6.99 | N/A |
> | Annual price | $29.99 | $49.99 | N/A |
> | Lifetime option | $99 | No | $4.99 |
> | Free tier | Generous (URL, manual, voice, AI gen) | Limited | Full app |
> | **App Quality** | | | |
> | App Store rating | TBD (new) | 4.8 (200K+ ratings) | 4.7 |
> | Platform | iOS | iOS, Android | iOS, macOS, Android |
> | UI framework | SwiftUI (modern) | Unknown | UIKit (dated) |

**Speaker Notes:**

This matrix is designed for due diligence. Let me highlight the rows that matter most.

On import methods, Heirloom has six methods versus ReciMe's three and Paprika's two. The differentiators are voice dictation — which neither competitor offers — silent video extraction — which only Heirloom can do via the ASMR pipeline — and handwriting OCR for cookbook scanning. These are not incremental features; they are entire use cases that competitors cannot serve.

On AI architecture, the gap is fundamental. Heirloom has a three-tier multi-model pipeline with automatic failover and on-device transcription. ReciMe has a single model. Paprika has no AI at all. The cost tiering means Heirloom can offer more AI features at lower marginal cost, and the on-device transcription means our highest-volume AI operation costs zero.

On sync and data, Heirloom is the only product with a CRDT merge engine. ReciMe does cloud sync with last-write-wins conflict resolution — which means if two people edit a recipe at the same time, one person's changes are silently lost. Paprika is local-only with no native sync. Heirloom's CRDT engine handles simultaneous edits with field-level granularity and surfaces genuine conflicts to the user for resolution. Provenance tracking, generation counting, and attribution chains are unique to Heirloom.

On privacy, Heirloom's architecture-level approach — on-device audio, server-side-only API keys, Keychain storage, SEC-8 field validation — is fundamentally different from competitors who either do not address these concerns or handle them at the policy level rather than the architecture level.

On pricing, Heirloom is cheaper than ReciMe on every dimension — $4.99 versus $6.99 monthly, $29.99 versus $49.99 annually — while offering more features. The honest gap is App Store ratings and platform coverage: ReciMe has 200,000+ ratings and supports Android, while Heirloom is new and iOS-only. That gap closes with distribution investment and platform expansion, which is exactly what the raise funds.

**Visual Direction:**

- Full-page comparison table with three product columns
- Heirloom column highlighted with a subtle green background
- Checkmarks (green), X marks (red), and partial indicators (yellow) for each feature
- Group headers for each category (Import Methods, AI Architecture, etc.) in bold
- "Unique to Heirloom" badges on voice dictation, ASMR pipeline, CRDT, provenance hashing
- Professional, data-dense layout — this is an appendix slide for technical/analytical investors
- Small logos for each product at the top of their columns

**Key Data Points:**

- Heirloom: 6 import methods vs. ReciMe 3, Paprika 2
- Voice dictation: Heirloom only
- ASMR extraction: Heirloom only
- CRDT sync: Heirloom only
- Provenance tracking: Heirloom only
- Pricing: Heirloom cheaper than ReciMe on every tier
- Gap: ReciMe has 200K+ ratings, Android support
- Heirloom unique features: 5 features no competitor offers

---

## Deck Summary

**The pitch in one paragraph:**

Heirloom is the system of record for family food culture — an iOS app that captures recipes from any source (URL, video, cookbook scan, voice, AI generation, manual), preserves them with SHA256 provenance hashing and CRDT offline-first sync, and shares them through intentional peer-to-peer connections or an optional public feed. Built by a solo founder who shipped the entire stack — CRDT merge engine, multi-pass AI pipeline, on-device WhisperKit transcription, Firebase backend, RevenueCat subscriptions, and marketing website — the product is live on the App Store today. The $750K seed round funds 18 months of distribution to reach 50,000 downloads and 5,000 subscribers, with unit economics of ~$0.18/user/month cost against $2.50-4.99/month revenue and 80-90% gross margins.

---

*Prepared by Rationale Studio | 2026*
*Confidential — For Investor Use Only*
