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

async function main() {
  const testEmails = [
    'hanson@rationale.com',
    'newmatthanson@gmail.com', 
    'admin@rationale.com',
    'demo@heirloomrecipebox.app',
    'tester01@heirloomrecipebox.app',
    'deletetest@heirloomrecipebox.app'
  ];
  
  console.log('Checking accounts:\n');
  for (const email of testEmails) {
    try {
      const user = await auth.getUserByEmail(email);
      const providers = user.providerData.map((p: any) => p.providerId).join(', ');
      console.log('FOUND: ' + email);
      console.log('  UID: ' + user.uid);
      console.log('  Providers: ' + providers);
      console.log('');
    } catch (e: any) {
      if (e.code === 'auth/user-not-found') {
        console.log('NOT FOUND: ' + email + '\n');
      } else {
        console.log('ERROR: ' + email + ' - ' + e.message + '\n');
      }
    }
  }
}

main().then(() => process.exit(0)).catch(console.error);
