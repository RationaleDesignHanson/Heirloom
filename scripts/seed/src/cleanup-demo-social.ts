/**
 * Clean up demo social data - shares and connections between real and demo users
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

const DEMO_USER_IDS = [
  'demo_grandmazing',
  'demo_phillipfry',
  'demo_chef_maria',
  'demo_fitfoodie',
  'demo_bakingbelle',
  'demo_grillmaster'
];

const REAL_USER_ID = 'TuQgh4k7HSY8p5eDk90ja53u9ki2';

async function cleanup() {
  console.log('=== CLEANING UP DEMO SOCIAL DATA ===\n');

  // 1. Delete all demo shares
  console.log('1. Deleting demo shares...');
  const demoShares = await db.collection('shares').where('isDemoShare', '==', true).get();
  console.log(`   Found ${demoShares.size} demo shares`);
  for (const doc of demoShares.docs) {
    await doc.ref.delete();
    console.log(`   Deleted share: ${doc.data().recipeTitle}`);
  }

  // 2. Delete shares where sender is a demo user
  console.log('\n2. Deleting shares from demo users...');
  for (const demoId of DEMO_USER_IDS) {
    const shares = await db.collection('shares').where('ownerId', '==', demoId).get();
    for (const doc of shares.docs) {
      await doc.ref.delete();
      console.log(`   Deleted share from ${demoId}: ${doc.data().recipeTitle}`);
    }
  }

  // 3. Delete shares TO demo users
  console.log('\n3. Deleting shares to demo users...');
  for (const demoId of DEMO_USER_IDS) {
    const shares = await db.collection('shares')
      .where('recipientUserIds', 'array-contains', demoId)
      .get();
    for (const doc of shares.docs) {
      await doc.ref.delete();
      console.log(`   Deleted share to ${demoId}: ${doc.data().recipeTitle}`);
    }
  }

  // 4. Delete connections involving demo users (check real user's connections)
  console.log('\n4. Deleting connections with demo users...');

  // Check real user's connections subcollection
  const userConnections = await db.collection(`users/${REAL_USER_ID}/connections`).get();
  console.log(`   Found ${userConnections.size} connections for real user`);
  for (const doc of userConnections.docs) {
    const data = doc.data();
    const connectedUserId = data.connectedUserId || data.userId || doc.id;
    if (DEMO_USER_IDS.includes(connectedUserId)) {
      await doc.ref.delete();
      console.log(`   Deleted connection to: ${connectedUserId}`);
    }
  }

  // Also check global connections collection
  const globalConnections = await db.collection('connections')
    .where('userIds', 'array-contains', REAL_USER_ID)
    .get();
  console.log(`   Found ${globalConnections.size} global connections`);
  for (const doc of globalConnections.docs) {
    const data = doc.data();
    const userIds: string[] = data.userIds || [];
    const hasDemoUser = userIds.some((id: string) => DEMO_USER_IDS.includes(id));
    if (hasDemoUser) {
      await doc.ref.delete();
      console.log(`   Deleted global connection: ${doc.id}`);
    }
  }

  // 5. Delete demo users' connections to real users
  console.log('\n5. Cleaning demo users connections subcollections...');
  for (const demoId of DEMO_USER_IDS) {
    const demoConnections = await db.collection(`users/${demoId}/connections`).get();
    for (const doc of demoConnections.docs) {
      await doc.ref.delete();
      console.log(`   Deleted ${demoId} connection: ${doc.id}`);
    }
  }

  // 6. Delete any pending connection requests
  console.log('\n6. Cleaning connection requests...');
  for (const demoId of DEMO_USER_IDS) {
    // From demo users
    const fromRequests = await db.collection('connectionRequests')
      .where('fromUserId', '==', demoId)
      .get();
    for (const doc of fromRequests.docs) {
      await doc.ref.delete();
      console.log(`   Deleted request from: ${demoId}`);
    }

    // To demo users
    const toRequests = await db.collection('connectionRequests')
      .where('toUserId', '==', demoId)
      .get();
    for (const doc of toRequests.docs) {
      await doc.ref.delete();
      console.log(`   Deleted request to: ${demoId}`);
    }
  }

  // 7. Clean up lineages involving demo users
  console.log('\n7. Cleaning lineages involving demo users...');
  for (const demoId of DEMO_USER_IDS) {
    const lineages = await db.collection('lineages')
      .where('ownerId', '==', demoId)
      .get();
    for (const doc of lineages.docs) {
      await doc.ref.delete();
      console.log(`   Deleted lineage owned by: ${demoId}`);
    }
  }

  console.log('\n=== CLEANUP COMPLETE ===');
}

cleanup()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
