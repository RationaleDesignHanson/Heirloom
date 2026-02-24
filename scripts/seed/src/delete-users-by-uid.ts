import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const auth = admin.auth();
const db = admin.firestore();

async function deleteUserByUid(uid: string): Promise<void> {
  console.log('\nDeleting UID: ' + uid);
  
  try {
    const user = await auth.getUser(uid);
    console.log('  Display Name: ' + (user.displayName || 'none'));
    console.log('  Email: ' + (user.email || 'no email'));
    
    // Delete Firestore data
    const subcollections = ['recipes', 'collections', 'connections', 'notifications'];
    for (const sub of subcollections) {
      const snap = await db.collection('users').doc(uid).collection(sub).get();
      if (snap.size > 0) {
        const batch = db.batch();
        snap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log('  Deleted ' + snap.size + ' ' + sub);
      }
    }
    
    // Delete user profile document
    await db.collection('users').doc(uid).delete();
    console.log('  Deleted profile document');
    
    // Delete Firebase Auth account
    await auth.deleteUser(uid);
    console.log('  Deleted Auth account');
    
    console.log('  DONE');
  } catch (e: any) {
    if (e.code === 'auth/user-not-found') {
      console.log('  NOT FOUND - skipping');
    } else {
      console.log('  ERROR: ' + e.message);
    }
  }
}

async function main() {
  const uidsToDelete = process.argv.slice(2);
  
  if (uidsToDelete.length === 0) {
    console.log('Usage: npx ts-node src/delete-users-by-uid.ts uid1 uid2 ...');
    process.exit(1);
  }
  
  console.log('Deleting ' + uidsToDelete.length + ' users by UID...');
  
  for (const uid of uidsToDelete) {
    await deleteUserByUid(uid);
  }
  
  console.log('\nDone!');
}

main().then(() => process.exit(0)).catch(console.error);
