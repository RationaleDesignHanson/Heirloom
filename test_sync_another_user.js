#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'heirloom-ios-prod'
});

const db = admin.firestore();

async function testSync() {
  console.log('🧪 Testing Algolia sync with test_user_2 (Bob)...\n');

  const bobId = 'test_user_2';
  const profileRef = db.collection('users').doc(bobId).collection('profile').doc('data');

  // Update Bob's profile
  const timestamp = new Date().toLocaleTimeString();
  await profileRef.set({
    displayName: `Bob Wilson UPDATED ${timestamp}`,
    photoURL: 'https://i.pravatar.cc/300?img=12',
    bio: 'Professional chef with 15 years of experience',
    location: 'Chicago, IL',
    specialties: ['Italian', 'Pasta'],
    connectionCount: 0,
    isVerified: false,
    updatedAt: admin.firestore.Timestamp.now()
  }, { merge: true });

  console.log(`✅ Updated Bob's profile`);
  console.log(`   Trigger should fire in 5-10 seconds`);
  console.log(`   Check function logs: gcloud logging read "resource.labels.service_name=syncusertoalgolia" --project=heirloom-ios-prod --limit=10`);

  process.exit(0);
}

testSync().catch((error) => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
