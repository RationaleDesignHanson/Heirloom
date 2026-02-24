/**
 * Cleanup duplicate lineage records in Firebase
 * 
 * The seed-demo-lineages.ts script was creating random document IDs,
 * resulting in multiple lineage records for the same recipe.
 * This script removes duplicates, keeping only the newest one.
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

async function cleanupDuplicateLineages(): Promise<void> {
  console.log('Cleaning up duplicate lineage records...\n');

  // Fetch all lineages
  const snapshot = await db.collection('lineages').get();
  console.log(`Found ${snapshot.size} total lineage documents\n`);

  // Group by currentRecipeId + ownerId (unique key for a lineage)
  const lineageGroups: Map<string, admin.firestore.QueryDocumentSnapshot[]> = new Map();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const currentRecipeId = data.currentRecipeId || data.recipeId || '';
    const ownerId = data.ownerId || '';
    const key = `${currentRecipeId}_${ownerId}`;

    if (!lineageGroups.has(key)) {
      lineageGroups.set(key, []);
    }
    lineageGroups.get(key)!.push(doc);
  }

  // Find and delete duplicates
  let deletedCount = 0;
  for (const [key, docs] of lineageGroups) {
    if (docs.length > 1) {
      console.log(`Found ${docs.length} duplicates for: ${key}`);

      // Sort by updatedAt (newest first), keep the first one
      docs.sort((a, b) => {
        const aTime = a.data().updatedAt?.toMillis?.() || 0;
        const bTime = b.data().updatedAt?.toMillis?.() || 0;
        return bTime - aTime;
      });

      // Delete all but the first (newest)
      for (let i = 1; i < docs.length; i++) {
        console.log(`  Deleting duplicate: ${docs[i].id}`);
        await docs[i].ref.delete();
        deletedCount++;
      }
      console.log(`  Kept: ${docs[0].id}`);
    }
  }

  console.log(`\nDeleted ${deletedCount} duplicate lineage records`);
}

cleanupDuplicateLineages()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
