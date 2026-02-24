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

const APPLE_TEST_ACCOUNTS = [
  'demo@heirloomrecipebox.app',
  'tester01@heirloomrecipebox.app',
  'deletetest@heirloomrecipebox.app'
];

async function listAllUsers() {
  console.log('All Firebase Auth Users (excluding Apple test accounts)\n');
  console.log('='.repeat(80));
  
  let nextPageToken: string | undefined;
  let count = 0;
  
  do {
    const result = await auth.listUsers(1000, nextPageToken);
    
    for (const user of result.users) {
      const email = user.email || 'no-email';
      
      // Skip Apple test accounts
      if (APPLE_TEST_ACCOUNTS.includes(email)) {
        continue;
      }
      
      const providers = user.providerData.map((p: any) => p.providerId).join(', ') || 'none';
      const created = user.metadata.creationTime ? new Date(user.metadata.creationTime).toLocaleDateString() : 'unknown';
      const lastSignIn = user.metadata.lastSignInTime ? new Date(user.metadata.lastSignInTime).toLocaleDateString() : 'never';
      
      console.log('Email: ' + email);
      console.log('  UID: ' + user.uid);
      console.log('  Provider: ' + providers);
      console.log('  Created: ' + created + ' | Last Sign-in: ' + lastSignIn);
      console.log('  Display Name: ' + (user.displayName || 'not set'));
      console.log('');
      count++;
    }
    
    nextPageToken = result.pageToken;
  } while (nextPageToken);
  
  console.log('='.repeat(80));
  console.log('Total users (excluding Apple test accounts): ' + count);
}

listAllUsers().then(() => process.exit(0)).catch(console.error);
