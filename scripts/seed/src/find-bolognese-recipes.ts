import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function findBolognese() {
  const users = ['demo_grandmazing', 'demo_phillipfry', 'demo_chef_maria', 'demo_grillmaster', 'demo_bigshare'];

  console.log('=== Finding All Bolognese Recipes ===\n');

  for (const userId of users) {
    const recipes = await db.collection(`users/${userId}/recipes`).get();

    for (const doc of recipes.docs) {
      const title = doc.data().title?.toLowerCase() || '';
      if (title.includes('bolognese')) {
        console.log(`${userId}:`);
        console.log(`  ID: ${doc.id}`);
        console.log(`  Title: ${doc.data().title}`);
        console.log('');
      }
    }
  }
}

findBolognese();
