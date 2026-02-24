/**
 * Clean up duplicate collections in Firestore for a given user
 * Keeps the collection with the most recipes, deletes duplicates
 *
 * Run: npx ts-node src/cleanup-duplicates.ts <email>
 * Example: npx ts-node src/cleanup-duplicates.ts hanson@rationale.work
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();
const auth = admin.auth();

interface CollectionDoc {
  id: string;
  docId: string;
  name: string;
  recipeIds: string[];
  data: admin.firestore.DocumentData;
}

async function cleanupDuplicateCollections(email: string): Promise<void> {
  console.log(`\nCleaning up duplicate collections for: ${email}\n`);

  try {
    const user = await auth.getUserByEmail(email);
    console.log(`Found user: ${user.uid}`);

    const collectionsRef = db.collection('users').doc(user.uid).collection('collections');
    const snapshot = await collectionsRef.get();

    console.log(`Found ${snapshot.size} total collections\n`);

    // Group collections by name
    const collectionsByName: Map<string, CollectionDoc[]> = new Map();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const name = data.name || 'Unnamed';
      const recipeIds = data.recipeIds || [];

      const collDoc: CollectionDoc = {
        id: data.id || doc.id,
        docId: doc.id,
        name,
        recipeIds,
        data,
      };

      if (!collectionsByName.has(name)) {
        collectionsByName.set(name, []);
      }
      collectionsByName.get(name)!.push(collDoc);
    }

    // Find and clean up duplicates
    let totalDeleted = 0;
    let totalMerged = 0;

    for (const [name, collections] of collectionsByName) {
      if (collections.length <= 1) continue;

      console.log(`\n📁 "${name}" has ${collections.length} duplicates:`);

      // Sort by recipe count (descending) - keep the one with most recipes
      collections.sort((a, b) => b.recipeIds.length - a.recipeIds.length);

      const primary = collections[0];
      const duplicates = collections.slice(1);

      console.log(`  ✓ Keeping: ${primary.docId} (${primary.recipeIds.length} recipes)`);

      // Merge recipe IDs from duplicates into primary
      const mergedRecipeIds = new Set(primary.recipeIds);
      for (const dup of duplicates) {
        for (const recipeId of dup.recipeIds) {
          if (!mergedRecipeIds.has(recipeId)) {
            mergedRecipeIds.add(recipeId);
            totalMerged++;
          }
        }
      }

      // Update primary with merged recipe IDs
      if (mergedRecipeIds.size > primary.recipeIds.length) {
        await collectionsRef.doc(primary.docId).update({
          recipeIds: Array.from(mergedRecipeIds),
        });
        console.log(`  ↳ Merged ${mergedRecipeIds.size - primary.recipeIds.length} recipes into primary`);
      }

      // Delete duplicates
      for (const dup of duplicates) {
        await collectionsRef.doc(dup.docId).delete();
        console.log(`  ✗ Deleted: ${dup.docId} (${dup.recipeIds.length} recipes)`);
        totalDeleted++;
      }
    }

    console.log(`\n═══════════════════════════════════════`);
    console.log(`✅ Cleanup complete!`);
    console.log(`   Deleted: ${totalDeleted} duplicate collections`);
    console.log(`   Merged: ${totalMerged} recipes into primary collections`);
    console.log(`═══════════════════════════════════════\n`);

  } catch (error: any) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

// CLI handling
if (require.main === module) {
  const email = process.argv[2];

  if (!email) {
    console.log('Usage: npx ts-node src/cleanup-duplicates.ts <email>');
    console.log('Example: npx ts-node src/cleanup-duplicates.ts hanson@rationale.work');
    process.exit(1);
  }

  cleanupDuplicateCollections(email)
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Error:', err);
      process.exit(1);
    });
}

export { cleanupDuplicateCollections };
