import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      path.resolve(__dirname, '../../../service-account-key.json')
    ),
  });
}

const db = admin.firestore();

const uid = process.argv[2] || 'TuQgh4k7HSY8p5eDk90ja53u9ki2';
const displayName = process.argv[3] || 'heirloomguy';
const email = process.argv[4] || 'newmatthanson@gmail.com';

db.collection('users').doc(uid).set({
  email,
  displayName,
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
}, { merge: true }).then(() => {
  console.log('✅ Profile document created/updated!');
  console.log(`   UID: ${uid}`);
  console.log(`   Display Name: ${displayName}`);
  console.log(`   Email: ${email}`);
}).catch((e: Error) => console.error('Error:', e.message));
