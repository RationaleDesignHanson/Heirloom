/**
 * Export all Firebase data for specified users to local JSON files
 * 
 * Exports: recipes, collections, connections, profile, notifications, shares
 * 
 * Usage: 
 *   npx ts-node src/export-user-data.ts                    # Export all configured users
 *   npx ts-node src/export-user-data.ts user@email.com     # Export specific user
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();
const auth = admin.auth();

// Users to export by default
const DEFAULT_USERS = [
  'hanson@rationale.com',
  'newmatthanson@gmail.com',
  'admin@rationale.com',
];

const OUTPUT_DIR = path.resolve(__dirname, '../exports');

interface ExportData {
  exportedAt: string;
  email: string;
  userId: string;
  profile: any;
  recipes: any[];
  collections: any[];
  connections: any[];
  notifications: any[];
  shares: any[];
  pendingShares: any[];
}

async function exportUserData(email: string): Promise<void> {
  console.log('\n' + '='.repeat(60));
  console.log('Exporting: ' + email);
  console.log('='.repeat(60));

  // Find user by email
  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (e: any) {
    if (e.code === 'auth/user-not-found') {
      console.log('ERROR: User not found in Firebase Auth: ' + email);
      return;
    }
    throw e;
  }

  const userId = user.uid;
  console.log('User ID: ' + userId);
  console.log('Provider: ' + (user.providerData.map(p => p.providerId).join(', ') || 'unknown'));

  const exportData: ExportData = {
    exportedAt: new Date().toISOString(),
    email: email,
    userId: userId,
    profile: null,
    recipes: [],
    collections: [],
    connections: [],
    notifications: [],
    shares: [],
    pendingShares: [],
  };

  // Export profile
  console.log('\nFetching profile...');
  const profileDoc = await db.collection('users').doc(userId).get();
  if (profileDoc.exists) {
    exportData.profile = { id: profileDoc.id, ...profileDoc.data() };
    console.log('  Profile: found');
  } else {
    console.log('  Profile: not found');
  }

  // Export recipes
  console.log('\nFetching recipes...');
  const recipesSnap = await db.collection('users').doc(userId).collection('recipes').get();
  for (const doc of recipesSnap.docs) {
    exportData.recipes.push({ id: doc.id, ...doc.data() });
  }
  console.log('  Recipes: ' + exportData.recipes.length);

  // Export collections
  console.log('\nFetching collections...');
  const collectionsSnap = await db.collection('users').doc(userId).collection('collections').get();
  for (const doc of collectionsSnap.docs) {
    exportData.collections.push({ id: doc.id, ...doc.data() });
  }
  console.log('  Collections: ' + exportData.collections.length);

  // Export connections
  console.log('\nFetching connections...');
  const connectionsSnap = await db.collection('users').doc(userId).collection('connections').get();
  for (const doc of connectionsSnap.docs) {
    exportData.connections.push({ id: doc.id, ...doc.data() });
  }
  console.log('  Connections: ' + exportData.connections.length);

  // Export notifications
  console.log('\nFetching notifications...');
  const notificationsSnap = await db.collection('users').doc(userId).collection('notifications').get();
  for (const doc of notificationsSnap.docs) {
    exportData.notifications.push({ id: doc.id, ...doc.data() });
  }
  console.log('  Notifications: ' + exportData.notifications.length);

  // Export shares (created by this user)
  console.log('\nFetching shares...');
  const sharesSnap = await db.collection('shares').where('ownerId', '==', userId).get();
  for (const doc of sharesSnap.docs) {
    exportData.shares.push({ id: doc.id, ...doc.data() });
  }
  console.log('  Shares created: ' + exportData.shares.length);

  // Export pending shares (waiting for this user)
  const pendingSharesSnap = await db.collection('shares')
    .where('recipientEmail', '==', email)
    .where('status', '==', 'pending')
    .get();
  for (const doc of pendingSharesSnap.docs) {
    exportData.pendingShares.push({ id: doc.id, ...doc.data() });
  }
  console.log('  Pending shares: ' + exportData.pendingShares.length);

  // Ensure output directory exists
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  // Write to file
  const safeEmail = email.replace(/[^a-z0-9]/gi, '_');
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const filename = safeEmail + '_' + timestamp + '.json';
  const filepath = path.join(OUTPUT_DIR, filename);

  fs.writeFileSync(filepath, JSON.stringify(exportData, null, 2));
  console.log('\nExported to: ' + filepath);

  // Summary
  console.log('\n' + '-'.repeat(40));
  console.log('SUMMARY:');
  console.log('  Profile: ' + (exportData.profile ? 'Yes' : 'No'));
  console.log('  Recipes: ' + exportData.recipes.length);
  console.log('  Collections: ' + exportData.collections.length);
  console.log('  Connections: ' + exportData.connections.length);
  console.log('  Notifications: ' + exportData.notifications.length);
  console.log('  Shares: ' + exportData.shares.length);
  console.log('  Pending Shares: ' + exportData.pendingShares.length);
}

async function main() {
  const args = process.argv.slice(2);
  const usersToExport = args.length > 0 ? args : DEFAULT_USERS;

  console.log('Firebase User Data Export');
  console.log('='.repeat(60));
  console.log('Output directory: ' + OUTPUT_DIR);
  console.log('Users to export: ' + usersToExport.length);

  for (const email of usersToExport) {
    await exportUserData(email);
  }

  console.log('\n' + '='.repeat(60));
  console.log('EXPORT COMPLETE');
  console.log('='.repeat(60));
  console.log('Files saved to: ' + OUTPUT_DIR);
}

main()
  .then(() => process.exit(0))
  .catch((err) => { console.error('Error:', err); process.exit(1); });
