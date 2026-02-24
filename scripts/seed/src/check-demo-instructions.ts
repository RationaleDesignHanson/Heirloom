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

// NOTE: Use lowercase UUIDs to match Swift's UUID.firebaseString convention
const DEMO_RECIPES = [
  { userId: 'demo_phillipfry', recipeId: '7ee0a981-0dd2-4105-aa26-ab941c23d688', title: 'Creamy One-Pot Pasta' },
  { userId: 'demo_grandmazing', recipeId: '5e13b837-1a80-4d22-af8a-c474a6ea5c35', title: 'Brown Butter Cookies' },
  { userId: 'demo_grillmaster', recipeId: '1de8ec4c-7629-466d-b39b-87d97b48ec9f', title: 'Ultimate Smash Burgers' },
];

async function check() {
  console.log('Checking demo user recipe instructions...\n');

  for (const recipe of DEMO_RECIPES) {
    const instructions = await db.collection(`users/${recipe.userId}/recipes/${recipe.recipeId}/instructions`).get();
    const ingredients = await db.collection(`users/${recipe.userId}/recipes/${recipe.recipeId}/ingredients`).get();

    console.log(`${recipe.title} (${recipe.userId}):`);
    console.log(`  Ingredients: ${ingredients.size}`);
    console.log(`  Instructions: ${instructions.size}`);

    if (instructions.size > 0) {
      console.log('  All instructions:');
      for (const doc of instructions.docs) {
        const data = doc.data();
        console.log(`    [order=${data.order}, orderIndex=${data.orderIndex}] ${data.text?.substring(0, 50)}`);
      }
    }
    console.log('');
  }
}

check().then(() => process.exit(0));
