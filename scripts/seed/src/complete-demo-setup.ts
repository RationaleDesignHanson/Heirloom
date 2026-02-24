/**
 * Complete demo account setup:
 * 1. Add system collections (All Recipes, Generated Recipes)
 * 2. Set onboarding as complete in Firestore
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { v4 as uuidv4 } from 'uuid';

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

async function completeDemoSetup(email: string): Promise<void> {
  console.log(`\nCompleting setup for: ${email}\n`);

  const user = await auth.getUserByEmail(email);
  console.log('User ID:', user.uid);

  const collectionsRef = db.collection('users').doc(user.uid).collection('collections');

  // 1. Add All Recipes collection
  const allRecipesId = uuidv4().toLowerCase();
  await collectionsRef.doc(allRecipesId).set({
    id: allRecipesId,
    name: 'All Recipes',
    icon: 'square.stack',
    color: '#8B4513',
    isAllRecipes: true,
    isSystemCollection: true,
    isDemoSeed: false,
    recipeIds: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    modifiedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('  ✓ Created All Recipes');

  // 2. Add Generated Recipes collection
  const generatedId = uuidv4().toLowerCase();
  await collectionsRef.doc(generatedId).set({
    id: generatedId,
    name: 'Generated Recipes',
    icon: 'wand.and.stars',
    color: '#9C27B0',
    isAllRecipes: false,
    isSystemCollection: true,
    isDemoSeed: false,
    recipeIds: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    modifiedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('  ✓ Created Generated Recipes');

  // 3. Set onboarding as complete
  await db.collection('users').doc(user.uid).collection('settings').doc('onboarding').set({
    isComplete: true,
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    version: 2,
  }, { merge: true });
  console.log('  ✓ Set onboarding as complete');

  // 4. Verify final state
  const final = await collectionsRef.get();
  console.log(`\nFinal collections (${final.size}):`);
  for (const doc of final.docs) {
    const d = doc.data();
    const recipeCount = (d.recipeIds || []).length;
    console.log(`  - ${d.name} | ${recipeCount} recipes | isAllRecipes: ${d.isAllRecipes || false}`);
  }

  const recipes = await db.collection('users').doc(user.uid).collection('recipes').get();
  console.log(`\nRecipes: ${recipes.size}`);
}

const email = process.argv[2] || 'demo@heirloomrecipebox.app';
completeDemoSetup(email)
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
