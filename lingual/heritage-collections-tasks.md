# Heirloom Cold Start: Claude Code Implementation Guide

> **Companion Document:** This implementation guide works alongside `docs/heritage-collections-spec.md` which contains the complete design specifications. Reference the spec for detailed requirements, data schemas, and UI specifications.

---

## File Structure

```
docs/
├── heritage-collections-spec.md    ← Design specs (the "what")
├── heritage-collections-tasks.md   ← This file - Implementation tasks (the "how")
├── multilingual-import-spec.md     ← Multilingual import specs
└── multilingual-import-tasks.md    ← Multilingual import tasks (has unified CLAUDE.md)
```

---

## CLAUDE.md Setup

See `docs/multilingual-import-tasks.md` for the unified CLAUDE.md block that covers both features. Add that entire block to your project's `CLAUDE.md` file.

---

## Sequential Task Prompts

Run these as separate Claude Code sessions. Each builds on the previous.

---

### Task 1: Explore & Plan

```
Explore the current codebase structure, specifically:
1. How recipes are modeled (find the Recipe type/model)
2. How the bottom navigation/tab bar is implemented
3. Where recipe data is stored (local DB, API, etc.)
4. The current "Add" flow entry point

Then create a brief implementation plan for adding heritage collections. Save the plan to docs/heritage-collections-plan.md
```

---

### Task 2: Data Models

```
Create the heritage content data models. 
Reference: docs/heritage-collections-spec.md "Prompt 1: Seed Content Data Architecture" for full schema.

Based on the existing Recipe model, create these new types:

1. HeritageRecipe - extends Recipe with:
   - sourceType: "manuscript" | "cookbook" | "presidential" | "literary" | "ancient"
   - sourceAttribution: string (e.g., "Library of Congress")
   - historicalEra: string
   - associatedFigure?: string
   - historicalContext: string
   - engagementHook: string
   - originalText?: string (verbatim archaic text)
   - yearEstimate: number
   - isHeritage: true (discriminator)
   - images: HeritageImageSet (see below)

2. HeritageImageSet - image data for each recipe:
   - hero: ImageAsset (primary display image - AI generated or archival)
   - archival?: ImageAsset (original historical image if exists)
   - manuscript?: ImageAsset (scan of original recipe text if exists)
   - generationPrompt?: string (prompt used if AI generated, for reproducibility)

3. ImageAsset:
   - url: string (local path or CDN URL)
   - source: "ai-generated" | "library-of-congress" | "wikimedia" | "smithsonian" | "nypl" | "internet-archive" | "public-domain"
   - attribution?: string (required for archival images)
   - license: "public-domain" | "cc0" | "cc-by"
   - width: number
   - height: number
   - blurhash?: string (for loading placeholders)

4. HeritageCollection - new model:
   - id, slug, title, subtitle, description
   - accentColor: string (hex)
   - coverImageStyle: "vintage-photo" | "manuscript" | "illustration" | "painting"
   - coverImage: ImageAsset
   - recipeIds: string[]
   - curatorProfileId: string

5. FoundingCuratorProfile:
   - id, displayName, bio
   - avatarStyle: "seal" | "portrait" | "archive-stamp" | "quill"
   - avatarImage?: ImageAsset
   - isFoundingProfile: true

Put these where other models/types live in this project. Make heritage content read-only at the type level if possible.
```

---

### Task 3: Seed Data File

```
Create a seed data file at data/heritage-seed.json (or appropriate location for this project's data loading pattern).

Start with 5 recipes across 2 collections as a proof of concept:

THE PRESIDENTIAL PANTRY (3 recipes):
1. George Washington's Hoecakes - cornmeal cakes, Mount Vernon source
2. Thomas Jefferson's Vanilla Ice Cream - Library of Congress manuscript
3. Abraham Lincoln's Gingerbread Men - from his childhood story about trading chores

THE LITERARY KITCHEN (2 recipes):
1. Emily Dickinson's Coconut Cake - manuscript on back of poem, no instructions
2. Jane Austen's White Soup - from Martha Lloyd's Household Book, mentioned in Pride & Prejudice

Each recipe needs:
- originalText (archaic language)
- ingredients with both original and modern equivalents
- modernized step-by-step instructions
- historicalContext (2-3 sentences)
- engagementHook (shareable one-liner)
- images: placeholder structure (to be filled by image tasks):
  {
    "hero": null,       // Will be AI-generated or sourced
    "thumbnail": null,  // Generated from hero
    "archival": null,   // If historical image exists
    "manuscript": null  // If original document scan exists
  }
- imageSearchHints: keywords to help image sourcing script
  (e.g., ["Thomas Jefferson", "Monticello", "colonial ice cream", "18th century dessert"])

Include the collection and curator profile definitions too.

Collection entries need:
- coverImage: null (to be generated)
- coverImagePrompt: description for AI generation
  (e.g., "White House state dining room, 1900s formal dinner, sepia photograph style")
```

---

### Task 3B: Image Sourcing Script

```
Create a script at scripts/source-heritage-images.ts (or .js) that searches public domain archives for recipe imagery.
Reference: docs/heritage-collections-spec.md "Image Strategy" section for source priority and style guidelines.

The script should:

1. Read heritage-seed.json and extract recipe metadata (title, associatedFigure, yearEstimate, historicalEra)

2. For each recipe, search these APIs/sources in order:
   
   a) Library of Congress API (loc.gov/pictures/api)
      - Search: "{associatedFigure}" OR "{recipe title}" + "food" + era
      - Filter: access-restricted=false
      - Example: "Thomas Jefferson" + "dining" + "1800s"
   
   b) Wikimedia Commons API
      - Search categories: Historical_food, {Era}_cuisine, {Figure}_images
      - Filter: License = PD or CC0
   
   c) Smithsonian Open Access API
      - Search their food/domestic life collections
   
   d) NYPL Digital Collections
      - Menu and cookbook collections
   
   e) Internet Archive
      - Search for cookbook scans matching the source attribution

3. For each result, save:
   - Thumbnail URL and full-res URL
   - Source archive name
   - Attribution/credit line
   - License confirmation
   - Relevance score (how well it matches)

4. Output to: data/heritage-images-sourced.json
   Structure:
   {
     "recipeId": {
       "candidates": [
         { url, source, attribution, license, relevanceScore, width, height }
       ],
       "selected": null  // to be filled in manually or by next task
     }
   }

5. Log recipes with no good matches (these need AI generation)

Include rate limiting and caching to avoid hammering APIs.
```

---

### Task 3C: Image Generation for Missing Recipes

```
Create a script at scripts/generate-heritage-images.ts that generates AI images for recipes without archival imagery.
Reference: docs/heritage-collections-spec.md "Image Strategy > AI Generation Prompts" for prompt templates and style by collection.

Setup:
- Use Google Imagen API (via Vertex AI) as primary
- Fallback: Use a local Stable Diffusion API if available
- Read GOOGLE_API_KEY from environment

The script should:

1. Read heritage-seed.json and heritage-images-sourced.json
2. Find recipes where sourced images are missing or low quality

3. For each recipe needing generation, construct a prompt:

   Base prompt template:
   "{dish_name}, {era} era, painted in warm nostalgic style, 
   vintage cookbook illustration aesthetic, soft lighting, 
   {cultural_context}, NOT modern food photography, 
   painterly brushstrokes, muted earth tones, 
   reminiscent of {artistic_reference}"

   Artistic references by collection:
   - Presidential: "Norman Rockwell Americana"
   - Literary: "Victorian still life painting"
   - Ancient: "classical Roman fresco or medieval illuminated manuscript"
   - American Foundation: "WPA-era American folk art"

   Example for Jefferson's Ice Cream:
   "Vanilla ice cream in ornate silver serving dish, 1780s Federal era,
   painted in warm nostalgic style, vintage cookbook illustration aesthetic,
   soft candlelight, Monticello dining room setting, NOT modern food photography,
   painterly brushstrokes, muted earth tones, reminiscent of Colonial American portraiture"

4. Call Imagen API with:
   - aspectRatio: "4:3" (for recipe cards)
   - numberOfImages: 3 (pick best)
   - negativePrompt: "modern, photograph, studio lighting, white background, 
     plastic, contemporary plating, Instagram style"

5. Save generated images to: assets/heritage-images/generated/{recipe-id}.png

6. Update heritage-images-sourced.json with:
   - Generated image path
   - source: "ai-generated"
   - generationPrompt: the exact prompt used
   - license: "generated" (we own it)

7. Create a review manifest at data/heritage-images-review.json listing all 
   generated images for human QA before shipping.

Include retry logic and cost tracking (log API calls made).
```

---

### Task 3D: Image Processing Pipeline

```
Create scripts/process-heritage-images.ts to prepare all images for the app.
Reference: docs/heritage-collections-spec.md "Image Strategy > Image Variants Required" for dimensions and formats.

This script should:

1. Read the finalized image selections from heritage-images-sourced.json

2. For each image (both sourced and generated):

   a) Download/copy to assets/heritage-images/{recipe-id}/
   
   b) Generate variants:
      - hero.jpg: 1200x900 (4:3) main display image
      - thumbnail.jpg: 400x300 for grid views
      - card.jpg: 800x600 for collection cards
   
   c) Optimize:
      - Convert to WebP with JPEG fallback
      - Quality: 85% for hero, 80% for others
      - Strip metadata
   
   d) Generate blurhash for each image (for loading placeholders)
   
   e) If archival manuscript image exists, process separately:
      - manuscript.jpg: preserve aspect ratio, max 1600px wide
      - Enhance contrast slightly for readability

3. Update heritage-seed.json with complete image paths:
   {
     "images": {
       "hero": {
         "url": "assets/heritage-images/jefferson-ice-cream/hero.webp",
         "fallback": "assets/heritage-images/jefferson-ice-cream/hero.jpg",
         "source": "ai-generated",
         "generationPrompt": "...",
         "width": 1200,
         "height": 900,
         "blurhash": "LEHV6nWB2yk8pyo0adR*.7kCMdnj"
       },
       "thumbnail": { ... },
       "archival": null,
       "manuscript": null
     }
   }

4. Generate a manifest of all images with total size for app bundle planning

Dependencies: sharp (image processing), blurhash (placeholder generation)
```

---

### Task 3E: Collection Cover Images

```
Generate or source cover images for each of the 4 heritage collections.

For each collection, we need a distinct visual identity:

1. THE PRESIDENTIAL PANTRY
   - Style: Sepia-toned vintage photograph aesthetic
   - Imagery: White House dining room, presidential china, formal table setting
   - Search: LOC for "White House dining" or generate with:
     "White House state dining room, 1900s, formal dinner table setting,
     crystal and silver, sepia photograph style, historical American grandeur"

2. THE LITERARY KITCHEN
   - Style: Handwritten manuscript aesthetic
   - Imagery: Recipe written on aged paper, quill and ink, kitchen scene
   - Generate: "Handwritten recipe on aged parchment paper, 19th century script,
     ink splatters, pressed flowers, vintage kitchen implements in background,
     warm candlelight, Jane Austen era aesthetic"

3. THE ANCIENT TABLE
   - Style: Classical illustration/fresco
   - Imagery: Roman feast scene, medieval banquet, ancient pottery
   - Search: Wikimedia for Roman feast frescoes or generate:
     "Ancient Roman dining scene, triclinium with reclining figures,
     terracotta pottery, figs and wine, painted in classical fresco style,
     warm Mediterranean colors, Pompeii wall painting aesthetic"

4. THE AMERICAN FOUNDATION  
   - Style: Warm sepia archival photograph
   - Imagery: Southern kitchen, cookbook pages, family gathering
   - Search: Smithsonian African American history collection or generate:
     "1880s Southern kitchen scene, cast iron stove, family recipe book open,
     warm hearth light, African American culinary heritage, WPA documentary
     photography style, sepia tones, intimate domestic scene"

Save to: assets/heritage-images/collections/{collection-slug}-cover.webp
Size: 1600x900 (16:9 for collection headers)

Update heritage-seed.json collection entries with coverImage field.
```

---

### Task 4: Seed Data Loading

```
Implement loading the heritage seed data:

1. Find where this app initializes its data/database
2. Add a function to load heritage-seed.json on first launch
3. Heritage content should be:
   - Loaded once, not re-seeded on every launch
   - Stored alongside user recipes but marked as heritage
   - Read-only (users can't edit, only "save a copy")

Check if there's a migration or initialization pattern already in use and follow it.
```

---

### Task 5: Bottom Nav - Add → Collections

```
Change the bottom navigation.
Reference: docs/heritage-collections-spec.md "Prompt 3: Bottom Bar UI Transformation" for full UI requirements.

1. Find the bottom tab bar component
2. Replace the "Add" tab with "Collections":
   - New icon: use a collections/folder-stack icon (check what icon library is in use)
   - Label: "Collections"
   - Route to a new CollectionsScreen

3. Create a basic CollectionsScreen that shows:
   - "Heritage Collections" section header
   - List/grid of the 4 collection cards (title, subtitle, recipe count)
   - "My Collections" section header  
   - Empty state: "Your collections will appear here"

Keep it simple for now - just navigation working and basic list rendering.
```

---

### Task 6: Collection Detail View

```
Create the collection detail screen (when you tap a collection).
Reference: docs/heritage-collections-spec.md "Prompt 3: Bottom Bar UI Transformation" section 3 for detail view specs.

1. Header with:
   - Collection title and subtitle
   - Accent color as background tint
   - Recipe count
   - For heritage: curator attribution

2. Recipe grid/list showing all recipes in collection

3. For heritage collections:
   - Add a "Save to My Recipes" button
   - Recipes are read-only (navigate to detail but can't edit)

4. For user collections (future):
   - Edit button in header
   - Reorder capability (can stub this)

Wire up the navigation: Collections tab → tap collection → this detail screen
```

---

### Task 7: Heritage Recipe Dual View

```
Modify the recipe detail screen to support heritage recipes with rich imagery.
Reference: docs/heritage-collections-spec.md "Prompt 5: Heritage Recipe Display" for complete dual-view interface specs.

1. Detect if recipe.isHeritage === true

2. HERO IMAGE DISPLAY:
   - Show recipe.images.hero as full-bleed header image
   - Use blurhash placeholder while loading
   - Support WebP with JPEG fallback
   - Parallax scroll effect (optional but nice)
   - Overlay gradient at bottom for text legibility

3. If heritage, add a view toggle: [Artifact] [Kitchen]
   
   ARTIFACT VIEW:
   - If recipe.images.manuscript exists, show it prominently
   - Display originalText with serif/manuscript styling below
   - If recipe.images.archival exists, show in a "From the Archives" section
   - Include source attribution with link if available
   
   KITCHEN VIEW:
   - Normal modernized instructions
   - Hero image remains visible
   - Standard ingredient list and steps

4. Add heritage-specific header elements:
   - Collection badge linking back to collection
   - Associated figure name and year
   - Historical context (expandable)
   - Image attribution line (small text): "Image: Library of Congress" or "Illustrated for Heirloom"

5. Add a CTA footer on heritage recipes:
   "This recipe is from [year]. Do you have a family version? [+ Add Yours]"

6. Hide edit/delete actions for heritage recipes, show "Save Copy" instead

7. IMAGE CACHING:
   - Heritage images should be bundled with app OR
   - Cached aggressively on first load (they never change)
   - Show blurhash immediately, fade in full image
```

---

### Task 8: FAB for Add Recipe

```
Since "Add" is no longer a bottom tab, add a Floating Action Button:

1. Create a FAB component (or use existing from UI library)
   - Position: bottom-right, above tab bar
   - Icon: "+"
   
2. Show FAB on these screens:
   - Home/main recipe list
   - Collection detail (user collections)
   - NOT on: Recipe detail, Settings, already-has-add-flow screens

3. FAB tap → opens existing Add Recipe flow

4. Optional enhancement: In collection detail, FAB could pre-select that collection
```

---

### Task 9: Bulk Selection Mode

```
Add bulk organization to collection detail view.
Reference: docs/heritage-collections-spec.md "Prompt 4: Bulk Organization in Collections Mode" for complete action list and UI states.

1. Add "Select" button to collection header (or long-press to enter selection mode)

2. Selection mode UI:
   - Checkboxes overlay on each recipe card
   - Header changes to: "[X] Cancel | N selected | Select All"
   - Bottom action bar appears

3. Bulk actions (bottom bar when items selected):
   - For user collections: Move | Copy | Remove | Delete
   - For heritage collections: Save to My Recipes | Share
   
4. Implement "Save to My Recipes" action:
   - Copies selected heritage recipes to user's collection
   - Shows confirmation toast

Stub out Move/Copy/Remove for now - just the UI and action triggers.
```

---

### Task 10: Expand Seed Data

```
Expand heritage-seed.json to include more recipes. Add:

THE PRESIDENTIAL PANTRY (add 5 more):
- Eisenhower's Vegetable Soup
  imageSearchHints: ["Eisenhower", "1950s kitchen", "hearty soup"]
  
- Lady Bird Johnson's Pedernales River Chili  
  imageSearchHints: ["Texas chili", "LBJ ranch", "1960s"]
  
- FDR's Grilled Cheese
  imageSearchHints: ["1930s comfort food", "Depression era", "simple sandwich"]
  
- Mary Todd Lincoln's White Almond Cake
  imageSearchHints: ["Victorian cake", "1860s", "White House entertaining"]
  
- Dolley Madison's Layer Cake
  imageSearchHints: ["Federal era", "1800s cake", "early American entertaining"]

THE ANCIENT TABLE (new collection, 5 recipes):
- Apicius: Honey Glazed Dates (Dulcia Domestica) - Rome
  imageSearchHints: ["Roman food", "ancient dates", "honey", "Pompeii fresco"]
  
- Apicius: Patina of Pears - Rome
  imageSearchHints: ["Roman dessert", "pears", "ancient pottery"]
  
- Forme of Cury: Makerouns (medieval mac & cheese) - 14th c. England
  imageSearchHints: ["medieval food", "14th century", "cheese dish", "illuminated manuscript"]
  
- Forme of Cury: Looseyns (medieval lasagna) - 14th c. England
  imageSearchHints: ["medieval pasta", "layered dish", "Richard II court"]
  
- Mayan Hot Chocolate - ancient Americas
  imageSearchHints: ["Mayan cacao", "ancient chocolate", "Pre-Columbian", "ceremonial drink"]

Include curator profile for Ancient Table:
- avatarStyle: "illustration"
- avatarImagePrompt: "Ancient Roman seal or medieval manuscript illumination, circular format"

Collection cover for Ancient Table:
- coverImagePrompt: "Ancient Roman triclinium feast scene, terracotta pottery, figs and wine, 
  classical fresco style, warm Mediterranean colors, Pompeii wall painting aesthetic"

After adding recipes, run the image sourcing script (Task 3B) for new entries.
```

---

## Quick Reference: Measurement Conversions for Recipes

When modernizing archaic recipes, use these conversions:

| Historical Term | Modern Equivalent |
|-----------------|-------------------|
| Butter size of walnut | 1 tablespoon |
| Butter size of egg | 2 tablespoons |
| Gill | ½ cup (4 oz) |
| Slow oven | 300°F |
| Moderate oven | 350°F |
| Quick oven | 400-425°F |
| Pearlash | Baking soda (use less) |
| Saleratus | Baking soda |
| Wine-glass | ¼ cup |
| Teacup | ¾ cup |

---

## Testing Checklist

After implementation, verify:

- [ ] Collections tab appears in bottom nav
- [ ] 4 heritage collections display with cover images
- [ ] Collection covers load with blurhash placeholders
- [ ] Tapping collection opens detail with recipes
- [ ] Recipe cards show thumbnail images
- [ ] Heritage recipes show hero image in detail view
- [ ] Hero images have parallax/fade effect on scroll
- [ ] Heritage recipes show dual view toggle
- [ ] Original text displays in Artifact view
- [ ] Manuscript images display when available in Artifact view
- [ ] Modern instructions display in Kitchen view
- [ ] Image attribution displays correctly
- [ ] FAB appears and opens Add flow
- [ ] Selection mode activates in collections
- [ ] "Save to My Recipes" copies heritage recipes (without images initially, or with)
- [ ] Heritage recipes cannot be edited directly
- [ ] User collections section shows (empty state ok)
- [ ] Images are cached after first load
- [ ] Blurhash placeholders appear during image load

---

## API Setup Requirements

### Google Cloud (for Imagen API)

```bash
# 1. Enable Vertex AI API in Google Cloud Console
# 2. Create service account with Vertex AI User role
# 3. Set environment variable
export GOOGLE_API_KEY="your-api-key"
# OR for Vertex AI specifically:
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
export GOOGLE_CLOUD_PROJECT="your-project-id"
```

### Archive API Keys (optional but recommended)

```bash
# Library of Congress - no key needed, but rate limited
# Wikimedia Commons - no key needed

# Smithsonian Open Access
export SMITHSONIAN_API_KEY="your-key"  # Get from api.si.edu

# NYPL Digital Collections  
export NYPL_API_KEY="your-key"  # Get from api.repo.nypl.org
```

### Local Development

For local dev without API keys, the scripts should:
1. Skip image generation and use placeholder images
2. Log which recipes need images
3. Allow manual image placement in assets folder

---

## Image Asset Budget

Estimated sizes for app bundle planning:

| Asset Type | Count | Size Each | Total |
|------------|-------|-----------|-------|
| Collection covers | 4 | ~200KB | ~800KB |
| Recipe heroes | 100 | ~150KB | ~15MB |
| Recipe thumbnails | 100 | ~30KB | ~3MB |
| Manuscript scans | ~20 | ~100KB | ~2MB |
| **Total** | | | **~21MB** |

Consider:
- Bundling only first 20 recipes, lazy-load rest
- Using CDN for images instead of bundling
- Offering "Download Heritage Collection" as optional
