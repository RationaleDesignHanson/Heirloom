#!/usr/bin/env node

/**
 * Image Upload Script
 * Uploads theme covers and recipe images to Firebase Storage
 *
 * Usage: node upload-images.js [--themes-only | --recipes-only]
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'heirloom-ios-prod.firebasestorage.app'
});

const bucket = admin.storage().bucket();

// Paths
const THEME_IMAGES_DIR = path.join(__dirname, '../theme-images');
const RECIPE_IMAGES_DIR = path.join(__dirname, '../recipe-images');

/**
 * Upload a single file to Firebase Storage
 */
async function uploadFile(localPath, storagePath, contentType = 'image/webp') {
  try {
    await bucket.upload(localPath, {
      destination: storagePath,
      metadata: {
        contentType: contentType,
        cacheControl: 'public, max-age=31536000', // Cache for 1 year
      },
      // Remove 'public: true' - bucket has uniform access enabled
    });

    // Get public URL (works with uniform bucket-level access)
    const file = bucket.file(storagePath);
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;

    return publicUrl;
  } catch (error) {
    throw new Error(`Failed to upload ${storagePath}: ${error.message}`);
  }
}

/**
 * Upload theme cover images
 */
async function uploadThemeImages() {
  console.log('\n📷 Uploading theme cover images...\n');

  if (!fs.existsSync(THEME_IMAGES_DIR)) {
    console.log(`⚠️  Theme images directory not found: ${THEME_IMAGES_DIR}`);
    return { success: 0, failed: 0 };
  }

  const files = fs.readdirSync(THEME_IMAGES_DIR)
    .filter(f => f.endsWith('.webp') || f.endsWith('.jpg') || f.endsWith('.png'));

  let successCount = 0;
  let errorCount = 0;

  for (const file of files) {
    // Extract theme ID from filename (e.g., "theme-01-automat-classics-cover.webp" -> "automat-classics")
    const match = file.match(/theme-\d+-(.+)-cover\.(webp|jpg|png)$/);
    const themeId = match ? match[1] : file.replace(/\.(webp|jpg|png)$/, '');

    const localPath = path.join(THEME_IMAGES_DIR, file);
    const storagePath = `themes/${themeId}.webp`; // Store as {theme-id}.webp

    try {
      const url = await uploadFile(localPath, storagePath);
      console.log(`  ✓ Uploaded: ${themeId}`);
      console.log(`    URL: ${url}`);
      successCount++;
    } catch (error) {
      console.error(`  ✗ Failed: ${themeId} - ${error.message}`);
      errorCount++;
    }
  }

  return { success: successCount, failed: errorCount };
}

/**
 * Upload recipe images
 */
async function uploadRecipeImages() {
  console.log('\n🍳 Uploading recipe images...\n');

  if (!fs.existsSync(RECIPE_IMAGES_DIR)) {
    console.log(`⚠️  Recipe images directory not found: ${RECIPE_IMAGES_DIR}`);
    return { success: 0, failed: 0 };
  }

  // Expected structure: recipe-images/{themeId}/{recipeId}.webp
  const themeDirs = fs.readdirSync(RECIPE_IMAGES_DIR)
    .filter(d => fs.statSync(path.join(RECIPE_IMAGES_DIR, d)).isDirectory());

  let successCount = 0;
  let errorCount = 0;

  for (const themeId of themeDirs) {
    const themeDir = path.join(RECIPE_IMAGES_DIR, themeId);
    const files = fs.readdirSync(themeDir)
      .filter(f => f.endsWith('.webp') || f.endsWith('.jpg') || f.endsWith('.png'));

    console.log(`\n  📂 Theme: ${themeId} (${files.length} images)`);

    for (const file of files) {
      const localPath = path.join(themeDir, file);
      const storagePath = `recipes/${themeId}/${file}`;

      try {
        await uploadFile(localPath, storagePath);
        console.log(`    ✓ ${file}`);
        successCount++;
      } catch (error) {
        console.error(`    ✗ ${file} - ${error.message}`);
        errorCount++;
      }
    }
  }

  return { success: successCount, failed: errorCount };
}

/**
 * Update Firestore with image URLs
 */
async function updateFirestoreWithImageURLs() {
  console.log('\n🔗 Updating Firestore with image URLs...\n');

  const db = admin.firestore();

  // Update theme cover URLs
  const themesSnapshot = await db.collection('themes').get();

  for (const doc of themesSnapshot.docs) {
    const themeId = doc.id;

    // Check if webp exists, fallback to jpg
    const webpFile = bucket.file(`themes/${themeId}.webp`);
    const jpgFile = bucket.file(`themes/${themeId}.jpg`);

    let imageFile = webpFile;
    const [webpExists] = await webpFile.exists();

    if (!webpExists) {
      const [jpgExists] = await jpgFile.exists();
      if (jpgExists) {
        imageFile = jpgFile;
      } else {
        console.log(`  ⚠️  No image found for theme: ${themeId}`);
        continue;
      }
    }

    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${imageFile.name}`;

    await doc.ref.update({
      coverImageURL: publicUrl
    });

    console.log(`  ✓ Updated theme: ${themeId}`);
  }

  // Update recipe image URLs
  for (const doc of themesSnapshot.docs) {
    const themeId = doc.id;
    const recipesSnapshot = await doc.ref.collection('recipes').get();

    for (const recipeDoc of recipesSnapshot.docs) {
      const recipeId = recipeDoc.id;

      // Check if webp exists, fallback to jpg
      const webpFile = bucket.file(`recipes/${themeId}/${recipeId}.webp`);
      const jpgFile = bucket.file(`recipes/${themeId}/${recipeId}.jpg`);

      let imageFile = webpFile;
      const [webpExists] = await webpFile.exists();

      if (!webpExists) {
        const [jpgExists] = await jpgFile.exists();
        if (jpgExists) {
          imageFile = jpgFile;
        } else {
          continue; // Skip if no image
        }
      }

      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${imageFile.name}`;

      await recipeDoc.ref.update({
        imageURL: publicUrl
      });
    }

    console.log(`  ✓ Updated recipes for: ${themeId}`);
  }

  console.log('\n✅ Firestore URLs updated!');
}

/**
 * Main function
 */
async function main() {
  console.log('🔥 Starting image upload...\n');

  const args = process.argv.slice(2);
  const themesOnly = args.includes('--themes-only');
  const recipesOnly = args.includes('--recipes-only');

  let themeResults = { success: 0, failed: 0 };
  let recipeResults = { success: 0, failed: 0 };

  if (!recipesOnly) {
    themeResults = await uploadThemeImages();
  }

  if (!themesOnly) {
    recipeResults = await uploadRecipeImages();
  }

  // Update Firestore with URLs
  if (themeResults.success > 0 || recipeResults.success > 0) {
    await updateFirestoreWithImageURLs();
  }

  console.log('\n📊 Upload Summary:');
  console.log(`   Theme covers: ${themeResults.success} uploaded, ${themeResults.failed} failed`);
  console.log(`   Recipe images: ${recipeResults.success} uploaded, ${recipeResults.failed} failed`);

  if (themeResults.success > 0 || recipeResults.success > 0) {
    console.log('\n✅ Image upload complete!');
    console.log('\n🎯 Next Steps:');
    console.log('   1. Verify images in Firebase Console');
    console.log('   2. Test image loading in the app');
    console.log('   3. Check image quality and sizing');
  } else {
    console.log('\n⚠️  No images were uploaded. Check your image directories.');
  }

  process.exit(themeResults.failed > 0 || recipeResults.failed > 0 ? 1 : 0);
}

// Run the upload
main().catch((error) => {
  console.error('❌ Fatal error:', error);
  console.error(error.stack);
  process.exit(1);
});
