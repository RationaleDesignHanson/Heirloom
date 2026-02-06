/**
 * Clean up duplicate ingredients from recipes
 *
 * This script identifies recipes with duplicate ingredients (same originalText)
 * and removes the duplicates, keeping only one of each unique ingredient.
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

async function cleanupDuplicateIngredients(userId: string): Promise<void> {
  console.log(`Cleaning up duplicate ingredients for user: ${userId}\n`);

  const recipesRef = db.collection(`users/${userId}/recipes`);
  const recipes = await recipesRef.get();

  console.log(`Found ${recipes.size} recipes to check\n`);

  let totalDuplicatesRemoved = 0;

  for (const recipeDoc of recipes.docs) {
    const recipeData = recipeDoc.data();
    const recipeTitle = recipeData.title || recipeDoc.id;

    // Get all ingredients for this recipe
    const ingredientsRef = db.collection(`users/${userId}/recipes/${recipeDoc.id}/ingredients`);
    const ingredients = await ingredientsRef.get();

    if (ingredients.size === 0) continue;

    // Group ingredients by originalText
    const ingredientsByText: Map<string, admin.firestore.DocumentSnapshot[]> = new Map();

    for (const ingDoc of ingredients.docs) {
      const ingData = ingDoc.data();
      const text = ingData.originalText || ingData.text || '';

      if (!ingredientsByText.has(text)) {
        ingredientsByText.set(text, []);
      }
      ingredientsByText.get(text)!.push(ingDoc);
    }

    // Find duplicates and delete extras
    let duplicatesInRecipe = 0;

    for (const [text, docs] of ingredientsByText) {
      if (docs.length > 1) {
        // Keep the first one, delete the rest
        const toDelete = docs.slice(1);
        for (const doc of toDelete) {
          await doc.ref.delete();
          duplicatesInRecipe++;
        }
      }
    }

    if (duplicatesInRecipe > 0) {
      console.log(`  ${recipeTitle}: removed ${duplicatesInRecipe} duplicate ingredients`);
      totalDuplicatesRemoved += duplicatesInRecipe;
    }
  }

  // Also clean up instructions
  console.log('\nCleaning up duplicate instructions...\n');

  for (const recipeDoc of recipes.docs) {
    const recipeData = recipeDoc.data();
    const recipeTitle = recipeData.title || recipeDoc.id;

    const instructionsRef = db.collection(`users/${userId}/recipes/${recipeDoc.id}/instructions`);
    const instructions = await instructionsRef.get();

    if (instructions.size === 0) continue;

    // Group instructions by text
    const instructionsByText: Map<string, admin.firestore.DocumentSnapshot[]> = new Map();

    for (const instDoc of instructions.docs) {
      const instData = instDoc.data();
      const text = instData.text || '';

      if (!instructionsByText.has(text)) {
        instructionsByText.set(text, []);
      }
      instructionsByText.get(text)!.push(instDoc);
    }

    // Find duplicates and delete extras
    let duplicatesInRecipe = 0;

    for (const [text, docs] of instructionsByText) {
      if (docs.length > 1) {
        const toDelete = docs.slice(1);
        for (const doc of toDelete) {
          await doc.ref.delete();
          duplicatesInRecipe++;
        }
      }
    }

    if (duplicatesInRecipe > 0) {
      console.log(`  ${recipeTitle}: removed ${duplicatesInRecipe} duplicate instructions`);
      totalDuplicatesRemoved += duplicatesInRecipe;
    }
  }

  console.log(`\nDone! Removed ${totalDuplicatesRemoved} total duplicates.`);
}

// Main
const userId = process.argv[2] || 'TuQgh4k7HSY8p5eDk90ja53u9ki2';
cleanupDuplicateIngredients(userId)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
