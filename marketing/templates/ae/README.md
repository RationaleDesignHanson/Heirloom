# Heirloom After Effects Video Setup

Automation script to set up the complete Heirloom video production project in After Effects.

## Quick Start

1. Open After Effects
2. **File > Scripts > Run Script File...**
3. Select `heirloom_video_setup.jsx`
4. Click "Continue" when prompted
5. Import your screen captures to the `/Captures/` folder
6. Alt+drag each capture onto its matching placeholder layer (e.g., drag your CAP_03 footage onto the yellow "CAP_03" solid)
7. Render from the queue

## What the Script Creates

### Folder Structure

```
Project Panel
├── Captures/
│   └── _Placeholder_Source (helper comp with all CAP solids)
├── Compositions/
│   ├── _Blocks/
│   │   ├── _BLOCK_A_HOOK (2.5s)
│   │   ├── _BLOCK_B_BEHAVIOR (3.5s)
│   │   ├── _BLOCK_C_MAGIC (6s)
│   │   ├── _BLOCK_D_TRUST (4s)
│   │   └── _BLOCK_E_CTA (3s)
│   ├── App Store/
│   │   └── HEIRLOOM_APPSTORE_PREVIEW (30s @ 1290x2796)
│   └── Ads/
│       ├── V01_SCREENSHOTS_GRAVEYARD (15s)
│       ├── V02_EVEN_ASMR (15s)
│       ├── V03_COOKBOOK_PAGE (15s)
│       ├── V04_SCREENSHOT_A_RECIPE (15s)
│       ├── V05_PRIVATE_BY_DEFAULT (15s)
│       ├── V06_SHARE_THAT_STICKS (15s)
│       ├── V07_GENERATOR (15s)
│       ├── V08_RANGE_MONTAGE (15s)
│       ├── V09_GRANDMAS_RECIPE (30s)
│       ├── V10_FREE_DAILY_CREDITS (15s)
│       ├── V11_RESPECT_CREATORS (15s)
│       └── V12_PUBLIC_ONLY_WHEN_YOURS (15s)
├── Assets/
│   ├── Logo/
│   ├── End Card/
│   └── App Store Badge/
└── Exports/
```

### Capture Placeholders

Each placeholder is a colored solid named after the required capture:

| Capture ID | Color | Category | Duration |
|------------|-------|----------|----------|
| `CAP_02` | Yellow | Credits/premium | 5s |
| `CAP_03` | Green | Share/Import | 8s |
| `CAP_03B` | Green | Share/Import | 5s |
| `CAP_04` | Blue | P2P sharing | 6s |
| `CAP_04B` | Blue | P2P sharing | 4s |
| `CAP_05` | Purple | Privacy/visibility | 6s |
| `CAP_07B` | Orange | Collections/detail | 6s |
| `CAP_08` | Red | Attestation/ownership | 4s |
| `CAP_09` | Red | Attestation/ownership | 4s |
| `CAP_10` | Cyan | AI/generation | 5s |
| `CAP_11` | Green | Share/Import | 5s |
| `CAP_12` | Green | Share/Import | 8s |
| `CAP_13` | Purple | Privacy/visibility | 5s |
| `CAP_15` | Orange | Collections/detail | 8s |
| `CAP_17` | Teal | Scan | 6s |
| `CAP_18` | Teal | Scan | 5s |
| `CAP_20` | Cyan | AI/generation | 6s |
| `CAP_21` | Yellow | Credits/premium | 5s |

## Replacing Placeholders with Actual Footage

1. Import your screen recordings to the `/Captures/` folder in the Project panel
2. Name them to match the capture IDs (e.g., `CAP_03.mov`)
3. In a composition, select the placeholder layer you want to replace
4. **Alt+drag** (Option+drag on Mac) the actual footage from the Project panel onto the placeholder
5. The footage replaces the solid while keeping all timing and position

Alternatively:
- Right-click the placeholder layer > **Replace With Source**
- Select your imported footage

## Composition Specifications

### App Store Preview
- **Resolution:** 1290 x 2796 (iPhone 15 Pro Max)
- **Duration:** 30 seconds
- **Frame Rate:** 30 fps
- **Export:** H.264, 20 Mbps

### Ad Variants
- **Resolution:** 1080 x 1920 (9:16 vertical)
- **Duration:** 15 seconds (V09 is 30s)
- **Frame Rate:** 30 fps
- **Export:** H.264, 15 Mbps

## Safe Zones

Each composition includes magenta guide layers showing:
- **Top:** 150px (status bar area)
- **Bottom:** 100px (home indicator area)
- **Sides:** 40px each

Keep text and important elements inside these zones.

## Block Structure

All compositions use a modular 5-block structure:

| Block | Name | Duration | Purpose |
|-------|------|----------|---------|
| A | Hook | 2.5s | Attention-grabbing opener |
| B | Behavior | 3.5s | Show the problem/action |
| C | Magic | 6s | Demonstrate the solution |
| D | Trust | 4s | Build credibility |
| E | CTA | 3s | Call to action |

## Transitions

Transition markers are placed at block boundaries. To add dissolves:
1. Select both layers at a transition point
2. Apply a Cross Dissolve (8 frames = 0.27s)
3. Or use Effect > Transition > Linear Wipe for more control

## Render Queue

All compositions are added to the render queue with:
- H.264 codec (if available)
- Output naming: `[Comp Name].mp4`
- Output folder: `/Exports/` in project directory

To render:
1. **Composition > Add to Render Queue** (if not already added)
2. Verify output settings
3. Click **Render**

## Customization

### Changing Text
Text layers are named by their content. Double-click to edit the text, or modify in the Source Text property.

### Adjusting Timing
- Drag layer in/out points in the timeline
- Use markers as reference for block boundaries
- Keep total duration within spec (15s or 30s)

### Modifying Colors
Background solids use warm cream (#FAF5ED). To change:
1. Select the Background layer
2. Effect > Generate > Fill
3. Adjust color

## Troubleshooting

**"Script not allowed" error:**
- Edit > Preferences > Scripting & Expressions
- Enable "Allow Scripts to Write Files and Access Network"

**Missing fonts:**
- Default font is "SF Pro Display"
- Replace with any available sans-serif font

**Render queue issues:**
- Delete items and re-add compositions manually
- Use Adobe Media Encoder for more export options

## File References

- Capture specifications: `docs/launch/05-video-creative-production.md` Section E
- Ad scripts and timing: `docs/launch/05-video-creative-production.md` Section D
- Export settings: `docs/launch/05-video-creative-production.md` Section K
