/**
 * Inspect demo account state in Firebase
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

async function inspect(): Promise<void> {
  const email = process.argv[2] || 'demo@heirloomrecipebox.app';
  console.log(`\nInspecting: ${email}\n`);

  const user = await auth.getUserByEmail(email);
  console.log('User ID:', user.uid);

  // Collections
  const cols = await db.collection('users').doc(user.uid).collection('collections').get();
  console.log(`\nCollections (${cols.size}):`);
  for (const doc of cols.docs) {
    const d = doc.data();
    console.log(`  - ${d.name}`);
    console.log(`    id: ${doc.id}`);
    console.log(`    recipeIds: ${(d.recipeIds || []).length}`);
    console.log(`    isAllRecipes: ${d.isAllRecipes || false}`);
    console.log(`    isSystemCollection: ${d.isSystemCollection || false}`);
  }

  // Recipes
  const recipes = await db.collection('users').doc(user.uid).collection('recipes').get();
  console.log(`\nRecipes (${recipes.size}):`);
  for (const doc of recipes.docs) {
    const d = doc.data();
    console.log(`  - ${d.title} | collectionIds: ${JSON.stringify(d.collectionIds || [])}`);
  }
}

inspect()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
