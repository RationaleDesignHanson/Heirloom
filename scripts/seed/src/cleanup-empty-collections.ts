/**
 * Clean up empty/orphan collections for demo account
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

async function cleanupEmptyCollections(email: string): Promise<void> {
  console.log(`\nCleaning up empty collections for: ${email}\n`);

  const user = await auth.getUserByEmail(email);
  const collectionsRef = db.collection('users').doc(user.uid).collection('collections');
  const snapshot = await collectionsRef.get();

  // Collections to delete (empty theme collections)
  const toDelete = [
    'German-American Kitchen',
    'Boston Cooking School',
    'Scandinavian Heritage',
    'Generated Recipes'
  ];

  let deleted = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (toDelete.includes(data.name)) {
      await doc.ref.delete();
      console.log('  Deleted:', data.name);
      deleted++;
    }
  }

  console.log(`\n  Deleted ${deleted} empty collections`);

  // Verify final state
  const final = await collectionsRef.get();
  console.log(`\nFinal collections (${final.size}):`);
  final.docs.forEach(doc => {
    const d = doc.data();
    console.log(`  - ${d.name} | ${(d.recipeIds || []).length} recipes`);
  });
}

const email = process.argv[2] || 'demo@heirloomrecipebox.app';
cleanupEmptyCollections(email)
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
