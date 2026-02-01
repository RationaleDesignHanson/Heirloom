#!/usr/bin/env node

/**
 * Test Cloud Function by updating a user profile
 * This should trigger syncUserToAlgolia function
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'heirloom-ios-prod'
});

const db = admin.firestore();

async function testSync() {
  console.log('🧪 Testing Algolia sync...\n');

  // Update test user profile (Alice)
  const aliceId = 'test_user_1';
  const profileRef = db.collection('users').doc(aliceId).collection('profile').doc('data');

  // Update displayName with timestamp
  const timestamp = new Date().toLocaleTimeString();
  await profileRef.set({
    displayName: `Alice Thompson ${timestamp}`,
    updatedAt: admin.firestore.Timestamp.now(),
    photoURL: 'https://i.pravatar.cc/300?img=5',
    bio: 'Home cook specializing in Italian cuisine and baking'
  }, { merge: true });

  console.log(`✅ Updated Alice's profile with new displayName`);
  console.log(`   Check Algolia dashboard in 5-10 seconds to verify sync\n`);
  console.log(`📊 Algolia Dashboard: https://www.algolia.com/apps/A1DITUD2QN/explorer/browse/users`);

  process.exit(0);
}

testSync().catch((error) => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
