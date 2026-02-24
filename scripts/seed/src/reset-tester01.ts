/**
 * Reset tester01@ to a true first-time user state
 *
 * This script deletes ALL Firebase data for tester01@heirloomrecipebox.app:
 * - All recipes
 * - All collections
 * - All tags
 * - Profile data
 *
 * Run: npx ts-node src/reset-tester01.ts [--fix]
 *
 * Without --fix: Dry run (shows what would be deleted)
 * With --fix: Actually deletes the data
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

// Can override with --email=xxx@xxx.com
const DEFAULT_EMAIL = 'tester01@heirloomrecipebox.app';
const emailArg = process.argv.find(a => a.startsWith('--email='));
const TESTER_EMAIL = emailArg ? emailArg.split('=')[1] : DEFAULT_EMAIL;

async function getUserIdByEmail(email: string): Promise<string | null> {
  try {
    const user = await auth.getUserByEmail(email);
    return user.uid;
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log(`  User not found: ${email}`);
      return null;
    }
    throw error;
  }
}

async function deleteSubcollection(docRef: admin.firestore.DocumentReference, subcollectionName: string, dryRun: boolean): Promise<number> {
  const subcollection = await docRef.collection(subcollectionName).get();
  let count = 0;
  for (const doc of subcollection.docs) {
    if (!dryRun) {
      await doc.ref.delete();
    }
    count++;
  }
  return count;
}

async function resetUser(userId: string, dryRun: boolean): Promise<void> {
  console.log(`\n${'─'.repeat(60)}`);
  console.log(`${dryRun ? '🔍 DRY RUN -' : '🔥 DELETING -'} ${TESTER_EMAIL} (${userId})`);
  console.log(`${'─'.repeat(60)}`);

  const userRef = db.collection('users').doc(userId);

  // Delete recipes (with subcollections)
  const recipesSnapshot = await userRef.collection('recipes').get();
  console.log(`\n📖 Recipes: ${recipesSnapshot.docs.length}`);
  for (const doc of recipesSnapshot.docs) {
    const data = doc.data();
    console.log(`  - ${data.title || 'Untitled'} (${doc.id.substring(0, 8)}...)`);

    if (!dryRun) {
      // Delete subcollections first
      await deleteSubcollection(doc.ref, 'ingredients', dryRun);
      await deleteSubcollection(doc.ref, 'steps', dryRun);
      await deleteSubcollection(doc.ref, 'comments', dryRun);
      await deleteSubcollection(doc.ref, 'operations', dryRun);
      await doc.ref.delete();
    }
  }

  // Delete collections
  const collectionsSnapshot = await userRef.collection('collections').get();
  console.log(`\n📁 Collections: ${collectionsSnapshot.docs.length}`);
  for (const doc of collectionsSnapshot.docs) {
    const data = doc.data();
    console.log(`  - ${data.name || 'Unnamed'} (${data.collectionType || 'unknown'})`);

    if (!dryRun) {
      await doc.ref.delete();
    }
  }

  // Delete tags
  const tagsSnapshot = await userRef.collection('tags').get();
  console.log(`\n🏷️ Tags: ${tagsSnapshot.docs.length}`);
  for (const doc of tagsSnapshot.docs) {
    const data = doc.data();
    console.log(`  - ${data.name || 'Unnamed'}`);

    if (!dryRun) {
      await doc.ref.delete();
    }
  }

  // Delete connections
  const connectionsSnapshot = await userRef.collection('connections').get();
  console.log(`\n👥 Connections: ${connectionsSnapshot.docs.length}`);
  for (const doc of connectionsSnapshot.docs) {
    if (!dryRun) {
      await doc.ref.delete();
    }
  }

  // Delete notifications
  const notificationsSnapshot = await userRef.collection('notifications').get();
  console.log(`\n🔔 Notifications: ${notificationsSnapshot.docs.length}`);
  for (const doc of notificationsSnapshot.docs) {
    if (!dryRun) {
      await doc.ref.delete();
    }
  }

  // Delete user's lineages (user-specific collection)
  const userLineagesSnapshot = await userRef.collection('lineages').get();
  console.log(`\n🌳 User Lineages: ${userLineagesSnapshot.docs.length}`);
  for (const doc of userLineagesSnapshot.docs) {
    if (!dryRun) {
      await doc.ref.delete();
    }
  }

  // Delete from global lineages collection (where ownerId = this user)
  const globalLineagesSnapshot = await db.collection('lineages')
    .where('ownerId', '==', userId)
    .get();
  console.log(`\n🌳 Global Lineages (owned by user): ${globalLineagesSnapshot.docs.length}`);
  for (const doc of globalLineagesSnapshot.docs) {
    if (!dryRun) {
      await doc.ref.delete();
    }
  }

  // Delete any shares created by this user
  const sharesSnapshot = await db.collection('shares')
    .where('ownerId', '==', userId)
    .get();
  console.log(`\n📤 Shares created by user: ${sharesSnapshot.docs.length}`);
  for (const doc of sharesSnapshot.docs) {
    if (!dryRun) {
      await doc.ref.delete();
    }
  }

  // Delete profile (both 'main' and 'data' documents)
  const profileDoc = await userRef.collection('profile').doc('main').get();
  if (profileDoc.exists) {
    console.log(`\n👤 Profile (main): exists`);
    if (!dryRun) {
      await profileDoc.ref.delete();
    }
  }

  // Delete profile/data document (contains hasCompletedOnboarding flag)
  const profileDataDoc = await userRef.collection('profile').doc('data').get();
  if (profileDataDoc.exists) {
    console.log(`\n👤 Profile (data): exists - contains onboarding flag`);
    if (!dryRun) {
      await profileDataDoc.ref.delete();
    }
  }

  // Clear lastSyncDate from user document
  const userDoc = await userRef.get();
  if (userDoc.exists) {
    console.log(`\n📄 User document: exists`);
    if (!dryRun) {
      await userRef.delete();
    }
  }

  console.log(`\n${'─'.repeat(60)}`);
  if (dryRun) {
    console.log('🔍 DRY RUN COMPLETE - No changes made');
    console.log('Run with --fix to delete this data');
  } else {
    console.log('✅ RESET COMPLETE - tester01@ is now a fresh first-time user');
    console.log('The next login will show full onboarding experience');
  }
  console.log(`${'─'.repeat(60)}\n`);
}

async function main(): Promise<void> {
  const dryRun = !process.argv.includes('--fix');

  console.log('\n' + '═'.repeat(60));
  console.log('RESET TESTER01@ TO FIRST-TIME USER STATE');
  console.log(dryRun ? '🔍 DRY RUN MODE' : '🔥 LIVE MODE - DATA WILL BE DELETED');
  console.log('═'.repeat(60));

  const userId = await getUserIdByEmail(TESTER_EMAIL);
  if (!userId) {
    console.log('\n❌ Could not find user. Exiting.');
    process.exit(1);
  }

  await resetUser(userId, dryRun);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
