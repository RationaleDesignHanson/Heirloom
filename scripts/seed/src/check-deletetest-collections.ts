import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, '../../../service-account-key.json')),
  });
}

const db = admin.firestore();
const userId = 'ngVz2G0d4ZQ545hzJMV7dk7TIlK2';

async function check() {
  console.log('=== Collections for deletetest user ===\n');

  const collections = await db.collection('users/' + userId + '/collections').get();

  for (const doc of collections.docs) {
    const d = doc.data();
    console.log('Collection: ' + d.name);
    console.log('  ID: ' + doc.id);
    console.log('  recipeIds: ' + (d.recipeIds ? d.recipeIds.length : 0) + ' recipes');
    if (d.recipeIds && d.recipeIds.length > 0) {
      console.log('  recipeIds list: ' + JSON.stringify(d.recipeIds.slice(0, 3)) + (d.recipeIds.length > 3 ? '...' : ''));
    }
    console.log('  isSystemCollection: ' + d.isSystemCollection);
    console.log('  collectionType: ' + d.collectionType);
    if (d.customBackgroundImagePath) {
      console.log('  customBackgroundImagePath: ' + d.customBackgroundImagePath);
    }
    console.log('');
  }

  console.log('=== Recipes ===\n');
  const recipes = await db.collection('users/' + userId + '/recipes').get();
  console.log('Total recipes: ' + recipes.docs.length + '\n');

  for (const doc of recipes.docs) {
    const d = doc.data();
    const collectionIds = d.collectionIds || [];
    console.log(d.title);
    console.log('  ID: ' + doc.id);
    console.log('  isFavorite: ' + d.isFavorite);
    console.log('  collectionIds: ' + (collectionIds.length > 0 ? JSON.stringify(collectionIds) : '(none)'));
    console.log('');
  }

  // Cross-reference check
  console.log('=== Cross-reference Check ===\n');
  const collectionMap = new Map<string, { name: string; recipeIds: string[] }>();
  for (const doc of collections.docs) {
    const d = doc.data();
    collectionMap.set(doc.id, { name: d.name, recipeIds: d.recipeIds || [] });
  }

  for (const doc of recipes.docs) {
    const d = doc.data();
    const recipeCollectionIds = d.collectionIds || [];

    for (const collId of recipeCollectionIds) {
      const coll = collectionMap.get(collId);
      if (!coll) {
        console.log('WARNING: Recipe "' + d.title + '" references non-existent collection: ' + collId);
      } else if (!coll.recipeIds.includes(doc.id)) {
        console.log('WARNING: Recipe "' + d.title + '" in collectionIds but not in collection "' + coll.name + '" recipeIds');
      }
    }
  }

  // Check collections have valid recipe references
  for (const [collId, coll] of collectionMap) {
    for (const recipeId of coll.recipeIds) {
      const recipeExists = recipes.docs.some(r => r.id === recipeId);
      if (!recipeExists) {
        console.log('WARNING: Collection "' + coll.name + '" references non-existent recipe: ' + recipeId);
      }
    }
  }

  console.log('\nDone.');
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
