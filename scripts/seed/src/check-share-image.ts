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

async function check() {
  const shareDoc = await db.doc('shares/9A02A587-AAA4-465C-B90E-1E58CDBAC49F').get();
  if (!shareDoc.exists) {
    console.log('Share not found');
    return;
  }

  const data = shareDoc.data()!;
  console.log('Share firebaseImageURL:', data.firebaseImageURL);
  console.log('Recipe ID:', data.recipeId);
  console.log('Owner ID:', data.ownerId);

  const recipeDoc = await db.doc('users/' + data.ownerId + '/recipes/' + data.recipeId).get();
  console.log('Recipe exists:', recipeDoc.exists);
  if (recipeDoc.exists) {
    console.log('Recipe firebaseImageURL:', recipeDoc.data()!.firebaseImageURL);
  }
}

check().then(() => process.exit(0));
