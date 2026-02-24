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
  // Check the cookies recipe heritageChain
  console.log('=== Test user cookies recipe ===\n');
  const recipesSnapshot = await db.collection('users').doc(TEST_USER_ID).collection('recipes').get();
  
  for (const doc of recipesSnapshot.docs) {
    const data = doc.data();
    if (data.title?.includes('Chocolate Chip') && data.sourceType === 'shared') {
      console.log('Title: ' + data.title);
      console.log('heritageChain: ' + JSON.stringify(data.heritageChain));
      console.log('heritageChainNames: ' + JSON.stringify(data.heritageChainNames));
      console.log('rootRecipeId: ' + data.rootRecipeId);
      console.log('sharedBy: ' + data.sharedBy);
      console.log('');
    }
  }

  // Check Favorites collection
  console.log('\n=== Favorites collection ===\n');
  const collectionsSnapshot = await db.collection('users').doc(TEST_USER_ID).collection('collections').get();
  
  for (const doc of collectionsSnapshot.docs) {
    const data = doc.data();
    if (data.name === 'Favorites') {
      console.log('ID: ' + doc.id);
      console.log('recipeIds count: ' + (data.recipeIds?.length || 0));
      console.log('recipeIds: ' + JSON.stringify(data.recipeIds?.slice(0, 10)));
    }
  }

  // Check recipes with isFavorite flag
  console.log('\n=== Recipes with isFavorite=true ===\n');
  let favCount = 0;
  for (const doc of recipesSnapshot.docs) {
    const data = doc.data();
    if (data.isFavorite) {
      console.log('- ' + data.title);
      favCount++;
    }
  }
  console.log('\nTotal favorites: ' + favCount);
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
