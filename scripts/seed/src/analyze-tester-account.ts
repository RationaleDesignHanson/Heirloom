/**
 * Comprehensive analysis of tester account state
 * Checks: recipes, collections, images, collection-recipe links
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
    storageBucket: 'heirloom-7b945.firebasestorage.app',
  });
}

const db = admin.firestore();
const auth = admin.auth();
const bucket = admin.storage().bucket();

interface RecipeInfo {
  id: string;
  title: string;
  hasFirebaseImageURL: boolean;
  firebaseImageURL?: string;
  imageExists?: boolean;
  isThemeRecipe: boolean;
  sourceThemeId?: string;
  collectionIds: string[];
}

interface CollectionInfo {
  id: string;
  name: string;
  recipeIds: string[];
  recipeCount: number;
}

async function analyzeAccount(email: string): Promise<void> {
  console.log(`\n${'='.repeat(70)}`);
  console.log(`ANALYZING: ${email}`);
  console.log('='.repeat(70));

  let userId: string;
  try {
    const user = await auth.getUserByEmail(email);
    userId = user.uid;
    console.log(`User ID: ${userId}`);
    console.log(`Created: ${user.metadata.creationTime}`);
    console.log(`Last Sign In: ${user.metadata.lastSignInTime}`);
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log('ERROR: User not found in Firebase Auth');
      return;
    }
    throw error;
  }

  // ============ RECIPES ============
  console.log(`\n${'─'.repeat(70)}`);
  console.log('RECIPES');
  console.log('─'.repeat(70));

  const recipesSnap = await db.collection(`users/${userId}/recipes`).get();
  const recipes: RecipeInfo[] = [];

  let withImage = 0;
  let withoutImage = 0;
  let themeRecipes = 0;
  let userRecipes = 0;

  for (const doc of recipesSnap.docs) {
    const data = doc.data();
    const hasImage = !!data.firebaseImageURL;

    const info: RecipeInfo = {
      id: doc.id,
      title: data.title || '(Untitled)',
      hasFirebaseImageURL: hasImage,
      firebaseImageURL: data.firebaseImageURL,
      isThemeRecipe: !!data.isThemeRecipe,
      sourceThemeId: data.sourceThemeId,
      collectionIds: data.collectionIds || [],
    };

    if (hasImage) withImage++;
    else withoutImage++;

    if (data.isThemeRecipe) themeRecipes++;
    else userRecipes++;

    recipes.push(info);
  }

  console.log(`Total Recipes: ${recipes.length}`);
  console.log(`  Theme Recipes: ${themeRecipes}`);
  console.log(`  User Recipes: ${userRecipes}`);
  console.log(`  With Image URL: ${withImage}`);
  console.log(`  Without Image URL: ${withoutImage}`);

  // Check image existence for a sample
  if (recipes.length > 0 && withImage > 0) {
    console.log(`\nChecking image URLs validity (sample of up to 5)...`);
    const recipesWithImages = recipes.filter(r => r.hasFirebaseImageURL).slice(0, 5);

    for (const recipe of recipesWithImages) {
      try {
        // Extract storage path from URL
        const url = recipe.firebaseImageURL!;
        if (url.includes('firebasestorage.googleapis.com')) {
          // Try to fetch the URL to verify it's accessible
          const response = await fetch(url, { method: 'HEAD' });
          recipe.imageExists = response.ok;
          console.log(`  ${recipe.imageExists ? '✓' : '✗'} ${recipe.title}`);
        }
      } catch (e) {
        recipe.imageExists = false;
        console.log(`  ✗ ${recipe.title} (fetch error)`);
      }
    }
  }

  // List recipes without images
  if (withoutImage > 0) {
    console.log(`\nRecipes WITHOUT image URL:`);
    recipes.filter(r => !r.hasFirebaseImageURL).forEach(r => {
      console.log(`  - ${r.title} ${r.isThemeRecipe ? '(theme)' : '(user)'}`);
    });
  }

  // ============ COLLECTIONS ============
  console.log(`\n${'─'.repeat(70)}`);
  console.log('COLLECTIONS');
  console.log('─'.repeat(70));

  const collectionsSnap = await db.collection(`users/${userId}/collections`).get();
  const collections: CollectionInfo[] = [];
  const collectionNames: Record<string, string[]> = {};

  for (const doc of collectionsSnap.docs) {
    const data = doc.data();
    const name = data.name || '(Unnamed)';

    if (!collectionNames[name]) collectionNames[name] = [];
    collectionNames[name].push(doc.id);

    collections.push({
      id: doc.id,
      name,
      recipeIds: data.recipeIds || [],
      recipeCount: (data.recipeIds || []).length,
    });
  }

  console.log(`Total Collections: ${collections.length}`);

  // Check for duplicates
  const duplicates = Object.entries(collectionNames).filter(([_, ids]) => ids.length > 1);
  if (duplicates.length > 0) {
    console.log(`\n⚠️  DUPLICATE COLLECTIONS FOUND:`);
    duplicates.forEach(([name, ids]) => {
      console.log(`  "${name}" appears ${ids.length} times:`);
      ids.forEach(id => console.log(`    - ${id}`));
    });
  }

  // Check for required collections
  const hasFavorites = collections.some(c => c.name === 'Favorites');
  console.log(`\nHas 'Favorites': ${hasFavorites ? '✓ YES' : '✗ NO - REQUIRED!'}`);

  // List collections with recipe counts
  console.log(`\nCollection Details:`);
  collections.sort((a, b) => a.name.localeCompare(b.name)).forEach(c => {
    console.log(`  ${c.name}: ${c.recipeCount} recipes`);
  });

  // ============ INTEGRITY CHECK ============
  console.log(`\n${'─'.repeat(70)}`);
  console.log('INTEGRITY CHECK');
  console.log('─'.repeat(70));

  // Check if recipe collectionIds match collection recipeIds
  let integrityIssues = 0;

  // Build a map of collection ID to name
  const collectionIdToName: Record<string, string> = {};
  collections.forEach(c => collectionIdToName[c.id] = c.name);

  // Check each recipe's collectionIds
  for (const recipe of recipes) {
    for (const collId of recipe.collectionIds) {
      const collection = collections.find(c => c.id === collId);
      if (!collection) {
        console.log(`  ⚠️  Recipe "${recipe.title}" references non-existent collection: ${collId}`);
        integrityIssues++;
      } else if (!collection.recipeIds.includes(recipe.id)) {
        console.log(`  ⚠️  Recipe "${recipe.title}" in collection "${collection.name}" but not in recipeIds`);
        integrityIssues++;
      }
    }
  }

  // Check each collection's recipeIds
  for (const collection of collections) {
    for (const recipeId of collection.recipeIds) {
      const recipe = recipes.find(r => r.id === recipeId);
      if (!recipe) {
        console.log(`  ⚠️  Collection "${collection.name}" references non-existent recipe: ${recipeId}`);
        integrityIssues++;
      }
    }
  }

  if (integrityIssues === 0) {
    console.log(`  ✓ No integrity issues found`);
  } else {
    console.log(`\n  Total integrity issues: ${integrityIssues}`);
  }

  // ============ SUMMARY ============
  console.log(`\n${'='.repeat(70)}`);
  console.log('SUMMARY');
  console.log('='.repeat(70));
  console.log(`Recipes: ${recipes.length} (${withImage} with images, ${withoutImage} without)`);
  console.log(`Collections: ${collections.length} (${duplicates.length} duplicated names)`);
  console.log(`Has Favorites: ${hasFavorites ? 'Yes' : 'NO - needs creation'}`);
  console.log(`Integrity Issues: ${integrityIssues}`);

  const isReady = recipes.length > 0 && hasFavorites && duplicates.length === 0 && integrityIssues === 0;
  console.log(`\nREADY FOR EXPORT: ${isReady ? '✓ YES' : '✗ NO - issues need fixing'}`);
}

async function main() {
  const targetEmail = process.argv[2] || 'tester01@heirloomrecipebox.app';
  await analyzeAccount(targetEmail);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
