/**
 * Create Test Account
 *
 * Creates a simple test account for manual testing.
 *
 * Run: npx ts-node src/create-test-account.ts
 * Delete: npx ts-node src/create-test-account.ts delete
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const auth = admin.auth();
const db = admin.firestore();

// Default test account (can be overridden via command line)
const TEST_ACCOUNTS = {
  '01': { email: 'tester01@heirloomrecipebox.app', password: '123456', name: 'Test User 01' },
  '02': { email: 'tester02@heirloomrecipebox.app', password: '123456', name: 'Test User 02' },
};

const accountNum = process.argv.find(arg => arg === '02') ? '02' : '01';
const TEST_EMAIL = TEST_ACCOUNTS[accountNum].email;
const TEST_PASSWORD = TEST_ACCOUNTS[accountNum].password;
const TEST_DISPLAY_NAME = TEST_ACCOUNTS[accountNum].name;

async function createAccount(): Promise<void> {
  console.log('Creating test account...\n');

  // Check if user already exists
  try {
    const existingUser = await auth.getUserByEmail(TEST_EMAIL);
    console.log(`User already exists: ${existingUser.uid}`);
    console.log(`Email: ${TEST_EMAIL}`);
    console.log(`Password: ${TEST_PASSWORD}`);
    return;
  } catch (error: any) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  // Create user
  const userRecord = await auth.createUser({
    email: TEST_EMAIL,
    password: TEST_PASSWORD,
    displayName: TEST_DISPLAY_NAME,
    emailVerified: true,
  });

  console.log(`✅ Created user: ${userRecord.uid}`);

  // Create minimal user profile in Firestore
  await db.collection('users').doc(userRecord.uid).set({
    email: TEST_EMAIL,
    displayName: TEST_DISPLAY_NAME,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('✅ Created user profile in Firestore');

  console.log('\n' + '='.repeat(40));
  console.log('TEST ACCOUNT CREATED');
  console.log('='.repeat(40));
  console.log(`Email:    ${TEST_EMAIL}`);
  console.log(`Password: ${TEST_PASSWORD}`);
  console.log(`UID:      ${userRecord.uid}`);
  console.log('='.repeat(40));
}

async function deleteAccount(): Promise<void> {
  console.log('Deleting test account...\n');

  try {
    const user = await auth.getUserByEmail(TEST_EMAIL);

    // Delete Firestore data
    const userRef = db.collection('users').doc(user.uid);

    // Delete subcollections
    const recipes = await userRef.collection('recipes').get();
    for (const doc of recipes.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${recipes.size} recipes`);

    const collections = await userRef.collection('collections').get();
    for (const doc of collections.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${collections.size} collections`);

    // Delete user document
    await userRef.delete();
    console.log('  Deleted user document');

    // Delete auth user
    await auth.deleteUser(user.uid);
    console.log('  Deleted auth user');

    console.log('\n✅ Test account deleted');
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log('User not found - nothing to delete');
    } else {
      throw error;
    }
  }
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.includes('delete')) {
    await deleteAccount();
  } else {
    await createAccount();
  }
}

main().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
