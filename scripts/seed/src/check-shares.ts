import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function check() {
  const tester01Id = 'uBaIzSsCTnWXPoYSLHwpkU54G3U2';

  // Check shares TO tester01
  console.log('=== Shares TO tester01 ===');
  const sharesToTester = await db.collection('shares')
    .where('recipientId', '==', tester01Id)
    .get();
  console.log('Count:', sharesToTester.size);
  sharesToTester.forEach(doc => {
    const d = doc.data();
    console.log('  -', d.recipeTitle, 'from', d.senderDisplayName, '(status:', d.status + ')');
  });

  // Check shares FROM demo_bigshare
  console.log('\n=== Shares FROM demo_bigshare ===');
  const sharesFromBigshare = await db.collection('shares')
    .where('senderId', '==', 'demo_bigshare')
    .get();
  console.log('Count:', sharesFromBigshare.size);
  sharesFromBigshare.forEach(doc => {
    const d = doc.data();
    console.log('  -', d.recipeTitle, 'to', d.recipientId, '(status:', d.status + ')');
  });

  // Check user shares subcollection
  console.log('\n=== tester01 user shares subcollection ===');
  const userShares = await db.collection('users/' + tester01Id + '/shares').get();
  console.log('Count:', userShares.size);
  userShares.forEach(doc => {
    const d = doc.data();
    console.log('  -', d.recipeTitle, 'from', d.senderDisplayName, '(status:', d.status + ')');
  });
}

check();
