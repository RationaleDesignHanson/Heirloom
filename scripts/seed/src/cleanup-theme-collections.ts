import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, '../../../service-account-key.json')),
  });
}

const db = admin.firestore();
const userId = 'ngVz2G0d4ZQ545hzJMV7dk7TIlK2';

async function cleanup() {
  console.log('Cleaning up stale theme collections...');

  const collections = await db.collection('users/' + userId + '/collections').get();

  for (const doc of collections.docs) {
    const d = doc.data();
    if (d.collectionType === 'theme') {
      console.log('  Deleting theme collection: ' + d.name);
      await doc.ref.delete();
    }
    // Also delete Generated Recipes if empty
    if (d.name === 'Generated Recipes' && (!d.recipeIds || d.recipeIds.length === 0)) {
      console.log('  Deleting empty Generated Recipes collection');
      await doc.ref.delete();
    }
  }

  console.log('Done!');
}

cleanup().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
