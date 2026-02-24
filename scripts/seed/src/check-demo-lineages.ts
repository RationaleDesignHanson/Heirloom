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
  // Check lineages for the demo cookie recipe
  const recipeId = '5e13b837-1a80-4d22-af8a-c474a6ea5c35';

  console.log('=== Checking lineages for demo cookie recipe ===');
  console.log('Recipe ID:', recipeId);

  // Query by rootRecipeId
  const rootSnapshot = await db.collection('lineages')
    .where('rootRecipeId', '==', recipeId)
    .get();
  console.log('\nLineages with rootRecipeId:', rootSnapshot.size);
  for (const doc of rootSnapshot.docs) {
    const d = doc.data();
    console.log('  Doc ID:', doc.id);
    console.log('    ownerId:', d.ownerId);
    console.log('    currentRecipeId:', d.currentRecipeId);
    console.log('    generation:', d.generation);
    console.log('    rootOwnerId:', d.rootOwnerId);
    console.log('---');
  }

  // Also check for uppercase (shouldn't find any now)
  const upperSnapshot = await db.collection('lineages')
    .where('rootRecipeId', '==', recipeId.toUpperCase())
    .get();
  console.log('\nLineages with UPPERCASE rootRecipeId:', upperSnapshot.size);

  // Check what lineages exist for demo users
  console.log('\n=== Checking lineages for demo users ===');
  const demoUsers = ['demo_grandmazing', 'demo_fitfoodie', 'demo_alexchen'];

  for (const userId of demoUsers) {
    const userLineages = await db.collection('lineages')
      .where('ownerId', '==', userId)
      .get();
    console.log(`\n${userId}: ${userLineages.size} lineages`);
    for (const doc of userLineages.docs) {
      const d = doc.data();
      console.log(`  rootRecipeId: ${d.rootRecipeId}`);
      console.log(`  generation: ${d.generation}`);
    }
  }
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
