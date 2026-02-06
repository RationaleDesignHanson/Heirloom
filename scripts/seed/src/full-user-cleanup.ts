/**
 * Full cleanup of a user's recipes and collections
 * WARNING: This deletes ALL recipes (except theme recipes) and ALL collections
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

// Theme collection names to preserve
const THEME_COLLECTION_NAMES = [
  'Heritage Southern',
  'Italian Classics',
  'Asian Favorites',
  'Mexican Traditions',
  'French Bistro',
  'Mediterranean',
];

async function fullUserCleanup(userId: string): Promise<void> {
  console.log(`\n🧹 FULL USER CLEANUP for: ${userId}`);
  console.log('='.repeat(50));

  // 1. Delete ALL recipes and their subcollections
  console.log('\nDeleting all recipes...');
  const recipesRef = db.collection(`users/${userId}/recipes`);
  const recipes = await recipesRef.get();
  
  let deletedRecipes = 0;
  for (const doc of recipes.docs) {
    // Delete subcollections
    const ingredientsRef = doc.ref.collection('ingredients');
    const ingredients = await ingredientsRef.get();
    for (const ing of ingredients.docs) {
      await ing.ref.delete();
    }
    
    const instructionsRef = doc.ref.collection('instructions');
    const instructions = await instructionsRef.get();
    for (const inst of instructions.docs) {
      await inst.ref.delete();
    }
    
    const commentsRef = doc.ref.collection('comments');
    const comments = await commentsRef.get();
    for (const comment of comments.docs) {
      await comment.ref.delete();
    }
    
    await doc.ref.delete();
    deletedRecipes++;
    console.log(`  Deleted: ${doc.data().title || doc.id}`);
  }
  console.log(`  Total recipes deleted: ${deletedRecipes}`);

  // 2. Delete ALL collections (except themes if you want to preserve)
  console.log('\nDeleting all collections...');
  const collectionsRef = db.collection(`users/${userId}/collections`);
  const collections = await collectionsRef.get();
  
  let deletedCollections = 0;
  for (const doc of collections.docs) {
    const data = doc.data();
    // Optionally preserve theme collections
    // if (THEME_COLLECTION_NAMES.includes(data.name)) {
    //   console.log(`  Preserving theme: ${data.name}`);
    //   continue;
    // }
    await doc.ref.delete();
    deletedCollections++;
    console.log(`  Deleted collection: ${data.name}`);
  }
  console.log(`  Total collections deleted: ${deletedCollections}`);

  // 3. Delete lineages for this user
  console.log('\nDeleting user lineages...');
  const lineagesRef = db.collection(`users/${userId}/lineages`);
  const lineages = await lineagesRef.get();
  let deletedLineages = 0;
  for (const doc of lineages.docs) {
    await doc.ref.delete();
    deletedLineages++;
  }
  console.log(`  Deleted ${deletedLineages} lineage records`);

  // Also clean global lineages where user is owner
  const globalLineages = await db.collection('lineages')
    .where('ownerId', '==', userId)
    .get();
  for (const doc of globalLineages.docs) {
    await doc.ref.delete();
    deletedLineages++;
  }
  console.log(`  Deleted ${globalLineages.size} global lineage records`);

  console.log('\n' + '='.repeat(50));
  console.log('✅ CLEANUP COMPLETE');
  console.log(`  Recipes: ${deletedRecipes}`);
  console.log(`  Collections: ${deletedCollections}`);
  console.log(`  Lineages: ${deletedLineages}`);
}

const userId = process.argv[2];
if (!userId) {
  console.error('Usage: npx ts-node src/full-user-cleanup.ts <userId>');
  process.exit(1);
}

fullUserCleanup(userId)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
