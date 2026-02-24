import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, '../../../service-account-key.json')),
  });
}

const db = admin.firestore();
const TEST_USER_ID = 'bXICr37RCXVVvYVczltN85iLFLy2';

async function check() {
  console.log('=== Checking From Friends recipes in Firebase ===\n');
  
  const recipes = await db.collection('users').doc(TEST_USER_ID).collection('recipes').get();
  
  for (const doc of recipes.docs) {
    const d = doc.data();
    if (d.sourceType === 'shared') {
      console.log('ID: ' + doc.id);
      console.log('  Title: ' + d.title);
      console.log('  sharedBy: ' + d.sharedBy);
      console.log('  sharedByName: ' + d.sharedByName);
      console.log('  heritageChain: ' + JSON.stringify(d.heritageChain));
      console.log('  heritageChainNames: ' + JSON.stringify(d.heritageChainNames));
      console.log('  generationCount: ' + d.generationCount);
      console.log('');
    }
  }
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
