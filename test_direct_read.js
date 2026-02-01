#!/usr/bin/env node

// Test direct document read vs collectionGroup query
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'heirloom-ios-prod'
});

const db = admin.firestore();

async function testQueries() {
  console.log('Testing Firestore queries...\n');

  // Test 1: Direct document read
  console.log('Test 1: Direct document read');
  try {
    const doc = await db
      .collection('users')
      .doc('test-user-1')
      .collection('profile')
      .doc('data')
      .get();

    if (doc.exists) {
      console.log('✅ Direct read successful');
      console.log('   displayName:', doc.data().displayName);
    } else {
      console.log('❌ Document does not exist');
    }
  } catch (error) {
    console.log('❌ Direct read failed:', error.message);
  }

  console.log('');

  // Test 2: Collection group query
  console.log('Test 2: CollectionGroup query');
  try {
    const snapshot = await db
      .collectionGroup('profile')
      .where('displayName', '>=', 'Matt')
      .where('displayName', '<', 'Mattz')
      .limit(5)
      .get();

    console.log('✅ CollectionGroup query successful');
    console.log('   Results:', snapshot.size);

    snapshot.forEach(doc => {
      console.log('   -', doc.data().displayName, '(path:', doc.ref.path + ')');
    });
  } catch (error) {
    console.log('❌ CollectionGroup query failed:', error.message);
  }

  console.log('');

  // Test 3: List all profile collections
  console.log('Test 3: Checking all users for profile collection');
  try {
    const usersSnapshot = await db.collection('users').listDocuments();
    console.log('Found', usersSnapshot.length, 'user documents');

    for (const userDoc of usersSnapshot.slice(0, 3)) {
      const profileData = await userDoc.collection('profile').doc('data').get();
      if (profileData.exists) {
        console.log('   -', userDoc.id, ':', profileData.data().displayName);
      }
    }
  } catch (error) {
    console.log('❌ List query failed:', error.message);
  }

  process.exit(0);
}

testQueries().catch((error) => {
  console.error('Test failed:', error);
  process.exit(1);
});
