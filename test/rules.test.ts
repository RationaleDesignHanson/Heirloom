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

// ========================================
// FIRESTORE: Recipe subcollection reads (P0 Security)
// Verifies subcollections inherit parent recipe access control
// ========================================
describe('Firestore: Recipe subcollection reads', () => {
  const ownerUid = 'user_owner';
  const connectedUid = 'user_connected';
  const strangerUid = 'user_stranger';
  const demoUid = 'demo_testuser';

  const subcollections = ['ingredients', 'instructions', 'comments', 'cardBack', 'operations'];

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      // Create recipe and subcollection docs
      await db.doc(`users/${ownerUid}/recipes/recipe1`).set({ title: 'Test Recipe' });
      for (const sub of subcollections) {
        await db.doc(`users/${ownerUid}/recipes/recipe1/${sub}/doc1`).set({ data: 'test' });
      }
      // Create demo recipe and subcollection docs
      await db.doc(`users/${demoUid}/recipes/recipe1`).set({ title: 'Demo Recipe' });
      for (const sub of subcollections) {
        await db.doc(`users/${demoUid}/recipes/recipe1/${sub}/doc1`).set({ data: 'test' });
      }
      // Create connection between owner and connected user
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

  for (const sub of subcollections) {
    test(`owner CAN read ${sub}`, async () => {
      const db = testEnv.authenticatedContext(ownerUid).firestore();
      await assertSucceeds(db.doc(`users/${ownerUid}/recipes/recipe1/${sub}/doc1`).get());
    });
  }

  // Test one subcollection for connected user (representative)
  test('connected user CAN read ingredients', async () => {
    const db = testEnv.authenticatedContext(connectedUid).firestore();
    await assertSucceeds(db.doc(`users/${ownerUid}/recipes/recipe1/ingredients/doc1`).get());
  });

  test('connected user CAN read instructions', async () => {
    const db = testEnv.authenticatedContext(connectedUid).firestore();
    await assertSucceeds(db.doc(`users/${ownerUid}/recipes/recipe1/instructions/doc1`).get());
  });

  for (const sub of subcollections) {
    test(`stranger CANNOT read ${sub}`, async () => {
      const db = testEnv.authenticatedContext(strangerUid).firestore();
      await assertFails(db.doc(`users/${ownerUid}/recipes/recipe1/${sub}/doc1`).get());
    });
  }

  // Test one subcollection for unauth (representative)
  test('unauthenticated CANNOT read ingredients', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc(`users/${ownerUid}/recipes/recipe1/ingredients/doc1`).get());
  });

  test('unauthenticated CANNOT read operations', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc(`users/${ownerUid}/recipes/recipe1/operations/doc1`).get());
  });

  // Demo subcollection reads
  test('any authenticated user CAN read demo user ingredients', async () => {
    const db = testEnv.authenticatedContext(strangerUid).firestore();
    await assertSucceeds(db.doc(`users/${demoUid}/recipes/recipe1/ingredients/doc1`).get());
  });

  test('any authenticated user CAN read demo user instructions', async () => {
    const db = testEnv.authenticatedContext(strangerUid).firestore();
    await assertSucceeds(db.doc(`users/${demoUid}/recipes/recipe1/instructions/doc1`).get());
  });
});

// ========================================
// FIRESTORE: Share reads (P0 Security)
// Shares require authentication (UUIDs are bearer tokens)
// ========================================
describe('Firestore: Share reads', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('shares/share-uuid-123').set({
        shareId: 'share-uuid-123',
        recipeId: 'recipe1',
        ownerId: 'user_a',
        ownerName: 'User A',
      });
    });
  });

  test('authenticated user CAN read share', async () => {
    const db = testEnv.authenticatedContext('user_b').firestore();
    await assertSucceeds(db.doc('shares/share-uuid-123').get());
  });

  test('unauthenticated user CANNOT read share', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc('shares/share-uuid-123').get());
  });
});

// ========================================
// FIRESTORE: Public recipe reads (P0 Security)
// Public recipes require authentication
// ========================================
describe('Firestore: Public recipe reads', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('publicRecipes/pub1').set({
        title: 'Community Recipe',
        ownerId: 'user_a',
      });
    });
  });

  test('authenticated user CAN read public recipe', async () => {
    const db = testEnv.authenticatedContext('user_b').firestore();
    await assertSucceeds(db.doc('publicRecipes/pub1').get());
  });

  test('unauthenticated user CANNOT read public recipe', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc('publicRecipes/pub1').get());
  });
});

// ========================================
// FIRESTORE: Demo flag protection (P0 Security)
// isDemoUser checks server-side UID pattern, not client fields
// ========================================
describe('Firestore: Demo flag protection', () => {
  test('non-demo user CANNOT create recipe for another non-demo user', async () => {
    const db = testEnv.authenticatedContext('user_attacker').firestore();
    await assertFails(
      db.doc('users/user_victim/recipes/recipe1').set({
        title: 'Injected Recipe',
        isDemoRecipe: true,
      })
    );
  });

  test('any authenticated user CAN create recipe for demo user', async () => {
    const db = testEnv.authenticatedContext('user_a').firestore();
    await assertSucceeds(
      db.doc('users/demo_friend1/recipes/recipe1').set({
        title: 'Demo Recipe',
      })
    );
  });

  test('isDemoConnection field does NOT bypass connection rules for non-demo users', async () => {
    const db = testEnv.authenticatedContext('user_attacker').firestore();
    await assertFails(
      db.doc('users/user_victim/connections/conn1').set({
        connectedUserId: 'user_other',
        status: 'accepted',
        isDemoConnection: true,
      })
    );
  });
});

// ========================================
// FIRESTORE: Unauthenticated access (P0 Security)
// All user-scoped collections deny unauthenticated access
// ========================================
describe('Firestore: Unauthenticated access denied', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc('users/user_a').set({ displayName: 'User A' });
      await db.doc('users/user_a/recipes/recipe1').set({ title: 'Secret Recipe' });
      await db.doc('users/user_a/notifications/notif1').set({ type: 'test', read: false });
      await db.doc('users/user_a/settings/prefs').set({ theme: 'dark' });
      await db.doc('users/user_a/collections/coll1').set({ name: 'Favorites' });
    });
  });

  test('unauthenticated CANNOT read user document', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc('users/user_a').get());
  });

  test('unauthenticated CANNOT read recipes', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc('users/user_a/recipes/recipe1').get());
  });

  test('unauthenticated CANNOT read notifications', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc('users/user_a/notifications/notif1').get());
  });

  test('unauthenticated CANNOT read settings', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc('users/user_a/settings/prefs').get());
  });

  test('unauthenticated CANNOT read collections', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.doc('users/user_a/collections/coll1').get());
  });
});

// ========================================
// STORAGE: Read restrictions (P0 Security)
// Owner-only for recipe images, any-auth for profile images
// ========================================
describe('Storage: Read restrictions', () => {
  test('owner CAN read their own recipe images', async () => {
    // First upload a file as owner
    const ownerStorage = testEnv.authenticatedContext('user_a').storage();
    const ref = ownerStorage.ref('users/user_a/recipes/image.jpg');
    const data = new Uint8Array(1024);
    await assertSucceeds(ref.put(data, { contentType: 'image/jpeg' }));
    // Owner can read it back
    await assertSucceeds(ref.getDownloadURL());
  });

  test('non-owner CANNOT read other user recipe images', async () => {
    // Upload as owner
    const ownerStorage = testEnv.authenticatedContext('user_a').storage();
    const ref = ownerStorage.ref('users/user_a/recipes/image.jpg');
    const data = new Uint8Array(1024);
    await ref.put(data, { contentType: 'image/jpeg' });
    // Try to read as non-owner
    const otherStorage = testEnv.authenticatedContext('user_b').storage();
    const otherRef = otherStorage.ref('users/user_a/recipes/image.jpg');
    await assertFails(otherRef.getDownloadURL());
  });

  test('any authenticated user CAN read profile images', async () => {
    // Upload profile image as owner
    const ownerStorage = testEnv.authenticatedContext('user_a').storage();
    const ref = ownerStorage.ref('users/user_a/profile/avatar.jpg');
    const data = new Uint8Array(1024);
    await ref.put(data, { contentType: 'image/jpeg' });
    // Other user can read profile images
    const otherStorage = testEnv.authenticatedContext('user_b').storage();
    const otherRef = otherStorage.ref('users/user_a/profile/avatar.jpg');
    await assertSucceeds(otherRef.getDownloadURL());
  });

  test('unauthenticated CANNOT read any user storage files', async () => {
    // Upload as owner first
    const ownerStorage = testEnv.authenticatedContext('user_a').storage();
    const ref = ownerStorage.ref('users/user_a/recipes/image.jpg');
    const data = new Uint8Array(1024);
    await ref.put(data, { contentType: 'image/jpeg' });
    // Try unauthenticated read
    const unauthStorage = testEnv.unauthenticatedContext().storage();
    const unauthRef = unauthStorage.ref('users/user_a/recipes/image.jpg');
    await assertFails(unauthRef.getDownloadURL());
  });
});
