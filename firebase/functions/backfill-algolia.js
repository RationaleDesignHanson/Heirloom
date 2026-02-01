#!/usr/bin/env node

/**
 * Backfill existing users to Algolia
 * Run once to sync all existing user profiles
 */

const admin = require('firebase-admin');
const algoliasearch = require('algoliasearch');

// Initialize Firebase Admin
const serviceAccount = require('../../service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'heirloom-ios-prod'
});

// Initialize Algolia
const client = algoliasearch(
  'A1DITUD2QN',
  'e07b85696f6d023e0ac63434db054d16'
);
const index = client.initIndex('users');

async function backfillUsers() {
  console.log('🚀 Starting Algolia backfill...\n');

  const db = admin.firestore();
  const usersSnapshot = await db.collection('users').listDocuments();

  const algoliaObjects = [];
  let skipped = 0;

  for (const userDoc of usersSnapshot) {
    const profileDoc = await userDoc.collection('profile').doc('data').get();

    if (!profileDoc.exists) {
      console.log(`  ⚠️  Skipping ${userDoc.id} - no profile`);
      skipped++;
      continue;
    }

    const data = profileDoc.data();

    // Skip users who hide from search
    if (data.privacySettings?.hideFromSearch === true) {
      console.log(`  🔒 Skipping ${userDoc.id} - hidden from search`);
      skipped++;
      continue;
    }

    algoliaObjects.push({
      objectID: userDoc.id,
      displayName: data.displayName || '',
      photoURL: data.photoURL || null,
      bio: data.bio || null,
      location: data.location || null,
      specialties: data.specialties || [],
      connectionCount: data.connectionCount || 0,
      isVerified: data.isVerified || false,
      updatedAt: Math.floor(Date.now() / 1000)
    });

    console.log(`  ✅ ${data.displayName || userDoc.id}`);
  }

  // Batch upload to Algolia
  if (algoliaObjects.length > 0) {
    console.log(`\n📤 Uploading ${algoliaObjects.length} users to Algolia...`);
    await index.saveObjects(algoliaObjects);
    console.log('✅ Upload complete!');
  }

  console.log(`\n📊 Summary:`);
  console.log(`   • Indexed: ${algoliaObjects.length} users`);
  console.log(`   • Skipped: ${skipped} users`);
  console.log(`\n✨ Backfill complete!`);

  process.exit(0);
}

backfillUsers().catch((error) => {
  console.error('❌ Backfill failed:', error);
  process.exit(1);
});
