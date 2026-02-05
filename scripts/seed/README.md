# Heirloom Demo Seeds

Idempotent seeding system for demo creators and public recipes used in Discovery feature captures.

## Overview

This tool creates demo data in Firestore with two fictional creators:

- **Grandmazing** - A warm grandmother with 7 family recipes
- **Phillip Fry** - A young home cook with 5 weeknight favorites

All recipes include full content (title, description, ingredients, instructions, tags, times) and AI-generated images.

## Prerequisites

1. **Node.js 18+** installed
2. **Service account key** at `../../service-account-key.json` (relative to this directory)
3. **Replicate API token** (only needed for image generation)

## Setup

```bash
# Navigate to seed scripts
cd scripts/seed

# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Edit .env with your credentials
```

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to Firebase service account JSON | Yes |
| `FIREBASE_STORAGE_BUCKET` | Firebase Storage bucket name | Yes |
| `REPLICATE_API_TOKEN` | Replicate API token for image generation | Only for `npm run seed` |

## Commands

### Seed Data

```bash
# Full seed with AI-generated images (~2-3 minutes)
npm run seed

# Seed data only, skip image generation
npm run seed:no-images
```

### Verify

Check capture readiness and view seeded data summary:

```bash
npm run verify
```

### Cleanup

Remove all demo seed data from Firestore and Storage:

```bash
npm run cleanup
```

## Demo Creators

### Grandmazing
- **Profile slug**: `grandmazing`
- **Style**: Traditional, family-oriented recipes with stories
- **Recipes**: 7 (Lemon Garlic Chicken, Tomato Soup, Salmon Rice Bowls, etc.)

### Phillip Fry
- **Profile slug**: `phillip-fry`
- **Style**: Modern weeknight cooking, easy and practical
- **Recipes**: 5 (One-Pot Pasta, Smashed Potatoes, Chickpea Salad, etc.)

## Idempotency

The seeding script is idempotent:

- Uses deterministic document IDs (e.g., `demo_grandmazing_lemon_garlic_chicken`)
- Checks if images already exist before generating
- Uses `set({ merge: true })` for Firestore upserts

Running `npm run seed` multiple times is safe.

## Seed Tagging

All seeded documents include metadata for easy identification and cleanup:

```typescript
{
  isDemoSeed: true,
  demoSeedVersion: "v1",
  demoSeedLabel: "discover-capture"
}
```

## Image Generation

Images are generated using [Replicate](https://replicate.com) with the **Flux 1.1 Pro** model:

- Recipe images: 4:3 aspect ratio, food photography style
- Avatar images: 1:1 aspect ratio, portrait style

Images are uploaded to Firebase Storage at `seed/demo/`.

### Rate Limiting

The script includes a 2-second delay between image generations to avoid rate limits. Total generation time for all images is approximately 30-60 seconds.

## Verification Checklist

After seeding, the `npm run verify` command checks:

- [ ] 12 documents in `publicRecipes` collection
- [ ] All have `isDemoSeed: true`
- [ ] Grandmazing: 7 recipes
- [ ] Phillip Fry: 5 recipes
- [ ] All required fields populated
- [ ] SearchKeywords properly generated
- [ ] PublishedAt dates distributed correctly

## Testing in App

After seeding:

1. Open Heirloom app
2. Navigate to Discovery tab
3. Verify recipes appear in Trending/New/Popular tabs
4. Tap a recipe to view full detail (including instructions)
5. Test "Save to My Recipes" flow
6. Test search functionality

## Troubleshooting

### "GOOGLE_APPLICATION_CREDENTIALS not set"
Ensure your `.env` file has the correct path to your service account JSON file.

### "REPLICATE_API_TOKEN not set"
Get a token from [replicate.com/account](https://replicate.com/account) or use `npm run seed:no-images` to skip image generation.

### Images not appearing
Run `npm run verify` to check image URLs. You can re-run `npm run seed` to regenerate missing images.

### Firestore permission errors
Ensure your service account has the `Cloud Datastore User` role.
