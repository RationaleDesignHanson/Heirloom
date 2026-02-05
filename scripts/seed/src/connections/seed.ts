/**
 * Seed demo connections between demo users
 *
 * Creates bi-directional connection documents in Firestore.
 * Connections stored at: users/{userId}/connections/{connectionId}
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

// Demo connection definitions
interface DemoConnection {
  user1Id: string;
  user2Id: string;
  user1Name: string;
  user2Name: string;
  relationshipNote: string;
  recipesSharedCount: number;
  lastInteractionDaysAgo: number;
}

const DEMO_CONNECTIONS: DemoConnection[] = [
  {
    user1Id: 'demo_grandmazing',
    user2Id: 'demo_bakingbelle',
    user1Name: 'Grandmazing',
    user2Name: 'Belle Thompson',
    relationshipNote: 'Baking connection - sharing classic recipes',
    recipesSharedCount: 8,
    lastInteractionDaysAgo: 3,
  },
  {
    user1Id: 'demo_grandmazing',
    user2Id: 'demo_phillipfry',
    user1Name: 'Grandmazing',
    user2Name: 'Phillip Fry',
    relationshipNote: 'Mentorship - teaching comfort food basics',
    recipesSharedCount: 5,
    lastInteractionDaysAgo: 7,
  },
  {
    user1Id: 'demo_chef_maria',
    user2Id: 'demo_grandmazing',
    user1Name: 'Maria Santos',
    user2Name: 'Grandmazing',
    relationshipNote: 'Recipe appreciation - traditional methods',
    recipesSharedCount: 4,
    lastInteractionDaysAgo: 10,
  },
  {
    user1Id: 'demo_chef_maria',
    user2Id: 'demo_grillmaster',
    user1Name: 'Maria Santos',
    user2Name: 'Marcus Johnson',
    relationshipNote: 'Professional network - culinary experts',
    recipesSharedCount: 6,
    lastInteractionDaysAgo: 5,
  },
  {
    user1Id: 'demo_fitfoodie',
    user2Id: 'demo_phillipfry',
    user1Name: 'Alex Chen',
    user2Name: 'Phillip Fry',
    relationshipNote: 'Quick healthy meals inspiration',
    recipesSharedCount: 3,
    lastInteractionDaysAgo: 2,
  },
  {
    user1Id: 'demo_bakingbelle',
    user2Id: 'demo_fitfoodie',
    user1Name: 'Belle Thompson',
    user2Name: 'Alex Chen',
    relationshipNote: 'Healthy dessert experiments',
    recipesSharedCount: 2,
    lastInteractionDaysAgo: 14,
  },
  {
    user1Id: 'demo_grillmaster',
    user2Id: 'demo_phillipfry',
    user1Name: 'Marcus Johnson',
    user2Name: 'Phillip Fry',
    relationshipNote: 'BBQ basics for beginners',
    recipesSharedCount: 4,
    lastInteractionDaysAgo: 8,
  },
];

/**
 * Create a connection document between two users
 */
async function createConnection(
  userId: string,
  connectedUserId: string,
  connectedUserName: string,
  connectionData: {
    relationshipNote: string;
    recipesSharedCount: number;
    lastInteractionDaysAgo: number;
  }
): Promise<void> {
  const connectionRef = db
    .collection('users')
    .doc(userId)
    .collection('connections')
    .doc(connectedUserId);

  const lastInteractionDate = new Date();
  lastInteractionDate.setDate(lastInteractionDate.getDate() - connectionData.lastInteractionDaysAgo);

  await connectionRef.set({
    connectedUserId,
    connectedUserName,
    status: 'accepted',
    recipesSharedCount: connectionData.recipesSharedCount,
    lastInteraction: admin.firestore.Timestamp.fromDate(lastInteractionDate),
    notes: connectionData.relationshipNote,
    isDemoConnection: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

/**
 * Seed all demo connections (bi-directional)
 */
export async function seedDemoConnections(): Promise<void> {
  console.log('Seeding demo connections...\n');

  let connectionCount = 0;

  for (const connection of DEMO_CONNECTIONS) {
    console.log(`  Creating connection: ${connection.user1Name} <-> ${connection.user2Name}`);

    // Create connection in user1's collection
    await createConnection(
      connection.user1Id,
      connection.user2Id,
      connection.user2Name,
      {
        relationshipNote: connection.relationshipNote,
        recipesSharedCount: connection.recipesSharedCount,
        lastInteractionDaysAgo: connection.lastInteractionDaysAgo,
      }
    );

    // Create connection in user2's collection (bi-directional)
    await createConnection(
      connection.user2Id,
      connection.user1Id,
      connection.user1Name,
      {
        relationshipNote: connection.relationshipNote,
        recipesSharedCount: connection.recipesSharedCount,
        lastInteractionDaysAgo: connection.lastInteractionDaysAgo,
      }
    );

    connectionCount += 2;
    console.log(`    ✓ Created bi-directional connection`);
  }

  console.log(`\n✅ Seeded ${connectionCount} connection documents (${DEMO_CONNECTIONS.length} pairs)`);
}

/**
 * Cleanup demo connections from Firestore
 */
export async function cleanupDemoConnections(): Promise<void> {
  console.log('Cleaning up demo connections...\n');

  const demoUserIds = [
    'demo_grandmazing',
    'demo_phillipfry',
    'demo_chef_maria',
    'demo_fitfoodie',
    'demo_bakingbelle',
    'demo_grillmaster',
  ];

  let deletedCount = 0;

  for (const userId of demoUserIds) {
    const connectionsRef = db.collection('users').doc(userId).collection('connections');
    const snapshot = await connectionsRef.where('isDemoConnection', '==', true).get();

    for (const doc of snapshot.docs) {
      await doc.ref.delete();
      deletedCount++;
    }

    console.log(`  Deleted ${snapshot.size} connections for ${userId}`);
  }

  console.log(`\n✅ Cleaned up ${deletedCount} demo connection documents`);
}

// CLI handling
if (require.main === module) {
  const command = process.argv[2];

  if (command === 'cleanup') {
    cleanupDemoConnections()
      .then(() => process.exit(0))
      .catch((err) => {
        console.error('Error:', err);
        process.exit(1);
      });
  } else {
    seedDemoConnections()
      .then(() => process.exit(0))
      .catch((err) => {
        console.error('Error:', err);
        process.exit(1);
      });
  }
}
