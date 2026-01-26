#!/usr/bin/env node

/**
 * Cleanup Old Images Script
 * Deletes all old recipe images from Firebase Storage before uploading new ones
 *
 * Usage: node cleanup-old-images.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'heirloom-ios-prod.firebasestorage.app'
  });
}

const bucket = admin.storage().bucket();

async function cleanupOldImages() {
  console.log('🗑️  Cleaning up old recipe images from Firebase Storage...\n');

  try {
    // Delete all files in recipes/ directory
    const [files] = await bucket.getFiles({
      prefix: 'recipes/'
    });

    if (files.length === 0) {
      console.log('✓ No old recipe images found to delete');
      return;
    }

    console.log(`Found ${files.length} files to delete\n`);

    let deletedCount = 0;
    let errorCount = 0;

    for (const file of files) {
      try {
        await file.delete();
        console.log(`  ✓ Deleted: ${file.name}`);
        deletedCount++;
      } catch (error) {
        console.log(`  ✗ Failed to delete: ${file.name} - ${error.message}`);
        errorCount++;
      }
    }

    console.log(`\n📊 Cleanup Summary:`);
    console.log(`   Deleted: ${deletedCount}`);
    console.log(`   Failed: ${errorCount}`);

    if (deletedCount > 0) {
      console.log('\n✅ Old images cleaned up successfully!');
      console.log('\n🎯 Next Step: Upload new images with npm run upload-images');
    }

  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    console.error(error.stack);
    process.exit(1);
  }

  process.exit(0);
}

// Run cleanup
cleanupOldImages().catch((error) => {
  console.error('❌ Fatal error:', error);
  console.error(error.stack);
  process.exit(1);
});
