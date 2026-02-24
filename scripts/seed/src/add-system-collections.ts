/**
 * Add system collections (All Recipes, Generated Recipes) to Firebase
 * These are normally local-only but we add them to prevent sync from deleting them
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

async function addSystemCollections(email: string): Promise<void> {
  console.log(`\nAdding system collections for: ${email}\n`);

  const user = await auth.getUserByEmail(email);
  const collectionsRef = db.collection('users').doc(user.uid).collection('collections');

  // Check if All Recipes exists
  const existing = await collectionsRef.get();
  const existingNames = existing.docs.map(d => d.data().name);

  if (!existingNames.includes('All Recipes')) {
    const allRecipesId = uuidv4();
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
  } else {
    console.log('  - All Recipes already exists');
  }

  if (!existingNames.includes('Generated Recipes')) {
    const generatedId = uuidv4();
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
  } else {
    console.log('  - Generated Recipes already exists');
  }

  // Final state
  const final = await collectionsRef.get();
  console.log(`\nFinal collections (${final.size}):`);
  for (const doc of final.docs) {
    const d = doc.data();
    console.log(`  - ${d.name} | isAllRecipes: ${d.isAllRecipes || false} | isSystem: ${d.isSystemCollection || false}`);
  }
}

const email = process.argv[2] || 'demo@heirloomrecipebox.app';
addSystemCollections(email)
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
