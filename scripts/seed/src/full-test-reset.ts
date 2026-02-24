import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

// Test user IDs
const TEST_USERS = {
  tester01: 'uBaIzSsCTnWXPoYSLHwpkU54G3U2',
  tester02: 'EqVWyDlKMFNHQB5vKSNxo3vC6Wy2',
  tester03: 'mQv9mWkCZyQirFrl1f1RFZCbYC02',  // Real ID from share data
};

// Demo user IDs
const DEMO_USERS = [
  'demo_grandmazing',
  'demo_phillipfry',
  'demo_bigshare',
  'demo_chef_maria',
  'demo_grillmaster',
  'demo_fitfoodie',
  'demo_bakingbelle',
];

async function fullReset() {
  console.log('====================================');
  console.log('  FULL TEST ENVIRONMENT RESET');
  console.log('====================================\n');
  console.log('This will:');
  console.log('  1. Delete all shares TO test users');
  console.log('  2. Delete test user connections to demo users');
  console.log('  3. Delete test user recipes');
  console.log('  4. Delete test user lineages');
  console.log('  5. Delete test user notifications');
  console.log('  6. Delete demo user connections to test users');
  console.log('\nTest users can then friend demo users fresh.\n');

  // 1. Delete shares TO test users
  console.log('=== Deleting Shares ===');
  const shares = await db.collection('shares').get();
  let sharesDeleted = 0;

  for (const doc of shares.docs) {
    const data = doc.data();
    const recipientIds = data.recipientUserIds || [];

    // Delete if any test user is a recipient
    const involvesTestUser = recipientIds.some((id: string) =>
      Object.values(TEST_USERS).includes(id)
    );

    if (involvesTestUser) {
      await doc.ref.delete();
      sharesDeleted++;
      console.log(`  Deleted: ${data.recipeTitle} to ${recipientIds[0]}`);
    }
  }
  console.log(`Deleted ${sharesDeleted} shares`);

  // 2-5. Process each test user
  for (const [name, userId] of Object.entries(TEST_USERS)) {
    console.log(`\n=== Resetting ${name} (${userId}) ===`);

    // Delete connections
    const connections = await db.collection(`users/${userId}/connections`).get();
    for (const doc of connections.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${connections.size} connections`);

    // Delete recipes
    const recipes = await db.collection(`users/${userId}/recipes`).get();
    for (const doc of recipes.docs) {
      // Also delete ingredients subcollection
      const ingredients = await doc.ref.collection('ingredients').get();
      for (const ing of ingredients.docs) {
        await ing.ref.delete();
      }
      await doc.ref.delete();
    }
    console.log(`  Deleted ${recipes.size} recipes`);

    // Delete notifications
    const notifications = await db.collection(`users/${userId}/notifications`).get();
    for (const doc of notifications.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${notifications.size} notifications`);

    // Delete lineages owned by this user
    const lineages = await db.collection('lineages')
      .where('ownerId', '==', userId)
      .get();
    for (const doc of lineages.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${lineages.size} lineages`);
  }

  // 6. Clean up demo user connections to test users
  console.log('\n=== Cleaning Demo User Connections ===');
  for (const demoUserId of DEMO_USERS) {
    const demoConns = await db.collection(`users/${demoUserId}/connections`).get();
    let deleted = 0;

    for (const doc of demoConns.docs) {
      const data = doc.data();
      // Delete if connected to a test user
      if (Object.values(TEST_USERS).includes(data.connectedUserId)) {
        await doc.ref.delete();
        deleted++;
      }
    }

    if (deleted > 0) {
      console.log(`  ${demoUserId}: deleted ${deleted} connections`);
    }
  }

  // Also clear the proactive request sent flag from UserDefaults
  // (This is done client-side, but we can note it)
  console.log('\n=== IMPORTANT ===');
  console.log('On the device, clear UserDefaults key: demo_social_proactive_request_sent');
  console.log('Or reinstall the app for a fresh start.\n');

  console.log('====================================');
  console.log('  RESET COMPLETE');
  console.log('====================================');
  console.log('\nTest users now have a clean slate.');
  console.log('They can friend demo_bigshare to get the Traveling Bolognese.');
}

fullReset().catch(console.error);
