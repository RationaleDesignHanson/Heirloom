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
  // Check lineages for demo_bigshare
  console.log('=== Lineages for demo_bigshare (with full data) ===');
  const lineages = await db.collection('lineages')
    .where('ownerId', '==', 'demo_bigshare')
    .get();

  lineages.forEach(doc => {
    console.log('\nLineage ID:', doc.id);
    console.log(JSON.stringify(doc.data(), null, 2));
  });

  // Also check globalLineages
  console.log('\n=== Global Lineages for demo_bigshare ===');
  const globalLineages = await db.collection('globalLineages')
    .where('currentOwnerId', '==', 'demo_bigshare')
    .get();

  console.log('Count:', globalLineages.size);
  globalLineages.forEach(doc => {
    console.log('\nGlobal Lineage ID:', doc.id);
    console.log(JSON.stringify(doc.data(), null, 2));
  });

  // Check the recipe data directly
  console.log('\n=== demo_bigshare recipes with full data ===');
  const recipes = await db.collection('users/demo_bigshare/recipes').get();
  recipes.forEach(doc => {
    const data = doc.data();
    console.log('\nRecipe:', doc.id);
    console.log('  title:', data.title);
    console.log('  sourceType:', data.sourceType);
    console.log('  generation:', data.generation);
    console.log('  heritageChainNames:', data.heritageChainNames);
    console.log('  inheritedFromUserId:', data.inheritedFromUserId);
  });
}

check();
