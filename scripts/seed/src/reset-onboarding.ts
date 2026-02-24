import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function resetOnboarding() {
  const tester01 = 'uBaIzSsCTnWXPoYSLHwpkU54G3U2';

  await db.doc(`users/${tester01}/profile/data`).update({
    hasCompletedOnboarding: false
  });

  console.log('Reset tester01 onboarding flag to false');
  console.log('Now delete app and reinstall to go through onboarding');
}

resetOnboarding().catch(console.error);
