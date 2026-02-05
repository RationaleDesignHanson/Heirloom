#!/usr/bin/env npx ts-node --esm
/**
 * Cleanup Demo Seeds
 * Removes all demo seed data from Firestore and Storage
 *
 * Usage:
 *   npm run cleanup
 */

import { initializeFirebase, getDb } from './utils/firebase';
import { deleteAllSeedImages } from './utils/storage';

// ============================================================================
// Cleanup Logic
// ============================================================================

async function cleanupFirestore(): Promise<number> {
  console.log('\n🗑️  Cleaning up Firestore documents...');
  const db = getDb();

  // Query all demo seeds
  const snapshot = await db
    .collection('publicRecipes')
    .where('isDemoSeed', '==', true)
    .get();

  if (snapshot.empty) {
    console.log('   No demo seeds found.');
    return 0;
  }

  // Delete in batches of 500 (Firestore limit)
  const batchSize = 500;
  let deletedCount = 0;

  for (let i = 0; i < snapshot.docs.length; i += batchSize) {
    const batch = db.batch();
    const batchDocs = snapshot.docs.slice(i, i + batchSize);

    batchDocs.forEach((doc) => {
      batch.delete(doc.ref);
      deletedCount++;
    });

    await batch.commit();
    console.log(`   Deleted batch of ${batchDocs.length} documents`);
  }

  return deletedCount;
}

async function cleanupStorage(): Promise<number> {
  console.log('\n🗑️  Cleaning up Storage images...');

  try {
    const deletedCount = await deleteAllSeedImages();
    return deletedCount;
  } catch (error) {
    console.error('   Error cleaning up storage:', error);
    return 0;
  }
}

async function main(): Promise<void> {
  console.log('🧹 Demo Seeds Cleanup\n');
  console.log('This will delete ALL demo seed data from:');
  console.log('  - Firestore publicRecipes collection (where isDemoSeed == true)');
  console.log('  - Firebase Storage seed/demo/ folder');

  // Initialize Firebase
  console.log('\n🔥 Initializing Firebase...');
  initializeFirebase();

  // Cleanup Firestore
  const firestoreDeleted = await cleanupFirestore();

  // Cleanup Storage
  const storageDeleted = await cleanupStorage();

  // Summary
  console.log('\n✅ Cleanup complete!');
  console.log('─'.repeat(40));
  console.log(`Firestore documents deleted: ${firestoreDeleted}`);
  console.log(`Storage files deleted: ${storageDeleted}`);

  if (firestoreDeleted === 0 && storageDeleted === 0) {
    console.log('\nNo demo data was found to clean up.');
  } else {
    console.log('\nAll demo seeds have been removed.');
    console.log('Run `npm run seed` to create new demo data.');
  }
}

// Run cleanup
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
