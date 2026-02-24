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

  // Check specific connection ID from the log
  const connId = '7989acd4-d018-457a-95ff-6ebd7271da95';
  const conn = await db.collection('connections').doc(connId).get();
  console.log('=== Specific Connection from logs ===');
  console.log('Connection', connId, 'exists:', conn.exists);
  if (conn.exists) {
    console.log('Data:', JSON.stringify(conn.data(), null, 2));
  }

  // Check connections for tester01
  console.log('=== Connections involving tester01 ===');
  const connections1 = await db.collection('connections')
    .where('userIds', 'array-contains', tester01Id)
    .get();
  console.log('Count:', connections1.size);

  // Check connections for demo_bigshare
  console.log('\n=== Connections involving demo_bigshare ===');
  const connections2 = await db.collection('connections')
    .where('userIds', 'array-contains', 'demo_bigshare')
    .get();
  console.log('Count:', connections2.size);
  connections2.forEach((doc: admin.firestore.QueryDocumentSnapshot) => {
    const d = doc.data();
    console.log('\nConnection:', doc.id);
    console.log('  userIds:', d.userIds);
    console.log('  status:', d.status);
    console.log('  shareHistory:', JSON.stringify(d.shareHistory || [], null, 2));
  });

  // Check ALL connections
  console.log('\n=== ALL connections (first 10) ===');
  const allConnections = await db.collection('connections').limit(10).get();
  console.log('Total found:', allConnections.size);
  allConnections.forEach((doc: admin.firestore.QueryDocumentSnapshot) => {
    const d = doc.data();
    console.log('  -', doc.id, ':', d.userIds, '(' + d.status + ')');
  });

  // Check user subcollections
  console.log('\n=== tester01 connections subcollection (FULL DATA) ===');
  const userConns = await db.collection('users/' + tester01Id + '/connections').get();
  console.log('Count:', userConns.size);
  userConns.forEach((doc: admin.firestore.QueryDocumentSnapshot) => {
    const d = doc.data();
    console.log('\nConnection:', doc.id);
    console.log(JSON.stringify(d, null, 2));
  });

  console.log('\n=== demo_bigshare connections subcollection (FULL DATA) ===');
  const demoConns = await db.collection('users/demo_bigshare/connections').get();
  console.log('Count:', demoConns.size);
  demoConns.forEach((doc: admin.firestore.QueryDocumentSnapshot) => {
    const d = doc.data();
    console.log('\nConnection:', doc.id);
    console.log(JSON.stringify(d, null, 2));
  });

  // Check demo_bigshare shares subcollection
  console.log('\n=== demo_bigshare shares subcollection ===');
  const demoShares = await db.collection('users/demo_bigshare/shares').get();
  console.log('Count:', demoShares.size);
  demoShares.forEach((doc: admin.firestore.QueryDocumentSnapshot) => {
    const d = doc.data();
    console.log('  -', doc.id, ':', d.recipeTitle, 'to', d.recipientId);
  });
}

check();
