#!/usr/bin/env node

/**
 * Fix boston-cooking-school recipe image URLs to match actual Storage filenames
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const bucket = admin.storage().bucket('heirloom-ios-prod.firebasestorage.app');

// Mapping of recipe IDs to actual image filenames
const IMAGE_MAPPING = {
  'boston-cooking-school-001': 'boston-cooking-school-fannie-farmer-parker-house-rolls.webp',
  'boston-cooking-school-002': 'boston-cooking-school-fannie-farmer-baked-beans.webp',
  'boston-cooking-school-003': 'boston-cooking-school-fannie-farmer-sugar-cookies.webp',
  'boston-cooking-school-004': 'boston-cooking-school-fannie-farmer-indian-pudding.webp',
  'boston-cooking-school-005': 'boston-cooking-school-fannie-farmer-brown-bread.webp',
  'boston-cooking-school-006': 'boston-cooking-school-fannie-farmer-gingerbread.webp',
  'boston-cooking-school-007': 'boston-cooking-school-fannie-farmer-popovers.webp',
  'boston-cooking-school-008': 'boston-cooking-school-fannie-farmer-boston-cream-pie.webp',
  'boston-cooking-school-009': 'boston-cooking-school-fannie-farmer-fish-chowder.webp',
  'boston-cooking-school-010': 'boston-cooking-school-fannie-farmer-welsh-rarebit.webp',
  'boston-cooking-school-011': 'boston-cooking-school-fannie-farmer-clam-fritters.webp',
  'boston-cooking-school-012': 'boston-cooking-school-fannie-farmer-codfish-balls.webp',
  'boston-cooking-school-013': 'boston-cooking-school-fannie-farmer-creamed-oysters.webp',
  'boston-cooking-school-014': 'boston-cooking-school-fannie-farmer-lobster-newburg.webp'
};

async function fixImageURLs() {
  console.log('🔧 Fixing Boston Cooking School image URLs...\n');

  try {
    const recipesSnapshot = await db
      .collection('themes')
      .doc('boston-cooking-school')
      .collection('recipes')
      .get();

    const batch = db.batch();
    let fixedCount = 0;

    for (const doc of recipesSnapshot.docs) {
      const recipeId = doc.id;
      const imageFilename = IMAGE_MAPPING[recipeId];

      if (!imageFilename) {
        console.log(`⚠️  No mapping for recipe ${recipeId}`);
        continue;
      }

      const newURL = `https://firebasestorage.googleapis.com/v0/b/heirloom-ios-prod.firebasestorage.app/o/recipes%2Fboston-cooking-school%2F${imageFilename}?alt=media`;

      batch.update(doc.ref, { imageURL: newURL });
      fixedCount++;
      console.log(`✓ ${recipeId} → ${imageFilename}`);
    }

    await batch.commit();
    console.log(`\n✅ Fixed ${fixedCount} image URLs`);

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

fixImageURLs();
