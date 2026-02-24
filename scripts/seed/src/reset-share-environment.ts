import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

// Test user IDs (these get cleared)
const TEST_USERS = {
  tester01: 'uBaIzSsCTnWXPoYSLHwpkU54G3U2',
  tester02: 'EqVWyDlKMFNHQB5vKSNxo3vC6Wy2',
  tester03: 'tester03', // May not exist as real user
};

// Demo user IDs (these keep their base data)
const DEMO_USERS = [
  'demo_grandmazing',
  'demo_phillipfry',
  'demo_bigshare',
  'demo_chef_maria',
  'demo_grillmaster',
];

async function deleteCollection(collectionRef: admin.firestore.CollectionReference) {
  const snapshot = await collectionRef.get();
  if (snapshot.empty) return 0;

  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  return snapshot.size;
}

async function resetTestUserShares() {
  console.log('\n=== Clearing Test User Share Data ===\n');

  for (const [name, userId] of Object.entries(TEST_USERS)) {
    console.log(`\n--- ${name} (${userId}) ---`);

    // 1. Clear shares subcollection
    const sharesRef = db.collection(`users/${userId}/shares`);
    const sharesDeleted = await deleteCollection(sharesRef);
    console.log(`  Deleted ${sharesDeleted} shares`);

    // 2. Reset connection share counts (but keep connections)
    const connectionsRef = db.collection(`users/${userId}/connections`);
    const connections = await connectionsRef.get();
    let connectionsReset = 0;

    for (const doc of connections.docs) {
      await doc.ref.update({
        recipesReceivedCount: 0,
        recipesSharedCount: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      connectionsReset++;
    }
    console.log(`  Reset ${connectionsReset} connection share counts`);

    // 3. Delete any recipes that were received via share (sourceType: 'shared')
    const recipesRef = db.collection(`users/${userId}/recipes`);
    const recipes = await recipesRef.get();
    let sharedRecipesDeleted = 0;

    for (const doc of recipes.docs) {
      const data = doc.data();
      // Delete recipes that came from shares
      if (data.sourceType === 'shared' || data.sharedFromUserId) {
        await doc.ref.delete();
        sharedRecipesDeleted++;
        console.log(`    Deleted shared recipe: ${data.title}`);
      }
    }
    console.log(`  Deleted ${sharedRecipesDeleted} shared recipes`);

    // 4. Delete test user's lineages (they'll recreate from fresh shares)
    const lineagesRef = db.collection(`users/${userId}/lineages`);
    const lineagesDeleted = await deleteCollection(lineagesRef);
    console.log(`  Deleted ${lineagesDeleted} lineages`);
  }
}

async function resetDemoUserShareCounts() {
  console.log('\n=== Resetting Demo User Connection Share Counts ===\n');

  for (const userId of DEMO_USERS) {
    console.log(`\n--- ${userId} ---`);

    // Reset share counts in connections to demo users
    const connectionsRef = db.collection(`users/${userId}/connections`);
    const connections = await connectionsRef.get();
    let connectionsReset = 0;

    for (const doc of connections.docs) {
      // Only reset counts for connections TO test users
      const data = doc.data();
      const isTestUserConnection = Object.values(TEST_USERS).includes(data.connectedUserId);

      if (isTestUserConnection) {
        await doc.ref.update({
          recipesReceivedCount: 0,
          recipesSharedCount: 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        connectionsReset++;
        console.log(`  Reset connection to ${data.connectedUserDisplayName || data.connectedUserId}`);
      }
    }
    console.log(`  Reset ${connectionsReset} connection share counts`);

    // Clear the shares subcollection for demo users too
    // (they don't actually send via this - it's behavior-driven)
    const sharesRef = db.collection(`users/${userId}/shares`);
    const sharesDeleted = await deleteCollection(sharesRef);
    if (sharesDeleted > 0) {
      console.log(`  Deleted ${sharesDeleted} share records`);
    }
  }
}

async function fixBigshareConnection() {
  console.log('\n=== Fixing demo_bigshare Connection to tester01 ===\n');

  const tester01Id = TEST_USERS.tester01;
  const connId = '7989acd4-d018-457a-95ff-6ebd7271da95';

  // Check if tester01 has the connection
  const tester01Conn = await db.doc(`users/${tester01Id}/connections/${connId}`).get();

  if (!tester01Conn.exists) {
    console.log('tester01 connection not found - will be created fresh on friend request');
    return;
  }

  const t1Data = tester01Conn.data()!;

  // Create/update reciprocal connection for demo_bigshare
  const bigshareConnData = {
    id: connId,
    userId: 'demo_bigshare',
    connectedUserId: tester01Id,
    connectedUserDisplayName: t1Data.displayName || 'Tester1Guy',
    connectedUserPhotoURL: t1Data.photoURL || '',
    status: 'connected',
    initiatedBy: tester01Id,
    isFavorite: false,
    isKitchenTableConnection: false,
    recipesReceivedCount: 0,
    recipesSharedCount: 0,
    createdAt: t1Data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
    requestedAt: t1Data.requestedAt || admin.firestore.FieldValue.serverTimestamp(),
    acceptedAt: t1Data.acceptedAt || admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.doc(`users/demo_bigshare/connections/${connId}`).set(bigshareConnData, { merge: true });
  console.log('Created/updated reciprocal connection for demo_bigshare → tester01');
}

async function clearGlobalSharesCollection() {
  console.log('\n=== Clearing Global Shares Collection ===\n');

  // Check for shares involving test users in the global shares collection
  const sharesRef = db.collection('shares');
  const snapshot = await sharesRef.get();

  let deleted = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const involvesTestUser =
      Object.values(TEST_USERS).includes(data.senderId) ||
      Object.values(TEST_USERS).includes(data.recipientId);

    if (involvesTestUser) {
      await doc.ref.delete();
      deleted++;
      console.log(`  Deleted share: ${data.recipeTitle} (${data.senderId} → ${data.recipientId})`);
    }
  }

  console.log(`Deleted ${deleted} global share records involving test users`);
}

async function verifyDemoRecipes() {
  console.log('\n=== Verifying Demo User Base Recipes ===\n');

  for (const userId of DEMO_USERS) {
    const recipesRef = db.collection(`users/${userId}/recipes`);
    const recipes = await recipesRef.get();
    console.log(`${userId}: ${recipes.size} recipes`);

    recipes.docs.forEach(doc => {
      const data = doc.data();
      console.log(`  - ${data.title}`);
    });
  }
}

async function main() {
  console.log('====================================');
  console.log('  RESET SHARE ENVIRONMENT SCRIPT');
  console.log('====================================');
  console.log('\nThis will:');
  console.log('  1. Clear test user shares and shared recipes');
  console.log('  2. Reset connection share counts');
  console.log('  3. Delete test user lineages');
  console.log('  4. Fix demo_bigshare connection');
  console.log('  5. Clear global shares involving test users');
  console.log('\nDemo users keep their base recipes and behaviors.\n');

  await resetTestUserShares();
  await resetDemoUserShareCounts();
  await fixBigshareConnection();
  await clearGlobalSharesCollection();
  await verifyDemoRecipes();

  console.log('\n====================================');
  console.log('  RESET COMPLETE');
  console.log('====================================');
  console.log('\nTest users are now ready for fresh lineage testing.');
  console.log('When tester01 friends demo_bigshare, the demo behavior');
  console.log('should trigger and share the Bolognese recipe.');
}

main().catch(console.error);
