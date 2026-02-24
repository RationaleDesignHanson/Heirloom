/**
 * Check the state of test accounts in Firebase
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

async function checkAccount(email: string): Promise<void> {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Checking: ${email}`);
  console.log('='.repeat(60));

  try {
    const user = await auth.getUserByEmail(email);
    console.log(`User ID: ${user.uid}`);

    const collections = await db.collection('users').doc(user.uid).collection('collections').get();
    console.log(`\nCollections (${collections.size}):`);

    const collectionNames: Record<string, number> = {};
    let hasFavorites = false;

    collections.docs.forEach(doc => {
      const d = doc.data();
      const name = d.name || 'Unnamed';
      collectionNames[name] = (collectionNames[name] || 0) + 1;
      if (name === 'Favorites') hasFavorites = true;
    });

    // Show unique collection names with counts
    Object.entries(collectionNames).sort((a, b) => b[1] - a[1]).forEach(([name, count]) => {
      if (count > 1) {
        console.log(`  - ${name} (${count} DUPLICATES!)`);
      } else {
        console.log(`  - ${name}`);
      }
    });

    console.log(`\nHas Favorites: ${hasFavorites ? 'YES' : 'NO - MISSING!'}`);

    const recipes = await db.collection('users').doc(user.uid).collection('recipes').get();
    console.log(`Total recipes: ${recipes.size}`);

  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log('User not found');
    } else {
      throw error;
    }
  }
}

async function main() {
  await checkAccount('demo@heirloomrecipebox.app');
  await checkAccount('deletetest@heirloomrecipebox.app');
  await checkAccount('tester01@heirloomrecipebox.app');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
