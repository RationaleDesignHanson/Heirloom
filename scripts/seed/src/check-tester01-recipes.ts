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
  const tester01Id = 'uBaIzSsCTnWXPoYSLHwpkU54G3U2';

  console.log('=== tester01 Recipes ===\n');
  const recipes = await db.collection(`users/${tester01Id}/recipes`).get();
  console.log('Total recipes:', recipes.size);

  recipes.forEach(doc => {
    const d = doc.data();
    console.log('\nRecipe:', doc.id);
    console.log('  Title:', d.title);
    console.log('  Source Type:', d.sourceType);
    console.log('  Inherited From:', d.inheritedFromUserId);
    console.log('  Generation:', d.generation);
    console.log('  Heritage Chain:', d.heritageChainNames);
    console.log('  Firebase Image:', d.firebaseImageURL ? 'yes' : 'no');
  });

  // Check tester01's lineages
  console.log('\n=== tester01 Lineages ===');
  const lineages = await db.collection('lineages')
    .where('ownerId', '==', tester01Id)
    .get();
  console.log('Count:', lineages.size);

  lineages.forEach(doc => {
    const d = doc.data();
    console.log('\nLineage:', doc.id);
    console.log('  Recipe:', d.title || d.recipeTitle);
    console.log('  Generation:', d.generation);
    console.log('  Root Owner:', d.rootOwnerId);
    console.log('  Parent Owner:', d.parentOwnerId);
  });
}

check();
