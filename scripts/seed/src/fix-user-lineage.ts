import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

async function fix() {
  const rootRecipeId = '7EE0A981-0DD2-4105-AA26-AB941C23D688';
  const userId = 'TuQgh4k7HSY8p5eDk90ja53u9ki2';

  // Find the user's lineage record
  const lineages = await db.collection('lineages')
    .where('rootRecipeId', '==', rootRecipeId)
    .where('ownerId', '==', userId)
    .get();

  console.log('Found', lineages.size, 'user lineage records');

  for (const doc of lineages.docs) {
    const data = doc.data();
    console.log('Current data:', JSON.stringify(data, null, 2));

    // Fix the recipeId field - should be same as rootRecipeId for immutable recipe IDs
    if (!data.recipeId) {
      await doc.ref.update({
        recipeId: rootRecipeId,
        currentRecipeId: rootRecipeId
      });
      console.log('Fixed recipeId to:', rootRecipeId);
    }
  }
}

fix().then(() => process.exit(0));
