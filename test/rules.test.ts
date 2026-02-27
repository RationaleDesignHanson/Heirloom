/**
 * Firebase Security Rules Tests
 * Tests Firestore and Storage rules for all security hardening changes.
 *
 * Run with: firebase emulators:exec --only firestore,storage "npx jest test/rules.test.ts"
 */

import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { resolve } from 'path';

const PROJECT_ID = 'heirloom-rules-test';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(resolve(__dirname, '../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: readFileSync(resolve(__dirname, '../storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

// ========================================
// FIRESTORE: Recipe Reads (Priority 3)
// ========================================
describe('Firestore: Recipe reads', () => {
  const ownerUid = 'user_owner';
  const connectedUid = 'user_connected';
  const strangerUid = 'user_stranger';

  beforeEach(async () => {
    // Set up connection between owner and connected user
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      // Create a recipe
      await db.doc(`users/${ownerUid}/recipes/recipe1`).set({
        title: 'Test Recipe',
        servings: '4',
      });
      // Create bidirectional connection docs
      await db.doc(`users/${ownerUid}/connections/${connectedUid}`).set({
        connectedUserId: connectedUid,
        status: 'accepted',
      });
      await db.doc(`users/${connectedUid}/connections/${ownerUid}`).set({
        connectedUserId: ownerUid,
        status: 'accepted',
      });
    });
  });

  test('owner CAN read their own recipe', async () => {
    const db = testEnv.authenticatedContext(ownerUid).firestore();
    await assertSucceeds(db.doc(`users/${ownerUid}/recipes/recipe1`).get());
  });

  test('connected user CAN read recipe', async () => {
    const db = testEnv.authenticatedContext(connectedUid).firestore();
    await assertSucceeds(db.doc(`users/${ownerUid}/recipes/recipe1`).get());
  });

  test('unconnected stranger CANNOT read recipe', async () => {
    const db = testEnv.authenticatedContext(strangerUid).firestore();
    await assertFails(db.doc(`users/${ownerUid}/recipes/recipe1`).get());
  });

  test('unauthenticated user CANNOT read recipe', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc(`users/${ownerUid}/recipes/recipe1`).get());
  });

  test('demo user recipes CAN be read by any authenticated user', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc('users/demo_testuser/recipes/recipe1').set({ title: 'Demo Recipe' });
    });
    const db = testEnv.authenticatedContext(strangerUid).firestore();
    await assertSucceeds(db.doc('users/demo_testuser/recipes/recipe1').get());
  });
});

// ========================================
// FIRESTORE: Shares (Priority 4 - isDemoShare)
// ========================================
describe('Firestore: Share creation', () => {
  test('owner CAN create share with own UID', async () => {
    const db = testEnv.authenticatedContext('user_a').firestore();
    await assertSucceeds(
      db.doc('shares/share1').set({
        shareId: 'share1',
        recipeId: 'recipe1',
        ownerId: 'user_a',
        ownerName: 'User A',
      })
    );
  });

  test('non-owner CANNOT create share with isDemoShare=true if ownerId is NOT demo_*', async () => {
    const db = testEnv.authenticatedContext('user_attacker').firestore();
    await assertFails(
      db.doc('shares/share2').set({
        shareId: 'share2',
        recipeId: 'recipe1',
        ownerId: 'user_victim',
        ownerName: 'Victim',
        isDemoShare: true,
      })
    );
  });

  test('any user CAN create share when ownerId IS demo_* pattern', async () => {
    const db = testEnv.authenticatedContext('user_a').firestore();
    await assertSucceeds(
      db.doc('shares/share3').set({
        shareId: 'share3',
        recipeId: 'recipe1',
        ownerId: 'demo_friend1',
        ownerName: 'Demo Friend',
      })
    );
  });
});

// ========================================
// FIRESTORE: Connections (Priority 4 - isDemoConnection)
// ========================================
describe('Firestore: Connection creation', () => {
  test('third-party user CANNOT create connection between two other users', async () => {
    // user_attacker is neither the collection owner (user_victim) nor the connectedUserId (user_other)
    const db = testEnv.authenticatedContext('user_attacker').firestore();
    await assertFails(
      db.doc('users/user_victim/connections/conn1').set({
        connectedUserId: 'user_other',
        status: 'accepted',
      })
    );
  });

  test('isDemoConnection=true does NOT bypass rules for non-demo users', async () => {
    // user_attacker is neither party and setting isDemoConnection should not help
    const db = testEnv.authenticatedContext('user_attacker').firestore();
    await assertFails(
      db.doc('users/user_victim/connections/conn1').set({
        connectedUserId: 'user_other',
        status: 'accepted',
        isDemoConnection: true,
      })
    );
  });

  test('connection involving demo_* userId CAN be created', async () => {
    const db = testEnv.authenticatedContext('user_a').firestore();
    await assertSucceeds(
      db.doc('users/demo_friend1/connections/conn1').set({
        connectedUserId: 'user_a',
        status: 'pending',
      })
    );
  });

  test('connection involving demo_* connectedUserId CAN be created', async () => {
    const db = testEnv.authenticatedContext('user_a').firestore();
    await assertSucceeds(
      db.doc('users/user_a/connections/conn2').set({
        connectedUserId: 'demo_friend1',
        status: 'pending',
      })
    );
  });

  test('user CAN create connection in own collection', async () => {
    const db = testEnv.authenticatedContext('user_a').firestore();
    await assertSucceeds(
      db.doc('users/user_a/connections/conn3').set({
        connectedUserId: 'user_b',
        status: 'pending',
      })
    );
  });

  test('user CAN create connection in other user collection with matching connectedUserId', async () => {
    const db = testEnv.authenticatedContext('user_a').firestore();
    await assertSucceeds(
      db.doc('users/user_b/connections/conn4').set({
        connectedUserId: 'user_a',
        status: 'pending',
      })
    );
  });
});

// ========================================
// FIRESTORE: Notifications (Priority 5)
// ========================================
describe('Firestore: Notification creation', () => {
  const ownerUid = 'user_owner';
  const connectedUid = 'user_connected';
  const strangerUid = 'user_stranger';

  beforeEach(async () => {
    // Set up connection
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`users/${ownerUid}/connections/${connectedUid}`).set({
        connectedUserId: connectedUid,
        status: 'accepted',
      });
    });
  });

  test('connected user CAN create notification with valid actorUserId', async () => {
    const db = testEnv.authenticatedContext(connectedUid).firestore();
    await assertSucceeds(
      db.collection(`users/${ownerUid}/notifications`).add({
        type: 'connectionSharedRecipe',
        actorUserId: connectedUid,
        actorDisplayName: 'Connected User',
        timestamp: new Date(),
        read: false,
      })
    );
  });

  test('stranger CANNOT create notification for unconnected user', async () => {
    const db = testEnv.authenticatedContext(strangerUid).firestore();
    await assertFails(
      db.collection(`users/${ownerUid}/notifications`).add({
        type: 'connectionSharedRecipe',
        actorUserId: strangerUid,
        actorDisplayName: 'Stranger',
        timestamp: new Date(),
        read: false,
      })
    );
  });

  test('NOBODY can create notification with spoofed actorUserId', async () => {
    const db = testEnv.authenticatedContext(connectedUid).firestore();
    await assertFails(
      db.collection(`users/${ownerUid}/notifications`).add({
        type: 'connectionSharedRecipe',
        actorUserId: 'spoofed_user_id',
        actorDisplayName: 'Spoofed',
        timestamp: new Date(),
        read: false,
      })
    );
  });

  test('connection request CAN be sent to non-connected user', async () => {
    const db = testEnv.authenticatedContext(strangerUid).firestore();
    await assertSucceeds(
      db.collection(`users/${ownerUid}/notifications`).add({
        type: 'connectionRequestReceived',
        actorUserId: strangerUid,
        actorDisplayName: 'Stranger',
        timestamp: new Date(),
        read: false,
      })
    );
  });

  test('lineage_modification CAN be sent to non-connected user', async () => {
    const db = testEnv.authenticatedContext(strangerUid).firestore();
    await assertSucceeds(
      db.collection(`users/${ownerUid}/notifications`).add({
        type: 'lineage_modification',
        modifiedBy: strangerUid,
        modifiedByName: 'Heritage Descendant',
        recipeId: 'recipe1',
        timestamp: new Date(),
        read: false,
      })
    );
  });

  test('user CAN create notification in own inbox (demo flow)', async () => {
    const db = testEnv.authenticatedContext(ownerUid).firestore();
    await assertSucceeds(
      db.collection(`users/${ownerUid}/notifications`).add({
        type: 'connectionRequestReceived',
        actorUserId: 'demo_friend1',
        actorDisplayName: 'Demo Friend',
        timestamp: new Date(),
        read: false,
      })
    );
  });
});

// ========================================
// FIRESTORE: RestyleJobs (Priority 8)
// ========================================
describe('Firestore: Restyle jobs', () => {
  test('owner CAN read/write their own restyle job', async () => {
    const db = testEnv.authenticatedContext('user_a').firestore();
    await assertSucceeds(
      db.doc('users/user_a/restyleJobs/job1').set({
        status: 'pending',
        recipeIds: ['r1', 'r2'],
        stylePreset: 'watercolor',
      })
    );
    await assertSucceeds(db.doc('users/user_a/restyleJobs/job1').get());
  });

  test('other user CANNOT read/write restyle jobs', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/user_a/restyleJobs/job1').set({
        status: 'pending',
      });
    });
    const db = testEnv.authenticatedContext('user_b').firestore();
    await assertFails(db.doc('users/user_a/restyleJobs/job1').get());
    await assertFails(
      db.doc('users/user_a/restyleJobs/job2').set({ status: 'pending' })
    );
  });
});

// ========================================
// FIRESTORE: Credits (Priority 8)
// ========================================
describe('Firestore: Credits', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/user_a/credits/balance').set({
        balance: 100,
      });
    });
  });

  test('owner CAN read their own credits', async () => {
    const db = testEnv.authenticatedContext('user_a').firestore();
    await assertSucceeds(db.doc('users/user_a/credits/balance').get());
  });

  test('other user CANNOT read credits', async () => {
    const db = testEnv.authenticatedContext('user_b').firestore();
    await assertFails(db.doc('users/user_a/credits/balance').get());
  });

  test('NOBODY can write credits (server-only)', async () => {
    const db = testEnv.authenticatedContext('user_a').firestore();
    await assertFails(
      db.doc('users/user_a/credits/balance').set({ balance: 999 })
    );
  });
});

// ========================================
// STORAGE: User files (Priority 10)
// ========================================
describe('Storage: User files', () => {
  test('owner CAN write file under 10MB', async () => {
    const storage = testEnv.authenticatedContext('user_a').storage();
    const ref = storage.ref('users/user_a/recipes/image.jpg');
    const smallData = new Uint8Array(1024); // 1KB
    await assertSucceeds(ref.put(smallData, { contentType: 'image/jpeg' }));
  });

  test('owner CANNOT write file over 10MB', async () => {
    const storage = testEnv.authenticatedContext('user_a').storage();
    const ref = storage.ref('users/user_a/recipes/large.jpg');
    const largeData = new Uint8Array(11 * 1024 * 1024); // 11MB
    await assertFails(ref.put(largeData, { contentType: 'image/jpeg' }));
  });

  test('non-owner CANNOT write to other user folder', async () => {
    const storage = testEnv.authenticatedContext('user_b').storage();
    const ref = storage.ref('users/user_a/recipes/image.jpg');
    const smallData = new Uint8Array(1024);
    await assertFails(ref.put(smallData, { contentType: 'image/jpeg' }));
  });
});

// ========================================
// STORAGE: Public recipe images (Priority 4 + 10)
// ========================================
describe('Storage: Public recipe images', () => {
  test('owner (matching ownerId metadata) CAN write image under 10MB', async () => {
    const storage = testEnv.authenticatedContext('user_a').storage();
    const ref = storage.ref('publicRecipes/recipe1/image.jpg');
    const data = new Uint8Array(1024);
    await assertSucceeds(
      ref.put(data, {
        contentType: 'image/jpeg',
        customMetadata: { ownerId: 'user_a' },
      })
    );
  });

  test('non-owner CANNOT write to public recipe images', async () => {
    const storage = testEnv.authenticatedContext('user_b').storage();
    const ref = storage.ref('publicRecipes/recipe1/image.jpg');
    const data = new Uint8Array(1024);
    await assertFails(
      ref.put(data, {
        contentType: 'image/jpeg',
        customMetadata: { ownerId: 'user_b' },
      })
    );
  });

  test('CANNOT write non-image file to public recipes', async () => {
    const storage = testEnv.authenticatedContext('user_a').storage();
    const ref = storage.ref('publicRecipes/recipe1/file.pdf');
    const data = new Uint8Array(1024);
    await assertFails(
      ref.put(data, {
        contentType: 'application/pdf',
        customMetadata: { ownerId: 'user_a' },
      })
    );
  });
});

// ========================================
// STORAGE: Restyle staging (Priority 8 + 10)
// ========================================
describe('Storage: Restyle staging', () => {
  test('owner CAN write image under 10MB to restyle-staging', async () => {
    const storage = testEnv.authenticatedContext('user_a').storage();
    const ref = storage.ref('users/user_a/restyle-staging/job1/recipe1.jpg');
    const data = new Uint8Array(1024);
    await assertSucceeds(ref.put(data, { contentType: 'image/jpeg' }));
  });

  test('non-owner CANNOT write to restyle-staging', async () => {
    const storage = testEnv.authenticatedContext('user_b').storage();
    const ref = storage.ref('users/user_a/restyle-staging/job1/recipe1.jpg');
    const data = new Uint8Array(1024);
    await assertFails(ref.put(data, { contentType: 'image/jpeg' }));
  });

  test('CANNOT write non-image file to restyle-staging', async () => {
    const storage = testEnv.authenticatedContext('user_a').storage();
    const ref = storage.ref('users/user_a/restyle-staging/job1/file.pdf');
    const data = new Uint8Array(1024);
    await assertFails(ref.put(data, { contentType: 'application/pdf' }));
  });
});
