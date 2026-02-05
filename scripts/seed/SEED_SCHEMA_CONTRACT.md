# Seed Schema Contract

This document defines the schema for seeded demo data in the `publicRecipes` Firestore collection.

## Design Principle

**PublicRecipe = Recipe content + attribution rules**

Public recipes have ALL the same content fields as local Recipe. The difference is in:
- **Attribution** - Shows creator info
- **Modification rules** - Saved copies become editable forks

## Collection: `publicRecipes`

### Required Fields

| Field | Type | Notes |
|-------|------|-------|
| `id` | String | Document ID (deterministic: `demo_grandmazing_lemon_garlic_chicken`) |
| `sourceRecipeId` | String | Fake UUID reference (e.g., `seed-uuid-001`) |
| `ownerId` | String | Deterministic: `demo_grandmazing` or `demo_phillipfry` |
| `title` | String | Recipe title (max 2 lines in UI, ~60 chars) |
| `ingredients` | [String] | 8-14 ingredients with amounts (e.g., "2 cups all-purpose flour") |
| `instructions` | [String] | 6-10 cooking steps |
| `tags` | [String] | 3-6 tags |
| `creatorName` | String | "Grandmazing" or "Phillip Fry" |
| `viewCount` | Int | Engagement metric |
| `saveCount` | Int | Engagement metric (< viewCount) |
| `searchKeywords` | [String] | Auto-generated, lowercase, >= 3 chars |
| `isHidden` | Bool | Always `false` for seeds |
| `reportCount` | Int | Always `0` for seeds |
| `publishedAt` | Timestamp | Relative dates (2d, 5d, 14d, 30d ago) |
| `updatedAt` | Timestamp | Same as publishedAt |

### Optional Fields (Should Be Populated)

| Field | Type | Notes |
|-------|------|-------|
| `description` | String | 2-4 sentences with story/context |
| `imageURL` | String | Firebase Storage URL |
| `category` | String | Recipe category (Dinner, Dessert, etc.) |
| `servings` | String | e.g., "4 servings" |
| `prepTime` | String | Minutes as string, e.g., "15" |
| `cookTime` | String | Minutes as string, e.g., "25" |
| `totalTime` | String | Combined time, e.g., "40" |
| `creatorPhotoURL` | String | Creator avatar URL |
| `creatorProfileSlug` | String | e.g., "grandmazing" |
| `moderationStatus` | String | `null` for seeds |

### Seed Tagging Fields

| Field | Type | Notes |
|-------|------|-------|
| `isDemoSeed` | Bool | Always `true` |
| `demoSeedVersion` | String | "v1" |
| `demoSeedLabel` | String | "discover-capture" |

## Field Parity: Recipe ↔ PublicRecipe

| Recipe Field | PublicRecipe Field | Status |
|-------------|-------------------|--------|
| title | title | ✅ |
| imageFileName | imageURL | ✅ |
| ingredients | ingredients | ✅ (flattened to strings) |
| instructions | instructions | ✅ |
| servings | servings | ✅ |
| prepTime | prepTime | ✅ |
| cookTime | cookTime | ✅ |
| totalTime | totalTime | ✅ |
| notes | description | ✅ |
| recipeCategory | category | ✅ |
| tags | tags | ✅ (flattened to strings) |

## Engagement Stats Tiers

| Tier | Views | Saves | Use Case |
|------|-------|-------|----------|
| Hit | 3000-4500 | 400-650 | Top recipes, trending |
| Solid | 900-1800 | 140-250 | Established recipes |
| New | 150-400 | 25-55 | Recently published |

## Search Keywords Generation

Keywords are generated from:
1. Title words (lowercase, >= 3 chars)
2. Ingredient words (excluding measurements)
3. Creator name words
4. Tag words
5. Category words

Stop words and numbers are excluded.

## Example Document

```json
{
  "id": "demo_grandmazing_lemon_garlic_chicken",
  "sourceRecipeId": "seed-uuid-001",
  "ownerId": "demo_grandmazing",
  "title": "Lemon Garlic Chicken",
  "description": "This was my mother's Sunday dinner staple...",
  "imageURL": "https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grandmazing_lemon_garlic_chicken-image.webp",
  "ingredients": [
    "4 bone-in chicken thighs",
    "3 tablespoons olive oil",
    "4 cloves garlic, minced",
    ...
  ],
  "instructions": [
    "In a bowl, combine olive oil, minced garlic...",
    "Place chicken thighs in a large zip-lock bag...",
    ...
  ],
  "category": "Dinner",
  "tags": ["Chicken", "Lemon", "Garlic", "Family Recipe"],
  "servings": "4 servings",
  "prepTime": "15",
  "cookTime": "35",
  "totalTime": "50",
  "creatorName": "Grandmazing",
  "creatorPhotoURL": "https://storage.googleapis.com/.../grandmazing-avatar.webp",
  "creatorProfileSlug": "grandmazing",
  "viewCount": 3500,
  "saveCount": 480,
  "searchKeywords": ["chicken", "garlic", "lemon", "dinner", "grandmazing", ...],
  "isHidden": false,
  "reportCount": 0,
  "moderationStatus": null,
  "publishedAt": "2025-01-22T12:00:00.000Z",
  "updatedAt": "2025-01-22T12:00:00.000Z",
  "isDemoSeed": true,
  "demoSeedVersion": "v1",
  "demoSeedLabel": "discover-capture"
}
```

## Validation Rules

1. **Title**: Non-empty, < 60 chars recommended
2. **Ingredients**: Array with 3-20 items, each item >= 3 chars
3. **Instructions**: Array with 3-15 items, each item >= 10 chars
4. **Tags**: Array with 2-8 items
5. **ViewCount**: >= 0
6. **SaveCount**: >= 0, <= viewCount
7. **PublishedDaysAgo**: >= 0
