#!/usr/bin/env node

// Fix test users by creating parent documents
// Run with: node fix_user_documents.js

const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'heirloom-ios-prod'
});

const db = admin.firestore();

const testUserIds = [
  'test-user-1',
  'test-user-2',
  'test-user-3',
  'test-user-4',
  'test-user-5',
  'test-user-6'
];

async function createUserDocuments() {
  console.log('Creating parent user documents...\n');

  for (const userId of testUserIds) {
    try {
      // Create minimal parent document (just to make it exist)
      await db
        .collection('users')
        .doc(userId)
        .set({
          _exists: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true }); // merge: true won't overwrite subcollections

      console.log(`✅ Created parent document: users/${userId}`);
    } catch (error) {
      console.error(`❌ Failed to create parent for ${userId}:`, error.message);
    }
  }

  console.log('\n✨ Parent documents created!');
  console.log('Now refresh Firebase Console and try searching again.');
  process.exit(0);
}

createUserDocuments().catch((error) => {
  console.error('Failed:', error);
  process.exit(1);
});
