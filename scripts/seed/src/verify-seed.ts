import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, '../../../service-account-key.json')),
  });
}

const db = admin.firestore();
const TEST_USER_ID = 'nVkKpcbBtdNxXqRErSYQdeIUiHh1';

async function verify() {
  console.log('=== SEED DATA VERIFICATION ===\n');
  console.log('Test User ID: ' + TEST_USER_ID + '\n');

  // Check collections
  console.log('--- Collections ---');
  const cols = await db.collection('users').doc(TEST_USER_ID).collection('collections').get();
  console.log('Total: ' + cols.docs.length);
  for (const doc of cols.docs) {
    const d = doc.data();
    console.log('  ' + d.name + ': ' + (d.recipeIds?.length || 0) + ' recipes');
  }

  // Check recipes
  console.log('\n--- Recipes ---');
  const recipes = await db.collection('users').doc(TEST_USER_ID).collection('recipes').get();
  console.log('Total: ' + recipes.docs.length);
  let favCount = 0;
  for (const doc of recipes.docs) {
    const d = doc.data();
    if (d.isFavorite) favCount++;
  }
  console.log('With isFavorite=true: ' + favCount);

  // Check the cookies recipe in detail
  console.log('\n--- Grandmazing Cookies (shared) ---');
  for (const doc of recipes.docs) {
    const d = doc.data();
    if (d.title?.includes('Brown Butter') && d.sourceType === 'shared') {
      console.log('sharedBy: ' + d.sharedBy);
      console.log('sharedByName: ' + d.sharedByName);
      console.log('heritageChain: ' + JSON.stringify(d.heritageChain));
      console.log('heritageChainNames: ' + JSON.stringify(d.heritageChainNames));
      console.log('generationCount: ' + d.generationCount);
    }
  }

  // Check lineages for cookies rootRecipeId
  console.log('\n--- Lineages for cookies (rootRecipeId: 5e13b837...) ---');
  const lineages = await db.collection('lineages')
    .where('rootRecipeId', '==', '5e13b837-1a80-4d22-af8a-c474a6ea5c35')
    .get();
  console.log('Total in global index: ' + lineages.docs.length);
  for (const doc of lineages.docs) {
    const d = doc.data();
    console.log('  Gen ' + d.generation + ' | ' + d.ownerId);
  }

  // Check user's lineages
  console.log('\n--- User lineages ---');
  const userLineages = await db.collection('users').doc(TEST_USER_ID).collection('lineages').get();
  console.log('Total: ' + userLineages.docs.length);
  for (const doc of userLineages.docs) {
    const d = doc.data();
    console.log('  Gen ' + d.generation + ' | root: ' + (d.rootRecipeId || '').substring(0, 8));
  }
}

verify().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
