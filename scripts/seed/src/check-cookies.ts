import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, '../../../service-account-key.json')),
  });
}

const db = admin.firestore();
const TEST_USER_ID = 'nVkKpcbBtdNxXqRErSYQdeIUiHh1';

async function check() {
  console.log('=== ALL chocolate chip cookie recipes for test user ===\n');
  
  const recipes = await db.collection('users').doc(TEST_USER_ID).collection('recipes').get();
  
  for (const doc of recipes.docs) {
    const data = doc.data();
    if (data.title?.toLowerCase().includes('chocolate chip') || data.title?.toLowerCase().includes('cookie')) {
      console.log('ID: ' + doc.id);
      console.log('  Title: ' + data.title);
      console.log('  sourceType: ' + data.sourceType);
      console.log('  heritageChain: ' + JSON.stringify(data.heritageChain));
      console.log('  rootRecipeId: ' + data.rootRecipeId);
      console.log('');
    }
  }
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
