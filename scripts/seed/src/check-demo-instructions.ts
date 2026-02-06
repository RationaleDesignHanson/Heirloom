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

const DEMO_RECIPES = [
  { userId: 'demo_phillipfry', recipeId: '7EE0A981-0DD2-4105-AA26-AB941C23D688', title: 'Creamy One-Pot Pasta' },
  { userId: 'demo_grandmazing', recipeId: '5E13B837-1A80-4D22-AF8A-C474A6EA5C35', title: 'Brown Butter Cookies' },
  { userId: 'demo_grillmaster', recipeId: '1DE8EC4C-7629-466D-B39B-87D97B48EC9F', title: 'Ultimate Smash Burgers' },
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
