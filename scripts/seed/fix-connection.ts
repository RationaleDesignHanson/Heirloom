/**
 * Fix existing demo connection that's missing required fields
 *
 * This script patches the connection document to add the missing 'isKitchenTableConnection' field
 * which was causing the Connection model's Codable decoder to fail.
 *
 * Usage: npx ts-node fix-connection.ts <userId>
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '.env') });

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

async function fixConnection(userId: string) {
  console.log(`Fixing connections for user: ${userId}`);
  console.log('='.repeat(60));

  // Get all connections for this user
  const connectionsRef = db.collection('users').doc(userId).collection('connections');
  const snapshot = await connectionsRef.get();

  console.log(`Found ${snapshot.size} connections`);

  let fixed = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();

    // Check if isKitchenTableConnection is missing
    if (data.isKitchenTableConnection === undefined) {
      console.log(`  Fixing connection: ${doc.id} (missing isKitchenTableConnection)`);

      await doc.ref.update({
        isKitchenTableConnection: data.sourceKitchenTableId != null,
      });
      fixed++;
    }

    // Also check for other missing fields that could cause decoder failure
    const updates: Record<string, any> = {};

    if (data.recipesSharedCount === undefined) {
      updates.recipesSharedCount = 0;
    }
    if (data.recipesReceivedCount === undefined) {
      updates.recipesReceivedCount = 0;
    }
    if (data.isFavorite === undefined) {
      updates.isFavorite = false;
    }

    if (Object.keys(updates).length > 0) {
      console.log(`  Adding missing fields to ${doc.id}:`, Object.keys(updates).join(', '));
      await doc.ref.update(updates);
      if (data.isKitchenTableConnection !== undefined) {
        fixed++;
      }
    }
  }

  console.log(`\nFixed ${fixed} connections`);
}

async function main() {
  const userId = process.argv[2];

  if (!userId) {
    console.error('Usage: npx ts-node fix-connection.ts <userId>');
    console.error('');
    console.error('Example: npx ts-node fix-connection.ts TuQgh4k7HSY8p5eDk90ja53u9ki2');
    process.exit(1);
  }

  await fixConnection(userId);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
