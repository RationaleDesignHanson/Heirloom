import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, '../../../service-account-key.json')),
  });
}

const db = admin.firestore();

async function cleanupDuplicates() {
  const rootRecipeId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

  // Find all lineages for this root
  const lineages = await db.collection('lineages').where('rootRecipeId', '==', rootRecipeId).get();

  console.log('All Bolognese lineages:');
  const toDelete: admin.firestore.DocumentReference[] = [];

  for (const doc of lineages.docs) {
    const d = doc.data();
    console.log(doc.id + ': Gen ' + d.generation + ' | ownerId: ' + d.ownerId);

    // Keep only the bigshare-lineage-* ones and user-created ones (not demo)
    if (!doc.id.startsWith('bigshare-lineage-') && d.ownerId.startsWith('demo_')) {
      toDelete.push(doc.ref);
    }
  }

  console.log('\nDeleting ' + toDelete.length + ' stale lineages...');
  for (const ref of toDelete) {
    console.log('  Deleting: ' + ref.path);
    await ref.delete();
  }

  console.log('\nDone!');
}

cleanupDuplicates().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
