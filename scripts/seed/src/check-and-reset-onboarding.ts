import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function checkAndReset() {
  const tester01 = 'uBaIzSsCTnWXPoYSLHwpkU54G3U2';

  // Check current state
  const profile = await db.doc(`users/${tester01}/profile/data`).get();
  console.log('Current profile data:');
  console.log(JSON.stringify(profile.data(), null, 2));

  // Force reset
  await db.doc(`users/${tester01}/profile/data`).set({
    ...profile.data(),
    hasCompletedOnboarding: false
  });

  // Verify
  const updated = await db.doc(`users/${tester01}/profile/data`).get();
  console.log('\nUpdated hasCompletedOnboarding:', updated.data()?.hasCompletedOnboarding);
}

checkAndReset().catch(console.error);
