import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(process.env.GOOGLE_APPLICATION_CREDENTIALS || '../service-account-key.json'),
  });
}

const db = admin.firestore();

const DEMO_RECIPES = [
  { userId: 'demo_grandmazing', recipeId: '5e13b837-1a80-4d22-af8a-c474a6ea5c35', name: 'Cookies' },
  { userId: 'demo_fitfoodie', recipeId: 'f3890dc5-f51a-455a-8bf2-eb4bb089c5a9', name: 'Protein Bowl' },
  { userId: 'demo_chef_maria', recipeId: '5d5a16d4-4fc2-483b-9737-7d0451f3c236', name: 'Garlic Shrimp' },
  { userId: 'demo_phillipfry', recipeId: '7ee0a981-0dd2-4105-aa26-ab941c23d688', name: 'One-Pot Pasta' },
  { userId: 'demo_grillmaster', recipeId: '1de8ec4c-7629-466d-b39b-87d97b48ec9f', name: 'Smash Burgers' },
  { userId: 'demo_bakingbelle', recipeId: 'fceb840f-6acb-49f3-a7f0-e1da3de286ff', name: 'Lava Cakes' },
];

async function check() {
  console.log('=== Checking instructions in all demo user recipes ===\n');

  for (const recipe of DEMO_RECIPES) {
    const doc = await db.doc(`users/${recipe.userId}/recipes/${recipe.recipeId}`).get();

    if (doc.exists) {
      const data = doc.data()!;
      const hasInstructions = 'instructions' in data && Array.isArray(data.instructions);
      const count = hasInstructions ? data.instructions.length : 0;

      console.log(`${recipe.userId} (${recipe.name}):`);
      console.log(`  Has instructions: ${hasInstructions}`);
      console.log(`  Count: ${count}`);
      console.log(`  Title: ${data.title}`);
    } else {
      console.log(`${recipe.userId} (${recipe.name}): NOT FOUND`);
    }
    console.log('');
  }

  // Also check the user's copies
  const userId = 'jkxDVuA91wTOSLKWk3GZWqdOigQ2';
  console.log('=== User recipes (copies) ===\n');

  const userRecipes = await db.collection(`users/${userId}/recipes`).get();
  for (const doc of userRecipes.docs) {
    const data = doc.data();
    const hasInstructions = 'instructions' in data && Array.isArray(data.instructions);
    const count = hasInstructions ? data.instructions.length : 0;
    console.log(`${data.title}:`);
    console.log(`  Has instructions: ${hasInstructions}, Count: ${count}`);
  }
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
