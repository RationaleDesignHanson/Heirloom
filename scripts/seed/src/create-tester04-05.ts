/**
 * Create tester04 and tester05 accounts
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

const auth = admin.auth();
const db = admin.firestore();

const ACCOUNTS = [
  { email: 'tester04@heirloomrecipebox.app', password: '123456', name: 'Test User 04' },
  { email: 'tester05@heirloomrecipebox.app', password: '123456', name: 'Test User 05' },
];

async function createAccount(account: typeof ACCOUNTS[0]): Promise<void> {
  // Check if user already exists
  try {
    const existingUser = await auth.getUserByEmail(account.email);
    console.log(`✓ ${account.email} already exists: ${existingUser.uid}`);
    return;
  } catch (error: any) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  // Create user
  const userRecord = await auth.createUser({
    email: account.email,
    password: account.password,
    displayName: account.name,
    emailVerified: true,
  });

  console.log(`✅ Created ${account.email}: ${userRecord.uid}`);

  // Create minimal user profile in Firestore
  await db.collection('users').doc(userRecord.uid).set({
    email: account.email,
    displayName: account.name,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Create profile/data document
  await db.collection('users').doc(userRecord.uid).collection('profile').doc('data').set({
    displayName: account.name,
    hasCompletedOnboarding: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`   Created Firestore profile for ${account.email}`);
}

async function main(): Promise<void> {
  console.log('Creating tester04 and tester05 accounts...\n');

  for (const account of ACCOUNTS) {
    await createAccount(account);
  }

  console.log('\n='.repeat(50));
  console.log('ACCOUNTS READY');
  console.log('='.repeat(50));
  console.log('tester04@heirloomrecipebox.app / 123456');
  console.log('tester05@heirloomrecipebox.app / 123456');
  console.log('='.repeat(50));
}

main().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
