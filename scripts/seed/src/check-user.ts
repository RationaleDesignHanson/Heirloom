import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(process.env.GOOGLE_APPLICATION_CREDENTIALS || '../service-account-key.json'),
  });
}

const userId = process.argv[2] || 'jkxDVuA91wTOSLKWk3GZWqdOigQ2';

admin.auth().getUser(userId).then(u => {
  console.log('User ID:', userId);
  console.log('Email:', u.email);
  console.log('Display Name:', u.displayName);
}).catch(e => console.error(e));
