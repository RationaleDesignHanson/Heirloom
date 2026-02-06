/**
 * Fix share document image URLs to match recipe image URLs
 */

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

async function updateShareImages() {
  console.log('Updating share documents with correct image URLs...');

  // Get all demo shares (isDemoShare = true)
  const shares = await db.collection('shares').where('isDemoShare', '==', true).get();

  console.log(`Found ${shares.size} demo shares`);

  for (const doc of shares.docs) {
    const shareData = doc.data();
    const recipeId = shareData.recipeId;
    const ownerId = shareData.ownerId;

    // Get the recipe to get the correct image URL
    const recipeDoc = await db.doc(`users/${ownerId}/recipes/${recipeId}`).get();

    if (recipeDoc.exists) {
      const recipeData = recipeDoc.data();
      const correctImageURL = recipeData?.firebaseImageURL;

      if (correctImageURL && correctImageURL !== shareData.firebaseImageURL) {
        await doc.ref.update({
          firebaseImageURL: correctImageURL
        });
        console.log(`  Updated: ${shareData.recipeTitle}`);
        console.log(`    Old: ${shareData.firebaseImageURL}`);
        console.log(`    New: ${correctImageURL}`);
      } else {
        console.log(`  OK: ${shareData.recipeTitle} (image URL matches)`);
      }
    } else {
      console.log(`  WARN: Recipe not found for share ${doc.id}`);
    }
  }

  console.log('\nDone!');
}

updateShareImages()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
