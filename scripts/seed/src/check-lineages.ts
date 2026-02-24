import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(process.env.GOOGLE_APPLICATION_CREDENTIALS || '../service-account-key.json'),
  });
}

const db = admin.firestore();

async function check() {
  console.log('=== Checking lineage documents ===\n');

  // Check all lineages
  const allSnapshot = await db.collection('lineages').limit(20).get();
  console.log('Total lineages (first 20):');
  for (const doc of allSnapshot.docs) {
    const d = doc.data();
    console.log(`  ${d.rootRecipeId} | owner: ${d.ownerId} | gen: ${d.generation}`);
  }

  console.log('\n=== Checking for demo user lineages ===\n');

  // Check lineage documents for demo users
  const demoSnapshot = await db.collection('lineages')
    .where('rootOwnerId', '==', 'demo_grandmazing')
    .limit(10)
    .get();

  console.log('demo_grandmazing as rootOwnerId:', demoSnapshot.size);
  for (const doc of demoSnapshot.docs) {
    const d = doc.data();
    console.log('  rootRecipeId:', d.rootRecipeId);
    console.log('  currentRecipeId:', d.currentRecipeId);
    console.log('  ownerId:', d.ownerId);
    console.log('  generation:', d.generation);
    console.log('---');
  }

  console.log('\n=== Checking for specific recipe IDs ===\n');

  // Check for lowercase rootRecipeId
  const lowerSnapshot = await db.collection('lineages')
    .where('rootRecipeId', '==', '5e13b837-1a80-4d22-af8a-c474a6ea5c35')
    .limit(5)
    .get();
  console.log('Lineages with lowercase rootRecipeId 5e13b837...:', lowerSnapshot.size);

  // Check for uppercase rootRecipeId
  const upperSnapshot = await db.collection('lineages')
    .where('rootRecipeId', '==', '5e13b837-1a80-4d22-af8a-c474a6ea5c35')
    .limit(5)
    .get();
  console.log('Lineages with uppercase rootRecipeId 5E13B837...:', upperSnapshot.size);

  // Check for fitfoodie recipe
  const fitfoodieSnapshot = await db.collection('lineages')
    .where('rootRecipeId', '==', 'f3890dc5-f51a-455a-8bf2-eb4bb089c5a9')
    .limit(5)
    .get();
  console.log('Lineages with lowercase rootRecipeId f3890dc5...:', fitfoodieSnapshot.size);
  for (const doc of fitfoodieSnapshot.docs) {
    const d = doc.data();
    console.log('  ownerId:', d.ownerId);
    console.log('  generation:', d.generation);
  }
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
