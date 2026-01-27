# Firebase Seeding Scripts

Scripts to clean up duplicate recipes and upload theme images to Firebase.

## Prerequisites

Install dependencies:
```bash
cd /Users/matthanson/Heirloom/scripts
npm install
```

## Fix Process

### Step 1: Clean Up Duplicates & Re-seed Recipes

```bash
node cleanup-and-reseed-recipes.js
```

Deletes ALL existing recipes and re-uploads from JSON with correct IDs and image URLs.

### Step 2: Upload Images to Firebase Storage

```bash
node upload-images-to-storage.js
```

Uploads 14 theme covers + 186 recipe images to Firebase Storage.

### Step 3: Test in App

1. Delete app and reinstall (clears SwiftData cache)
2. Complete onboarding, select 2 themes
3. Verify images load and recipe counts are correct

## Verification (Optional)

```bash
node verify-image-mapping.js
```

Checks that all recipe images match recipe data before uploading.
