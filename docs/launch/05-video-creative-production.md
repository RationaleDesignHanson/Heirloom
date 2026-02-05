# Video Creative Production Guide

> **Purpose:** Complete video brand system, modular templates, scripts, and production workflow for App Store preview, paid ads, and landing page videos.
>
> **Cross-references:**
> - Screen captures: See `04-manual-tasks-and-creative.md` Section A
> - App Store specs: See `02-app-store-submission.md` Section H
> - Onboarding flows to capture: See `01-app-onboarding-changes.md`

---

## Overview

### Core Message (One Sentence)

**"Share anything → Heirloom turns it into a real recipe with credit → saved in your recipe box → private by default."**

This is the through-line for every video asset. Show behavior, show transformation, end with trust.

### Competitive Wedge

| Competitor | Their Position | Heirloom's Differentiation |
|------------|---------------|---------------------------|
| **Paprika** | Classic recipe manager, clip from web | Modern capture + trust + sharing that sticks |
| **ReciMe** | Save from social platforms | Attribution + provenance + privacy-first sharing |

**Heirloom wins by owning:**
1. Attribution + provenance (credit where it came from)
2. Privacy-first sharing (private by default, P2P by default)
3. "Even ASMR" + "read recipe into phone" (meet users where recipes live)

---

## A. Video Brand Guidelines

### A.1 Visual Identity: "Warm Ceramic Calm"

**Core Traits:**
- Warmth, calm, craft, permanence
- Not techy, not glossy SaaS
- Soft grain texture
- Minimal shapes (recipe cards, boxes, gentle arrows)
- No busy patterns

**Palette:**
- Cream base (#FAF5F0) → terracotta/warm gold accents (#E07B54)
- Sage/green (#4CAF50) for trust/privacy moments
- Charcoal (#2C2C2C) for text

**Visual Keywords:**
- Ceramic / paper / recipe cards / warm kitchen light
- Minimal, premium, tactile
- "Organized calm" after chaos

**Avoid:**
- Techy neon, "AI sci-fi" vibes
- Glitch effects, hard wipes
- Loud kinetic typography
- Hard cuts every 0.3s

---

### A.2 Motion Language: "Soft, Human, Inevitable"

**Timing Rules:**

| Segment | Duration | Purpose |
|---------|----------|---------|
| Hook | 0:00–0:02.5 | Stop the scroll |
| Behavior | 0:02.5–0:06 | Show the action (Share → Heirloom) |
| Magic | 0:06–0:12 | Transformation moment |
| Trust | 0:12–0:16 | Differentiator beat |
| CTA | Last 2–3s | Download prompt |

**Easing:**
- Use slow-in / slow-out curves
- Let viewer read: hold key states for 0.8–1.2s
- No bouncing UI

**Transitions:**
- Default: cross-dissolve (6–10 frames) + gentle slide (8–16px)
- "Magic" moments: subtle "settle" easing
- Range montage: max 2–3 quick cuts

**Signature Micro-Animations:**
- "Recipe appears" = content fades in line-by-line (ingredients then steps)
- "Credit appears" = small chip slides in (source icon + creator)
- "Private by default" = pill toggles animate with tiny "lock" settle

---

### A.3 Typography: "Short, Confident, Human"

**Tone:**
- Plainspoken, friendly, slightly wry
- No exaggerated claims ("perfect every time")
- Instead: "ready to cook—tweak if you want"

**On-Screen Text Rules:**
- Max **7 words** per line
- Max **2 lines** at a time
- Only **1 claim per shot**
- Always paired to visible UI action

**Approved Phrase Bank:**

| Phrase | Use Case |
|--------|----------|
| "Save recipes from anywhere." | Universal CTA |
| "Even ASMR." | Video import hook |
| "One tap. Real recipe." | Magic moment |
| "Credit where it came from." | Attribution beat |
| "Share recipes that stick." | P2P sharing |
| "Private by default." | Trust beat |
| "Tell us what you have—get a recipe." | Generator |
| "Preserve family recipes." | Emotional/Grandma |
| "Ingredients • Steps • Credit." | Transformation payoff |
| "You control what's shared." | Privacy |

**Do Not Say:**
- "Perfect every time"
- "AI-powered" (as primary selling point)
- "Revolutionary" / "Game-changing"
- Technical jargon

---

### A.4 Audio Rules

**App Store Preview:**
- No voiceover (Apple preference)
- Light acoustic bed OK
- Subtle UI taps / success chime optional (low volume)

**Paid Ads (TikTok/Reels/Meta):**
- Can use VO (UGC-style), but **always works muted**
- If VO, keep it "friend talking" not "ad announcer"
- Light acoustic percussion OK
- For "Even ASMR" creatives: use actual cooking audio as texture

---

## B. Modular Video System (5 Reusable Blocks)

Build every video from these 5 interchangeable blocks:

### Block A — Hook (0–2.5s)

**Purpose:** Stop the scroll, create recognition

**Hook Options (pick one per video):**

| Hook ID | Text | Visual |
|---------|------|--------|
| HOOK_01 | "My recipe screenshots are out of control" | Camera roll chaos |
| HOOK_02 | "I found it on TikTok… again." | TikTok playing |
| HOOK_03 | "My mom texted me a photo of a cookbook page…" | iMessage with photo |
| HOOK_04 | "This recipe was ASMR… and I still saved it." | ASMR cooking clip |
| HOOK_05 | "Cookbook page? Don't retype it." | Cookbook in hand |
| HOOK_06 | "I want the recipe… and the source." | Video playing |
| HOOK_07 | "My recipes aren't public. Period." | Collections grid |
| HOOK_08 | "Stop texting screenshots." | iMessage chaos |
| HOOK_09 | "I had chicken, lemons, and zero plan." | Fridge contents |
| HOOK_10 | "Try it free—every day." | App icon |
| HOOK_11 | "Save recipes. Respect creators." | Attribution chip |
| HOOK_12 | "Public sharing shouldn't be risky." | Publish flow |

---

### Block B — Behavior (2.5–6s)

**Purpose:** Show the action, prove it's easy

**Always show one of:**
- Share → Heirloom (share extension flow)
- + menu → Paste/Scan/Generate

**Capture IDs:**
- `CAP_03` — Share sheet with Heirloom visible
- `CAP_16` — + menu open
- `CAP_17` — Camera scan UI

**On-screen text:** None (let action speak)

---

### Block C — Magic Transformation (6–12s)

**Purpose:** The "aha" moment—chaos becomes recipe

**Sequence:**
1. "Detecting recipe…" state (`CAP_03B`)
2. Ingredients populate (line-by-line animation)
3. **Attribution chip appears** (source icon + creator name)

**On-screen text:** "One tap. Real recipe." or "Ingredients • Steps • Credit."

**Capture IDs:**
- `CAP_03B` — Import progress
- `CAP_12` — Video import result with attribution
- `CAP_15` — Recipe detail clean

---

### Block D — Trust Contract (12–16s)

**Purpose:** Differentiate from competitors with trust beat

**Pick one trust moment:**

| Trust Beat | Visual | Capture ID |
|------------|--------|------------|
| Privacy pills | Private/Shared/Public toggle | `CAP_05` |
| P2P sharing | Send → Accept flow | `CAP_04` + `CAP_04B` |
| Ownership gate | Verification sheet | `CAP_09` |
| Attestation | "Respect creators" sheet | `CAP_08` |
| Attribution | Provenance chip visible | `CAP_13` |

**On-screen text options:**
- "Private by default."
- "Share recipes that stick."
- "Publish only what's yours."
- "You control what's shared."

---

### Block E — CTA (final 2–3s)

**Purpose:** Clear download prompt

**Standard end card:**
- Heirloom logo (centered)
- App Store badge
- CTA text: "Save recipes from anywhere."

**Optional additions:**
- "Start free. 25 daily credits." (pricing clarity)
- "Download Heirloom" (direct)

**Technical:**
- Same end card template for ALL videos
- Consistent logo position, badge position
- Warm cream background with subtle texture

---

## C. App Store Preview Script (30s)

### Specifications

| Spec | Value |
|------|-------|
| Resolution | 1290 x 2796 (iPhone 15 Pro Max) |
| Aspect | 9:16 |
| Codec | H.264 MP4 |
| Duration | 25–30 seconds |
| Audio | No voiceover, optional light bed |

### Frame-by-Frame Storyboard

| Timecode | Segment | Visual | On-Screen Text | Capture ID | Transition |
|----------|---------|--------|----------------|------------|------------|
| 0:00–0:03 | Hook | Cooking video playing (TikTok-style) | "Found a recipe you love?" | External clip | Fade in |
| 0:03–0:07 | Behavior | Share button → share sheet → tap Heirloom | — | `CAP_03` | Cut |
| 0:07–0:12 | Magic | "Detecting…" → recipe fills in | "One tap. Real recipe." | `CAP_03B` → `CAP_12` | Dissolve |
| 0:12–0:15 | Attribution | Attribution chip appears | "Ingredients • Steps • Credit" | `CAP_13` | Slide in |
| 0:15–0:18 | Save | "Saved to Inbox" toast | — | `CAP_11` | Cut |
| 0:18–0:22 | Result | Collections grid → tap recipe detail | — | `CAP_07B` → `CAP_15` | Cut |
| 0:22–0:24 | Range | PDF → scan result (quick cuts) | — | Various | Quick cuts |
| 0:24–0:27 | Trust | Privacy pills: Private by default | "Private by default." | `CAP_05` | Dissolve |
| 0:27–0:30 | CTA | Logo + App Store badge | "Save recipes from anywhere." | End card | Dissolve |

---

## D. Paid Ad Scripts (12 Variants)

All variants use the modular block system. Record once, remix forever.

### Variant 1: "Screenshots Graveyard" (Proven Winner)

**Duration:** 15s
**Hook:** "I screenshot every recipe… and lose it."
**Differentiator:** Share instead of screenshot

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | Camera roll chaos | Hook text |
| 0:02–0:06 | B | Share → Heirloom | — |
| 0:06–0:10 | C | Recipe appears | "One tap. Real recipe." |
| 0:10–0:12 | — | Saved toast | — |
| 0:12–0:15 | E | End card | "Save recipes from anywhere." |

**Captures needed:** `CAP_03`, `CAP_12`, `CAP_11`

---

### Variant 2: "Even ASMR"

**Duration:** 15s
**Hook:** "This recipe was ASMR… and I still saved it."
**Differentiator:** Video → recipe extraction

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | ASMR cooking clip (1s) | Hook text |
| 0:02–0:06 | B | Share → Heirloom | — |
| 0:06–0:10 | C | Video import result | — |
| 0:10–0:12 | D | Attribution chip | "Credit where it came from." |
| 0:12–0:15 | E | End card | "One tap. Real recipe." |

**Captures needed:** `CAP_03`, `CAP_12`, `CAP_13`

---

### Variant 3: "Cookbook Page"

**Duration:** 15s
**Hook:** "Cookbook page? Don't retype it."
**Differentiator:** Scan capability

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | Hands over cookbook (b-roll) | Hook text |
| 0:02–0:04 | — | (Optional) Attestation flash | — |
| 0:04–0:08 | B+C | Scan → result | — |
| 0:08–0:12 | — | Saved in collection | — |
| 0:12–0:15 | E | End card | "Your personal recipe box." |

**Captures needed:** `CAP_17`, `CAP_18`, `CAP_07B`, (optional `CAP_08`)

---

### Variant 4: "Credit Where It Came From"

**Duration:** 15s
**Hook:** "I want the recipe… and the source."
**Differentiator:** Attribution/provenance

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | Video playing | Hook text |
| 0:02–0:06 | B | Share → Heirloom | — |
| 0:06–0:10 | C | Recipe appears | — |
| 0:10–0:12 | D | Attribution visible | — |
| 0:12–0:15 | E | End card | "Ingredients • Steps • Credit." |

**Captures needed:** `CAP_03`, `CAP_12`, `CAP_13`

---

### Variant 5: "Private by Default"

**Duration:** 15s
**Hook:** "My recipes aren't public. Period."
**Differentiator:** Privacy controls

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | Collections grid | Hook text |
| 0:02–0:06 | — | Share privately to friend | — |
| 0:06–0:10 | D | Privacy pills | "Private by default." |
| 0:10–0:15 | E | End card | "You control what's shared." |

**Captures needed:** `CAP_07B`, `CAP_04`, `CAP_05`

---

### Variant 6: "Share That Sticks"

**Duration:** 15s
**Hook:** "Stop texting screenshots."
**Differentiator:** Accept flow—recipes land in their box

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | iMessage with recipe screenshot | Hook text |
| 0:02–0:06 | B | Sender hits share | — |
| 0:06–0:10 | — | Recipient taps Accept | — |
| 0:10–0:12 | — | Recipe in recipient collection | "They keep it forever." |
| 0:12–0:15 | E | End card | "Share recipes that stick." |

**Captures needed:** `CAP_04`, `CAP_04B`, `CAP_07B`

---

### Variant 7: "Make Something New" (Generator)

**Duration:** 15s
**Hook:** "I had chicken, lemons, and zero plan."
**Differentiator:** Generate from ingredients

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | Fridge/ingredients | Hook text |
| 0:02–0:06 | B | Generator input UI | "Tell us what you have." |
| 0:06–0:10 | C | Generated recipe with badge | "Get a recipe." |
| 0:10–0:12 | D | Share privately option | "Share privately." |
| 0:12–0:15 | E | End card | CTA |

**On-screen compliance:** "Generated recipes: private sharing only." (small text)

**Captures needed:** `CAP_20`, `CAP_10`

---

### Variant 8: "Range Montage"

**Duration:** 15s
**Hook:** "Recipes are everywhere. Now your box is too."
**Differentiator:** Versatility

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | Quick cuts: video, PDF, scan | Hook text |
| 0:02–0:04 | — | Video import result | — |
| 0:04–0:06 | — | PDF → recipes found | — |
| 0:06–0:08 | — | Scan result | — |
| 0:08–0:12 | — | Collections grid | — |
| 0:12–0:15 | E | End card | "Save recipes from anywhere." |

**Captures needed:** `CAP_12`, `CAP_18`, `CAP_07B`

---

### Variant 9: "Grandma's Recipe" (Emotional, 30s)

**Duration:** 30s
**Hook:** "My grandmother's handwriting is fading…"
**Differentiator:** Preserve / archive / legacy

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:04 | A | Hands holding old recipe card (b-roll) | Hook text |
| 0:04–0:08 | — | Camera positions over card | — |
| 0:08–0:12 | B | Scan flow | — |
| 0:12–0:18 | C | Recipe appears, ingredients line by line | — |
| 0:18–0:22 | D | "Family" / "Heritage" source chip | "Saved with credit." |
| 0:22–0:26 | — | Collections with family collection | — |
| 0:26–0:30 | E | End card | "Preserve your family's recipes." |

**Captures needed:** `CAP_17`, `CAP_18`, `CAP_07B`
**B-roll needed:** Warm kitchen hands shot (generated or filmed)

---

### Variant 10: "Free Daily Credits"

**Duration:** 15s
**Hook:** "Try it free—every day."
**Differentiator:** Free tier + credits model

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | App icon / launch | Hook text |
| 0:02–0:06 | B | Quick share import | — |
| 0:06–0:10 | — | Credits screen (25/25) | "25 free daily credits." |
| 0:10–0:12 | — | Premium upsell screen | — |
| 0:12–0:15 | E | End card | "Start free. Go premium when ready." |

**Captures needed:** `CAP_03`, `CAP_02`, `CAP_21`

---

### Variant 11: "Respect Creators"

**Duration:** 15s
**Hook:** "Save recipes. Respect creators."
**Differentiator:** Attestation + attribution (trust as brand)

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | Text on warm bg | Hook text |
| 0:02–0:06 | D | Attestation sheet | — |
| 0:06–0:10 | C | Import result | — |
| 0:10–0:12 | D | Attribution shown | — |
| 0:12–0:15 | E | End card | "Ingredients • Steps • Credit." |

**Captures needed:** `CAP_08`, `CAP_12`, `CAP_13`

---

### Variant 12: "Public Only When It's Yours"

**Duration:** 15s
**Hook:** "Public sharing shouldn't be risky."
**Differentiator:** Ownership verification before publishing

| Time | Block | Visual | Text |
|------|-------|--------|------|
| 0:00–0:02 | A | Discover feed | Hook text |
| 0:02–0:06 | — | User taps "Share publicly" | — |
| 0:06–0:10 | D | Ownership verification sheet | — |
| 0:10–0:12 | D | Privacy pills | "Private by default." |
| 0:12–0:15 | E | End card | "You control what's shared." |

**Captures needed:** `CAP_09`, `CAP_05`

---

## E. Master Capture Map (All Documents)

This is the **single source of truth** for all captures needed across screenshots, video, and landing pages.

> **For docs 01–04:** All file paths and names reference this section. Complete doc 05 captures first, then other docs will plug-and-play with correct paths.

### Workflow: Start Here

1. **Create the folder structure** (see Master Asset Directory below)
2. **Record captures** in priority order (see Priority Recording Order)
3. **Generate AI images** using prompts from `04-manual-tasks-and-creative.md` Section B
4. **Assemble screenshots** using specs from `02-app-store-submission.md` Section G
5. **Edit videos** using scripts from this doc Sections C & D

### Capture Device & Settings

| Setting | Value |
|---------|-------|
| **Device** | iPhone 15 Pro Max (physical or Simulator) |
| **iOS Version** | iOS 18+ |
| **Mode** | Light Mode |
| **Time** | 9:41 AM |
| **Battery** | 100% (full) |
| **Carrier** | Hidden or "Carrier" |
| **WiFi** | Full signal |
| **Notifications** | Do Not Disturb ON |
| **Resolution** | 1290 x 2796 px (6.7" display) |

### Screenshot vs Screen Recording

**Static Screenshots (PNG):**
- Used for: App Store screenshots, landing page images, reference stills
- Capture method: Cmd+S in Simulator, or physical screenshot
- Format: PNG, no alpha channel

**Screen Recordings (MOV/MP4):**
- Used for: App Store Preview, paid ads, landing page videos
- Capture method: QuickTime via Mac, or Simulator recording
- Format: MOV (raw), then export to H.264 MP4
- **Frame rate:** 30fps or 60fps (30fps preferred for smaller files)

---

### Master Asset Directory

This is the **canonical folder structure** for all marketing assets. All other docs reference these paths.

```
/marketing/
├── captures/
│   ├── screenshots/                    # Static PNGs from app
│   │   ├── CAP_01_onboarding_welcome.png
│   │   ├── CAP_02_onboarding_credits.png
│   │   └── ...
│   └── recordings/                     # Screen recordings from app
│       ├── CAP_03_share_sheet.mov
│       ├── CAP_03_share_sheet.mp4      # Exported H.264
│       └── ...
│
├── app-store/
│   ├── screenshots/                    # Final framed screenshots (10)
│   │   ├── SS_01_collections_home.png
│   │   ├── SS_02_one_tap_save.png
│   │   └── ...SS_10
│   └── preview/
│       ├── HEIRLOOM_APPSTORE_PREVIEW_30s.mov   # Raw
│       └── HEIRLOOM_APPSTORE_PREVIEW_30s.mp4   # Final
│
├── ads/
│   ├── V01_save_from_link_15s.mp4
│   ├── V02_even_asmr_15s.mp4
│   └── ...V12
│
├── landing/
│   ├── hero/
│   │   └── landing_hero_bg.png
│   ├── proof/
│   │   ├── lp_video_proof.mp4
│   │   ├── lp_scan_proof.mp4
│   │   └── ...
│   └── og/
│       └── og_image.png
│
├── ai-generated/
│   ├── AI_01_onboarding_hero.png
│   ├── AI_02_collection_breakfast.png
│   └── ...AI_09
│
└── templates/
    ├── figma/
    │   └── screenshot_frame_template.fig
    ├── ae/
    │   ├── video_template.aep
    │   └── end_card.aep
    └── runway/
        └── broll_prompts.md
```

**Naming Conventions:**

| Asset Type | Pattern | Example |
|------------|---------|---------|
| Raw capture (screenshot) | `CAP_XX_description.png` | `CAP_01_onboarding_welcome.png` |
| Raw capture (recording) | `CAP_XX_description.mov` | `CAP_03_share_sheet.mov` |
| Exported recording | `CAP_XX_description.mp4` | `CAP_03_share_sheet.mp4` |
| App Store screenshot | `SS_XX_headline_slug.png` | `SS_01_collections_home.png` |
| Ad video | `VXX_hook_name_duration.mp4` | `V02_even_asmr_15s.mp4` |
| AI-generated image | `AI_XX_description.png` | `AI_01_onboarding_hero.png` |

**Create Directory Structure (run once):**

```bash
mkdir -p marketing/{captures/{screenshots,recordings},app-store/{screenshots,preview},ads,landing/{hero,proof,og},ai-generated,templates/{figma,ae,runway}}
```

---

### Complete Capture List with Type, Duration & Path

| ID | Description | Type | Duration | Path | Used In |
|----|-------------|------|----------|------|---------|
| `CAP_01` | Onboarding Welcome | Screenshot | — | `captures/screenshots/CAP_01_onboarding_welcome.png` | SS_01, Landing |
| `CAP_02` | Onboarding Credits (25/25) | Screenshot | — | `captures/screenshots/CAP_02_onboarding_credits.png` | SS_10, Landing |
| `CAP_02B` | Credits Modal open | Screenshot | — | `captures/screenshots/CAP_02B_credits_modal.png` | Internal |
| `CAP_03` | Share sheet → tap Heirloom | **Recording** | **5-8s** | `captures/recordings/CAP_03_share_sheet.mov` | App Store, V1, V2, V4, SS_02 |
| `CAP_03B` | Import progress "Detecting…" | **Recording** | **3-5s** | `captures/recordings/CAP_03B_import_progress.mov` | App Store |
| `CAP_03C` | Saved toast animation | **Recording** | **2-3s** | `captures/recordings/CAP_03C_saved_toast.mov` | V1 |
| `CAP_04` | Share send flow (enter email, send) | **Recording** | **4-6s** | `captures/recordings/CAP_04_share_send.mov` | V5, V6, SS_07 |
| `CAP_04B` | Accept sheet (recipient taps Accept) | **Recording** | **3-4s** | `captures/recordings/CAP_04B_accept_sheet.mov` | V6, SS_07 |
| `CAP_04C` | "Added to your box" success | **Recording** | **2-3s** | `captures/recordings/CAP_04C_added_success.mov` | Internal |
| `CAP_05` | Visibility pills (tap between states) | **Recording** | **4-6s** | `captures/recordings/CAP_05_visibility_pills.mov` | App Store, V5, V12, SS_08 |
| `CAP_05B` | Private pill selected | Screenshot | — | `captures/screenshots/CAP_05B_pill_private.png` | Internal |
| `CAP_05C` | Public pill selected | Screenshot | — | `captures/screenshots/CAP_05C_pill_public.png` | Internal |
| `CAP_06` | Quick Start screen | Screenshot | — | `captures/screenshots/CAP_06_quick_start.png` | Internal |
| `CAP_07` | Collections empty state | Screenshot | — | `captures/screenshots/CAP_07_collections_empty.png` | Internal |
| `CAP_07B` | Collections populated (scroll) | **Recording** | **4-6s** | `captures/recordings/CAP_07B_collections_populated.mov` | App Store, V5, V6, V8, V9, SS_01 |
| `CAP_07C` | Quick actions bar (tap chip) | **Recording** | **2-3s** | `captures/recordings/CAP_07C_quick_actions.mov` | Internal |
| `CAP_08` | Scan attestation (checkbox + continue) | **Recording** | **3-4s** | `captures/recordings/CAP_08_scan_attestation.mov` | V3, V11 |
| `CAP_09` | Ownership verification (checkbox + continue) | **Recording** | **3-4s** | `captures/recordings/CAP_09_ownership_verify.mov` | V12, SS_09 |
| `CAP_10` | Generated recipe with badge (scroll) | **Recording** | **4-5s** | `captures/recordings/CAP_10_generated_badge.mov` | V7, SS_06 |
| `CAP_11` | Share toast slides up | **Recording** | **2-3s** | `captures/recordings/CAP_11_share_toast.mov` | V1, SS_02 |
| `CAP_12` | Video import result (scroll ingredients) | **Recording** | **5-8s** | `captures/recordings/CAP_12_video_result.mov` | App Store, V1, V2, V4, V8, V11, SS_03 |
| `CAP_13` | Discover card with attribution (tap) | **Recording** | **3-5s** | `captures/recordings/CAP_13_discover_card.mov` | App Store, V2, V4, V11, SS_09 |
| `CAP_14` | Publishing rules sheet | Screenshot | — | `captures/screenshots/CAP_14_publishing_rules.png` | Internal |
| `CAP_15` | Recipe detail (scroll full recipe) | **Recording** | **5-8s** | `captures/recordings/CAP_15_recipe_detail.mov` | App Store |
| `CAP_16` | + menu open (tap to open) | **Recording** | **2-3s** | `captures/recordings/CAP_16_plus_menu.mov` | Block B |
| `CAP_17` | Camera scan (position + capture) | **Recording** | **4-6s** | `captures/recordings/CAP_17_camera_scan.mov` | V3, V9, SS_04 |
| `CAP_18` | Scan result (scroll) | **Recording** | **4-5s** | `captures/recordings/CAP_18_scan_result.mov` | V3, V8, V9, SS_04 |
| `CAP_19` | Read aloud (tap play, step highlights) | **Recording** | **5-8s** | `captures/recordings/CAP_19_read_aloud.mov` | SS_05 |
| `CAP_20` | Generator input (type ingredients) | **Recording** | **4-6s** | `captures/recordings/CAP_20_generator_input.mov` | V7, SS_06 |
| `CAP_21` | Premium paywall (scroll features) | **Recording** | **4-5s** | `captures/recordings/CAP_21_premium_paywall.mov` | V10, SS_10 |
| `CAP_22` | Credits quota display | Screenshot | — | `captures/screenshots/CAP_22_credits_quota.png` | Internal |
| `CAP_23` | Buy more credits sheet | Screenshot | — | `captures/screenshots/CAP_23_buy_credits.png` | Internal |

> **Note:** All paths are relative to `/marketing/`. For recordings, export `.mp4` versions to same directory after editing.

### Recording Specifications

| Spec | Value |
|------|-------|
| **Raw format** | MOV (from QuickTime or Simulator) |
| **Export format** | H.264 MP4 |
| **Resolution** | 1290 x 2796 (iPhone 15 Pro Max) |
| **Frame rate** | 30fps |
| **Record extra** | +2s before and after each action (trim in edit) |

### How to Record

**Option 1: Simulator + QuickTime (Recommended)**
1. Open Simulator with iPhone 15 Pro Max
2. Open QuickTime Player → File → New Movie Recording
3. Click dropdown next to record button → select Simulator
4. Record the full flow, trim later

**Option 2: Simulator Built-in**
1. In Simulator menu: Device → Record Screen (Cmd+R)
2. Perform the action
3. Stop recording (Cmd+R again)
4. Find recording in Desktop or Documents

**Option 3: Physical Device**
1. Connect iPhone 15 Pro Max to Mac
2. Open QuickTime → File → New Movie Recording
3. Select iPhone as source
4. Record at native resolution

### Screenshot Extraction from Recordings

For captures needed as **both screenshot AND video** (e.g., CAP_03, CAP_12):
1. Record the full flow as video
2. Export a still frame at the "hero moment" for screenshot use
3. In QuickTime: pause at frame → Edit → Copy → paste into Preview → Save as PNG

### Video-Specific Captures (Voice Feature)

| ID | Description | Used In | Setup |
|----|-------------|---------|-------|
| `CAP_V_VOICE_ENTRY` | + menu "Read recipe into Heirloom" | Voice ad | Tap + menu, show voice option |
| `CAP_V_VOICE_RECORDING` | Audio capture UI state | Voice ad | During voice recording |
| `CAP_V_VOICE_RESULT` | Parsed recipe from voice | Voice ad | After voice extraction |

### AI-Generated Images

| ID | Description | Dimensions | Path | Used In |
|----|-------------|------------|------|---------|
| `AI_01` | Onboarding hero illustration | 1290 x 800 | `ai-generated/AI_01_onboarding_hero.png` | Onboarding Screen 1 |
| `AI_02` | Collection header: Breakfast | 800 x 400 | `ai-generated/AI_02_collection_breakfast.png` | Demo state |
| `AI_03` | Collection header: Weeknight | 800 x 400 | `ai-generated/AI_03_collection_weeknight.png` | Demo state |
| `AI_04` | Collection header: Baking | 800 x 400 | `ai-generated/AI_04_collection_baking.png` | Demo state |
| `AI_05` | Collection header: Family | 800 x 400 | `ai-generated/AI_05_collection_family.png` | Demo state |
| `AI_06` | OG image (social share) | 1200 x 630 | `ai-generated/AI_06_og_image.png` | Landing, social |
| `AI_07` | Screenshot frame background | 1290 x 2796 | `ai-generated/AI_07_screenshot_bg.png` | SS_01–SS_10 |
| `AI_08` | Landing hero background | 2560 x 1440 | `ai-generated/AI_08_landing_hero_bg.png` | Landing pages |
| `AI_09` | Press kit header | 1600 x 900 | `ai-generated/AI_09_presskit_header.png` | Press kit |

> **See:** `04-manual-tasks-and-creative.md` **Section B** for full generation prompts.

### App Store Screenshots (Final Outputs)

| ID | Headline | Path | Source Captures |
|----|----------|------|-----------------|
| `SS_01` | Your recipes, finally organized | `app-store/screenshots/SS_01_collections_home.png` | `CAP_07B` |
| `SS_02` | Save from any app—one tap | `app-store/screenshots/SS_02_one_tap_save.png` | `CAP_03` + `CAP_11` |
| `SS_03` | Turn any video into a recipe | `app-store/screenshots/SS_03_video_import.png` | `CAP_12` |
| `SS_04` | Scan cookbook pages instantly | `app-store/screenshots/SS_04_scan_cookbook.png` | `CAP_17` + `CAP_18` |
| `SS_05` | Hands busy? Have it read aloud | `app-store/screenshots/SS_05_read_aloud.png` | `CAP_19` |
| `SS_06` | Tell us what you have | `app-store/screenshots/SS_06_ai_generate.png` | `CAP_10` + `CAP_20` |
| `SS_07` | Share recipes that stick | `app-store/screenshots/SS_07_share_friends.png` | `CAP_04` |
| `SS_08` | Private by default | `app-store/screenshots/SS_08_private_default.png` | `CAP_05` |
| `SS_09` | Credit where it came from | `app-store/screenshots/SS_09_attribution.png` | `CAP_13` + `CAP_09` |
| `SS_10` | 25 free credits daily | `app-store/screenshots/SS_10_premium.png` | `CAP_02` + `CAP_21` |

### Ad Video Exports

| ID | Hook | Duration | Path |
|----|------|----------|------|
| `V01` | Save from link | 15s | `ads/V01_save_from_link_15s.mp4` |
| `V02` | Even ASMR | 15s | `ads/V02_even_asmr_15s.mp4` |
| `V03` | Scan cookbook | 15s | `ads/V03_scan_cookbook_15s.mp4` |
| `V04` | Screenshot a recipe | 15s | `ads/V04_screenshot_15s.mp4` |
| `V05` | Share that sticks | 15s | `ads/V05_share_sticks_15s.mp4` |
| `V06` | Accept flow | 15s | `ads/V06_accept_flow_15s.mp4` |
| `V07` | What do I have | 15s | `ads/V07_generator_15s.mp4` |
| `V08` | Range montage | 15s | `ads/V08_range_montage_15s.mp4` |
| `V09` | Grandma's recipes | 15s | `ads/V09_grandma_15s.mp4` |
| `V10` | Free credits | 15s | `ads/V10_free_credits_15s.mp4` |
| `V11` | Creator credit | 15s | `ads/V11_creator_credit_15s.mp4` |
| `V12` | Ownership | 15s | `ads/V12_ownership_15s.mp4` |

---

### Usage by Asset Type (Quick Reference)

**App Store Screenshots (10):**
- SS_01: `CAP_07B`
- SS_02: `CAP_03` + `CAP_11`
- SS_03: `CAP_12`
- SS_04: `CAP_17` + `CAP_18`
- SS_05: `CAP_19`
- SS_06: `CAP_10` + `CAP_20`
- SS_07: `CAP_04`
- SS_08: `CAP_05`
- SS_09: `CAP_13` + `CAP_09`
- SS_10: `CAP_02` + `CAP_21`

**App Store Preview Video:**
- `CAP_03`, `CAP_03B`, `CAP_12`, `CAP_13`, `CAP_11`, `CAP_07B`, `CAP_15`, `CAP_05`

**Landing Page Variants:**
- `/` (Homepage): `CAP_01`, `CAP_02`, `CAP_05`, `CAP_07B`, `CAP_21`
- `/lp/video`: `CAP_12`
- `/lp/scan`: `CAP_03`, `CAP_17`, `CAP_18`
- `/lp/generate`: `CAP_10`, `CAP_20`
- `/lp/share`: `CAP_04`, `CAP_04B`

### Priority Recording Order

Record in this order to maximize efficiency (dependencies grouped):

**Session 1: Onboarding Flow**
1. `CAP_01` — Welcome screen
2. `CAP_02` — Credits screen
3. `CAP_02B` — Credits modal
4. `CAP_05` — Privacy pills
5. `CAP_05B`, `CAP_05C` — Pill states
6. `CAP_06` — Quick Start

**Session 2: Collections & Import**
1. `CAP_07` — Collections empty
2. `CAP_07B` — Collections populated
3. `CAP_07C` — Quick actions
4. `CAP_16` — + menu open
5. `CAP_03` — Share sheet
6. `CAP_03B` — Import progress
7. `CAP_11` / `CAP_03C` — Saved toast

**Session 3: Recipe Results**
1. `CAP_12` — Video import result
2. `CAP_18` — Scan result
3. `CAP_10` — Generated recipe
4. `CAP_15` — Recipe detail
5. `CAP_19` — Read aloud UI

**Session 4: Sharing & Trust**
1. `CAP_04` — Share send
2. `CAP_04B` — Accept sheet
3. `CAP_04C` — Added success
4. `CAP_08` — Scan attestation
5. `CAP_09` — Ownership verification
6. `CAP_13` — Discover card
7. `CAP_14` — Publishing rules

**Session 5: Monetization**
1. `CAP_21` — Premium paywall
2. `CAP_22` — Credits quota
3. `CAP_23` — Buy more credits

**Session 6: Camera (needs cookbook/recipe card prop)**
1. `CAP_17` — Camera scan UI

**Session 7: Voice (if feature ready)**
1. `CAP_V_VOICE_ENTRY`
2. `CAP_V_VOICE_RECORDING`
3. `CAP_V_VOICE_RESULT`

---

## F. Generative Video (Runway/Gen Tools)

### Role 1: "Warm Kitchen B-Roll" (Hands Only)

**Use for:** Emotional beats, Grandma storyline, cooking vibe, end-card lifestyle

**Constraints:**
- No identifiable faces
- Hands only
- Warm lighting
- Shallow depth of field
- Natural motion

**Prompt Template:**
```
hands cooking, warm natural light, shallow depth of field, ceramic bowl,
wooden counter, minimal scene, no faces, no text, calm camera, golden hour,
home kitchen, [SPECIFIC ACTION]
```

**Specific Action Examples:**
- "writing on recipe card"
- "stirring pot slowly"
- "holding old handwritten recipe"
- "flipping cookbook pages"
- "placing ingredients on counter"

**Negative Prompt:**
```
faces, brand logos, text overlays, harsh lighting, sterile modern kitchen,
commercial kitchen, restaurant, cold colors, blue tones
```

---

### Role 2: "Abstract Transformation" (Chaos → Recipe Box)

**Use for:** Hooks showing "screenshots everywhere" without needing real camera roll

**Prompt Template:**
```
recipe cards / paper slips swirling then settling into a tidy recipe box,
warm cream + terracotta palette, subtle ceramic texture, minimalist,
slow push-in, [SPECIFIC TRANSFORMATION]
```

**Transformation Examples:**
- "scattered papers becoming organized stack"
- "floating recipe cards landing in wooden box"
- "chaos of ingredients resolving into neat grid"

**Negative Prompt:**
```
text, words, faces, logos, harsh shadows, cold colors, digital effects,
glitch, neon
```

---

### Role 3: "Ceramic/Paper Texture Loops" (Backgrounds)

**Use for:** Background plates, transitions, end card backgrounds

**Prompt Template:**
```
subtle texture loop, warm cream ceramic surface, soft speckle pattern,
gentle ambient movement, no distinct objects, background plate,
[DURATION] seconds
```

**Duration:** 3-5 second loops

---

## G. After Effects Assembly Rules

### Project Setup

```
/ae_project/
├── heirloom_video_template.aep
├── /footage/
│   ├── /captures/         # Screen recordings
│   ├── /broll/            # Kitchen b-roll
│   └── /generated/        # Runway outputs
├── /assets/
│   ├── logo/
│   ├── end_card/
│   └── app_store_badge/
└── /exports/
```

### Text Animation Preset

**Standard text entrance:**
- Fade: 0% → 100% over 8 frames
- Position: +8px Y → 0 over 8 frames
- Easing: Ease Out (33% influence)

**Hold duration:** 0.8–1.2 seconds minimum

### Transition Presets

| Transition | Settings |
|------------|----------|
| Cross dissolve | 6–10 frames |
| Slide | 8–16px, Ease Out |
| Cut | For quick action sequences only |

### End Card Specification

| Element | Position | Size |
|---------|----------|------|
| Logo | Center, 40% from top | 180px width |
| App Store badge | Center, 70% from top | 200px width |
| CTA text | Center, 85% from top | 48pt |
| Background | Full frame | Warm cream gradient |

### Export Settings

| Setting | Value |
|---------|-------|
| Format | H.264 |
| Resolution | 1080x1920 (9:16) or 1290x2796 (App Store) |
| Frame rate | 30fps |
| Bitrate | 15-20 Mbps |
| Audio | AAC, 256kbps (if used) |

### Safe Margins

- Top: 150px (status bar area)
- Bottom: 100px (home indicator)
- Sides: 40px

---

## H. Production Workflow

### Creative Refresh Cadence

**Recommendation:** Refresh every 10–14 days to avoid fatigue

**Weekly output (limited bandwidth):**
- 2 new paid ad variants (same body + different hook)
- 1 "new body" variant every 2 weeks (new feature focus)

### The "Remix Rule"

To produce quickly without reinventing:

**Keep constant:**
- Body footage (Share → Detect → Recipe)
- End card
- Motion presets

**Swap only:**
- Hook (first 2 seconds)
- One differentiator beat (trust, generator, credits)
- End card line

### Recording Session Checklist

**Before recording:**
- [ ] iPhone 15 Pro Max (or Simulator)
- [ ] Light Mode enabled
- [ ] Time set to 9:41 AM
- [ ] Battery 100%
- [ ] Do Not Disturb ON
- [ ] Demo account logged in
- [ ] Sample recipes loaded
- [ ] Collections populated

**Record in one session:**
1. All share extension flows
2. All + menu flows
3. All import results
4. All trust screens (attestation, ownership, privacy)
5. Collections views
6. Recipe detail views

### Quality Checklist

- [ ] UI is readable at all times (no zoom blur)
- [ ] Text on screen ≤ 7 words per line
- [ ] Key states hold for 0.8s minimum
- [ ] Transitions are smooth (no jarring cuts)
- [ ] End card matches template exactly
- [ ] Works with sound OFF (all claims visible)
- [ ] Brand colors consistent throughout

---

## I. Video Asset Naming Convention

```
HEIRLOOM_[TYPE]_[VARIANT]_[VERSION]_[ASPECT].[EXT]

Examples:
HEIRLOOM_APPSTORE_PREVIEW_V1_9x16.mp4
HEIRLOOM_AD_SCREENSHOTS_V2_9x16.mp4
HEIRLOOM_AD_EVENASMR_V1_9x16.mp4
HEIRLOOM_AD_GENERATOR_V1_1x1.mp4
```

**Types:**
- `APPSTORE` — App Store preview
- `AD` — Paid advertisement
- `LANDING` — Landing page video
- `SOCIAL` — Organic social content

**Aspects:**
- `9x16` — Vertical (TikTok, Reels, Stories)
- `1x1` — Square (Feed)
- `16x9` — Horizontal (YouTube, landing page)

---

## J. Platform-Specific Adaptations

### TikTok/Reels (9:16)

- First 1s is critical (hook MUST stop scroll)
- Trending audio optional but helpful
- Caption text larger (mobile viewing)
- UGC-style VO performs well

### Meta Feed (1x1)

- Crop to center the phone/UI
- Text must be readable at smaller size
- Can be slightly longer (up to 30s)
- Sound off is default

### YouTube Pre-Roll (16:9)

- Skip button at 5s—hook before then
- Can include more detail
- Voiceover acceptable
- Landscape crop of UI

### App Store (9:16, specific)

- No spoken audio
- Must show real app
- Auto-loops
- First frame is poster frame

---

## K. Folder Structure

> **See Section E: Master Asset Directory** for the complete `/marketing/` folder structure.
>
> All captures, screenshots, ads, and templates use paths defined there.

**Quick reference for video-specific subdirectories:**

| Path | Contents |
|------|----------|
| `/marketing/captures/recordings/` | Raw `.mov` screen recordings |
| `/marketing/app-store/preview/` | 30s App Store preview video |
| `/marketing/ads/` | V01–V12 ad exports |
| `/marketing/templates/ae/` | After Effects project + presets |
| `/marketing/templates/runway/` | Runway/AI b-roll prompts |

**Video asset naming:**

```
HEIRLOOM_APPSTORE_PREVIEW_30s.mp4      # App Store
V01_save_from_link_15s.mp4             # Ads
V02_even_asmr_15s.mp4
...
V12_ownership_15s.mp4
```

---

## L. Cross-Reference to Other Docs

### Capture Setup Instructions

For **detailed setup steps** per capture (app state, device settings, etc.), see:
- `04-manual-tasks-and-creative.md` **Section A** — Full instructions for CAP_01 through CAP_23

### Screenshot Assembly

For **App Store screenshot framing** (headlines, backgrounds, device frames), see:
- `02-app-store-submission.md` **Section G** — 10 screenshot specs
- `02-app-store-submission.md` **Section I** — Template specs (Figma layout)

### Features to Implement First

Some captures require **features that may not exist yet**. See implementation prompts in:
- `01-app-onboarding-changes.md` — 14 Claude Code prompts for:
  - Visibility pills (CAP_05)
  - Scan attestation (CAP_08)
  - Ownership verification (CAP_09)
  - Generated sourceType badge (CAP_10)
  - Share toast with collection (CAP_11)
  - Discover card redesign (CAP_13)

### Landing Page Images

For **landing page image requirements**, see:
- `03-landing-pages.md` **Prompt 5** — Placeholder system
- `04-manual-tasks-and-creative.md` **Section B** — AI image prompts

### Full Document Map

| Doc | Primary Content |
|-----|-----------------|
| 01 | App changes (14 Claude Code prompts) |
| 02 | App Store metadata + 10 screenshots |
| 03 | Landing pages (8 Cursor prompts) |
| 04 | Capture instructions + AI prompts + checklists |
| 05 | Video brand system + scripts + production |

---

## M. Quick Reference: Recording Checklist

Print this for recording sessions. See `04-manual-tasks-and-creative.md` Section A for detailed setup instructions per capture.

### Session 1: Onboarding Flow (6 captures)

- [ ] `CAP_01` — Onboarding Welcome screen
- [ ] `CAP_02` — Onboarding Credits (25/25 meter)
- [ ] `CAP_02B` — "How credits work" modal
- [ ] `CAP_05` — Privacy pills (Private selected)
- [ ] `CAP_05B` — Private pill selected state
- [ ] `CAP_05C` — Public pill selected state
- [ ] `CAP_06` — Quick Start screen (post-onboarding)

### Session 2: Collections & Import (7 captures)

- [ ] `CAP_07` — Collections empty state (Inbox only)
- [ ] `CAP_07B` — Collections populated (6-10 collections)
- [ ] `CAP_07C` — Quick actions bar visible
- [ ] `CAP_16` — + menu open
- [ ] `CAP_03` — iOS Share sheet with Heirloom
- [ ] `CAP_03B` — Import progress "Detecting…"
- [ ] `CAP_11` — "Saved to [Collection]" toast

### Session 3: Recipe Results (5 captures)

- [ ] `CAP_12` — Video import result with @creator
- [ ] `CAP_18` — Scan result (cookbook page → recipe)
- [ ] `CAP_10` — Generated recipe with "AI Generated" badge
- [ ] `CAP_15` — Recipe detail with source attribution
- [ ] `CAP_19` — Read aloud UI (step highlighted)

### Session 4: Sharing & Trust (7 captures)

- [ ] `CAP_04` — Share send flow (enter recipient)
- [ ] `CAP_04B` — Accept sheet (recipient view)
- [ ] `CAP_04C` — "Added to your recipe box" success
- [ ] `CAP_08` — Scan attestation "Respect creators" sheet
- [ ] `CAP_09` — Ownership verification sheet
- [ ] `CAP_13` — Discover card with creator attribution
- [ ] `CAP_14` — Publishing rules info sheet

### Session 5: Monetization (3 captures)

- [ ] `CAP_21` — Premium paywall
- [ ] `CAP_22` — Credits quota display (e.g., 15/25)
- [ ] `CAP_23` — Buy more credits sheet

### Session 6: Camera (1 capture, needs prop)

- [ ] `CAP_17` — Camera scan UI (point at cookbook page)

### Session 7: Voice Feature (3 captures, if ready)

- [ ] `CAP_V_VOICE_ENTRY` — + menu with voice option
- [ ] `CAP_V_VOICE_RECORDING` — Audio capture UI
- [ ] `CAP_V_VOICE_RESULT` — Parsed recipe from voice

---

### B-Roll to Generate/Film

- [ ] Hands over cookbook (warm light)
- [ ] Hands writing on recipe card
- [ ] Hands holding phone over food
- [ ] Kitchen counter with ingredients
- [ ] Old recipe card (Grandma narrative)
- [ ] Hands stirring pot slowly
- [ ] Flipping cookbook pages

### End Card Assets

- [ ] Heirloom logo (PNG, transparent)
- [ ] App Store badge (official Apple asset)
- [ ] Warm cream background (1080x1920)
- [ ] Warm cream background (1290x2796 for App Store)

---

### Total Capture Count

| Category | Count |
|----------|-------|
| Onboarding | 7 |
| Collections & Import | 7 |
| Recipe Results | 5 |
| Sharing & Trust | 7 |
| Monetization | 3 |
| Camera | 1 |
| Voice (optional) | 3 |
| **Total** | **33** |

### Priority Captures (minimum for launch)

If time-constrained, capture these 17 first (covers all App Store screenshots + video):

1. `CAP_02` — Credits
2. `CAP_03` — Share sheet
3. `CAP_03B` — Import progress
4. `CAP_04` — Share send
5. `CAP_04B` — Accept sheet
6. `CAP_05` — Privacy pills
7. `CAP_07B` — Collections populated
8. `CAP_10` — Generated badge
9. `CAP_11` — Saved toast
10. `CAP_12` — Video import result
11. `CAP_13` — Discover card
12. `CAP_15` — Recipe detail
13. `CAP_17` — Camera scan
14. `CAP_18` — Scan result
15. `CAP_19` — Read aloud
16. `CAP_20` — Generator input
17. `CAP_21` — Premium paywall
