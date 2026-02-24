import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../scripts/seed/.env') });

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(process.env.GOOGLE_APPLICATION_CREDENTIALS || '/Users/matthanson/Heirloom/service-account-key.json'),
  });
}

const db = admin.firestore();

async function check() {
  // Check what recipes demo_grandmazing actually has
  console.log('=== demo_grandmazing recipes ===');
  const recipes = await db.collection('users/demo_grandmazing/recipes').get();
  for (const doc of recipes.docs) {
    const data = doc.data();
    console.log(doc.id, '-', data.title);
  }

  console.log('');
  console.log('=== Looking for specific ID from lineage ===');
  const specificId = '5e13b837-1a80-4d22-af8a-c474a6ea5c35';
  const lowerId = specificId.toLowerCase();

  const upperDoc = await db.doc('users/demo_grandmazing/recipes/' + specificId).get();
  console.log('Uppercase ID exists:', upperDoc.exists);

  const lowerDoc = await db.doc('users/demo_grandmazing/recipes/' + lowerId).get();
  console.log('Lowercase ID exists:', lowerDoc.exists);

  console.log('');
  console.log('=== Lineage docs referencing demo_grandmazing ===');
  const lineages = await db.collection('lineages')
    .where('rootOwnerId', '==', 'demo_grandmazing')
    .limit(5)
    .get();
  for (const doc of lineages.docs) {
    const data = doc.data();
    console.log('rootRecipeId:', data.rootRecipeId);
    console.log('parentRecipeId:', data.parentRecipeId);
    console.log('currentRecipeId:', data.currentRecipeId);
    console.log('---');
  }
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
