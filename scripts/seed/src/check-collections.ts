import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert('/Users/matthanson/Heirloom/service-account-key.json'),
  });
}

const db = admin.firestore();
const userId = 'TuQgh4k7HSY8p5eDk90ja53u9ki2';

async function checkCollections() {
  const collections = await db.collection(`users/${userId}/collections`).get();
  
  console.log('Found ' + collections.size + ' collections:');
  
  for (const doc of collections.docs) {
    const data = doc.data();
    console.log('- ' + data.name + ' (' + (data.recipeIds?.length || 0) + ' recipes)');
  }
}

checkCollections().then(() => process.exit(0));
