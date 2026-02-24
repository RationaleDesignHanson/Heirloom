/**
 * Find users by name/email pattern
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

async function findUsers() {
  const searchTerms = process.argv.slice(2);
  const users = await db.collection('users').get();

  console.log(`Searching ${users.size} users for: ${searchTerms.join(', ') || 'all'}\n`);

  for (const doc of users.docs) {
    const data = doc.data();
    const email = (data.email || '').toLowerCase();
    const name = (data.displayName || '').toLowerCase();

    // If search terms provided, filter
    if (searchTerms.length > 0) {
      const matches = searchTerms.some(term =>
        name.includes(term.toLowerCase()) || email.includes(term.toLowerCase())
      );
      if (!matches) continue;
    }

    const recipes = await db.collection(`users/${doc.id}/recipes`).get();
    const collections = await db.collection(`users/${doc.id}/collections`).get();

    console.log('---');
    console.log('UID:', doc.id);
    console.log('Name:', data.displayName || 'no name');
    console.log('Email:', data.email || 'no email');
    console.log('Recipes:', recipes.size);
    console.log('Collections:', collections.size);

    // Check for From Friends collection
    const fromFriends = collections.docs.find((c: admin.firestore.QueryDocumentSnapshot) =>
      c.data().name === 'From Friends'
    );
    if (fromFriends) {
      const ffData = fromFriends.data();
      console.log('From Friends:', ffData.recipeIds?.length || 0, 'recipes');
    }

    // Show collections with recipes
    if (collections.size > 0) {
      console.log('Collections:');
      collections.docs.forEach((c: admin.firestore.QueryDocumentSnapshot) => {
        const cData = c.data();
        const count = cData.recipeIds?.length || 0;
        if (count > 0 || cData.name === 'From Friends') {
          console.log(`  - ${cData.name}: ${count} recipes`);
        }
      });
    }
  }
}

findUsers().catch(console.error);
