import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, '../../../service-account-key.json')),
  });
}

const db = admin.firestore();
const TEST_USER_ID = 'nVkKpcbBtdNxXqRErSYQdeIUiHh1';

async function cleanup() {
  console.log('Cleaning up ALL data for test user: ' + TEST_USER_ID);
  
  // Delete ALL collections
  const collections = await db.collection('users').doc(TEST_USER_ID).collection('collections').get();
  console.log('Deleting ' + collections.docs.length + ' collections...');
  for (const doc of collections.docs) {
    await doc.ref.delete();
  }

  // Delete ALL recipes and their ingredients
  const recipes = await db.collection('users').doc(TEST_USER_ID).collection('recipes').get();
  console.log('Deleting ' + recipes.docs.length + ' recipes...');
  for (const doc of recipes.docs) {
    const ingredients = await doc.ref.collection('ingredients').get();
    for (const ing of ingredients.docs) {
      await ing.ref.delete();
    }
    await doc.ref.delete();
  }

  // Delete ALL lineages
  const lineages = await db.collection('users').doc(TEST_USER_ID).collection('lineages').get();
  console.log('Deleting ' + lineages.docs.length + ' user lineages...');
  for (const doc of lineages.docs) {
    await doc.ref.delete();
  }

  // Delete from global lineages
  const globalLineages = await db.collection('lineages').where('ownerId', '==', TEST_USER_ID).get();
  console.log('Deleting ' + globalLineages.docs.length + ' global lineages...');
  for (const doc of globalLineages.docs) {
    await doc.ref.delete();
  }

  console.log('Done!');
}

cleanup().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
