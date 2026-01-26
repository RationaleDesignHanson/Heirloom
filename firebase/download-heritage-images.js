#!/usr/bin/env node

/**
 * Heritage Images Download Script
 * Downloads existing heritage recipe images from Firebase Storage
 *
 * Usage: node download-heritage-images.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const https = require('https');

// Initialize Firebase Admin SDK (reuse existing initialization)
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'heirloom-ios-prod.firebasestorage.app'
  });
}

const bucket = admin.storage().bucket();

// Output directory
const OUTPUT_DIR = path.join(__dirname, '../heritage-images-export');

/**
 * Download a file from URL
 */
function downloadFile(url, filepath) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(filepath);
    https.get(url, (response) => {
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (error) => {
      fs.unlink(filepath, () => {}); // Delete file on error
      reject(error);
    });
  });
}

/**
 * Download all heritage recipe images
 */
async function downloadHeritageImages() {
  console.log('📥 Downloading heritage recipe images from Firebase Storage...\n');

  // Create output directory
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  try {
    // List all files in the heritage_recipes folder
    const [files] = await bucket.getFiles({
      prefix: 'heritage_recipes/'
    });

    if (files.length === 0) {
      console.log('⚠️  No heritage recipe images found in Firebase Storage');
      console.log('   Checking alternative paths...\n');

      // Try recipes/ path with heritage collection IDs
      const collections = ['presidential-pantry', 'literary-kitchen', 'ancient-table', 'american-foundation'];
      let totalDownloaded = 0;

      for (const collectionId of collections) {
        console.log(`\n📂 Checking ${collectionId}...`);

        const collectionDir = path.join(OUTPUT_DIR, collectionId);
        if (!fs.existsSync(collectionDir)) {
          fs.mkdirSync(collectionDir, { recursive: true });
        }

        const [collectionFiles] = await bucket.getFiles({
          prefix: `recipes/${collectionId}/`
        });

        for (const file of collectionFiles) {
          const filename = path.basename(file.name);
          const filepath = path.join(collectionDir, filename);

          try {
            await file.download({ destination: filepath });
            console.log(`  ✓ Downloaded: ${filename}`);
            totalDownloaded++;
          } catch (error) {
            console.log(`  ✗ Failed: ${filename} - ${error.message}`);
          }
        }

        console.log(`  → ${collectionFiles.length} images in ${collectionId}`);
      }

      if (totalDownloaded === 0) {
        console.log('\n⚠️  No images found in either location');
        console.log('   Heritage recipe images may not have been uploaded yet');
        process.exit(0);
      }

      console.log(`\n✅ Downloaded ${totalDownloaded} heritage recipe images!`);
      console.log(`\n📍 Saved to: ${OUTPUT_DIR}`);

      process.exit(0);
    }

    console.log(`Found ${files.length} files in heritage_recipes/\n`);

    let downloadedCount = 0;
    let errorCount = 0;

    for (const file of files) {
      // Skip directories
      if (file.name.endsWith('/')) {
        continue;
      }

      const filename = path.basename(file.name);
      const filepath = path.join(OUTPUT_DIR, filename);

      try {
        // Download file
        await file.download({ destination: filepath });
        console.log(`  ✓ Downloaded: ${filename}`);
        downloadedCount++;
      } catch (error) {
        console.log(`  ✗ Failed: ${filename} - ${error.message}`);
        errorCount++;
      }
    }

    console.log(`\n📊 Download Summary:`);
    console.log(`   Downloaded: ${downloadedCount}`);
    console.log(`   Failed: ${errorCount}`);

    if (downloadedCount > 0) {
      console.log(`\n✅ Heritage images exported successfully!`);
      console.log(`\n📍 Saved to: ${OUTPUT_DIR}`);
      console.log('\n🎯 Next Steps:');
      console.log('   1. Review the images to understand the current style');
      console.log('   2. Use these as reference when generating new theme images');
      console.log('   3. Ensure consistent visual style across all themes');
    } else {
      console.log('\n⚠️  No images were downloaded');
    }

  } catch (error) {
    console.error('❌ Error downloading heritage images:', error);
    console.error(error.stack);
    process.exit(1);
  }

  process.exit(0);
}

// Run the download
downloadHeritageImages().catch((error) => {
  console.error('❌ Fatal error:', error);
  console.error(error.stack);
  process.exit(1);
});
