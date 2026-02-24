/**
 * Detailed check of tester01 account - recipes, images, collections, connections
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
const auth = admin.auth();

async function main() {
  const email = 'tester01@heirloomrecipebox.app';

  console.log('=== TESTER01 DETAILED CHECK ===\n');

  const user = await auth.getUserByEmail(email);
  const userId = user.uid;
  console.log('User ID:', userId);
  console.log('Email:', email);
  console.log('');

  // Check recipes with image status
  console.log('=== RECIPES ===');
  const recipesSnap = await db.collection('users').doc(userId).collection('recipes').get();

  let withImages = 0;
  let withoutImages = 0;
  const recipesWithoutImages: string[] = [];

  for (const doc of recipesSnap.docs) {
    const d = doc.data();
    const hasImage = d.firebaseImageURL || d.imageFileName;

    if (hasImage) {
      withImages++;
    } else {
      withoutImages++;
      recipesWithoutImages.push(d.title || 'Untitled');
    }

    console.log('- ' + (d.title || 'Untitled'));
    console.log('  ID: ' + doc.id);
    console.log('  Image: ' + (hasImage ? 'YES' : 'MISSING'));
    if (d.firebaseImageURL) {
      const url = d.firebaseImageURL;
      console.log('  Firebase URL: ' + url.substring(0, 80) + '...');
    }
    console.log('  Source: ' + (d.sourceType || 'unknown'));
    console.log('  isDemoRecipe: ' + (d.isDemoRecipe || false));
    console.log('  themeRecipeId: ' + (d.themeRecipeId || 'none'));
    if (d.heritageChain && d.heritageChain.length > 0) {
      console.log('  heritageChain: ' + d.heritageChain.join(' -> '));
    }
    console.log('');
  }

  console.log('IMAGE SUMMARY:');
  console.log('  With images: ' + withImages);
  console.log('  Missing images: ' + withoutImages);
  if (recipesWithoutImages.length > 0) {
    console.log('  Recipes needing images: ' + recipesWithoutImages.join(', '));
  }
  console.log('');

  // Check collections
  console.log('=== COLLECTIONS ===');
  const collSnap = await db.collection('users').doc(userId).collection('collections').get();

  for (const doc of collSnap.docs) {
    const d = doc.data();
    const recipeCount = d.recipeIds?.length || 0;
    console.log('- ' + d.name + ' (' + recipeCount + ' recipes)');
    console.log('  ID: ' + doc.id);
    console.log('  Type: ' + (d.collectionType || 'user'));
    console.log('  isDemoSeed: ' + (d.isDemoSeed || false));
    console.log('');
  }

  // Check connections
  console.log('=== CONNECTIONS ===');
  const connSnap = await db.collection('users').doc(userId).collection('connections').get();

  if (connSnap.empty) {
    console.log('No connections');
  } else {
    for (const doc of connSnap.docs) {
      const d = doc.data();
      const isDemo = d.connectedUserId?.startsWith('demo_') || false;
      console.log('- ' + (d.connectedUserDisplayName || d.connectedUserId));
      console.log('  Status: ' + d.status);
      console.log('  isDemo: ' + isDemo);
      console.log('');
    }
  }

  // Check profile
  console.log('=== PROFILE ===');
  const profileSnap = await db.collection('users').doc(userId).get();
  if (profileSnap.exists) {
    const profile = profileSnap.data();
    console.log('Display Name: ' + (profile?.displayName || 'not set'));
    console.log('Photo URL: ' + (profile?.photoURL ? 'set' : 'not set'));
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
