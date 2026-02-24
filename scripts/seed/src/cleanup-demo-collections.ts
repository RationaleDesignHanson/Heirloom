/**
 * Clean up duplicate collections for demo and test accounts
 *
 * This script:
 * 1. Identifies duplicate collections (same name + type)
 * 2. Merges recipe IDs from duplicates into the primary (most recipes)
 * 3. Updates recipes' collectionIds to point to the primary
 * 4. Deletes duplicate collections
 *
 * Run: npx ts-node src/cleanup-demo-collections.ts [--fix]
 *
 * Without --fix: Dry run (shows what would be changed)
 * With --fix: Actually makes changes
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
const auth = admin.auth();

// Accounts to clean up
const ACCOUNTS_TO_CLEANUP = [
  'demo@heirloomrecipebox.app',
  'hanson@rationale.work',
  'tester01@heirloomrecipebox.app',
];

interface CollectionDoc {
  id: string;
  name: string;
  type: string;
  recipeIds: string[];
  createdAt: admin.firestore.Timestamp | null;
  data: admin.firestore.DocumentData;
}

async function getUserIdByEmail(email: string): Promise<string | null> {
  try {
    const user = await auth.getUserByEmail(email);
    return user.uid;
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log(`  User not found: ${email}`);
      return null;
    }
    throw error;
  }
}

async function analyzeCollections(userId: string): Promise<{
  duplicateGroups: number;
  collectionsToDelete: number;
  recipesToRelink: number;
  details: Map<string, CollectionDoc[]>;
}> {
  const collectionsRef = db.collection(`users/${userId}/collections`);
  const snapshot = await collectionsRef.get();

  // Group by name + type
  const groups = new Map<string, CollectionDoc[]>();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const key = `${data.name}|${data.collectionType || 'unknown'}`;

    if (!groups.has(key)) {
      groups.set(key, []);
    }

    groups.get(key)!.push({
      id: doc.id,
      name: data.name || 'Unnamed',
      type: data.collectionType || 'unknown',
      recipeIds: data.recipeIds || [],
      createdAt: data.createdDate || data.createdAt || null,
      data: data,
    });
  }

  // Count duplicates
  let duplicateGroups = 0;
  let collectionsToDelete = 0;
  let recipesToRelink = 0;
  const details = new Map<string, CollectionDoc[]>();

  for (const [key, collections] of groups) {
    if (collections.length > 1) {
      duplicateGroups++;
      details.set(key, collections);

      // Sort by most recipes, then by oldest (prefer older)
      collections.sort((a, b) => {
        if (b.recipeIds.length !== a.recipeIds.length) {
          return b.recipeIds.length - a.recipeIds.length;
        }
        // Prefer older collection
        const aTime = a.createdAt?.toMillis() || Infinity;
        const bTime = b.createdAt?.toMillis() || Infinity;
        return aTime - bTime;
      });

      const keeper = collections[0];
      const duplicates = collections.slice(1);
      collectionsToDelete += duplicates.length;

      // Count recipes to relink
      const allRecipeIds = new Set(keeper.recipeIds);
      for (const dup of duplicates) {
        for (const recipeId of dup.recipeIds) {
          if (!allRecipeIds.has(recipeId)) {
            allRecipeIds.add(recipeId);
            recipesToRelink++;
          }
        }
      }
    }
  }

  return { duplicateGroups, collectionsToDelete, recipesToRelink, details };
}

async function cleanupUser(userId: string, email: string, dryRun: boolean): Promise<void> {
  console.log(`\n${'─'.repeat(60)}`);
  console.log(`Analyzing: ${email} (${userId})`);
  console.log(`${'─'.repeat(60)}`);

  const analysis = await analyzeCollections(userId);

  if (analysis.duplicateGroups === 0) {
    console.log('  ✅ No duplicate collections found');
    return;
  }

  console.log(`\n  Found ${analysis.duplicateGroups} duplicate groups:`);

  for (const [key, collections] of analysis.details) {
    const [name, type] = key.split('|');
    console.log(`\n  📁 "${name}" (${type}): ${collections.length} copies`);

    const keeper = collections[0];
    const duplicates = collections.slice(1);

    console.log(`     ✓ KEEP: ${keeper.id.substring(0, 8)}... (${keeper.recipeIds.length} recipes)`);
    for (const dup of duplicates) {
      console.log(`     ✗ DELETE: ${dup.id.substring(0, 8)}... (${dup.recipeIds.length} recipes)`);
    }

    if (!dryRun) {
      const collectionsRef = db.collection(`users/${userId}/collections`);

      // Merge recipe IDs
      const allRecipeIds = new Set(keeper.recipeIds);
      for (const dup of duplicates) {
        for (const recipeId of dup.recipeIds) {
          allRecipeIds.add(recipeId);
        }
      }

      const mergedRecipeIds = Array.from(allRecipeIds);

      // Update keeper with merged recipeIds
      if (mergedRecipeIds.length > keeper.recipeIds.length) {
        await collectionsRef.doc(keeper.id).update({
          recipeIds: mergedRecipeIds,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`     → Merged ${mergedRecipeIds.length - keeper.recipeIds.length} recipes into keeper`);
      }

      // Update recipes to point to keeper collection
      for (const recipeId of mergedRecipeIds) {
        const recipeRef = db.collection(`users/${userId}/recipes`).doc(recipeId);
        const recipeDoc = await recipeRef.get();

        if (recipeDoc.exists) {
          const recipeData = recipeDoc.data()!;
          const collectionIds: string[] = recipeData.collectionIds || [];

          // Remove duplicate collection IDs and add keeper
          const duplicateIds = new Set(duplicates.map(d => d.id.toLowerCase()));
          const newCollectionIds = collectionIds.filter(
            (id: string) => !duplicateIds.has(id.toLowerCase())
          );

          const keeperIdLower = keeper.id.toLowerCase();
          if (!newCollectionIds.some(id => id.toLowerCase() === keeperIdLower)) {
            newCollectionIds.push(keeperIdLower);
          }

          // Only update if changed
          if (JSON.stringify(newCollectionIds.sort()) !== JSON.stringify(collectionIds.sort())) {
            await recipeRef.update({
              collectionIds: newCollectionIds,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // Delete duplicates
      for (const dup of duplicates) {
        await collectionsRef.doc(dup.id).delete();
        console.log(`     🗑️  Deleted: ${dup.id.substring(0, 8)}...`);
      }
    }
  }

  console.log(`\n  Summary:`);
  console.log(`    Duplicate groups: ${analysis.duplicateGroups}`);
  console.log(`    Collections to delete: ${analysis.collectionsToDelete}`);
  console.log(`    Recipes to relink: ${analysis.recipesToRelink}`);
}

async function main(): Promise<void> {
  const dryRun = !process.argv.includes('--fix');

  console.log('\n' + '═'.repeat(60));
  console.log(dryRun ? '🔍 DRY RUN - No changes will be made' : '🔥 LIVE RUN - Making changes');
  console.log('═'.repeat(60));

  for (const email of ACCOUNTS_TO_CLEANUP) {
    const userId = await getUserIdByEmail(email);
    if (userId) {
      await cleanupUser(userId, email, dryRun);
    }
  }

  console.log('\n' + '═'.repeat(60));
  if (dryRun) {
    console.log('Run with --fix to apply changes');
  } else {
    console.log('✅ Cleanup complete!');
  }
  console.log('═'.repeat(60) + '\n');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
