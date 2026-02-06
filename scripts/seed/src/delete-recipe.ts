/**
 * Delete a specific recipe and re-seed it
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { v5 as uuidv5 } from 'uuid';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

const RECIPE_NAMESPACE = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

function generateDeterministicId(title: string, collectionName: string): string {
  const input = `${collectionName}:${title}`.toLowerCase();
  return uuidv5(input, RECIPE_NAMESPACE);
}

async function deleteRecipe(userId: string, recipeId: string): Promise<void> {
  console.log(`Deleting recipe ${recipeId} for user ${userId}...`);

  // Delete subcollections first
  const ingredientsRef = db.collection(`users/${userId}/recipes/${recipeId}/ingredients`);
  const ingredients = await ingredientsRef.get();
  console.log(`  Deleting ${ingredients.size} ingredients...`);
  for (const doc of ingredients.docs) {
    await doc.ref.delete();
  }

  const instructionsRef = db.collection(`users/${userId}/recipes/${recipeId}/instructions`);
  const instructions = await instructionsRef.get();
  console.log(`  Deleting ${instructions.size} instructions...`);
  for (const doc of instructions.docs) {
    await doc.ref.delete();
  }

  // Delete the recipe document
  await db.doc(`users/${userId}/recipes/${recipeId}`).delete();
  console.log(`  Recipe deleted!`);
}

async function main() {
  const userId = process.argv[2] || 'TuQgh4k7HSY8p5eDk90ja53u9ki2';
  const recipeTitle = process.argv[3] || 'Beef and Broccoli';
  const collectionName = process.argv[4] || 'Weeknight Dinners';

  const recipeId = generateDeterministicId(recipeTitle, collectionName);
  console.log(`Recipe: "${recipeTitle}" in "${collectionName}"`);
  console.log(`Generated ID: ${recipeId}`);

  await deleteRecipe(userId, recipeId);

  console.log('\nDone! Now run the seed script to recreate it:');
  console.log('  npm run seed:screenshot-demo');
}

main().then(() => process.exit(0)).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
