/**
 * Reset all tester accounts (01-05) to fresh first-time user state
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

// Tester accounts to reset
const TESTER_EMAILS = [
  'tester01@heirloomrecipebox.app',
  'tester02@heirloomrecipebox.app',
  'tester03@heirloomrecipebox.app',
  'tester04@heirloomrecipebox.app',
  'tester05@heirloomrecipebox.app',
];

async function resetUser(email: string): Promise<void> {
  console.log(`\n--- Resetting ${email} ---`);

  // Get user ID from email
  let userId: string;
  try {
    const user = await auth.getUserByEmail(email);
    userId = user.uid;
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log(`  User not found, skipping`);
      return;
    }
    throw error;
  }

  console.log(`  UID: ${userId}`);

  // Delete all recipes (including ingredients subcollection)
  const recipes = await db.collection(`users/${userId}/recipes`).get();
  for (const doc of recipes.docs) {
    const ingredients = await doc.ref.collection('ingredients').get();
    for (const ing of ingredients.docs) {
      await ing.ref.delete();
    }
    await doc.ref.delete();
  }
  console.log(`  Deleted ${recipes.size} recipes`);

  // Delete all connections
  const connections = await db.collection(`users/${userId}/connections`).get();
  for (const doc of connections.docs) {
    await doc.ref.delete();
  }
  console.log(`  Deleted ${connections.size} connections`);

  // Delete all notifications
  const notifications = await db.collection(`users/${userId}/notifications`).get();
  for (const doc of notifications.docs) {
    await doc.ref.delete();
  }
  console.log(`  Deleted ${notifications.size} notifications`);

  // Delete all collections
  const collections = await db.collection(`users/${userId}/collections`).get();
  for (const doc of collections.docs) {
    await doc.ref.delete();
  }
  console.log(`  Deleted ${collections.size} collections`);

  // Reset profile
  await db.doc(`users/${userId}/profile/data`).set({
    hasCompletedOnboarding: false,
    selectedThemeIds: [],
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log(`  Reset onboarding flag`);

  // Delete shares FROM this user
  const sharesFrom = await db.collection('shares').where('ownerId', '==', userId).get();
  for (const doc of sharesFrom.docs) {
    await doc.ref.delete();
  }
  console.log(`  Deleted ${sharesFrom.size} outgoing shares`);

  // Delete shares TO this user
  const sharesTo = await db.collection('shares').where('recipientUserIds', 'array-contains', userId).get();
  for (const doc of sharesTo.docs) {
    await doc.ref.delete();
  }
  console.log(`  Deleted ${sharesTo.size} incoming shares`);

  // Delete lineages owned by this user
  const lineages = await db.collection('lineages').where('ownerId', '==', userId).get();
  for (const doc of lineages.docs) {
    await doc.ref.delete();
  }
  console.log(`  Deleted ${lineages.size} lineages`);
}

async function main(): Promise<void> {
  console.log('=== Resetting All Tester Accounts ===');
  console.log('This will reset tester01-05 to fresh first-time user state.\n');

  for (const email of TESTER_EMAILS) {
    await resetUser(email);
  }

  console.log('\n=== Reset Complete ===');
  console.log('All testers are now fresh first-time users.');
  console.log('Delete apps and reinstall to go through onboarding.\n');
}

main().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
