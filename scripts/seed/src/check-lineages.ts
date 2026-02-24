import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function checkLineages() {
  const lineages = await db.collection('globalLineages').get();
  console.log('Global lineages found:', lineages.size);
  
  for (const doc of lineages.docs) {
    const data = doc.data();
    console.log('---');
    console.log('Recipe:', data.recipeTitle || data.title || 'unknown');
    console.log('Generation:', data.generation || 0);
    if (data.heritageChainNames) {
      console.log('Chain:', data.heritageChainNames.join(' → '));
    }
  }
}

checkLineages();
