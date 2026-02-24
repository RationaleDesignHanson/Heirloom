import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

async function checkLineages() {
  const cookiesRootId = '5e13b837-1a80-4d22-af8a-c474a6ea5c35';

  console.log('=== Lineages for cookies (rootRecipeId: ' + cookiesRootId + ') ===\n');

  const snapshot = await db.collection('lineages')
    .where('rootRecipeId', '==', cookiesRootId)
    .get();

  console.log('Found ' + snapshot.docs.length + ' lineages:\n');

  for (const doc of snapshot.docs) {
    const data = doc.data();
    console.log('ID: ' + doc.id);
    console.log('  ownerId: ' + data.ownerId);
    console.log('  generation: ' + data.generation);
    console.log('');
  }

  console.log('\n=== ALL global lineages ===\n');
  const allSnapshot = await db.collection('lineages').get();
  console.log('Total: ' + allSnapshot.docs.length + '\n');

  for (const doc of allSnapshot.docs) {
    const data = doc.data();
    console.log(doc.id.substring(0,20) + '... | root: ' + (data.rootRecipeId || '').substring(0,8) + ' | owner: ' + data.ownerId + ' | gen: ' + data.generation);
  }
}

checkLineages().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
