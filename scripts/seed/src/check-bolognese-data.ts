import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, '../../../service-account-key.json')),
  });
}

const db = admin.firestore();

async function check() {
  const rootRecipeId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  const bigshareRecipeId = 'e5f6a7b8-c9d0-1234-efab-345678901234';
  const testUserId = 'hHVSiLLLw5fc6bRYDmlyoVgYXbE2';

  console.log('=== Grandmazing Root Bolognese ===');
  const root = await db.doc('users/demo_grandmazing/recipes/' + rootRecipeId).get();
  if (root.exists) {
    const d = root.data()!;
    console.log('Title: ' + d.title);
    console.log('sourceType: ' + d.sourceType);
    console.log('heritageChain: ' + JSON.stringify(d.heritageChain));
    const ing = await db.collection('users/demo_grandmazing/recipes/' + rootRecipeId + '/ingredients').get();
    console.log('Ingredients: ' + ing.docs.length);
  } else {
    console.log('NOT FOUND');
  }

  console.log('\n=== Big Share Bolognese ===');
  const bigshare = await db.doc('users/demo_bigshare/recipes/' + bigshareRecipeId).get();
  if (bigshare.exists) {
    const d = bigshare.data()!;
    console.log('Title: ' + d.title);
    console.log('sourceType: ' + d.sourceType);
    console.log('heritageChain: ' + JSON.stringify(d.heritageChain));
    const ing = await db.collection('users/demo_bigshare/recipes/' + bigshareRecipeId + '/ingredients').get();
    console.log('Ingredients: ' + ing.docs.length);
  } else {
    console.log('NOT FOUND');
  }

  console.log('\n=== Test User Bolognese ===');
  const testUser = await db.doc('users/' + testUserId + '/recipes/' + bigshareRecipeId).get();
  if (testUser.exists) {
    const d = testUser.data()!;
    console.log('Title: ' + d.title);
    console.log('sourceType: ' + d.sourceType);
    console.log('heritageChain: ' + JSON.stringify(d.heritageChain));
    console.log('sharedBy: ' + d.sharedBy);
    console.log('sharedByUserId: ' + d.sharedByUserId);
    console.log('provenance: ' + JSON.stringify(d.provenance));
    const ing = await db.collection('users/' + testUserId + '/recipes/' + bigshareRecipeId + '/ingredients').get();
    console.log('Ingredients: ' + ing.docs.length);
  } else {
    console.log('NOT FOUND');
  }
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
