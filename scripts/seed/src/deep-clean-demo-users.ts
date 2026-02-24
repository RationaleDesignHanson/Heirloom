import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, '../../../service-account-key.json')),
  });
}

const db = admin.firestore();

async function deepCleanDemoUsers() {
  const demoUsers = ['demo_grandmazing', 'demo_bigshare', 'demo_phillipfry', 'demo_chef_maria', 'demo_grillmaster'];

  console.log('=== Deep cleaning ALL demo user data ===\n');

  for (const userId of demoUsers) {
    console.log('Cleaning ' + userId + '...');

    // Delete all recipes and their subcollections
    const recipes = await db.collection('users/' + userId + '/recipes').get();
    for (const doc of recipes.docs) {
      // Delete ingredients
      const ingredients = await doc.ref.collection('ingredients').get();
      for (const ing of ingredients.docs) {
        await ing.ref.delete();
      }
      // Delete comments
      const comments = await doc.ref.collection('comments').get();
      for (const c of comments.docs) {
        await c.ref.delete();
      }
      // Delete cardBack
      const cardBack = await doc.ref.collection('cardBack').get();
      for (const cb of cardBack.docs) {
        await cb.ref.delete();
      }
      // Delete recipe doc
      await doc.ref.delete();
    }
    console.log('  Deleted ' + recipes.docs.length + ' recipes');

    // Delete lineages
    const lineages = await db.collection('users/' + userId + '/lineages').get();
    for (const doc of lineages.docs) {
      await doc.ref.delete();
    }
    console.log('  Deleted ' + lineages.docs.length + ' lineages');
  }

  // Delete global lineages for demo users
  for (const userId of demoUsers) {
    const globalLineages = await db.collection('lineages').where('ownerId', '==', userId).get();
    for (const doc of globalLineages.docs) {
      await doc.ref.delete();
    }
    console.log('Deleted ' + globalLineages.docs.length + ' global lineages for ' + userId);
  }

  // Also clean up any stale global lineages for bolognese or cookies
  const allGlobalLineages = await db.collection('lineages').get();
  let staleCount = 0;
  for (const doc of allGlobalLineages.docs) {
    const d = doc.data();
    // Delete lineages for the demo recipe roots
    if (d.rootRecipeId === 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' ||
        d.rootRecipeId === '5e13b837-1a80-4d22-af8a-c474a6ea5c35') {
      await doc.ref.delete();
      staleCount++;
    }
  }
  console.log('\nDeleted ' + staleCount + ' stale global lineages');

  // Delete pending shares
  await db.doc('shares/share-grandmazing-cookies-pending').delete().catch(() => {});
  await db.doc('shares/share-bigshare-bolognese-pending').delete().catch(() => {});
  console.log('Deleted pending shares');

  console.log('\n=== Deep clean complete ===');
}

deepCleanDemoUsers().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
