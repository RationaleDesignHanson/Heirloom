import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function main() {
  const accounts = [
    { email: 'tester01@heirloomrecipebox.app', uid: 'uBaIzSsCTnWXPoYSLHwpkU54G3U2' },
    { email: 'demo@heirloomrecipebox.app', uid: 'R0T5LDdelWQj87sk96IyAd2ttTZ2' },
    { email: 'deletetest@heirloomrecipebox.app', uid: 'SgD5W23m1TfDK9tPaCNDAaED6ZY2' }
  ];

  console.log('Apple Test Accounts Status:\n');
  for (const acc of accounts) {
    const doc = await db.collection('users').doc(acc.uid).get();
    const data = doc.data() || {};
    console.log(acc.email);
    console.log('  Display Name: ' + (data.displayName || 'NOT SET'));
    console.log('  Photo URL: ' + (data.photoURL ? 'YES' : 'NOT SET'));
    console.log('');
  }
}

main().then(() => process.exit(0)).catch(console.error);
