# Heirloom App: Cold Start Solution & Collections UI
## Complete Design Specification

> **This document is the source of truth for design decisions.** The companion implementation guide (`heritage-collections-tasks.md`) references sections here for detailed specs.

---

## Context

Heirloom is a recipe preservation app focused on nostalgia, intergenerational connection, and culinary heritage. Unlike utility-driven recipe apps, Heirloom emphasizes the story and legacy behind recipes. The app faces a "cold start" problem: users hesitate to contribute personal recipes to a platform that feels empty or transactional.

**Solution:** Launch with a curated "seed" library of 100 public domain historical recipes organized into discoverable collections. These recipes establish the app's tone of reverence and cultural significance, validating users' own preservation efforts by placing their grandmother's recipes alongside Thomas Jefferson's ice cream.

---

## Image Strategy

### Philosophy
Heritage recipes need visual treatment that feels authentic to their era—NOT modern food photography. Images should evoke nostalgia, warmth, and historical weight. Each collection has a distinct visual identity.

### Image Sources (Priority Order)
1. **Public Domain Archives** (preferred for authenticity)
   - Library of Congress (loc.gov/pictures/api)
   - Wikimedia Commons (commons.wikimedia.org/w/api.php)
   - Smithsonian Open Access (api.si.edu)
   - NYPL Digital Collections (api.repo.nypl.org)
   - Internet Archive (archive.org)

2. **AI Generation** (for recipes without archival imagery)
   - Google Imagen API via Vertex AI (primary)
   - Stable Diffusion (fallback/local)

### Visual Style by Collection

| Collection | Style | Color Palette | Reference |
|------------|-------|---------------|-----------|
| Presidential Pantry | Sepia vintage photograph | Deep reds, golds, warm browns | Norman Rockwell Americana |
| Literary Kitchen | Handwritten manuscript | Ink blacks, aged cream, slate | Victorian still life |
| Ancient Table | Classical fresco/illustration | Terracotta, Mediterranean blues | Pompeii wall paintings |
| American Foundation | WPA documentary photography | Warm amber, hearth oranges | Depression-era photography |

### AI Generation Prompts

**Base Template:**
```
{dish_name}, {era} era, painted in warm nostalgic style, 
vintage cookbook illustration aesthetic, soft lighting, 
{cultural_context}, NOT modern food photography, 
painterly brushstrokes, muted earth tones, 
reminiscent of {artistic_reference}
```

**Negative Prompt (always include):**
```
modern, photograph, studio lighting, white background, 
plastic, contemporary plating, Instagram style, 
stock photo, bright colors, minimalist
```

**Example - Jefferson's Ice Cream:**
```
Vanilla ice cream in ornate silver serving dish, 1780s Federal era,
painted in warm nostalgic style, vintage cookbook illustration aesthetic,
soft candlelight, Monticello dining room setting, NOT modern food photography,
painterly brushstrokes, muted earth tones, reminiscent of Colonial American portraiture
```

### Image Variants Required

| Variant | Dimensions | Aspect | Use Case |
|---------|------------|--------|----------|
| hero | 1200×900 | 4:3 | Recipe detail header |
| card | 800×600 | 4:3 | Collection grid |
| thumbnail | 400×300 | 4:3 | Lists, search results |
| collection-cover | 1600×900 | 16:9 | Collection header |
| manuscript | max 1600w | preserve | Original document scans |

### Image Processing Pipeline

1. **Download/Source** → Original from archive or AI
2. **Resize** → Generate all variants
3. **Optimize** → WebP (85% quality) + JPEG fallback
4. **Blurhash** → Generate placeholder hash for each
5. **Manifest** → Update seed data with paths

### Blurhash Implementation
Every image needs a blurhash for loading placeholders:
- Generate using `blurhash` library
- Store as string in image metadata
- Display immediately while full image loads
- Fade transition when image ready

---

## Prompt 1: Seed Content Data Architecture

```
TASK: Define the data model for Heirloom's seed content system

CONTEXT:
Heirloom needs to launch with pre-populated "heritage" recipes from the public domain. These recipes serve as templates showing users how to organize and present their own family recipes. They must feel like authentic preserved heirlooms, not generic database entries.

REQUIREMENTS:

1. Create a `HeritageRecipe` model that extends the existing Recipe model with:
   - `sourceType`: enum ["manuscript", "cookbook", "presidential", "literary", "ancient"]
   - `sourceAttribution`: string (e.g., "Library of Congress", "National Archives")
   - `historicalEra`: string (e.g., "Civil War", "Gilded Age", "Medieval", "Ancient Rome")
   - `associatedFigure`: optional string (e.g., "Thomas Jefferson", "Emily Dickinson")
   - `historicalContext`: string - 2-3 sentence narrative about the recipe's significance
   - `engagementHook`: string - shareable one-liner (e.g., "Eat the breakfast that built the nation")
   - `originalText`: optional string - verbatim archaic text if available
   - `isModernized`: boolean - whether instructions have been adapted
   - `yearEstimate`: number - approximate year of origin
   - `publicDomainJustification`: string - legal basis (pre-1930, government work, etc.)
   - `images`: HeritageImageSet - all image variants for this recipe
   - `imageSearchHints`: string[] - keywords for archive searches

2. Create `HeritageImageSet` model:
   - `hero`: ImageAsset - primary display image (AI generated or archival)
   - `thumbnail`: ImageAsset - grid/list display
   - `card`: ImageAsset - collection card display
   - `archival`: optional ImageAsset - original historical image if exists
   - `manuscript`: optional ImageAsset - scan of original recipe document
   - `generationPrompt`: optional string - prompt used if AI generated

3. Create `ImageAsset` model:
   - `url`: string - local path or CDN URL
   - `fallbackUrl`: optional string - JPEG fallback for WebP
   - `source`: enum ["ai-generated", "library-of-congress", "wikimedia", "smithsonian", "nypl", "internet-archive", "public-domain"]
   - `attribution`: optional string - required for archival images
   - `license`: enum ["public-domain", "cc0", "cc-by", "generated"]
   - `width`: number
   - `height`: number
   - `blurhash`: string - loading placeholder hash

4. Create a `HeritageCollection` model:
   - `id`: string
   - `slug`: string (e.g., "presidential-pantry")
   - `title`: string (e.g., "The Presidential Pantry")
   - `subtitle`: string (e.g., "White House Favorites from Washington to Obama")
   - `description`: string - collection narrative
   - `coverImageStyle`: enum ["vintage-photo", "illustration", "manuscript", "painting"]
   - `coverImage`: ImageAsset - collection header image
   - `coverImagePrompt`: string - AI generation prompt for cover
   - `accentColor`: string - hex color for collection theming
   - `recipeIds`: string[] - ordered list of recipes
   - `curatorProfile`: reference to a "Founding User Profile"
   - `featured`: boolean - whether to highlight on home screen

5. Create `FoundingUserProfile` model (simulated heritage accounts):
   - `id`: string
   - `displayName`: string (e.g., "The Presidential Pantry")
   - `avatarStyle`: enum ["seal", "portrait", "archive-stamp", "quill"]
   - `avatarImage`: optional ImageAsset
   - `bio`: string
   - `collectionIds`: string[]
   - `isFoundingProfile`: boolean (always true, distinguishes from real users)

IMPLEMENTATION NOTES:
- Heritage recipes should be seeded from a JSON file at build time or first launch
- Collections should feel like browsing a curated museum exhibition
- Original archaic text should be preservable alongside modernized instructions
- All heritage content is read-only (users cannot edit seed recipes)
```

---

## Prompt 2: The Four Founding Collections

```
TASK: Implement the four seed collections for Heirloom's launch

CONTEXT:
Based on the cold start strategy, create these four collections that will populate the app at launch. Each represents a distinct narrative angle on culinary heritage.

COLLECTIONS:

1. THE PRESIDENTIAL PANTRY
   - Slug: "presidential-pantry"
   - Subtitle: "White House Favorites from Washington to Obama"
   - Description: "Food humanizes history. These recipes come from presidential archives, letters, and official White House records—offering a taste of how America's leaders ate, from George Washington's hoecakes swimming in butter to Lady Bird Johnson's legendary chili."
   - Accent Color: #8B0000 (deep presidential red)
   - Cover Style: vintage-photo (sepia toned White House imagery)
   - Recipe Count: ~20 recipes
   - Key Recipes to Include:
     • George Washington's Hoecakes
     • Thomas Jefferson's Vanilla Ice Cream
     • Abraham Lincoln's Gingerbread Men
     • Dwight D. Eisenhower's Vegetable Soup
     • Lady Bird Johnson's Pedernales River Chili
     • FDR's Grilled Cheese ("The Roosevelt Special")

2. THE LITERARY KITCHEN
   - Slug: "literary-kitchen"
   - Subtitle: "Recipes from the Diaries and Letters of Famous Authors"
   - Description: "Writers nourish more than minds. Discover what Emily Dickinson baked for neighborhood children, the cheese toast Jane Austen craved, and the American foods Mark Twain desperately missed while abroad."
   - Accent Color: #2F4F4F (ink/slate green)
   - Cover Style: manuscript (handwritten recipe aesthetic)
   - Recipe Count: ~20 recipes
   - Key Recipes to Include:
     • Emily Dickinson's Coconut Cake
     • Jane Austen's Toasted Cheese
     • Jane Austen's White Soup (from Pride & Prejudice)
     • Mark Twain's Hot Buckwheat Cakes
     • Claude Monet's Cherry Clafoutis

3. THE ANCIENT TABLE
   - Slug: "ancient-table"
   - Subtitle: "Strange & Fascinating Recipes from Antiquity"
   - Description: "What did a Roman centurion eat? How did medieval peasants flavor their food? These recipes span millennia—from honey-glazed dates in ancient Rome to 14th-century 'Makerouns' (the original mac and cheese)."
   - Accent Color: #8B4513 (terracotta/ancient pottery)
   - Cover Style: illustration (ancient cookbook/scroll aesthetic)
   - Recipe Count: ~15 recipes
   - Key Recipes to Include:
     • Apicius: Honey Glazed Dates (Dulcia Domestica)
     • Apicius: Patina of Pears
     • Forme of Cury: Makerouns (Medieval Mac & Cheese)
     • Forme of Cury: Looseyns (Medieval Lasagna)
     • Mayan Hot Chocolate

4. THE AMERICAN FOUNDATION
   - Slug: "american-foundation"
   - Subtitle: "Voices from America's Earliest Cookbooks"
   - Description: "These recipes preserve the culinary genius of pioneers who shaped American food. From Abby Fisher—a formerly enslaved woman who couldn't read or write but won medals for her pickles—to Rosa Parks' featherlight pancakes, discovered on an envelope in the Library of Congress."
   - Accent Color: #CD853F (warm amber/honey)
   - Cover Style: vintage-photo (sepia archival documents)
   - Recipe Count: ~20 recipes
   - Key Recipes to Include:
     • Abby Fisher's Fried Chicken
     • Abby Fisher's Sweet Potato Pie
     • Abby Fisher's Jumberlie (Jambalaya)
     • Malinda Russell's Washington Cake
     • Rosa Parks' Featherlight Pancakes
     • Mary Randolph's "Gaspacha"
     • Election Cake (Suffrage Cookbook)

IMPLEMENTATION NOTES:
- Each collection should have a distinct visual identity
- Collections appear as the primary content in the new "Collections" tab
- The "featured" flag can rotate which collection is highlighted
- Consider seasonal relevance (e.g., feature Presidential Pantry near July 4th)
```

---

## Prompt 3: Bottom Bar UI Transformation (Add → Collections)

```
TASK: Transform the bottom navigation "Add" tab into a "Collections" tab

CURRENT STATE:
The bottom navigation bar has an "Add" button/tab that likely opens a flow to add new recipes.

NEW STATE:
Replace "Add" with "Collections" - a browsing interface for both heritage collections AND user-created collections.

UI REQUIREMENTS:

1. BOTTOM BAR CHANGES:
   - Icon: Change from "+" to a collections icon (stacked squares, folder stack, or bookshelf)
   - Label: "Collections" (not "Add")
   - The "Add Recipe" action moves to:
     a. A FAB (floating action button) that appears contextually
     b. The "..." overflow menu on recipe cards
     c. Long-press gestures where appropriate
     d. An "Add" option within each collection view

2. COLLECTIONS TAB STRUCTURE:
   
   [Header Section]
   - "Collections" title
   - Optional: Filter chips (All | Heritage | My Collections)
   
   [Heritage Collections Section]
   - Section header: "Heritage Collections" with subtle "What's this?" tooltip
   - Horizontal scroll or 2-column grid of the 4 founding collections
   - Each collection card shows:
     • Cover image with collection's visual style
     • Title
     • Subtitle
     • Recipe count badge
     • Accent color accent/border
   
   [My Collections Section]  
   - Section header: "My Collections" 
   - "Create Collection" card as first item (with + icon)
   - User's personal collections displayed same style as heritage
   - Empty state: "Your collections will appear here. Save family recipes together by theme, occasion, or origin."
   
   [Recently Added Section] (optional)
   - Section header: "Recently Saved"
   - Horizontal scroll of recent recipe cards
   - Quick access without navigating to full collection

3. COLLECTION DETAIL VIEW:
   When tapping a collection:
   - Hero header with collection cover, title, subtitle
   - Description text (expandable if long)
   - Curator attribution for heritage collections (e.g., "Curated by The Presidential Pantry")
   - Recipe grid/list with ability to toggle view
   - For user collections: Edit button in header
   - For heritage collections: "Save to My Recipes" bulk action

4. VISUAL TREATMENT:
   - Heritage collections should feel "special" - slight visual distinction
   - Consider a subtle seal/badge on heritage content
   - User collections should feel personal and customizable
   - Maintain warm, nostalgic Heirloom aesthetic throughout

NAVIGATION FLOW:
- Tab Bar → Collections Tab → Collection List View
- Collection List → Tap Collection → Collection Detail View
- Collection Detail → Tap Recipe → Recipe Detail View
- Recipe Detail → "..." menu → Add to Collection / Edit / Share / etc.
```

---

## Prompt 4: Bulk Organization in Collections Mode

```
TASK: Implement bulk organization features for Collections

CONTEXT:
When viewing a collection (especially user-created ones), users need to efficiently manage multiple recipes at once. This is the "bulk organization" capability mentioned for Collections mode.

BULK ACTIONS TO SUPPORT:

1. SELECTION MODE:
   - Trigger: "Select" button in collection header OR long-press on any recipe
   - Visual: Checkbox overlay on each recipe card
   - Selection counter in header: "3 selected"
   - "Select All" / "Deselect All" quick actions

2. BULK ACTIONS TOOLBAR:
   When items are selected, show a bottom action bar with:
   
   For User Collections:
   - "Move to..." → Opens collection picker modal
   - "Copy to..." → Duplicates recipes to another collection
   - "Remove" → Remove from THIS collection (doesn't delete recipe)
   - "Delete" → Permanently delete selected recipes (with confirmation)
   - "Share" → Share selected recipes as a group
   
   For Heritage Collections (read-only):
   - "Save to My Recipes" → Copy to user's personal collection
   - "Share" → Share selected heritage recipes
   
   Additional bulk actions:
   - "Add Tags" → Bulk-apply tags to selected recipes
   - "Set Category" → Bulk-assign to a category (Breakfast, Dessert, etc.)
   - "Export" → Export selected as PDF/printable format

3. DRAG-TO-REORDER:
   - Within user collections, allow drag handles to reorder recipes
   - Visual feedback: Lift effect on dragged item, insertion indicator
   - Auto-scroll when dragging near edges
   - Save order automatically on release

4. COLLECTION MANAGEMENT (for user collections):
   - Edit collection: Title, description, cover image
   - Delete collection: Confirm, ask about orphaned recipes
   - Merge collections: Combine two collections
   - Split collection: Select items to move to new collection

5. QUICK FILTERS IN COLLECTION VIEW:
   - Filter by: Era, Difficulty, Tags, Favorites
   - Sort by: Date Added, Name, Year (for heritage), Custom Order
   - Search within collection

UI IMPLEMENTATION:

[Normal Collection View]
┌─────────────────────────────┐
│ [<] Collection Name    [⋮]  │  ← Overflow has: Edit, Select, Share, Delete
│     Subtitle               │
├─────────────────────────────┤
│ [Recipe] [Recipe] [Recipe]  │
│ [Recipe] [Recipe] [Recipe]  │
└─────────────────────────────┘

[Selection Mode Active]
┌─────────────────────────────┐
│ [✕] 3 selected    [Select All] │
├─────────────────────────────┤
│ [☑Recipe] [☐Recipe] [☑Recipe] │
│ [☑Recipe] [☐Recipe] [☐Recipe] │
├─────────────────────────────┤
│ [Move] [Copy] [Remove] [⋮]  │  ← Bulk action toolbar
└─────────────────────────────┘

EDGE CASES:
- Cannot bulk-edit heritage recipes (only save copies)
- Removing last recipe from collection: Prompt to delete or keep empty collection
- Moving recipes between collections: Maintain original in source? (Copy vs Move)
- Undo support for bulk actions (snackbar with "Undo" option)
```

---

## Prompt 5: Heritage Recipe Display (Dual-View Interface)

```
TASK: Implement the dual-view interface for heritage recipes

CONTEXT:
Historical recipes often have charming archaic language ("Take a piece of butter the size of a walnut", "Bake in a quick oven") that is part of their appeal but not usable. Heritage recipes need two views: the original artifact and the modernized kitchen version.

DUAL-VIEW REQUIREMENTS:

1. ARTIFACT VIEW (The "Heirloom" View):
   - Display original archaic text verbatim
   - Typography: Serif font, slightly aged/manuscript aesthetic
   - Optional: Scan/image of original document if available
   - Source attribution prominently displayed
   - "Historical Context" section with narrative
   - Visual treatment: Aged paper background, subtle texture
   
   Example display:
   ┌─────────────────────────────────┐
   │ 📜 ORIGINAL TEXT                │
   │                                 │
   │ "Take 2 bottles of good cream,  │
   │  6 yolks of eggs, ½ lb of       │
   │  sugar, put it in moulds,       │
   │  justling it well down on       │
   │  the knee..."                   │
   │                                 │
   │ — Thomas Jefferson, c. 1780     │
   │   Library of Congress           │
   └─────────────────────────────────┘

2. KITCHEN VIEW (The Modernized View):
   - Converted measurements (standard cups/tsp/etc.)
   - Clear step-by-step instructions
   - Modern ingredient substitutions noted
   - Temperature in °F (with °C toggle)
   - Estimated time
   - Normal recipe card styling
   
   Conversion Reference:
   - "Butter the size of a walnut" → 1 tablespoon
   - "Gill" → ½ cup (4 oz)
   - "Slow oven" → 300°F
   - "Quick oven" → 400-425°F
   - "Pearlash" / "Saleratus" → Baking soda (reduce quantity)

3. VIEW TOGGLE:
   - Segmented control or tab at top of recipe: [Artifact] [Kitchen]
   - Default to Kitchen view (more usable)
   - Remember user's preference per session
   - Smooth animation between views

4. HERITAGE RECIPE HEADER:
   - Collection badge: "From The Presidential Pantry"
   - Associated figure with small portrait/silhouette if available
   - Year/era badge
   - Engagement hook as pull quote
   
   Example:
   ┌─────────────────────────────────┐
   │ [🏛 Presidential Pantry]        │
   │                                 │
   │ VANILLA ICE CREAM               │
   │ Thomas Jefferson · c. 1780      │
   │                                 │
   │ "Jefferson popularized ice      │
   │  cream in America after his     │
   │  diplomatic service in France"  │
   │                                 │
   │ [Artifact] [Kitchen ✓]          │
   └─────────────────────────────────┘

5. CALL-TO-ACTION FOOTER:
   Every heritage recipe ends with a prompt encouraging user contribution:
   
   ┌─────────────────────────────────┐
   │ This recipe is from 1780.       │
   │ Do you have a family ice cream  │
   │ recipe? Save yours to compare.  │
   │                                 │
   │ [+ Add Your Version]            │
   └─────────────────────────────────┘

6. SHARING TREATMENT:
   - Share card includes engagement hook
   - Visual: Heritage badge/frame
   - Link back to collection in app
```

---

## Prompt 6: Recipe Add Flow Relocation

```
TASK: Relocate the "Add Recipe" flow since "Add" is no longer a bottom tab

CONTEXT:
With Collections replacing Add in the bottom bar, we need to ensure adding recipes remains discoverable and convenient.

NEW ADD RECIPE ENTRY POINTS:

1. FLOATING ACTION BUTTON (FAB):
   - Position: Bottom-right, above tab bar
   - Icon: "+" 
   - Appears on: Home screen, Collection detail views, Recipe list views
   - Does NOT appear on: Recipe detail view, Settings, Profile
   - Behavior: Tap opens Add Recipe flow
   - Optional: FAB can expand to show options (Add Recipe, Scan Recipe, Import URL)

2. COLLECTION CONTEXT:
   - Within any collection view, show "Add to [Collection Name]" action
   - This pre-selects the collection when adding
   - Position: In collection header or as last item in grid ("+ Add Recipe" card)

3. RECIPE CARD OVERFLOW MENU:
   - Existing "..." menu on recipe cards should include:
     • Add to Collection
     • Edit Recipe
     • Duplicate Recipe
     • Share
     • Delete
   - This allows management without dedicated tab

4. HOME SCREEN:
   - "Add Recipe" prominent in empty state
   - Quick action card or banner when collection is small
   - "Continue where you left off" for draft recipes

5. GESTURE-BASED:
   - Consider: Pull-down-to-add on home screen
   - Long-press on empty space to add (advanced)

6. IMPORT OPTIONS (in Add flow):
   - Manual entry (form)
   - Scan from image (OCR)
   - Import from URL
   - Import from photo of handwritten recipe
   - Voice dictation

ADD RECIPE FLOW MODIFICATIONS:
- Add "Collection" field to the add/edit recipe form
- Default to "Uncategorized" or last-used collection
- Allow creation of new collection inline during add
- "Save & Add Another" option for batch entry

VISUAL HIERARCHY:
The FAB should be the primary discovery mechanism. Make it:
- Prominent but not intrusive
- Consistent position across screens
- Clear "+" iconography
- Optional tooltip on first launch: "Tap to add your first recipe"
```

---

## Prompt 7: Seed Data JSON Structure

```
TASK: Create the JSON seed data file structure for heritage recipes

FILE: heritage-recipes-seed.json

STRUCTURE:

{
  "version": "1.0",
  "generatedAt": "2025-01-04T00:00:00Z",
  "collections": [
    {
      "id": "presidential-pantry",
      "slug": "presidential-pantry",
      "title": "The Presidential Pantry",
      "subtitle": "White House Favorites from Washington to Obama",
      "description": "Food humanizes history...",
      "accentColor": "#8B0000",
      "coverImageStyle": "vintage-photo",
      "coverImageUrl": null,
      "curatorProfileId": "curator-presidential",
      "featured": true,
      "sortOrder": 1
    }
    // ... other collections
  ],
  
  "curatorProfiles": [
    {
      "id": "curator-presidential",
      "displayName": "The Presidential Pantry",
      "avatarStyle": "seal",
      "bio": "Recipes from the American presidency, sourced from the National Archives, Library of Congress, and official White House records.",
      "isFoundingProfile": true
    }
    // ... other profiles
  ],
  
  "recipes": [
    {
      "id": "jefferson-vanilla-ice-cream",
      "collectionId": "presidential-pantry",
      "title": "Vanilla Ice Cream",
      "associatedFigure": "Thomas Jefferson",
      "yearEstimate": 1780,
      "historicalEra": "Founding Era",
      "sourceType": "manuscript",
      "sourceAttribution": "Library of Congress",
      "publicDomainJustification": "Government publication; original manuscript pre-1930",
      
      "historicalContext": "Jefferson is credited with popularizing ice cream in America after his diplomatic service in France. His handwritten recipe, preserved by the Library of Congress, is one of the earliest recorded American recipes for the dessert.",
      
      "engagementHook": "The recipe that introduced America to ice cream",
      
      "originalText": "2. bottles of good cream. 6. yolks of eggs. 1/2 lb. sugar mix the yolks & sugar put the cream on a fire in a casserole, first putting in a stick of Vanilla. when near boiling take it off & pour it gently into the mixture of eggs & sugar. stir it well. put it on the fire again stirring it thoroughly with a spoon to prevent it's sticking to the casserole. when near boiling take it off and strain it thro' a towel. put it in the Sabottiere then set it in ice an hour before it is to be served. put into the ice a handful of salt. put salt on the coverlid of the Sabotiere & cover the whole with ice. leave it still half a quarter of an hour. then turn the Sabottiere in the ice 10 minutes open it to loosen with a spatula the ice from the inner sides of the Sabotiere. shut it & replace it in the ice open it from time to time to detach the ice from the sides when well taken (prise) stir it well with the Spatula. put it in moulds, justling it well down on the knee. then put the mould into the same bucket of ice. leave it there to the moment of serving it. to withdraw it, immerse the mould in warm water, turning it well till it will come out & turn it into a plate.",
      
      "ingredients": [
        { "original": "2 bottles of good cream", "modern": "4 cups heavy cream", "notes": null },
        { "original": "6 yolks of eggs", "modern": "6 egg yolks", "notes": null },
        { "original": "1/2 lb sugar", "modern": "1 cup sugar", "notes": null },
        { "original": "a stick of Vanilla", "modern": "1 vanilla bean, split", "notes": "Or 2 tsp vanilla extract" }
      ],
      
      "instructionsModern": [
        "Split the vanilla bean lengthwise and scrape out the seeds.",
        "In a heavy saucepan, combine the cream, vanilla bean, and seeds. Heat over medium until just simmering (do not boil). Remove from heat and let steep 15 minutes.",
        "In a bowl, whisk egg yolks and sugar until pale and thick, about 2 minutes.",
        "Slowly pour the warm cream into the egg mixture, whisking constantly to temper.",
        "Return mixture to saucepan over medium-low heat. Stir constantly with a wooden spoon until custard thickens enough to coat the back of the spoon (170°F), about 8-10 minutes.",
        "Strain through a fine-mesh sieve into a clean bowl. Discard vanilla bean.",
        "Cover and refrigerate until completely cold, at least 4 hours or overnight.",
        "Churn in an ice cream maker according to manufacturer's instructions.",
        "Transfer to a freezer-safe container and freeze until firm, about 2 hours."
      ],
      
      "metadata": {
        "difficulty": "intermediate",
        "prepTime": "30 minutes",
        "cookTime": "15 minutes",
        "chillTime": "4+ hours",
        "freezeTime": "2+ hours",
        "servings": "6-8",
        "cuisine": "American",
        "course": "dessert",
        "tags": ["ice-cream", "founding-fathers", "vanilla", "custard", "french-influence"]
      },
      
      "callToAction": "This recipe is from 1780. Do you have a family ice cream recipe? Save yours to continue the tradition."
    }
    // ... other recipes
  ]
}

IMPLEMENTATION:
1. Store this JSON in the app bundle or fetch from CDN
2. Parse and insert into local database on first launch
3. Include version number for future updates
4. Consider delta updates rather than full replacement
5. Images can be bundled or fetched lazily
```

---

## Prompt 8: Image Sourcing & Generation

```
TASK: Source and generate images for all heritage recipes

PHASE 1: Archive Search
For each recipe, search public domain archives using imageSearchHints:

1. Library of Congress API (loc.gov/pictures/api)
   - Search: "{associatedFigure}" OR "{recipe title}" + "food" + era
   - Filter: access-restricted=false

2. Wikimedia Commons API
   - Search categories: Historical_food, {Era}_cuisine
   - Filter: License = PD or CC0

3. Smithsonian Open Access API
   - Search food/domestic life collections

4. NYPL Digital Collections
   - Menu and cookbook collections

Output: data/heritage-images-sourced.json with candidates per recipe

PHASE 2: AI Generation
For recipes without good archival matches:

1. Construct prompt using base template + collection style reference
2. Call Google Imagen API:
   - aspectRatio: "4:3"
   - numberOfImages: 3 (select best)
   - Include negative prompt
3. Save to: assets/heritage-images/generated/{recipe-id}.png
4. Log generation prompt for reproducibility

PHASE 3: Processing
For all images (sourced and generated):

1. Generate variants: hero (1200×900), card (800×600), thumbnail (400×300)
2. Convert to WebP with JPEG fallback
3. Generate blurhash for each
4. Update heritage-seed.json with complete image paths

PHASE 4: Collection Covers
Generate cover image for each collection using coverImagePrompt.
Size: 1600×900 (16:9)
```

---

## Summary: Implementation Priorities

### Document Structure
- **This document** (`heritage-collections-spec.md`): Design specifications and detailed requirements
- **Companion document** (`heritage-collections-tasks.md`): Claude Code implementation tasks

### Key Implementation Priorities

1. **Data Models First**: Define HeritageRecipe, HeritageImageSet, ImageAsset, HeritageCollection, and FoundingUserProfile models
2. **Seed Data**: Create JSON file with 20-30 recipes across the 4 collections (can expand later)
3. **Image Pipeline**: Source from archives → Generate AI images for gaps → Process into variants
4. **Bottom Bar Change**: Replace "Add" with "Collections" tab
5. **Collections UI**: Build the collection browsing and detail views
6. **Dual-View**: Implement Artifact/Kitchen toggle for heritage recipes
7. **Bulk Actions**: Add selection mode and bulk organization toolbar
8. **FAB**: Add floating action button for recipe creation
9. **Call-to-Action**: Every heritage recipe prompts user to add their own version

### Image Asset Budget

| Asset Type | Count | Size Each | Total |
|------------|-------|-----------|-------|
| Collection covers | 4 | ~200KB | ~800KB |
| Recipe heroes | 100 | ~150KB | ~15MB |
| Recipe thumbnails | 100 | ~30KB | ~3MB |
| Manuscript scans | ~20 | ~100KB | ~2MB |
| **Total** | | | **~21MB** |

Consider: Bundling only first 20 recipes, lazy-load rest via CDN.

### The Virtuous Cycle
Users browse heritage content → feel validated → add their own recipes → which enriches the platform for others.
