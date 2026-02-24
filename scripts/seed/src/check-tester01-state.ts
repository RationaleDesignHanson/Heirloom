import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();
const tester01 = 'uBaIzSsCTnWXPoYSLHwpkU54G3U2';

async function checkState() {
  console.log('=== Checking tester01 Firebase State ===\n');

  // Check connections
  const connections = await db.collection(`users/${tester01}/connections`).get();
  console.log('Connections:', connections.size);
  connections.docs.forEach(doc => {
    const d = doc.data();
    console.log('  -', doc.id, d.connectedUserId, d.status);
  });

  // Check profile
  const profile = await db.doc(`users/${tester01}/profile/data`).get();
  const pd = profile.data();
  console.log('\nProfile:');
  console.log('  hasCompletedOnboarding:', pd?.hasCompletedOnboarding);
  console.log('  displayName:', pd?.displayName);
}

checkState().catch(console.error);
