/**
 * Find user in Firebase Auth and Firestore
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      path.resolve(__dirname, '../../../service-account-key.json')
    ),
  });
}

const db = admin.firestore();
const auth = admin.auth();

async function findUser(email: string) {
  console.log(`Looking for: ${email}\n`);

  // Check Firebase Auth
  try {
    const authUser = await auth.getUserByEmail(email);
    console.log('=== Firebase Auth ===');
    console.log('UID:', authUser.uid);
    console.log('Email:', authUser.email);
    console.log('Display Name:', authUser.displayName || 'not set');
    console.log('Created:', authUser.metadata.creationTime);

    // Check Firestore
    const userDoc = await db.collection('users').doc(authUser.uid).get();
    if (userDoc.exists) {
      const data = userDoc.data()!;
      console.log('\n=== Firestore Profile ===');
      console.log('Display Name:', data.displayName);
      console.log('Email:', data.email);

      // Get recipes and collections
      const recipes = await db.collection(`users/${authUser.uid}/recipes`).get();
      const collections = await db.collection(`users/${authUser.uid}/collections`).get();

      console.log('\n=== Data ===');
      console.log('Recipes:', recipes.size);
      console.log('Collections:', collections.size);

      // Check for From Friends
      const fromFriends = collections.docs.find(c => c.data().name === 'From Friends');
      if (fromFriends) {
        const ffData = fromFriends.data();
        console.log('\nFrom Friends collection:');
        console.log('  ID:', fromFriends.id);
        console.log('  Recipes:', ffData.recipeIds?.length || 0);
      } else {
        console.log('\nNo "From Friends" collection found');
      }

      // List collections
      if (collections.size > 0) {
        console.log('\nAll collections:');
        collections.docs.forEach(c => {
          const cData = c.data();
          console.log(`  - ${cData.name} (${cData.collectionType}): ${cData.recipeIds?.length || 0} recipes`);
        });
      }
    } else {
      console.log('\n⚠️ No Firestore profile document found');

      // Still check for subcollections
      const recipes = await db.collection(`users/${authUser.uid}/recipes`).get();
      const collections = await db.collection(`users/${authUser.uid}/collections`).get();

      console.log('\n=== Subcollections (without profile doc) ===');
      console.log('Recipes:', recipes.size);
      console.log('Collections:', collections.size);

      if (collections.size > 0) {
        console.log('\nCollections:');
        collections.docs.forEach(c => {
          const cData = c.data();
          console.log(`  - ${cData.name} (${cData.collectionType}): ${cData.recipeIds?.length || 0} recipes`);
        });
      }

      if (recipes.size > 0) {
        console.log('\nRecipes:');
        recipes.docs.slice(0, 10).forEach(r => {
          const rData = r.data();
          console.log(`  - ${rData.title} | sharedBy: ${rData.sharedBy || 'n/a'} | collectionIds: ${rData.collectionIds?.length || 0}`);
        });
        if (recipes.size > 10) {
          console.log(`  ... and ${recipes.size - 10} more`);
        }
      }
    }
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log('❌ User not found in Firebase Auth');
    } else {
      console.error('Error:', error.message);
    }
  }
}

const email = process.argv[2] || 'newmatthanson@gmail.com';
findUser(email).catch(console.error);
