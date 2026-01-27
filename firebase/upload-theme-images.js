#!/usr/bin/env node

/**
 * Upload theme recipe images from local directory to Firebase Storage
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const bucket = admin.storage().bucket('heirloom-ios-prod.firebasestorage.app');
const LOCAL_IMAGES_DIR = '/Users/matthanson/Heirloom/scripts/theme-image-gen/images';

async function uploadImages() {
  console.log('📤 Uploading theme images to Firebase Storage...\n');

  try {
    // Get all local image files
    const files = fs.readdirSync(LOCAL_IMAGES_DIR).filter(f => f.endsWith('.webp'));
    console.log(`Found ${files.length} images to upload\n`);

    let uploadedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;

    for (const filename of files) {
      try {
        // Extract theme ID from filename (e.g., "automat-classics" from "automat-classics-automat-apple-pie.webp")
        const parts = filename.split('-');
        let themeId;

        // Handle multi-word theme IDs
        if (filename.startsWith('american-foundation')) {
          themeId = 'american-foundation';
        } else if (filename.startsWith('ancient-table')) {
          themeId = 'ancient-table';
        } else if (filename.startsWith('automat-classics')) {
          themeId = 'automat-classics';
        } else if (filename.startsWith('boston-cooking-school')) {
          themeId = 'boston-cooking-school';
        } else if (filename.startsWith('german-american')) {
          themeId = 'german-american';
        } else if (filename.startsWith('literary-kitchen')) {
          themeId = 'literary-kitchen';
        } else if (filename.startsWith('navy-mess')) {
          themeId = 'navy-mess';
        } else if (filename.startsWith('presidential-pantry')) {
          themeId = 'presidential-pantry';
        } else if (filename.startsWith('quick-weeknight')) {
          themeId = 'quick-weeknight';
        } else if (filename.startsWith('railroad-dining')) {
          themeId = 'railroad-dining';
        } else if (filename.startsWith('scandinavian-heritage')) {
          themeId = 'scandinavian-heritage';
        } else if (filename.startsWith('southern-roots')) {
          themeId = 'southern-roots';
        } else if (filename.startsWith('sunday-suppers')) {
          themeId = 'sunday-suppers';
        } else if (filename.startsWith('victory-kitchen')) {
          themeId = 'victory-kitchen';
        } else {
          console.log(`  ⚠️  Skipping ${filename} - unknown theme`);
          skippedCount++;
          continue;
        }

        const storagePath = `recipes/${themeId}/${filename}`;

        // Check if file already exists
        const [exists] = await bucket.file(storagePath).exists();
        if (exists) {
          console.log(`  → ${filename} (already exists)`);
          skippedCount++;
          continue;
        }

        // Upload file
        const localPath = path.join(LOCAL_IMAGES_DIR, filename);
        await bucket.upload(localPath, {
          destination: storagePath,
          metadata: {
            contentType: 'image/webp',
            cacheControl: 'public, max-age=31536000', // 1 year
          }
        });

        console.log(`  ✓ ${filename} → ${storagePath}`);
        uploadedCount++;

      } catch (error) {
        console.error(`  ✗ ${filename} - ${error.message}`);
        errorCount++;
      }
    }

    console.log(`\n✅ Upload complete:`);
    console.log(`   - Uploaded: ${uploadedCount}`);
    console.log(`   - Skipped (already exist): ${skippedCount}`);
    console.log(`   - Errors: ${errorCount}`);

  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

uploadImages();
