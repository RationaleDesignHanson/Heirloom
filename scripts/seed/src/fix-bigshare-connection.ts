import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function fix() {
  const tester01Id = 'uBaIzSsCTnWXPoYSLHwpkU54G3U2';
  const connId = '7989acd4-d018-457a-95ff-6ebd7271da95';

  // Get tester01's connection to copy from
  const tester01Conn = await db.doc('users/' + tester01Id + '/connections/' + connId).get();
  if (!tester01Conn.exists) {
    console.log('ERROR: tester01 connection not found');
    return;
  }

  const t1Data = tester01Conn.data()!;

  // Create reciprocal connection for demo_bigshare
  const bigshareConnData = {
    id: connId,
    userId: 'demo_bigshare',
    connectedUserId: tester01Id,
    connectedUserDisplayName: 'Tester1Guy', // tester01's display name
    connectedUserPhotoURL: '',
    status: 'connected',
    initiatedBy: tester01Id,
    isFavorite: false,
    isKitchenTableConnection: false,
    recipesReceivedCount: 0,
    recipesSharedCount: 0,
    createdAt: t1Data.createdAt,
    requestedAt: t1Data.requestedAt,
    acceptedAt: t1Data.acceptedAt,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.doc('users/demo_bigshare/connections/' + connId).set(bigshareConnData);
  console.log('Created reciprocal connection for demo_bigshare');

  // Delete the old stale connection to tester03
  const oldConnId = '65f01663-7cb8-4323-bb58-12b3ba9d358b';
  await db.doc('users/demo_bigshare/connections/' + oldConnId).delete();
  console.log('Deleted stale connection to tester03');

  console.log('Done! demo_bigshare now has connection to tester01');
}

fix();
