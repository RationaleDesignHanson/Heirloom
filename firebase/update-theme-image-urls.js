#!/usr/bin/env node

/**
 * Update theme recipe documents in Firestore with their image URLs
 * Images are stored in Firebase Storage at: recipes/{themeId}/{filename}.webp
 */

const admin = require('firebase-admin');
const serviceAccount = require('./functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'heirloom-ios-prod.firebasestorage.app'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Map recipe IDs to their image filenames
// Format: recipes/{themeId}/{themeId}-{recipe-name}.webp
const RECIPE_IMAGE_MAP = {
  'german-american': {
    'german-american-001': 'german-american-sauerbraten.webp',           // Sauerbraten (German Pot Roast)
    'german-american-002': 'german-american-schnitzel.webp',             // Wiener Schnitzel
    'german-american-003': 'german-american-spaetzle.webp',              // Spätzle (German Egg Noodles)
    'german-american-004': 'german-american-german-apple-cake.webp',     // German Apple Cake
    'german-american-005': 'german-american-german-potato-salad.webp',   // German Potato Salad
    'german-american-006': 'german-american-lebkuchen.webp',             // Lebkuchen
    'german-american-007': 'german-american-stollen.webp',               // Christmas Stollen
    'german-american-008': 'german-american-kartoffelpuffer.webp',       // Kartoffelpuffer
    'german-american-009': 'german-american-german-red-cabbage.webp',    // Rotkohl
    'german-american-010': 'german-american-rouladen.webp',              // Rouladen
    'german-american-011': 'german-american-bratwurst.webp',             // Beer-Braised Bratwurst
    'german-american-012': 'german-american-black-forest-cake.webp',     // Black Forest Cake
    'german-american-013': 'german-american-german-pork-schnitzel.webp', // Jägerschnitzel
    'german-american-014': 'german-american-german-lentil-soup.webp',    // German Lentil Soup
  }
};

async function getPublicUrl(filePath) {
  try {
    const file = bucket.file(filePath);
    const [exists] = await file.exists();

    if (!exists) {
      console.log(`  ⚠️  File not found: ${filePath}`);
      return null;
    }

    // Get the download URL
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '01-01-2030' // Long expiry
    });

    return url;
  } catch (error) {
    console.log(`  ❌ Error getting URL for ${filePath}: ${error.message}`);
    return null;
  }
}

async function updateThemeRecipes(themeId) {
  console.log(`\n📸 Updating image URLs for theme: ${themeId}`);

  const imageMap = RECIPE_IMAGE_MAP[themeId];
  if (!imageMap) {
    console.log(`  ⚠️  No image map found for theme: ${themeId}`);
    return;
  }

  // Get all recipes for this theme
  const recipesRef = db.collection('themeRecipes').where('themeId', '==', themeId);
  const snapshot = await recipesRef.get();

  console.log(`  Found ${snapshot.size} recipes`);

  let updated = 0;
  let skipped = 0;
  let errors = 0;

  for (const doc of snapshot.docs) {
    const recipeId = doc.id;
    const data = doc.data();

    // Skip if already has imageURL
    if (data.imageURL) {
      console.log(`  → ${recipeId} (already has imageURL)`);
      skipped++;
      continue;
    }

    // Find the image filename
    const imageFilename = imageMap[recipeId];
    if (!imageFilename) {
      console.log(`  ⚠️  No image mapping for: ${recipeId}`);
      skipped++;
      continue;
    }

    // Construct the storage path
    const storagePath = `recipes/${themeId}/${imageFilename}`;

    // Get the public URL - use the direct Firebase Storage URL format
    const imageURL = `https://firebasestorage.googleapis.com/v0/b/heirloom-ios-prod.firebasestorage.app/o/${encodeURIComponent(storagePath)}?alt=media`;

    // Verify the file exists
    try {
      const [exists] = await bucket.file(storagePath).exists();
      if (!exists) {
        console.log(`  ⚠️  Image not found in storage: ${storagePath}`);
        skipped++;
        continue;
      }
    } catch (error) {
      console.log(`  ❌ Error checking file: ${error.message}`);
      errors++;
      continue;
    }

    // Update the document
    try {
      await doc.ref.update({ imageURL });
      console.log(`  ✓ ${recipeId} → ${imageFilename}`);
      updated++;
    } catch (error) {
      console.log(`  ❌ Failed to update ${recipeId}: ${error.message}`);
      errors++;
    }
  }

  console.log(`\n  Results: ${updated} updated, ${skipped} skipped, ${errors} errors`);
}

async function main() {
  console.log('🔄 Updating theme recipe image URLs...\n');

  // Update each theme
  for (const themeId of Object.keys(RECIPE_IMAGE_MAP)) {
    await updateThemeRecipes(themeId);
  }

  console.log('\n✅ Done!');
  process.exit(0);
}

main().catch(error => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
