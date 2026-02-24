/**
 * Check for orphaned recipes (recipes not in any collection)
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

async function checkOrphanedRecipes(email: string): Promise<void> {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Checking orphaned recipes for: ${email}`);
  console.log('='.repeat(60));

  try {
    const user = await auth.getUserByEmail(email);
    const userId = user.uid;

    // Get all recipes
    const recipesSnap = await db.collection('users').doc(userId).collection('recipes').get();
    const recipes = recipesSnap.docs.map(doc => ({
      id: doc.id,
      title: doc.data().title || 'Untitled',
      collectionIds: doc.data().collectionIds || [],
    }));

    // Get all collections
    const collectionsSnap = await db.collection('users').doc(userId).collection('collections').get();
    const collections = new Map<string, { name: string; recipeIds: string[] }>();
    collectionsSnap.docs.forEach(doc => {
      collections.set(doc.id, {
        name: doc.data().name || 'Unnamed',
        recipeIds: doc.data().recipeIds || [],
      });
    });

    console.log(`\nTotal recipes: ${recipes.length}`);
    console.log(`Total collections: ${collections.size}`);

    // Check each recipe
    const orphaned: typeof recipes = [];
    const inFavoritesOnly: typeof recipes = [];

    for (const recipe of recipes) {
      // Check if recipe is in ANY collection's recipeIds
      let foundIn: string[] = [];
      for (const [collId, coll] of collections) {
        if (coll.recipeIds.includes(recipe.id)) {
          foundIn.push(coll.name);
        }
      }

      if (foundIn.length === 0) {
        orphaned.push(recipe);
      } else if (foundIn.length === 1 && foundIn[0] === 'Favorites') {
        inFavoritesOnly.push(recipe);
      }
    }

    if (orphaned.length > 0) {
      console.log(`\n🚨 ORPHANED RECIPES (not in any collection):`);
      orphaned.forEach(r => console.log(`  - ${r.title} (${r.id})`));
    } else {
      console.log(`\n✅ No orphaned recipes`);
    }

    if (inFavoritesOnly.length > 0) {
      console.log(`\n⚠️ RECIPES ONLY IN FAVORITES (won't show if Favorites hidden):`);
      inFavoritesOnly.forEach(r => console.log(`  - ${r.title} (${r.id})`));
    }

    // Show collection breakdown
    console.log(`\nCollection breakdown:`);
    for (const [collId, coll] of collections) {
      console.log(`  - ${coll.name}: ${coll.recipeIds.length} recipes`);
    }

  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log('User not found');
    } else {
      throw error;
    }
  }
}

async function main() {
  await checkOrphanedRecipes('deletetest@heirloomrecipebox.app');
  await checkOrphanedRecipes('demo@heirloomrecipebox.app');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
