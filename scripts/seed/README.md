# Heirloom Seed System

Unified seeding system for all Heirloom demo and test data. Provides a single entry point to seed/reset the database while keeping existing scripts in their original locations.

## Quick Start

```bash
cd scripts/seed
npm install
cp .env.example .env   # Edit with your credentials

# Seed everything
npm run seed:all

# Or seed individual components
npm run seed:themes       # Theme recipes only
npm run seed:public       # Demo creators only
npm run seed:algolia      # Sync to Algolia only

# Verify and cleanup
npm run verify            # Check seeded data
npm run cleanup:all       # Remove demo data
```

## What Gets Seeded

| Component | Description | Documents |
|-----------|-------------|-----------|
| **Theme Recipes** | 14 heritage themes with recipes | ~140 recipes in `themes/{themeId}/recipes` |
| **Public Recipes** | Demo creators (Grandmazing, Phillip Fry) | 12 recipes in `publicRecipes` |
| **Algolia Index** | Search index for public recipes | Synced to `public_recipes` index |

## Commands

### Seed All Data

```bash
# Full seed: themes + public recipes + Algolia (~3-5 minutes)
npm run seed:all
```

### Seed Individual Components

```bash
# Theme recipes (14 themes from JSON files)
npm run seed:themes

# Public recipes with AI-generated images
npm run seed:public

# Public recipes without image generation (faster)
npm run seed:public:no-images

# Sync public recipes to Algolia
npm run seed:algolia
```

### Verify & Cleanup

```bash
# Verify seeded data
npm run verify

# Clean up demo data (public recipes only)
npm run cleanup:all

# Clean up just public recipes
npm run cleanup:public
```

## Architecture

This orchestrator calls existing scripts without moving them:

```
scripts/seed/
├── src/
│   ├── orchestrate.ts      # Unified entry point (calls scripts below)
│   ├── seed.ts             # Public recipes seeding
│   ├── seed_data.ts        # Demo creator recipe content
│   ├── verify.ts           # Verification
│   ├── cleanup.ts          # Cleanup
│   └── utils/              # Shared utilities

scripts/
├── cleanup-and-reseed-recipes.js   # Theme recipes (called by orchestrator)

firebase/functions/
├── backfill-public-recipes-algolia.js  # Algolia sync (called by orchestrator)

themerecipes/
├── theme-01-automat-classics.json  # Theme recipe data
├── theme-02-railroad-dining.json
└── ... (14 theme files)
```

## Prerequisites

1. **Node.js 18+**
2. **Service account key** at `../../service-account-key.json`
3. **Replicate API token** (only for image generation)

## Environment Variables

Create `.env` from `.env.example`:

| Variable | Description | Required |
|----------|-------------|----------|
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to Firebase service account JSON | Yes |
| `FIREBASE_STORAGE_BUCKET` | Firebase Storage bucket name | Yes |
| `REPLICATE_API_TOKEN` | Replicate API token for image generation | Only for `seed:public` |

## Demo Creators

### Grandmazing
- **ID**: `demo_grandmazing`
- **Style**: Traditional, family-oriented recipes with stories
- **Recipes**: 7 (Lemon Garlic Chicken, Tomato Soup, Salmon Rice Bowls, etc.)

### Phillip Fry
- **ID**: `demo_phillipfry`
- **Style**: Modern weeknight cooking, easy and practical
- **Recipes**: 5 (One-Pot Pasta, Smashed Potatoes, Chickpea Salad, etc.)

## Idempotency

All seeding operations are idempotent:

- **Deterministic IDs**: `demo_grandmazing_lemon_garlic_chicken`
- **Image checks**: Skips generation if image already exists
- **Firestore upserts**: Uses `set({ merge: true })`

Running `npm run seed:all` multiple times is safe.

## Seed Tagging

Demo data is tagged for easy identification and cleanup:

```typescript
{
  isDemoSeed: true,
  demoSeedVersion: "v1",
  demoSeedLabel: "discover-capture"
}
```

## Database Reset Procedure

To completely reset and reseed the database:

```bash
cd scripts/seed

# 1. Clean up demo data
npm run cleanup:all

# 2. Reseed everything
npm run seed:all

# 3. Verify
npm run verify
```

**Note**: Theme recipes are app content (not demo data) and are always reseeded, not cleaned.

## Troubleshooting

### "GOOGLE_APPLICATION_CREDENTIALS not set"
Ensure your `.env` file has the correct path to your service account JSON file.

### "REPLICATE_API_TOKEN not set"
Get a token from [replicate.com/account](https://replicate.com/account) or use `--skip-images`.

### Theme recipes not seeding
Check that `themerecipes/*.json` files exist and `scripts/cleanup-and-reseed-recipes.js` can access the service account.

### Algolia sync failing
Ensure the Algolia credentials in `firebase/functions/backfill-public-recipes-algolia.js` are correct.

## Adding New Seed Modules

To add new seedable data (e.g., mock users):

1. Create `src/users/seed.ts` and `src/users/cleanup.ts`
2. Add script paths to `SCRIPTS` in `orchestrate.ts`
3. Add new functions (e.g., `seedUsers()`) and CLI commands
4. Update `seedAll()` to include the new module
5. Document in this README
