/**
 * Cleanup all demo social data from Firestore
 *
 * Removes:
 * - Demo shares (isDemoShare: true or from demo users)
 * - Connections with demo users (for all users, not just demo users)
 * - Demo notifications
 * - Lineage records for demo users
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

const DEMO_USER_IDS = [
  'demo_grandmazing',
  'demo_phillipfry',
  'demo_chef_maria',
  'demo_fitfoodie',
  'demo_bakingbelle',
  'demo_grillmaster',
];

/**
 * Delete all demo shares from the shares collection
 */
async function cleanupDemoShares(): Promise<number> {
  console.log('Cleaning up demo shares...');
  let deletedCount = 0;

  // Delete shares marked as demo
  const demoSharesSnapshot = await db.collection('shares')
    .where('isDemoShare', '==', true)
    .get();

  for (const doc of demoSharesSnapshot.docs) {
    await doc.ref.delete();
    deletedCount++;
  }
  console.log(`  Deleted ${demoSharesSnapshot.size} shares marked as isDemoShare`);

  // Delete shares from demo users (in case isDemoShare wasn't set)
  for (const demoUserId of DEMO_USER_IDS) {
    const userSharesSnapshot = await db.collection('shares')
      .where('ownerId', '==', demoUserId)
      .get();

    for (const doc of userSharesSnapshot.docs) {
      await doc.ref.delete();
      deletedCount++;
    }

    if (userSharesSnapshot.size > 0) {
      console.log(`  Deleted ${userSharesSnapshot.size} shares from ${demoUserId}`);
    }
  }

  return deletedCount;
}

/**
 * Delete connections with demo users from ALL users
 *
 * Note: Demo user accounts don't accumulate connection docs from real users
 * (connections are one-way: only in real user's account). This cleanup handles:
 * 1. Real users' connections to demo users
 * 2. Demo-to-demo connections (seeded for demo social graph)
 */
async function cleanupDemoConnections(): Promise<number> {
  console.log('Cleaning up demo connections...');
  let deletedCount = 0;

  // Get all users (we need to check each user's connections subcollection)
  const usersSnapshot = await db.collection('users').get();

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const connectionsRef = db.collection('users').doc(userId).collection('connections');

    // Delete connections marked as demo
    const demoFlagConnections = await connectionsRef
      .where('isDemoConnection', '==', true)
      .get();

    for (const doc of demoFlagConnections.docs) {
      await doc.ref.delete();
      deletedCount++;
    }

    // Delete connections to demo users (by connectedUserId)
    // This catches any connections not marked with isDemoConnection flag
    for (const demoUserId of DEMO_USER_IDS) {
      const toDemo = await connectionsRef
        .where('connectedUserId', '==', demoUserId)
        .get();

      for (const doc of toDemo.docs) {
        await doc.ref.delete();
        deletedCount++;
      }
    }
  }

  console.log(`  Deleted ${deletedCount} total demo connection documents`);
  return deletedCount;
}

/**
 * Delete demo notifications from all users
 */
async function cleanupDemoNotifications(): Promise<number> {
  console.log('Cleaning up demo notifications...');
  let deletedCount = 0;

  const usersSnapshot = await db.collection('users').get();

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const notificationsRef = db.collection('users').doc(userId).collection('notifications');

    // Delete notifications marked as demo
    const demoNotifications = await notificationsRef
      .where('isDemoNotification', '==', true)
      .get();

    for (const doc of demoNotifications.docs) {
      await doc.ref.delete();
      deletedCount++;
    }

    // Delete notifications from demo user actors
    for (const demoUserId of DEMO_USER_IDS) {
      const fromDemo = await notificationsRef
        .where('actorUserId', '==', demoUserId)
        .get();

      for (const doc of fromDemo.docs) {
        await doc.ref.delete();
        deletedCount++;
      }
    }
  }

  console.log(`  Deleted ${deletedCount} demo notifications`);
  return deletedCount;
}

/**
 * Delete lineage records involving demo users
 */
async function cleanupDemoLineages(): Promise<number> {
  console.log('Cleaning up demo lineage records...');
  let deletedCount = 0;

  for (const demoUserId of DEMO_USER_IDS) {
    // Delete where demo user is owner
    const ownerLineages = await db.collection('lineages')
      .where('ownerId', '==', demoUserId)
      .get();

    for (const doc of ownerLineages.docs) {
      await doc.ref.delete();
      deletedCount++;
    }

    // Delete where demo user is root owner
    const rootOwnerLineages = await db.collection('lineages')
      .where('rootOwnerId', '==', demoUserId)
      .get();

    for (const doc of rootOwnerLineages.docs) {
      await doc.ref.delete();
      deletedCount++;
    }
  }

  console.log(`  Deleted ${deletedCount} demo lineage records`);
  return deletedCount;
}

/**
 * Run full social cleanup
 */
export async function cleanupAllDemoSocial(): Promise<void> {
  console.log('\n🧹 DEMO SOCIAL CLEANUP');
  console.log('======================\n');
  console.log('This will remove all demo social data:\n');
  console.log('  - Demo shares (from demo users)');
  console.log('  - Connections with demo users (all users)');
  console.log('  - Demo notifications');
  console.log('  - Demo lineage records\n');

  const startTime = Date.now();

  const shares = await cleanupDemoShares();
  const connections = await cleanupDemoConnections();
  const notifications = await cleanupDemoNotifications();
  const lineages = await cleanupDemoLineages();

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  const total = shares + connections + notifications + lineages;

  console.log('\n' + '='.repeat(40));
  console.log(`✅ SOCIAL CLEANUP COMPLETE (${elapsed}s)`);
  console.log('='.repeat(40));
  console.log(`\nRemoved ${total} documents:`);
  console.log(`  - ${shares} shares`);
  console.log(`  - ${connections} connections`);
  console.log(`  - ${notifications} notifications`);
  console.log(`  - ${lineages} lineage records\n`);
}

// CLI handling
if (require.main === module) {
  cleanupAllDemoSocial()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Error:', err);
      process.exit(1);
    });
}
