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
  console.log('=== Global Shares Collection ===\n');
  const shares = await db.collection('shares').get();
  console.log('Total shares:', shares.size);

  shares.forEach(doc => {
    const d = doc.data();
    console.log('\nShare:', doc.id);
    console.log('  Recipe:', d.recipeTitle);
    console.log('  From:', d.ownerName, '(' + d.ownerId + ')');
    console.log('  To:', d.recipientUserIds);
    console.log('  Created:', d.createdAt?.toDate?.() || d.createdAt);
    console.log('  Accepted by:', d.acceptedBy);
  });

  // Also check tester01's notifications
  console.log('\n=== tester01 Notifications ===');
  const tester01Id = 'uBaIzSsCTnWXPoYSLHwpkU54G3U2';
  const notifications = await db.collection(`users/${tester01Id}/notifications`).get();
  console.log('Total notifications:', notifications.size);

  notifications.forEach(doc => {
    const d = doc.data();
    console.log('\nNotification:', doc.id);
    console.log('  Type:', d.type);
    console.log('  From:', d.actorDisplayName);
    console.log('  Recipe:', d.recipeTitle);
    console.log('  Read:', d.read);
  });
}

check();
