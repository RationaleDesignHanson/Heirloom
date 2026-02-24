/**
 * Deduplicate collections for a user
 * Merges duplicate collections (same name + type) and fixes recipe links
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      path.resolve(__dirname, '../../../service-account-key.json')
    ),
  });
}

const db = admin.firestore();

interface CollectionDoc {
  id: string;
  name: string;
  type: string;
  recipeIds: string[];
  data: admin.firestore.DocumentData;
}

async function dedupeCollections(userId: string, dryRun: boolean = true) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(dryRun ? 'DRY RUN - No changes will be made' : '🔥 LIVE RUN - Making changes');
  console.log(`${'='.repeat(60)}\n`);

  const collectionsRef = db.collection(`users/${userId}/collections`);
  const snapshot = await collectionsRef.get();

  console.log(`Found ${snapshot.size} collections\n`);

  // Group by name + type
  const groups = new Map<string, CollectionDoc[]>();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const key = `${data.name}|${data.collectionType}`;

    if (!groups.has(key)) {
      groups.set(key, []);
    }

    groups.get(key)!.push({
      id: doc.id,
      name: data.name,
      type: data.collectionType,
      recipeIds: data.recipeIds || [],
      data: data,
    });
  }

  // Find duplicates
  let duplicateGroups = 0;
  let collectionsToDelete = 0;
  let recipesToRelink = 0;

  for (const [key, collections] of groups) {
    if (collections.length > 1) {
      duplicateGroups++;
      console.log(`\n📁 DUPLICATE: ${key}`);

      // Sort by most recipes, then by oldest
      collections.sort((a, b) => {
        if (b.recipeIds.length !== a.recipeIds.length) {
          return b.recipeIds.length - a.recipeIds.length;
        }
        return 0; // Keep original order if same count
      });

      const keeper = collections[0];
      const duplicates = collections.slice(1);

      console.log(`   ✓ KEEP: ${keeper.id} (${keeper.recipeIds.length} recipes)`);

      // Merge recipe IDs from duplicates
      const allRecipeIds = new Set(keeper.recipeIds);
      for (const dup of duplicates) {
        console.log(`   ✗ DELETE: ${dup.id} (${dup.recipeIds.length} recipes)`);
        collectionsToDelete++;
        for (const recipeId of dup.recipeIds) {
          if (!allRecipeIds.has(recipeId)) {
            allRecipeIds.add(recipeId);
            recipesToRelink++;
          }
        }
      }

      const mergedRecipeIds = Array.from(allRecipeIds);
      if (mergedRecipeIds.length > keeper.recipeIds.length) {
        console.log(`   → Merging ${mergedRecipeIds.length - keeper.recipeIds.length} recipes into keeper`);
      }

      if (!dryRun) {
        // Update keeper with merged recipeIds
        await collectionsRef.doc(keeper.id).update({
          recipeIds: mergedRecipeIds,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update recipes to point to keeper collection
        for (const recipeId of mergedRecipeIds) {
          const recipeRef = db.collection(`users/${userId}/recipes`).doc(recipeId);
          const recipeDoc = await recipeRef.get();

          if (recipeDoc.exists) {
            const recipeData = recipeDoc.data()!;
            const collectionIds = recipeData.collectionIds || [];

            // Remove duplicate collection IDs, add keeper
            const newCollectionIds = collectionIds.filter(
              (id: string) => !duplicates.some(d => d.id === id || d.id.toLowerCase() === id.toLowerCase())
            );

            if (!newCollectionIds.includes(keeper.id) && !newCollectionIds.includes(keeper.id.toLowerCase())) {
              newCollectionIds.push(keeper.id.toLowerCase());
            }

            await recipeRef.update({
              collectionIds: newCollectionIds,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }

        // Delete duplicates
        for (const dup of duplicates) {
          await collectionsRef.doc(dup.id).delete();
        }
      }
    }
  }

  console.log(`\n${'='.repeat(60)}`);
  console.log('SUMMARY');
  console.log(`${'='.repeat(60)}`);
  console.log(`Duplicate groups: ${duplicateGroups}`);
  console.log(`Collections to delete: ${collectionsToDelete}`);
  console.log(`Recipes to relink: ${recipesToRelink}`);

  if (dryRun && duplicateGroups > 0) {
    console.log(`\nRun with --fix to apply changes`);
  }
}

async function checkFromFriends(userId: string) {
  console.log(`\n${'='.repeat(60)}`);
  console.log('FROM FRIENDS ANALYSIS');
  console.log(`${'='.repeat(60)}\n`);

  const collectionsRef = db.collection(`users/${userId}/collections`);
  const snapshot = await collectionsRef.where('name', '==', 'From Friends').get();

  console.log(`Found ${snapshot.size} "From Friends" collections:\n`);

  for (const doc of snapshot.docs) {
    const data = doc.data();
    console.log(`Collection ID: ${doc.id}`);
    console.log(`  Type: ${data.collectionType}`);
    console.log(`  Recipe IDs: ${data.recipeIds?.length || 0}`);

    if (data.recipeIds?.length > 0) {
      console.log(`  Recipes:`);
      for (const recipeId of data.recipeIds) {
        const recipeDoc = await db.collection(`users/${userId}/recipes`).doc(recipeId).get();
        if (recipeDoc.exists) {
          const recipeData = recipeDoc.data()!;
          console.log(`    - ${recipeData.title}`);
          console.log(`      sharedBy: ${recipeData.sharedBy || 'n/a'}`);
          console.log(`      sharedDate: ${recipeData.sharedDate?.toDate?.() || 'n/a'}`);
        } else {
          console.log(`    - [Recipe not found: ${recipeId}]`);
        }
      }
    }
    console.log();
  }
}

async function main() {
  const userId = process.argv[2] || 'TuQgh4k7HSY8p5eDk90ja53u9ki2';
  const shouldFix = process.argv.includes('--fix');

  await checkFromFriends(userId);
  await dedupeCollections(userId, !shouldFix);
}

main().catch(console.error);
