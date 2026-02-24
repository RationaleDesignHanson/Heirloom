/**
 * Fix recipe collectionIds to match collection document IDs (case-sensitive)
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

async function fixRecipeLinks(email: string): Promise<void> {
  console.log(`\nFixing recipe links for: ${email}\n`);

  const user = await auth.getUserByEmail(email);
  const userRef = db.collection('users').doc(user.uid);

  // Get all collections and build a map of lowercase ID -> actual ID
  const collectionsSnap = await userRef.collection('collections').get();
  const collectionMap = new Map<string, string>();

  for (const doc of collectionsSnap.docs) {
    const lowerId = doc.id.toLowerCase();
    collectionMap.set(lowerId, doc.id);
    console.log(`  Collection: ${doc.data().name} -> ${doc.id}`);
  }

  // Fix each recipe's collectionIds
  const recipesSnap = await userRef.collection('recipes').get();
  let fixed = 0;

  for (const recipeDoc of recipesSnap.docs) {
    const data = recipeDoc.data();
    const oldIds: string[] = data.collectionIds || [];
    const newIds: string[] = [];
    let changed = false;

    for (const oldId of oldIds) {
      const lowerId = oldId.toLowerCase();
      const correctId = collectionMap.get(lowerId);
      if (correctId && correctId !== oldId) {
        newIds.push(correctId);
        changed = true;
      } else {
        newIds.push(oldId);
      }
    }

    if (changed) {
      await recipeDoc.ref.update({ collectionIds: newIds });
      console.log(`  Fixed: ${data.title}`);
      console.log(`    Old: ${oldIds.join(', ')}`);
      console.log(`    New: ${newIds.join(', ')}`);
      fixed++;
    }
  }

  console.log(`\n✅ Fixed ${fixed} recipes`);
}

const email = process.argv[2] || 'demo@heirloomrecipebox.app';
fixRecipeLinks(email)
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
