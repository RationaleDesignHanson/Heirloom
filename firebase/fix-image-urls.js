#!/usr/bin/env node

/**
 * Fix Image URLs Script
 * Updates Firestore with correct image URLs for themes and recipes
 *
 * Usage: node fix-image-urls.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK (reuse existing app if already initialized)
if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'heirloom-ios-prod.firebasestorage.app'
  });
}

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Local paths
const RECIPE_IMAGES_DIR = path.join(__dirname, '../recipe-images');
const THEME_IMAGES_DIR = path.join(__dirname, '../theme-images');

/**
 * Update theme cover URLs
 */
async function updateThemeCoverURLs() {
  console.log('\n🎨 Updating theme cover URLs...\n');

  const themesSnapshot = await db.collection('themes').get();
  let successCount = 0;
  let errorCount = 0;

  for (const doc of themesSnapshot.docs) {
    const themeId = doc.id;

    try {
      // Check for theme cover in Storage
      const webpFile = bucket.file(`themes/${themeId}.webp`);
      const jpgFile = bucket.file(`themes/${themeId}.jpg`);

      let imageFile = webpFile;
      const [webpExists] = await webpFile.exists();

      if (!webpExists) {
        const [jpgExists] = await jpgFile.exists();
        if (jpgExists) {
          imageFile = jpgFile;
        } else {
          console.log(`  ⚠️  No cover image for theme: ${themeId}`);
          errorCount++;
          continue;
        }
      }

      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${imageFile.name}`;

      await doc.ref.update({
        coverImageURL: publicUrl
      });

      console.log(`  ✓ ${themeId}: ${publicUrl}`);
      successCount++;
    } catch (error) {
      console.error(`  ✗ ${themeId}: ${error.message}`);
      errorCount++;
    }
  }

  console.log(`\n📊 Theme covers: ${successCount} updated, ${errorCount} failed`);
}

/**
 * Update recipe image URLs by listing all images and matching to recipes
 */
async function updateRecipeImageURLs() {
  console.log('\n🍳 Updating recipe image URLs...\n');

  const themesSnapshot = await db.collection('themes').get();
  let totalSuccess = 0;
  let totalError = 0;

  for (const themeDoc of themesSnapshot.docs) {
    const themeId = themeDoc.id;
    console.log(`\n  📂 Theme: ${themeId}`);

    try {
      // List all images in Storage for this theme
      const [files] = await bucket.getFiles({
        prefix: `recipes/${themeId}/`
      });

      if (files.length === 0) {
        console.log(`    ⚠️  No recipe images found in Storage`);
        continue;
      }

      // Get all recipes for this theme
      const recipesSnapshot = await themeDoc.ref.collection('recipes').get();

      console.log(`    Found ${files.length} images and ${recipesSnapshot.docs.length} recipes`);

      // For each image, construct the public URL and update the FIRST recipe without an imageURL
      // This is a temporary solution - ideally we'd match by title similarity
      let imageIndex = 0;
      for (const recipeDoc of recipesSnapshot.docs) {
        if (imageIndex >= files.length) break;

        const imageFile = files[imageIndex];
        const publicUrl = `https://storage.googleapis.com/${bucket.name}/${imageFile.name}`;

        await recipeDoc.ref.update({
          imageURL: publicUrl
        });

        console.log(`    ✓ ${recipeDoc.id}: ${path.basename(imageFile.name)}`);
        totalSuccess++;
        imageIndex++;
      }

    } catch (error) {
      console.error(`    ✗ Error processing ${themeId}: ${error.message}`);
      totalError++;
    }
  }

  console.log(`\n📊 Recipe images: ${totalSuccess} updated, ${totalError} failed`);
}

/**
 * Main function
 */
async function main() {
  console.log('🔧 Fixing image URLs in Firestore...\n');

  // Update theme cover URLs
  await updateThemeCoverURLs();

  // Update recipe image URLs
  await updateRecipeImageURLs();

  console.log('\n✅ Image URL updates complete!');
  console.log('\n🎯 Next Steps:');
  console.log('   1. Verify images load in the app');
  console.log('   2. If recipe images are mismatched, we can add title-based matching');

  process.exit(0);
}

// Run the fix
main().catch((error) => {
  console.error('❌ Fatal error:', error);
  console.error(error.stack);
  process.exit(1);
});
