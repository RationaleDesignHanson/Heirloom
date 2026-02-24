/**
 * Check test and demo user data in Firebase
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

async function checkUsers() {
  // Check test user
  const testUserRecipes = await db.collection('users/uBaIzSsCTnWXPoYSLHwpkU54G3U2/recipes').get();
  const testUserCollections = await db.collection('users/uBaIzSsCTnWXPoYSLHwpkU54G3U2/collections').get();

  console.log('=== Test User (tester01@heirloomrecipebox.app) ===');
  console.log('Recipes:', testUserRecipes.size);
  console.log('Collections:', testUserCollections.size);

  if (testUserRecipes.size > 0) {
    console.log('\nRecipe IDs (checking case):');
    testUserRecipes.docs.forEach(doc => {
      const data = doc.data();
      const isLowercase = doc.id === doc.id.toLowerCase();
      console.log(`  ${isLowercase ? '✅' : '❌'} ${doc.id} | ${data.title || 'no title'}`);
    });
  }

  if (testUserCollections.size > 0) {
    console.log('\nCollection IDs (checking case):');
    testUserCollections.docs.forEach(doc => {
      const data = doc.data();
      const isLowercase = doc.id === doc.id.toLowerCase();
      const recipeIds = data.recipeIds || [];
      const uppercaseRecipes = recipeIds.filter((id: string) => id !== id.toLowerCase());
      console.log(`  ${isLowercase ? '✅' : '❌'} ${doc.id} | ${data.name || 'no name'}`);
      if (recipeIds.length > 0) {
        console.log(`     └─ recipeIds: ${recipeIds.length} total, ${uppercaseRecipes.length} uppercase`);
      }
    });
  }

  // Check tester02
  const tester02Id = 'jkxDVuA91wTOSLKWk3GZWqdOigQ2';
  const tester02Recipes = await db.collection(`users/${tester02Id}/recipes`).get();
  const tester02Collections = await db.collection(`users/${tester02Id}/collections`).get();

  console.log('\n=== Tester02 (tester02@heirloomrecipebox.app) ===');
  console.log('Recipes:', tester02Recipes.size);
  console.log('Collections:', tester02Collections.size);

  if (tester02Collections.size > 0) {
    console.log('\nCollections:');
    tester02Collections.docs.forEach(doc => {
      const data = doc.data();
      const recipeIds = data.recipeIds || [];
      console.log(`  - ${data.name || 'no name'} | type: ${data.collectionType} | recipes: ${recipeIds.length}`);
    });
  }

  if (tester02Recipes.size > 0) {
    console.log('\nRecipes:');
    tester02Recipes.docs.forEach(doc => {
      const data = doc.data();
      const collectionIds = data.collectionIds || [];
      console.log(`  - ${data.title || 'no title'} | collectionIds: ${collectionIds.length} | sharedBy: ${data.sharedBy || 'n/a'}`);
    });
  }

  // Check demo user
  const demoUsers = await db.collection('users').where('email', '==', 'demo@heirloomrecipebox.app').get();
  if (demoUsers.size > 0) {
    const demoUserId = demoUsers.docs[0].id;
    const demoRecipes = await db.collection(`users/${demoUserId}/recipes`).get();
    const demoCollections = await db.collection(`users/${demoUserId}/collections`).get();

    console.log('\n=== Demo User (demo@heirloomrecipebox.app) ===');
    console.log('User ID:', demoUserId);
    console.log('Recipes:', demoRecipes.size);
    console.log('Collections:', demoCollections.size);

    if (demoRecipes.size > 0) {
      console.log('\nRecipe IDs (checking case):');
      demoRecipes.docs.slice(0, 5).forEach(doc => {
        const data = doc.data();
        const isLowercase = doc.id === doc.id.toLowerCase();
        console.log(`  ${isLowercase ? '✅' : '❌'} ${doc.id} | ${data.title || 'no title'}`);
      });
      if (demoRecipes.size > 5) {
        console.log(`  ... and ${demoRecipes.size - 5} more`);
      }
    }
  } else {
    console.log('\n=== Demo User not found ===');
  }
}

checkUsers().catch(console.error);
