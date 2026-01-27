#!/usr/bin/env node

/**
 * Upload theme covers and recipe images to Firebase Storage
 *
 * Usage: node scripts/upload-images-to-storage.js
 *
 * This script:
 * 1. Uploads theme cover images from theme-image-gen/theme-covers/
 * 2. Uploads recipe images from theme-image-gen/images/
 * 3. Sets proper content types and makes images publicly accessible
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./firebase/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'heirloom-ios-prod.firebasestorage.app'
});

const bucket = admin.storage().bucket();

// Paths
const THEME_COVERS_DIR = path.join(__dirname, 'theme-image-gen', 'theme-covers');
const RECIPE_IMAGES_DIR = path.join(__dirname, 'theme-image-gen', 'images');

// Theme ID mapping (from file name to Firestore ID)
const THEME_ID_MAP = {
  'theme-01-automat-classics-cover.webp': 'automat-classics',
  'theme-02-railroad-dining-cover.webp': 'railroad-dining',
  'theme-03-victory-kitchen-cover.webp': 'victory-kitchen',
  'theme-04-navy-mess-cover.webp': 'navy-mess',
  'theme-05-boston-cooking-cover.webp': 'boston-cooking-school',
  'theme-06-southern-roots-cover.webp': 'southern-roots',
  'theme-07-scandinavian-cover.webp': 'scandinavian-heritage',
  'theme-08-german-american-cover.webp': 'german-american',
  'theme-09-quick-weeknight-cover.webp': 'quick-weeknight',
  'theme-10-sunday-suppers-cover.webp': 'sunday-suppers',
  'theme-11-presidential-pantry-cover.webp': 'presidential-pantry',
  'theme-12-literary-kitchen-cover.webp': 'literary-kitchen',
  'theme-13-ancient-table-cover.webp': 'ancient-table',
  'theme-14-american-foundation-cover.webp': 'american-foundation'
};

/**
 * Upload a single file to Firebase Storage
 */
async function uploadFile(localPath, storagePath, contentType = 'image/webp') {
  try {
    const file = bucket.file(storagePath);

    // Upload file
    await bucket.upload(localPath, {
      destination: storagePath,
      metadata: {
        contentType: contentType,
        cacheControl: 'public, max-age=31536000', // Cache for 1 year
      },
    });

    // Note: With uniform bucket-level access, files are already public via bucket rules
    // No need to call makePublic() on individual files

    console.log(`✓ Uploaded: ${storagePath}`);
    return true;
  } catch (error) {
    console.error(`✗ Failed to upload ${storagePath}:`, error.message);
    return false;
  }
}

/**
 * Upload all theme cover images
 */
async function uploadThemeCovers() {
  console.log('\n📸 Uploading theme cover images...\n');

  const files = fs.readdirSync(THEME_COVERS_DIR)
    .filter(f => f.endsWith('.webp') && f.startsWith('theme-'));

  let successCount = 0;
  let failCount = 0;

  for (const fileName of files) {
    const themeId = THEME_ID_MAP[fileName];

    if (!themeId) {
      console.warn(`⚠ Skipping unknown theme cover: ${fileName}`);
      continue;
    }

    const localPath = path.join(THEME_COVERS_DIR, fileName);
    const storagePath = `themes/${themeId}.webp`;

    const success = await uploadFile(localPath, storagePath);
    if (success) successCount++;
    else failCount++;
  }

  console.log(`\n📊 Theme covers: ${successCount} uploaded, ${failCount} failed`);
}

/**
 * Upload all recipe images
 */
async function uploadRecipeImages() {
  console.log('\n🍽️  Uploading recipe images...\n');

  const files = fs.readdirSync(RECIPE_IMAGES_DIR)
    .filter(f => f.endsWith('.webp'));

  let successCount = 0;
  let failCount = 0;

  for (const fileName of files) {
    // Extract theme ID from filename (e.g., "german-american-sauerbraten.webp" -> "german-american")
    const parts = fileName.replace('.webp', '').split('-');

    // Find theme ID by checking prefixes
    let themeId = null;

    // Try two-word theme IDs first (e.g., "german-american", "southern-roots")
    if (parts.length >= 3) {
      const twoWordId = `${parts[0]}-${parts[1]}`;
      // Check if this is a valid theme by seeing if the file follows pattern
      const possibleThemes = [
        'automat-classics', 'railroad-dining', 'victory-kitchen', 'navy-mess',
        'boston-cooking', 'southern-roots', 'scandinavian-heritage', 'german-american',
        'quick-weeknight', 'sunday-suppers', 'presidential-pantry', 'literary-kitchen',
        'ancient-table', 'american-foundation'
      ];

      if (possibleThemes.includes(twoWordId)) {
        themeId = twoWordId;
      }

      // Try three-word theme IDs (e.g., "scandinavian-heritage", "presidential-pantry")
      if (!themeId && parts.length >= 4) {
        const threeWordId = `${parts[0]}-${parts[1]}-${parts[2]}`;
        if (possibleThemes.includes(threeWordId)) {
          themeId = threeWordId;
        }
      }
    }

    if (!themeId) {
      console.warn(`⚠ Could not determine theme ID for: ${fileName}`);
      failCount++;
      continue;
    }

    const localPath = path.join(RECIPE_IMAGES_DIR, fileName);
    const storagePath = `recipes/${themeId}/${fileName}`;

    const success = await uploadFile(localPath, storagePath);
    if (success) successCount++;
    else failCount++;

    // Rate limit to avoid overwhelming Firebase
    if (successCount % 10 === 0) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }

  console.log(`\n📊 Recipe images: ${successCount} uploaded, ${failCount} failed`);
}

/**
 * Main execution
 */
async function main() {
  console.log('🚀 Starting Firebase Storage upload...\n');
  console.log(`Storage bucket: ${bucket.name}`);
  console.log('Note: Bucket uses uniform bucket-level access (files are public via bucket rules)\n');

  try {
    await uploadThemeCovers();
    await uploadRecipeImages();

    console.log('\n✅ Upload complete!');
    console.log('\n💡 Images are now publicly accessible at:');
    console.log('   Theme covers: https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/themes/{theme-id}.webp');
    console.log('   Recipe images: https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/recipes/{theme-id}/{recipe-file}.webp');
    console.log('\n📝 Next step: Delete app and reinstall to test with fresh data');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Upload failed:', error);
    process.exit(1);
  }
}

// Run main function
main();
