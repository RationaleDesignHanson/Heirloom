/**
 * Deduplicate recipeIds in collections (case-insensitive)
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

async function dedupRecipeIds(email: string): Promise<void> {
  console.log(`\nDeduplicating recipeIds for: ${email}\n`);

  const user = await auth.getUserByEmail(email);
  const collectionsRef = db.collection('users').doc(user.uid).collection('collections');
  const snapshot = await collectionsRef.get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const recipeIds: string[] = data.recipeIds || [];

    // Deduplicate case-insensitively (keep first occurrence)
    const seen = new Set<string>();
    const uniqueIds: string[] = [];

    for (const id of recipeIds) {
      const lower = id.toLowerCase();
      if (!seen.has(lower)) {
        seen.add(lower);
        uniqueIds.push(id);
      }
    }

    if (uniqueIds.length !== recipeIds.length) {
      await doc.ref.update({ recipeIds: uniqueIds });
      console.log(`  ${data.name}: ${recipeIds.length} -> ${uniqueIds.length} recipes`);
    }
  }

  console.log('\n✅ Done');
}

const email = process.argv[2] || 'demo@heirloomrecipebox.app';
dedupRecipeIds(email)
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
