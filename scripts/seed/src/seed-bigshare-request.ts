import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function seedRequest() {
  const tester01Id = 'uBaIzSsCTnWXPoYSLHwpkU54G3U2';
  const connectionId = 'demo-bigshare-request-' + Date.now();
  const now = admin.firestore.Timestamp.now();

  // Create pending friend request from demo_bigshare to tester01
  const connectionData = {
    id: connectionId,
    userId: tester01Id,
    connectedUserId: 'demo_bigshare',
    connectedUserDisplayName: 'Big Share',
    connectedUserPhotoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bigshare-avatar.webp',
    status: 'pending',
    initiatedBy: 'demo_bigshare',
    requestedAt: now,
    recipesSharedCount: 0,
    recipesReceivedCount: 0,
    isFavorite: false,
    isKitchenTableConnection: false,
    createdAt: now,
    updatedAt: now,
    isDemoConnection: true
  };

  await db.doc(`users/${tester01Id}/connections/${connectionId}`).set(connectionData);
  console.log('Created pending friend request from demo_bigshare to tester01');
  console.log('Connection ID:', connectionId);
  console.log('\nRefresh the app - should see pending request in Table tab');
}

seedRequest().catch(console.error);
