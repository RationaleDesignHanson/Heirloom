/**
 * Set up profile names and avatars for demo@ and deletetest@ accounts
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { callReplicateAPI, delay } from './utils/replicate';
import { getStorage } from 'firebase-admin/storage';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
    storageBucket: 'heirloom-ios-prod.firebasestorage.app',
  });
}

const db = admin.firestore();
const storage = getStorage().bucket();

const ACCOUNTS = [
  {
    email: 'demo@heirloomrecipebox.app',
    userId: 'R0T5LDdelWQj87sk96IyAd2ttTZ2',
    displayName: 'PurchaseDemo',
    avatarSlug: 'purchase-demo',
    avatarPrompt: 'Simple flat icon style illustration of a golden money bag with dollar sign, moneybags emoji style, gold and green colors, white background, minimal clean design, app icon style, centered composition, 8k resolution'
  },
  {
    email: 'deletetest@heirloomrecipebox.app',
    userId: 'SgD5W23m1TfDK9tPaCNDAaED6ZY2',
    displayName: 'DeletionDemo',
    avatarSlug: 'deletion-demo',
    avatarPrompt: 'Simple flat icon style illustration of a trash can or recycle bin, trash emoji style, gray and silver metallic colors, white background, minimal clean design, app icon style, centered composition, 8k resolution'
  }
];

async function setupAccount(account: typeof ACCOUNTS[0]): Promise<void> {
  console.log('\n' + '='.repeat(50));
  console.log('Setting up: ' + account.email);
  console.log('Display Name: ' + account.displayName);
  console.log('='.repeat(50));

  const avatarPath = 'seed/test-accounts/' + account.avatarSlug + '-avatar.webp';
  const avatarFile = storage.file(avatarPath);

  // Check if avatar exists
  const [exists] = await avatarFile.exists();
  let avatarUrl: string;

  if (exists) {
    console.log('Avatar already exists, using existing...');
    avatarUrl = 'https://storage.googleapis.com/' + storage.name + '/' + avatarPath;
  } else {
    console.log('Generating avatar...');
    console.log('  Prompt: ' + account.avatarPrompt.substring(0, 60) + '...');

    try {
      const generatedUrl = await callReplicateAPI({
        prompt: account.avatarPrompt,
        aspect_ratio: '1:1',
        output_format: 'webp',
        output_quality: 90,
        safety_tolerance: 2,
        prompt_upsampling: true,
      });

      console.log('  Downloading...');
      const response = await fetch(generatedUrl);
      const buffer = await response.arrayBuffer();

      console.log('  Uploading to Firebase Storage...');
      await avatarFile.save(Buffer.from(buffer), {
        metadata: { contentType: 'image/webp', cacheControl: 'public, max-age=31536000' },
      });

      avatarUrl = 'https://storage.googleapis.com/' + storage.name + '/' + avatarPath;
      console.log('  Avatar uploaded: ' + avatarUrl);
    } catch (error) {
      console.error('  Avatar generation failed: ' + error);
      return;
    }
  }

  // Update Firestore profile
  console.log('Updating Firestore profile...');
  await db.collection('users').doc(account.userId).set({
    displayName: account.displayName,
    photoURL: avatarUrl,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('DONE: ' + account.displayName);
}

async function main() {
  console.log('Setting up test account profiles...\n');

  for (const account of ACCOUNTS) {
    await setupAccount(account);
    await delay(1000);
  }

  console.log('\n' + '='.repeat(50));
  console.log('ALL DONE');
  console.log('='.repeat(50));
}

main().then(() => process.exit(0)).catch(console.error);
