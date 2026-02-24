import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function fullReset() {
  const tester01 = 'uBaIzSsCTnWXPoYSLHwpkU54G3U2';

  console.log('=== Full tester01 Reset ===\n');

  // 1. Delete all recipes
  const recipes = await db.collection(`users/${tester01}/recipes`).get();
  for (const doc of recipes.docs) {
    // Delete ingredients subcollection first
    const ingredients = await doc.ref.collection('ingredients').get();
    for (const ing of ingredients.docs) {
      await ing.ref.delete();
    }
    await doc.ref.delete();
  }
  console.log(`Deleted ${recipes.size} recipes`);

  // 2. Delete all connections
  const connections = await db.collection(`users/${tester01}/connections`).get();
  for (const doc of connections.docs) {
    await doc.ref.delete();
  }
  console.log(`Deleted ${connections.size} connections`);

  // 3. Delete all notifications
  const notifications = await db.collection(`users/${tester01}/notifications`).get();
  for (const doc of notifications.docs) {
    await doc.ref.delete();
  }
  console.log(`Deleted ${notifications.size} notifications`);

  // 4. Delete all collections (except keep profile)
  const collections = await db.collection(`users/${tester01}/collections`).get();
  for (const doc of collections.docs) {
    await doc.ref.delete();
  }
  console.log(`Deleted ${collections.size} collections`);

  // 5. Reset onboarding flag in profile
  await db.doc(`users/${tester01}/profile/data`).update({
    hasCompletedOnboarding: false,
    selectedThemeIds: [],  // Clear theme selections too
  });
  console.log('Reset onboarding flag and theme selections');

  // 6. Delete any shares TO tester01
  const shares = await db.collection('shares').where('recipientUserIds', 'array-contains', tester01).get();
  for (const doc of shares.docs) {
    await doc.ref.delete();
  }
  console.log(`Deleted ${shares.size} shares`);

  // 7. Delete tester01's lineages
  const lineages = await db.collection('lineages').where('ownerId', '==', tester01).get();
  for (const doc of lineages.docs) {
    await doc.ref.delete();
  }
  console.log(`Deleted ${lineages.size} lineages`);

  console.log('\n=== Reset Complete ===');
  console.log('Delete app, reinstall, and login as tester01');
  console.log('Should go through onboarding and get a demo friend request');
}

fullReset().catch(console.error);
