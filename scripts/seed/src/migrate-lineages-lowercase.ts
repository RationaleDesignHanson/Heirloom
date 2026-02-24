/**
 * Migrate all lineage documents to use lowercase UUIDs
 *
 * This fixes the case mismatch between:
 * - Old lineage documents (uppercase UUIDs)
 * - New code that queries with lowercase UUIDs (firebaseString)
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(process.env.GOOGLE_APPLICATION_CREDENTIALS || '../service-account-key.json'),
  });
}

const db = admin.firestore();

function toLowerCase(value: any): string | null {
  if (typeof value === 'string') {
    return value.toLowerCase();
  }
  return null;
}

async function migrateLineages() {
  console.log('=== Migrating lineage documents to lowercase UUIDs ===\n');

  const snapshot = await db.collection('lineages').get();
  console.log(`Found ${snapshot.size} lineage documents\n`);

  let migratedCount = 0;
  let skippedCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const updates: Record<string, any> = {};
    let needsUpdate = false;

    // Check and update rootRecipeId
    if (data.rootRecipeId && data.rootRecipeId !== data.rootRecipeId.toLowerCase()) {
      updates.rootRecipeId = data.rootRecipeId.toLowerCase();
      needsUpdate = true;
    }

    // Check and update parentRecipeId
    if (data.parentRecipeId && data.parentRecipeId !== data.parentRecipeId.toLowerCase()) {
      updates.parentRecipeId = data.parentRecipeId.toLowerCase();
      needsUpdate = true;
    }

    // Check and update currentRecipeId
    if (data.currentRecipeId && data.currentRecipeId !== data.currentRecipeId.toLowerCase()) {
      updates.currentRecipeId = data.currentRecipeId.toLowerCase();
      needsUpdate = true;
    }

    // Check and update id field
    if (data.id && data.id !== data.id.toLowerCase()) {
      updates.id = data.id.toLowerCase();
      needsUpdate = true;
    }

    if (needsUpdate) {
      console.log(`Migrating: ${doc.id}`);
      console.log(`  Before: rootRecipeId=${data.rootRecipeId}`);
      console.log(`  After:  rootRecipeId=${updates.rootRecipeId || data.rootRecipeId}`);

      await doc.ref.update(updates);
      migratedCount++;
    } else {
      skippedCount++;
    }
  }

  console.log(`\n=== Migration complete ===`);
  console.log(`Migrated: ${migratedCount}`);
  console.log(`Skipped (already lowercase): ${skippedCount}`);
}

migrateLineages()
  .then(() => process.exit(0))
  .catch(e => { console.error(e); process.exit(1); });
