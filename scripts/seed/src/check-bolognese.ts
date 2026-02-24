import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function check() {
  // Check bigshare's recipes
  const recipes = await db.collection('users/demo_bigshare/recipes').get();
  console.log('demo_bigshare recipes:');
  recipes.forEach(doc => {
    const d = doc.data();
    console.log(`  - ${d.title} (${doc.id})`);
  });
  
  // Check for bigshare lineages
  const lineages = await db.collection('lineages')
    .where('ownerId', '==', 'demo_bigshare')
    .get();
  console.log('\nLineages owned by demo_bigshare:', lineages.size);
  lineages.forEach(doc => {
    const d = doc.data();
    console.log(`  - ${d.recipeTitle} (gen ${d.generation})`);
    if (d.heritageChainNames) {
      console.log(`    Chain: ${d.heritageChainNames.join(' → ')}`);
    }
  });
}

check();
